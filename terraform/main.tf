##############################################################################################################
#
# K3s - Kubernetes on Oracle Cloud Always Free Tier
#
##############################################################################################################

##############################################################################################################
## VCN
##############################################################################################################

module "vcn" {
  source  = "oracle-terraform-modules/vcn/oci"
  version = ">3.5.0"

  compartment_id = var.compartment_ocid
  region         = var.region

  internet_gateway_route_rules = null
  local_peering_gateways       = null
  nat_gateway_route_rules      = null

  vcn_name      = "${var.PREFIX}-vcn"
  vcn_dns_label = "${var.PREFIX}hub"
  vcn_cidrs     = [var.vcn]

  create_internet_gateway = true
  create_nat_gateway      = false
  create_service_gateway  = false

  internet_gateway_display_name = "${var.PREFIX}-igw"
}

##############################################################################################################
## Server node NETWORK
##############################################################################################################

resource "oci_core_subnet" "servernode_subnet" {
  cidr_block        = var.subnet["1"]
  display_name      = "${var.PREFIX}-servernode"
  compartment_id    = var.compartment_ocid
  vcn_id            = module.vcn.vcn_id
  route_table_id    = oci_core_route_table.servernode_routetable.id
  security_list_ids = ["${module.vcn.vcn_all_attributes.default_security_list_id}", "${oci_core_security_list.servernode_security_list.id}"]
  dhcp_options_id   = module.vcn.vcn_all_attributes.default_dhcp_options_id
  dns_label         = "${var.PREFIX}servernode"
}

resource "oci_core_route_table" "servernode_routetable" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.vcn.vcn_id
  display_name   = "${var.PREFIX}-servernode-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = module.vcn.internet_gateway_id
  }
}

resource "oci_core_security_list" "servernode_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.vcn.vcn_id
  display_name   = "${var.PREFIX}-servernode-security-list"

  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    source   = "172.16.32.0/24"
    protocol = "all"
  }

  // allow inbound http (port 80) traffic
  ingress_security_rules {
    protocol = "6" // tcp
    source   = "0.0.0.0/0"

    tcp_options {
      min = 80
      max = 80
    }
  }

  // allow inbound http (port 443) traffic
  ingress_security_rules {
    protocol = "6" // tcp
    source   = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }

  // allow inbound ssh traffic
  ingress_security_rules {
    protocol  = "6" // tcp
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  // allow inbound icmp traffic of a specific type
  ingress_security_rules {
    protocol = 1
    source   = "0.0.0.0/0"
  }
}

##############################################################################################################
## Worker node NETWORK
##############################################################################################################

resource "oci_core_subnet" "agentnode_subnet" {
  cidr_block        = var.subnet["3"]
  display_name      = "${var.PREFIX}-agentnode"
  compartment_id    = var.compartment_ocid
  vcn_id            = module.vcn.vcn_id
  route_table_id    = oci_core_route_table.agentnode_routetable.id
  security_list_ids = ["${module.vcn.vcn_all_attributes.default_security_list_id}", "${oci_core_security_list.agentnode_security_list.id}"]
  dhcp_options_id   = module.vcn.vcn_all_attributes.default_dhcp_options_id
  dns_label         = "${var.PREFIX}agentnode"
  /* prohibit_public_ip_on_vnic = true */
}

resource "oci_core_route_table" "agentnode_routetable" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.vcn.vcn_id
  display_name   = "${var.PREFIX}-agentnode-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = module.vcn.internet_gateway_id
  }
}

resource "oci_core_security_list" "agentnode_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = module.vcn.vcn_id
  display_name   = "${var.PREFIX}-internal-security-list"

  // allow outbound traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  // allow inbound traffic on all ports
  ingress_security_rules {
    protocol = "all"
    source   = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "backend_subnet" {
  cidr_block        = var.subnet["2"]
  display_name      = "${var.PREFIX}-backend"
  compartment_id    = var.compartment_ocid
  vcn_id            = module.vcn.vcn_id
  security_list_ids = ["${module.vcn.vcn_all_attributes.default_security_list_id}", "${oci_core_security_list.servernode_security_list.id}"]
  dhcp_options_id   = module.vcn.vcn_all_attributes.default_dhcp_options_id
  dns_label         = "${var.PREFIX}backend"
}

##############################################################################################################
## K3s server node
##############################################################################################################
// create oci instance for active
resource "oci_core_instance" "k3s_servernode" {
  depends_on = [module.vcn]

  availability_domain = lookup(data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain - 1], "name")
  compartment_id      = var.compartment_ocid
  display_name        = "${var.PREFIX}-k3s-servernode"
  shape               = var.instance_shape
  shape_config {
    memory_in_gbs = "4"
    ocpus         = "1"
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.servernode_subnet.id
    display_name     = "${var.PREFIX}-k3s-server-vnic-servernode"
    assign_public_ip = true
    hostname_label   = "${var.PREFIX}-k3s-server-vnic-servernode"
    private_ip       = local.servernode_ipaddresses["2"]
  }

  source_details {
    source_id               = var.vm_image_ocid_ampere
    source_type             = "image"
    boot_volume_size_in_gbs = var.volume_size
  }

  // Required for bootstrap
  // Commnet out the following if you use the feature.
  metadata = {
    user_data           = base64encode(([templatefile("${path.module}/customdata-k3s-server.tftpl", { k3s_token = var.K3S_TOKEN })])[0])
    ssh_authorized_keys = file("id_ed2519.pub")
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

##############################################################################################################
## K3s agent node
##############################################################################################################
// create oci instance for active
resource "oci_core_instance" "k3s_agentnodes" {
  depends_on = [oci_core_instance.k3s_servernode]
  count      = var.number_of_agentnodes

  availability_domain = lookup(data.oci_identity_availability_domains.ads.availability_domains[0], "name")
  compartment_id      = var.compartment_ocid
  display_name        = format("%s-k3s-agentnode-%03d", var.PREFIX, count.index + 1)
  shape               = var.instance_shape
  shape_config {
    memory_in_gbs = "6"
    ocpus         = "1"
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.agentnode_subnet.id
    display_name     = format("%s-k3s-agentnode-%03d", var.PREFIX, count.index + 1)
    assign_public_ip = true
    hostname_label   = format("%s-k3s-agentnode-%03d", var.PREFIX, count.index + 1)
  }

  source_details {
    source_id               = var.vm_image_ocid_ampere
    source_type             = "image"
    boot_volume_size_in_gbs = var.volume_size
  }

  // Required for bootstrap
  // Commnet out the following if you use the feature.
  metadata = {
    user_data           = base64encode(([templatefile("${path.module}/customdata-k3s-agent.tftpl", { server_ip = local.servernode_ipaddresses["2"], k3s_token = var.K3S_TOKEN })])[0])
    ssh_authorized_keys = file("id_ed2519.pub")
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}
