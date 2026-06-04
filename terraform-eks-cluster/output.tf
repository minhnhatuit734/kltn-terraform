output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "configure_kubectl" {
  description = "Command to configure kubectl for this EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ingress_nginx_load_balancer" {
  description = "NGINX Ingress LoadBalancer hostname"
  value       = local.ingress_nginx_lb_hostname
}

output "app_urls" {
  description = "Application URLs"
  value = {
    dev_frontend  = "https://dev.uittravel.shop"
    dev_api       = "https://api-dev.uittravel.shop"
    prod_frontend = "https://prod.uittravel.shop"
    prod_api      = "https://api-prod.uittravel.shop"
  }
}

output "argocd_url" {
  description = "ArgoCD URL through NGINX Ingress"
  value       = "https://argocd.uittravel.shop"
}

output "argocd_initial_admin_password_cmd" {
  description = "Command to get initial ArgoCD admin password"
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "grafana_url" {
  description = "Grafana URL through NGINX Ingress"
  value       = "https://grafana.uittravel.shop"
}

output "grafana_admin_credentials" {
  description = "Grafana admin credentials"
  value       = "Username: admin | Password: see terraform.tfvars -> grafana_admin_password"
}

output "prometheus_service" {
  description = "Prometheus is not exposed publicly. Access with kubectl port-forward."
  value       = "kubectl port-forward svc/kube-prometheus-stack-prometheus -n ${var.monitoring_namespace} 9090:9090"
}