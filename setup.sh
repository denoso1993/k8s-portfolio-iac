#!/bin/bash
echo "[*] Copiando servidor para o WSL..."
cp /mnt/c/wsl_bridge/wsl_bridge_server.py /home/$(whoami)/wsl_bridge_server.py
chmod +x /home/$(whoami)/wsl_bridge_server.py
echo "[*] Instalando dependências..."
python3 -c "import socket; import subprocess; import json; print('[*] Dependencias OK')"
echo "[*] Setup completo!"
echo "[*] Para iniciar o servidor: python3 ~/wsl_bridge_server.py"
