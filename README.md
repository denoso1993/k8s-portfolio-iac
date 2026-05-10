# Laboratório Kubernetes SRE

Projeto de SRE com Kubernetes e Terraform.

![Cluster](https://github.com/user-attachments/assets/f4d0563d-fbe8-44b8-88e7-74c77a47cb8d)

## Implementado

- Kubernetes v1.27.3
- HPA: 1-5 réplicas (70% CPU)
- Prometheus + Grafana + Loki
- WSL Bridge

![HPA](https://github.com/user-attachments/assets/8fce90cf-31c5-476b-8af1-37c57a47cb8d)

## Uso

```bash
git clone https://github.com/denoso1993/k8s-portfolio-iac.git
./setup.sh
terraform init && terraform apply
```

## Acessar

- Nginx: localhost:8080
- Grafana: localhost:3000

## Sobre

Denis Oliveira Ramos - linkedin.com/in/denis93

MIT License
