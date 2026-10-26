resource "cloudflare_dns_record" "terraform_managed_resource_9717e31295d75533722402b61d8dac88_0" {
  content  = "209.15.228.200"
  name     = "500px.ebertek.com"
  proxied  = false
  tags     = []
  ttl      = 86400
  type     = "A"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_3c03f83f3d8d99af568bb90e7b9c08a3_1" {
  content = "d.ktk.bme.hu"
  name    = "d.ebertek.com"
  proxied = false
  tags    = []
  ttl     = 86400
  type    = "CNAME"
  zone_id = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {
    flatten_cname = false
  }
}

resource "cloudflare_dns_record" "terraform_managed_resource_5658602202ba436fc5ee56da48f44e4f_2" {
  content = "ebertek.com"
  name    = "*.ebertek.com"
  proxied = false
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {
    flatten_cname = false
  }
}

resource "cloudflare_dns_record" "terraform_managed_resource_2bab6a6b4c37fb44b3fe723bcf47bdac_3" {
  content = "hc.ebi.nu"
  name    = "ebertek.com"
  proxied = false
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {
    flatten_cname = false
  }
}

resource "cloudflare_dns_record" "terraform_managed_resource_f87f3573f8a3df0d84f831d2f34e5ee3_4" {
  content = "52acd579-76f3-4b52-bec4-8c505258a7b1.cfargotunnel.com"
  name    = "mirror.ebertek.com"
  proxied = true
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {
    flatten_cname = false
  }
}

resource "cloudflare_dns_record" "terraform_managed_resource_fac35460b30a92423c7acfb86f276d5c_5" {
  content = "wkd.keys.openpgp.org"
  name    = "openpgpkey.ebertek.com"
  proxied = false
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {
    flatten_cname = false
  }
}

resource "cloudflare_dns_record" "terraform_managed_resource_5664e3f89202abdce78f55c08819a091_6" {
  content = "ebertek.com"
  name    = "www.ebertek.com"
  proxied = false
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {
    flatten_cname = false
  }
}

resource "cloudflare_dns_record" "terraform_managed_resource_ffd401b4719757394a766088fdd3f47b_7" {
  name    = "ebertek.com"
  proxied = false
  tags    = []
  ttl     = 86400
  type    = "LOC"
  zone_id = "74ca30b14b96ba174a06c9ba1f6886ce"
  data = {
    altitude       = 133
    lat_degrees    = 47
    lat_direction  = "N"
    lat_minutes    = 29
    lat_seconds    = 14.186
    long_degrees   = 19
    long_direction = "E"
    long_minutes   = 1
    long_seconds   = 30.598
    precision_horz = 10
    precision_vert = 10
    size           = 10
  }
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_439ef1af543797c107b58f643a06a515_8" {
  content  = "route3.mx.cloudflare.net"
  name     = "ebertek.com"
  priority = 72
  proxied  = false
  tags     = []
  ttl      = 1
  type     = "MX"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_05578aaf73d2894389548a7d96f4846c_9" {
  content  = "route2.mx.cloudflare.net"
  name     = "ebertek.com"
  priority = 1
  proxied  = false
  tags     = []
  ttl      = 1
  type     = "MX"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_ec0433e3ea3b2d2bea17a508c3036502_10" {
  content  = "route1.mx.cloudflare.net"
  name     = "ebertek.com"
  priority = 18
  proxied  = false
  tags     = []
  ttl      = 1
  type     = "MX"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_2b879284cced9dae8d740ccc70cada07_11" {
  content  = "\"v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiweykoi+o48IOGuP7GR3X0MOExCUDY/BCRHoWBnh3rChl7WhdyCxW3jgq1daEjPPqoi7sJvdg5hEQVsgVRQP4DcnQDVjGMbASQtrY4WmB1VebF+RPJB2ECPsEDTpeiI5ZyUAwJaVX7r6bznU67g7LvFq35yIo4sdlmtZGV+i0H4cpYH9+3JJ78k\" \"m4KXwaf9xUJCWF6nxeD+qG6Fyruw1Qlbds2r85U9dkNDVAS3gioCvELryh1TxKGiVTkg4wqHTyHfWsp7KD3WQHYJn0RyfJJu6YEmL77zonn7p2SRMvTMP3ZEXibnC9gz3nnhR6wcYL8Q7zXypKTMD58bTixDSJwIDAQAB\""
  name     = "cf2024-1._domainkey.ebertek.com"
  proxied  = false
  tags     = []
  ttl      = 1
  type     = "TXT"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_ba9428c06c1501196630634f27a9610b_12" {
  content  = "\"dh=c41f59376ce6c324808cbce997341a3d063a94f9\""
  name     = "_discord.ebertek.com"
  proxied  = false
  tags     = []
  ttl      = 1
  type     = "TXT"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_017ad4c9268defeefc9c3bac3ae211ae_13" {
  content  = "\"v=DMARC1;  p=none; rua=mailto:97a7d1156e6143b685d6eaec6ab117eb@dmarc-reports.cloudflare.net\""
  name     = "_dmarc.ebertek.com"
  proxied  = false
  tags     = []
  ttl      = 1
  type     = "TXT"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_20bd259dda580a9e04b681e28804f007_14" {
  content  = "\"v=spf1 include:_spf.mx.cloudflare.net ~all\""
  name     = "ebertek.com"
  proxied  = false
  tags     = []
  ttl      = 1
  type     = "TXT"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_b2b3b31d8050e9a26a1601a1a252f40f_15" {
  content  = "\"adn_verification=ebertek\""
  name     = "ebertek.com"
  proxied  = false
  tags     = []
  ttl      = 86400
  type     = "TXT"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_41a103611dfc884256ba6cb764c71968_16" {
  content  = "\"google-site-verification=aNzsWMhep6X_irKsxuxrb4XihcBYh_WWbwbkXJnVxlQ\""
  name     = "ebertek.com"
  proxied  = false
  tags     = []
  ttl      = 86400
  type     = "TXT"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_b28f90395aebebca6001ea79b5f11788_17" {
  content  = "\"google-site-verification=OuRYfqZkXDIG69WMk9BiRENDUszP23yGZJlw5fIW5tA\""
  name     = "ebertek.com"
  proxied  = false
  tags     = []
  ttl      = 86400
  type     = "TXT"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}

resource "cloudflare_dns_record" "terraform_managed_resource_ec418548e1371e2d0b952b8986bf7f74_18" {
  content  = "\"keybase-site-verification=Ymj58nuUfImxzsw83RpB4FJEHxuoScHgKtwwUGj8ARY\""
  name     = "ebertek.com"
  proxied  = false
  tags     = []
  ttl      = 86400
  type     = "TXT"
  zone_id  = "74ca30b14b96ba174a06c9ba1f6886ce"
  settings = {}
}
