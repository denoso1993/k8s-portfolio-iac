resource "kubernetes_config_map" "portfolio_html" {
  metadata {
    name      = "nginx-html-config"
    namespace = "default"
  }
  data = {
    "index.html" = "<html><body><h1>Portfolio de Denis - SRE Lab (Porta 8081 Corrigida)</h1></body></html>"
  }
}

resource "kubernetes_deployment" "nginx_portfolio" {
  metadata {
    name      = "nginx-deployment"
    namespace = "default"
    labels    = { app = "nginx" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "nginx" } }
    template {
      metadata { labels = { app = "nginx" } }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port { container_port = 80 }
          volume_mount {
            name       = "html-volume"
            mount_path = "/usr/share/nginx/html"
          }
        }
        volume {
          name = "html-volume"
          config_map { name = "nginx-html-config" }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx_service" {
  metadata {
    name      = "nginx-service"
    namespace = "default"
  }
  spec {
    selector = { app = "nginx" }
    type     = "NodePort"
    port {
      port        = 80
      target_port = 80
      node_port   = 30000
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  set {
    name  = "server.persistentVolume.enabled"
    value = "false"
  }
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  set {
    name  = "persistence.enabled"
    value = "false"
  }
  set {
    name  = "adminPassword"
    value = "admin"
  }
  set {
    name  = "service.type"
    value = "NodePort"
  }
  set {
    name  = "service.nodePort"
    value = "30001"
  }
}
