terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
    archive = {
        source = "hashicorp/archive"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------- S3 ----------
resource "aws_s3_bucket" "upload" {
  bucket = "${var.project}-serverless"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# ---------- SNS ----------
resource "aws_sns_topic" "notify" {
  name = "${var.project}-topic"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notify.arn
  protocol  = "email"
  endpoint  = var.email
}