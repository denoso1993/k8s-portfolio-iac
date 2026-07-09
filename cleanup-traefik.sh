#!/bin/bash
kubectl patch svc traefik -n kube-system --type=json -p='[{"op": "replace", "path": "/metadata/finalizers", "value": []}]' 2>&1
kubectl delete svc traefik -n kube-system --grace-period=0 --force 2>&1
kubectl patch helmchart traefik -n kube-system --type=json -p='[{"op": "replace", "path": "/metadata/finalizers", "value": []}]' 2>&1
kubectl delete helmchart traefik -n kube-system --grace-period=0 --force 2>&1
echo 'DONE'
