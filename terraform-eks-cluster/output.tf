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

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "argocd_server_service" {
  description = "ArgoCD Server LoadBalancer - chay lenh nay de lay URL"
  value       = "kubectl get svc argocd-server -n ${var.argocd_namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "argocd_initial_admin_password_cmd" {
  description = "Lenh lay mat khau admin mac dinh cua ArgoCD"
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "grafana_service" {
  description = "Grafana LoadBalancer - chay lenh nay de lay URL"
  value       = "kubectl get svc kube-prometheus-stack-grafana -n ${var.monitoring_namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "grafana_admin_credentials" {
  description = "Grafana admin credentials"
  value       = "Username: admin | Password: xem variables.tf hoac tfvars -> grafana_admin_password"
}

output "prometheus_service" {
  description = "Prometheus khong expose ra ngoai. Truy cap qua kubectl port-forward"
  value       = "kubectl port-forward svc/kube-prometheus-stack-prometheus -n ${var.monitoring_namespace} 9090:9090"
}
