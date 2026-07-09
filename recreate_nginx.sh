#!/bin/bash
set -e
kubectl delete cm nginx-full-config -n default --ignore-not-found 2>&1
kubectl delete deployment nginx-deployment -n default --ignore-not-found 2>&1
kubectl delete svc nginx-service -n default --ignore-not-found 2>&1
sleep 5
kubectl create cm nginx-full-config -n default --from-file=nginx.conf=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/nginx-secure.conf 2>&1
kubectl create cm nginx-html-config -n default --from-file=index.html=/home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/html/prod-index.html 2>&1
kubectl apply -f /home/administrator/k8s-portfolio-iac/wsl/cluster/services/portfolio/deployment.yaml 2>&1
sleep 15
kubectl expose deployment nginx-deployment -n default --port=80 --target-port=8080 --name=nginx-service --type=NodePort 2>&1
kubectl patch svc nginx-service -n default -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":31701}]}}' 2>&1
sleep 20
echo 'RECREATE_DONE'
