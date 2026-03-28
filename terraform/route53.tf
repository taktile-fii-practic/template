resource "aws_route53_zone" "main_hosted_zone" {
  name = "${local.resource_identifier}.fiipractic.com"
}