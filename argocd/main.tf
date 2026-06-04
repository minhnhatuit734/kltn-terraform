# ArgoCD Terraform Configuration for KLTN
# Purpose:
# - Provision AWS infrastructure for a standalone ArgoCD server
# - Install K3s + ArgoCD automatically through EC2 user_data

terraform {
  required_version = ">= 1.6.0"

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
# Get latest Ubuntu 22.04 LTS AMI
# Canonical owner ID: 099720109477
# ─────────────────────────────────────────
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
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
    Managed = "terraform"
  }
}

# ─────────────────────────────────────────
# Public Subnet
# ─────────────────────────────────────────
resource "aws_subnet" "argocd_subnet" {
  vpc_id                  = aws_vpc.argocd_vpc.id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet"
    Project = var.project_name
    Managed = "terraform"
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
    Managed = "terraform"
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
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
    Managed = "terraform"
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
  description = "Security group for K3s and ArgoCD server"
  vpc_id      = aws_vpc.argocd_vpc.id

  # SSH
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP - reserved for future reverse proxy / ingress
  ingress {
    description = "HTTP access - reserved for future reverse proxy"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_web_cidr]
  }

  # HTTPS - reserved for future reverse proxy / ingress
  ingress {
    description = "HTTPS access - reserved for future reverse proxy"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_web_cidr]
  }

  # K3s API server
  ingress {
    description = "K3s Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_k8s_api_cidr]
  }

  # ArgoCD UI HTTP NodePort
  ingress {
    description = "ArgoCD UI HTTP NodePort"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_web_cidr]
  }

  # ArgoCD UI HTTPS NodePort
  ingress {
    description = "ArgoCD UI HTTPS NodePort"
    from_port   = 30443
    to_port     = 30443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_web_cidr]
  }

  # NodePort range for future K8s services
  ingress {
    description = "Kubernetes NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.allowed_nodeport_cidr]
  }

  # Outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
    Managed = "terraform"
  }
}

# ─────────────────────────────────────────
# EC2 Key Pair
# ─────────────────────────────────────────
resource "aws_key_pair" "argocd_key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  tags = {
    Name    = var.key_name
    Project = var.project_name
    Managed = "terraform"
  }
}

# ─────────────────────────────────────────
# EC2 Instance
# ─────────────────────────────────────────
resource "aws_instance" "argocd_server" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.argocd_subnet.id
  vpc_security_group_ids      = [aws_security_group.argocd_sg.id]
  key_name                    = aws_key_pair.argocd_key.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  user_data = file("${path.module}/scripts/install.sh")

  tags = {
    Name    = "${var.project_name}-server"
    Project = var.project_name
    Role    = "argocd"
    Managed = "terraform"
  }
}

# ─────────────────────────────────────────
# Elastic IP
# ─────────────────────────────────────────
resource "aws_eip" "argocd_eip" {
  instance = aws_instance.argocd_server.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
    Managed = "terraform"
  }
}
