variable "SOC_DEV_TERRAFORM_SA_TOK" {
  description = "Grafana Cloud SOC DEV Service Account Token"
  type        = string
  sensitive   = true
}

variable "pagerduty_backup_integration_key" {
  description = "PagerDuty Events API V2 integration key for the Ghost Stack backup service"
  type        = string
  sensitive   = true
}

variable "metrics_publisher_key" {
  description = "Grafana Cloud access policy token for Synthetic Monitoring (requires stacks:read, metrics:write, logs:write, traces:write scopes)"
  type        = string
  sensitive   = true
}

variable "pagerduty_health_check_integration_key" {
  description = "PagerDuty Events API V2 integration key for the Ghost Stack health check service"
  type        = string
  sensitive   = true
}

variable "health_check_token" {
  description = "Token for X-Health-Check-Token header used by tenant health check probes"
  type        = string
  sensitive   = true
}

variable "tenant_domain" {
  description = "Tenant domain for health check probes (e.g., separationofconcerns.dev)"
  type        = string
}
