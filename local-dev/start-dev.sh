#!/bin/bash
set -e
kubectl get configmap nginx-html-config -n default -o jsonpath='{.data.index\.html}' > ../tmp/flex-final.html 2>/dev/null
echo "HTML extraido, iniciando servidor..."
cd "$(dirname "$0")"
node dev-server.js
