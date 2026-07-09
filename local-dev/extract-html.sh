#!/bin/bash
kubectl get configmap nginx-html-config -n default -o jsonpath='{.data.index\.html}' > ../tmp/flex-final.html 2>/dev/null
if [ -s ../tmp/flex-final.html ]; then
  echo "HTML extraido: $(wc -c < ../tmp/flex-final.html) bytes"
  echo "Rode: cd local-dev && node dev-server.js"
else
  echo "ERRO: Cluster nao disponivel"
  exit 1
fi
