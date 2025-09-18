# -----------------------------------------------------------
# Section 1: Terraform Settings and Provider Declarations
# -----------------------------------------------------------
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

# Provider for the 'gouravhalder-careq' project
provider "google" {
  alias   = "careq"
  project = "gouravhalder-careq"
}

# Provider for the 'gouravhalder-sandbox' project
provider "google" {
  alias   = "sandbox"
  project = "gouravhalder-sandbox"
}

################################################################################
# Project: gouravhalder-careq
################################################################################

# Enable CAS API in careq
resource "google_project_service" "cas_api_careq" {
  provider           = google.careq
  project            = "gouravhalder-careq"
  service            = "privateca.googleapis.com"
  disable_on_destroy = true
}

################################################################################
# IAM Bindings for Certificate Manager SA
################################################################################

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

  ca_pool  = "projects/gouravhalder-sandbox/locations/europe-west4/caPools/consolepool"

  role     = "roles/privateca.certificateRequester"
  member   = google_project_service_identity.cert_manager_sa.member
}

################################################################################
# Issuance Config in gouravhalder-careq
################################################################################

resource "random_string" "ca_suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "google_certificate_manager_certificate_issuance_config" "issuance_config" {
  provider    = google.careq
  name        = "issuance-config-${random_string.ca_suffix.id}"
  location    = "europe-west4"
  description = "Issuance config to use specific CA from sandbox project"

  certificate_authority_config {
    certificate_authority_service_config {
      # Directly reference the full CA resource path in sandbox project
      ca_pool = "projects/gouravhalder-sandbox/locations/europe-west4/caPools/consolepool"

    }
  }

  lifetime                   = "2592000s"  # 30 days
  rotation_window_percentage = 33
  key_algorithm              = "RSA_2048"

  # Only needed if you want to ensure CA exists before creating issuance config
  depends_on = [
    google_privateca_ca_pool_iam_member.cm_sa_can_request
  ]
}
