Kubernetes SRE Lab - Infrastructure as Code (IaC)
Este repositório contém a orquestração completa de um ecossistema Kubernetes resiliente e observável, provisionado de forma 100% declarativa. O projeto evoluiu de um deploy simples para uma arquitetura que simula desafios reais de produção, como persistência de estado e centralização de logs.

🏗️ Arquitetura e Engenharia
A solução é composta pelos seguintes pilares de confiabilidade:

Provisionamento Declarativo: Toda a infraestrutura, desde o cluster local (Kind) até os recursos internos, é gerenciada via Terraform e Helm, eliminando configurações manuais.

Resiliência de Dados: Diferente de arquiteturas stateless simples, este lab utiliza StatefulSets e PersistentVolumeClaims (PVC) para o banco de dados PostgreSQL, garantindo que os dados sobrevivam ao ciclo de vida dos Pods.

Serviço Web: O portfólio técnico é servido via Nginx, com o conteúdo desacoplado da imagem através de ConfigMaps.

Escalabilidade: Implementação de HPA (Horizontal Pod Autoscaler), permitindo que a aplicação responda dinamicamente a picos de tráfego (1 a 5 réplicas).

📊 Observabilidade (Full-Stack)
Não há SRE sem dados. O cluster integra uma stack completa de telemetria:

Métricas: Prometheus extraindo dados de performance em tempo real.

Logs: Stack Loki & Promtail para agregação centralizada de logs, permitindo auditoria e troubleshooting sem acesso direto ao terminal.

Visualização: Dashboards dinâmicos no Grafana, provisionados automaticamente via código (Data Sources & Dashboards-as-Code).

🚀 Tecnologias Utilizadas
Orquestração: Kubernetes (Kind)

IaC: Terraform & Helm

Web Server: Nginx

Database: PostgreSQL 15 (Alpine)

Observability: Prometheus, Grafana, Loki & Promtail

🛠️ Próximos Passos (Roadmap)
[ ] Secret Management: Migração de segredos para External Secrets / Vault.

[ ] Ingress Control: Implementação de NGINX Ingress com suporte a TLS.

[ ] Disaster Recovery: Automação de backups do PostgreSQL para Cloud Storage.

<img width="1587" height="931" alt="SRE" src="https://github.com/user-attachments/assets/f4d0563d-fbe8-44b8-88e7-74c77a47cb8d" />

<img width="1661" height="950" alt="SRE2" src="https://github.com/user-attachments/assets/8fce90cf-31c5-476b-8af1-37c5c7fc7864" />


Mantido por Denis Oliveira Ramos
