#!/bin/bash

echo "🧹 Performance Lab Cleanup"
echo "=========================="

# Check if any containers are running
APP_RUNNING=$(docker ps -q -f name=perf-lab-app)
NGINX_RUNNING=$(docker ps -q -f name=perf-lab-nginx)
PROMETHEUS_RUNNING=$(docker ps -q -f name=perf-lab-prometheus)
GRAFANA_RUNNING=$(docker ps -q -f name=perf-lab-grafana)

if [ -z "$APP_RUNNING" ] && [ -z "$NGINX_RUNNING" ] && [ -z "$PROMETHEUS_RUNNING" ] && [ -z "$GRAFANA_RUNNING" ]; then
    echo "✅ No performance lab containers running"
    exit 0
fi

echo "Found running containers:"
[ ! -z "$APP_RUNNING" ] && echo "  - perf-lab-app"
[ ! -z "$NGINX_RUNNING" ] && echo "  - perf-lab-nginx"
[ ! -z "$PROMETHEUS_RUNNING" ] && echo "  - perf-lab-prometheus"
[ ! -z "$GRAFANA_RUNNING" ] && echo "  - perf-lab-grafana"

echo ""
read -p "Stop and remove all containers? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 Stopping application stack..."
    docker-compose down 2>/dev/null || true
    
    echo "🛑 Stopping observability stack..."
    docker-compose -f observability/docker-compose.yml down 2>/dev/null || true
    
    echo "🧹 Cleaning up remaining containers..."
    docker stop perf-lab-app perf-lab-nginx perf-lab-prometheus perf-lab-grafana 2>/dev/null || true
    docker rm perf-lab-app perf-lab-nginx perf-lab-prometheus perf-lab-grafana 2>/dev/null || true
    
    echo "🌐 Removing network..."
    docker network rm perf-lab-network 2>/dev/null || true
    
    echo "✅ Cleanup completed!"
else
    echo "❌ Cleanup cancelled"
fi