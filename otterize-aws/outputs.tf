output "trust-profile-arn" {
  value = aws_rolesanywhere_profile.otterize-credentials-operator.arn
}

output "trust-anchor-arn" {
  value = aws_rolesanywhere_trust_anchor.otterize-cert-manager-spiffe-ca.arn
}

output "otterize-credentials-operator-role-arn" {
  value = aws_iam_role.otterize-credentials-operator.arn
}

output "otterize-intents-operator-role-arn" {
  value = aws_iam_role.otterize-intents-operator.arn
}
