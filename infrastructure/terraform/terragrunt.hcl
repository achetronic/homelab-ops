remote_state {
  backend = "http"

  config = {
    address        = "https://gitlab.com/api/v4/projects/49083217/terraform/state/${path_relative_to_include()}"
    lock_address   = "https://gitlab.com/api/v4/projects/49083217/terraform/state/${path_relative_to_include()}/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/49083217/terraform/state/${path_relative_to_include()}/lock"
    username       = "achetronic"
    password       = get_env("GITLAB_ACCESS_TOKEN")
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = "5"
  }

}
