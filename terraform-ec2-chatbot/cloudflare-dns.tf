terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "chatbot" {
  zone_id = var.cloudflare_zone_id

  name    = "chatbot"
  content = aws_eip.chatbot_eip.public_ip
  type    = "A"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "mlflow" {
  zone_id = var.cloudflare_zone_id

  name    = "mlflow"
  content = aws_eip.chatbot_eip.public_ip
  type    = "A"
  ttl     = 1
  proxied = false
}
