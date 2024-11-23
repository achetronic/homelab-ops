# TODO
data "gitlab_project_variable" "instance_access_compute_20_username" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key     = "INSTANCE_ACCESS_COMPUTE_20_USERNAME"
}

data "gitlab_project_variable" "instance_access_compute_20_password" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key     = "INSTANCE_ACCESS_COMPUTE_20_PASSWORD"
}

data "gitlab_project_variable" "instance_access_compute_20_host" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key     = "INSTANCE_ACCESS_COMPUTE_20_HOST"
}

# TODO
locals {

  # Globals definition
  globals_compute_20 = {

    # Configuration for SSH connection parameters
    ssh_connection = {
      host     = data.gitlab_project_variable.instance_access_compute_20_host.value
      username = data.gitlab_project_variable.instance_access_compute_20_username.value
      password = data.gitlab_project_variable.instance_access_compute_20_password.value
      mode     = "password"
    }

    # You can define as many urls as needed
    # Expected format: map[string]string
    # Example: {"desired_name" = "https://url/to/image.iso"}
    iso_image_urls = {
      "talos_v1.6.1_metal_amd64" = "https://github.com/siderolabs/talos/releases/download/v1.6.1/metal-amd64.iso"
    }
  }


  # Instance basic definition.
  # WARNING: Choose IP a address inside the right subnet
  instances_compute_20 = {

    # Define the masters
    compute-21 = {
      image = "talos_v1.6.1_metal_amd64"

      vcpu   = 4
      memory = 5 * 1024
      disk   = 20000000000

      networks = [
        {
          interface   = "enp1s0"
          addresses   = ["192.168.2.21"]
          mac         = "02:7A:4F:3B:1E:62"
        }
      ]
    }

    # Define the workers
    compute-22 = {
      image = "talos_v1.6.1_metal_amd64"

      vcpu   = 10
      memory = 25 * 1024
      disk   = 20000000000

      networks = [
        {
          interface   = "enp1s0"
          addresses   = ["192.168.2.22"]
          mac         = "1A:4F:30:B8:F8:2D"
        }
      ]
    }

  }
}

