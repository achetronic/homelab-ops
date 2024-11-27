# TODO
data "gitlab_project_variable" "instance_access_compute_10_username" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key     = "INSTANCE_ACCESS_COMPUTE_10_USERNAME"
}

data "gitlab_project_variable" "instance_access_compute_10_password" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key     = "INSTANCE_ACCESS_COMPUTE_10_PASSWORD"
}

data "gitlab_project_variable" "instance_access_compute_10_host" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key     = "INSTANCE_ACCESS_COMPUTE_10_HOST"
}

# TODO
locals {

  # Globals definition
  globals_compute_10 = {

    # Configuration for SSH connection parameters
    ssh_connection = {
      host     = data.gitlab_project_variable.instance_access_compute_10_host.value
      username = data.gitlab_project_variable.instance_access_compute_10_username.value
      password = data.gitlab_project_variable.instance_access_compute_10_password.value
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
  instances_compute_10 = {

    # Define the masters
    compute-11 = {
      image = "talos_v1.6.1_metal_amd64"

      vcpu   = 4
      memory = 5 * 1024
      disk   = 20000000000

      networks = [
        {
          interface   = "enp1s0"
          addresses   = ["192.168.2.11"]
          mac         = "CE:65:9B:BC:66:BE"
        }
      ]
    }

    compute-12 = {
      image = "talos_v1.6.1_metal_amd64"

      vcpu   = 4
      memory = 5 * 1024
      disk   = 20000000000

      networks = [
        {
          interface   = "enp1s0"
          addresses   = ["192.168.2.12"]
          mac         = "46:8F:5E:5B:DF:5F"
        }
      ]
    }

    # Define the workers
    compute-13 = {
      image = "talos_v1.6.1_metal_amd64"

      vcpu   = 6
      memory = 20 * 1024
      disk   = 20000000000

      networks = [
        {
          interface   = "enp1s0"
          addresses   = ["192.168.2.13"]
          mac         = "46:6D:08:95:51:3B"
        }
      ]

      # TODO: Craft a task to install xsltproc
      # This requires to have installed 'xsltproc' in client's machine
      # Ref: https://gist.github.com/goja288/9b8122cedd042156a1cea2af2bfa0f09
      xslt = file("${path.module}/templates/xsl/attach-usb.xsl")
    }
  }
}

