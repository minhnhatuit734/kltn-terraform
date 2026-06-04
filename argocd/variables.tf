# Input variables for KLTN ArgoCD infrastructure

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet"
  type        = string
  default     = "ap-southeast-1a"
}

variable "project_name" {
  description = "Project name used for naming AWS resources"
  type        = string
  default     = "kltn-argocd"
}

variable "vpc_cidr" {
  description = "CIDR block for the ArgoCD VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for K3s and ArgoCD"
  type        = string
  default     = "t2.micro"
}

variable "volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "key_name" {
  description = "AWS EC2 key pair name"
  type        = string
  default     = "kltn-argocd-key"
}

variable "public_key_path" {
  description = "Path to local SSH public key used by AWS EC2 key pair"
  type        = string
  default     = "~/.ssh/kltn-argocd.pub"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into EC2. For demo, 0.0.0.0/0 is acceptable but not secure."
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_k8s_api_cidr" {
  description = "CIDR block allowed to access K3s API server on port 6443."
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_web_cidr" {
  description = "CIDR block allowed to access ArgoCD UI and web ports."
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_nodeport_cidr" {
  description = "CIDR block allowed to access Kubernetes NodePort range."
  type        = string
  default     = "0.0.0.0/0"
}