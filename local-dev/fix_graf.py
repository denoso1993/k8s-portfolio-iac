#!/usr/bin/env python3
import subprocess, sys

# Get ConfigMap content
r = subprocess.run(["bash", "-c", 'kubectl get configmap nginx-html-config -n default -o jsonpath="{.data.index\.html}" 2>/dev/null'], capture_output=True, text=True)
html = r.stdout

# Fix sizes
html = html.replace('height="400" frameborder="0" style="display:block;position:absolute;top:-75px;left:0;width:100%;height:125%;',
                     'height="500" frameborder="0" style="display:block;position:absolute;top:-65px;left:0;width:100%;height:135%;')
html = html.replace('min-height:200px;overflow:hidden;position:relative;', 'height:420px;overflow:hidden;position:relative;')

with open("/tmp/graf_final.html", "w") as f:
    f.write(html)

print("OK - Fixed!")
sys.stdout.flush()
