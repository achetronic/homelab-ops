#######################################
## Firewall machines DNS registries
#######################################
resource "opnsense_unbound_host_override" "router_01" {
  enabled = true
  description = "Router @ OPNsense"

  hostname = "router-01"
  domain = "internal.place"
  server = "192.168.2.1"
}

#######################################
## Compute machines DNS registries
#######################################
# Resources related to Compute 01 (this is an hypervisor)
resource "opnsense_unbound_host_override" "metal_compute_10" {
  enabled = true
  description = "Metal @ Compute 10"

  hostname = "compute-10"
  domain = "internal.place"
  server = "192.168.2.10"
}

resource "opnsense_unbound_host_override" "vm_01_compute_10" {
  enabled = true
  description = "VM 01 @ Compute 10"

  hostname = "compute-11"
  domain = "internal.place"
  server = "192.168.2.11"
}

resource "opnsense_unbound_host_override" "vm_02_compute_10" {
  enabled = true
  description = "VM 02 @ Compute 10"

  hostname = "compute-12"
  domain = "internal.place"
  server = "192.168.2.12"
}

resource "opnsense_unbound_host_override" "vm_03_compute_10" {
  enabled = true
  description = "VM 03 @ Compute 10"

  hostname = "compute-13"
  domain = "internal.place"
  server = "192.168.2.13"
}

# Resources related to SPCs (this are mainly OrangePI 5 boards that will be kicked off the rack)
resource "opnsense_unbound_host_override" "compute_04" {
  enabled = true
  description = "Compute @ OrangePi 01"

  hostname = "compute-04"
  domain = "internal.place"
  server = "192.168.2.14"
}

resource "opnsense_unbound_host_override" "compute_05" {
  enabled = true
  description = "Compute @ OrangePi 02"

  hostname = "compute-05"
  domain = "internal.place"
  server = "192.168.2.15"
}

#######################################
## Storage machines DNS registries
#######################################
resource "opnsense_unbound_host_override" "storage_01" {
  enabled = true
  description = "Storage @ TrueNAS 01"

  hostname = "storage-01"
  domain = "internal.place"
  server = "192.168.2.21"
}

#######################################
## Applications DNS registries
#######################################

# Balance the requests between Kubernetes 01 master servers
#resource "opnsense_unbound_host_alias" "kubernetes_01_masters_balance_01" {
#  override = opnsense_unbound_host_override.compute_01.id
#
#  enabled = false
#  hostname = "kubernetes-01"
#  domain = "internal.place"
#}

resource "opnsense_unbound_host_alias" "kubernetes_01_masters_balance_04" {
  override = opnsense_unbound_host_override.compute_04.id

  enabled = true
  hostname = "kubernetes-01"
  domain = "internal.place"
}

resource "opnsense_unbound_host_override" "kubernetes_ingress_lb" {
  enabled = true
  description = "Point all the tools to Kubernetes ingress controller's LB"

  hostname = "*"
  domain = "tools.internal.place"
  server = "192.168.2.60"
}

resource "opnsense_unbound_host_alias" "kubernetes_02_masters_balance_11" {
  override = opnsense_unbound_host_override.vm_01_compute_10.id

  enabled = true
  hostname = "kubernetes-02"
  domain = "internal.place"
}

resource "opnsense_unbound_host_alias" "kubernetes_02_masters_balance_12" {
  override = opnsense_unbound_host_override.vm_02_compute_10.id

  enabled = true
  hostname = "kubernetes-02"
  domain = "internal.place"
}
