# The globals block is the place to define global stuff
# mostly related to things that are common to all the VMs,
# such as the credentials to connect to the hypervisor
variable "globals" {
  type = object({

    # SSH parameters to connect to the host
    ssh_connection = object({
      # IP address to connect to the host
      host = string

      # Username to be authenticated in the host
      username = string

      # Password to be authenticated in the host
      password = optional(string)

      # Path to the ssh key (public or private) to be authenticated in the host
      # This key should already exists on the host machine
      key_path = optional(string)

      # Which auth method use on SSH connection: password, key
      mode = string
    })

    # Map of names that reference ISO images URIs.
    # These images will be downloaded instead of using them from remote
    # Expected format: map[string]string
    # Example: {"desired_name" = "https://url/to/image.iso"}
    iso_image_urls = map(string)
  })

  description = "Global configuration definition block"

  validation {
    condition     = contains(["password", "key"], var.globals.ssh_connection.mode)
    error_message = "Allowed values for ssh_connection.mode are \"password\" or \"key\"."
  }

  validation {
    condition = alltrue([for url in values(var.globals.iso_image_urls) : endswith(url, ".iso")])
    error_message = "All ISO image URLs must end with '.iso'."
  }
}

# The instances block is the place to define all the VMs
# (and their resources) that will be created
variable "instances" {
  type = map(object({

    image = string

    # TODO
    vcpu   = number
    memory = number
    disk   = number
    networks = list(object({
      interface = string
      addresses = list(string)
      mac       = string
    }))

    # XLST template to modify params of VM that are not covered by the module
    # Some XSLT tags will be deleted as Terraform cannot merge: xml, xsl:stylesheet, xsl:transform
    xslt = optional(string)

  }))
  description = "Instances definition block"

  validation {
    condition = alltrue(flatten([
      for instance_name, instance_definition in var.instances :
      [for network in instance_definition.networks :
        can(regex("^[a-fA-F0-9]{2}(:[a-fA-F0-9]{2}){5}$", network.mac)) ]
    ]))

    error_message = "Allowed values for instance.networks.mac are like: AA:BB:CC:DD:EE:FF."
  }
}
