resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_be9ea0f2-32ff-4a11-9528-bbc36167c283_42" {
  account_id                = "bbe7e7cd88aa3e9d775379a230d15953"
  auto_redirect_to_identity = false
  domain                    = "ebertek.cloudflareaccess.com/warp"
  name                      = "Warp Login App"
  session_duration          = "24h"
  type                      = "warp"
  policies = [
    {
      id         = "b93aae41-a89d-40a9-af0a-afb7125c5fa1"
      precedence = 2
    }
  ]
}
