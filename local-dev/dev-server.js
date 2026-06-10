#!/usr/bin/env node
const http = require("http");
const fs = require("fs");
const path = require("path");
const PORT = parseInt(process.argv[2]) || 5500;
const HTML_FILE = path.join(__dirname, "..", "tmp", "flex-final.html");
const clients = [];
fs.watch(path.join(__dirname, "..", "tmp"), (e, fn) => {
  if (fn && fn.endsWith(".html")) {
    console.log("[" + new Date().toLocaleTimeString() + "] HTML changed, reloading...");
    clients.forEach(r => r.write("data: reload\n\n"));
    clients.length = 0;
  }
});
http.createServer((req, res) => {
  if (req.url === "/live-reload") {
    res.writeHead(200, {"Content-Type": "text/event-stream","Cache-Control": "no-cache","Access-Control-Allow-Origin": "*"});
    clients.push(res);
    req.on("close", () => { var i = clients.indexOf(res); if(i>=0) clients.splice(i,1); });
    return;
  }
  if (fs.existsSync(HTML_FILE)) {
    var html = fs.readFileSync(HTML_FILE, "utf-8");
    html = html.replace("</body>", '<script>(function(){var s=new EventSource("/live-reload");s.onmessage=function(){location.reload();}})();</script>\n</body>');
    res.writeHead(200, {"Content-Type": "text/html"});
    res.end(html);
  } else { res.writeHead(404); res.end("Extract HTML first: bash extract-html.sh"); }
}).listen(PORT, function() {
  console.log("Portfolio Dev Server: http://localhost:" + PORT);
  console.log("Edit " + HTML_FILE + " and save - browser auto-reloads!");
});
