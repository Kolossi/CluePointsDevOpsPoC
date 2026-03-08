terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = var.app_name
    }
  }
}

# ---------------------------------------------------------------------------
# ConfigMap — application environment variables
# ---------------------------------------------------------------------------
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "${var.app_name}-config"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.common_labels
  }

  data = merge(
    {
      LOG_LEVEL = var.log_level
    },
    var.extra_env
  )
}

# ---------------------------------------------------------------------------
# Deployment
# ---------------------------------------------------------------------------
resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.common_labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = local.selector_labels
    }

    template {
      metadata {
        labels = local.common_labels
      }

      spec {
        container {
          name  = var.app_name
          image = var.image

          port {
            container_port = var.container_port
            protocol       = "TCP"
          }

          # Inject all ConfigMap keys as environment variables
          env_from {
            config_map_ref {
              name = kubernetes_config_map.app_config.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Service — ClusterIP; nginx ingress routes traffic here
# ---------------------------------------------------------------------------
resource "kubernetes_service" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.common_labels
  }

  spec {
    selector = local.selector_labels
    type     = "ClusterIP"

    port {
      name        = "http"
      port        = 80
      target_port = var.container_port
      protocol    = "TCP"
    }
  }
}

# ---------------------------------------------------------------------------
# Ingress — nginx ingress controller; host-based routing
# ---------------------------------------------------------------------------
resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.common_labels
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.ingress_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  selector_labels = {
    "app.kubernetes.io/name" = var.app_name
  }

  common_labels = merge(local.selector_labels, {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = var.app_name
  })
}
