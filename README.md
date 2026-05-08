# Kubernetes Lab - Infrastructure as Code (IaC)

Este projeto demonstra a migração de um ambiente Kubernetes local (**Kind**) para gestão via **Terraform**, aplicando princípios de SRE e automação.

## 🚀 Tecnologias Utilizadas
*   **Kubernetes (Kind):** Orquestração de containers local.
*   **Terraform:** Provisionamento e gestão da infraestrutura.
*   **Nginx:** Servidor web stateless para o portfólio.
*   **HPA (Horizontal Pod Autoscaler):** Escalabilidade baseada em consumo de CPU.

## 🏗️ Arquitetura do Projeto
O cluster gerencia um deploy de Nginx que consome o conteúdo estático via **ConfigMap**. O escalonamento é automatizado para variar entre 1 e 5 réplicas conforme a demanda.

## 🛠️ Como Executar
1. Certifique-se de ter o **Kind** e o **Terraform** instalados.
2. Inicie o cluster local: `kind create cluster --name lab-sre-denoso`
3. Inicialize o Terraform: `terraform init`
4. Aplique a configuração: `terraform apply`

---
*Projeto mantido por [Denis De Oliveira Ramos](https://github.com/denoso1993)*


<img width="1587" height="931" alt="SRE" src="https://github.com/user-attachments/assets/d392910c-b4f2-4ab7-af3d-3fd945520461" />

<img width="1587" height="931" alt="SRE" src="https://github.com/user-attachments/assets/6d7049b0-acaf-4b84-95ea-72bcbac46435" />
