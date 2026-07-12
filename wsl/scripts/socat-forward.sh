#!/bin/bash
# socat-forward.sh - Forward com deteccao automatica de IP do Kind
# Uso: socat-forward.sh <host_port> <node_port>
HOST_PORT="$1"
NODE_PORT="$2"

NODE_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane 2>/dev/null)
if [ -z "$NODE_IP" ]; then
  NODE_IP=$(kubectl get node lab-sre-denoso-control-plane -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
fi
if [ -z "$NODE_IP" ]; then
  echo "ERRO: Nao foi possivel detectar IP do Kind"
  exit 1
fi
exec /usr/bin/socat TCP-LISTEN:${HOST_PORT},fork,reuseaddr TCP:${NODE_IP}:${NODE_PORT}
