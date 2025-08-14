resource "cloudflare_zone" "main" {
  zone = "separationofconcerns.dev"
  plan = "free"
}