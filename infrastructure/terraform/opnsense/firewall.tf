########################################
### TODO ALIAS
########################################
#resource "opnsense_firewall_alias" "docker_reverse_proxy" {
#  name = "heimdal"
#
#  type = "host"
#  content = [
#    "192.168.2.2"
#  ]
#
#  stats       = true
#  description = "Custom name for Docker reverse proxy host"
#}
#
#resource "opnsense_firewall_alias" "kubernetes_lb_wireguard" {
#  name = "kubernetes_lb_wireguard"
#
#  type = "host"
#  content = [
#    "192.168.2.63"
#  ]
#
#  stats       = true
#  description = "Custom name for Kubernetes' LoadBalancer exposing Wireguard"
#}

#resource "opnsense_firewall_alias" "kubernetes_lb_wireguard" {
#  name = "test_kubernetes_lb_wireguard"
#
#  type    = "host"
#  content = [
#    "192.168.2.63"
#  ]
#
#  categories = []
#
#  stats       = false
#  description = "[TEST] Custom name for Kubernetes' LoadBalancer exposing Wireguard"
#}


########################################
### TODO NAT XXXXXX
########################################
#resource "opnsense_firewall_nat" "test_http_forwarding_rule" {
#  interface = "wan"
#  protocol  = "TCP"
#
#  source = {
#    net = "any"
#    invert = false
#  }
#
#  destination = {
#    net  = "wanip"
#    port = 8080
#  }
#
#  target = {
#    ip = "heimdal"
#    port = 80
#  }
#
#  description = "Forward HTTP traffic"
#}

## TODO
#resource "opnsense_firewall_nat" "http_forwarding_rule" {
#  interface = "wan"
#  protocol  = "TCP"
#
#  source = {
#    net = "any"
#    invert = false
#  }
#
#  destination = {
#    net  = "wanip"
#    port = 80
#  }
#
#  target = {
#    ip = "heimdal"
#    port = 80
#  }
#
#  description = "Forward HTTP traffic to Nginx Gateway"
#}

## TODO
#resource "opnsense_firewall_nat" "https_forwarding_rule" {
#  interface = "wan"
#  protocol  = "TCP"
#
#  source = {
#    net = "any"
#    invert = false
#  }
#
#  destination = {
#    net  = "wanip"
#    port = 443
#  }
#
#  target = {
#    ip = "heimdal"
#    port = 443
#  }
#
#  description = "Forward HTTPS traffic to Nginx Gateway"
#}

# TODO
#resource "opnsense_firewall_nat" "wireguard_forwarding_rule" {
#  interface = "wan"
#  protocol  = "UDP"
#
#  source = {
#    net = "any"
#    invert = false
#  }
#
#  destination = {
#    net  = "wanip"
#    port = 31830
#  }
#
#  target = {
#    ip = "kubernetes_lb_wireguard"
#    port = 31830
#  }
#
#  #description = "Forward UDP traffic on port '31825' to Wireguard"
#  description = "Example"
#}