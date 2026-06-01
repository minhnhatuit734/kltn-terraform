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
