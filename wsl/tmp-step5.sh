#!/bin/bash
echo "=== STEP 5: Criar service NodePort ==="
kubectl expose deployment nginx-deployment -n default --port=80 --target-port=8080 --name=nginx-service --type=NodePort 2>&1
kubectl patch svc nginx-service -n default -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":31701}]}}' 2>&1
sleep 10
kubectl get endpoints nginx-service -n default 2>&1
kubectl get svc nginx-service -n default 2>&1
