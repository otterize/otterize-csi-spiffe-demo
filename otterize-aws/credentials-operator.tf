resource "aws_iam_role" "otterize-credentials-operator" {
  name = var.otterize-credentials-operator-role-name

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
            "aws:PrincipalTag/x509SAN/URI" = "spiffe://${var.trust-domain}/ns/${var.otterize-namespace}/sa/${var.otterize-serviceaccount}",
          }
          ArnEquals = {
            "aws:SourceArn" = aws_rolesanywhere_trust_anchor.otterize-cert-manager-spiffe-ca.arn
          }
        }
      },
    ],
  })
}

resource "aws_iam_role_policy" "otterize-credentials-operator" {
  name = var.otterize-credentials-operator-policy-name
  role = aws_iam_role.otterize-credentials-operator.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "iam:*",
        "organizations:DescribeAccount",
        "organizations:DescribeOrganization",
        "organizations:DescribeOrganizationalUnit",
        "organizations:DescribePolicy",
        "organizations:ListChildren",
        "organizations:ListParents",
        "organizations:ListPoliciesForTarget",
        "organizations:ListRoots",
        "organizations:ListPolicies",
        "organizations:ListTargetsForPolicy",
        "ec2:DescribeInstances",
        "eks:DescribeCluster"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "rolesanywhere:CreateProfile",
        "rolesanywhere:DeleteProfile",
        "rolesanywhere:GetProfile",
        "rolesanywhere:ListProfiles"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_rolesanywhere_profile" "otterize-credentials-operator" {

  name           = var.otterize-credentials-operator-profile-name
  enabled        = true
  role_arns      = [aws_iam_role.otterize-credentials-operator.arn]
}
