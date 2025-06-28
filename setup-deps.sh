#!/bin/bash

set -e

echo "🚀 Performance Lab Dependencies Setup"
echo "====================================="

# Function to check if dependencies are running
deps_running() {
    local influxdb_running=$(docker ps -q -f name=perf-lab-influxdb)
    local grafana_running=$(docker ps -q -f name=perf-lab-grafana)
    
    if [ ! -z "$influxdb_running" ] && [ ! -z "$grafana_running" ]; then
        return 0  # Both running
    else
        return 1  # At least one not running
    fi
}

# Function to show access URLs
show_access_urls() {
    echo ""
    echo "📊 Ready! Access your dashboards:"
    echo "  🎯 K6 Performance Dashboard: http://localhost:3001/d/k6-load-testing"
    echo "  📊 Grafana Home:             http://localhost:3001 (admin/admin)"
    echo "  🗄️ InfluxDB:                 http://localhost:8086"
    echo ""
}

# Check if dependencies are already running
if deps_running; then
    echo "✅ Dependencies already running"
    
    # Verify they're actually healthy
    echo "🔍 Checking service health..."
    
    if curl -s http://localhost:8086/ping > /dev/null 2>&1; then
        echo "  ✅ InfluxDB is healthy"
    else
        echo "  ⚠️ InfluxDB container running but not responding"
        echo "  🔄 Restarting dependencies..."
        docker-compose -f observability/docker-compose.yml restart
        sleep 5
    fi
    
    if curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
        echo "  ✅ Grafana is healthy"
    else
        echo "  ⚠️ Grafana container running but not responding"
        echo "  🔄 Restarting dependencies..."
        docker-compose -f observability/docker-compose.yml restart
        sleep 5
    fi
    
    show_access_urls
    echo "✅ Dependencies setup completed!"
    exit 0
fi

echo "📦 Starting dependencies..."

echo "🌐 Creating network..."
docker network create perf-lab-network 2>/dev/null || echo "  Network already exists"

echo "📊 Starting InfluxDB and Grafana..."
docker-compose -f observability/docker-compose.yml up -d influxdb grafana

echo ""
echo "⏳ Waiting for services to start..."

# Wait for InfluxDB
echo "  - Checking InfluxDB..."
timeout=60
counter=0
while [ $counter -lt $timeout ]; do
    if curl -s http://localhost:8086/ping > /dev/null 2>&1; then
        echo "  ✅ InfluxDB is ready!"
        break
    fi
    counter=$((counter + 1))
    sleep 1
    if [ $counter -eq $timeout ]; then
        echo "  ❌ InfluxDB failed to start within ${timeout} seconds"
        echo "📋 InfluxDB logs:"
        docker-compose -f observability/docker-compose.yml logs influxdb | tail -10
        exit 1
    fi
done

# Wait for Grafana
echo "  - Checking Grafana..."
timeout=60
counter=0
while [ $counter -lt $timeout ]; do
    if curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
        echo "  ✅ Grafana is ready!"
        break
    fi
    counter=$((counter + 1))
    sleep 1
    if [ $counter -eq $timeout ]; then
        echo "  ❌ Grafana failed to start within ${timeout} seconds"
        echo "📋 Grafana logs:"
        docker-compose -f observability/docker-compose.yml logs grafana | tail -10
        exit 1
    fi
done

show_access_urls

echo "✅ Dependencies setup completed!"
echo ""
echo "🎯 Next steps:"
echo "  1. Run performance tests: ./test-runner.sh <app-image>"
echo "  2. 📈 Watch live metrics: http://localhost:3001/d/k6-load-testing"
echo "  3. Cleanup when done: ./cleanup.sh"