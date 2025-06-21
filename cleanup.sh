#!/bin/bash

echo "🧹 Performance Lab Cleanup"
echo "=========================="

# Check if any containers are running
APP_RUNNING=$(docker ps -q -f name=perf-lab-app)
NGINX_RUNNING=$(docker ps -q -f name=perf-lab-nginx)
GRAFANA_RUNNING=$(docker ps -q -f name=perf-lab-grafana)
INFLUXDB_RUNNING=$(docker ps -q -f name=perf-lab-influxdb)
K6_RUNNING=$(docker ps -q -f name=perf-lab-k6)

if [ -z "$APP_RUNNING" ] && [ -z "$NGINX_RUNNING" ] && [ -z "$GRAFANA_RUNNING" ] && [ -z "$INFLUXDB_RUNNING" ] && [ -z "$K6_RUNNING" ]; then
    echo "✅ No performance lab containers running"
    exit 0
fi

echo "Found running containers:"
[ ! -z "$APP_RUNNING" ] && echo "  - perf-lab-app"
[ ! -z "$NGINX_RUNNING" ] && echo "  - perf-lab-nginx"
[ ! -z "$GRAFANA_RUNNING" ] && echo "  - perf-lab-grafana"
[ ! -z "$INFLUXDB_RUNNING" ] && echo "  - perf-lab-influxdb"
[ ! -z "$K6_RUNNING" ] && echo "  - perf-lab-k6"

echo ""
read -p "Stop and remove all containers? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 Stopping application stack..."
    docker-compose down 2>/dev/null || true
    
    echo "🛑 Stopping observability stack..."
    docker-compose -f observability/docker-compose.yml down 2>/dev/null || true
    
    echo "🧹 Cleaning up remaining containers..."
    docker stop perf-lab-app perf-lab-nginx perf-lab-grafana perf-lab-influxdb perf-lab-k6 2>/dev/null || true
    docker rm perf-lab-app perf-lab-nginx perf-lab-grafana perf-lab-influxdb perf-lab-k6 2>/dev/null || true
    
    echo "🗄️ Removing InfluxDB volume (this will delete all test data)..."
    read -p "Delete InfluxDB data volume? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume rm influxdb_data 2>/dev/null || true
        echo "✅ InfluxDB data volume removed"
    else
        echo "⚠️ InfluxDB data volume preserved for next run"
    fi
    
    echo "🌐 Removing network..."
    docker network rm perf-lab-network 2>/dev/null || true
    
    echo "✅ Cleanup completed!"
else
    echo "❌ Cleanup cancelled"
fi