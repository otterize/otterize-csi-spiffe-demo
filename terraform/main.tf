terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

resource "aws_s3_bucket" "otterize-test" {
  bucket = var.bucket-name

  tags = {
    Name        = var.bucket-name
    Environment = "Dev"
  }
}

resource "aws_s3_object" "test_file" {
  bucket = aws_s3_bucket.otterize-test.bucket
  key    = "test.txt"
  source = "test.txt"
  etag   = filemd5("test.txt")
}

resource "aws_rolesanywhere_trust_anchor" "cert-manager-spiffe-ca" {
  name    = "cert-manager-spiffe"
  enabled = true
  source {
    source_data {
      x509_certificate_data = file("ca.pub")
    }
    source_type = "CERTIFICATE_BUNDLE"
  }
}

resource "aws_iam_role" "otterize-role" {
  name = "otterize-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["sts:AssumeRole", "sts:TagSession", "sts:SetSourceIdentity"]
        Effect = "Allow",
        Principal = {
          Service = "rolesanywhere.amazonaws.com",
        },
        Condition = {
          StringLike = {
            "aws:PrincipalTag/x509SAN/URI" = "spiffe://cert-manager-spiffe.mattiasgees.be/ns/*/sa/*",
          }
          ArnEquals = {
            "aws:SourceArn" = aws_rolesanywhere_trust_anchor.cert-manager-spiffe-ca.arn
          }
        }
      },
    ],
  })
}

resource "aws_iam_role_policy" "s3" {
  name = "otterize-test"
  role = aws_iam_role.otterize-role.name

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutAccountPublicAccessBlock",
                "s3:GetAccountPublicAccessBlock",
                "s3:ListAllMyBuckets",
                "s3:ListJobs",
                "s3:CreateJob",
                "s3:HeadBucket"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.otterize-test.bucket}",
                "arn:aws:s3:::${aws_s3_bucket.otterize-test.bucket}/*",
                "arn:aws:s3:*:*:job/*"
            ]
        }
    ]
}
EOF
}

resource "aws_rolesanywhere_profile" "otterize-iam-anywhere-policy" {

  name           = "otterize-s3-test"
  enabled        = true
  role_arns      = [aws_iam_role.otterize-role.arn]
  session_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [      
        {
          "Sid":"statement1",
          "Effect": "Allow",
          "Action": [
            "s3:PutObject",
            "s3:PutObjectAcl",
            "s3:GetObject",
            "s3:GetObjectAcl",
            "s3:*"
          ],
          "Resource": [
              "arn:aws:s3:::${aws_s3_bucket.otterize-test.bucket}",
              "arn:aws:s3:::${aws_s3_bucket.otterize-test.bucket}/*",
              "arn:aws:s3:*:*:job/*"
          ],
          "Condition": {
              "StringLike": {
                  "aws:PrincipalTag/x509SAN/URI": "spiffe://cert-manager-spiffe.mattiasgees.be/ns/sandbox/sa/*"
              }
          }
        }
    ]
}
EOF
}

output "trust-profile-arn" {
  value = aws_rolesanywhere_profile.otterize-iam-anywhere-policy.arn
}

output "trust-anchor-arn" {
  value = aws_rolesanywhere_trust_anchor.cert-manager-spiffe-ca.arn
}

output "role-arn" {
  value = aws_iam_role.otterize-role.arn
}
