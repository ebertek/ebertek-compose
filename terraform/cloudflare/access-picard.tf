resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_d0ddf05c-d626-4de3-bf34-90c01097ae90_0" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "picard.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Picard"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "picard.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}
