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