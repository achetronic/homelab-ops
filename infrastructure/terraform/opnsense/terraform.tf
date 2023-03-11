# Ref: https://registry.terraform.io/providers/browningluke/opnsense/latest/docs
terraform {
  # Storing the .tfstate locally.
  # This is suitable only for testing purposes. Store it on S3 compatible backend for reliability
  #backend "local" {}
  backend "http" {}

  required_providers {
    gitlab = {
      source = "gitlabhq/gitlab"
      version = "~> 16.3.0"
    }

    opnsense = {
      version = "~> 0.6.0"
      source  = "browningluke/opnsense"
    }
  }
}

# Ref: https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs
provider "gitlab" {
  token = var.GITLAB_ACCESS_TOKEN
}

data "gitlab_project_variable" "opnsense_user_api_key_automation" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key     = "OPNSENSE_USER_API_KEY_AUTOMATION"
}

data "gitlab_project_variable" "opnsense_user_api_secret_automation" {
  project           = var.GITLAB_VARIABLES_PROJECT_ID
  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT

  key     = "OPNSENSE_USER_API_SECRET_AUTOMATION"
}

# Ref: https://registry.terraform.io/providers/browningluke/opnsense/latest/docs
provider "opnsense" {
  uri = "https://192.168.2.1"
  allow_insecure = true

  api_key = data.gitlab_project_variable.opnsense_user_api_key_automation.value
  api_secret = data.gitlab_project_variable.opnsense_user_api_secret_automation.value
}
