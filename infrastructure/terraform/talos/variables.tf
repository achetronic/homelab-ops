# Token to access Gitlab.
# This is used for storing TFstate and get credentials to access hypervisor machines
variable "GITLAB_ACCESS_TOKEN" {
  type        = string
  description = "Token to access Gitlab"
  default     = "api-token-placeholder"
}

# TODO
variable "GITLAB_VARIABLES_PROJECT_ID" {
  type        = string
  description = "Project ID on Gitlab to get the variables"
  default     = "49083217"
}

# TODO
variable "GITLAB_VARIABLES_ENVIRONMENT" {
  type        = string
  description = "Environment on Gitlab to get the variables"
  default     = "terraform"
}
