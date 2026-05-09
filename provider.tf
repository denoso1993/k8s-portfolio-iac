terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "/home/denoso/.kube/config"
  config_context = "kind-lab-sre-denoso"
}

provider "helm" {
  kubernetes {
    config_path = "/home/denoso/.kube/config"
    config_context = "kind-lab-sre-denoso"
  }
}
