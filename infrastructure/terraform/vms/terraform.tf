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
  }
}

# Ref: https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs
provider "gitlab" {
  token = var.GITLAB_ACCESS_TOKEN
}
