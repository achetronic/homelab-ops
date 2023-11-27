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
resource "opnsense_unbound_host_override" "compute_01" {
  enabled = true
  description = "Compute @ Odroid 01"

  hostname = "compute-01"
  domain = "internal.place"
  server = "192.168.2.11"
}

resource "opnsense_unbound_host_override" "compute_02" {
  enabled = true
  description = "Compute @ Odroid 02"

  hostname = "compute-02"
  domain = "internal.place"
  server = "192.168.2.12"
}

resource "opnsense_unbound_host_override" "compute_03" {
  enabled = true
  description = "Compute @ Odroid 03"

  hostname = "compute-03"
  domain = "internal.place"
  server = "192.168.2.13"
}

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
resource "opnsense_unbound_host_alias" "kubernetes_01_masters_balance_01" {
  override = opnsense_unbound_host_override.compute_01.id

  enabled = false
  hostname = "kubernetes-01"
  domain = "internal.place"
}

resource "opnsense_unbound_host_alias" "kubernetes_01_masters_balance_02" {
  override = opnsense_unbound_host_override.compute_02.id

  enabled = false
  hostname = "kubernetes-01"
  domain = "internal.place"
}

resource "opnsense_unbound_host_alias" "kubernetes_01_masters_balance_03" {
  override = opnsense_unbound_host_override.compute_03.id

  enabled = false
  hostname = "kubernetes-01"
  domain = "internal.place"
}

resource "opnsense_unbound_host_alias" "kubernetes_01_masters_balance_03" {
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
