#!/usr/bin/env python3
import socket
import subprocess
import sys
import json
import threading

HOST = '127.0.0.1'
PORT = 5555

def execute_command(cmd):
    # Se comando comeca com PF:, usa Popen (nao espera)
    if cmd.startswith('PF:'):
        cmd = cmd[3:]
        proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {'status': 'started', 'pid': proc.pid}
    # Senao, usa run() normal (comportamento original)
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120)
        return {'status': 'success', 'stdout': result.stdout, 'stderr': result.stderr, 'returncode': result.returncode}
    except subprocess.TimeoutExpired:
        return {'status': 'error', 'error': 'Command timeout'}
    except Exception as e:
        return {'status': 'error', 'error': str(e)}

def main():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, PORT))
        s.listen(1)
        print(f"[*] WSL Bridge Server listening on {HOST}:{PORT}")
        sys.stdout.flush()
        
        while True:
            conn, addr = s.accept()
            with conn:
                print(f"[+] Connected: {addr}")
                sys.stdout.flush()
                
                while True:
                    data = conn.recv(4096)
                    if not data:
                        break
                    
                    try:
                        request = json.loads(data.decode())
                        cmd = request.get('command', '')
                        
                        if cmd.lower() in ['exit', 'quit']:
                            conn.sendall(json.dumps({'status': 'exit'}).encode())
                            break
                        if cmd.lower() == 'ping':
                            conn.sendall(json.dumps({'status': 'pong'}).encode())
                            continue
                        
                        result = execute_command(cmd)
                        conn.sendall(json.dumps(result).encode())
                    except json.JSONDecodeError:
                        conn.sendall(json.dumps({'status': 'error', 'error': 'Invalid JSON'}).encode())
                    except Exception as e:
                        conn.sendall(json.dumps({'status': 'error', 'error': str(e)}).encode())
                
                print(f"[-] Disconnected: {addr}")
                sys.stdout.flush()

if __name__ == '__main__':
    main()
