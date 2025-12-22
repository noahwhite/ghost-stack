mock_provider "vultr" {
  mock_data "vultr_firewall_group" {
    defaults = {
      id          = "test-firewall-group-id"
      description = "test-firewall"
    }
  }
}

run "firewall_group_tests" {
  command = plan

  module {
    source = "../../modules/vultr/firewall"
  }

  variables {
    name = "test-firewall"
    admin_subnets = [
      {
        subnet      = "192.168.1.0"
        subnet_size = 24
      },
      {
        subnet      = "10.0.0.1"
        subnet_size = 32
      }
    ]
  }

  assert {
    condition     = vultr_firewall_group.this.description == "test-firewall"
    error_message = "Firewall group description should match the provided name"
  }

  assert {
    condition     = vultr_firewall_group.this.id != null
    error_message = "Firewall group should have an ID"
  }
}

run "http_https_rules_tests" {
  command = plan

  module {
    source = "../../modules/vultr/firewall"
  }

  variables {
    name = "test-firewall"
    admin_subnets = [
      {
        subnet      = "192.168.1.0"
        subnet_size = 24
      },
      {
        subnet      = "10.0.0.1"
        subnet_size = 32
      }
    ]
  }

  # Test HTTP rules
  assert {
    condition = (
      length(vultr_firewall_rule.http) == 2 &&
      vultr_firewall_rule.http["0"].protocol == "tcp" &&
      vultr_firewall_rule.http["0"].ip_type == "v4" &&
      vultr_firewall_rule.http["0"].port == "80" &&
      vultr_firewall_rule.http["0"].subnet == "192.168.1.0" &&
      vultr_firewall_rule.http["0"].subnet_size == 24 &&
      vultr_firewall_rule.http["0"].notes == "HTTP"
    )
    error_message = "HTTP rules should be correctly configured for admin subnets"
  }

  # Test HTTPS rules
  assert {
    condition = (
      length(vultr_firewall_rule.https) == 2 &&
      vultr_firewall_rule.https["0"].protocol == "tcp" &&
      vultr_firewall_rule.https["0"].ip_type == "v4" &&
      vultr_firewall_rule.https["0"].port == "443" &&
      vultr_firewall_rule.https["0"].subnet == "192.168.1.0" &&
      vultr_firewall_rule.https["0"].subnet_size == 24 &&
      vultr_firewall_rule.https["0"].notes == "HTTPS"
    )
    error_message = "HTTPS rules should be correctly configured for admin subnets"
  }

  # Test second subnet rules
  assert {
    condition = (
      vultr_firewall_rule.http["1"].subnet == "10.0.0.1" &&
      vultr_firewall_rule.http["1"].subnet_size == 32 &&
      vultr_firewall_rule.https["1"].subnet == "10.0.0.1" &&
      vultr_firewall_rule.https["1"].subnet_size == 32
    )
    error_message = "Rules should be created for all admin subnets"
  }
}

run "cloudflare_rules_tests" {
  command = plan

  module {
    source = "../../modules/vultr/firewall"
  }

  variables {
    name          = "test-firewall"
    admin_subnets = []
  }

  # Test that Cloudflare rules are created
  assert {
    condition     = length(vultr_firewall_rule.allow_https_from_cloudflare) == 15
    error_message = "Should create 15 Cloudflare HTTPS rules for all IP ranges"
  }

  # Test a specific Cloudflare rule configuration
  assert {
    condition = (
      vultr_firewall_rule.allow_https_from_cloudflare["173.245.48.0/20"].protocol == "tcp" &&
      vultr_firewall_rule.allow_https_from_cloudflare["173.245.48.0/20"].ip_type == "v4" &&
      vultr_firewall_rule.allow_https_from_cloudflare["173.245.48.0/20"].port == "443" &&
      vultr_firewall_rule.allow_https_from_cloudflare["173.245.48.0/20"].subnet == "173.245.48.0" &&
      vultr_firewall_rule.allow_https_from_cloudflare["173.245.48.0/20"].subnet_size == 20
    )
    error_message = "Cloudflare rules should be correctly configured with proper subnet and size"
  }

  # Test another Cloudflare rule to ensure proper CIDR parsing
  assert {
    condition = (
      vultr_firewall_rule.allow_https_from_cloudflare["104.16.0.0/13"].subnet == "104.16.0.0" &&
      vultr_firewall_rule.allow_https_from_cloudflare["104.16.0.0/13"].subnet_size == 13 &&
      strcontains(vultr_firewall_rule.allow_https_from_cloudflare["104.16.0.0/13"].notes, "Cloudflare")
    )
    error_message = "Cloudflare rules should parse CIDR blocks correctly and include descriptive notes"
  }
}

run "outputs_test" {
  command = plan

  module {
    source = "../../modules/vultr/firewall"
  }

  variables {
    name          = "test-firewall"
    admin_subnets = []
  }

  assert {
    condition     = output.id == vultr_firewall_group.this.id
    error_message = "Output ID should match the firewall group ID"
  }
}

run "no_admin_subnets_test" {
  command = plan

  module {
    source = "../../modules/vultr/firewall"
  }

  variables {
    name          = "test-firewall"
    admin_subnets = []
  }

  # When no admin subnets are provided, HTTP/HTTPS rules should not be created
  assert {
    condition     = length(vultr_firewall_rule.http) == 0
    error_message = "No HTTP rules should be created when admin_subnets is empty"
  }

  assert {
    condition     = length(vultr_firewall_rule.https) == 0
    error_message = "No HTTPS rules should be created when admin_subnets is empty"
  }

  # But Cloudflare rules should still exist
  assert {
    condition     = length(vultr_firewall_rule.allow_https_from_cloudflare) == 15
    error_message = "Cloudflare rules should always be created regardless of admin_subnets"
  }
}
