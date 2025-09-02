firewall_name = "ghost-fw"

instance_name   = "ghost-dev-01"
instance_region = "ewr"           # pick your region slug
instance_plan   = "vc2-4c-8gb"    # pick a plan slug

ssh_key_name   = "ghost-dev-admin"

ghost_url = "http://separationofconverns.dev"

block_storage_size_gb = 25
block_storage_label   = "ghost-block"