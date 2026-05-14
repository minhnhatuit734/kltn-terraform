# ArgoCD Terraform Configuration
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
resource "aws_vpc" "argocd_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# ─────────────────────────────────────────
# Subnet (public)
# ─────────────────────────────────────────
resource "aws_subnet" "argocd_subnet" {
  vpc_id                  = aws_vpc.argocd_vpc.id
  cidr_block              = var.subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-subnet"
    Project = var.project_name
  }
}

# ─────────────────────────────────────────
# Internet Gateway
# ─────────────────────────────────────────
resource "aws_internet_gateway" "argocd_igw" {
  vpc_id = aws_vpc.argocd_vpc.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# ─────────────────────────────────────────
# Route Table
# ─────────────────────────────────────────
resource "aws_route_table" "argocd_rt" {
  vpc_id = aws_vpc.argocd_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.argocd_igw.id
  }

  tags = {
    Name    = "${var.project_name}-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "argocd_rta" {
  subnet_id      = aws_subnet.argocd_subnet.id
  route_table_id = aws_route_table.argocd_rt.id
}

# ─────────────────────────────────────────
# Security Group
# ─────────────────────────────────────────
resource "aws_security_group" "argocd_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for ArgoCD server"
  vpc_id      = aws_vpc.argocd_vpc.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # ArgoCD UI (HTTPS)
  ingress {
    description = "ArgoCD UI HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ArgoCD UI (HTTP - redirect)
  ingress {
    description = "ArgoCD UI HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ArgoCD gRPC (cho CLI)
  ingress {
    description = "ArgoCD gRPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K3s API server (kubectl remote access)
  ingress {
    description = "K3s API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # NodePort range (cho các service expose qua NodePort)
  ingress {
    description = "NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: tất cả
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# ─────────────────────────────────────────
# Key Pair
# ─────────────────────────────────────────
resource "aws_key_pair" "argocd_key" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.public_key_path)

  tags = {
    Name    = "${var.project_name}-key"
    Project = var.project_name
  }
}

# ─────────────────────────────────────────
# EC2 Instance
# ─────────────────────────────────────────
resource "aws_instance" "argocd_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.argocd_subnet.id
  vpc_security_group_ids = [aws_security_group.argocd_sg.id]
  key_name               = aws_key_pair.argocd_key.key_name

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  # Tự động cài K3s + ArgoCD khi EC2 khởi động
  user_data = file("${path.module}/scripts/install.sh")

  tags = {
    Name    = "${var.project_name}-server"
    Project = var.project_name
    Role    = "argocd"
  }
}

# ─────────────────────────────────────────
# Elastic IP (IP tĩnh cho ArgoCD server)
# ─────────────────────────────────────────
resource "aws_eip" "argocd_eip" {
  instance = aws_instance.argocd_server.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }
}
