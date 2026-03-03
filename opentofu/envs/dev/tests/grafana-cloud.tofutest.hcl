mock_provider "grafana" {
  mock_resource "grafana_cloud_stack" {
    defaults = {
      id  = "test-stack-id"
      url = "https://separationofconcerns0dev.grafana.net"
    }
  }

  mock_resource "grafana_cloud_stack_service_account" {
    defaults = {
      id = "test-service-account-id"
    }
  }

  mock_resource "grafana_folder" {
    defaults = {
      id  = "test-folder-id"
      uid = "test-folder-uid"
    }
  }

  mock_resource "grafana_folder_permission" {
    defaults = {
      id = "test-folder-permission-id"
    }
  }

  mock_resource "grafana_dashboard" {
    defaults = {
      id  = "test-dashboard-id"
      uid = "test-dashboard-uid"
    }
  }

  mock_resource "grafana_dashboard_permission" {
    defaults = {
      id = "test-dashboard-permission-id"
    }
  }

  mock_resource "grafana_contact_point" {
    defaults = {
      id   = "test-contact-point-id"
      name = "PagerDuty - Ghost Stack Backup"
    }
  }

  mock_resource "grafana_notification_policy" {
    defaults = {
      id = "test-notification-policy-id"
    }
  }

  mock_resource "grafana_rule_group" {
    defaults = {
      id = "test-rule-group-id"
    }
  }

  mock_data "grafana_data_source" {
    defaults = {
      id   = "test-datasource-id"
      name = "grafanacloud-separationofconcerns0dev-prom"
      type = "prometheus"
      uid  = "grafanacloud-prom"
    }
  }

  mock_data "grafana_dashboard" {
    defaults = {
      id  = "test-dashboard-id"
      uid = "test-dashboard-uid"
    }
  }
}

run "grafana_cloud_module_tests" {
  command = plan

  module {
    source = "../../modules/grafana-cloud"
  }

  variables {
    SOC_DEV_TERRAFORM_SA_TOK         = "test-token"
    pagerduty_backup_integration_key = "test-pd-integration-key"
  }

  # Override all data sources to prevent real API calls
  # Only override computed outputs, not input parameters
  override_data {
    target = data.grafana_data_source.soc_dev_prometheus
    values = {
      id   = "test-prometheus-id"
      uid  = "grafanacloud-prom"
      type = "prometheus"
      url  = "https://prometheus-test.grafana.net"
    }
  }

  override_data {
    target = data.grafana_data_source.soc_dev_loki
    values = {
      id   = "test-loki-id"
      uid  = "grafanacloud-logs"
      type = "loki"
      url  = "https://loki-test.grafana.net"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_card_mgmt
    values = {
      id          = "test-dashboard-1"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_card_mgmt_metrics
    values = {
      id          = "test-dashboard-2"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_card_mgmt_labels
    values = {
      id          = "test-dashboard-3"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_grafana_cloud_cloud_logs_exports_insights
    values = {
      id          = "test-dashboard-4"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_grafana_cloud_billing_usage
    values = {
      id          = "test-dashboard-5"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_grafana_cloud_usage_overview
    values = {
      id          = "test-dashboard-6"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_grafana_cloud_usage_data_sources
    values = {
      id          = "test-dashboard-7"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_grafana_cloud_usage_query_errors
    values = {
      id          = "test-dashboard-8"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_grafana_cloud_usage_alert_mgr
    values = {
      id          = "test-dashboard-9"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_grafana_cloud_usage_metrics_ingst
    values = {
      id          = "test-dashboard-10"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_grafana_cloud_usage_loki_dd
    values = {
      id          = "test-dashboard-11"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_grafana_cloud_alert_group_insights
    values = {
      id          = "test-dashboard-12"
      config_json = "{}"
    }
  }

  override_data {
    target = data.grafana_dashboard.soc_dev_grafana_cloud_incident_insights
    values = {
      id          = "test-dashboard-13"
      config_json = "{}"
    }
  }

  # Test cloud stack configuration
  assert {
    condition     = grafana_cloud_stack.soc_dev.name == "separationofconcerns0dev.grafana.net"
    error_message = "Cloud stack name should be separationofconcerns0dev.grafana.net"
  }

  assert {
    condition     = grafana_cloud_stack.soc_dev.region_slug == "prod-us-east-0"
    error_message = "Cloud stack should be in prod-us-east-0 region"
  }

  assert {
    condition     = grafana_cloud_stack.soc_dev.slug == "separationofconcerns0dev"
    error_message = "Cloud stack slug should be separationofconcerns0dev"
  }

  # Test service account
  assert {
    condition     = grafana_cloud_stack_service_account.terraform_sa.name == "sa-1-extsvc-grafana-terraform-app"
    error_message = "Service account name should be sa-1-extsvc-grafana-terraform-app"
  }

  assert {
    condition     = grafana_cloud_stack_service_account.terraform_sa.role == "None"
    error_message = "Service account role should be None"
  }

  assert {
    condition     = grafana_cloud_stack_service_account.terraform_sa.stack_slug == "separationofconcerns0dev"
    error_message = "Service account should be associated with separationofconcerns0dev stack"
  }

  assert {
    condition     = grafana_cloud_stack_service_account.terraform_sa.is_disabled == false
    error_message = "Service account should be enabled"
  }

  # Test tailscale folder
  assert {
    condition     = grafana_folder.tailscale_folder.title == "tailscale"
    error_message = "Tailscale folder title should be 'tailscale'"
  }

  # Test linux node folder
  assert {
    condition     = grafana_folder.integration_linux_node.title == "Integration - Linux Node"
    error_message = "Linux node folder title should be 'Integration - Linux Node'"
  }

  assert {
    condition     = grafana_folder.integration_linux_node.org_id == "0"
    error_message = "Linux node folder should be in org 0"
  }

  # Test folder permissions exist
  assert {
    condition     = grafana_folder_permission.soc_dev_tailscale_folder_permission.org_id == "0"
    error_message = "Tailscale folder permission should be in org 0"
  }

  assert {
    condition     = grafana_folder_permission.integration_linux_node.org_id == "0"
    error_message = "Linux node folder permission should be in org 0"
  }

  # Test tailscale dashboard exists

  assert {
    condition     = grafana_dashboard.soc_dev_tailscale_connection.config_json != null
    error_message = "Dashboard config should not be null"
  }

  assert {
    condition     = jsondecode(grafana_dashboard.soc_dev_tailscale_connection.config_json).title == "Ghost-Dev-01-TS-Connection"
    error_message = "Tailscale dashboard title should be 'Ghost-Dev-01-TS-Connection'"
  }

  assert {
    condition     = length(jsondecode(grafana_dashboard.soc_dev_tailscale_connection.config_json).panels) == 2
    error_message = "Tailscale dashboard should have 2 panels"
  }

  assert {
    condition     = jsondecode(grafana_dashboard.soc_dev_tailscale_connection.config_json).panels[0].type == "timeseries"
    error_message = "First panel should be a timeseries panel"
  }

  assert {
    condition     = jsondecode(grafana_dashboard.soc_dev_tailscale_connection.config_json).panels[1].type == "gauge"
    error_message = "Second panel should be a gauge panel"
  }

  assert {
    condition = (
      length(jsondecode(grafana_dashboard.soc_dev_tailscale_connection.config_json).panels[0].targets) > 0 &&
      strcontains(jsondecode(grafana_dashboard.soc_dev_tailscale_connection.config_json).panels[0].targets[0].expr, "tailscale_device_connected")
    )
    error_message = "Dashboard panels should query tailscale_device_connected metric"
  }

  assert {
    condition     = jsondecode(grafana_dashboard.soc_dev_tailscale_connection.config_json).editable == true
    error_message = "Dashboard should be editable"
  }

  # Test linux node dashboard exists

  assert {
    condition     = grafana_dashboard.soc_dev_linux_cpu_sys.config_json != null
    error_message = "Linux node dashboard config should not be null"
  }

  assert {
    condition     = length(jsondecode(grafana_dashboard.soc_dev_linux_cpu_sys.config_json).annotations.list) > 0
    error_message = "Linux node dashboard should have annotations configured"
  }

  assert {
    condition     = length(jsondecode(grafana_dashboard.soc_dev_linux_cpu_sys.config_json).panels) > 0
    error_message = "Linux node dashboard should have panels"
  }

  assert {
    condition     = length(jsondecode(grafana_dashboard.soc_dev_linux_cpu_sys.config_json).links) > 0
    error_message = "Linux node dashboard should have navigation links"
  }

  assert {
    condition     = jsondecode(grafana_dashboard.soc_dev_linux_cpu_sys.config_json).editable == false
    error_message = "Linux node integration dashboard should not be editable"
  }

  # Test dashboard permissions exist
  assert {
    condition     = grafana_dashboard_permission.soc_dev_tailscale_connection_permission.org_id == "0"
    error_message = "Dashboard permission should be in org 0"
  }

  # Test data source references (checking computed outputs only)
  assert {
    condition     = data.grafana_data_source.soc_dev_prometheus.uid == "grafanacloud-prom"
    error_message = "Prometheus data source should have correct UID"
  }

  assert {
    condition     = data.grafana_data_source.soc_dev_loki.uid == "grafanacloud-logs"
    error_message = "Loki data source should have correct UID"
  }

  # Test backup alerting resources (GHO-98)
  assert {
    condition     = grafana_contact_point.pagerduty_backup.name == "PagerDuty - Ghost Stack Backup"
    error_message = "Backup contact point name should be 'PagerDuty - Ghost Stack Backup'"
  }

  assert {
    condition     = grafana_rule_group.ghost_stack_backup.name == "Ghost Stack Backup"
    error_message = "Alert rule group name should be 'Ghost Stack Backup'"
  }

  assert {
    condition     = grafana_rule_group.ghost_stack_backup.interval_seconds == 300
    error_message = "Alert rule group should evaluate every 300 seconds"
  }

  assert {
    condition     = length(grafana_rule_group.ghost_stack_backup.rule) == 3
    error_message = "Alert rule group should have 3 rules"
  }

  assert {
    condition     = grafana_folder.ghost_stack_folder.title == "Ghost Stack"
    error_message = "Ghost Stack folder title should be 'Ghost Stack'"
  }

  assert {
    condition     = grafana_dashboard.ghost_stack_backup.config_json != null
    error_message = "Backup dashboard config should not be null"
  }

  assert {
    condition     = jsondecode(grafana_dashboard.ghost_stack_backup.config_json).title == "Ghost Stack Backup"
    error_message = "Backup dashboard title should be 'Ghost Stack Backup'"
  }
}
