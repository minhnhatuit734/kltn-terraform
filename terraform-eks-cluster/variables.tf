# ──────────────────────────────────────────────
# AWS & Infrastructure
# ──────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region for KLTN EKS lab"
  type        = string
  default     = "ap-southeast-1"
}

variable "cluster_name" {
  description = "EKS cluster name for KLTN"
  type        = string
  default     = "kltn-eks-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "CIDR block for KLTN EKS VPC"
  type        = string
  default     = "10.10.0.0/16"
}

# ──────────────────────────────────────────────
# Node Group Configuration
# ──────────────────────────────────────────────
variable "node_instance_types" {
  description = "EC2 instance types for EKS managed node group"
  type        = list(string)
  default     = ["m7i-flex.large"]
}

variable "node_capacity_type" {
  description = "Capacity type for EKS managed node group: SPOT or ON_DEMAND"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

# ──────────────────────────────────────────────
# ArgoCD
# ──────────────────────────────────────────────
variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart"
  type        = string
  default     = "7.8.23"
}

# ──────────────────────────────────────────────
# Monitoring (kube-prometheus-stack)
# ──────────────────────────────────────────────
variable "monitoring_namespace" {
  description = "Kubernetes namespace for Prometheus + Grafana"
  type        = string
  default     = "monitoring"
}

variable "kube_prometheus_stack_chart_version" {
  description = "Version of the kube-prometheus-stack Helm chart"
  type        = string
  default     = "72.3.0"
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana UI"
  type        = string
  sensitive   = true
  default     = "Admin@KLTN2024!"
}

variable "prometheus_retention" {
  description = "How long Prometheus retains metrics data"
  type        = string
  default     = "15d"
}

# ──────────────────────────────────────────────
# Secrets (SENSITIVE - Update in terraform.tfvars)
# ──────────────────────────────────────────────
variable "jwt_secret" {
  description = "JWT secret for backend services"
  type        = string
  sensitive   = true
}

variable "mongo_atlas_uri" {
  description = "MongoDB Atlas connection string"
  type        = string
  sensitive   = true
}

variable "together_api_key" {
  description = "Together AI API key"
  type        = string
  sensitive   = true
}

# ──────────────────────────────────────────────
# Per-service MongoDB URIs
# ──────────────────────────────────────────────
variable "mongo_url_users" {
  description = "MongoDB URI for users-service → tour_users database"
  type        = string
  sensitive   = true
}

variable "mongo_url_tours" {
  description = "MongoDB URI for tours-service → tour_tours database"
  type        = string
  sensitive   = true
}

variable "mongo_url_bookings" {
  description = "MongoDB URI for bookings-service → tour_bookings database"
  type        = string
  sensitive   = true
}

variable "mongo_url_reviews" {
  description = "MongoDB URI for reviews-service → tour_reviews database"
  type        = string
  sensitive   = true
}

variable "mongo_url_blog" {
  description = "MongoDB URI for blog-service → tour_blog database"
  type        = string
  sensitive   = true
}

variable "mongo_url_chat" {
  description = "MongoDB URI for chat-service → tour_chat database"
  type        = string
  sensitive   = true
}

# ──────────────────────────────────────────────
# Frontend URLs (Environment-specific)
# ──────────────────────────────────────────────
variable "dev_frontend_api_url" {
  description = "Public API URL used by frontend in dev environment"
  type        = string
  default     = "http://api-dev.uittravel.shop"
}

variable "prod_frontend_api_url" {
  description = "Public API URL used by frontend in prod environment"
  type        = string
  default     = "http://api-prod.uittravel.shop"
}

# ──────────────────────────────────────────────
# Cloudflare DNS & TLS
# ──────────────────────────────────────────────
variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone Read and DNS Edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for uittravel.shop"
  type        = string
}

variable "letsencrypt_email" {
  description = "Email used for Let's Encrypt ACME registration"
  type        = string
}

variable "dev_namespace" { type = string }
variable "prod_namespace" { type = string }
variable "chatbot_db_user" { type = string }
variable "chatbot_db_password" {
  type      = string
  sensitive = true
}
variable "chatbot_gemini_api_key" {
  type      = string
  sensitive = true
}
variable "chatbot_qdrant_api_key" {
  type      = string
  sensitive = true
}
variable "chatbot_aws_access_key_id" {
  type      = string
  sensitive = true
}
variable "chatbot_aws_secret_access_key" {
  type      = string
  sensitive = true
}
variable "chatbot_aws_default_region" { type = string }
variable "chatbot_s3_bucket_name" { type = string }
variable "chatbot_s3_model_key" { type = string }
variable "dockerhub_username" { type = string }
variable "dockerhub_password" {
  type      = string
  sensitive = true
}
variable "dockerhub_email" { type = string }

