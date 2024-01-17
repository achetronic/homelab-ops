variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
  default     = "kubernetes-02"
}

variable "cluster_endpoint" {
  description = "The endpoint for the Talos cluster"
  type        = string
  default     = "https://kubernetes-02.internal.place:6443"
}

variable "node_data" {
  description = "A map of node data"

  type = object({
    controlplanes = map(object({
      install_disk = string
      hostname     = optional(string)
    }))
    workers = map(object({
      install_disk = string
      hostname     = optional(string)
    }))
  })

  default = {
    controlplanes = {
      "192.168.2.11" = {
        hostname      = "compute-11"
        install_disk = "/dev/sda"
      },
      "192.168.2.12" = {
        hostname     = "compute-12"
        install_disk = "/dev/sda"
      }
    }
    workers = {
      "192.168.2.13" = {
        hostname     = "compute-13"
        install_disk = "/dev/sda"
      }
    }
  }
}


# The globals block is the place to define global stuff
# mostly related to things that are common to all the VMs,
# such as the credentials to connect to the hypervisor
variable "globals" {
  type = object({

    # Name of Kubernetes cluster
    cluster_name = string

    # Endpoint to reach API server
    cluster_endpoint = string

    # SSH parameters to connect to the host
    machine = object({

      # IP address to connect to the host
      certSans = list(string)
    })

    # Parameters related to Talos
    talos = object({
      version = string
    })

  })

  description = "Global configuration definition block"
}
