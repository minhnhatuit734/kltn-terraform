resource "kubernetes_namespace_v1" "dev" {
  metadata {
    name = "dev"

    labels = {
      environment = "dev"
      project     = "kltn"
      managed-by  = "terraform"
    }
  }

  depends_on = [
    time_sleep.wait_for_eks_api
  ]
}

resource "kubernetes_namespace_v1" "prod" {
  metadata {
    name = "prod"

    labels = {
      environment = "prod"
      project     = "kltn"
      managed-by  = "terraform"
    }
  }

  depends_on = [
    module.eks
  ]
}

resource "kubernetes_secret_v1" "kltn_app_secrets_dev" {
  metadata {
    name      = "kltn-app-secrets"
    namespace = kubernetes_namespace_v1.dev.metadata[0].name
  }

  type = "Opaque"

  data = {
    JWT_SECRET          = var.jwt_secret
    MONGO_ATLAS_URI     = var.mongo_atlas_uri
    MONGO_URL           = var.mongo_atlas_uri
    TOGETHER_API_KEY    = var.together_api_key
    NEXT_PUBLIC_API_URL = var.dev_frontend_api_url
  }

  depends_on = [
    kubernetes_namespace_v1.dev
  ]
}

resource "kubernetes_secret_v1" "kltn_app_secrets_prod" {
  metadata {
    name      = "kltn-app-secrets"
    namespace = kubernetes_namespace_v1.prod.metadata[0].name
  }

  type = "Opaque"

  data = {
    JWT_SECRET          = var.jwt_secret
    MONGO_ATLAS_URI     = var.mongo_atlas_uri
    MONGO_URL           = var.mongo_atlas_uri
    TOGETHER_API_KEY    = var.together_api_key
    NEXT_PUBLIC_API_URL = var.prod_frontend_api_url
  }

  depends_on = [
    kubernetes_namespace_v1.prod
  ]
}
