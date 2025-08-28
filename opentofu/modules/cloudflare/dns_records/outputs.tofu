output "mailgun_dns_txt_records" {
  value = {
    txt_spf = cloudflare_dns_record.mailgun_spf,
    txt_dkim = cloudflare_dns_record.mailgun_dkim
  }
  description = "Mailgun TXT records created (SPF and DKIM)."
}

output "mailgun_dns_mx_records" {
  description = "Mailgun MX records created."
  value = {
    mx_a = cloudflare_dns_record.mailgun_mx_1
    mx_b = cloudflare_dns_record.mailgun_mx_2
  }
}

output "mailgun_tracking_cname" {
  value       = cloudflare_dns_record.mailgun_tracking
  description = "CNAME record used for email tracking."
}