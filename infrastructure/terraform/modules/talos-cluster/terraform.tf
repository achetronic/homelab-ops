terraform {
  # Storing the .tfstate locally.
  # This is suitable only for testing purposes. Store it on S3 compatible backend for reliability
  #backend "local" {}
  backend "http" {}

  required_providers {
    talos = {
      source = "siderolabs/talos"
      version = "0.4.0"
    }

  }
}

provider "talos" {
  # Configuration options
}
