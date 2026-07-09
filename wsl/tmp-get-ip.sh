#!/bin/bash
docker network inspect kind -f '{{json .Containers}}' 2>&1 | python3 -c '
import sys, json
d = json.load(sys.stdin)
for k, v in d.items():
    print("{}: {}".format(k, v["IPv4Address"]))
'
echo "---"
docker network inspect kind 2>&1 | python3 -c '
import sys, json
d = json.load(sys.stdin)
for k, v in d[0].get("Containers", {}).items():
    print("{}: name={}, ip={}".format(k, v.get("Name","?"), v.get("IPv4Address","?")))
'
echo "---"
# Try to get IP from the container itself
docker exec lab-sre-denoso-control-plane ip addr show eth0 2>/dev/null | grep "inet " || echo "Cannot exec in container"
echo "---"
# Try kubectl get nodes -o wide
kubectl get nodes -o wide 2>&1
