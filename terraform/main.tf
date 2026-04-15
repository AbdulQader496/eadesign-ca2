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
  metadata {
    name      = "mongodb-data"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "5Gi"
      }
    }
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
          image = "mongo:7.0"

          port {
            container_port = 27017
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
          image = "aq496/eadesign-ca2-backend:v1"

          env {
            name  = "DATABASE_URL"
            value = "mongodb://mongodb:27017"
          }

          env {
            name  = "DATABASE_NAME"
            value = "ead_ca2"
          }

          env {
            name  = "DATABASE_COLLECTION"
            value = "ead_2024"
          }

          port {
            container_port = 8080
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.mongodb]
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
          image = "aq496/eadesign-ca2-frontend:v2"

          port {
            container_port = 22137
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

    type = "ClusterIP"
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
