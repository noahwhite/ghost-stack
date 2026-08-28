variable "PD_CLIENT_ID" {
  description = "Pagerduty OAUTH client id"
  type        = string
  sensitive   = true
}

variable "PD_CLIENT_SECRET" {
  description = "Pagerduty client secret"
  type        = string
  sensitive   = true
}

variable "pd_subdomain" {
  description = "Pagerduty subdomain"
  type        = string
}

variable "pd_user_tok" {
  description = "Pagerduty user token"
  type        = string
  sensitive   = true
}

variable "GC_ACCESS_TOK" {
  description = "Grafana Cloud access token"
  type        = string
  sensitive   = true
}

variable "SOC_DEV_TERRAFORM_SA_TOK" {
  description = "Grafana Cloud SOC DEV Service Account Token"
  type        = string
  sensitive   = true
}

variable "health_check_token" {
  description = "Token for X-Health-Check-Token header used by Grafana synthetic health check probes"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID (optional, reads from bootstrap state if not provided)"
  type        = string
  default     = ""
}

# ==========================================================================
# Infisical Provider (management identity credentials)
# ==========================================================================

variable "infisical_client_id" {
  description = "Infisical management identity client ID (used by OpenTofu to manage Infisical resources)"
  type        = string
  sensitive   = true
}

variable "infisical_client_secret" {
  description = "Infisical management identity client secret"
  type        = string
  sensitive   = true
}

variable "infisical_org_id" {
  description = "Infisical organization ID"
  type        = string
}
