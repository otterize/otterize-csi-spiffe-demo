variable "aws_region" {
  default = "eu-west-2"
}

variable "aws_rolesanywhere_trust_anchor-name" {
  default = "otterize-cert-manager-spiffe"
}

variable "otterize-credentials-operator-role-name" {
  default = "otterize-credentials-operator"
}

variable "otterize-credentials-operator-policy-name" {
  default = "otterize-credentials-operator"
}

variable "otterize-credentials-operator-profile-name" {
  default = "otterize-credentials-operator"
}

variable "trust-domain" {
  default = "cert-manager-spiffe.mattiasgees.be"
}

variable "otterize-namespace" {
  default = "otterize-system"
}

variable "otterize-serviceaccount" {
  default = "credentials-operator-controller-manager"
}
