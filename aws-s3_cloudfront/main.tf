resource "aws_s3_bucket" "bucket_details" {
  bucket = var.bucket_name
}

resource "aws_s3_object" "website_files" {
  
  for_each = fileset("${path.module}/www", "**/*")
  bucket = aws_s3_bucket.bucket_details.id
  key    = each.value
  source = "${path.module}/www/${each.value}"
  etag = filemd5("${path.module}/www/${each.value}")
  content_type = lookup(var.content, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
}

resource "aws_s3_bucket_public_access_block" "private_bucket" {
  bucket = aws_s3_bucket.bucket_details.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "cloudfront_oac" {
  name                              = "s3-project-oac"
  description                       = "OAC Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.bucket_details.id
  depends_on = [aws_s3_bucket_public_access_block.private_bucket]
  # policy = data.aws_iam_policy_document.allow_access_from_another_account.json
  
  policy = jsonencode({
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "AllowCloudFrontAccess",
         "Effect": "Allow",
         "Principal": {
             "Service": "cloudfront.amazonaws.com"
        },
        "Action": [
          "s3:GetObject"
        ],
        "Resource": "${aws_s3_bucket.bucket_details.arn}/*"
      }
    ]
  })

}

# data "aws_iam_policy_document" "allow_access_from_another_account" {
#   statement {
#     principals {
#       type        = "AWS"
#       identifiers = ["123456789012"]
#     }

#     actions = [
#       "s3:GetObject",
#       "s3:ListBucket",
#     ]

#     resources = [
#       aws_s3_bucket.bucket_details.arn,
#       "${aws_s3_bucket.bucket_details.arn}/*",
#     ]
#   }
# }

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.bucket_details.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.cloudfront_oac.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
        restriction_type = "none"
    #   restriction_type = "whitelist"
    #   locations        = ["US", "CA", "GB", "DE"]
    }
  }

  # aliases = ["cloudfronts3.com", "www.cloudfronts3.com"]
   
  viewer_certificate {
    cloudfront_default_certificate = true
    # acm_certificate_arn      = aws_acm_certificate.cloudfront_cert.arn
    # ssl_support_method       = "sni-only"
  }

  # depends_on = [aws_acm_certificate_validation.cert_validation]
}

# resource "aws_acm_certificate" "cloudfront_cert" {
#   domain_name       = "cloudfronts3.com"
#   validation_method = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# data "aws_route53_zone" "primary" {
#   name         = "cloudfronts3.com"
#   private_zone = false
# }

# resource "aws_route53_record" "cloudfront_record" {
#   for_each = {
#     for dvo in aws_acm_certificate.cloudfront_cert.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.primary.zone_id
# }

# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn         = aws_acm_certificate.cloudfront_cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.cloudfront_record : record.fqdn]
# }