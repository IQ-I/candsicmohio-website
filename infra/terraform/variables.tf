variable "aws_region" {
  description = "AWS region for S3. CloudFront + ACM are global / us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "prod | staging"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Apex domain. Do not apply until domain purchase is approved."
  type        = string
  default     = "candsicmohio.com"
}

variable "acm_certificate_arn" {
  description = "Validated ACM cert ARN in us-east-1 covering apex + www. Empty = do not apply."
  type        = string
  default     = ""
  validation {
    condition     = var.acm_certificate_arn == "" || startswith(var.acm_certificate_arn, "arn:aws:acm:us-east-1:")
    error_message = "ACM cert for CloudFront must be in us-east-1."
  }
}

variable "account_id_suffix" {
  description = "Short suffix to keep bucket globally unique, e.g. last 4 of account ID. Never put secrets here."
  type        = string
  default     = "prod"
}

variable "create_hosted_zone" {
  description = "Create Route53 hosted zone ($0.50/mo). False = use existing zone / manage DNS elsewhere."
  type        = bool
  default     = false
}
