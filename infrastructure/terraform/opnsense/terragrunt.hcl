include "root" {
  path = find_in_parent_folders()
}

inputs = {
  GITLAB_ACCESS_TOKEN  = get_env("GITLAB_ACCESS_TOKEN")
}
