#!/usr/bin/env bash
# usage: scripts/load.sh http://localhost:30080/burn   (run in terminal A; watch HPA in terminal B)
URL=${1:-http://localhost:30080/burn}
for i in $(seq 1 20); do ( while true; do curl -s -o /dev/null "$URL"; done ) & done
echo "Load running. Stop with: pkill -f 'curl -s -o /dev/null'; kill 0"; wait
