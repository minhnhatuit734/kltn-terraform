# Output values from KLTN ArgoCD infrastructure

output "argocd_public_ip" {
  description = "Elastic IP of the ArgoCD server"
  value       = aws_eip.argocd_eip.public_ip
}

output "argocd_ui_url" {
  description = "ArgoCD UI HTTP URL through NodePort"
  value       = "http://${aws_eip.argocd_eip.public_ip}:30080"
}

output "argocd_https_url" {
  description = "ArgoCD UI HTTPS URL through NodePort"
  value       = "https://${aws_eip.argocd_eip.public_ip}:30443"
}

output "ssh_command" {
  description = "SSH command to access the ArgoCD server"
  value       = "ssh -i ~/.ssh/kltn-argocd ubuntu@${aws_eip.argocd_eip.public_ip}"
}

output "k3s_api_server" {
  description = "K3s API server endpoint"
  value       = "https://${aws_eip.argocd_eip.public_ip}:6443"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.argocd_server.id
}

output "argocd_initial_password_command" {
  description = "Command to get the initial ArgoCD admin password"
  value       = "ssh -i ~/.ssh/kltn-argocd ubuntu@${aws_eip.argocd_eip.public_ip} 'sudo cat /home/ubuntu/argocd-admin-password.txt'"
}

output "argocd_info_command" {
  description = "Command to show ArgoCD server information"
  value       = "ssh -i ~/.ssh/kltn-argocd ubuntu@${aws_eip.argocd_eip.public_ip} 'cat /home/ubuntu/argocd-info.txt'"
}