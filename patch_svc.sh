kubectl patch svc nginx-service -n default -p '{"spec":{"ports":[{"port":80,"targetPort":8080,"nodePort":31701}]}}' 2>&1
