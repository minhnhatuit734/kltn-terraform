variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API Token"
  sensitive   = true
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID"
}

variable "instance_type" {
  type        = string
  description = "EC2 Instance Type"
}

variable "key_name" {
  type        = string
  description = "EC2 Key Pair Name"
}
