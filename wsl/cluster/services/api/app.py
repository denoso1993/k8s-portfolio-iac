import os, psycopg2
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

conn = psycopg2.connect(
    host=os.getenv("PG_HOST", "postgres-service"),
    user=os.getenv("PG_USER", "postgres"),
    password=os.getenv("PG_PASSWORD", "postgres"),
    dbname=os.getenv("PG_DB", "portfolio")
)

class API(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/api/health":
            cur = conn.cursor()
            cur.execute("SELECT 1")
            cur.close()
            self.send(200, {"status": "ok", "db": "connected"})
        else:
            self.send(404, {"error": "not found"})
    
    def send(self, code, data):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

HTTPServer(("0.0.0.0", 5000), API).serve_forever()
