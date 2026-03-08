variable "image" {
  description = "Full Docker image reference including tag. Overridden by CI via -var flag."
  type        = string
}

variable "ingress_base_domain" {
  description = "Base domain used to construct the ingress hostname (e.g. example.com → helloworld-dev.example.com)."
  type        = string
}
