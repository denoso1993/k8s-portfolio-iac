#!/bin/bash
# WSL Bridge Helper
cmd=nodes
case  in
  pods) kubectl get pods -A ;;
  nodes) kubectl get nodes ;;
  hpa) kubectl get hpa -A ;;
  status) kubectl get all -A ;;
  logs) kubectl logs -f deploy/nginx-deployment ;;
  top) kubectl top nodes ;;
  *) echo Commands:
