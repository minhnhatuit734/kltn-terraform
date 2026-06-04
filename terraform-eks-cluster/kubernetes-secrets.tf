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
    TOGETHER_API_KEY    = var.together_api_key
    NEXT_PUBLIC_API_URL = var.dev_frontend_api_url

    # Per-service MONGO_URL — trỏ đúng database cho từng service
    MONGO_URL_USERS    = var.mongo_url_users
    MONGO_URL_TOURS    = var.mongo_url_tours
    MONGO_URL_BOOKINGS = var.mongo_url_bookings
    MONGO_URL_REVIEWS  = var.mongo_url_reviews
    MONGO_URL_BLOG     = var.mongo_url_blog
    MONGO_URL_CHAT     = var.mongo_url_chat
  }
  depends_on = [kubernetes_namespace_v1.dev]
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
    TOGETHER_API_KEY    = var.together_api_key
    NEXT_PUBLIC_API_URL = var.prod_frontend_api_url

    # Per-service MONGO_URL — trỏ đúng database cho từng service
    MONGO_URL_USERS    = var.mongo_url_users
    MONGO_URL_TOURS    = var.mongo_url_tours
    MONGO_URL_BOOKINGS = var.mongo_url_bookings
    MONGO_URL_REVIEWS  = var.mongo_url_reviews
    MONGO_URL_BLOG     = var.mongo_url_blog
    MONGO_URL_CHAT     = var.mongo_url_chat
  }
  depends_on = [kubernetes_namespace_v1.prod]
}