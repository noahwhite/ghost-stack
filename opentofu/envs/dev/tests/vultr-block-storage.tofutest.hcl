mock_provider "vultr" {
  mock_resource "vultr_block_storage" {
    defaults = {
      id       = "test-block-storage-id"
      mount_id = "test-instance-id"
    }
  }
}

run "block_storage_defaults" {
  command = plan

  module {
    source = "../../modules/vultr/block_storage"
  }

  variables {
    region            = "ewr"
    mount_instance_id = "test-instance-id"
  }

  assert {
    condition     = vultr_block_storage.this.region == "ewr"
    error_message = "Block storage region should match provided value"
  }

  assert {
    condition     = vultr_block_storage.this.size_gb == 25
    error_message = "Block storage size should default to 25 GB"
  }

  assert {
    condition     = vultr_block_storage.this.label == "ghost-block"
    error_message = "Block storage label should default to ghost-block"
  }

  assert {
    condition     = vultr_block_storage.this.live == true
    error_message = "Block storage live should be true"
  }

  assert {
    condition     = vultr_block_storage.this.attached_to_instance == "test-instance-id"
    error_message = "Block storage should be attached to the provided instance ID"
  }
}

run "block_storage_custom_values" {
  command = plan

  module {
    source = "../../modules/vultr/block_storage"
  }

  variables {
    region            = "lax"
    size_gb           = 50
    label             = "custom-label"
    mount_instance_id = "custom-instance-id"
  }

  assert {
    condition     = vultr_block_storage.this.region == "lax"
    error_message = "Block storage region should match provided value"
  }

  assert {
    condition     = vultr_block_storage.this.size_gb == 50
    error_message = "Block storage size should match provided value"
  }

  assert {
    condition     = vultr_block_storage.this.label == "custom-label"
    error_message = "Block storage label should match provided value"
  }

  assert {
    condition     = vultr_block_storage.this.attached_to_instance == "custom-instance-id"
    error_message = "Block storage should be attached to the provided instance ID"
  }
}
