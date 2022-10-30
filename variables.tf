##############################################################################################################
#
# K3s - Kubernetes on Oracle Cloud Always Free Tier
#
##############################################################################################################

# Prefix for all resources created for this deployment in Microsoft Azure
variable "PREFIX" {
  description = "Added name to each deployed resource"
}

variable "region" {
  description = "Oracle Cloud region"
}

variable "K3S_TOKEN" {
  description = "Token to join agents to k3s server"
}

##############################################################################################################
# Oracle Cloud configuration
##############################################################################################################

variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "user_ocid" {
  default = ""
}
variable "private_key" {
  default = ""
}
variable "fingerprint" {
  default = ""
}

variable "instance_shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

##############################################################################################################
# VCN and SUBNET ADDRESSESS
##############################################################################################################

variable "vcn" {
  default = "172.16.32.0/24"
}

variable "subnet" {
  type        = map(string)
  description = ""

  default = {
    "1" = "172.16.32.0/27"   # Server node 
    "2" = "172.16.32.32/27"  # Backend
    "3" = "172.16.32.128/25" # Agent/Worker node
  }
}

locals {
  servernode_ipaddresses = {
    "1" = "${cidrhost(var.subnet["1"], 1)}" # Default GW
    "2" = "${cidrhost(var.subnet["1"], 4)}" # K3s server
  }
  agentnode_ipaddresses = {
    "1" = "${cidrhost(var.subnet["3"], 1)}" # Default GW
    "2" = "${cidrhost(var.subnet["3"], 4)}" # Agent 1
    "3" = "${cidrhost(var.subnet["3"], 5)}" # Agent 2
  }
}

variable "number_of_agentnodes" {
  type    = number
  default = 2
}

# Choose an Availability Domain (1,2,3)
variable "availability_domain" {
  type    = string
  default = "1"
}

variable "availability_domain2" {
  type    = string
  default = "2"
}

variable "volume_size" {
  type    = string
  default = "50" //GB; you can modify this, can't less than 50
}

variable "vm_image_ocid_ampere" {
  type    = string
  default = "ocid1.image.oc1.eu-amsterdam-1.aaaaaaaar7oga5lyoitgqhvtgnxltq2dhiyif7rkll7f36joqpmuth72mjza"
}
