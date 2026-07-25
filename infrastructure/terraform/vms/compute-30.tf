# TODO
data "gitlab_project_variable" "instance_access_compute_30_username" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key = "INSTANCE_ACCESS_COMPUTE_30_USERNAME"
}

data "gitlab_project_variable" "instance_access_compute_30_password" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key = "INSTANCE_ACCESS_COMPUTE_30_PASSWORD"
}

data "gitlab_project_variable" "instance_access_compute_30_host" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key = "INSTANCE_ACCESS_COMPUTE_30_HOST"
}

# TODO
locals {

  # Globals definition
  globals_compute_30 = {

    # Configuration for SSH connection parameters
    ssh_connection = {
      host     = data.gitlab_project_variable.instance_access_compute_30_host.value
      username = data.gitlab_project_variable.instance_access_compute_30_username.value
      password = data.gitlab_project_variable.instance_access_compute_30_password.value
      mode     = "password"
    }

    # You can define as many urls as needed
    # Expected format: map[string]string
    # Example: {"desired_name" = "https://url/to/image.iso"}
    iso_image_urls = {
      "talos_v1.6.1_metal_amd64"  = "https://github.com/siderolabs/talos/releases/download/v1.6.1/metal-amd64.iso",
      "talos_v1.10.2_metal_amd64" = "https://github.com/siderolabs/talos/releases/download/v1.10.2/metal-amd64.iso"
    }
  }


  # Instance basic definition.
  # WARNING: Choose IP a address inside the right subnet
  instances_compute_30 = {

    # Define the masters
    compute-31 = {
      image = "talos_v1.10.2_metal_amd64"

      vcpu   = 4
      memory = 5 * 1024 * 1024 # KiB
      disk   = 20000000000

      networks = [
        {
          interface = "eno1"
          addresses = ["192.168.2.31"]
          mac       = "52:54:00:d7:3a:9e"
        }
      ]
    }

    # Define the workers
    compute-32 = {
      image = "talos_v1.10.2_metal_amd64"

      vcpu   = 6
      memory = 25 * 1024 * 1024 # KiB
      disk   = 60000000000      # qemu-img resize /opt/libvirt/vms-volume-pool/compute-32.qcow2 60G

      networks = [
        {
          interface = "eno1"
          addresses = ["192.168.2.32"]
          mac       = "52:54:00:b2:6f:41"
        }
      ]
    }

  }
}
