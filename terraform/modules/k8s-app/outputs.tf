output "namespace" {
  description = "The Kubernetes namespace created for this environment."
  value       = kubernetes_namespace.this.metadata[0].name
}

output "ingress_host" {
  description = "The hostname configured on the nginx Ingress resource."
  value       = kubernetes_ingress_v1.app.spec[0].rule[0].host
}

output "service_name" {
  description = "The name of the Kubernetes Service resource."
  value       = kubernetes_service.app.metadata[0].name
}

output "deployment_name" {
  description = "The name of the Kubernetes Deployment resource."
  value       = kubernetes_deployment.app.metadata[0].name
}
