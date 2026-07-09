#!/bin/bash
docker inspect lab-sre-denoso-control-plane 2>/dev/null | grep -oP '"IPAddress": "\K[0-9.]+' | head -1
