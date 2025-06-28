#!/bin/bash

set -e

# Check if image was provided
if [ -z "$1" ]; then
    echo "❌ Error: Application image is required"
    echo "Usage: $0 <app-image>"
    echo "Example: $0 my-app:latest"
    exit 1
fi

# Configuration
APP_IMAGE=$1
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="results/${TIMESTAMP}"

echo "🚀 Performance Lab Test Runner"
echo "==============================================="
echo "App Image: ${APP_IMAGE}"
echo "Timestamp: ${TIMESTAMP}"
echo "Results will be saved to: ${RESULTS_DIR}"
echo ""

# Create the results directory
mkdir -p "${RESULTS_DIR}"
chmod 755 "${RESULTS_DIR}"

# Function to check if dependencies are running and healthy
deps_running() {
    local influxdb_running=$(docker ps -q -f name=perf-lab-influxdb)
    local grafana_running=$(docker ps -q -f name=perf-lab-grafana)
    
    if [ ! -z "$influxdb_running" ] && [ ! -z "$grafana_running" ]; then
        # Check if they're actually responding
        if curl -s http://localhost:8086/ping > /dev/null 2>&1 && \
           curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
            return 0  # Both running and healthy
        fi
    fi
    return 1  # Not running or not healthy
}

# Check dependencies and start if needed
if ! deps_running; then
    echo "📦 Dependencies not running, starting them..."
    ./setup-deps.sh
    echo ""
else
    echo "✅ Dependencies already running and healthy"
    echo ""
fi

# Check if application is already running
APP_RUNNING=$(docker ps -q -f name=perf-lab-app)
if [ ! -z "$APP_RUNNING" ]; then
    echo "⚠️  Found existing application container running"
    read -p "Stop it and start fresh? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🛑 Stopping existing application..."
        docker-compose down 2>/dev/null || true
        echo ""
    else
        echo "❌ Cannot proceed with existing application"
        echo "Stop the existing container first or choose 'y'"
        exit 1
    fi
fi

# Export variable for docker-compose
export APP_IMAGE

echo "📦 Starting application..."
docker-compose up -d

echo ""
echo "📊 Monitor URLs:"
echo "  Application:  http://localhost:9999"
echo "  K6 Dashboard: http://localhost:3001/d/k6-load-testing"
echo "  Grafana:      http://localhost:3001 (admin/admin)"
echo ""

echo "⏳ Waiting for application to start..."

echo "  - Checking if application container is running..."
sleep 5  # Give docker-compose a moment to start
if ! docker ps | grep -q perf-lab-app; then
    echo "  ❌ Application container is not running!"
    echo "📋 App logs:"
    docker-compose logs app
    exit 1
fi

echo "  - Checking application health via reverse proxy..."
timeout=45
counter=0
while [ $counter -lt $timeout ]; do
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9999/health 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        echo "  ✅ Application is ready!"
        break
    elif [ "$response" = "502" ] || [ "$response" = "503" ]; then
        echo "  ⏳ Got ${response}, application starting... (${counter}/${timeout})"
    elif [ "$response" = "000" ]; then
        echo "  ⏳ No response yet... (${counter}/${timeout})"
    else
        echo "  ⚠️ Unexpected response: ${response} (${counter}/${timeout})"
    fi
    
    counter=$((counter + 1))
    sleep 1
    
    if [ $counter -eq $timeout ]; then
        echo "  ❌ Application failed to respond with 200 within ${timeout} seconds"
        echo "  📋 Final response code: ${response}"
        echo "📋 App logs:"
        docker-compose logs app | tail -20
        echo "📋 Reverse proxy logs:"
        docker-compose logs nginx | tail -20
        exit 1
    fi
done

echo ""
echo "🧪 Testing endpoints via reverse proxy (port 9999)..."

# Test endpoint /health
echo "Testing /health:"
curl -s http://localhost:9999/health | jq . 2>/dev/null || echo "Response: $(curl -s http://localhost:9999/health)"

echo ""
echo "Testing /hello:"
curl -s http://localhost:9999/hello

echo ""
echo ""
echo "🚀 Running K6 load test with InfluxDB integration..."
echo "📊 Real-time metrics available at: http://localhost:3001/d/k6-load-testing"
echo ""

# Run K6 test
docker-compose -f observability/docker-compose.yml --profile testing run --rm \
  --user "$(id -u):$(id -g)" \
  -e RESULTS_DIR="/shared/results/${TIMESTAMP}" \
  k6 run /scripts/load-test.js --out influxdb=http://influxdb:8086/k6

echo ""
echo "📊 K6 Test Results Summary:"
echo "=========================="
if [ -f "${RESULTS_DIR}/k6-summary.txt" ]; then
    cat "${RESULTS_DIR}/k6-summary.txt"
else
    echo "⚠️  K6 summary file not found at: ${RESULTS_DIR}/k6-summary.txt"
    echo "📁 Files in results directory:"
    ls -la "${RESULTS_DIR}/" 2>/dev/null || echo "  Directory doesn't exist"
fi

echo ""
echo "🛑 Stopping application (keeping dependencies running)..."
docker-compose down

echo ""
echo "✅ Performance test completed successfully!"
echo ""
echo "📁 Results saved to: ${RESULTS_DIR}"
echo "📊 Dependencies still running - view dashboard: http://localhost:3001/d/k6-load-testing"
echo "🛑 To stop dependencies: ./cleanup.sh"
echo ""

# Save test information
cat > "${RESULTS_DIR}/test_info.json" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "app_image": "${APP_IMAGE}",
  "test_type": "k6_load_test_with_influxdb",
  "status": "completed",
  "access_urls": {
    "grafana": "http://localhost:3001",
    "k6_dashboard": "http://localhost:3001/d/k6-load-testing",
    "influxdb": "http://localhost:8086"
  },
  "notes": "Dependencies kept running for analysis. Use ./cleanup.sh to stop them."
}
EOF

echo "📝 Test info saved to ${RESULTS_DIR}/test_info.json"
echo ""
echo "🎯 Next steps:"
echo "  1. Analyze results in Grafana dashboard"
echo "  2. Run more tests: ./test-runner.sh <another-app-image>"
echo "  3. When done: ./cleanup.sh"