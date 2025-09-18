terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.2"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

################################################################################
# Providers
################################################################################
# Sandbox project (where CA pool + Root CA live)
provider "google" {
  alias   = "sandbox"
  project = "gouravhalder-sandbox"
  region  = "europe-west4"
}

# Careq project (where issuance config lives)
provider "google" {
  alias   = "careq"
  project = "gouravhalder-careq"
  region  = "europe-west4"
}

################################################################################
# Project: gouravhalder-sandbox (Root CA + Pool)
################################################################################

# Enable Private CA API
resource "google_project_service" "privateca_sandbox" {
  provider = google.sandbox
  project  = "gouravhalder-sandbox"
  service  = "privateca.googleapis.com"
}

# Create a CA Pool
resource "google_privateca_ca_pool" "root_pool" {
  provider = google.sandbox
  name     = "mainroot-ca-pool"
  location = "europe-west4"
  tier     = "DEVOPS"

  lifecycle {
    prevent_destroy = false
  }
}

# Create a Root Certificate Authority
resource "google_privateca_certificate_authority" "root_ca" {
  provider                 = google.sandbox
  certificate_authority_id = "mainroot-ca"
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
    algorithm = "RSA_PKCS1_4096_SHA256"
  }

  lifetime = "315360000s" # 10 years

  lifecycle {
    prevent_destroy = true
  }
}

################################################################################
# Project: gouravhalder-careq (Issuance Config + IAM)
################################################################################

# Enable CAS API in careq
resource "google_project_service" "cas_api_careq" {
  provider           = google.careq
  project            = "gouravhalder-careq"
  service            = "privateca.googleapis.com"
  disable_on_destroy = true
}

# Cert Manager SA (auto-created identity in careq project)
resource "google_project_service_identity" "cert_manager_sa" {
  provider = google-beta
  project  = "gouravhalder-careq"
  service  = "certificatemanager.googleapis.com"
}

# Grant CertificateRequester role on the CA Pool in sandbox project
resource "google_privateca_ca_pool_iam_member" "cm_sa_can_request" {
  provider = google-beta
  project  = "gouravhalder-sandbox"
  location = "europe-west4"

  ca_pool  = google_privateca_ca_pool.root_pool.id

  role   = "roles/privateca.certificateRequester"
  member = google_project_service_identity.cert_manager_sa.member
}

# Random suffix for issuance config name
resource "random_string" "ca_suffix" {
  length  = 4
  upper   = false
  special = false
}

# Issuance Config in careq project
resource "google_certificate_manager_certificate_issuance_config" "issuance_config" {
  provider    = google.careq
  name        = "issuance-config-${random_string.ca_suffix.id}"
  location    = "europe-west4"
  description = "Issuance config to use specific CA from sandbox project"

  certificate_authority_config {
    certificate_authority_service_config {
      #ca_pool = google_privateca_ca_pool.root_pool.id
      ca_pool = "projects/${google_privateca_ca_pool.root_pool.project}/locations/${google_privateca_ca_pool.root_pool.location}/caPools/${google_privateca_ca_pool.root_pool.name}"
    }
  }

  lifetime                   = "2592000s"  # 30 days
  rotation_window_percentage = 33
  key_algorithm              = "RSA_2048"

  depends_on = [
    google_privateca_ca_pool_iam_member.cm_sa_can_request
  ]
}
