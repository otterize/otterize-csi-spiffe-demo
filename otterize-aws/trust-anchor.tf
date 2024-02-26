data "kubernetes_secret" "ca" {
  metadata {
    name      = "cert-manager-spiffe"
    namespace = "cert-manager"
  }
  binary_data = {
    "tls.crt" = "",
    "tls.key" = ""
  }
}

resource "aws_rolesanywhere_trust_anchor" "otterize-cert-manager-spiffe-ca" {
  name    = var.aws_rolesanywhere_trust_anchor-name
  enabled = true
  source {
    source_data {
      x509_certificate_data = data.kubernetes_secret.ca.data["ca.crt"]
    }
    source_type = "CERTIFICATE_BUNDLE"
  }
}
