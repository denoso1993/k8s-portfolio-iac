with open("/home/administrator/k8s-portfolio-iac/wsl/scripts/ensure-everything.sh", "rb") as f:
    data = f.read()
data = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
with open("/home/administrator/k8s-portfolio-iac/wsl/scripts/ensure-everything.sh", "wb") as f:
    f.write(data)
print("CRLF fixed")
