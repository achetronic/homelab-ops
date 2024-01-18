# The globals block is the place to define global stuff
# mostly related to parameters for Talos to generate
# initial configuration YAMLs and secrets
variable "globals" {
  description = "Global configuration definition block"

  type = object({

    # Talos version that generated initial secrets and config
    talos = object({
      version = string
    })

    # Configuration parameters used to generate initial config
    config = object({
      cluster_name = string
      controlplane_endpoint = string
    })
  })
}

# TODO
variable "node_data" {
  description = "A map of node data"

  type = object({

    controlplanes = map(object({
      # IP or FQDN that is reachable through current network
      node_address = string

      # YAML terraform template and vars to substitute to patch
      # auto-generated talos cluster+machine config
      config_template_path = string
      config_template_vars = optional(any)
    }))

    workers = map(object({
      # IP or FQDN that is reachable through current network
      node_address = string

      # YAML terraform template and vars to substitute to patch
      # auto-generated talos cluster+machine config
      config_template_path = string
      config_template_vars = optional(any)
    }))
  })
}



