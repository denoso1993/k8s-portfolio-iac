# Arquitetura do Portfolio

## Fluxo de Trafego (navegador -> site)

\`\`\`mermaid
graph TD
    U[Usuario] -->|HTTPS| CT[Cloudflare Tunnel]
    CT -->|localhost:8083| PF1[port-forward nginx:8083]
    PF1 --> NP[nginx pod :8080]
    
    NP -->|/k8s/pods| KP[kubectl proxy :8001]
    KP --> KA[K8s API]
    
    NP -->|iframe| GF[Grafana :3000]
    GF -->|datasource| PS[Prometheus]
    PS -->|scrape| KS[Kube State Metrics]
    
    NP -->|arquivos estaticos| HTML[index.html]
    
    subgraph WSL2
        PF1
        KP
        KA
    end
    
    subgraph Kind Cluster
        NP
        GF
        PS
        KS
        PG[(PostgreSQL)]
    end
    
    subgraph Windows
        CT
        SM[Scheduled Tasks]
        SM -->|startup| DC[Daemon Controle]
        DC -->|monitor| PF1
        DC -->|monitor| KP
    end
\`\`\`

## Componentes

| Componente | Funcao | Porta |
|-----------|--------|-------|
| nginx | Servidor web (Win95 theme) | 8083 (host) / 8080 (pod) |
| kubectl proxy | Proxy para K8s API (pods/nodes) | 8001 |
| Grafana | Dashboard de metricas | 3000 (localhost) |
| Prometheus | Coleta de metricas | interna |
| PostgreSQL | Banco de dados | interna |
| Cloudflare Tunnel | Exposicao HTTPS publica | 443/80 |
| Daemon | Monitor cont?nuo (WSL) | - |
