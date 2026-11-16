resource "aws_acm_certificate" "memos" {
  domain_name       = "memos.humdaan.co.uk"
  validation_method = "DNS"
}

resource "cloudflare_dns_record" "certificate" {
  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(one(aws_acm_certificate.memos.domain_validation_options).resource_record_name, ".")
  type    = "CNAME"
  content = trimsuffix(one(aws_acm_certificate.memos.domain_validation_options).resource_record_value, ".")
  ttl     = 60
  proxied = false
}

resource "aws_acm_certificate_validation" "memos" {
  certificate_arn         = aws_acm_certificate.memos.arn
  validation_record_fqdns = [cloudflare_dns_record.certificate.name]
}

resource "cloudflare_dns_record" "memos" {
  zone_id = var.cloudflare_zone_id
  name    = "memos.humdaan.co.uk"
  type    = "CNAME"
  content = module.alb.alb_dns_name
  ttl     = 60
  proxied = false
}
