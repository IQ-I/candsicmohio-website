# C&S ICM Ohio — candsicmohio.com — static hosting on S3 + CloudFront
# Near-$0 design: private S3 bucket, CloudFront OAC, ACM cert in us-east-1,
# Route53 hosted zone + records. No EC2, no ALB, no WAF, no access logging by default.
# WARNING: Not $0-for-life. Route53 domain (~$12-14/yr .com) + hosted zone ($0.50/mo)
# are recurring. S3/CloudFront are near-$0 at low traffic but can bill if traffic spikes.
# Apply from infra/ branch only after site content is approved. See README.md.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

# ACM must live in us-east-1 for CloudFront
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = "candsicmohio-website"
    Owner       = "C&S ICM Church"
    Developer   = "iDnoBLes Quantum Ideas Inc."
    Environment = var.environment
    CostCenter  = "church-website"
    ManagedBy   = "terraform"
    Repo        = "candsicmohio-website"
  }
  bucket_name = var.environment == "prod" ? "candsicmohio-com-${var.account_id_suffix}" : "candsicmohio-${var.environment}-${var.account_id_suffix}"
}

# --- S3: private bucket, website files only ---
resource "aws_s3_bucket" "site" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# --- CloudFront OAC ---
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "candsicmohio-oac-${var.environment}"
  description                     = "OAC for candsicmohio.com"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipal"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.site.arn } }
    }]
  })
}

# --- ACM cert (must already be validated in us-east-1, or create + validate via DNS) ---
# This template expects a validated cert ARN passed in. Do NOT create certs in loops.
# If you need a new cert, uncomment the block below and add DNS validation records.
# resource "aws_acm_certificate" "site" {
#   provider          = aws.us_east_1
#   domain_name       = var.domain_name
#   subject_alternative_names = ["www.${var.domain_name}"]
#   validation_method = "DNS"
#   tags = local.common_tags
#   lifecycle { create_before_destroy = true }
# }

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "candsicmohio.com — C&S ICM Church"
  default_root_object = "index.html"
  aliases             = [var.domain_name, "www.${var.domain_name}"]
  price_class         = "PriceClass_100" # US/EU only = cheapest
  tags                = local.common_tags

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # SPA-style fallback: serve index.html on 404/403 so deep links don't break
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# --- Route53 ---
# If you already own the domain in Route53, set var.create_hosted_zone = true
# and var.domain_name = "candsicmohio.com". Do NOT run this until you approve
# the domain purchase/transfer. Hosted zone costs $0.50/mo.
resource "aws_route53_zone" "site" {
  count = var.create_hosted_zone ? 1 : 0
  name  = var.domain_name
  tags  = local.common_tags
}

resource "aws_route53_record" "apex" {
  count   = var.create_hosted_zone ? 1 : 0
  zone_id = aws_route53_zone.site[0].zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  count   = var.create_hosted_zone ? 1 : 0
  zone_id = aws_route53_zone.site[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
