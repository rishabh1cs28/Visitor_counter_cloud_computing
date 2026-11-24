#!/usr/bin/env bash
# prints image sizes + live pod resource usage for the cost table
docker build -q -f Dockerfile.before -t visitor-counter:before .
docker build -q -f Dockerfile        -t visitor-counter:optimized .
docker images visitor-counter --format 'table {{.Tag}}\t{{.Size}}'
kubectl top pods 2>/dev/null || true
