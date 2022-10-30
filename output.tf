##############################################################################################################
#
# K3s - Kubernetes on Oracle Cloud Always Free Tier
#
##############################################################################################################

output "servernode_public_ip" {
  value = oci_core_instance.k3s_servernode.public_ip
}

output "servernode_private_ip" {
  value = oci_core_instance.k3s_servernode.private_ip
}

output "agentnode_1_public_ip" {
  value = oci_core_instance.k3s_agentnodes[0].public_ip
}

output "agentnode_1_private_ip" {
  value = oci_core_instance.k3s_agentnodes[0].private_ip
}

output "agentnode_2_public_ip" {
  value = oci_core_instance.k3s_agentnodes[1].public_ip
}

output "agentnode_2_private_ip" {
  value = oci_core_instance.k3s_agentnodes[1].private_ip
}
