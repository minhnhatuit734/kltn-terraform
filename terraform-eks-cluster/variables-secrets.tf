variable "jwt_secret" {
  description = "JWT secret for backend services"
  type        = string
  sensitive   = true
}

variable "mongo_atlas_uri" {
  description = "MongoDB Atlas connection string"
  type        = string
  sensitive   = true
}

variable "together_api_key" {
  description = "Together AI API key"
  type        = string
  sensitive   = true
}

variable "dev_frontend_api_url" {
  description = "Public API URL used by frontend in dev environment"
  type        = string
  default     = "http://api-dev.uittravel.shop"
}

variable "prod_frontend_api_url" {
  description = "Public API URL used by frontend in prod environment"
  type        = string
  default     = "http://api-prod.uittravel.shop"
}
