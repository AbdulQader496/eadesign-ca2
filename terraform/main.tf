provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Namespace
resource "kubernetes_namespace_v1" "ca2" {
  metadata {
    name = "eadesign-ca2"
  }
}

# MongoDB Persistent Volume Claim
resource "kubernetes_persistent_volume_claim_v1" "mongodb_data" {
  wait_until_bound = false

  metadata {
    name      = "mongodb-data"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "managed-csi"

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

# Backend Secret
resource "kubernetes_secret_v1" "backend_env" {
  metadata {
    name      = "backend-env"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  type = "Opaque"

  data = {
    DATABASE_URL        = "mongodb://mongodb:27017"
    DATABASE_NAME       = "ead_ca2"
    DATABASE_COLLECTION = "ead_2024"
  }
}

# MongoDB Deployment
resource "kubernetes_deployment" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
    labels = {
      app = "mongodb"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongodb"
        }
      }

      spec {
        container {
          name  = "mongodb"
          image = var.mongodb_image

          port {
            container_port = 27017
          }

          liveness_probe {
            tcp_socket {
              port = 27017
            }

            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            tcp_socket {
              port = 27017
            }

            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "mongodb-data"
            mount_path = "/data/db"
          }
        }

        volume {
          name = "mongodb-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mongodb_data.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_persistent_volume_claim_v1.mongodb_data]
}

# MongoDB Service
resource "kubernetes_service" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    selector = {
      app = "mongodb"
    }

    port {
      port        = 27017
      target_port = 27017
    }

    type = "ClusterIP"
  }
}

# Backend Deployment
resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
    labels = {
      app = "backend"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          name  = "backend"
          image = var.backend_image

          env {
            name = "DATABASE_URL"

            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.backend_env.metadata[0].name
                key  = "DATABASE_URL"
              }
            }
          }

          env {
            name = "DATABASE_NAME"

            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.backend_env.metadata[0].name
                key  = "DATABASE_NAME"
              }
            }
          }

          env {
            name = "DATABASE_COLLECTION"

            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.backend_env.metadata[0].name
                key  = "DATABASE_COLLECTION"
              }
            }
          }

          port {
            container_port = 8080
          }

          startup_probe {
            http_get {
              path = "/health"
              port = 8080
            }

            failure_threshold = 30
            period_seconds    = 10
            timeout_seconds   = 5
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }

            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }

            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.mongodb, kubernetes_secret_v1.backend_env]
}

# Backend Service
resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    selector = {
      app = "backend"
    }

    port {
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

# Frontend Deployment
resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
    labels = {
      app = "frontend"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          name  = "frontend"
          image = var.frontend_image

          port {
            container_port = 22137
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 22137
            }

            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 22137
            }

            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "300m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

# Frontend Service
resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    selector = {
      app = "frontend"
    }

    port {
      port        = 80
      target_port = 22137
    }

    type = "LoadBalancer"
  }
}

# Ingress
resource "kubernetes_ingress_v1" "ca2_ingress" {
  metadata {
    name      = "ca2-ingress"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name

    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      http {
        path {
          path      = "/api(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = kubernetes_service.backend.metadata[0].name
              port {
                number = 8080
              }
            }
          }
        }

        path {
          path      = "/(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = kubernetes_service.frontend.metadata[0].name
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
