# Input variables for ArgoCD
variable "aws_region" {
  description = "AWS region để deploy"
  type        = string
  default     = "ap-southeast-1" # Singapore - gần Việt Nam nhất
}

variable "project_name" {
  description = "Tên project, dùng để đặt tên tài nguyên"
  type        = string
  default     = "kltn-argocd"
}

variable "vpc_cidr" {
  description = "CIDR block cho VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block cho public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_cidr" {
  description = "IP được phép SSH và truy cập K3s API (nên giới hạn IP của bạn)"
  type        = string
  default     = "0.0.0.0/0" # Đổi thành IP của bạn để bảo mật hơn, ví dụ: "123.456.789.0/32"
}

variable "ami_id" {
  description = "AMI ID cho Ubuntu 22.04 LTS tại ap-southeast-1"
  type        = string
  default     = "ami-0df7a207adb9748c7" # Ubuntu 22.04 LTS - Singapore
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium" # 2 vCPU, 4GB RAM - đủ để chạy K3s + ArgoCD
}

variable "volume_size" {
  description = "Dung lượng ổ đĩa root (GB)"
  type        = number
  default     = 20
}

variable "public_key_path" {
  description = "Đường dẫn đến public key SSH"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
