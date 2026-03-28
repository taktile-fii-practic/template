variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "domain_name" {
  description = "The domain name of the project"
  type        = string
}

variable "hosted_zone_id" {
  description = "The hosted zone id of the project"
  type        = string
}

variable "function_association" {
  description = "The function association for the CloudFront distribution"
  type = object({
    event_type   = string
    function_arn = string
  })
  default = null
}

variable "project_description" {
  description = "The description of the project"
  type        = string
}

variable "build_path" {
  description = "Path to the frontend build directory to upload to S3 (static mode — directory must exist at plan time)"
  type        = string
  default     = null
}

variable "build_command" {
  description = "Shell command to build the frontend (e.g. 'npm ci && npm run build'). When set, Terraform runs the build and deploys via S3 sync automatically."
  type        = string
  default     = null
}

variable "build_working_dir" {
  description = "Working directory for build_command"
  type        = string
  default     = null
}

variable "build_output_dir" {
  description = "Build output directory relative to build_working_dir (default: dist)"
  type        = string
  default     = "dist"
}

variable "build_source_dir" {
  description = "Source directory to watch for changes, relative to build_working_dir (default: src)"
  type        = string
  default     = "src"
}

