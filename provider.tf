##############################################################################################################
#
# K3s - Kubernetes on Oracle Cloud Always Free Tier
#
##############################################################################################################

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key      = var.private_key
  region           = var.region
}

terraform {
  required_version = ">=1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">=4.69.0"
    }
  }
  cloud {
    organization = "untangled"

    workspaces {
      name = "free-oci-k3s"
    }
  }
}
