#!/bin/bash
set -euo pipefail

# Configuration
VERSION="1.10.2"
ARCHITECTURE="amd64"
SYSEXT_NAME="alloy"
DOWNLOAD_URL="https://github.com/grafana/alloy/releases/download/v${VERSION}/alloy-linux-${ARCHITECTURE}.zip"

echo "=== Building Grafana Alloy systemd-sysext v${VERSION} ==="

# Create build directory structure
BUILD_DIR="/build/${SYSEXT_NAME}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Download Alloy
echo "Downloading Alloy ${VERSION}..."
curl -L "${DOWNLOAD_URL}" -o "/tmp/alloy-${VERSION}.zip"

# Extract the zip file
echo "Extracting Alloy..."
unzip -q "/tmp/alloy-${VERSION}.zip" -d /tmp/alloy-extract

# Create sysext directory structure
echo "Creating sysext directory structure..."
mkdir -p "${BUILD_DIR}/usr/local/bin"
mkdir -p "${BUILD_DIR}/usr/lib/systemd/system"
mkdir -p "${BUILD_DIR}/usr/lib/extension-release.d"

# Copy Alloy binary
echo "Installing Alloy binary..."
cp /tmp/alloy-extract/alloy-linux-${ARCHITECTURE} "${BUILD_DIR}/usr/local/bin/alloy"
chmod +x "${BUILD_DIR}/usr/local/bin/alloy"

# Verify binary
echo "Verifying binary..."
file "${BUILD_DIR}/usr/local/bin/alloy"

# Create systemd service file
echo "Creating systemd service file..."
cat > "${BUILD_DIR}/usr/lib/systemd/system/alloy.service" << 'EOF'
[Unit]
Description=Grafana Alloy
Documentation=https://grafana.com/docs/alloy/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/alloy run /var/mnt/storage/alloy/config.alloy
Restart=on-failure
RestartSec=10s
TimeoutStopSec=20s

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/alloy /tmp
PrivateTmp=true

# State directory
StateDirectory=alloy
StateDirectoryMode=0750

# Working directory
WorkingDirectory=/var/lib/alloy

# Environment
Environment="HOSTNAME=%H"

[Install]
WantedBy=multi-user.target
EOF

# Create extension-release file
echo "Creating extension-release metadata..."
cat > "${BUILD_DIR}/usr/lib/extension-release.d/extension-release.${SYSEXT_NAME}" << EOF
ID=_any
ARCHITECTURE=x86-64
EOF

# Create the squashfs image
echo "Creating squashfs image..."
SYSEXT_IMAGE="/output/${SYSEXT_NAME}-${VERSION}-${ARCHITECTURE}.raw"
mksquashfs "${BUILD_DIR}" "${SYSEXT_IMAGE}" \
    -noappend \
    -comp xz \
    -Xdict-size 100% \
    -no-progress

# Create a version without architecture for compatibility
SYSEXT_IMAGE_NOARCH="/output/${SYSEXT_NAME}-${VERSION}.raw"
cp "${SYSEXT_IMAGE}" "${SYSEXT_IMAGE_NOARCH}"

# Generate checksums
echo "Generating checksums..."
cd /output
sha256sum "${SYSEXT_NAME}-${VERSION}-${ARCHITECTURE}.raw" > "${SYSEXT_NAME}-${VERSION}-${ARCHITECTURE}.raw.sha256"
sha256sum "${SYSEXT_NAME}-${VERSION}.raw" > "${SYSEXT_NAME}-${VERSION}.raw.sha256"

# Display information
echo ""
echo "=== Build Complete ==="
echo "Output files:"
ls -lh /output/
echo ""
echo "Image size:"
du -h "${SYSEXT_IMAGE}"
echo ""
echo "SHA256 checksums:"
cat /output/*.sha256

# Cleanup
rm -rf "${BUILD_DIR}"
rm -rf /tmp/alloy-extract
rm -f "/tmp/alloy-${VERSION}.zip"

echo ""
echo "=== Success! ==="
echo "Your systemd-sysext images are ready in the output directory."