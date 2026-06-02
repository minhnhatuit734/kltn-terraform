variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone Read and DNS Edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for uittravel.shop"
  type        = string
}
