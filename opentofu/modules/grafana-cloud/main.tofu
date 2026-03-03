terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 4.20.1"
    }
  }
}

resource "grafana_cloud_stack" "soc_dev" {
  name        = "separationofconcerns0dev.grafana.net"
  region_slug = "prod-us-east-0"
  slug        = "separationofconcerns0dev"
}

# Associated service account and service account token were created manually in the dashboard and the
# token is securely injected.
provider "grafana" {
  alias = "soc_dev"

  url  = grafana_cloud_stack.soc_dev.url
  auth = var.SOC_DEV_TERRAFORM_SA_TOK
}

resource "grafana_cloud_stack_service_account" "terraform_sa" {
  name        = "sa-1-extsvc-grafana-terraform-app"
  role        = "None"
  stack_slug  = "separationofconcerns0dev"
  is_disabled = false
}

# Grant the terraform SA access to the alerting provisioning API (required by
# grafana_rule_group, grafana_contact_point, grafana_notification_policy).
# fixed:alerting:writer covers the regular alerting API but not /v1/provisioning/*.
#
# SA numeric ID (19) is hardcoded: grafana_cloud_stack_service_account does not
# export a usable instance-level ID attribute, and the SA predates full IaC
# management of its role assignments.
resource "grafana_role_assignment" "terraform_sa_alerting_provisioning" {
  provider         = grafana.soc_dev
  role_uid         = "fixed:alerting.provisioning:writer"
  service_accounts = ["19"]
}

resource "grafana_folder" "tailscale_folder" {
  provider = grafana.soc_dev
  title    = "tailscale"
}

resource "grafana_folder_permission" "soc_dev_tailscale_folder_permission" {
  provider   = grafana.soc_dev
  folder_uid = grafana_folder.tailscale_folder.uid
  org_id     = "0"

  permissions {
    permission = "Edit"
    role       = "Editor"
  }
  permissions {
    permission = "View"
    role       = "Viewer"
  }
}

resource "grafana_dashboard" "soc_dev_tailscale_connection" {
  provider = grafana.soc_dev
  folder   = grafana_folder.tailscale_folder.id
  config_json = jsonencode({
    annotations = {
      list = [
        {
          builtIn = 1
          datasource = {
            type = "grafana"
            uid  = "-- Grafana --"
          }
          enable    = true
          hide      = true
          iconColor = "rgba(0, 211, 255, 1)"
          name      = "Annotations & Alerts"
          type      = "dashboard"
        },
      ]
    }
    editable             = true
    fiscalYearStartMonth = 0
    graphTooltip         = 0
    links                = []
    panels = [
      {
        datasource = {
          type = "prometheus"
          uid  = "grafanacloud-prom"
        }
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              axisBorderShow   = false
              axisCenteredZero = false
              axisColorMode    = "text"
              axisLabel        = ""
              axisPlacement    = "auto"
              barAlignment     = 0
              barWidthFactor   = 0.6
              drawStyle        = "line"
              fillOpacity      = 0
              gradientMode     = "none"
              hideFrom = {
                legend  = false
                tooltip = false
                viz     = false
              }
              insertNulls       = false
              lineInterpolation = "linear"
              lineWidth         = 1
              pointSize         = 5
              scaleDistribution = {
                type = "linear"
              }
              showPoints = "auto"
              showValues = false
              spanNulls  = false
              stacking = {
                group = "A"
                mode  = "none"
              }
              thresholdsStyle = {
                mode = "off"
              }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "green"
                  value = 0
                },
                {
                  color = "red"
                  value = 80
                },
              ]
            }
          }
          overrides = []
        }
        gridPos = {
          h = 8
          w = 12
          x = 0
          y = 0
        }
        options = {
          legend = {
            calcs       = []
            displayMode = "list"
            placement   = "bottom"
            showLegend  = true
          }
          tooltip = {
            hideZeros = false
            mode      = "single"
            sort      = "none"
          }
        }
        pluginVersion = "12.2.0-17638611789.patch2"
        targets = [
          {
            editorMode   = "builder"
            expr         = "tailscale_device_connected{device_name=\"ghost-dev-01\"}"
            legendFormat = "__auto"
            range        = true
            refId        = "A"
          },
        ]
        title = "ghost-dev-01 connected series"
        type  = "timeseries"
      },
      {
        datasource = {
          type = "prometheus"
          uid  = "grafanacloud-prom"
        }
        fieldConfig = {
          defaults = {
            color = {
              mode = "thresholds"
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "dark-red"
                  value = 0
                },
                {
                  color = "dark-green"
                  value = 1
                },
              ]
            }
            unit = "bool_on_off"
          }
          overrides = []
        }
        gridPos = {
          h = 8
          w = 12
          x = 0
          y = 8
        }
        options = {
          minVizHeight = 75
          minVizWidth  = 75
          orientation  = "auto"
          reduceOptions = {
            calcs = [
              "lastNotNull",
            ]
            fields = ""
            values = false
          }
          showThresholdLabels  = false
          showThresholdMarkers = true
          sizing               = "auto"
        }
        pluginVersion = "12.2.0-17638611789.patch2"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid  = "grafanacloud-prom"
            }
            editorMode   = "builder"
            expr         = "tailscale_device_connected{device_name=\"ghost-dev-01\"}"
            legendFormat = "__auto"
            range        = true
            refId        = "A"
          },
        ]
        title = "ghost-dev-1 tailscale connection status"
        type  = "gauge"
      },
    ]
    preload       = false
    schemaVersion = 42
    tags          = []
    templating = {
      list = []
    }
    time = {
      from = "2025-09-30T00:08:08.411Z"
      to   = "2025-09-30T02:25:47.235Z"
    }
    timepicker = {}
    timezone   = "browser"
    title      = "Ghost-Dev-01-TS-Connection"
    uid        = "nodlbz4"
  })
}

resource "grafana_dashboard_permission" "soc_dev_tailscale_connection_permission" {
  provider      = grafana.soc_dev
  dashboard_uid = grafana_dashboard.soc_dev_tailscale_connection.uid
  org_id        = "0"
}

resource "grafana_folder" "integration_linux_node" {
  provider = grafana.soc_dev
  org_id   = "0"
  title    = "Integration - Linux Node"
}

resource "grafana_folder_permission" "integration_linux_node" {
  provider   = grafana.soc_dev
  folder_uid = grafana_folder.integration_linux_node.uid
  org_id     = "0"

  permissions {
    permission = "Edit"
    role       = "Editor"
  }
  permissions {
    permission = "View"
    role       = "Viewer"
  }
}

data "grafana_data_source" "soc_dev_prometheus" {
  provider = grafana.soc_dev
  name     = "grafanacloud-separationofconcerns0dev-prom"
}

data "grafana_data_source" "soc_dev_loki" {
  provider = grafana.soc_dev
  name     = "grafanacloud-separationofconcerns0dev-logs"
}

resource "grafana_dashboard" "soc_dev_linux_cpu_sys" {
  provider = grafana.soc_dev
  folder   = grafana_folder.integration_linux_node.id
  config_json = jsonencode(
    {
      annotations = {
        list = [
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", transport=\"kernel\", level=\"emerg\"}"
            hide        = true
            iconColor   = "light-purple"
            name        = "Critical system event"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Critical system event"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = <<-EOT
                            changes(
                            sum by (instance) (
                                group by (instance,release) (node_uname_info{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                )
                            [$__interval:1m] offset -$__interval) > 1
                        EOT
            hide        = true
            iconColor   = "light-blue"
            name        = "Kernel update"
            step        = "5m"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "Kernel update"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = "increase(node_vmstat_oom_kill{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__interval:] offset -$__interval)"
            hide        = true
            iconColor   = "light-purple"
            name        = "OOMkill"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "OOMkill"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable          = true
            expr            = "node_boot_time_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}*1000 > $__from < $__to"
            hide            = true
            iconColor       = "light-yellow"
            name            = "Reboot"
            tagKeys         = "cluster,job,instance"
            titleFormat     = "Reboot"
            useValueForTime = "on"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"init.scope\"} |= \"code=exited, status=1/FAILURE\""
            hide        = true
            iconColor   = "light-orange"
            name        = "Service failed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Service failed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session closed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session closed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session opened"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session opened"
          },
        ]
      }
      editable = false
      links = [
        {
          keepTime = true
          title    = "Back to Linux node / fleet"
          type     = "link"
          url      = "/d/node-fleet"
        },
        {
          keepTime = true
          title    = "Back to Linux node / overview"
          type     = "link"
          url      = "/d/nodes"
        },
        {
          asDropdown  = true
          includeVars = true
          keepTime    = true
          tags = [
            "linux-node-integration",
          ]
          title = "All Linux node /  dashboards"
          type  = "dashboards"
        },
      ]
      panels = [
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 0
          }
          panels = []
          title  = "System"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Total CPU utilization percent is a metric that indicates the overall level of central processing unit (CPU) usage in a computer system.
                        It represents the combined load placed on all CPU cores or processors.

                        For instance, if the total CPU utilization percent is 50%, it means that,
                        on average, half of the CPU's processing capacity is being used to execute tasks. A higher percentage indicates that the CPU is working more intensively, potentially leading to system slowdowns if it remains consistently high.
                    EOT
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "continuous-BlYlRd"
              }
              decimals = 1
              max      = 100
              min      = 0
              unit     = "percent"
            }
          }
          gridPos = {
            h = 6
            w = 6
            x = 0
            y = 1
          }
          options = {
            colorMode = "value"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                (((count by (instance) (count(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) by (cpu, instance)))
                                -
                                sum by (instance) (sum by (instance, mode)(irate(node_cpu_seconds_total{mode=~'idle|iowait|steal',job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])))) * 100)
                                /
                                count by(instance) (count(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) by (cpu, instance))
                            EOT
              legendFormat = "CPU usage"
            },
          ]
          title = "CPU usage"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Total CPU utilization percent is a metric that indicates the overall level of central processing unit (CPU) usage in a computer system.
                        It represents the combined load placed on all CPU cores or processors.

                        For instance, if the total CPU utilization percent is 50%, it means that,
                        on average, half of the CPU's processing capacity is being used to execute tasks. A higher percentage indicates that the CPU is working more intensively, potentially leading to system slowdowns if it remains consistently high.
                    EOT
          fieldConfig = {
            defaults = {
              color = {
                mode = "continuous-BlYlRd"
              }
              custom = {
                fillOpacity       = 30
                gradientMode      = "scheme"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              max      = 100
              min      = 0
              unit     = "percent"
            }
          }
          gridPos = {
            h = 6
            w = 9
            x = 6
            y = 1
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                (100 - sum without (mode) (rate(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance", mode=~"idle|iowait|steal"}[$__rate_interval])) * 100 )
                            EOT
              legendFormat = "CPU {{cpu}}"
            },
          ]
          title = "CPU usage"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        - System: Processes executing in kernel mode.
                        - User: Normal processes executing in user mode.
                        - Nice: Niced processes executing in user mode.
                        - Idle: Waiting for something to happen.
                        - Iowait: Waiting for I/O to complete.
                        - Irq: Servicing interrupts.
                        - Softirq: Servicing softirqs.
                        - Steal: Time spent in other operating systems when running in a virtualized environment.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 80
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
                stacking = {
                  mode = "normal"
                }
              }
              max  = 100
              min  = 0
              unit = "percent"
            }
            overrides = [
              {
                matcher = {
                  id      = "byName"
                  options = "idle"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-blue"
                      mode       = "fixed"
                    }
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "interrupt"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-purple"
                      mode       = "fixed"
                    }
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "user"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "system|privileged"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-red"
                      mode       = "fixed"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 6
            w = 9
            x = 15
            y = 1
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                sum by(instance, mode) (irate(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval]))
                                / on(instance)
                                group_left sum by (instance)((irate(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval]))) * 100
                            EOT
              legendFormat = "{{ mode }}"
            },
          ]
          title = "CPU usage by modes"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        System load average over the previous 1, 5, and 15 minute ranges.

                        A measurement of how many processes are waiting for CPU cycles. The maximum number is the number of CPU cores for the node.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 0
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "short"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "Cores"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 7
            w = 12
            x = 0
            y = 8
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_load1{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "1m"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_load5{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "5m"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_load15{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "15m"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "count without (cpu) (node_cpu_seconds_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", mode=\"idle\"})"
              legendFormat = "Cores"
            },
          ]
          title = "Load average"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Context switches occur when the operating system switches from running one process to another. Interrupts are signals sent to the CPU by external devices to request its attention.

                        A high number of context switches or interrupts can indicate that the system is overloaded or that there are problems with specific devices or processes.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
            }
          }
          gridPos = {
            h = 7
            w = 12
            x = 12
            y = 8
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_context_switches_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "Context switches"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_intr_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "Interrupts"
            },
          ]
          title = "Context switches/Interrupts"
          type  = "timeseries"
        },
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 15
          }
          panels = []
          title  = "Time"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Current system timezone."
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
            }
          }
          gridPos = {
            h = 4
            w = 3
            x = 0
            y = 16
          }
          options = {
            colorMode = "fixed"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
              fields = "/^time_zone$/"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr   = "node_time_zone_offset_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format = "table"
            },
          ]
          title = "Timezone"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Status of time synchronization."
          fieldConfig = {
            defaults = {
              color = {
                mode = "fixed"
              }
              mappings = [
                {
                  options = {
                    "0" = {
                      color = "light-yellow"
                      index = 1
                      text  = "Not in sync"
                    }
                    "1" = {
                      color = "light-green"
                      index = 0
                      text  = "In sync"
                    }
                  }
                  type = "value"
                },
              ]
              noValue = "No data."
            }
          }
          gridPos = {
            h = 4
            w = 21
            x = 3
            y = 16
          }
          maxDataPoints = 50
          options = {
            legend = false
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_timex_sync_status{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "NTP status"
            },
          ]
          title = "NTP status"
          type  = "status-history"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Time synchronization is essential to ensure accurate timekeeping, which is critical for many system operations such as logging, authentication, and network communication, as well as distributed systems or clusters where data consistency is important.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              noValue = "No data."
              unit    = "s"
            }
          }
          gridPos = {
            h = 7
            w = 24
            x = 0
            y = 23
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_timex_estimated_error_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Estimated error in seconds"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_timex_offset_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Time offset"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_timex_maxerror_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Maximum error in seconds"
            },
          ]
          title = "Time synchronized drift"
          type  = "timeseries"
        },
      ]
      refresh       = "30s"
      schemaVersion = 39
      tags = [
        "linux-node-integration",
      ]
      templating = {
        list = [
          {
            label = "Prometheus data source"
            name  = "prometheus_datasource"
            query = "prometheus"
            regex = "(?!grafanacloud-usage|grafanacloud-ml-metrics).+"
            type  = "datasource"
          },
          {
            allValue = ".*"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Cluster"
            multi      = true
            name       = "cluster"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\"}, cluster)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Job"
            multi      = true
            name       = "job"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\"}, job)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = false
            label      = "Instance"
            multi      = false
            name       = "instance"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\"}, instance)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            hide  = 2
            label = "Loki data source"
            name  = "loki_datasource"
            query = "loki"
            regex = "(?!grafanacloud.+usage-insights|grafanacloud.+alert-state-history).+"
            type  = "datasource"
          },
        ]
      }
      time = {
        from = "now-30m"
        to   = "now"
      }
      timezone = "default"
      title    = "Linux node / CPU and system"
      uid      = "node-system"
    }
  )
}

resource "grafana_dashboard" "soc_dev_linux_fs_disk" {
  provider = grafana.soc_dev
  folder   = grafana_folder.integration_linux_node.id
  config_json = jsonencode(
    {
      annotations = {
        list = [
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", transport=\"kernel\", level=\"emerg\"}"
            hide        = true
            iconColor   = "light-purple"
            name        = "Critical system event"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Critical system event"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = <<-EOT
                            changes(
                            sum by (instance) (
                                group by (instance,release) (node_uname_info{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                )
                            [$__interval:1m] offset -$__interval) > 1
                        EOT
            hide        = true
            iconColor   = "light-blue"
            name        = "Kernel update"
            step        = "5m"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "Kernel update"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = "increase(node_vmstat_oom_kill{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__interval:] offset -$__interval)"
            hide        = true
            iconColor   = "light-purple"
            name        = "OOMkill"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "OOMkill"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable          = true
            expr            = "node_boot_time_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}*1000 > $__from < $__to"
            hide            = true
            iconColor       = "light-yellow"
            name            = "Reboot"
            tagKeys         = "cluster,job,instance"
            titleFormat     = "Reboot"
            useValueForTime = "on"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"init.scope\"} |= \"code=exited, status=1/FAILURE\""
            hide        = true
            iconColor   = "light-orange"
            name        = "Service failed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Service failed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session closed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session closed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session opened"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session opened"
          },
        ]
      }
      editable = false
      links = [
        {
          keepTime = true
          title    = "Back to Linux node / fleet"
          type     = "link"
          url      = "/d/node-fleet"
        },
        {
          keepTime = true
          title    = "Back to Linux node / overview"
          type     = "link"
          url      = "/d/nodes"
        },
        {
          asDropdown  = true
          includeVars = true
          keepTime    = true
          tags = [
            "linux-node-integration",
          ]
          title = "All Linux node /  dashboards"
          type  = "dashboards"
        },
      ]
      panels = [
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 0
          }
          panels = []
          title  = "Filesystem"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Filesystem space utilisation in bytes, by mountpoint."
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 1
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 1
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_filesystem_avail_bytes{fstype!=\"\", mountpoint!=\"\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "{{ mountpoint }} free"
            },
          ]
          title = "Filesystem space availabe"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Disk utilisation in percent, by mountpoint. Some duplication can occur if the same filesystem is mounted in multiple locations."
          fieldConfig = {
            defaults = {
              thresholds = {
                steps = [
                  {
                    color = "light-blue"
                    value = null
                  },
                  {
                    color = "light-yellow"
                    value = 0.8
                  },
                  {
                    color = "light-red"
                    value = 0.9
                  },
                ]
              }
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byName"
                  options = "Mounted on"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 260
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Size"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 80
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Used"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 80
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Available"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 80
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Used, %"
                }
                properties = [
                  {
                    id = "custom.cellOptions"
                    value = {
                      mode             = "basic"
                      type             = "gauge"
                      valueDisplayMode = "text"
                    }
                  },
                  {
                    id    = "max"
                    value = 1
                  },
                  {
                    id    = "min"
                    value = 0
                  },
                  {
                    id    = "unit"
                    value = "percentunit"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 1
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "node_filesystem_size_bytes{fstype!=\"\", mountpoint!=\"\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format  = "table"
              instant = true
              refId   = "TOTAL"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_filesystem_avail_bytes{fstype!=\"\", mountpoint!=\"\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format       = "table"
              instant      = true
              legendFormat = "{{ mountpoint }} free"
              refId        = "FREE"
            },
          ]
          title = "Disk space usage"
          transformations = [
            {
              id = "groupBy"
              options = {
                fields = {
                  "Value #FREE" = {
                    aggregations = [
                      "lastNotNull",
                    ]
                    operation = "aggregate"
                  }
                  "Value #TOTAL" = {
                    aggregations = [
                      "lastNotNull",
                    ]
                    operation = "aggregate"
                  }
                  mountpoint = {
                    aggregations = []
                    operation    = "groupby"
                  }
                }
              }
            },
            {
              id      = "merge"
              options = {}
            },
            {
              id = "calculateField"
              options = {
                alias = "Used"
                binary = {
                  left     = "Value #TOTAL (lastNotNull)"
                  operator = "-"
                  reducer  = "sum"
                  right    = "Value #FREE (lastNotNull)"
                }
                mode = "binary"
                reduce = {
                  reducer = "sum"
                }
              }
            },
            {
              id = "calculateField"
              options = {
                alias = "Used, %"
                binary = {
                  left     = "Used"
                  operator = "/"
                  reducer  = "sum"
                  right    = "Value #TOTAL (lastNotNull)"
                }
                mode = "binary"
                reduce = {
                  reducer = "sum"
                }
              }
            },
            {
              id = "organize"
              options = {
                excludeByName = {}
                indexByName = {
                  Used                         = 3
                  "Used, %"                    = 4
                  "Value #FREE (lastNotNull)"  = 2
                  "Value #TOTAL (lastNotNull)" = 1
                  mountpoint                   = 0
                }
                renameByName = {
                  "Value #FREE (lastNotNull)"  = "Available"
                  "Value #TOTAL (lastNotNull)" = "Size"
                  mountpoint                   = "Mounted on"
                }
              }
            },
            {
              id = "sortBy"
              options = {
                fields = {}
                sort = [
                  {
                    desc  = false
                    field = "Mounted on"
                  },
                ]
              }
            },
          ]
          type = "table"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "The inode is a data structure in a Unix-style file system that describes a file-system object such as a file or a directory."
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 1
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              unit = "short"
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 9
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_filesystem_files_free{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", fstype!=\"\", mountpoint!=\"\"}"
              legendFormat = "{{ mountpoint }} inodes free"
            },
          ]
          title = "Free inodes"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "The inode is a data structure in a Unix-style file system that describes a file-system object such as a file or a directory."
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 1
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              unit = "short"
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 9
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_filesystem_files{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", fstype!=\"\", mountpoint!=\"\"}"
              legendFormat = "{{ mountpoint }} inodes total"
            },
          ]
          title = "Total inodes"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = ""
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 1
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              max = 1
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 17
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_filesystem_device_error{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", fstype!=\"\", mountpoint!=\"\"}"
              legendFormat = "{{ mountpoint }} device error"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_filesystem_readonly{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", fstype!=\"\", mountpoint!=\"\"}"
              legendFormat = "{{ mountpoint }} read-only"
            },
          ]
          title = "Filesystems with errors / read-only"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        File descriptor is a handle to an open file or input/output (I/O) resource, such as a network socket or a pipe.
                        The operating system uses file descriptors to keep track of open files and I/O resources, and provides a way for programs to read from and write to them.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 1
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 17
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "process_max_fds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Maximum open file descriptors"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "process_open_fds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Open file descriptors"
            },
          ]
          title = "File descriptors"
          type  = "timeseries"
        },
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 25
          }
          panels = []
          title  = "Disk"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Disk read/writes in bytes per second."
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 1
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              unit = "Bps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/time|used|busy|util/"
                }
                properties = [
                  {
                    id    = "custom.axisSoftMax"
                    value = 100
                  },
                  {
                    id    = "custom.drawStyle"
                    value = "points"
                  },
                  {
                    id    = "unit"
                    value = "percent"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 26
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_disk_read_bytes_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", device!=\"\"}[$__rate_interval])"
              legendFormat = "{{ device }} read"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_disk_written_bytes_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", device!=\"\"}[$__rate_interval])"
              legendFormat = "{{ device }} written"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_disk_io_time_seconds_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", device!=\"\"}[$__rate_interval])"
              legendFormat = "{{ device }} io util"
            },
          ]
          title = "Disk reads/writes"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        The number of I/O requests per second for the device/volume.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = true
                axisLabel         = "write(-) | read(+)"
                fillOpacity       = 1
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              unit = "iops"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/write|written/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 26
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                irate(node_disk_reads_completed_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance", device!=""}[$__rate_interval])
                            EOT
              legendFormat = "{{ device }} reads"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                irate(node_disk_writes_completed_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance", device!=""}[$__rate_interval])
                            EOT
              legendFormat = "{{ device }} writes"
            },
          ]
          title = "Disk I/O"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        The average time for requests issued to the device to be served.
                        This includes the time spent by the requests in queue and the time spent servicing them.'
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = true
                axisLabel         = "write(-) | read(+)"
                fillOpacity       = 1
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              unit = "s"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/write|written/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 34
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                irate(node_disk_read_time_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance", device!=""}[$__rate_interval])
                                /
                                irate(node_disk_reads_completed_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance", device!=""}[$__rate_interval])
                            EOT
              legendFormat = "{{ device }} avg read time"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                irate(node_disk_write_time_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance", device!=""}[$__rate_interval])
                                /
                                irate(node_disk_writes_completed_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance", device!=""}[$__rate_interval])
                            EOT
              legendFormat = "{{ device }} avg write time"
            },
          ]
          title = "Disk average wait time"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Disk average IO queue."
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = true
                axisLabel         = "write(-) | read(+)"
                fillOpacity       = 1
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/write|written/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 34
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_disk_io_time_weighted_seconds_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", device!=\"\"}[$__rate_interval])"
              legendFormat = "{{ device }} avg queue"
            },
          ]
          title = "Disk average queue"
          type  = "timeseries"
        },
      ]
      refresh       = "30s"
      schemaVersion = 39
      tags = [
        "linux-node-integration",
      ]
      templating = {
        list = [
          {
            label = "Prometheus data source"
            name  = "prometheus_datasource"
            query = "prometheus"
            regex = "(?!grafanacloud-usage|grafanacloud-ml-metrics).+"
            type  = "datasource"
          },
          {
            allValue = ".*"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Cluster"
            multi      = true
            name       = "cluster"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\"}, cluster)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Job"
            multi      = true
            name       = "job"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\"}, job)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = false
            label      = "Instance"
            multi      = false
            name       = "instance"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\"}, instance)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            hide  = 2
            label = "Loki data source"
            name  = "loki_datasource"
            query = "loki"
            regex = "(?!grafanacloud.+usage-insights|grafanacloud.+alert-state-history).+"
            type  = "datasource"
          },
        ]
      }
      time = {
        from = "now-30m"
        to   = "now"
      }
      timezone = "default"
      title    = "Linux node / filesystem and disks"
      uid      = "node-disk"
    }
  )
}

resource "grafana_dashboard" "soc_dev_linux_node_fleet" {
  provider = grafana.soc_dev
  folder   = grafana_folder.integration_linux_node.id
  config_json = jsonencode(
    {
      annotations = {
        list = [
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", transport=\"kernel\", level=\"emerg\"}"
            hide        = true
            iconColor   = "light-purple"
            name        = "Critical system event"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Critical system event"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = <<-EOT
                            changes(
                            sum by (instance) (
                                group by (instance,release) (node_uname_info{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                )
                            [$__interval:1m] offset -$__interval) > 1
                        EOT
            hide        = true
            iconColor   = "light-blue"
            name        = "Kernel update"
            step        = "5m"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "Kernel update"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = "increase(node_vmstat_oom_kill{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__interval:] offset -$__interval)"
            hide        = true
            iconColor   = "light-purple"
            name        = "OOMkill"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "OOMkill"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable          = true
            expr            = "node_boot_time_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}*1000 > $__from < $__to"
            hide            = true
            iconColor       = "light-yellow"
            name            = "Reboot"
            tagKeys         = "cluster,job,instance"
            titleFormat     = "Reboot"
            useValueForTime = "on"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"init.scope\"} |= \"code=exited, status=1/FAILURE\""
            hide        = true
            iconColor   = "light-orange"
            name        = "Service failed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Service failed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session closed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session closed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session opened"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session opened"
          },
        ]
      }
      editable = false
      links = [
        {
          asDropdown  = true
          includeVars = true
          keepTime    = true
          tags = [
            "linux-node-integration",
          ]
          title = "All Linux node /  dashboards"
          type  = "dashboards"
        },
      ]
      panels = [
        {
          datasource = {
            type = "datasource"
            uid  = "-- Mixed --"
          }
          description = "Shows if metrics are being received for the selected time range."
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
              mappings = [
                {
                  options = {
                    match = "null"
                    result = {
                      color = "light-red"
                      index = 0
                      text  = "No metrics received - Check configuration"
                    }
                  }
                  type = "special"
                },
                {
                  options = {
                    from = 0
                    result = {
                      color = "light-red"
                      index = 1
                      text  = "Failed to collect metrics"
                    }
                    to = 0
                  }
                  type = "range"
                },
                {
                  options = {
                    from = 1
                    result = {
                      color = "light-green"
                      index = 2
                      text  = "Receiving metrics"
                    }
                    to = 1000000
                  }
                  type = "range"
                },
              ]
              noValue = "No data"
              unit    = "string"
            }
          }
          gridPos = {
            h = 2
            w = 8
            x = 0
            y = 0
          }
          options = {
            colorMode = "background"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v10.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = "$prometheus_datasource"
              }
              expr = <<-EOT
                                vector(1) and on() ((count(up{job=~"$job"} == 1) > 0) and (absent(absent(node_uname_info{job=~"$job"})))) or vector(0) and on() ((count(up{job=~"$job"}) > 0) and (absent(node_uname_info{job=~"$job"})))
                            EOT
            },
          ]
          title = "Metrics"
          type  = "stat"
        },
        {
          datasource = {
            type = "datasource"
            uid  = "-- Mixed --"
          }
          description = "Shows the timestamp of the latest metrics received for this integration in the last 24 hours."
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
              noValue = "No data"
              unit    = "dateTimeFromNow"
            }
          }
          gridPos = {
            h = 2
            w = 8
            x = 8
            y = 0
          }
          options = {
            colorMode = "background"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
              fields = "Time"
            }
          }
          pluginVersion = "v10.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = "$prometheus_datasource"
              }
              expr = <<-EOT
                                vector(1) and on() ((count(up{job=~"$job"} == 1) > 0) and (absent(absent(node_uname_info{job=~"$job"})))) or vector(0) and on() ((count(up{job=~"$job"}) > 0) and (absent(node_uname_info{job=~"$job"})))
                            EOT
            },
          ]
          timeFrom = "now-24h"
          title    = "Latest metrics received"
          type     = "stat"
        },
        {
          datasource = {
            type = "datasource"
            uid  = "-- Mixed --"
          }
          description = "Shows the installed version of this integration."
          gridPos = {
            h = 2
            w = 8
            x = 16
            y = 0
          }
          options = {
            content = "<p style=\"text-align: center\">1.6.2</p>"
            mode    = "html"
          }
          pluginVersion = "v10.0.0"
          title         = "Integration version"
          type          = "text"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "All nodes' perfomance at a glance."
          fieldConfig = {
            overrides = [
              {
                matcher = {
                  id      = "byName"
                  options = "Uptime"
                }
                properties = [
                  {
                    id = "custom.cellOptions"
                    value = {
                      type = "color-text"
                    }
                  },
                  {
                    id = "color"
                    value = {
                      mode = "thresholds"
                    }
                  },
                  {
                    id    = "decimals"
                    value = 1
                  },
                  {
                    id = "thresholds"
                    value = {
                      mode = "absolute"
                      steps = [
                        {
                          color = "orange"
                          value = null
                        },
                        {
                          color = "text"
                          value = 600
                        },
                      ]
                    }
                  },
                  {
                    id    = "unit"
                    value = "dtdurations"
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "Product|^Hostname$"
                }
                properties = [
                  {
                    id    = "custom.filterable"
                    value = true
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Instance"
                }
                properties = [
                  {
                    id    = "custom.filterable"
                    value = true
                  },
                  {
                    id = "links"
                    value = [
                      {
                        targetBlank = false
                        title       = "Drill down to $${__field.name} $${__value.text}"
                        url         = "d/nodes?$${__url_time_range}&$${datasource:queryparam}&var-instance=$${__data.fields.instance}"
                      },
                    ]
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "Cluster|Job"
                }
                properties = [
                  {
                    id    = "custom.filterable"
                    value = true
                  },
                  {
                    id = "links"
                    value = [
                      {
                        targetBlank = false
                        title       = "Filter by $${__field.name}"
                        url         = "d/node-fleet?var-$${__field.name}=$${__value.text}&$${__url_time_range}&$${datasource:queryparam}"
                      },
                    ]
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Cores"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 120
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "CPU usage"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 120
                  },
                  {
                    id = "custom.cellOptions"
                    value = {
                      mode             = "basic"
                      type             = "gauge"
                      valueDisplayMode = "text"
                    }
                  },
                  {
                    id = "color"
                    value = {
                      mode = "continuous-BlYlRd"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 30
                  },
                  {
                    id    = "custom.gradientMode"
                    value = "scheme"
                  },
                  {
                    id    = "custom.lineInterpolation"
                    value = "smooth"
                  },
                  {
                    id    = "custom.lineWidth"
                    value = 2
                  },
                  {
                    id    = "custom.showPoints"
                    value = "never"
                  },
                  {
                    id    = "decimals"
                    value = 1
                  },
                  {
                    id    = "max"
                    value = 100
                  },
                  {
                    id    = "min"
                    value = 0
                  },
                  {
                    id    = "unit"
                    value = "percent"
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Memory total"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 120
                  },
                  {
                    id    = "unit"
                    value = "bytes"
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Memory usage"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 120
                  },
                  {
                    id = "custom.cellOptions"
                    value = {
                      mode             = "basic"
                      type             = "gauge"
                      valueDisplayMode = "text"
                    }
                  },
                  {
                    id = "color"
                    value = {
                      mode = "continuous-BlYlRd"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 30
                  },
                  {
                    id    = "custom.gradientMode"
                    value = "scheme"
                  },
                  {
                    id    = "custom.lineInterpolation"
                    value = "smooth"
                  },
                  {
                    id    = "custom.lineWidth"
                    value = 2
                  },
                  {
                    id    = "custom.showPoints"
                    value = "never"
                  },
                  {
                    id    = "decimals"
                    value = 1
                  },
                  {
                    id    = "max"
                    value = 100
                  },
                  {
                    id    = "min"
                    value = 0
                  },
                  {
                    id    = "unit"
                    value = "percent"
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Root mount size"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 120
                  },
                  {
                    id    = "unit"
                    value = "bytes"
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Root mount used"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 120
                  },
                  {
                    id = "custom.cellOptions"
                    value = {
                      mode             = "basic"
                      type             = "gauge"
                      valueDisplayMode = "text"
                    }
                  },
                  {
                    id    = "unit"
                    value = "percent"
                  },
                  {
                    id = "color"
                    value = {
                      mode = "continuous-BlYlRd"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 30
                  },
                  {
                    id    = "custom.gradientMode"
                    value = "scheme"
                  },
                  {
                    id    = "custom.lineInterpolation"
                    value = "smooth"
                  },
                  {
                    id    = "custom.lineWidth"
                    value = 2
                  },
                  {
                    id    = "custom.showPoints"
                    value = "never"
                  },
                  {
                    id    = "decimals"
                    value = 1
                  },
                  {
                    id    = "max"
                    value = 100
                  },
                  {
                    id    = "min"
                    value = 0
                  },
                  {
                    id    = "unit"
                    value = "percent"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 16
            w = 24
            x = 0
            y = 3
          }
          options = {
            footer = {
              fields = [
                "Value #Cores",
                "Value #Load 1",
                "Value #Memory total",
                "Value #Root mount size",
              ]
              reducer = [
                "sum",
              ]
              show = true
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = <<-EOT
                                node_uname_info{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"} 
                                * on (cluster,job,instance)
                                group_left(pretty_name)
                                node_os_info{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}
                            EOT
              format  = "table"
              instant = true
              refId   = "OS Info"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "time() - node_boot_time_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format  = "table"
              instant = true
              refId   = "Uptime"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_load1{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format       = "table"
              instant      = true
              legendFormat = "1m"
              refId        = "Load 1"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "count without (cpu) (node_cpu_seconds_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", mode=\"idle\"})"
              format       = "table"
              instant      = true
              legendFormat = "Cores"
              refId        = "Cores"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                (((count by (instance) (count(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) by (cpu, instance))) 
                                - 
                                sum by (instance) (sum by (instance, mode)(irate(node_cpu_seconds_total{mode=~'idle|iowait|steal',job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])))) * 100) 
                                / 
                                count by(instance) (count(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) by (cpu, instance))
                            EOT
              format       = "table"
              instant      = true
              legendFormat = "CPU usage"
              refId        = "CPU usage"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_MemTotal_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format       = "table"
              instant      = true
              legendFormat = "Memory total"
              refId        = "Memory total"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = <<-EOT
                                100 -
                                (
                                  avg by (instance) (node_memory_MemAvailable_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) /
                                  avg by (instance) (node_memory_MemTotal_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                * 100
                                )
                            EOT
              format  = "table"
              instant = true
              refId   = "Memory usage"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "node_filesystem_size_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", mountpoint=\"/\", fstype!=\"rootfs\"}"
              format  = "table"
              instant = true
              refId   = "Root mount size"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "100 - node_filesystem_avail_bytes{mountpoint=\"/\",fstype!=\"rootfs\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}/node_filesystem_size_bytes{mountpoint=\"/\",fstype!=\"rootfs\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}*100"
              format  = "table"
              instant = true
              refId   = "Root mount used"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "count by (instance) (max_over_time(ALERTS{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", alertstate=\"firing\", severity=\"critical\"}[1m])) * group by (instance) (node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"})"
              format  = "table"
              instant = true
              refId   = "CRITICAL"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "count by (instance) (max_over_time(ALERTS{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", alertstate=\"firing\", severity=\"warning\"}[1m])) * group by (instance) (node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"})"
              format  = "table"
              instant = true
              refId   = "WARNING"
            },
          ]
          title = "Fleet overview"
          transformations = [
            {
              id = "joinByField"
              options = {
                byField = "instance"
                mode    = "outer"
              }
            },
            {
              id = "filterFieldsByName"
              options = {
                include = {
                  pattern = "instance|instance 1|cluster 1|job 1|product|^hostname$|^nodename$|^pretty_name$|Value.+"
                }
              }
            },
            {
              id = "organize"
              options = {
                excludeByName = {
                  "Value #OS Info" = true
                }
                indexByName = {
                  cluster     = 3
                  hostname    = 1
                  instance    = 0
                  job         = 3
                  nodename    = 1
                  pretty_name = 2
                  product     = 2
                }
                renameByName = {
                  "cluster 1"  = "Cluster"
                  hostname     = "Hostname"
                  instance     = "Instance"
                  "instance 1" = "Instance"
                  "job 1"      = "Job"
                  nodename     = "Hostname"
                  pretty_name  = "OS"
                  product      = "OS"
                }
              }
            },
            {
              id = "renameByRegex"
              options = {
                regex         = "Value #(.*)"
                renamePattern = "$1"
              }
            },
          ]
          type = "table"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Top 25"
          fieldConfig = {
            defaults = {
              color = {
                mode = "continuous-BlYlRd"
              }
              custom = {
                fillOpacity       = 1
                gradientMode      = "scheme"
                lineInterpolation = "smooth"
                lineWidth         = 1
                showPoints        = "never"
              }
              decimals = 1
              links = [
                {
                  title = "Drill down to this instance"
                  url   = "/d/nodes?var-instance=$${__field.labels.instance}&$${__url_time_range}&$${datasource:queryparam}"
                },
              ]
              max  = 100
              min  = 0
              unit = "percent"
            }
            overrides = [
              {
                matcher = {
                  id      = "byName"
                  options = "Mean"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-purple"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 7
            w = 12
            x = 0
            y = 10
          }
          options = {
            legend = {
              calcs = [
                "mean",
                "max",
                "lastNotNull",
              ]
              displayMode = "table"
              placement   = "right"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                topk(25,(((count by (instance) (count(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) by (cpu, instance))) 
                                - 
                                sum by (instance) (sum by (instance, mode)(irate(node_cpu_seconds_total{mode=~'idle|iowait|steal',job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])))) * 100) 
                                / 
                                count by(instance) (count(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) by (cpu, instance))
                                )
                            EOT
              legendFormat = "{{instance}}"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                avg((((count by (instance) (count(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) by (cpu, instance))) 
                                - 
                                sum by (instance) (sum by (instance, mode)(irate(node_cpu_seconds_total{mode=~'idle|iowait|steal',job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])))) * 100) 
                                / 
                                count by(instance) (count(node_cpu_seconds_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) by (cpu, instance))
                                )
                            EOT
              legendFormat = "Mean"
            },
          ]
          title = "CPU usage"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Top 25"
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 0
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "short"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "Cores"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 7
            w = 12
            x = 12
            y = 10
          }
          options = {
            legend = {
              calcs = [
                "mean",
                "max",
                "lastNotNull",
              ]
              displayMode = "table"
              placement   = "right"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "topk(25, node_load1{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"})>0"
              legendFormat = "{{instance}}"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "count without (cpu) (node_cpu_seconds_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", mode=\"idle\"})"
              hide         = true
              legendFormat = "Cores"
            },
          ]
          title = "Load average 1m"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Top 25"
          fieldConfig = {
            defaults = {
              color = {
                mode = "continuous-BlYlRd"
              }
              custom = {
                fillOpacity       = 1
                gradientMode      = "scheme"
                lineInterpolation = "smooth"
                lineWidth         = 1
                showPoints        = "never"
              }
              decimals = 1
              links = [
                {
                  title = "Drill down to this instance"
                  url   = "/d/nodes?var-instance=$${__field.labels.instance}&$${__url_time_range}&$${datasource:queryparam}"
                },
              ]
              max  = 100
              min  = 0
              unit = "percent"
            }
            overrides = [
              {
                matcher = {
                  id      = "byName"
                  options = "Mean"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-purple"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 7
            w = 24
            x = 0
            y = 17
          }
          options = {
            legend = {
              calcs = [
                "mean",
                "max",
                "lastNotNull",
              ]
              displayMode = "table"
              placement   = "right"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                topk(25,100 -
                                (
                                  avg by (instance) (node_memory_MemAvailable_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) /
                                  avg by (instance) (node_memory_MemTotal_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                * 100
                                )
                                )
                            EOT
              legendFormat = "{{instance}}"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                avg(100 -
                                (
                                  avg by (instance) (node_memory_MemAvailable_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) /
                                  avg by (instance) (node_memory_MemTotal_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                * 100
                                )
                                )
                            EOT
              legendFormat = "Mean"
            },
          ]
          title = "Memory usage"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Top 25"
          fieldConfig = {
            defaults = {
              color = {
                mode = "continuous-BlYlRd"
              }
              custom = {
                fillOpacity       = 1
                gradientMode      = "scheme"
                lineInterpolation = "smooth"
                lineWidth         = 1
                showPoints        = "never"
              }
              decimals = 1
              links = [
                {
                  title = "Drill down to this instance"
                  url   = "/d/nodes?var-instance=$${__field.labels.instance}&var-device=$${__field.labels.device}&$${__url_time_range}&$${datasource:queryparam}"
                },
              ]
              max  = 100
              min  = 0
              unit = "percent"
            }
            overrides = [
              {
                matcher = {
                  id      = "byName"
                  options = "Mean"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-purple"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 7
            w = 12
            x = 0
            y = 24
          }
          options = {
            legend = {
              calcs = [
                "mean",
                "max",
                "lastNotNull",
              ]
              displayMode = "table"
              placement   = "right"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "topk(25,irate(node_disk_io_time_seconds_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", device!=\"\"}[$__rate_interval]))"
              legendFormat = "{{instance}}: {{device}}"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "avg(irate(node_disk_io_time_seconds_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", device!=\"\"}[$__rate_interval]))"
              legendFormat = "Mean"
            },
          ]
          title = "Disk IO"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Top 25"
          fieldConfig = {
            defaults = {
              color = {
                mode = "continuous-BlYlRd"
              }
              custom = {
                fillOpacity       = 1
                gradientMode      = "scheme"
                lineInterpolation = "smooth"
                lineWidth         = 1
                showPoints        = "never"
              }
              decimals = 1
              links = [
                {
                  title = "Drill down to this instance"
                  url   = "/d/nodes?var-instance=$${__field.labels.instance}&var-mountpoint=$${__field.labels.mountpoint}&$${__url_time_range}&$${datasource:queryparam}"
                },
              ]
              max  = 100
              min  = 0
              unit = "percent"
            }
            overrides = [
              {
                matcher = {
                  id      = "byName"
                  options = "Mean"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-purple"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 7
            w = 12
            x = 12
            y = 24
          }
          options = {
            legend = {
              calcs = [
                "mean",
                "max",
                "lastNotNull",
              ]
              displayMode = "table"
              placement   = "right"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "topk(25,100 - node_filesystem_avail_bytes{fstype!=\"\", mountpoint!=\"\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}/node_filesystem_size_bytes{fstype!=\"\", mountpoint!=\"\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}*100)"
              legendFormat = "{{instance}}: {{mountpoint}}"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "avg(100 - node_filesystem_avail_bytes{fstype!=\"\", mountpoint!=\"\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}/node_filesystem_size_bytes{fstype!=\"\", mountpoint!=\"\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}*100)"
              legendFormat = "Mean"
            },
          ]
          title = "Disk space usage"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Top 25 interfaces"
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No traffic"
              unit     = "bps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 7
            w = 12
            x = 0
            y = 31
          }
          options = {
            legend = {
              calcs = [
                "mean",
                "max",
                "lastNotNull",
              ]
              displayMode = "table"
              placement   = "right"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                topk(25, irate(node_network_receive_bytes_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])*8
                                # only show interfaces that had traffic change at least once during selected dashboard interval:
                                and
                                increase(
                                    node_network_receive_bytes_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__range]
                                    ) > 0
                                )>0
                            EOT
              legendFormat = "{{instance}}: {{ device }} received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                topk(25, irate(node_network_transmit_bytes_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])*8
                                # only show interfaces that had traffic change at least once during selected dashboard interval:
                                and
                                increase(
                                    node_network_transmit_bytes_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__range]
                                    ) > 0
                                )>0
                            EOT
              legendFormat = "{{instance}}: {{ device }} transmitted"
            },
          ]
          title = "Network traffic"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Top 25.
                        
                        **Network errors**:
                        
                        Network errors refer to issues that occur during the transmission of data across a network. 
                        
                        These errors can result from various factors, including physical issues, jitter, collisions, noise and interference.
                        
                        Monitoring network errors is essential for diagnosing and resolving issues, as they can indicate problems with network hardware or environmental factors affecting network quality.
                        
                        **Dropped packets**:
                        
                        Dropped packets occur when data packets traveling through a network are intentionally discarded or lost due to congestion, resource limitations, or network configuration issues. 
                        
                        Common causes include network congestion, buffer overflows, QoS settings, and network errors, as corrupted or incomplete packets may be discarded by receiving devices.
                        
                        Dropped packets can impact network performance and lead to issues such as degraded voice or video quality in real-time applications.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                drawStyle         = "points"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                pointSize         = 5
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No errors"
              unit     = "pps"
            }
          }
          gridPos = {
            h = 7
            w = 12
            x = 12
            y = 31
          }
          options = {
            legend = {
              calcs = [
                "mean",
                "max",
                "lastNotNull",
              ]
              displayMode = "table"
              placement   = "right"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "topk(25, irate(node_network_transmit_errs_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval]))>0"
              legendFormat = "{{instance}}: {{ device }} errors transmitted"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "topk(25, irate(node_network_receive_errs_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval]))>0"
              legendFormat = "{{instance}}: {{ device }} errors received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "topk(25, irate(node_network_transmit_drop_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval]))>0"
              legendFormat = "{{instance}}: {{ device }} transmitted dropped"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "topk(25, irate(node_network_receive_drop_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval]))>0"
              legendFormat = "{{instance}}: {{ device }} received dropped"
            },
          ]
          title = "Network errors and dropped packets"
          type  = "timeseries"
        },
      ]
      refresh       = "30s"
      schemaVersion = 39
      tags = [
        "linux-node-integration",
      ]
      templating = {
        list = [
          {
            label = "Prometheus data source"
            name  = "prometheus_datasource"
            query = "prometheus"
            regex = "(?!grafanacloud-usage|grafanacloud-ml-metrics).+"
            type  = "datasource"
          },
          {
            allValue = ".*"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Cluster"
            multi      = true
            name       = "cluster"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\"}, cluster)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Job"
            multi      = true
            name       = "job"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\"}, job)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Instance"
            multi      = true
            name       = "instance"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\"}, instance)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            hide  = 2
            label = "Loki data source"
            name  = "loki_datasource"
            query = "loki"
            regex = "(?!grafanacloud.+usage-insights|grafanacloud.+alert-state-history).+"
            type  = "datasource"
          },
        ]
      }
      time = {
        from = "now-30m"
        to   = "now"
      }
      timezone = "default"
      title    = "Linux node / fleet overview"
      uid      = "node-fleet"
    }
  )
}

resource "grafana_dashboard" "soc_dev_linux_node_logs" {
  provider = grafana.soc_dev
  folder   = grafana_folder.integration_linux_node.id
  config_json = jsonencode(
    {
      annotations = {
        list = [
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", transport=\"kernel\", level=\"emerg\"}"
            hide        = true
            iconColor   = "light-purple"
            name        = "Critical system event"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Critical system event"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = <<-EOT
                            changes(
                            sum by (instance) (
                                group by (instance,release) (node_uname_info{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                )
                            [$__interval:1m] offset -$__interval) > 1
                        EOT
            hide        = true
            iconColor   = "light-blue"
            name        = "Kernel update"
            step        = "5m"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "Kernel update"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = "increase(node_vmstat_oom_kill{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__interval:] offset -$__interval)"
            hide        = true
            iconColor   = "light-purple"
            name        = "OOMkill"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "OOMkill"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable          = true
            expr            = "node_boot_time_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}*1000 > $__from < $__to"
            hide            = true
            iconColor       = "light-yellow"
            name            = "Reboot"
            tagKeys         = "cluster,job,instance"
            titleFormat     = "Reboot"
            useValueForTime = "on"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"init.scope\"} |= \"code=exited, status=1/FAILURE\""
            hide        = true
            iconColor   = "light-orange"
            name        = "Service failed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Service failed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session closed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session closed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session opened"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session opened"
          },
        ]
      }
      editable = false
      links = [
        {
          keepTime = true
          title    = "Back to Linux node / fleet"
          type     = "link"
          url      = "/d/node-fleet"
        },
        {
          keepTime = true
          title    = "Back to Linux node / overview"
          type     = "link"
          url      = "/d/nodes"
        },
        {
          asDropdown  = true
          includeVars = true
          keepTime    = true
          tags = [
            "linux-node-integration",
          ]
          title = "All Linux node /  dashboards"
          type  = "dashboards"
        },
      ]
      panels = [
        {
          datasource = {
            type = "datasource"
            uid  = "-- Mixed --"
          }
          description = "Shows if logs are being received for the selected time range."
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
              mappings = [
                {
                  options = {
                    match = "null"
                    result = {
                      color = "light-yellow"
                      index = 0
                      text  = "Failed to collect logs or no logs available"
                    }
                  }
                  type = "special"
                },
                {
                  options = {
                    from = 0
                    result = {
                      color = "light-yellow"
                      index = 1
                      text  = "Failed to collect logs or no logs available"
                    }
                    to = 0
                  }
                  type = "range"
                },
                {
                  options = {
                    from = 1
                    result = {
                      color = "light-green"
                      index = 2
                      text  = "Receiving logs"
                    }
                    to = 1000000
                  }
                  type = "range"
                },
              ]
              noValue = "No data"
              unit    = "string"
            }
          }
          gridPos = {
            h = 2
            w = 8
            x = 0
            y = 0
          }
          options = {
            colorMode = "background"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v10.0.0"
          targets = [
            {
              datasource = {
                type = "loki"
                uid  = "$loki_datasource"
              }
              expr = <<-EOT
                                sum(count_over_time({job=~"integrations/(node_exporter|unix)", job=~"$job"}[$__auto]))
                            EOT
            },
          ]
          title = "Logs"
          type  = "stat"
        },
        {
          datasource = {
            type = "datasource"
            uid  = "-- Mixed --"
          }
          description = "Shows the timestamp of the latest logs received for this integration in the last 24 hours."
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
              noValue = "No data"
              unit    = "dateTimeFromNow"
            }
          }
          gridPos = {
            h = 2
            w = 8
            x = 8
            y = 0
          }
          options = {
            colorMode = "background"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
              fields = "Time"
            }
          }
          pluginVersion = "v10.0.0"
          targets = [
            {
              datasource = {
                type = "loki"
                uid  = "$loki_datasource"
              }
              expr = <<-EOT
                                sum(count_over_time({job=~"integrations/(node_exporter|unix)", job=~"$job"}[$__auto]))
                            EOT
            },
          ]
          timeFrom = "now-24h"
          title    = "Latest logs received"
          type     = "stat"
        },
        {
          datasource = {
            type = "datasource"
            uid  = "-- Mixed --"
          }
          description = "Shows the installed version of this integration."
          gridPos = {
            h = 2
            w = 8
            x = 16
            y = 0
          }
          options = {
            content = "<p style=\"text-align: center\">1.6.2</p>"
            mode    = "html"
          }
          pluginVersion = "v10.0.0"
          title         = "Integration version"
          type          = "text"
        },
        {
          datasource = {
            type = "loki"
            uid  = data.grafana_data_source.soc_dev_loki.uid
          }
          description = "Logs volume grouped by \"level\" label."
          fieldConfig = {
            defaults = {
              custom = {
                drawStyle   = "bars"
                fillOpacity = 50
                stacking = {
                  mode = "normal"
                }
              }
              unit = "none"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "(E|e)merg|(F|f)atal|(A|a)lert|(C|c)rit.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "purple"
                      mode       = "fixed"
                    }
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "(E|e)(rr.*|RR.*)"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "red"
                      mode       = "fixed"
                    }
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "(W|w)(arn.*|ARN.*|rn|RN)"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "orange"
                      mode       = "fixed"
                    }
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "(N|n)(otice|ote)|(I|i)(nf.*|NF.*)"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "green"
                      mode       = "fixed"
                    }
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "dbg.*|DBG.*|(D|d)(EBUG|ebug)"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "blue"
                      mode       = "fixed"
                    }
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "(T|t)(race|RACE)"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-blue"
                      mode       = "fixed"
                    }
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "logs"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "text"
                      mode       = "fixed"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 6
            w = 24
            x = 0
            y = 3
          }
          maxDataPoints = 100
          options = {
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "loki"
                uid  = data.grafana_data_source.soc_dev_loki.uid
              }
              expr         = <<-EOT
                                sum by (level) (count_over_time({job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance",transport=~"$transport",unit=~"$unit",level=~"$level"}
                                |~ "$regex_search"

                                [$__auto]))
                            EOT
              legendFormat = "{{ level }}"
            },
          ]
          title = "Logs volume"
          transformations = [
            {
              id = "renameByRegex"
              options = {
                regex         = "Value"
                renamePattern = "logs"
              }
            },
          ]
          type = "timeseries"
        },
        {
          datasource = {
            type = "datasource"
            uid  = "-- Mixed --"
          }
          gridPos = {
            h = 18
            w = 24
            x = 0
            y = 21
          }
          options = {
            dedupStrategy      = "exact"
            enableLogDetails   = true
            prettifyLogMessage = true
            showTime           = false
            wrapLogMessage     = false
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "loki"
                uid  = data.grafana_data_source.soc_dev_loki.uid
              }
              expr = <<-EOT
                                {job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance",transport=~"$transport",unit=~"$unit",level=~"$level"}
                                |~ "$regex_search"

                                | label_format timestamp="{{__timestamp__}}"
                                | line_format `{{ if eq "[[instance]]" ".*" }}{{alignLeft 25 .instance}}|{{alignLeft 25 .unit}}|{{else}}{{alignLeft 25 .unit}}|{{end}} {{__line__}}`
                            EOT
            },
          ]
          title = "Logs"
          type  = "logs"
        },
      ]
      refresh       = "30s"
      schemaVersion = 39
      tags = [
        "linux-node-integration",
      ]
      templating = {
        list = [
          {
            label = "Loki data source"
            name  = "loki_datasource"
            query = "loki"
            regex = "(?!grafanacloud.+usage-insights|grafanacloud.+alert-state-history).+"
            type  = "datasource"
          },
          {
            allValue = ".*"
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            includeAll = true
            label      = "Cluster"
            multi      = true
            name       = "cluster"
            query      = "label_values({job=~\"integrations/(node_exporter|unix)\"}, cluster)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".*"
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            includeAll = true
            label      = "Job"
            multi      = true
            name       = "job"
            query      = "label_values({job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\"}, job)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".*"
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            includeAll = true
            label      = "Instance"
            multi      = true
            name       = "instance"
            query      = "label_values({job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\"}, instance)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".*"
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            includeAll = true
            label      = "Transport"
            multi      = true
            name       = "transport"
            query      = "label_values({job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}, transport)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".*"
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            includeAll = true
            label      = "Unit"
            multi      = true
            name       = "unit"
            query      = "label_values({job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\",transport=~\"$transport\"}, unit)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".*"
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            includeAll = true
            label      = "Level"
            multi      = true
            name       = "level"
            query      = "label_values({job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\",transport=~\"$transport\",unit=~\"$unit\"}, level)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            current = {
              selected = false
              text     = ""
              value    = ""
            }
            label = "Regex search"
            name  = "regex_search"
            options = [
              {
                selected = true
                text     = ""
                value    = ""
              },
            ]
            query = ""
            type  = "textbox"
          },
          {
            hide  = 2
            label = "Prometheus data source"
            name  = "prometheus_datasource"
            query = "prometheus"
            regex = "(?!grafanacloud-usage|grafanacloud-ml-metrics).+"
            type  = "datasource"
          },
        ]
      }
      time = {
        from = "now-30m"
        to   = "now"
      }
      timezone = "default"
      title    = "Linux node / logs"
      uid      = "node-logs"
    }
  )
}

resource "grafana_dashboard" "soc_dev_linux_node_memory" {
  provider = grafana.soc_dev
  folder   = grafana_folder.integration_linux_node.id
  config_json = jsonencode(
    {
      annotations = {
        list = [
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", transport=\"kernel\", level=\"emerg\"}"
            hide        = true
            iconColor   = "light-purple"
            name        = "Critical system event"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Critical system event"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = <<-EOT
                            changes(
                            sum by (instance) (
                                group by (instance,release) (node_uname_info{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                )
                            [$__interval:1m] offset -$__interval) > 1
                        EOT
            hide        = true
            iconColor   = "light-blue"
            name        = "Kernel update"
            step        = "5m"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "Kernel update"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = "increase(node_vmstat_oom_kill{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__interval:] offset -$__interval)"
            hide        = true
            iconColor   = "light-purple"
            name        = "OOMkill"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "OOMkill"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable          = true
            expr            = "node_boot_time_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}*1000 > $__from < $__to"
            hide            = true
            iconColor       = "light-yellow"
            name            = "Reboot"
            tagKeys         = "cluster,job,instance"
            titleFormat     = "Reboot"
            useValueForTime = "on"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"init.scope\"} |= \"code=exited, status=1/FAILURE\""
            hide        = true
            iconColor   = "light-orange"
            name        = "Service failed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Service failed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session closed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session closed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session opened"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session opened"
          },
        ]
      }
      editable = false
      links = [
        {
          keepTime = true
          title    = "Back to Linux node / fleet"
          type     = "link"
          url      = "/d/node-fleet"
        },
        {
          keepTime = true
          title    = "Back to Linux node / overview"
          type     = "link"
          url      = "/d/nodes"
        },
        {
          asDropdown  = true
          includeVars = true
          keepTime    = true
          tags = [
            "linux-node-integration",
          ]
          title = "All Linux node /  dashboards"
          type  = "dashboards"
        },
      ]
      panels = [
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 0
          }
          panels = []
          title  = "Memory"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "RAM (random-access memory) currently in use by the operating system and running applications, in percent."
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "continuous-BlYlRd"
              }
              decimals = 1
              max      = 100
              min      = 0
              unit     = "percent"
            }
          }
          gridPos = {
            h = 6
            w = 6
            x = 0
            y = 1
          }
          options = {
            colorMode = "value"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr = <<-EOT
                                100 -
                                (
                                  avg by (instance) (node_memory_MemAvailable_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) /
                                  avg by (instance) (node_memory_MemTotal_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                * 100
                                )
                            EOT
            },
          ]
          title = "Memory usage"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        - Used: The amount of physical memory currently in use by the system.
                        - Cached: The amount of physical memory used for caching data from disk. The Linux kernel uses available memory to cache data that is read from or written to disk. This helps speed up disk access times.
                        - Free: The amount of physical memory that is currently not in use.
                        - Buffers: The amount of physical memory used for temporary storage of data being transferred between devices or applications.
                        - Available: The amount of physical memory that is available for use by applications. This takes into account memory that is currently being used for caching but can be freed up if needed.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
              {
                __systemRef = "hideSeriesFrom"
                matcher = {
                  id = "byNames"
                  options = {
                    mode = "exclude"
                    names = [
                      "Memory total",
                      "Memory used",
                    ]
                    prefix   = "All except:"
                    readOnly = true
                  }
                }
                properties = [
                  {
                    id = "custom.hideFrom"
                    value = {
                      legend  = false
                      tooltip = false
                      viz     = true
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 6
            w = 18
            x = 6
            y = 1
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                (
                                  node_memory_MemTotal_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}
                                -
                                  node_memory_MemFree_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}
                                -
                                  node_memory_Buffers_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}
                                -
                                  node_memory_Cached_bytes{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}
                                )
                            EOT
              legendFormat = "Memory used"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Cached_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory cached"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_MemAvailable_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory available"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Buffers_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory buffers"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_MemFree_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory free"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_MemTotal_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory total"
            },
          ]
          title = "Memory usage"
          type  = "timeseries"
        },
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 7
          }
          panels = []
          title  = "Vmstat"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Page-In - Return of pages to physical memory. This is a common and normal event.
                        
                        Page-Out - process of writing pages to disk. Unlike page-in, page-outs can indicate trouble.
                        When the kernel detects low memory, it attempts to free memory by paging out. 
                        While occasional page-outs are normal, excessive and frequent page-outs can lead to thrashing.
                        Thrashing is a state in which the kernel spends more time managing paging activity than running applications, resulting in poor system performance.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 8
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_vmstat_pgpgin{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "Page-In"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_vmstat_pgpgout{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "Page-Out"
            },
          ]
          title = "Memory pages in / out"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Compared to the speed of the CPU and main memory, writing pages out to disk is relatively slow.
                        Nonetheless, it is a preferable option to crashing or killing off processes.
                        
                        The process of writing pages out to disk to free memory is known as swapping-out.
                        If a page fault occurs because the page is on disk, in the swap area, rather than in memory,
                        the kernel will read the page back in from the disk to satisfy the page fault. 
                        This is known as swapping-in.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 8
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_vmstat_pswpin{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "Pages swapped in"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_vmstat_pswpout{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "Pages swapped out"
            },
          ]
          title = "Memory pages swapping in / out"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        A page fault is an exception raised by the memory when a process accesses a memory page without the necessary preparations,
                        requiring a mapping to be added to the process's virtual address space.
                        
                        The page contents may also need to be loaded from a backing store such as a disk.
                        While the MMU detects the page fault, the operating system's kernel handles the exception by either making the required page accessible in physical memory or denying an illegal memory access.
                        Valid page faults are common and necessary to increase memory availability in any operating system that uses virtual memory, including Windows, macOS, and the Linux kernel.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 16
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_vmstat_pgmajfault{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "Major page fault operations"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                irate(node_vmstat_pgfault{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])
                                -
                                irate(node_vmstat_pgmajfault{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])
                            EOT
              legendFormat = "Minor page fault operations"
            },
          ]
          title = "Memory page faults"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Out Of Memory killer is a process used by the Linux kernel when the system is running critically low on memory.
                        
                        This can happen when the kernel has allocated more memory than is available for its processes.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 16
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "increase(node_vmstat_oom_kill{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__interval:] offset -$__interval)"
              legendFormat = "OOM killer invocations"
            },
          ]
          title = "OOM Killer"
          type  = "timeseries"
        },
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 24
          }
          panels = []
          title  = "Memstat"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        - Inactive: Memory which has been less recently used. It is more eligible to be reclaimed for other purposes.
                        - Active: Memory that has been used more recently and usually not reclaimed unless absolutely necessary.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 25
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Active_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Active"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Inactive_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Inactive"
            },
          ]
          title = "Memory active / inactive"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        - Inactive_file: File-backed memory on inactive LRU list.
                        - Inactive_anon: Anonymous and swap cache on inactive LRU list, including tmpfs (shmem).
                        - Active_file: File-backed memory on active LRU list.
                        - Active_anon: Anonymous and swap cache on active least-recently-used (LRU) list, including tmpfs.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 25
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Inactive_file_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Inactive_file"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Inactive_anon_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Inactive_anon"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Active_file_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Active_file"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Active_anon_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Active_anon"
            },
          ]
          title = "Memory active / inactive details"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        - Committed_AS - Amount of memory presently allocated on the system.
                        - CommitLimit - Amount of memory currently available to be allocated on the system.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 33
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Committed_AS_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Commited_AS"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_CommitLimit_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "CommitLimit"
            },
          ]
          title = "Memory commited"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        - Mapped: This refers to the memory used in mapped page files that have been memory mapped, such as libraries.
                        - Shmem: This is the memory used by shared memory, which is shared between multiple processes, including RAM disks.
                        - ShmemHugePages: This is the memory used by shared memory and tmpfs allocated with huge pages.
                        - ShmemPmdMapped: This is the amount of shared memory (shmem/tmpfs) backed by huge pages.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 33
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Mapped_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Mapped"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Shmem_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Shmem"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_ShmemPmdMapped_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "ShmemPmdMapped"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_ShmemHugePages_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "ShmemHugePages"
            },
          ]
          title = "Memory shared and mapped"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        - Writeback: This refers to the memory that is currently being actively written back to the disk.
                        - WritebackTmp: This is the memory used by FUSE for temporary writeback buffers.
                        - Dirty: This type of memory is waiting to be written back to the disk.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 41
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Writeback_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Writeback"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_WritebackTmp_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "WritebackTmp"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Dirty_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Dirty"
            },
          ]
          title = "Memory writeback and dirty"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Virtual Memory Allocation is a type of memory allocation in Linux that allows a process to request a contiguous block of memory larger than the amount of physically available memory. This is achieved by mapping the requested memory to virtual addresses that are backed by a combination of physical memory and swap space on disk.
                        
                        - VmallocChunk: Largest contiguous block of vmalloc area which is free.
                        - VmallocTotal: Total size of vmalloc memory area.
                        - VmallocUsed: Amount of vmalloc area which is used.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 41
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_VmallocChunk_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "VmallocChunk"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_VmallocTotal_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "VmallocTotal"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_VmallocUsed_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "VmallocUsed"
            },
          ]
          title = "Memory Vmalloc"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Slab Allocation is a type of memory allocation in Linux that allows the kernel to efficiently manage the allocation and deallocation of small and frequently used data structures, such as network packets, file system objects, and process descriptors.
                        
                        The Slab Allocator maintains a cache of pre-allocated objects of a fixed size and type, called slabs. When an application requests an object of a particular size and type, the Slab Allocator checks if a pre-allocated object of that size and type is available in the cache. If an object is available, it is returned to the application; if not, a new slab of objects is allocated and added to the cache.
                        
                        - SUnreclaim: Part of Slab, that cannot be reclaimed on memory pressure.
                        - SReclaimable: Part of Slab, that might be reclaimed, such as caches.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 49
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_SUnreclaim_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "SUnreclaim"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_SReclaimable_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "SReclaimable"
            },
          ]
          title = "Memory slab"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Memory Anonymous refers to the portion of the virtual memory that is used by a process for dynamically allocated memory that is not backed by any file or device.
                        
                        This type of memory is commonly used for heap memory allocation, which is used by programs to allocate and free memory dynamically during runtime.
                        
                        Memory Anonymous is different from Memory Mapped files, which refer to portions of the virtual memory space that are backed by a file or device,
                        and from Memory Shared with other processes,
                        which refers to memory regions that can be accessed and modified by multiple processes.
                        
                        - AnonHugePages: Memory in anonymous huge pages.
                        - AnonPages: Memory in user pages not backed by files.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 49
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_AnonHugePages_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "AnonHugePages"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_AnonPages_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "AnonPages"
            },
          ]
          title = "Memory anonymous"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Huge Pages are a feature that allows for the allocation of larger memory pages than the standard 4KB page size. By using larger page sizes, the kernel can reduce the overhead associated with managing a large number of smaller pages, which can improve system performance for certain workloads.
                        
                        - HugePages_Free: Huge pages in the pool that are not yet allocated.
                        - HugePages_Rsvd: Huge pages for which a commitment to allocate from the pool has been made, but no allocation has yet been made.
                        - HugePages_Surp: Huge pages in the pool above the value in /proc/sys/vm/nr_hugepages.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 57
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_HugePages_Free{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "HugePages_Free"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_HugePages_Rsvd{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "HugePages_Rsvd"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_HugePages_Surp{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "HugePages_Surp"
            },
          ]
          title = "Memory HugePages counter"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Huge Pages are a feature that allows for the allocation of larger memory pages than the standard 4KB page size. By using larger page sizes, the kernel can reduce the overhead associated with managing a large number of smaller pages, which can improve system performance for certain workloads.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 57
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_HugePages_Total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Huge pages total size"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Hugepagesize_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Huge page size"
            },
          ]
          title = "Memory HugePages size"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Direct Map memory refers to the portion of the kernel's virtual address space that is directly mapped to physical memory. This mapping is set up by the kernel during boot time and is used to provide fast access to certain critical kernel data structures, such as page tables and interrupt descriptor tables.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 65
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_DirectMap1G_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "DirectMap1G"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_DirectMap2M_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "DirectMap2M"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_DirectMap4k_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "DirectMap4k"
            },
          ]
          title = "Memory direct map"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Memory bounce is a technique used in the Linux kernel to handle situations where direct memory access (DMA) is required but the physical memory being accessed is not contiguous. This can happen when a device, such as a network interface card or a disk controller, requires access to a large amount of memory that is not available as a single contiguous block.
                        
                        To handle this situation, the kernel uses a technique called memory bouncing. In memory bouncing, the kernel sets up a temporary buffer in physical memory that is large enough to hold the entire data block being transferred by the device. The data is then copied from the non-contiguous source memory to the temporary buffer, which is physically contiguous.
                        
                        - Bounce: Memory used for block device bounce buffers.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 65
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Bounce_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Bounce"
            },
          ]
          title = "Memory bounce"
          type  = "timeseries"
        },
      ]
      refresh       = "30s"
      schemaVersion = 39
      tags = [
        "linux-node-integration",
      ]
      templating = {
        list = [
          {
            label = "Prometheus data source"
            name  = "prometheus_datasource"
            query = "prometheus"
            regex = "(?!grafanacloud-usage|grafanacloud-ml-metrics).+"
            type  = "datasource"
          },
          {
            allValue = ".*"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Cluster"
            multi      = true
            name       = "cluster"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\"}, cluster)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Job"
            multi      = true
            name       = "job"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\"}, job)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = false
            label      = "Instance"
            multi      = false
            name       = "instance"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\"}, instance)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            hide  = 2
            label = "Loki data source"
            name  = "loki_datasource"
            query = "loki"
            regex = "(?!grafanacloud.+usage-insights|grafanacloud.+alert-state-history).+"
            type  = "datasource"
          },
        ]
      }
      time = {
        from = "now-30m"
        to   = "now"
      }
      timezone = "default"
      title    = "Linux node / memory"
      uid      = "node-memory"
    }
  )
}

resource "grafana_dashboard" "soc_dev_linux_node_network" {
  provider = grafana.soc_dev
  folder   = grafana_folder.integration_linux_node.id
  config_json = jsonencode(
    {
      annotations = {
        list = [
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", transport=\"kernel\", level=\"emerg\"}"
            hide        = true
            iconColor   = "light-purple"
            name        = "Critical system event"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Critical system event"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = <<-EOT
                            changes(
                            sum by (instance) (
                                group by (instance,release) (node_uname_info{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                )
                            [$__interval:1m] offset -$__interval) > 1
                        EOT
            hide        = true
            iconColor   = "light-blue"
            name        = "Kernel update"
            step        = "5m"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "Kernel update"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = "increase(node_vmstat_oom_kill{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__interval:] offset -$__interval)"
            hide        = true
            iconColor   = "light-purple"
            name        = "OOMkill"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "OOMkill"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable          = true
            expr            = "node_boot_time_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}*1000 > $__from < $__to"
            hide            = true
            iconColor       = "light-yellow"
            name            = "Reboot"
            tagKeys         = "cluster,job,instance"
            titleFormat     = "Reboot"
            useValueForTime = "on"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"init.scope\"} |= \"code=exited, status=1/FAILURE\""
            hide        = true
            iconColor   = "light-orange"
            name        = "Service failed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Service failed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session closed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session closed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session opened"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session opened"
          },
        ]
      }
      editable = false
      links = [
        {
          keepTime = true
          title    = "Back to Linux node / fleet"
          type     = "link"
          url      = "/d/node-fleet"
        },
        {
          keepTime = true
          title    = "Back to Linux node / overview"
          type     = "link"
          url      = "/d/nodes"
        },
        {
          asDropdown  = true
          includeVars = true
          keepTime    = true
          tags = [
            "linux-node-integration",
          ]
          title = "All Linux node /  dashboards"
          type  = "dashboards"
        },
      ]
      panels = [
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 0
          }
          panels = []
          title  = "Network"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Network interfaces overview."
          fieldConfig = {
            overrides = [
              {
                matcher = {
                  id      = "byName"
                  options = "Interface"
                }
                properties = [
                  {
                    id    = "custom.filterable"
                    value = true
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Speed"
                }
                properties = [
                  {
                    id    = "unit"
                    value = "bps"
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "Transmitted|Received"
                }
                properties = [
                  {
                    id = "custom.cellOptions"
                    value = {
                      mode             = "gradient"
                      type             = "gauge"
                      valueDisplayMode = "text"
                    }
                  },
                  {
                    id = "color"
                    value = {
                      mode = "continuous-BlYlRd"
                    }
                  },
                  {
                    id    = "max"
                    value = 100000000
                  },
                  {
                    id    = "unit"
                    value = "bps"
                  },
                ]
              },
              {
                matcher = {
                  id      = "byRegexp"
                  options = "Carrier|Up"
                }
                properties = [
                  {
                    id = "custom.cellOptions"
                    value = {
                      type = "color-text"
                    }
                  },
                  {
                    id = "mappings"
                    value = [
                      {
                        options = {
                          "0" = {
                            color = "light-red"
                            index = 0
                            text  = "Down"
                          }
                          "1" = {
                            color = "light-green"
                            index = 1
                            text  = "Up"
                          }
                        }
                        type = "value"
                      },
                    ]
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 24
            x = 0
            y = 1
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_network_up{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format       = "table"
              instant      = true
              legendFormat = "{{device}}"
              refId        = "Up"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_network_carrier{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format       = "table"
              instant      = true
              legendFormat = "{{device}}"
              refId        = "Carrier"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_transmit_bytes_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])*8"
              format       = "table"
              instant      = false
              legendFormat = "{{ device }} transmitted"
              refId        = "Transmitted"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_receive_bytes_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])*8"
              format       = "table"
              instant      = false
              legendFormat = "{{ device }} received"
              refId        = "Received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "node_arp_entries{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format  = "table"
              instant = true
              refId   = "ARP entries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "node_network_mtu_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format  = "table"
              instant = true
              refId   = "MTU"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "node_network_speed_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"} * 8"
              format  = "table"
              instant = true
              refId   = "Speed"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "node_network_transmit_queue_length{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format  = "table"
              instant = true
              refId   = "Queue length"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "node_network_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format  = "table"
              instant = true
              refId   = "Info"
            },
          ]
          title = "Network interfaces overview"
          transformations = [
            {
              id = "joinByField"
              options = {
                byField = "device"
                mode    = "outer"
              }
            },
            {
              id = "filterFieldsByName"
              options = {
                include = {
                  pattern = "device|duplex|address|Value.+"
                }
              }
            },
            {
              id = "renameByRegex"
              options = {
                regex         = "(Value) #(.*)"
                renamePattern = "$2"
              }
            },
            {
              id = "organize"
              options = {
                excludeByName = {
                  Info = true
                }
                renameByName = {
                  address = "Address"
                  device  = "Interface"
                  duplex  = "Duplex"
                }
              }
            },
            {
              id = "organize"
              options = {
                indexByName = {
                  Carrier     = 2
                  Interface   = 0
                  Received    = 3
                  Transmitted = 4
                  Up          = 1
                }
              }
            },
          ]
          type = "table"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Network traffic (bits per sec) measures data transmitted and received."
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No traffic"
              unit     = "bps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 9
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                irate(node_network_receive_bytes_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])*8
                                # only show interfaces that had traffic change at least once during selected dashboard interval:
                                and
                                increase(
                                    node_network_receive_bytes_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__range]
                                    ) > 0
                            EOT
              legendFormat = "{{ device }} received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                irate(node_network_transmit_bytes_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])*8
                                # only show interfaces that had traffic change at least once during selected dashboard interval:
                                and
                                increase(
                                    node_network_transmit_bytes_total{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__range]
                                    ) > 0
                            EOT
              legendFormat = "{{ device }} transmitted"
            },
          ]
          title = "Network traffic"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Network interfaces carrier status"
          fieldConfig = {
            defaults = {
              color = {
                mode = "fixed"
              }
              mappings = [
                {
                  options = {
                    "0" = {
                      color = "light-red"
                      index = 0
                      text  = "Down"
                    }
                    "1" = {
                      color = "light-green"
                      index = 1
                      text  = "Up"
                    }
                  }
                  type = "value"
                },
              ]
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 9
          }
          maxDataPoints = 50
          options = {
            showValue = "never"
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_network_carrier{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "{{device}}"
            },
          ]
          title = "Network interfaces carrier status"
          type  = "status-history"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Network errors refer to issues that occur during the transmission of data across a network. 
                        
                        These errors can result from various factors, including physical issues, jitter, collisions, noise and interference.
                        
                        Monitoring network errors is essential for diagnosing and resolving issues, as they can indicate problems with network hardware or environmental factors affecting network quality.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No errors"
              unit     = "pps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 17
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_receive_errs_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} errors received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_transmit_errs_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} errors transmitted"
            },
          ]
          title = "Network errors"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Dropped packets occur when data packets traveling through a network are intentionally discarded or lost due to congestion, resource limitations, or network configuration issues. 
                        
                        Common causes include network congestion, buffer overflows, QoS settings, and network errors, as corrupted or incomplete packets may be discarded by receiving devices.
                        
                        Dropped packets can impact network performance and lead to issues such as degraded voice or video quality in real-time applications.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No dropped packets"
              unit     = "pps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 17
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_receive_drop_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} received dropped"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_transmit_drop_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} transmitted dropped"
            },
          ]
          title = "Dropped packets"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Network packet count tracks the number of data packets transmitted and received over a network connection, providing insight into network activity and performance."
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No packets"
              unit     = "pps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 25
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_receive_packets_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_transmit_packets_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} transmitted"
            },
          ]
          title = "Network packets"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Multicast packets received and transmitted."
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No multicast packets"
              unit     = "pps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 25
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_receive_multicast_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_transmit_multicast_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} transmitted"
            },
          ]
          title = "Multicast packets"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Network FIFO (First-In, First-Out) refers to a buffer used by the network stack to store packets in a queue.
                        It is a mechanism used to manage network traffic and ensure that packets are delivered to their destination in the order they were received.
                        Packets are stored in the FIFO buffer until they can be transmitted or processed further.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No packets"
              unit     = "pps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 33
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_receive_fifo_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_transmit_fifo_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} transmitted"
            },
          ]
          title = "Network FIFO"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        - Compressed received: 
                        Number of correctly received compressed packets. This counters is only meaningful for interfaces which support packet compression (e.g. CSLIP, PPP).
                        
                        - Compressed transmitted:
                        Number of transmitted compressed packets. This counters is only meaningful for interfaces which support packet compression (e.g. CSLIP, PPP).
                        
                        https://docs.kernel.org/networking/statistics.html
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No packets"
              unit     = "pps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 33
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_receive_compressed_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_transmit_compressed_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "{{ device }} transmitted"
            },
          ]
          title = "Compressed packets"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        NF Conntrack is a component of the Linux kernel's netfilter framework that provides stateful packet inspection to track and manage network connections,
                        enforce firewall rules, perform NAT, and manage network address/port translation.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 0
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 41
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_nf_conntrack_entries{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "NF conntrack entries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_nf_conntrack_entries_limit{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "NF conntrack limits"
            },
          ]
          title = "NF conntrack"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Softnet packets are received by the network and queued for processing by the kernel's networking stack.
                        Softnet packets are usually generated by network traffic that is directed to the local host, and they are typically processed by the kernel's networking subsystem before being passed on to the relevant application.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "Dropped(-) | Processed(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No packets"
              unit     = "pps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/dropped/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 41
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_softnet_processed_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "CPU {{ cpu }} processed"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_softnet_dropped_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "CPU {{ cpu }} dropped"
            },
          ]
          title = "Softnet packets"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        "Softnet out of quota" is a network-related metric in Linux that measures the number of times the kernel's softirq processing was unable to handle incoming network traffic due to insufficient softirq processing capacity.
                        This means that the kernel has reached its processing capacity limit for incoming packets, and any additional packets will be dropped or deferred.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No packets"
              unit     = "pps"
            }
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 49
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_softnet_times_squeezed_total{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
              legendFormat = "CPU {{ cpu }} out of quota"
            },
          ]
          title = "Softnet out of quota"
          type  = "timeseries"
        },
        {
          collapsed = true
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 57
          }
          panels = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = "Number of sockets currently in use."
              fieldConfig = {
                defaults = {
                  custom = {
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                }
              }
              gridPos = {
                h = 8
                w = 24
                x = 0
                y = 58
              }
              id = 15
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_sockets_used{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv4 sockets in use"
                },
              ]
              title = "Sockets in use"
              type  = "timeseries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = <<-EOT
                                TCP sockets are used for establishing and managing network connections between two endpoints over the TCP/IP protocol.
                                
                                Orphan sockets: If a process terminates unexpectedly or is terminated without closing its sockets properly, the sockets may become orphaned.
                            EOT
              fieldConfig = {
                defaults = {
                  custom = {
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                }
              }
              gridPos = {
                h = 8
                w = 12
                x = 0
                y = 66
              }
              id = 16
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_TCP_alloc{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "Allocated"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_TCP_inuse{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv4 in use"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_TCP6_inuse{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv6 in use"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_TCP_orphan{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "Orphan sockets"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_TCP_tw{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "Time wait"
                },
              ]
              title = "Sockets TCP"
              type  = "timeseries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = <<-EOT
                                UDP (User Datagram Protocol) and UDPlite (UDP-Lite) sockets are used for transmitting and receiving data over the UDP and UDPlite protocols, respectively.
                                Both UDP and UDPlite are connectionless protocols that do not provide a reliable data delivery mechanism.
                            EOT
              fieldConfig = {
                defaults = {
                  custom = {
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                }
              }
              gridPos = {
                h = 8
                w = 12
                x = 12
                y = 66
              }
              id = 17
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_UDPLITE_inuse{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv4 UDPLITE in use"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_UDP_inuse{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv4 UDP in use"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_UDPLITE6_inuse{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv6 UDPLITE in use"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_UDP6_inuse{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv6 UDP in use"
                },
              ]
              title = "Sockets UDP"
              type  = "timeseries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = <<-EOT
                                Memory currently in use for sockets.
                            EOT
              fieldConfig = {
                defaults = {
                  custom = {
                    axisLabel         = "Pages"
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                }
                overrides = [
                  {
                    matcher = {
                      id      = "byRegexp"
                      options = "/bytes/"
                    }
                    properties = [
                      {
                        id    = "custom.axisLabel"
                        value = "Bytes"
                      },
                      {
                        id    = "custom.drawStyle"
                        value = "bars"
                      },
                      {
                        id = "custom.stacking"
                        value = {
                          group = "A"
                          mode  = "normal"
                        }
                      },
                      {
                        id    = "decimals"
                        value = 2
                      },
                      {
                        id    = "unit"
                        value = "bytes"
                      },
                    ]
                  },
                ]
              }
              gridPos = {
                h = 8
                w = 12
                x = 0
                y = 74
              }
              id            = 18
              maxDataPoints = 100
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_TCP_mem{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "Memory pages allocated for TCP sockets"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_UDP_mem{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "Memory pages allocated for UDP sockets"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_TCP_mem_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "Memory bytes allocated for TCP sockets"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_UDP_mem_bytes{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "Memory bytes allocated for UDP sockets"
                },
              ]
              title = "Sockets memory"
              type  = "timeseries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = <<-EOT
                                FRAG (IP fragment) sockets: Used to receive and process fragmented IP packets. FRAG sockets are useful in network monitoring and analysis.
                                
                                RAW sockets: Allow applications to send and receive raw IP packets directly without the need for a transport protocol like TCP or UDP.
                            EOT
              fieldConfig = {
                defaults = {
                  custom = {
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                }
              }
              gridPos = {
                h = 8
                w = 12
                x = 12
                y = 74
              }
              id = 19
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_FRAG_inuse{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv4 Frag sockets in use"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_FRAG6_inuse{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv6 Frag sockets in use"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_RAW_inuse{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv4 Raw sockets in use"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "node_sockstat_RAW6_inuse{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
                  legendFormat = "IPv6 Raw sockets in use"
                },
              ]
              title = "Sockets other"
              type  = "timeseries"
            },
          ]
          title = "Network sockets"
          type  = "row"
        },
        {
          collapsed = true
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 82
          }
          panels = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = "Rate of IP octets received and transmitted."
              fieldConfig = {
                defaults = {
                  custom = {
                    axisCenteredZero  = false
                    axisLabel         = "out(-) | in(+)"
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                  decimals = 1
                  noValue  = "No packets"
                  unit     = "oct/s"
                }
                overrides = [
                  {
                    matcher = {
                      id      = "byRegexp"
                      options = "/transmit|tx|out/"
                    }
                    properties = [
                      {
                        id    = "custom.transform"
                        value = "negative-Y"
                      },
                    ]
                  },
                ]
              }
              gridPos = {
                h = 8
                w = 24
                x = 0
                y = 83
              }
              id = 21
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_IpExt_InOctets{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "Octets received"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_IpExt_OutOctets{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "Octets transmitted"
                },
              ]
              title = "IP octets"
              type  = "timeseries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = "Rate of TCP segments received and transmitted."
              fieldConfig = {
                defaults = {
                  custom = {
                    axisCenteredZero  = false
                    axisLabel         = "out(-) | in(+)"
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                  decimals = 1
                  noValue  = "No packets"
                  unit     = "seg/s"
                }
                overrides = [
                  {
                    matcher = {
                      id      = "byRegexp"
                      options = "/transmit|tx|out/"
                    }
                    properties = [
                      {
                        id    = "custom.transform"
                        value = "negative-Y"
                      },
                    ]
                  },
                ]
              }
              gridPos = {
                h = 8
                w = 12
                x = 0
                y = 91
              }
              id = 22
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Tcp_InSegs{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "TCP received"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Tcp_OutSegs{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "TCP transmitted"
                },
              ]
              title = "TCP segments"
              type  = "timeseries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = "Rate of TCP errors."
              fieldConfig = {
                defaults = {
                  custom = {
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                  decimals = 1
                  noValue  = "No errors"
                  unit     = "err/s"
                }
              }
              gridPos = {
                h = 8
                w = 12
                x = 12
                y = 91
              }
              id = 23
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_TcpExt_ListenOverflows{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "TCP overflow"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_TcpExt_ListenDrops{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "TCP ListenDrops - SYNs to LISTEN sockets ignored"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_TcpExt_TCPSynRetrans{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "TCP SYN rentransmits"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Tcp_RetransSegs{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "TCP retransmitted segments, containing one or more previously transmitted octets"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Tcp_InErrs{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "TCP received with errors"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Tcp_OutRsts{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "TCP segments sent with RST flag"
                },
              ]
              title = "TCP errors rate"
              type  = "timeseries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = "Rate of UDP datagrams received and transmitted."
              fieldConfig = {
                defaults = {
                  custom = {
                    axisCenteredZero  = false
                    axisLabel         = "out(-) | in(+)"
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                  decimals = 1
                  noValue  = "No packets"
                  unit     = "dat/s"
                }
                overrides = [
                  {
                    matcher = {
                      id      = "byRegexp"
                      options = "/transmit|tx|out/"
                    }
                    properties = [
                      {
                        id    = "custom.transform"
                        value = "negative-Y"
                      },
                    ]
                  },
                ]
              }
              gridPos = {
                h = 8
                w = 12
                x = 0
                y = 99
              }
              id = 24
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp_InDatagrams{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP received"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp_OutDatagrams{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP transmitted"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp6_InDatagrams{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP6 received"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp6_OutDatagrams{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP6 transmitted"
                },
              ]
              title = "UDP datagrams"
              type  = "timeseries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = "Rate of UDP errors."
              fieldConfig = {
                defaults = {
                  custom = {
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                  decimals = 1
                  noValue  = "No errors"
                  unit     = "err/s"
                }
              }
              gridPos = {
                h = 8
                w = 12
                x = 12
                y = 99
              }
              id = 25
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_UdpLite_InErrors{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDPLite InErrors"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp_InErrors{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP InErrors"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp6_InErrors{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP6 InErrors"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp_NoPorts{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP NoPorts"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp6_NoPorts{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP6 NoPorts"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp_RcvbufErrors{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP receive buffer errors"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp6_RcvbufErrors{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP6 receive buffer errors"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp_SndbufErrors{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP transmit buffer errors"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Udp6_SndbufErrors{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "UDP6 transmit buffer errors"
                },
              ]
              title = "UDP errors rate"
              type  = "timeseries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = "Rate of ICMP messages, like 'ping', received and transmitted."
              fieldConfig = {
                defaults = {
                  custom = {
                    axisCenteredZero  = false
                    axisLabel         = "out(-) | in(+)"
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                  decimals = 1
                  noValue  = "No packets"
                  unit     = "msg/s"
                }
                overrides = [
                  {
                    matcher = {
                      id      = "byRegexp"
                      options = "/transmit|tx|out/"
                    }
                    properties = [
                      {
                        id    = "custom.transform"
                        value = "negative-Y"
                      },
                    ]
                  },
                ]
              }
              gridPos = {
                h = 8
                w = 12
                x = 0
                y = 107
              }
              id = 26
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Icmp_InMsgs{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "ICMP received"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Icmp_OutMsgs{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "ICMP transmitted"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Icmp6_InMsgs{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "ICMP6 received"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Icmp6_OutMsgs{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "ICMP6 transmitted"
                },
              ]
              title = "ICMP messages"
              type  = "timeseries"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              description = "Rate of ICMP messages received and transmitted with errors."
              fieldConfig = {
                defaults = {
                  custom = {
                    fillOpacity       = 30
                    gradientMode      = "opacity"
                    lineInterpolation = "smooth"
                    lineWidth         = 2
                    showPoints        = "never"
                  }
                  decimals = 1
                  noValue  = "No errors"
                  unit     = "err/s"
                }
              }
              gridPos = {
                h = 8
                w = 12
                x = 12
                y = 107
              }
              id = 27
              options = {
                legend = {
                  calcs       = []
                  displayMode = "list"
                }
                tooltip = {
                  mode = "multi"
                  sort = "desc"
                }
              }
              pluginVersion = "v11.0.0"
              targets = [
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Icmp_InErrors{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "ICMP6 errors"
                },
                {
                  datasource = {
                    type = "prometheus"
                    uid  = data.grafana_data_source.soc_dev_prometheus.uid
                  }
                  expr         = "irate(node_netstat_Icmp6_InErrors{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])"
                  legendFormat = "ICMP6 errors"
                },
              ]
              title = "ICMP errors rate"
              type  = "timeseries"
            },
          ]
          title = "Network netstat"
          type  = "row"
        },
      ]
      refresh       = "30s"
      schemaVersion = 39
      tags = [
        "linux-node-integration",
      ]
      templating = {
        list = [
          {
            label = "Prometheus data source"
            name  = "prometheus_datasource"
            query = "prometheus"
            regex = "(?!grafanacloud-usage|grafanacloud-ml-metrics).+"
            type  = "datasource"
          },
          {
            allValue = ".*"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Cluster"
            multi      = true
            name       = "cluster"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\"}, cluster)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Job"
            multi      = true
            name       = "job"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\"}, job)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = false
            label      = "Instance"
            multi      = false
            name       = "instance"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\"}, instance)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            hide  = 2
            label = "Loki data source"
            name  = "loki_datasource"
            query = "loki"
            regex = "(?!grafanacloud.+usage-insights|grafanacloud.+alert-state-history).+"
            type  = "datasource"
          },
        ]
      }
      time = {
        from = "now-30m"
        to   = "now"
      }
      timezone = "default"
      title    = "Linux node / network"
      uid      = "node-network"
    }
  )
}

resource "grafana_dashboard" "soc_dev_linux_node_nodes" {
  provider = grafana.soc_dev
  folder   = grafana_folder.integration_linux_node.id
  config_json = jsonencode(
    {
      annotations = {
        list = [
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", transport=\"kernel\", level=\"emerg\"}"
            hide        = true
            iconColor   = "light-purple"
            name        = "Critical system event"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Critical system event"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = <<-EOT
                            changes(
                            sum by (instance) (
                                group by (instance,release) (node_uname_info{job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                )
                            [$__interval:1m] offset -$__interval) > 1
                        EOT
            hide        = true
            iconColor   = "light-blue"
            name        = "Kernel update"
            step        = "5m"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "Kernel update"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable      = true
            expr        = "increase(node_vmstat_oom_kill{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__interval:] offset -$__interval)"
            hide        = true
            iconColor   = "light-purple"
            name        = "OOMkill"
            tagKeys     = "cluster,job,instance"
            textFormat  = ""
            titleFormat = "OOMkill"
          },
          {
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            enable          = true
            expr            = "node_boot_time_seconds{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}*1000 > $__from < $__to"
            hide            = true
            iconColor       = "light-yellow"
            name            = "Reboot"
            tagKeys         = "cluster,job,instance"
            titleFormat     = "Reboot"
            useValueForTime = "on"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"init.scope\"} |= \"code=exited, status=1/FAILURE\""
            hide        = true
            iconColor   = "light-orange"
            name        = "Service failed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Service failed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session closed"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session closed"
          },
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            enable      = true
            expr        = "{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", unit=\"systemd-logind.service\"}|= \"New session\""
            hide        = true
            name        = "Session opened"
            tagKeys     = "cluster,job,instance,level"
            titleFormat = "Session opened"
          },
        ]
      }
      editable = false
      links = [
        {
          keepTime = true
          title    = "Back to Linux node / fleet"
          type     = "link"
          url      = "/d/node-fleet"
        },
        {
          asDropdown  = true
          includeVars = true
          keepTime    = true
          tags = [
            "linux-node-integration",
          ]
          title = "All Linux node /  dashboards"
          type  = "dashboards"
        },
      ]
      panels = [
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 0
          }
          panels = []
          title  = "Overview"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "The duration of time that has passed since the last reboot or system start."
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "thresholds"
              }
              decimals = 1
              thresholds = {
                mode = "absolute"
                steps = [
                  {
                    color = "orange"
                    value = null
                  },
                  {
                    color = "text"
                    value = 600
                  },
                ]
              }
              unit = "dtdurations"
            }
          }
          gridPos = {
            h = 2
            w = 6
            x = 0
            y = 1
          }
          options = {
            colorMode = "value"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr = "time() - node_boot_time_seconds{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
            },
          ]
          title = "Uptime"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "System's hostname."
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
            }
          }
          gridPos = {
            h = 2
            w = 6
            x = 6
            y = 1
          }
          options = {
            colorMode = "fixed"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
              fields = "/^nodename$/"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr   = "node_uname_info{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format = "table"
            },
          ]
          title = "Hostname"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Kernel version of linux host."
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
            }
          }
          gridPos = {
            h = 2
            w = 6
            x = 12
            y = 1
          }
          options = {
            colorMode = "fixed"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
              fields = "/^release$/"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr   = "node_uname_info{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format = "table"
            },
          ]
          title = "Kernel version"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Operating system"
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
            }
          }
          gridPos = {
            h = 2
            w = 6
            x = 18
            y = 1
          }
          options = {
            colorMode = "fixed"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
              fields = "/^pretty_name$/"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr   = <<-EOT
                                node_os_info{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}
                            EOT
              format = "table"
            },
          ]
          title = "OS"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        CPU count is the number of processor cores or central processing units (CPUs) in a computer,
                        determining its processing capability and ability to handle tasks concurrently.
                    EOT
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
              unit = "none"
            }
          }
          gridPos = {
            h = 2
            w = 6
            x = 0
            y = 3
          }
          options = {
            colorMode = "fixed"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "count without (cpu) (node_cpu_seconds_total{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", mode=\"idle\"})"
              legendFormat = "Cores"
            },
          ]
          title = "CPU count"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Amount of random-access memory (RAM) installed.
                        It represents the system's available working memory that applications and the operating system use to perform tasks.
                        A higher memory total generally leads to better system performance and the ability to run more demanding applications and processes simultaneously.
                    EOT
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
              unit = "bytes"
            }
          }
          gridPos = {
            h = 2
            w = 6
            x = 6
            y = 3
          }
          options = {
            colorMode = "fixed"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_MemTotal_bytes{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory total"
            },
          ]
          title = "Memory total"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Total swap available.
                        
                        Swap is a space on a storage device (usually a dedicated swap partition or a swap file) 
                        used as virtual memory when the physical RAM (random-access memory) is fully utilized.
                        Swap space helps prevent memory-related performance issues by temporarily transferring less-used data from RAM to disk,
                        freeing up physical memory for active processes and applications.
                    EOT
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
              unit = "bytes"
            }
          }
          gridPos = {
            h = 2
            w = 6
            x = 12
            y = 3
          }
          options = {
            colorMode = "fixed"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr = "node_memory_SwapTotal_bytes{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
            },
          ]
          title = "Total swap"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Total capacity on the primary mount point /.
                    EOT
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "fixed"
              }
              unit = "bytes"
            }
          }
          gridPos = {
            h = 2
            w = 6
            x = 18
            y = 3
          }
          options = {
            colorMode = "fixed"
            graphMode = "none"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr = "node_filesystem_size_bytes{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", mountpoint=\"/\", fstype!=\"rootfs\"}"
            },
          ]
          title = "Root mount size"
          type  = "stat"
        },
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 5
          }
          panels = []
          title  = "CPU"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Total CPU utilization percent is a metric that indicates the overall level of central processing unit (CPU) usage in a computer system.
                        It represents the combined load placed on all CPU cores or processors.
                        
                        For instance, if the total CPU utilization percent is 50%, it means that,
                        on average, half of the CPU's processing capacity is being used to execute tasks. A higher percentage indicates that the CPU is working more intensively, potentially leading to system slowdowns if it remains consistently high.
                    EOT
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "continuous-BlYlRd"
              }
              decimals = 1
              max      = 100
              min      = 0
              unit     = "percent"
            }
          }
          gridPos = {
            h = 6
            w = 6
            x = 0
            y = 6
          }
          options = {
            colorMode = "value"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                (((count by (instance) (count(node_cpu_seconds_total{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) by (cpu, instance))) 
                                - 
                                sum by (instance) (sum by (instance, mode)(irate(node_cpu_seconds_total{asserts_env=~"$env", asserts_site=~"$site", mode=~'idle|iowait|steal',job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])))) * 100) 
                                / 
                                count by(instance) (count(node_cpu_seconds_total{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) by (cpu, instance))
                            EOT
              legendFormat = "CPU usage"
            },
          ]
          title = "CPU usage"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        Total CPU utilization percent is a metric that indicates the overall level of central processing unit (CPU) usage in a computer system.
                        It represents the combined load placed on all CPU cores or processors.
                        
                        For instance, if the total CPU utilization percent is 50%, it means that,
                        on average, half of the CPU's processing capacity is being used to execute tasks. A higher percentage indicates that the CPU is working more intensively, potentially leading to system slowdowns if it remains consistently high.
                    EOT
          fieldConfig = {
            defaults = {
              color = {
                mode = "continuous-BlYlRd"
              }
              custom = {
                fillOpacity       = 30
                gradientMode      = "scheme"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              max      = 100
              min      = 0
              unit     = "percent"
            }
          }
          gridPos = {
            h = 6
            w = 12
            x = 6
            y = 6
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                (100 - sum without (mode) (rate(node_cpu_seconds_total{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance", mode=~"idle|iowait|steal"}[$__rate_interval])) * 100 )
                            EOT
              legendFormat = "CPU {{cpu}}"
            },
          ]
          title = "CPU usage"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        System load average over the previous 1, 5, and 15 minute ranges.
                        
                        A measurement of how many processes are waiting for CPU cycles. The maximum number is the number of CPU cores for the node.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 0
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "short"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "Cores"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 6
            w = 6
            x = 18
            y = 6
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_load1{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "1m"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_load5{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "5m"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_load15{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "15m"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "count without (cpu) (node_cpu_seconds_total{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", mode=\"idle\"})"
              legendFormat = "Cores"
            },
          ]
          title = "Load average"
          type  = "timeseries"
        },
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 12
          }
          panels = []
          title  = "Memory"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "RAM (random-access memory) currently in use by the operating system and running applications, in percent."
          fieldConfig = {
            defaults = {
              color = {
                fixedColor = "text"
                mode       = "continuous-BlYlRd"
              }
              decimals = 1
              max      = 100
              min      = 0
              unit     = "percent"
            }
          }
          gridPos = {
            h = 6
            w = 6
            x = 0
            y = 13
          }
          options = {
            colorMode = "value"
            reduceOptions = {
              calcs = [
                "lastNotNull",
              ]
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr = <<-EOT
                                100 -
                                (
                                  avg by (instance) (node_memory_MemAvailable_bytes{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}) /
                                  avg by (instance) (node_memory_MemTotal_bytes{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"})
                                * 100
                                )
                            EOT
            },
          ]
          title = "Memory usage"
          type  = "stat"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        - Used: The amount of physical memory currently in use by the system.
                        - Cached: The amount of physical memory used for caching data from disk. The Linux kernel uses available memory to cache data that is read from or written to disk. This helps speed up disk access times.
                        - Free: The amount of physical memory that is currently not in use.
                        - Buffers: The amount of physical memory used for temporary storage of data being transferred between devices or applications.
                        - Available: The amount of physical memory that is available for use by applications. This takes into account memory that is currently being used for caching but can be freed up if needed.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              min  = 0
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = ".*(T|t)otal.*"
                }
                properties = [
                  {
                    id = "color"
                    value = {
                      fixedColor = "light-orange"
                      mode       = "fixed"
                    }
                  },
                  {
                    id    = "custom.fillOpacity"
                    value = 0
                  },
                  {
                    id = "custom.lineStyle"
                    value = {
                      dash = [
                        10,
                        10,
                      ]
                      fill = "dash"
                    }
                  },
                ]
              },
              {
                __systemRef = "hideSeriesFrom"
                matcher = {
                  id = "byNames"
                  options = {
                    mode = "exclude"
                    names = [
                      "Memory total",
                      "Memory used",
                    ]
                    prefix   = "All except:"
                    readOnly = true
                  }
                }
                properties = [
                  {
                    id = "custom.hideFrom"
                    value = {
                      legend  = false
                      tooltip = false
                      viz     = true
                    }
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 6
            w = 18
            x = 6
            y = 13
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                (
                                  node_memory_MemTotal_bytes{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}
                                -
                                  node_memory_MemFree_bytes{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}
                                -
                                  node_memory_Buffers_bytes{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}
                                -
                                  node_memory_Cached_bytes{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}
                                )
                            EOT
              legendFormat = "Memory used"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Cached_bytes{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory cached"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_MemAvailable_bytes{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory available"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_Buffers_bytes{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory buffers"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_MemFree_bytes{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory free"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_memory_MemTotal_bytes{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              legendFormat = "Memory total"
            },
          ]
          title = "Memory usage"
          type  = "timeseries"
        },
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 19
          }
          panels = []
          title  = "Disk"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Disk read/writes in bytes per second."
          fieldConfig = {
            defaults = {
              custom = {
                fillOpacity       = 1
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              unit = "Bps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/time|used|busy|util/"
                }
                properties = [
                  {
                    id    = "custom.axisSoftMax"
                    value = 100
                  },
                  {
                    id    = "custom.drawStyle"
                    value = "points"
                  },
                  {
                    id    = "unit"
                    value = "percent"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 20
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_disk_read_bytes_total{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", device!=\"\"}[$__rate_interval])"
              legendFormat = "{{ device }} read"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_disk_written_bytes_total{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", device!=\"\"}[$__rate_interval])"
              legendFormat = "{{ device }} written"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_disk_io_time_seconds_total{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\", device!=\"\"}[$__rate_interval])"
              legendFormat = "{{ device }} io util"
            },
          ]
          title = "Disk reads/writes"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Disk utilisation in percent, by mountpoint. Some duplication can occur if the same filesystem is mounted in multiple locations."
          fieldConfig = {
            defaults = {
              thresholds = {
                steps = [
                  {
                    color = "light-blue"
                    value = null
                  },
                  {
                    color = "light-yellow"
                    value = 0.8
                  },
                  {
                    color = "light-red"
                    value = 0.9
                  },
                ]
              }
              unit = "bytes"
            }
            overrides = [
              {
                matcher = {
                  id      = "byName"
                  options = "Mounted on"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 260
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Size"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 80
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Used"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 80
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Available"
                }
                properties = [
                  {
                    id    = "custom.width"
                    value = 80
                  },
                ]
              },
              {
                matcher = {
                  id      = "byName"
                  options = "Used, %"
                }
                properties = [
                  {
                    id = "custom.cellOptions"
                    value = {
                      mode             = "basic"
                      type             = "gauge"
                      valueDisplayMode = "text"
                    }
                  },
                  {
                    id    = "max"
                    value = 1
                  },
                  {
                    id    = "min"
                    value = 0
                  },
                  {
                    id    = "unit"
                    value = "percentunit"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 20
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr    = "node_filesystem_size_bytes{asserts_env=~\"$env\", asserts_site=~\"$site\", fstype!=\"\", mountpoint!=\"\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format  = "table"
              instant = true
              refId   = "TOTAL"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "node_filesystem_avail_bytes{asserts_env=~\"$env\", asserts_site=~\"$site\", fstype!=\"\", mountpoint!=\"\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}"
              format       = "table"
              instant      = true
              legendFormat = "{{ mountpoint }} free"
              refId        = "FREE"
            },
          ]
          title = "Disk space usage"
          transformations = [
            {
              id = "groupBy"
              options = {
                fields = {
                  "Value #FREE" = {
                    aggregations = [
                      "lastNotNull",
                    ]
                    operation = "aggregate"
                  }
                  "Value #TOTAL" = {
                    aggregations = [
                      "lastNotNull",
                    ]
                    operation = "aggregate"
                  }
                  mountpoint = {
                    aggregations = []
                    operation    = "groupby"
                  }
                }
              }
            },
            {
              id      = "merge"
              options = {}
            },
            {
              id = "calculateField"
              options = {
                alias = "Used"
                binary = {
                  left     = "Value #TOTAL (lastNotNull)"
                  operator = "-"
                  reducer  = "sum"
                  right    = "Value #FREE (lastNotNull)"
                }
                mode = "binary"
                reduce = {
                  reducer = "sum"
                }
              }
            },
            {
              id = "calculateField"
              options = {
                alias = "Used, %"
                binary = {
                  left     = "Used"
                  operator = "/"
                  reducer  = "sum"
                  right    = "Value #TOTAL (lastNotNull)"
                }
                mode = "binary"
                reduce = {
                  reducer = "sum"
                }
              }
            },
            {
              id = "organize"
              options = {
                excludeByName = {}
                indexByName = {
                  Used                         = 3
                  "Used, %"                    = 4
                  "Value #FREE (lastNotNull)"  = 2
                  "Value #TOTAL (lastNotNull)" = 1
                  mountpoint                   = 0
                }
                renameByName = {
                  "Value #FREE (lastNotNull)"  = "Available"
                  "Value #TOTAL (lastNotNull)" = "Size"
                  mountpoint                   = "Mounted on"
                }
              }
            },
            {
              id = "sortBy"
              options = {
                fields = {}
                sort = [
                  {
                    desc  = false
                    field = "Mounted on"
                  },
                ]
              }
            },
          ]
          type = "table"
        },
        {
          collapsed = false
          gridPos = {
            h = 1
            w = 0
            x = 0
            y = 28
          }
          panels = []
          title  = "Network"
          type   = "row"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = "Network traffic (bits per sec) measures data transmitted and received."
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No traffic"
              unit     = "bps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 0
            y = 29
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                irate(node_network_receive_bytes_total{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])*8
                                # only show interfaces that had traffic change at least once during selected dashboard interval:
                                and
                                increase(
                                    node_network_receive_bytes_total{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__range]
                                    ) > 0
                            EOT
              legendFormat = "{{ device }} received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = <<-EOT
                                irate(node_network_transmit_bytes_total{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__rate_interval])*8
                                # only show interfaces that had traffic change at least once during selected dashboard interval:
                                and
                                increase(
                                    node_network_transmit_bytes_total{asserts_env=~"$env", asserts_site=~"$site", job=~"integrations/(node_exporter|unix)",cluster=~"$cluster",job=~"$job",instance=~"$instance"}[$__range]
                                    ) > 0
                            EOT
              legendFormat = "{{ device }} transmitted"
            },
          ]
          title = "Network traffic"
          type  = "timeseries"
        },
        {
          datasource = {
            type = "prometheus"
            uid  = data.grafana_data_source.soc_dev_prometheus.uid
          }
          description = <<-EOT
                        **Network errors**:
                        
                        Network errors refer to issues that occur during the transmission of data across a network. 
                        
                        These errors can result from various factors, including physical issues, jitter, collisions, noise and interference.
                        
                        Monitoring network errors is essential for diagnosing and resolving issues, as they can indicate problems with network hardware or environmental factors affecting network quality.
                        
                        **Dropped packets**:
                        
                        Dropped packets occur when data packets traveling through a network are intentionally discarded or lost due to congestion, resource limitations, or network configuration issues. 
                        
                        Common causes include network congestion, buffer overflows, QoS settings, and network errors, as corrupted or incomplete packets may be discarded by receiving devices.
                        
                        Dropped packets can impact network performance and lead to issues such as degraded voice or video quality in real-time applications.
                    EOT
          fieldConfig = {
            defaults = {
              custom = {
                axisCenteredZero  = false
                axisLabel         = "out(-) | in(+)"
                fillOpacity       = 30
                gradientMode      = "opacity"
                lineInterpolation = "smooth"
                lineWidth         = 2
                showPoints        = "never"
              }
              decimals = 1
              noValue  = "No errors"
              unit     = "pps"
            }
            overrides = [
              {
                matcher = {
                  id      = "byRegexp"
                  options = "/transmit|tx|out/"
                }
                properties = [
                  {
                    id    = "custom.transform"
                    value = "negative-Y"
                  },
                ]
              },
            ]
          }
          gridPos = {
            h = 8
            w = 12
            x = 12
            y = 29
          }
          options = {
            legend = {
              calcs       = []
              displayMode = "list"
            }
            tooltip = {
              mode = "multi"
              sort = "desc"
            }
          }
          pluginVersion = "v11.0.0"
          targets = [
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_transmit_errs_total{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])>0"
              legendFormat = "{{ device }} errors transmitted"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_receive_errs_total{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])>0"
              legendFormat = "{{ device }} errors received"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_transmit_drop_total{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])>0"
              legendFormat = "{{ device }} transmitted dropped"
            },
            {
              datasource = {
                type = "prometheus"
                uid  = data.grafana_data_source.soc_dev_prometheus.uid
              }
              expr         = "irate(node_network_receive_drop_total{asserts_env=~\"$env\", asserts_site=~\"$site\", job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\",instance=~\"$instance\"}[$__rate_interval])>0"
              legendFormat = "{{ device }} received dropped"
            },
          ]
          title = "Network errors and dropped packets"
          type  = "timeseries"
        },
      ]
      refresh       = "30s"
      schemaVersion = 39
      tags = [
        "linux-node-integration",
      ]
      templating = {
        list = [
          {
            allValue = ".*"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            hide       = 2
            includeAll = true
            label      = "Asserts environment"
            multi      = false
            name       = "env"
            query      = "label_values(asserts:mixin_workload_job, asserts_env)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".*"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            hide       = 2
            includeAll = true
            label      = "Asserts site"
            multi      = false
            name       = "site"
            query      = "label_values(asserts:mixin_workload_job{asserts_env=~\"$env\"}, asserts_site)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            label = "Prometheus data source"
            name  = "prometheus_datasource"
            query = "prometheus"
            regex = "(?!grafanacloud-usage|grafanacloud-ml-metrics).+"
            type  = "datasource"
          },
          {
            allValue = ".*"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Cluster"
            multi      = true
            name       = "cluster"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\"}, cluster)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = true
            label      = "Job"
            multi      = true
            name       = "job"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\"}, job)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            allValue = ".+"
            datasource = {
              type = "prometheus"
              uid  = data.grafana_data_source.soc_dev_prometheus.uid
            }
            includeAll = false
            label      = "Instance"
            multi      = false
            name       = "instance"
            query      = "label_values(node_uname_info{job=~\"integrations/(node_exporter|unix)\",cluster=~\"$cluster\",job=~\"$job\"}, instance)"
            refresh    = 2
            sort       = 1
            type       = "query"
          },
          {
            hide  = 2
            label = "Loki data source"
            name  = "loki_datasource"
            query = "loki"
            regex = "(?!grafanacloud.+usage-insights|grafanacloud.+alert-state-history).+"
            type  = "datasource"
          },
        ]
      }
      time = {
        from = "now-30m"
        to   = "now"
      }
      timezone = "default"
      title    = "Linux node / overview"
      uid      = "nodes"
    }
  )
}

resource "grafana_folder" "grafana_cloud_folder" {
  provider = grafana.soc_dev
  title    = "GrafanaCloud"
}

resource "grafana_folder_permission" "soc_dev_grafana_cloud_folder_permission" {
  provider   = grafana.soc_dev
  folder_uid = grafana_folder.grafana_cloud_folder.uid
  org_id     = "0"

  permissions {
    permission = "Edit"
    role       = "Editor"
    team_id    = "0"
    user_id    = "0"
  }
  permissions {
    permission = "View"
    role       = "Viewer"
    team_id    = "0"
    user_id    = "0"
  }
}

data "grafana_dashboard" "soc_dev_card_mgmt" {
  provider = grafana.soc_dev
  uid      = "cardinality-management"
}

data "grafana_dashboard" "soc_dev_card_mgmt_metrics" {
  provider = grafana.soc_dev
  uid      = "cardinality-management-metrics-detail"
}

data "grafana_dashboard" "soc_dev_card_mgmt_labels" {
  provider = grafana.soc_dev
  uid      = "cardinality-management-label-detail"
}

data "grafana_dashboard" "soc_dev_grafana_cloud_cloud_logs_exports_insights" {
  provider = grafana.soc_dev
  uid      = "4_D6mSh4z"
}

data "grafana_dashboard" "soc_dev_grafana_cloud_billing_usage" {
  provider = grafana.soc_dev
  uid      = "11668ff0-4573-40b9-bf91-817eb5c6c7b6"
}

data "grafana_dashboard" "soc_dev_grafana_cloud_usage_overview" {
  provider = grafana.soc_dev
  uid      = "XU8HAD5Gk"
}

data "grafana_dashboard" "soc_dev_grafana_cloud_usage_data_sources" {
  provider = grafana.soc_dev
  uid      = "AEbrOO2Mz"
}

data "grafana_dashboard" "soc_dev_grafana_cloud_usage_query_errors" {
  provider = grafana.soc_dev
  uid      = "MpmkYhRVz"
}

data "grafana_dashboard" "soc_dev_grafana_cloud_usage_alert_mgr" {
  provider = grafana.soc_dev
  uid      = "ntS5Ujs7z"
}

data "grafana_dashboard" "soc_dev_grafana_cloud_usage_metrics_ingst" {
  provider = grafana.soc_dev
  uid      = "cdn9jukg55bswb"
}

data "grafana_dashboard" "soc_dev_grafana_cloud_usage_loki_dd" {
  provider = grafana.soc_dev
  uid      = "cdybdibbio2dcd"
}

data "grafana_dashboard" "soc_dev_grafana_cloud_alert_group_insights" {
  provider = grafana.soc_dev
  uid      = "a9240249-f7da-4881-af55-cbdf52e983b5"
}

data "grafana_dashboard" "soc_dev_grafana_cloud_incident_insights" {
  provider = grafana.soc_dev
  uid      = "009d62c5-179c-4dcf-9bbc-722d5cf8e2c8"
}
# =============================================================================
# Ghost Stack Backup Alerting (GHO-98)
# =============================================================================

# Folder for backup alert rules and dashboard
resource "grafana_folder" "ghost_stack_folder" {
  provider = grafana.soc_dev
  title    = "Ghost Stack"
}

resource "grafana_folder_permission" "ghost_stack_folder_permission" {
  provider   = grafana.soc_dev
  folder_uid = grafana_folder.ghost_stack_folder.uid
  org_id     = "0"

  permissions {
    permission = "Edit"
    role       = "Editor"
  }
  permissions {
    permission = "View"
    role       = "Viewer"
  }
}

# PagerDuty contact point for backup alerts
resource "grafana_contact_point" "pagerduty_backup" {
  provider = grafana.soc_dev
  name     = "PagerDuty - Ghost Stack Backup"

  pagerduty {
    integration_key         = var.pagerduty_backup_integration_key
    severity                = "critical"
    disable_resolve_message = false
    class                   = "backup"
    component               = "ghost-backup.service"
    group                   = "ghost-stack-dev-01"
  }
}

# Root notification policy — routes backup alerts to PagerDuty
# NOTE: grafana_notification_policy is a singleton that replaces Grafana's entire
# alert routing tree. Future alert groups must add policy blocks here.
resource "grafana_notification_policy" "root" {
  provider      = grafana.soc_dev
  contact_point = grafana_contact_point.pagerduty_backup.name
  group_by      = ["alertname", "grafana_folder", "service"]

  policy {
    matcher {
      label = "service"
      match = "="
      value = "backup"
    }
    contact_point   = grafana_contact_point.pagerduty_backup.name
    group_by        = ["alertname"]
    group_wait      = "30s"
    group_interval  = "5m"
    repeat_interval = "4h"
  }
}

# Alert rules — 3 rules covering failure, missed window, compose recovery
resource "grafana_rule_group" "ghost_stack_backup" {
  provider         = grafana.soc_dev
  org_id           = "0"
  folder_uid       = grafana_folder.ghost_stack_folder.uid
  name             = "Ghost Stack Backup"
  interval_seconds = 300

  # Rule 1: Backup failure — ERROR log line seen in last 10 minutes
  rule {
    name      = "Backup Failure"
    condition = "C"
    for       = "0s"

    no_data_state  = "NoData"
    exec_err_state = "Error"

    annotations = {
      summary     = "Ghost backup failed"
      description = "ghost-backup.service logged an ERROR in the last 10 minutes. Check: journalctl -u ghost-backup -n 50"
      runbook_url = "https://github.com/noahwhite/ghost-stack/blob/main/docs/runbooks/backup-restore.md"
    }

    labels = {
      service  = "backup"
      severity = "critical"
    }

    data {
      ref_id         = "A"
      datasource_uid = data.grafana_data_source.soc_dev_loki.uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        datasource = {
          type = "loki"
          uid  = data.grafana_data_source.soc_dev_loki.uid
        }
        editorMode   = "code"
        expr         = "{job=~\"integrations/(node_exporter|unix)\", unit=\"ghost-backup.service\"} |= \"ERROR:\""
        queryType    = "range"
        refId        = "A"
        legendFormat = ""
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        conditions = [{
          evaluator = { params = [], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["A"] }
          reducer   = { params = [], type = "count" }
          type      = "query"
        }]
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "A"
        reducer    = "count"
        refId      = "B"
        type       = "reduce"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        conditions = [{
          evaluator = { params = [0], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["B"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "B"
        refId      = "C"
        type       = "threshold"
      })
    }
  }

  # Rule 2: Missed backup window — no "Backup complete." seen in 26 hours
  rule {
    name      = "Missed Backup Window"
    condition = "C"
    for       = "1h"

    no_data_state  = "Alerting"
    exec_err_state = "Alerting"

    annotations = {
      summary     = "No successful backup in 26 hours"
      description = "ghost-backup.service has not logged a successful completion in the past 26 hours. Check timer: systemctl list-timers ghost-backup.timer"
      runbook_url = "https://github.com/noahwhite/ghost-stack/blob/main/docs/runbooks/backup-restore.md"
    }

    labels = {
      service  = "backup"
      severity = "critical"
    }

    data {
      ref_id         = "A"
      datasource_uid = data.grafana_data_source.soc_dev_loki.uid
      relative_time_range {
        from = 93600 # 26 hours
        to   = 0
      }
      model = jsonencode({
        datasource = {
          type = "loki"
          uid  = data.grafana_data_source.soc_dev_loki.uid
        }
        editorMode   = "code"
        expr         = "count_over_time({job=~\"integrations/(node_exporter|unix)\", unit=\"ghost-backup.service\"} |= \"Backup complete.\" [26h])"
        queryType    = "range"
        refId        = "A"
        legendFormat = ""
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        conditions = [{
          evaluator = { params = [], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["A"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "A"
        reducer    = "last"
        refId      = "B"
        type       = "reduce"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        conditions = [{
          evaluator = { params = [1], type = "lt" }
          operator  = { type = "and" }
          query     = { params = ["B"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "B"
        refId      = "C"
        type       = "threshold"
      })
    }
  }

  # Rule 3: Ghost-compose not running — ghost-compose.service inactive for >15 min
  # 15-min `for` provides buffer beyond the ~3-5 min backup window
  rule {
    name      = "Ghost-Compose Down"
    condition = "C"
    for       = "15m"

    no_data_state  = "Alerting"
    exec_err_state = "Alerting"

    annotations = {
      summary     = "Ghost-compose is not running"
      description = "ghost-compose.service has not been active for over 15 minutes. May indicate failure to restart after backup. Check: docker ps && journalctl -u ghost-compose -n 50"
      runbook_url = "https://github.com/noahwhite/ghost-stack/blob/main/docs/runbooks/backup-restore.md"
    }

    labels = {
      service  = "backup"
      severity = "critical"
    }

    data {
      ref_id         = "A"
      datasource_uid = data.grafana_data_source.soc_dev_prometheus.uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        datasource = {
          type = "prometheus"
          uid  = data.grafana_data_source.soc_dev_prometheus.uid
        }
        editorMode   = "code"
        expr         = "node_systemd_unit_state{job=~\"integrations/node_exporter|unix\", name=\"ghost-compose.service\", state=\"active\"}"
        legendFormat = "{{instance}}"
        refId        = "A"
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        conditions = [{
          evaluator = { params = [], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["A"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "A"
        reducer    = "last"
        refId      = "B"
        type       = "reduce"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        conditions = [{
          evaluator = { params = [1], type = "lt" }
          operator  = { type = "and" }
          query     = { params = ["B"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "B"
        refId      = "C"
        type       = "threshold"
      })
    }
  }
}

# Backup history dashboard — Loki logs panel for ghost-backup.service
resource "grafana_dashboard" "ghost_stack_backup" {
  provider = grafana.soc_dev
  folder   = grafana_folder.ghost_stack_folder.id

  config_json = jsonencode({
    title       = "Ghost Stack Backup"
    description = "Backup job history for ghost-backup.service"
    editable    = true
    tags        = ["ghost-stack", "backup"]
    time = {
      from = "now-7d"
      to   = "now"
    }
    panels = [
      {
        id      = 1
        type    = "logs"
        title   = "Backup Job Logs"
        gridPos = { h = 20, w = 24, x = 0, y = 0 }
        options = {
          dedupStrategy      = "none"
          enableLogDetails   = true
          prettifyLogMessage = false
          showLabels         = false
          showTime           = true
          sortOrder          = "Descending"
          wrapLogMessage     = false
        }
        targets = [
          {
            datasource = {
              type = "loki"
              uid  = data.grafana_data_source.soc_dev_loki.uid
            }
            editorMode   = "code"
            expr         = "{job=~\"integrations/(node_exporter|unix)\", unit=\"ghost-backup.service\"}"
            legendFormat = ""
            refId        = "A"
          }
        ]
        datasource = {
          type = "loki"
          uid  = data.grafana_data_source.soc_dev_loki.uid
        }
      }
    ]
  })
}
