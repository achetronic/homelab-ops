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

    # Kubernetes version launched in this version of Talos
    kubernetes = object({
      version = string
    })

    # Configuration parameters used to generate initial config
    config = object({
      cluster_name          = string
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

      # Vars used by the controlplane template included in this module
      # to patch the auto-generated talos cluster+machine config.
      # The module always injects 'talos_version' from globals.talos.version.
      config_template_vars = optional(any)
    }))

    workers = map(object({
      # IP or FQDN that is reachable through current network
      node_address = string

      # Vars used by the worker template included in this module
      # to patch the auto-generated talos cluster+machine config.
      # The module always injects 'talos_version' from globals.talos.version.
      config_template_vars = optional(any)
    }))
  })
}
