resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  depends_on = [
    time_sleep.wait_for_eks_api
  ]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.18.2"
  namespace        = kubernetes_namespace_v1.cert_manager.metadata[0].name
  create_namespace = false

  wait                       = true
  wait_for_jobs              = true
  timeout                    = 900
  atomic                     = true
  cleanup_on_fail            = true
  disable_openapi_validation = true
  skip_crds        = false


  set {
    name  = "crds.enabled"
    value = "true"
  }

  set {
    name  = "crds.keep"
    value = "false"
  }

  depends_on = [
    kubernetes_namespace_v1.cert_manager
  ]
}

resource "time_sleep" "wait_for_cert_manager_crds" {
  create_duration = "60s"

  depends_on = [
    helm_release.cert_manager
  ]
}
# Chỉ tạo 1 lần — không bao giờ rotate trừ khi chủ động
resource "kubernetes_secret_v1" "letsencrypt_account_key" {
  metadata {
    name      = "letsencrypt-prod-account-key"
    namespace = "cert-manager"
  }

  type = "Opaque"

  data = {
    "tls.key" = file("${path.module}/../letsencrypt-account.key")
  }

  depends_on = [
    helm_release.cert_manager
  ]
}