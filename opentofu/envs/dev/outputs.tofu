output "instance_ip" {
  description = "The public IPv4 address of the Ghost dev instance"
  value       = module.vm.main_ip
}

output "mailgun_dns_txt_records" {
  value = module.dns_records.mailgun_dns_txt_records
  description = "Mailgun TXT records created (SPF and DKIM)."
}

output "mailgun_dns_mx_records" {
  description = "Mailgun MX records created."
  value = module.dns_records.mailgun_dns_mx_records
}

output "mailgun_tracking_cname" {
  value       = module.dns_records.mailgun_tracking_cname
  description = "CNAME record used for email tracking."
}

output "ignition_output" {
  value = module.vm.ghost_ignition
}