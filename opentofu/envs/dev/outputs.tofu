output "mailgun_dns_txt_records" {
  value       = module.dns_records.mailgun_dns_txt_records
  description = "Mailgun TXT records created (SPF and DKIM)."
}

output "mailgun_dns_mx_records" {
  description = "Mailgun MX records created."
  value       = module.dns_records.mailgun_dns_mx_records
}

output "mailgun_tracking_cname" {
  value       = module.dns_records.mailgun_tracking_cname
  description = "CNAME record used for email tracking."
}
