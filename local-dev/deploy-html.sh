#!/bin/bash
if [ ! -f ../tmp/flex-final.html ]; then echo "ERRO: HTML nao encontrado. Rode extract-html.sh primeiro"; exit 1; fi
kubectl create configmap nginx-html-config -n default --from-file=index.html=../tmp/flex-final.html --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment nginx-deployment -n default
kubectl rollout status deployment nginx-deployment -n default --timeout=60s
echo "Deploy OK! http://localhost:8083"
