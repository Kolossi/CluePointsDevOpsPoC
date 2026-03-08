variable "app_name" {
  description = "Name used for all Kubernetes resource labels and names."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to create and deploy into (e.g. cluepoints-dev)."
  type        = string
}

variable "image" {
  description = "Full Docker image reference including tag (e.g. docker.io/acme/helloworld-demo-python:1.0.42)."
  type        = string
}

variable "replicas" {
  description = "Number of pod replicas for the Deployment."
  type        = number
  default     = 1
}

variable "ingress_host" {
  description = "Fully-qualified hostname for the nginx Ingress rule (e.g. helloworld-dev.example.com)."
  type        = string
}

variable "log_level" {
  description = "Value for the LOG_LEVEL environment variable injected into the app container."
  type        = string
  default     = "INFO"
}

variable "extra_env" {
  description = "Additional environment variables to inject into the app container."
  type        = map(string)
  default     = {}
}

variable "container_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 8080
}
