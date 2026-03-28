locals {
  ses_domain = coalesce(var.ses_domain, split("@", var.ses_sender_email)[1])
}

# ── Sandbox test recipients ─────────────────────────────────
resource "aws_ses_email_identity" "sandbox" {
  for_each = toset(var.ses_sandbox_emails)
  email    = each.value
}

# ── Domain Identity ─────────────────────────────────────────
resource "aws_ses_domain_identity" "this" {
  domain = local.ses_domain
}

resource "aws_route53_record" "ses_verification" {
  zone_id = var.hosted_zone_id
  name    = "_amazonses.${local.ses_domain}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.this.verification_token]
}

resource "aws_ses_domain_identity_verification" "this" {
  domain     = aws_ses_domain_identity.this.domain
  depends_on = [aws_route53_record.ses_verification]
}

# ── DKIM ────────────────────────────────────────────────────
resource "aws_ses_domain_dkim" "this" {
  domain = aws_ses_domain_identity.this.domain
}

resource "aws_route53_record" "ses_dkim" {
  count = 3

  zone_id = var.hosted_zone_id
  name    = "${aws_ses_domain_dkim.this.dkim_tokens[count.index]}._domainkey.${local.ses_domain}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.this.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# ── Custom MAIL FROM (optional) ─────────────────────────────
resource "aws_ses_domain_mail_from" "this" {
  count = var.mail_from_subdomain != null ? 1 : 0

  domain           = aws_ses_domain_identity.this.domain
  mail_from_domain = "${var.mail_from_subdomain}.${local.ses_domain}"
}

resource "aws_route53_record" "mail_from_mx" {
  count = var.mail_from_subdomain != null ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = "${var.mail_from_subdomain}.${local.ses_domain}"
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${data.aws_region.current.name}.amazonses.com"]
}

resource "aws_route53_record" "mail_from_spf" {
  count = var.mail_from_subdomain != null ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = "${var.mail_from_subdomain}.${local.ses_domain}"
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com ~all"]
}
