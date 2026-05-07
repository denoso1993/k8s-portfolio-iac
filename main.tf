# 1. ConfigMap real
resource "kubernetes_config_map" "portfolio_html" {
  metadata {
    name      = "nginx-html-config"
    namespace = "default"
  }
  data = {
    "index.html" = "<html><body><h1>Portfolio de Denis - SRE Lab</h1></body></html>"
  }
}

# 2. Deployment real
resource "kubernetes_deployment" "nginx_portfolio" {
  metadata {
    name = "nginx-deployment"
    namespace = "default"
    labels = {
      app = "nginx"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "html-volume"
            mount_path = "/usr/share/nginx/html"
          }
        }
        volume {
          name = "html-volume"
          config_map {
            name = "nginx-html-config"
          }
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}

# 3. HPA real
resource "kubernetes_horizontal_pod_autoscaler" "portfolio_hpa" {
  metadata {
    name = "nginx-hpa"
    namespace = "default"
  }
  spec {
    max_replicas = 5
    min_replicas = 1
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "nginx-deployment"
    }
    target_cpu_utilization_percentage = 50
  }
}
