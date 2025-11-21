terraform {
  required_version = ">= 1.0"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.11.0"
    }
  }
}

# Grafana Cloud Organization
data "grafana_organization" "current" {
  count = var.organization_id != null ? 1 : 0
  id    = var.organization_id
}

# Dashboards
resource "grafana_dashboard" "dashboards" {
  for_each = var.dashboards

  config_json = jsonencode(each.value.config)
  folder      = each.value.folder_id
  overwrite   = try(each.value.overwrite, true)

  dynamic "message" {
    for_each = try(each.value.message, null) != null ? [1] : []
    content {
      message = each.value.message
    }
  }
}

# Folders
resource "grafana_folder" "folders" {
  for_each = var.folders

  title = each.value.title
  uid   = try(each.value.uid, null)
}

# Alert Rules
resource "grafana_rule_group" "alert_groups" {
  for_each = var.alert_rule_groups

  name             = each.value.name
  folder_uid       = each.value.folder_uid
  interval_seconds = try(each.value.interval_seconds, 60)
  org_id           = try(each.value.org_id, null)

  dynamic "rule" {
    for_each = each.value.rules
    content {
      name      = rule.value.name
      condition = rule.value.condition

      data {
        ref_id     = rule.value.data.ref_id
        query_type = try(rule.value.data.query_type, "")

        relative_time_range {
          from = rule.value.data.relative_time_range.from
          to   = rule.value.data.relative_time_range.to
        }

        datasource_uid = rule.value.data.datasource_uid
        model          = jsonencode(rule.value.data.model)
      }

      no_data_state  = try(rule.value.no_data_state, "NoData")
      exec_err_state = try(rule.value.exec_err_state, "Alerting")

      for = try(rule.value.for_duration, "5m")

      annotations = try(rule.value.annotations, {})
      labels      = try(rule.value.labels, {})
    }
  }
}

# Contact Points
resource "grafana_contact_point" "contact_points" {
  for_each = var.contact_points

  name = each.value.name

  dynamic "email" {
    for_each = try(each.value.email, null) != null ? [each.value.email] : []
    content {
      addresses               = email.value.addresses
      single_email            = try(email.value.single_email, false)
      message                 = try(email.value.message, null)
      subject                 = try(email.value.subject, null)
      disable_resolve_message = try(email.value.disable_resolve_message, false)
    }
  }

  dynamic "slack" {
    for_each = try(each.value.slack, null) != null ? [each.value.slack] : []
    content {
      url                     = slack.value.url
      text                    = try(slack.value.text, null)
      title                   = try(slack.value.title, null)
      username                = try(slack.value.username, null)
      disable_resolve_message = try(slack.value.disable_resolve_message, false)
    }
  }

  dynamic "webhook" {
    for_each = try(each.value.webhook, null) != null ? [each.value.webhook] : []
    content {
      url                     = webhook.value.url
      http_method             = try(webhook.value.http_method, "POST")
      basic_auth_user         = try(webhook.value.basic_auth_user, null)
      basic_auth_password     = try(webhook.value.basic_auth_password, null)
      disable_resolve_message = try(webhook.value.disable_resolve_message, false)
    }
  }
}

# Notification Policies
resource "grafana_notification_policy" "policy" {
  count = var.notification_policy != null ? 1 : 0

  group_by      = try(var.notification_policy.group_by, ["alertname"])
  contact_point = var.notification_policy.contact_point

  group_wait      = try(var.notification_policy.group_wait, "30s")
  group_interval  = try(var.notification_policy.group_interval, "5m")
  repeat_interval = try(var.notification_policy.repeat_interval, "4h")

  dynamic "policy" {
    for_each = try(var.notification_policy.policies, [])
    content {
      matcher {
        label = policy.value.matcher.label
        match = policy.value.matcher.match
        value = policy.value.matcher.value
      }

      group_by       = try(policy.value.group_by, ["alertname"])
      contact_point  = policy.value.contact_point
      continue       = try(policy.value.continue, false)
      mute_timings   = try(policy.value.mute_timings, [])
      group_wait     = try(policy.value.group_wait, null)
      group_interval = try(policy.value.group_interval, null)
      repeat_interval = try(policy.value.repeat_interval, null)
    }
  }
}

# Data Sources
resource "grafana_data_source" "data_sources" {
  for_each = var.data_sources

  type = each.value.type
  name = each.value.name
  url  = try(each.value.url, null)

  basic_auth_enabled  = try(each.value.basic_auth_enabled, false)
  basic_auth_username = try(each.value.basic_auth_username, null)

  json_data_encoded = try(each.value.json_data_encoded, null)

  secure_json_data_encoded = try(each.value.secure_json_data_encoded, null)
}