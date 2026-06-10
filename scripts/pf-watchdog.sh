#!/bin/bash
# pf-watchdog.sh - Mantem o port-forward do dev-server sempre ativo
# Roda em loop, reinicia imediatamente se cair
SVC="svc/dev-server-service"
NS="default"
LPORT="5500"
RPORT="5500"
LOG="/tmp/pf-dev.log"

while true; do
    kubectl port-forward --address 0.0.0.0 $SVC -n $NS $LPORT:$RPORT > $LOG 2>&1
    sleep 2
done
