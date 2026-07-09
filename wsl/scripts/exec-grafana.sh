#!/bin/bash
set -e

echo "=== STEP 1: Ver Grafana ==="
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o wide 2>&1
kubectl get svc grafana -n monitoring -o wide 2>&1

echo ""
echo "=== STEP 2: Verificar tipo do Grafana ==="
TYPE=$(kubectl get svc grafana -n monitoring -o jsonpath="{.spec.type}" 2>&1)
echo "Tipo atual: $TYPE"
echo ""
echo "=== Aplicando patch (sera no-op se ja for NodePort) ==="
kubectl patch svc grafana -n monitoring -p '{"spec":{"type":"NodePort"}}' 2>&1
echo ""
sleep 5
echo ""
NP=$(kubectl get svc grafana -n monitoring -o jsonpath="{.spec.ports[0].nodePort}" 2>/dev/null)
echo "Grafana NodePort: $NP"

echo ""
echo "=== STEP 3: Verificar socat-forward.sh ==="
ls -la /home/administrator/k8s-portfolio-iac/wsl/scripts/socat-forward.sh 2>&1
echo ""
head -10 /home/administrator/k8s-portfolio-iac/wsl/scripts/socat-forward.sh 2>&1

echo ""
echo "=== STEP 4: Criar servico socat-3000 ==="
K8S_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab-sre-denoso-control-plane 2>&1)
echo "Kubernetes control-plane IP: $K8S_IP"
echo ""
cat > /tmp/socat-3000.service << SERVICEEOF
[Unit]
Description=Socat forward 3000 -> Grafana NodePort
After=docker.service
Requires=docker.service
[Service]
Type=exec
ExecStart=/usr/bin/socat TCP-LISTEN:3000,fork,reuseaddr TCP:${K8S_IP}:${NP}
Restart=always
RestartSec=3
User=root
[Install]
WantedBy=multi-user.target
SERVICEEOF

sudo tee /etc/systemd/system/socat-3000.service > /dev/null < /tmp/socat-3000.service
sudo systemctl daemon-reload && sudo systemctl enable socat-3000.service && sudo systemctl restart socat-3000.service 2>&1
echo ""
sleep 3
echo ""
echo "Teste 3000: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://localhost:3000/ 2>&1)"
echo "GRAFANA_TUNNEL: $(curl -s -o /dev/null -w '%{http_code}' -H 'Host: grafana.denisdeoliveira.com.br' --connect-timeout 5 http://localhost:3000/ 2>&1)"

echo ""
echo "=== STEP 5: Testar tudo ==="
echo "SITE: $(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 15 https://denisdeoliveira.com.br/ 2>&1)"
echo "GRAFANA: $(curl -s -o /dev/null -w '%{http_code}' -H 'Host: grafana.denisdeoliveira.com.br' --connect-timeout 5 http://localhost:3000/ 2>&1)"
