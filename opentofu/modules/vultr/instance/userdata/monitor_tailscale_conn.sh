#!/bin/bash
#
# Tailscale OAuth Client for Device Status (Bash version with debugging)
# Retrieves device status information from Tailscale network using OAuth authentication.
#

set -euo pipefail

# Default configuration - can be overridden by environment variables
DEFAULT_CLIENT_ID=""         # Set your default client ID here
DEFAULT_CLIENT_SECRET=""     # Set your default client secret here
DEFAULT_TAILNET=""           # Set your default tailnet here (e.g., "your-org.com")

# API endpoints
TOKEN_URL="https://api.tailscale.com/api/v2/oauth/token"
API_BASE_URL="https://api.tailscale.com/api/v2"

# Global variables
ACCESS_TOKEN=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBUG="${TAILSCALE_DEBUG:-0}"  # Set TAILSCALE_DEBUG=1 for verbose output
CHECK_DURATION="0"  # Will store the duration of the check

# Debug logging function
debug_log() {
    if [[ "$DEBUG" == "1" ]]; then
        echo "🐛 DEBUG: $*" >&2
    fi
}

# Function to load .env file if it exists
load_env_file() {
    local env_file="/var/mnt/storage/sbin/tailscale_monitor/.env"

    if [[ -f "$env_file" ]]; then
        # Read .env file and export variables that aren't already set
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            # Skip empty lines and comments
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

            # Remove leading/trailing whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)

            # Remove quotes if present
            if [[ "$value" =~ ^[\"\'].*[\"\']$ ]]; then
                value="${value:1:-1}"
            fi

            # Only set if not already set in environment
            if [[ -z "${!key:-}" ]]; then
                export "$key"="$value"
            fi
        done < "$env_file"

        echo "📄 Loaded configuration from $env_file" >&2
        return 0
    fi

    return 1
}

# Function to get OAuth access token using client credentials
get_client_credentials_token() {
    local client_id="$1"
    local client_secret="$2"

    debug_log "Requesting OAuth token from $TOKEN_URL"

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$TOKEN_URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -d "client_id=$client_id" \
        -d "client_secret=$client_secret" 2>/dev/null) || {
        echo "❌ Error during token request" >&2
        return 1
    }

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | head -n -1)

    debug_log "Token request response code: $http_code"
    debug_log "Token request response body: $body"

    if [[ "$http_code" == "200" ]]; then
        ACCESS_TOKEN=$(echo "$body" | jq -r '.access_token // empty')
        if [[ -n "$ACCESS_TOKEN" && "$ACCESS_TOKEN" != "null" ]]; then
            echo "✅ Successfully obtained access token using client credentials" >&2
            debug_log "Access token (first 20 chars): ${ACCESS_TOKEN:0:20}..."
            return 0
        fi
    elif [[ "$http_code" == "403" ]]; then
        local error_msg
        error_msg=$(echo "$body" | jq -r '.message // "Unknown error"')
        echo "❌ Permission denied: $error_msg" >&2
        echo "💡 This usually means your OAuth client doesn't have the required scopes." >&2
        echo "   Please check your OAuth client configuration in the Tailscale admin console." >&2
        echo "   Make sure 'All' is selected or 'devices' scope is explicitly granted." >&2
    else
        echo "❌ Token request failed: HTTP $http_code - $body" >&2
    fi

    return 1
}

# Function to make authenticated API request
make_api_request() {
    local endpoint="$1"
    local full_url="${API_BASE_URL}${endpoint}"

    if [[ -z "$ACCESS_TOKEN" ]]; then
        echo "❌ No valid access token available" >&2
        return 1
    fi

    debug_log "Making API request to: $full_url"

    local response
    response=$(curl -s -w "\n%{http_code}" -X GET "$full_url" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" 2>/dev/null) || {
        echo "❌ Error making API request" >&2
        return 1
    }

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | head -n -1)

    debug_log "API response code: $http_code"
    debug_log "API response body length: ${#body} characters"
    
    if [[ "$DEBUG" == "1" ]]; then
        debug_log "API response body (first 500 chars): ${body:0:500}"
        if [[ ${#body} -gt 500 ]]; then
            debug_log "API response body (last 100 chars): ${body: -100}"
        fi
    fi

    if [[ "$http_code" == "200" ]]; then
        # Validate JSON before returning
        if echo "$body" | jq empty 2>/dev/null; then
            debug_log "JSON validation passed"
            echo "$body"
            return 0
        else
            echo "❌ API returned invalid JSON" >&2
            debug_log "Invalid JSON content: $body"
            return 1
        fi
    else
        echo "❌ API request failed: HTTP $http_code - $body" >&2
        return 1
    fi
}

# Function to get all devices in the tailnet
get_devices() {
    local tailnet="$1"
    local response

    debug_log "Getting devices for tailnet: $tailnet"

    response=$(make_api_request "/tailnet/$tailnet/devices") || return 1

    # Extract devices array from response
    local devices
    devices=$(echo "$response" | jq -r '.devices // []')
    
    debug_log "Extracted devices array"
    
    if [[ "$DEBUG" == "1" ]]; then
        local device_count
        device_count=$(echo "$devices" | jq 'length // 0')
        debug_log "Found $device_count devices"

        # Show device structures for debugging
        if [[ $device_count -gt 0 ]]; then
            debug_log "All device structures:"
            echo "$devices" | jq '.[]' >&2
            debug_log "--- End of device structures ---"
        fi
    fi

    echo "$devices"
}

# Function to check if a timestamp indicates recent activity
check_recent_activity() {
    local timestamp="$1"
    local threshold_seconds="$2"

    debug_log "Checking recent activity for timestamp: $timestamp (threshold: ${threshold_seconds}s)"

    if [[ -z "$timestamp" || "$timestamp" == "null" ]]; then
        debug_log "No timestamp provided or timestamp is null"
        return 1
    fi

    # Convert ISO timestamp to Unix timestamp
    local timestamp_unix
    timestamp_unix=$(date -d "$timestamp" +%s 2>/dev/null) || {
        debug_log "Failed to parse timestamp: $timestamp"
        return 1
    }

    local current_unix
    current_unix=$(date +%s)

    local diff=$((current_unix - timestamp_unix))

    debug_log "Time difference: ${diff}s (current: $current_unix, device: $timestamp_unix)"

    if [[ $diff -lt $threshold_seconds ]]; then
        debug_log "Device has recent activity (within ${threshold_seconds}s)"
        return 0
    else
        debug_log "Device does not have recent activity (${diff}s ago)"
        return 1
    fi
}

# Function to check device online status
check_device_online_status() {
    local device_json="$1"
    
    debug_log "Checking online status for device"

    # Method 1: Check explicit online/connected fields
    local online connected active isOnline connectedToControl
    online=$(echo "$device_json" | jq -r '.online // false')
    connected=$(echo "$device_json" | jq -r '.connected // false')
    active=$(echo "$device_json" | jq -r '.active // false')
    isOnline=$(echo "$device_json" | jq -r '.isOnline // false')
    connectedToControl=$(echo "$device_json" | jq -r '.connectedToControl // false')

    debug_log "Method 1 - Explicit flags: online=$online, connected=$connected, active=$active, isOnline=$isOnline, connectedToControl=$connectedToControl"

    if [[ "$online" == "true" || "$connected" == "true" || "$active" == "true" || "$isOnline" == "true" || "$connectedToControl" == "true" ]]; then
        debug_log "Device is online (Method 1: explicit flags)"
        return 0  # Online
    fi

    # Method 2: Check status/state fields
    local status state
    status=$(echo "$device_json" | jq -r '.status // ""')
    state=$(echo "$device_json" | jq -r '.state // ""')

    debug_log "Method 2 - Status fields: status=$status, state=$state"

    if [[ "$status" == "online" || "$status" == "connected" || "$status" == "active" ||
          "$state" == "online" || "$state" == "connected" || "$state" == "active" ]]; then
        debug_log "Device is online (Method 2: status/state fields)"
        return 0  # Online
    fi

    # Method 3: Check posture attributes
    local posture_online posture_connected posture_reachable
    posture_online=$(echo "$device_json" | jq -r '(.postureAttributes // {}).online // false')
    posture_connected=$(echo "$device_json" | jq -r '(.postureAttributes // {}).connected // false')
    posture_reachable=$(echo "$device_json" | jq -r '(.postureAttributes // {}).reachable // false')

    debug_log "Method 3 - Posture attributes: online=$posture_online, connected=$posture_connected, reachable=$posture_reachable"

    if [[ "$posture_online" == "true" || "$posture_connected" == "true" || "$posture_reachable" == "true" ]]; then
        debug_log "Device is online (Method 3: posture attributes)"
        return 0  # Online
    fi

    # Method 4: Check device capabilities or endpoints
    local endpoints_count capabilities_active
    endpoints_count=$(echo "$device_json" | jq -r '(.endpoints // []) | length')
    capabilities_active=$(echo "$device_json" | jq -r '(.capabilities // {}) | to_entries | any(.value == true) // false')

    debug_log "Method 4 - Capabilities: endpoints_count=$endpoints_count, capabilities_active=$capabilities_active"

    if [[ $endpoints_count -gt 0 || "$capabilities_active" == "true" ]]; then
        debug_log "Device is online (Method 4: endpoints/capabilities)"
        return 0  # Online
    fi

    # Method 5: Enhanced lastSeen analysis with authorization check
    local authorized last_seen expires
    authorized=$(echo "$device_json" | jq -r '.authorized // false')
    last_seen=$(echo "$device_json" | jq -r '.lastSeen // ""')
    expires=$(echo "$device_json" | jq -r '.expires // ""')

    debug_log "Method 5 - Time-based: authorized=$authorized, last_seen=$last_seen, expires=$expires"

    if [[ "$authorized" == "true" && -n "$last_seen" && "$last_seen" != "null" ]]; then
        if [[ -n "$expires" && "$expires" != "null" ]]; then
            # Device has expiring key - check if key is still valid
            local expires_unix current_unix
            expires_unix=$(date -d "$expires" +%s 2>/dev/null) || {
                debug_log "Failed to parse expires timestamp: $expires"
                return 1
            }
            current_unix=$(date +%s)

            if [[ $expires_unix -gt $current_unix ]]; then
                # Key is still valid, check recent activity (15 second threshold)
                if check_recent_activity "$last_seen" 15; then
                    debug_log "Device is online (Method 5: recent activity with valid expiring key)"
                    return 0  # Online
                fi
            else
                debug_log "Device key has expired"
            fi
        else
            # Permanent key - be more conservative (30 second threshold)
            if check_recent_activity "$last_seen" 30; then
                debug_log "Device is online (Method 5: recent activity with permanent key)"
                return 0  # Online
            fi
        fi
    fi

    debug_log "Device is offline (all methods failed)"
    return 1  # Offline
}

# Function to find and check device status by name prefix
check_device_status_by_prefix() {
    local devices_json="$1"
    local device_name_prefix="$2"

    debug_log "Looking for device with name prefix: $device_name_prefix"

    # First, let's validate the JSON structure
    if ! echo "$devices_json" | jq empty 2>/dev/null; then
        echo "❌ Invalid devices JSON structure" >&2
        debug_log "Invalid devices JSON: $devices_json"
        return 2
    fi

    # Show all device names for debugging
    if [[ "$DEBUG" == "1" ]]; then
        debug_log "All device names in response:"
        echo "$devices_json" | jq -r '.[] | {name: (.name // "null"), hostname: (.hostname // "null")}' >&2 || {
            debug_log "Failed to extract device names"
        }
    fi

    # Find device that starts with the specified prefix
    # Use -c flag to output compact JSON on a single line, then take first match
    local target_device
    target_device=$(echo "$devices_json" | jq -c --arg prefix "$device_name_prefix" '
        .[] | select(
            ((.name // "") | tostring | startswith($prefix)) or 
            ((.hostname // "") | tostring | startswith($prefix))
        )
    ' | head -n 1)

    if [[ -z "$target_device" ]]; then
        debug_log "No device found with prefix: $device_name_prefix"
        return 2  # Device not found
    fi

    debug_log "Found target device, checking online status"
    
    if [[ "$DEBUG" == "1" ]]; then
        local device_name
        device_name=$(echo "$target_device" | jq -r '.name // .hostname // "unknown"')
        debug_log "Target device name: $device_name"
        debug_log "Target device JSON: $target_device"
    fi

    # Check if device is online
    if check_device_online_status "$target_device"; then
        debug_log "Device is determined to be ONLINE"
        return 0  # Online
    else
        debug_log "Device is determined to be OFFLINE"
        return 1  # Offline
    fi
}

# Function to write Prometheus metrics
write_prometheus_metrics() {
    local status="$1"
    local device_name="${2:-unknown}"
    local metrics_file="/var/mnt/storage/sbin/tailscale_monitor/tailscale_conn_metrics.prom"
    local temp_file="/var/mnt/storage/sbin/tailscale_monitor/tailscale_conn_metrics.prom.$$"
    
    # Write to temp file
    cat > "$temp_file" << EOF
# HELP tailscale_device_connected Whether the Tailscale device is connected (1) or not (0)
# TYPE tailscale_device_connected gauge
tailscale_device_connected{device_name="$device_name"} $status

# HELP tailscale_check_timestamp_seconds Unix timestamp of when the check was performed
# TYPE tailscale_check_timestamp_seconds gauge
tailscale_check_timestamp_seconds $(date +%s)

# HELP tailscale_check_duration_seconds Time taken to perform the connectivity check
# TYPE tailscale_check_duration_seconds gauge
tailscale_check_duration_seconds $CHECK_DURATION
EOF

    # Atomic move
    mv "$temp_file" "$metrics_file"
}

# Main function
main() {
    local PROMETHEUS_OUTPUT=0
    local START_TIME=$(date +%s.%N)
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug|-d)
                DEBUG=1
                shift
                ;;
            --prometheus|-p)
                PROMETHEUS_OUTPUT=1
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -d, --debug      Enable debug output"
                echo "  -p, --prometheus Write metrics to /var/mnt/storage/sbin/tailscale_monitor/tailscale_conn_metrics.prom"
                echo "  -h, --help       Show this help message"
                echo ""
                echo "Environment variables:"
                echo "  TAILSCALE_CLIENT_ID     OAuth client ID"
                echo "  TAILSCALE_CLIENT_SECRET OAuth client secret"  
                echo "  TAILSCALE_TAILNET       Tailnet name"
                echo "  TAILSCALE_DEVICE_NAME   Device name prefix to search for (default: ghost-dev)"
                echo "  TAILSCALE_DEBUG         Set to 1 to enable debug output"
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done

    debug_log "Starting Tailscale device status check"

    # Ensure monitor directory exists on block storage (required for .env and metrics write)
    mkdir -p "/var/mnt/storage/sbin/tailscale_monitor"

    # Load .env file if it exists
    load_env_file || true

    # Load configuration with defaults and environment variable overrides
    local client_id="${TAILSCALE_CLIENT_ID:-$DEFAULT_CLIENT_ID}"
    local client_secret="${TAILSCALE_CLIENT_SECRET:-$DEFAULT_CLIENT_SECRET}"
    local tailnet="${TAILSCALE_TAILNET:-$DEFAULT_TAILNET}"
    local device_name_prefix="${TAILSCALE_DEVICE_NAME:-ghost-dev}"

    debug_log "Configuration: client_id=${client_id:0:10}..., tailnet=$tailnet, device_prefix=$device_name_prefix"

    # Check for missing configuration
    if [[ -z "$client_id" || -z "$client_secret" || -z "$tailnet" ]]; then
        echo "❌ Missing required configuration" >&2
        debug_log "Missing config - client_id: ${client_id:+set}, client_secret: ${client_secret:+set}, tailnet: ${tailnet:+set}"
        
        local end_time=$(date +%s.%N)
        CHECK_DURATION=$(echo "$end_time - $START_TIME" | bc -l 2>/dev/null || echo "0")
        
        if [[ "$PROMETHEUS_OUTPUT" == "1" ]]; then
            write_prometheus_metrics "0" "config_missing"
        fi
        echo "tailscale_connected 0"
        exit 0
    fi

    # Get OAuth access token
    if ! get_client_credentials_token "$client_id" "$client_secret"; then
        local end_time=$(date +%s.%N)
        CHECK_DURATION=$(echo "$end_time - $START_TIME" | bc -l 2>/dev/null || echo "0")
        
        if [[ "$PROMETHEUS_OUTPUT" == "1" ]]; then
            write_prometheus_metrics "0" "auth_failed"
        fi
        echo "tailscale_connected 0"
        exit 0
    fi

    # Get devices
    local devices
    if ! devices=$(get_devices "$tailnet"); then
        local end_time=$(date +%s.%N)
        CHECK_DURATION=$(echo "$end_time - $START_TIME" | bc -l 2>/dev/null || echo "0")
        
        if [[ "$PROMETHEUS_OUTPUT" == "1" ]]; then
            write_prometheus_metrics "0" "unknown"
        fi
        echo "tailscale_connected 0"
        exit 0
    fi

    # Check device status
    # Use || to prevent set -e from exiting on non-zero return codes (1=offline, 2=not found)
    local status_result=0 device_name="unknown"
    check_device_status_by_prefix "$devices" "$device_name_prefix" || status_result=$?
    
    # Extract device name for metrics if found
    if [[ $status_result != 2 ]]; then
        device_name=$(echo "$devices" | jq -c --arg prefix "$device_name_prefix" '
            .[] | select(
                ((.name // "") | tostring | startswith($prefix)) or 
                ((.hostname // "") | tostring | startswith($prefix))
            )
        ' | head -n 1 | jq -r '.hostname // .name // "unknown"' 2>/dev/null || echo "unknown")
    fi
    
    # Calculate check duration
    local end_time=$(date +%s.%N)
    CHECK_DURATION=$(echo "$end_time - $START_TIME" | bc -l 2>/dev/null || echo "0")

    case $status_result in
        0)
            debug_log "Final result: Device is ONLINE"
            if [[ "$PROMETHEUS_OUTPUT" == "1" ]]; then
                write_prometheus_metrics "1" "$device_name"
            fi
            echo "tailscale_connected 1"  # Device is online
            ;;
        1)
            debug_log "Final result: Device is OFFLINE"
            if [[ "$PROMETHEUS_OUTPUT" == "1" ]]; then
                write_prometheus_metrics "0" "$device_name"
            fi
            echo "tailscale_connected 0"  # Device is offline
            ;;
        2)
            debug_log "Final result: Device NOT FOUND"
            if [[ "$PROMETHEUS_OUTPUT" == "1" ]]; then
                write_prometheus_metrics "0" "not_found"
            fi
            echo "tailscale_connected 0"  # Device not found
            ;;
        *)
            debug_log "Final result: ERROR (code: $status_result)"
            if [[ "$PROMETHEUS_OUTPUT" == "1" ]]; then
                write_prometheus_metrics "0" "error"
            fi
            echo "tailscale_connected 0"  # Error case
            ;;
    esac
}

# Check dependencies
check_dependencies() {
    local missing_deps=()

    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi

    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi

    if ! command -v date >/dev/null 2>&1; then
        missing_deps+=("date")
    fi

    # bc is optional - only needed for precise duration calculation
    if ! command -v bc >/dev/null 2>&1; then
        debug_log "bc not available - duration calculation will be less precise"
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "❌ Missing required dependencies: ${missing_deps[*]}" >&2
        echo "💡 Install them with your package manager:" >&2
        echo "   Ubuntu/Debian: sudo apt install ${missing_deps[*]}" >&2
        echo "   CentOS/RHEL: sudo yum install ${missing_deps[*]}" >&2
        echo "   macOS: brew install ${missing_deps[*]}" >&2
        exit 1
    fi
}

# Run dependency check and main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_dependencies
    main "$@"
fi
