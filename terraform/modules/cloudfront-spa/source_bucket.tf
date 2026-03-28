resource "aws_s3_bucket" "source_code_bucket" {
  bucket = "${var.project_name}-source-code-bucket"

  force_destroy = false
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.source_code_bucket.id

  policy = jsonencode({
    Id      = "${var.project_name}-bucket-policy"
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PolicyForCloudFrontPrivateContent"
        Effect   = "Allow"
        Action   = ["s3:GetObject*"]
        Resource = "${aws_s3_bucket.source_code_bucket.arn}/*"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.project_distribution.id}"
          }
        }
      }
    ]
  })
}

locals {
  auto_build = var.build_command != null

  content_types = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2" = "font/woff2"
    ".ttf"  = "font/ttf"
    ".map"  = "application/json"
    ".txt"  = "text/plain"
    ".xml"  = "application/xml"
    ".webp" = "image/webp"
  }

  # Static mode: fileset at plan time (skipped when auto_build)
  build_files = !local.auto_build && var.build_path != null ? fileset(var.build_path, "**/*") : toset([])

  # Auto-build mode: hash source files to detect changes
  auto_build_source_files = local.auto_build ? fileset("${var.build_working_dir}/${var.build_source_dir}", "**/*") : toset([])
  auto_build_source_hash = local.auto_build ? sha256(join(",", concat(
    [filemd5("${var.build_working_dir}/package-lock.json")],
    sort([for f in local.auto_build_source_files : filemd5("${var.build_working_dir}/${var.build_source_dir}/${f}")])
  ))) : ""
}

# ── Static mode: Terraform-managed S3 objects ────────────────
resource "aws_s3_object" "build_files" {
  for_each = local.build_files

  bucket       = aws_s3_bucket.source_code_bucket.id
  key          = each.value
  source       = "${var.build_path}/${each.value}"
  etag         = filemd5("${var.build_path}/${each.value}")
  content_type = lookup(local.content_types, regex("\\.[^.]+$", each.value), "application/octet-stream")
}

# ── Auto-build mode: build + S3 sync at apply time ──────────
resource "null_resource" "auto_build_deploy" {
  count = local.auto_build ? 1 : 0

  triggers = {
    source_hash   = local.auto_build_source_hash
    build_command = var.build_command
  }

  provisioner "local-exec" {
    working_dir = var.build_working_dir
    environment = var.build_environment
    command     = <<-EOT
      ${var.build_command}
      aws s3 sync ${var.build_output_dir} s3://${aws_s3_bucket.source_code_bucket.id}/ --delete
    EOT
  }
}