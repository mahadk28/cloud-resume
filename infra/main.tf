# This block tells Terraform which plugins it needs to download
# Think of it like package.json declaring your dependencies
terraform {
  required_providers {
    aws = {
      # This is the official AWS plugin made by HashiCorp (the company that made Terraform)
      source = "hashicorp/aws"

      # Use any version 5.x — the ~> means "5.0 or higher but not 6.0"
      version = "~> 5.0"
    }
  }
}

# This tells Terraform HOW to connect to AWS
# It automatically uses the credentials you set with "aws configure"
provider "aws" {
  # All resources we create will live in this region (US East - Virginia)
  region = "us-east-1"
}




# S3 Bucket : This is where the resume is going to live
# S3 Bucket : Is Essentially a file storage in the cloud, like google drive but for apps

resource "aws_s3_bucket" "resume" {
  # This is the name of the bucket. It must be unique across all of AWS.
  # We add a random string to the end to make it unique.
  bucket = "mahad-cloud-resume"
}


# now lets block all public access at the bucket level
# We dont want anyone on the internet to access this bucket directly instead they should go through cloudflare

resource "aws_s3_bucket_public_access_block" "resume" {
  bucket = aws_s3_bucket.resume.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable static website hosting on the bucket
# This block is going to tell s3 which file to serve when someone visits the root url

resource "aws_s3_bucket_website_configuration" "resume" {
  bucket = aws_s3_bucket.resume.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}


# OAC - gives CloudFront permission to read from our private S3 bucket
# Without this CloudFront can't access the files since we blocked all public access
resource "aws_cloudfront_origin_access_control" "resume" {
  name                              = "resume-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution - this is the actual CDN that serves your resume globally
resource "aws_cloudfront_distribution" "resume" {
  enabled             = true
  default_root_object = "index.html"

  # Where CloudFront pulls your files from - your S3 bucket
  origin {
    domain_name              = aws_s3_bucket.resume.bucket_regional_domain_name
    origin_id                = "s3-resume"
    origin_access_control_id = aws_cloudfront_origin_access_control.resume.id
  }

  # How CloudFront handles requests - cache settings
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-resume"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # Where CloudFront serves from - use all edge locations worldwide
  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # HTTPS certificate - CloudFront provides this for free
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# S3 bucket policy - only allows CloudFront to read files, nobody else
resource "aws_s3_bucket_policy" "resume" {
  bucket = aws_s3_bucket.resume.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.resume.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.resume.arn
          }
        }
      }
    ]
  })
}

# Output the CloudFront URL so we can visit it after applying
output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.resume.domain_name}"
}
