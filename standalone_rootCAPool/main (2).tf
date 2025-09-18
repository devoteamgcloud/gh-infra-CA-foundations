provider "google" {
  project = "gouravhalder-sandbox"
  region  = "europe-west4"
}

# Enable the Private CA API
resource "google_project_service" "privateca" {
  service = "privateca.googleapis.com"
}

# Create a CA Pool
resource "google_privateca_ca_pool" "root_pool" {
  name     = "myroot-ca-pool"
  location = "europe-west4"
  tier     = "DEVOPS"
}

# Create a Root Certificate Authority
resource "google_privateca_certificate_authority" "root_ca" {
  certificate_authority_id = "myroot-ca"
  location                 = google_privateca_ca_pool.root_pool.location
  pool                     = google_privateca_ca_pool.root_pool.name
  type                     = "SELF_SIGNED"
  deletion_protection      = false

  config {
    subject_config {
      subject {
        common_name         = "root-ca.gouravhalder-sandbox"
        organization        = "Gourav Halder"
        organizational_unit = "Platform"
        locality            = "Stockholm"
        province            = "Stockholm"
        country_code        = "SE"
      }
    }

    x509_config {
      ca_options {
        is_ca = true
      }
      key_usage {
        base_key_usage {
          cert_sign = true
          crl_sign  = true
        }
        extended_key_usage {
          server_auth = true
          client_auth = true
        }
      }
    }
  }

  key_spec {
    algorithm = "RSA_PKCS1_4096_SHA256" # RSA2048
  }

  lifetime = "315360000s" # 10 years
}