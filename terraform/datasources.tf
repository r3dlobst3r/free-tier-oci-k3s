##############################################################################################################
#
# K3s - Kubernetes on Oracle Cloud Always Free Tier
#
##############################################################################################################

# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}
