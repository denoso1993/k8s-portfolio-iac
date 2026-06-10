import os, sys, urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5500
HTML_FILE = "/tmp/flex-final.html"

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/k8s/"):
            try:
                url = "http://localhost:8001" + self.path[4:]
                req = urllib.request.Request(url)
                req.add_header("Host", "localhost")
                resp = urllib.request.urlopen(req, timeout=5)
                data = resp.read()
                self.send_response(resp.status)
                ct = resp.headers.get("Content-Type", "application/json")
                self.send_header("Content-Type", ct)
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(data)
            except Exception as e:
                self.send_response(502)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(str(e).encode())
            return
        if self.path in ["/", "/index.html"]:
            if os.path.exists(HTML_FILE):
                with open(HTML_FILE, "rb") as f:
                    html = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(html)
                return
        self.send_error(404)

print("Dev: http://0.0.0.0:" + str(PORT))
HTTPServer(("0.0.0.0", PORT), H).serve_forever()
