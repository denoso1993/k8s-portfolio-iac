# Kubernetes SRE Lab - Infrastructure as Code

## Overview

This repository contains the infrastructure-as-code definitions for a Kubernetes cluster running on Kind (Kubernetes in Docker). The project demonstrates practical Site Reliability Engineering (SRE) practices including GitOps workflows, observability, security hardening, and policy-as-code enforcement.

The cluster runs a personal portfolio website (nginx-based) and a PostgreSQL database, both managed through ArgoCD with automatic sync from this repository.

## Repository Structure

```
k8s/                          # Kubernetes manifests (ArgoCD source path)
  infrastructure/             # Cluster-level components
  monitoring/                 # Alerting rules
  security/                   # Network policies, quotas, PSS
  services/                   # Application workloads
  platform/                   # Kyverno policies
bootstrap/                    # ArgoCD Application manifest (outside k8s/ path)
scripts/                      # Cluster bootstrap and health checks
archive/                      # Historical reports and legacy Terraform
assets/                       # Architecture diagrams
kind-config.yaml              # Kind cluster definition
``````
k8s/                          # Kubernetes manifests (ArgoCD source path)
  infrastructure/             # Cluster-level components
bootstrap/                    # ArgoCD Application definition (outside k8s/ to avoid circular reference)
  platform/                   # Kyverno policies
  monitoring/                 # Alerting rules
  security/                   # Network policies, quotas, PSS
  services/                   # Application workloads
scripts/                      # Cluster bootstrap and health checks
archive/                      # Historical reports and legacy Terraform
assets/                       # Architecture diagrams
kind-config.yaml              # Kind cluster definition
```

## Architecture

The environment consists of a single-node Kind cluster running Kubernetes 1.27.3 on WSL2 (Ubuntu). All infrastructure is defined declaratively and synchronized via ArgoCD.

### Components

| Component | Purpose |
|-----------|---------|
| Kind | Local Kubernetes cluster (single control-plane node) |
| nginx | Portfolio web server (nginxinc/nginx-unprivileged, non-root) |
| PostgreSQL 15 | Relational database (StatefulSet with persistent volume) |
| ArgoCD | GitOps sync - automatic reconciliation with this repository |
| cert-manager | TLS certificate lifecycle management |
| Kyverno | Policy-as-code engine |
| Goldilocks / VPA | Resource optimization recommendations |
| Prometheus / Grafana | Metrics collection and visualization |
| Loki / Promtail | Log aggregation |
| metrics-server | Resource metrics for HPA autoscaling |
| nginx-ingress-controller | HTTP/HTTPS ingress routing |

### Cluster Specifications

- Kubernetes version: 1.27.3
- Node count: 1 (control-plane)
- Resource capacity: 16 vCPU, 16 GB memory
- Container runtime: containerd 1.7.1
- Network: Kind default (CNI: kindnet)

## Security

### Pod Security Standards

Each namespace enforces a Pod Security Standard level appropriate to its workloads:

- restricted: default, argocd, cert-manager, monitoring, ingress-nginx
- baseline: kube-public, kube-node-lease, local-path-storage
- privileged: kube-system

### Resource Controls

The default namespace has the following resource limits:

- Max 20 pods
- CPU request limit: 4 cores (8 cores burst)
- Memory request limit: 4 GB (8 GB burst)
- Default container: 100m CPU / 128 MB memory request

### Network Policies

- Default deny-all ingress for all namespaces
- Explicit allow rules for nginx (port 8080) and PostgreSQL (port 5432)
- DNS access permitted to kube-system

### Policy Engine

Kyverno enforces two cluster policies:
- Disallow privileged containers (audit mode)
- Require resource requests and limits (audit mode)

## Getting Started

### Prerequisites

- WSL2 with Ubuntu 20.04 or later
- Docker Desktop with WSL2 integration
- Kind (Kubernetes in Docker)
- kubectl
- Helm (v3+)

### Creating the Cluster

```bash
git clone https://github.com/denoso1993/k8s-portfolio-iac.git
cd k8s-portfolio-iac
kind create cluster --name lab-sre-denoso --config kind-config.yaml
kubectl apply -f k8s/infrastructure/
kubectl apply -f k8s/security/
kubectl apply -f k8s/platform/argocd/
kubectl apply -f k8s/services/portfolio/
kubectl apply -f k8s/services/postgres/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm install prometheus prometheus-community/prometheus ---namespace monitoring --create-namespace
helm install grafana grafana/grafana ---namespace monitoring
helm install loki-stack grafana/loki-stack ---namespace monitoring
```

### Accessing Services

| Service | Internal Access | External Access |
|---------|----------------|-----------------|
| Portfolio | ClusterIP:80 | kubectl port-forward svc/nginx-service 8083:80 |
| Grafana | monitoring:80 | kubectl port-forward svc/grafana -n monitoring 3090:80 |
| Prometheus | monitoring:9090 | kubectl port-forward svc/prometheus-server -n monitoring 9090:9090 |
| ArgoCD | argocd:443 | kubectl port-forward svc/argocd-server -n argocd 8080:443 |

Default Grafana credentials: admin / admin

## Operational Notes

### Known Limitations

- Terraform: The Terraform provider registry (registry.terraform.io) is unreachable from this WSL environment due to DNS resolution constraints. All infrastructure is provisioned via kubectl and Helm directly.
- Port 8081: Already in use by another process on the host. The portfolio is served on port 8083 (forwarded from 8082 via Windows port proxy).
- WSL networking: WSL2 uses a virtualized network adapter. Services are exposed via kubectl port-forward with --address 0.0.0.0 and Windows netsh port proxies.

### Maintenance

```bash
kubectl get pods -A
kubectl get application -n argocd -o wide
kubectl top nodes
kubectl top pods -A
```

## Author

Denis Oliveira Ramos
Senior Cloud Analyst | SRE & Infrastructure
Barueri, SP - Brazil

- LinkedIn: linkedin.com/in/denis93
- Email: denoso1993@gmail.com

### License

This project is shared as a portfolio reference. Feel free to adapt and use as a starting point for your own infrastructure projects.

---

Infrastructure as Code portfolio project - Denis Oliveira Ramos