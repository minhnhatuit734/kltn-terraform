provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Data source để lấy AMI Ubuntu 24.04 mới nhất
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Tạo Security Group
resource "aws_security_group" "chatbot_sg" {
  name        = "kltn-chatbot-sg"
  description = "Security Group cho Chatbot EC2"
  vpc_id      = "vpc-0d1d6f06982eaf0ff"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP for Lets Encrypt and Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MLflow (Public for Demo)"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.106/32", "0.0.0.0/0"]
  }

  ingress {
    description = "MinIO API (Public for Demo)"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.106/32", "0.0.0.0/0"]
  }

  ingress {
    description = "MinIO Console (Public for Demo)"
    from_port   = 9001
    to_port     = 9001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Rasa API Internal"
    from_port   = 5005
    to_port     = 5005
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.106/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "kltn-chatbot-sg"
    Project = "KLTN"
  }
}

# EC2 Instance
resource "aws_instance" "chatbot" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = "subnet-0bb0da34ec00d82c3"

  vpc_security_group_ids = [aws_security_group.chatbot_sg.id]

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              # Cài đặt Docker
              apt-get install -y ca-certificates curl
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              chmod a+r /etc/apt/keyrings/docker.asc
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker
              
              # Tự động clone repo Chatbot (branch nhat)
              cd /home/ubuntu
              git clone -b nhat https://github.com/ThinhQuang08/Chatbot.git
              chown -R ubuntu:ubuntu Chatbot
              EOF

  tags = {
    Name    = "kltn-chatbot"
    Project = "KLTN"
  }
}

# Gán Elastic IP
resource "aws_eip" "chatbot_eip" {
  instance = aws_instance.chatbot.id
  domain   = "vpc"

  tags = {
    Name    = "kltn-chatbot-eip"
    Project = "KLTN"
  }
}
