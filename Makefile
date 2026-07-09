.PHONY: help cluster deploy clean test lint security setup-windows
help:
	@echo "=== Makefile ==="
	@echo "make cluster     - Start cluster"
	@echo "make deploy      - Deploy manifests"
	@echo "make clean       - Delete cluster"
	@echo "make test        - Check endpoints"
	@echo "make lint        - Shellcheck + YAML"
	@echo "make security    - Run audit"
	@echo "make setup-win   - Windows netsh"
cluster:
	bash wsl/scripts/bootstrap-wsl.sh
deploy:
	kubectl apply -f wsl/cluster/services/portfolio/
	kubectl apply -f wsl/cluster/monitoring/
clean:
	kind delete cluster --name lab-sre-denoso
test:
	@for port in 8083 5500 5599 5598 3000; do 		code=$$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$$port/); 		echo "localhost:$$port -> $$code"; 	done
lint:
	-find wsl/scripts -name "*.sh" -exec shellcheck {} +
setup-windows:
	powershell.exe -File windows/bootstrap-windows.ps1
