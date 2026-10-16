output "bucket_name" {
  value = aws_s3_bucket.site.id
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "route53_zone_id" {
  value = var.create_hosted_zone ? aws_route53_zone.site[0].zone_id : "not-created"
}
