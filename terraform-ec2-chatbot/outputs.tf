output "chatbot_public_ip" {
  description = "Public Elastic IP of the Chatbot EC2 instance"
  value       = aws_eip.chatbot_eip.public_ip
}

output "chatbot_domain" {
  description = "Domain of the Chatbot API"
  value       = "https://chatbot.uittravel.shop"
}

output "mlflow_domain" {
  description = "Domain of the MLflow tracking server"
  value       = "https://mlflow.uittravel.shop"
}
