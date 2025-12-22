# Configure the PagerDuty provider
terraform {
  required_providers {
    pagerduty = {
      source  = "pagerduty/pagerduty"
      version = "~> 3.30.7" # Mind the supported Provider version
    }
  }
}

# Create a PagerDuty user
resource "pagerduty_user" "noahwhite" {
  name            = "Noah White"
  email           = "noah@noahwhite.net"
  color           = "purple"
  job_title       = "Other"
  description     = "Mr. 1s and 0s"
  role            = "owner"
  license         = "PZDSDCM"
  time_zone       = "America/New_York"
}

resource "pagerduty_escalation_policy" "ghost-stack-dev-01-tailscale-ep" {
  name        = "ghost-stack-dev-01-tailscale-ep"
  description = "Managed by Terraform"
  num_loops   = 0
  teams       = []

  rule {
    escalation_delay_in_minutes = 30

    # escalation_rule_assignment_strategy {
    #   type = "assign_to_everyone"
    # }

    target {
      type = "user_reference"
      id   =  pagerduty_user.noahwhite.id
    }
  }

  rule {
    escalation_delay_in_minutes = 30

    # escalation_rule_assignment_strategy {
    #   type = "assign_to_everyone"
    # }

    target {
      type = "user_reference"
      id   =  pagerduty_user.noahwhite.id
    }
  }
}

resource "pagerduty_service" "ghost-stack-dev-01-tailscale" {
  name                    = "ghost-stack-dev-01-tailscale"
  description             = "Tailscale service on ghost-stack-dev-01"
  auto_resolve_timeout    = "null"
  acknowledgement_timeout = "600"
  escalation_policy       = pagerduty_escalation_policy.ghost-stack-dev-01-tailscale-ep.id
  alert_creation          = "create_alerts_and_incidents"

  auto_pause_notifications_parameters {
    enabled = true
    timeout = 300
  }

  incident_urgency_rule {
    type    = "constant"
    urgency = "severity_based"
  }
}

resource "pagerduty_service_integration" "ghost-stack-dev-01-tailscale_apiv2" {
  name            = "Events API V2"
  type            = "events_api_v2_inbound_integration"
  service         = pagerduty_service.ghost-stack-dev-01-tailscale.id
}

# data "pagerduty_vendor" "github" {
#   name  = "GitHub"
# }

resource "pagerduty_service_integration" "github" {
 name            = "GitHub"
 service         = pagerduty_service.ghost-stack-dev-01-tailscale.id
 vendor          = "PFZ9O9D"
}

# resource "pagerduty_slack_connection" "noahw" {
#  source_id         = pagerduty_service.ghost-stack-dev-01-tailscale.id
#  source_type       = "service_reference"
#  workspace_id      = "T0DQ8CG9L"
#  channel_id        = "C09HYEL5C9L"
#  notification_type = "responder"
#
#  config {
#    events     = [
#      "incident.acknowledged",
#      "incident.action_invocation.created",
#       "incident.action_invocation.terminated",
#       "incident.action_invocation.updated",
#       "incident.annotated",
#       "incident.delegated",
#       "incident.escalated",
#       "incident.incident_type.updated",
#       "incident.priority_updated",
#       "incident.reassigned",
#       "incident.reopened",
#       "incident.resolved",
#       "incident.responder.added",
#       "incident.responder.replied",
#       "incident.role.assigned",
#       "incident.status_update_published",
#       "incident.triggered",
#       "incident.unacknowledged",
#     ]
#     priorities = [
#       "*",
#     ]
#   }
# }

resource "pagerduty_business_service" "soc_blog" {
  name             = "Separation of Concerns Blog"
  description      = "Responsible for content on the Separation of Concerns blog"
  point_of_contact = "Noah White"
}

resource "pagerduty_service" "flatcar_instance" {
  name                    = "flatcar-instance"
  description             = "Flatcar instance hosting the ghost stack"
  auto_resolve_timeout    = "null"
  acknowledgement_timeout = "null"
  escalation_policy       = pagerduty_escalation_policy.ghost-stack-dev-01-tailscale-ep.id
  alert_creation          = "create_alerts_and_incidents"

  auto_pause_notifications_parameters {
    enabled = true
    timeout = 300
  }

  incident_urgency_rule {
    type    = "constant"
    urgency = "high"
  }
}

resource "pagerduty_service_integration" "flatcar_instance_apiv2" {
  name            = "Events API V2"
  type            = "events_api_v2_inbound_integration"
  service         = pagerduty_service.flatcar_instance.id
}

# resource "pagerduty_alert_grouping_setting" "gsd1ts_settings" {
#   name     = "ghost-stack-dev-01-tailscale"
#   services = [pagerduty_service.ghost-stack-dev-01-tailscale.id]
#   type     = "intelligent"
#
#   config {
#     iag_fields  = [
#       "summary",
#     ]
#     time_window = 300
#   }
# }

# resource "pagerduty_alert_grouping_setting" "fci_settings" {
#   name     = "flatcar-instance"
#   services = [pagerduty_service.flatcar_instance.id]
#   type     = "intelligent"
#
#   config {
#     iag_fields  = [
#       "summary",
#     ]
#     time_window = 300
#   }
# }

resource "pagerduty_service_dependency" "flatcar-gsd1ts-sd" {
  dependency {

    dependent_service {
      id   = pagerduty_service.ghost-stack-dev-01-tailscale.id
      type = "service"
    }
    supporting_service {
      id = pagerduty_service.flatcar_instance.id
      type = "service"
    }
  }
}

resource "pagerduty_service_dependency" "gsd1ts-soc_blog-sd" {

  dependency {
    type = "service_dependency"

    dependent_service {
      id = pagerduty_business_service.soc_blog.id
      type = "business_service"
    }
    supporting_service {
      id   = pagerduty_service.ghost-stack-dev-01-tailscale.id
      type = "service"
    }
  }
}

resource "pagerduty_schedule" "ghost-stack_dev" {
  name           = "ghost-stack dev"
  time_zone      = "America/New_York"
  description    = "On call schedule for monitoring the development Ghost stack environment"
  layer {
    name                         = "Primary"
    start                        = "2025-09-30T21:10:51-04:00"
    rotation_virtual_start       = "2025-09-30T21:00:00-04:00"
    rotation_turn_length_seconds = 604800
    users                        = [pagerduty_user.noahwhite.id]
  }
  teams          = []
}