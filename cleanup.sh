#!/bin/bash

echo "🧹 Performance Lab Cleanup"
echo "=========================="

# Check what's running
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
echo "🛑 Step 1: Stop containers"
echo "This will stop and remove all performance lab containers and networks."
echo "Data in InfluxDB volumes will be preserved unless explicitly deleted in step 2."
echo ""
read -p "Stop all containers? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 Stopping application stack..."
    docker-compose down 2>/dev/null || true
    
    echo "🛑 Stopping observability stack..."
    docker-compose -f observability/docker-compose.yml down 2>/dev/null || true
    
    echo "🧹 Cleaning up any remaining containers..."
    docker stop perf-lab-app perf-lab-nginx perf-lab-grafana perf-lab-influxdb perf-lab-k6 2>/dev/null || true
    docker rm perf-lab-app perf-lab-nginx perf-lab-grafana perf-lab-influxdb perf-lab-k6 2>/dev/null || true
    
    echo "🌐 Removing network..."
    docker network rm perf-lab-network 2>/dev/null || true
    
    echo "✅ Containers stopped and removed!"
    echo ""
    
    # Step 2: Data cleanup (separate question)
    echo "🗄️ Step 2: Data cleanup"
    echo "InfluxDB contains all your performance test data and metrics history."
    echo ""
    echo "💡 Keeping data allows you to:"
    echo "   • Compare performance across different test runs"
    echo "   • Analyze historical trends when you restart Grafana"  
    echo "   • Resume analysis later without losing insights"
    echo ""
    echo "⚠️  Delete only if you want to start completely fresh or need disk space."
    echo ""
    read -p "Delete InfluxDB data volume? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume rm influxdb_data 2>/dev/null || true
        echo "✅ InfluxDB data volume deleted - fresh start on next run"
    else
        echo "💾 InfluxDB data volume preserved"
        echo "   → All test history will be available when you restart"
        echo "   → Run ./setup-deps.sh to access historical data in Grafana"
    fi
    
    echo ""
    echo "✅ Cleanup completed!"
    echo ""
    echo "🎯 Next steps:"
    echo "  1. Run ./setup-deps.sh to start dependencies"
    echo "  2. Run ./test-runner.sh <app-image> to run tests"
    
else
    echo "❌ Cleanup cancelled"
    echo ""
    echo "💡 Alternative options:"
    echo "  - To stop just the application: docker-compose down"
    echo "  - To stop just dependencies: docker-compose -f observability/docker-compose.yml down"
    echo "  - To restart dependencies: ./setup-deps.sh"
fi