#!/usr/bin/env node
var http=require("http"),fs=require("fs"),path=require("path");
var PORT=parseInt(process.argv[2])||5500;
var HTML=path.join(__dirname,"..","tmp","flex-final.html");
var clients=[];

fs.watch(path.join(__dirname,"..","tmp"),function(e,n){
  if(n&&n.match(/\.html$/)){ 
    console.log("["+new Date().toLocaleTimeString()+"] reload");
    clients.forEach(function(r){try{r.write("data: reload\n\n")}catch(e){}});
    clients.length=0;
  }
});

http.createServer(function(q,r){
  if(q.url==="/_reload"){ 
    r.writeHead(200,{"Content-Type":"text/event-stream"});
    clients.push(r); 
    q.on("close",function(){var i=clients.indexOf(r);if(i>=0)clients.splice(i,1);});
    return; 
  }
  if(!fs.existsSync(HTML)){r.writeHead(404);r.end("no html");return;}
  var h=fs.readFileSync(HTML,"utf-8");
  h=h.replace("</body>","<script>new EventSource('/_reload').onmessage=function(){location.reload()}<\/script></body>");
  r.writeHead(200,{"Content-Type":"text/html"});
  r.end(h);
}).listen(PORT,"0.0.0.0",function(){
  console.log("Dev: http://localhost:"+PORT);
});
