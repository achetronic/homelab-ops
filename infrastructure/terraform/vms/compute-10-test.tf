# TODO
locals {

  # Globals definition
  globals_test = {

    # Configuration for SSH connection parameters
    ssh_connection = {
      host     = data.gitlab_project_variable.instance_access_compute_10_host.value
      username = data.gitlab_project_variable.instance_access_compute_10_username.value
      password = data.gitlab_project_variable.instance_access_compute_10_password.value
      mode     = "password"
    }

    talos = {
      version = "v1.6.3"
    }
  }


  # Instance basic definition.
  # WARNING: Choose IP a address inside the right subnet
  instances_test = {

    # Define the masters
    compute-test = {

      vcpu   = 4
      memory = 4 * 1024
      disk   = 20000000000

      networks = [
        {
          interface = "enp1s0"
          addresses = ["192.168.2.16"]
          mac       = "CE:65:9B:BC:66:BA"
        }
      ]
    }
  }
}

