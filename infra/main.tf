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
