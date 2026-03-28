# ── Dead Drop Frontend (auto-build via Terraform) ───────────
module "deaddrop_frontend" {
  source              = "./modules/cloudfront-spa"
  project_name        = "${local.resource_identifier}-deaddrop-fe"
  domain_name         = "deaddrop.${local.resource_identifier}.fiipractic.com"
  hosted_zone_id      = aws_route53_zone.main_hosted_zone.id
  project_description = "Dead Drop — self-destructing secret sharing"
  build_command       = "npm ci; npm run build"
  build_working_dir   = "${path.module}/../deaddrop/fe"
  build_environment   = {
    "VITE_API_URL" = "https://api.deaddrop.${local.resource_identifier}.fiipractic.com"
  }

  providers = {
    aws = aws.us-east-1
  }
}

# ── Dead Drop Backend ────────────────────────────────────────
module "deaddrop_backend" {
  source             = "./modules/deaddrop-backend"
  project_name       = "${local.resource_identifier}-deaddrop"
  source_path        = "${path.module}/../deaddrop/be"
  ses_sender_email   = "noreply@${local.resource_identifier}.fiipractic.com"
  ses_sandbox_emails = local.personal_email_addresses
  domain_name        = "api.deaddrop.${local.resource_identifier}.fiipractic.com"
  hosted_zone_id     = aws_route53_zone.main_hosted_zone.id
}
