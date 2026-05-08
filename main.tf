resource "kubernetes_config_map" "portfolio_html" {
  metadata {
    name      = "nginx-html-config"
    namespace = "default"
  }
  data = {
    "index.html" = <<-EOT
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Denis Oliveira Ramos - Portfolio</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #dbeafe; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .card { background-color: white; border-radius: 12px; padding: 40px; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1); max-width: 500px; width: 100%; text-align: center; }
        h1 { color: #1f2937; font-size: 24px; margin-bottom: 5px; }
        .subtitle { color: #0284c7; font-size: 12px; font-weight: bold; letter-spacing: 1px; margin-bottom: 30px; text-transform: uppercase; }
        .section-title { text-align: left; color: #6b7280; font-size: 12px; font-weight: bold; border-left: 3px solid #0284c7; padding-left: 10px; margin-bottom: 15px; text-transform: uppercase; }
        .btn-group { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 30px; }
        .btn { display: inline-block; padding: 10px 15px; border-radius: 6px; text-decoration: none; font-size: 14px; font-weight: 500; transition: all 0.2s; cursor: pointer; }
        .btn-primary { background-color: #0284c7; color: white; border: 1px solid #0284c7; }
        .btn-primary:hover { background-color: #0369a1; }
        .btn-outline { background-color: white; color: #4b5563; border: 1px solid #d1d5db; }
        .btn-outline:hover { background-color: #f3f4f6; }
        .footer-info { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; text-align: left; margin-top: 20px; border-top: 1px solid #e5e7eb; padding-top: 20px; font-size: 10px; color: #6b7280; }
        .footer-item::before { content: '●'; color: #10b981; margin-right: 5px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Denis Oliveira Ramos</h1>
        <div class="subtitle">SENIOR CLOUD ANALYST | SRE & INFRASTRUCTURE</div>
        <div class="section-title">CURRÍCULOS (RESUME)</div>
        <div class="btn-group">
            <a href="https://drive.google.com/open?id=1AtSEc-qtGJzdPCroJEleJrU8U6OsDz2w" target="_blank" class="btn btn-primary">Português (PT-BR)</a>
            <a href="https://drive.google.com/open?id=1nLev2K3tUuM09_PxtIShWjTdp4YSb9Tm" target="_blank" class="btn btn-primary">English (EN-US)</a>
        </div>
        <div class="section-title">EVIDÊNCIAS E CERTIFICAÇÕES</div>
        <div class="btn-group">
            <a href="https://drive.google.com/drive/folders/1k_4mO-j4WEoaIGngR9cGLX1WpVSKC-AD" target="_blank" class="btn btn-outline">Pasta de Certificados</a>
            <a href="https://drive.google.com/drive/folders/1tIIPUa3S2Tq-8M-J570m66ldim4fRnAj" target="_blank" class="btn btn-outline">Drive Profissional</a>
            <a href="https://linkedin.com/in/denis93" target="_blank" class="btn btn-outline">LinkedIn</a>
            <a href="mailto:denis_oliveira@rocketmail.com" class="btn btn-outline">E-mail</a>
        </div>
        <div class="footer-info">
            <div class="footer-item">Cloud Cluster: Kind</div>
            <div class="footer-item">Ingress: Nginx</div>
            <div class="footer-item">Region: Local (Barueri)</div>
            <div class="footer-item">Port: 8081</div>
        </div>
    </div>
</body>
</html>
EOT
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
          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "200m", memory = "256Mi" }
          }
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

  values = [
    yamlencode({
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [{
            name      = "Prometheus"
            type      = "prometheus"
            url       = "http://prometheus-server.monitoring.svc.cluster.local"
            access    = "proxy"
            isDefault = true
          }]
        }
      }
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [{
            name            = "default"
            orgId           = 1
            folder          = ""
            type            = "file"
            disableDeletion = false
            editable        = true
            options         = { path = "/var/lib/grafana/dashboards/default" }
          }]
        }
      }
      dashboards = {
        default = {
          kubernetes-pods = {
            gnetId     = 15760
            revision   = 28
            datasource = "Prometheus"
          }
        }
      }
    })
  ]
}
