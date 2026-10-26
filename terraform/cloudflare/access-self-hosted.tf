resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_f4a8c5cc-9b69-48ec-881c-04e7e3bc987a_1" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "komodo.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Komodo"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "komodo.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_f454e661-3f35-4fe5-b5cb-008718378273_2" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "books.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Books"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "books.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_046f64e4-53b2-4fad-a2d5-82a896e10d97_3" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "grafana.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Grafana"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "grafana.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_982de8df-aaff-4d5b-8278-1c278162eac2_4" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "influxdb.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  logo_url                   = "https://influxdata.github.io/branding/img/downloads/cubo-navy.svg"
  name                       = "InfluxDB"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "influxdb.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_dc53f6d6-e289-4380-913e-70ee9ff5ccfc_5" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "loki.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  logo_url                   = "https://grafana.com/static/img/logos/logo-loki.svg"
  name                       = "Loki"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "loki.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "918b5d0c-bc97-43a0-bd75-a30ced36ee34", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_e8fb246a-aa17-4bfe-986d-12e8f883feb8_6" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "prometheus.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  logo_url                   = "https://prometheus.io/_next/static/media/prometheus-logo.7aa022e5.svg"
  name                       = "Prometheus"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "prometheus.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "918b5d0c-bc97-43a0-bd75-a30ced36ee34", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_d5603aa8-4710-4c96-b391-d015c4b3ed00_7" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "alloy.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Alloy"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "alloy.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_b98ff605-5a02-4b72-9541-c979c8d7d278_8" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "dbeaver.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "DBeaver"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "dbeaver.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_2153279e-3785-4b1f-8de5-478486765589_9" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "bazarr.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Bazarr"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "bazarr.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_9a0e85ac-9dea-4c1b-adc7-9d457e0c136a_10" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "lidarr.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Lidarr"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "lidarr.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_0fa37c5b-78a4-4328-946f-4ac60d0762c4_11" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "prowlarr.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Prowlarr"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "prowlarr.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_3675e53b-77ec-4fac-b564-cfdf54083b98_12" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "radarr.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Radarr"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "radarr.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_2fcf160c-1c8f-4bfd-a8f2-5be8e95f3e3d_13" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "requestrr.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Requestrr"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "requestrr.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_47ab797b-47f4-4496-bcd4-171a769fc83e_14" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "sonarr.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Sonarr"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "sonarr.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_ae74fd30-72d8-4571-a8bb-bf1d69ccb2dc_15" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "plex.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Plex"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "plex.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_cf7430d6-4d40-4b8c-b8b7-68302339ad7f_16" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "tmm.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "TMM"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "tmm.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_9182ca57-1c80-4eb2-b059-ab2e2ed0421e_17" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "esphome.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "ESPHome"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "esphome.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_bdbd02f6-e399-46f1-baea-168599ed42ff_18" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "hass.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "HASS"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "hass.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_e32eed92-bc81-4db7-925d-e05b3950ac04_19" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "zigbee2mqtt.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Zigbee2MQTT"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "zigbee2mqtt.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_3555a630-4929-40fb-bc6f-b2e8f16ed96c_20" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "yggdrasil.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Yggdrasil"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "yggdrasil.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_cc540891-4921-4392-9925-1786ba53aba8_21" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "ucg.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "UCG"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "ucg.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_2b5f4d5d-c917-4ea9-8111-fbd42ec54ab6_22" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "vw.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Vaultwarden"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "vw.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_df864cbc-f24f-44b9-958f-fd145f1f056e_23" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "irc.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "IRC"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "irc.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_d826cca0-cfcc-4207-a652-bc86612c0637_24" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "tautulli.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Tautulli"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "tautulli.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_c84e2629-85a4-46c3-8c86-03f05f19ff63_25" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "download.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Download"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "download.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_6e6704ac-817c-49e0-99a7-a98827aaa4ab_26" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "keycloak.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Keycloak"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "keycloak.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_e83f521b-c6e7-4736-9cff-790a0f77e99e_27" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "oauth2-proxy.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "OAuth2-Proxy"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "oauth2-proxy.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_9e8cad90-2640-4a48-a290-c3294c45322a_28" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "immich.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Immich"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "immich.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_d091e88f-3dde-496a-8d8e-a2e8a84e6dc6_29" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "scrypted.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Scrypted"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "scrypted.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_aecd0108-5d52-4ebb-b719-6b09d287fe74_30" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "gramps.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Gramps"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "gramps.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_c1f9f2b8-2a25-4fbf-ae9c-dd88e7953aed_31" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "vonage.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Vonage"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "vonage.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_9cfa39e6-653d-4b45-b2f2-8bec17b590ea_32" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "mousehole.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Mousehole"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "mousehole.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_30060319-e6c9-45d7-8a5d-787b90f10f22_33" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "mass-alexa.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "MASS-Alexa"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "mass-alexa.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_465adc1f-2149-40e3-85f0-3197028c162e_34" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "mass-stream.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "MASS-Stream"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "mass-stream.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_6fb770a2-6b06-4dee-8ad2-1954d65cf8c1_35" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "mass.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "MASS"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "mass.ebi.nu"
  }]
  policies = [
    { id = "16079c5e-e6e7-469e-8df1-8a7e326d11d5", precedence = 1 },
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 2 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_a9c3cf91-ba08-4b38-90bf-5d7117a32756_36" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "frigate.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Frigate"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "frigate.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_c20cb2ce-6ee1-4741-9a51-d6274bbad13c_37" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "atuin.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Atuin"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "atuin.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "918b5d0c-bc97-43a0-bd75-a30ced36ee34", precedence = 3 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 4 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 5 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_8687644a-f50b-4905-8af2-b8b24fa0e89c_38" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "browser.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Browser"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "browser.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_d07b91cb-a13c-42a2-b779-120145ae67a5_39" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "dns.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "DNS"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "dns.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_5df0c802-c8fb-43f8-a0d1-a298246eb416_40" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "birdnet.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Birdnet"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "birdnet.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}

resource "cloudflare_zero_trust_access_application" "terraform_managed_resource_ed792e89-68b9-48c2-bb0d-3306534d7bf0_41" {
  account_id                 = "bbe7e7cd88aa3e9d775379a230d15953"
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "kuma.ebi.nu"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Kuma"
  options_preflight_bypass   = false
  session_duration           = "24h"
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "kuma.ebi.nu"
  }]
  policies = [
    { id = "792a444d-afde-4854-92d1-b0af5df74486", precedence = 1 },
    { id = "3f0ca63e-1ab7-4de5-be88-88fa928586c3", precedence = 2 },
    { id = "a08335e3-3d47-468d-8428-d4734ef4fb7a", precedence = 3 },
    { id = "ac74c778-98a0-431e-865d-3adef9e8487e", precedence = 4 }
  ]
}
