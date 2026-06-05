# Metrics Server para HPA funcionar no Kind
# Recurso gratuito e nativo do Kubernetes

resource "kubernetes_service_account" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
    labels = {
      "k8s-app" = "metrics-server"
    }
  }
}

resource "kubernetes_cluster_role" "metrics_server" {
  metadata {
    name = "system:metrics-server"
    labels = {
      "k8s-app" = "metrics-server"
    }
  }

  rule {
    api_groups = ["", "metrics.k8s.io"]
    resources  = ["pods", "nodes", "nodes/stats", "namespaces", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "metrics_server" {
  metadata {
    name = "system:metrics-server"
    labels = {
      "k8s-app" = "metrics-server"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:metrics-server"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "metrics-server"
    namespace = "kube-system"
  }
}

resource "kubernetes_service" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
    labels = {
      "k8s-app" = "metrics-server"
    }
  }

  spec {
    port {
      name       = "https"
      port       = 443
      protocol   = "TCP"
      target_port = "https"
    }

    selector = {
      "k8s-app" = "metrics-server"
    }
  }
}

resource "kubernetes_deployment" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
    labels = {
      "k8s-app" = "metrics-server"
    }
  }

  spec {
    selector {
      match_labels = {
        "k8s-app" = "metrics-server"
      }
    }

    strategy {
      rolling_update {
        max_unavailable = 1
      }
    }

    template {
      metadata {
        labels = {
          "k8s-app" = "metrics-server"
        }
      }

      spec {
        service_account_name = "metrics-server"
        
        container {
          name              = "metrics-server"
          image             = "registry.k8s.io/metrics-server/metrics-server:v0.7.2"
          image_pull_policy = "IfNotPresent"

          args = [
            "--secure-port=10250",
            "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
            "--kubelet-use-node-status-port",
            "--metric-resolution=15s",
            "--kubelet-insecure-tls"
          ]

          port {
            name           = "https"
            container_port = 10250
            protocol       = "TCP"
          }

          liveness_probe {
            http_get {
              path   = "/livez"
              port   = "https"
              scheme = "HTTPS"
            }
            failure_threshold = 3
            period_seconds    = 10
          }

          readiness_probe {
            http_get {
              path   = "/readyz"
              port   = "https"
              scheme = "HTTPS"
            }
            initial_delay_seconds = 20
            failure_threshold = 3
            period_seconds    = 10
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "300Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
            run_as_non_root            = true
            run_as_user                = 1000
            capabilities {
              drop = ["ALL"]
            }
          }
        }

        priority_class_name = "system-cluster-critical"

        toleration {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }

        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      }
    }
  }

  depends_on = [kubernetes_service_account.metrics_server]
}

resource "kubernetes_api_service" "metrics_server" {
  metadata {
    name = "v1beta1.metrics.k8s.io"
    labels = {
      "k8s-app" = "metrics-server"
    }
  }

  spec {
    group                    = "metrics.k8s.io"
    group_priority_minimum   = 100
    insecure_skip_tls_verify = true
    service {
      name      = "metrics-server"
      namespace = "kube-system"
    }
    version               = "v1beta1"
    version_priority      = 100
  }

  depends_on = [kubernetes_service.metrics_server]
}
