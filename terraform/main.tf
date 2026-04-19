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

# MongoDB Backup Persistent Volume Claim
resource "kubernetes_persistent_volume_claim_v1" "mongodb_backup" {
  wait_until_bound = false

  metadata {
    name      = "mongodb-backup"
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

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    revision_history_limit = 5

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

          security_context {
            run_as_non_root            = false
            allow_privilege_escalation = false
          }

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

resource "kubernetes_cron_job_v1" "mongodb_backup" {
  metadata {
    name      = "mongodb-backup"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    schedule                      = "0 2 * * *"
    failed_jobs_history_limit     = 3
    successful_jobs_history_limit = 3

    job_template {
      metadata {}

      spec {
        template {
          metadata {}

          spec {
            container {
              name  = "mongodb-backup"
              image = var.mongodb_image
              command = [
                "/bin/sh",
                "-c",
                "backup_dir=/backup/$(date +%Y%m%d-%H%M%S) && mkdir -p \"$backup_dir\" && mongodump --host mongodb --out \"$backup_dir\" && find /backup -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + && echo 'Backup completed successfully'",
              ]

              volume_mount {
                name       = "backup-storage"
                mount_path = "/backup"
              }
            }

            volume {
              name = "backup-storage"

              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim_v1.mongodb_backup.metadata[0].name
              }
            }

            restart_policy = "OnFailure"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service.mongodb,
    kubernetes_persistent_volume_claim_v1.mongodb_backup,
  ]
}

resource "kubernetes_network_policy" "mongodb_policy" {
  metadata {
    name      = "mongodb-allow-backend-only"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "mongodb"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "backend"
          }
        }
      }

      ports {
        port     = "27017"
        protocol = "TCP"
      }
    }
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

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    revision_history_limit = 5

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

        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8080"
          "prometheus.io/path"   = "/actuator/prometheus"
        }
      }

      spec {
        volume {
          name = "backend-tmp"

          empty_dir {}
        }

        container {
          name  = "backend"
          image = var.backend_image

          security_context {
            run_as_non_root            = true
            run_as_user                = 1000
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
          }

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

          volume_mount {
            name       = "backend-tmp"
            mount_path = "/tmp"
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

    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "8080"
      "prometheus.io/path"   = "/actuator/prometheus"
    }
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

resource "kubernetes_network_policy" "backend_policy" {
  metadata {
    name      = "backend-allow-frontend-monitoring-and-ingress"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "backend"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "frontend"
          }
        }
      }

      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "ingress-nginx"
          }
        }
      }

      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "prometheus"
          }
        }
      }

      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy" "backend_egress_policy" {
  metadata {
    name      = "backend-egress-db-and-dns"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "backend"
      }
    }

    policy_types = ["Egress"]

    egress {
      to {
        pod_selector {
          match_labels = {
            app = "mongodb"
          }
        }
      }

      ports {
        port     = "27017"
        protocol = "TCP"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }

        pod_selector {
          match_labels = {
            "k8s-app" = "kube-dns"
          }
        }
      }

      ports {
        port     = "53"
        protocol = "UDP"
      }

      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "backend" {
  metadata {
    name      = "backend-hpa"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    min_replicas = var.backend_hpa_min_replicas
    max_replicas = var.backend_hpa_max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.backend.metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = var.backend_hpa_cpu_target
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.backend]
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

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    revision_history_limit = 5

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

        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "22137"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        volume {
          name = "frontend-tmp"

          empty_dir {}
        }

        container {
          name  = "frontend"
          image = var.frontend_image

          security_context {
            run_as_non_root            = true
            run_as_user                = 1000
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
          }

          port {
            container_port = 22137
          }

          volume_mount {
            name       = "frontend-tmp"
            mount_path = "/tmp"
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

    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "22137"
      "prometheus.io/path"   = "/metrics"
    }
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

resource "kubernetes_network_policy" "frontend_policy" {
  metadata {
    name      = "frontend-allow-ingress-and-monitoring"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "frontend"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "ingress-nginx"
          }
        }
      }

      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "prometheus"
          }
        }
      }

      ports {
        port     = "22137"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_network_policy" "frontend_egress_policy" {
  metadata {
    name      = "frontend-egress-backend-and-dns"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "frontend"
      }
    }

    policy_types = ["Egress"]

    egress {
      to {
        pod_selector {
          match_labels = {
            app = "backend"
          }
        }
      }

      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }

        pod_selector {
          match_labels = {
            "k8s-app" = "kube-dns"
          }
        }
      }

      ports {
        port     = "53"
        protocol = "UDP"
      }

      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "frontend" {
  metadata {
    name      = "frontend-hpa"
    namespace = kubernetes_namespace_v1.ca2.metadata[0].name
  }

  spec {
    min_replicas = var.frontend_hpa_min_replicas
    max_replicas = var.frontend_hpa_max_replicas

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.frontend.metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"

        target {
          type                = "Utilization"
          average_utilization = var.frontend_hpa_cpu_target
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.frontend]
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
