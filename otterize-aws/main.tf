module "otterize-aws-iam" {
  source  = "otterize/otterize-aws-iam-rolesanywhere/aws"
  version = "~> 1.0.2"
  cert_manager_trust_anchor_ca_secret_name = "cert-manager-spiffe"
  cert_manager_namespace = "cert-manager"
  aws_region = "eu-west-2"
  cluster_name = "otterize-csi-spiffe-demo"
}
