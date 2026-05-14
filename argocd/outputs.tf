# Output values from ArgoCD deployment
output "argocd_public_ip" {
  description = "Public IP tĩnh của ArgoCD server (Elastic IP)"
  value       = aws_eip.argocd_eip.public_ip
}

output "argocd_ui_url" {
  description = "URL truy cập ArgoCD UI"
  value       = "https://${aws_eip.argocd_eip.public_ip}"
}

output "ssh_command" {
  description = "Lệnh SSH vào server"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.argocd_eip.public_ip}"
}

output "k3s_api_server" {
  description = "K3s API server URL (dùng cho kubectl remote)"
  value       = "https://${aws_eip.argocd_eip.public_ip}:6443"
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.argocd_server.id
}

output "argocd_initial_password_command" {
  description = "Lệnh lấy mật khẩu admin ArgoCD lần đầu"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.argocd_eip.public_ip} 'sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d'"
}
