import os, sys, time, threading
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5500
HTML_FILE = "/tmp/flex-final.html"
last_mtime = os.path.getmtime(HTML_FILE) if os.path.exists(HTML_FILE) else 0
clients = []

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        global last_mtime
        if self.path == "/_reload":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            clients.append(self.wfile)
            return
        if self.path in ["/", "/index.html"]:
            if os.path.exists(HTML_FILE):
                html = open(HTML_FILE, encoding="utf-8").read()
                fn = chr(102)+chr(117)+chr(110)+chr(99)+chr(116)+chr(105)+chr(111)+chr(110)
                js = "<script>new EventSource('/_reload').onmessage="+fn
                js += chr(40)+chr(41)+"{location.reload()}</script>"
                html = html.replace("</body>", js + "</body>")
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(html.encode("utf-8"))
                return
        self.send_error(404)

def check_reload():
    global last_mtime
    while True:
        time.sleep(0.5)
        if os.path.exists(HTML_FILE):
            mt = os.path.getmtime(HTML_FILE)
            if mt > last_mtime:
                last_mtime = mt
                while clients:
                    try:
                        clients.pop().write(b"data: reload\n\n")
                    except:
                        pass

threading.Thread(target=check_reload, daemon=True).start()
print("Dev: http://0.0.0.0:" + str(PORT))
HTTPServer(("0.0.0.0", PORT), H).serve_forever()
