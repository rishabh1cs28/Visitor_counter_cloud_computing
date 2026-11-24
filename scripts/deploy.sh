#!/usr/bin/env bash
# usage: scripts/deploy.sh <kind-cluster-name> <nodeport> <label>
set -euo pipefail
NAME=$1; PORT=$2; LABEL=$3
kind load docker-image visitor-counter:optimized --name "$NAME"
kubectl config use-context "kind-$NAME"
kubectl apply -f k8s/redis.yaml
sed -e "s/CLUSTER_PLACEHOLDER/$LABEL/" -e "s/NODEPORT_PLACEHOLDER/$PORT/" k8s/web.yaml | kubectl apply -f -
kubectl rollout status deploy/web
