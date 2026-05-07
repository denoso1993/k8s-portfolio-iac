#!/bin/bash

# 1. Reset do Cluster
echo "--- Deletando cluster antigo se existir... ---"
kind delete cluster --name lab-sre-denoso

echo "--- Criando cluster novo com porta 8081... ---"
kind create cluster --name lab-sre-denoso --config kind-config.yaml

# 2. Controladores Base (Ingress e Metrics Server)
echo "--- Instalando NGINX Ingress Controller... ---"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "--- Instalando Metrics Server... ---"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "--- Aplicando Patch TLS no Metrics Server (Requisito Kind)... ---"
kubectl patch -n kube-system deployment metrics-server --type=json \
  -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

echo "--- Aguardando Controladores estabilizarem... ---"
sleep 15
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

kubectl rollout status deployment/metrics-server -n kube-system --timeout=90s

# 3. Aplicacao dos Manifestos de Negocio
echo "--- Subindo ConfigMap e Dados... ---"
kubectl apply -f configmap-nginx.yaml

echo "--- Subindo Aplicacao e Rede... ---"
kubectl apply -f deployment-nginx.yaml
kubectl apply -f service-nginx.yaml

sleep 5
kubectl apply -f ingress-nginx.yaml

# 4. Autoescala
echo "--- Aplicando Regras de Autoescala (HPA)... ---"
kubectl apply -f hpa-nginx.yaml

# 5. Finalizacao
echo "--- Aguardando os Pods do Nginx ficarem Ready... ---"
kubectl rollout status deployment/nginx-deployment --timeout=90s

echo "-------------------------------------------------------"
echo "PROCESSO SRE CONCLUIDO COM SUCESSO!"
echo "Acesse: http://denoso.local:8081"
echo "Para ver o status da autoescala digite: kubectl get hpa"
echo "-------------------------------------------------------"
