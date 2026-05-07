# 1. ConfigMap para o conteúdo HTML
resource "kubernetes_config_map" "portfolio_html" {
  metadata {
    name      = "portfolio-content"
    namespace = "default"
  }

  data = {
    "index.html" = "<html><body><h1>Portfolio de Denis - SRE Lab</h1></body></html>"
  }
}

# 2. Deployment do Nginx
resource "kubernetes_deployment" "nginx_portfolio" {
  metadata {
    name = "nginx-portfolio"
    labels = {
      app = "portfolio"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "portfolio"
      }
    }

    template {
      metadata {
        labels = {
          app = "portfolio"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "nginx-container"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 3
          }

          volume_mount {
            name       = "html-volume"
            mount_path = "/usr/share/nginx/html"
          }
        }

        volume {
          name = "html-volume"
          config_map {
            name = "portfolio-content"
          }
        }
      }
    }
  }

  # Importante: Impede o Terraform de brigar com o HPA sobre o número de réplicas
  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}

# 3. HPA (Autoscaling)
resource "kubernetes_horizontal_pod_autoscaler" "portfolio_hpa" {
  metadata {
    name = "portfolio-hpa"
  }

  spec {
    max_replicas = 5
    min_replicas = 1

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "nginx-portfolio"
    }

    target_cpu_utilization_percentage = 50
  }
}
