resource "tls_private_key" "chatbot_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "chatbot_key" {
  key_name   = var.key_name
  public_key = tls_private_key.chatbot_key.public_key_openssh
}

resource "local_file" "chatbot_private_key" {
  content         = tls_private_key.chatbot_key.private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0400"
}
