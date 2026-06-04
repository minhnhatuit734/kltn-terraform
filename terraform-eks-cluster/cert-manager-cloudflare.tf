resource "kubernetes_secret_v1" "cloudflare_api_token_cert_manager" {
  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  }

  type = "Opaque"

  data = {
    api-token = var.cloudflare_api_token
  }

  depends_on = [
    kubernetes_namespace_v1.cert_manager
  ]
}

resource "kubectl_manifest" "letsencrypt_prod_cluster_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        email: ${var.letsencrypt_email}
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt-prod-account-key
        solvers:
          - dns01:
              cloudflare:
                apiTokenSecretRef:
                  name: cloudflare-api-token-secret
                  key: api-token
  YAML

  depends_on = [
    time_sleep.wait_for_cert_manager_crds,
    kubernetes_secret_v1.cloudflare_api_token_cert_manager
  ]
}