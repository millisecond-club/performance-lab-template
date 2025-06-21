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

# Create the results directory in the shared volume
mkdir -p "${RESULTS_DIR}"
# Ensure the host script can also write to this directory
chmod 755 "${RESULTS_DIR}"

# Check if environment is already running
APP_RUNNING=$(docker ps -q -f name=perf-lab-app)
if [ ! -z "$APP_RUNNING" ]; then
    echo "⚠️  Found existing performance lab environment running"
    read -p "Clean it up first? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./cleanup.sh
        echo ""
    else
        echo "❌ Cannot proceed with existing environment"
        echo "Run ./cleanup.sh first or choose 'y' to clean up"
        exit 1
    fi
fi

# Export variable for docker-compose
export APP_IMAGE

echo "🌐 Creating network..."
docker network create perf-lab-network 2>/dev/null || echo "Network already exists"

echo "📊 Starting observability stack (InfluxDB, Prometheus, Grafana)..."
docker-compose -f observability/docker-compose.yml up -d influxdb prometheus grafana

echo "📦 Starting application stack..."
docker-compose up -d

echo ""
echo "📊 Monitor URLs (starting up):"
echo "  Grafana:      http://localhost:3001 (admin/admin)"
echo "  Prometheus:   http://localhost:9090"
echo "  InfluxDB:     http://localhost:8086"
echo "  Application:  http://localhost:9999"
echo ""

echo "⏳ Waiting for services to start..."
echo "  - Initial startup delay..."
sleep 10

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
        exit 1
    fi
done

echo "  - Checking if application container is running..."
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
    # First check if we get any response (even error)
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

# Run K6 as a service with InfluxDB output
echo "🔧 K6 Configuration:"
echo "  - InfluxDB URL: http://influxdb:8086"
echo "  - Database: k6"
echo "  - Results dir: ${RESULTS_DIR}"
echo ""

docker-compose -f observability/docker-compose.yml --profile testing run --rm \
  --user "$(id -u):$(id -g)" \
  -e RESULTS_DIR="/shared/results/${TIMESTAMP}" \
  k6 run --no-summary /scripts/load-test.js --out influxdb=http://influxdb:8086/k6

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

echo ""
echo "✅ Performance test completed successfully!"
echo ""
echo "📁 Results saved to: ${RESULTS_DIR}"
echo "📊 View real-time dashboard: http://localhost:3001/d/k6-load-testing"
echo "🛑 To cleanup: ./cleanup.sh"
echo ""

# Save basic test information
cat > "${RESULTS_DIR}/test_info.json" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "app_image": "${APP_IMAGE}",
  "test_type": "k6_load_test_with_influxdb",
  "status": "completed",
  "access_urls": {
    "application": "http://localhost:9999",
    "grafana": "http://localhost:3001",
    "k6_dashboard": "http://localhost:3001/d/k6-load-testing",
    "prometheus": "http://localhost:9090",
    "influxdb": "http://localhost:8086"
  }
}
EOF

echo "📝 Test info saved to ${RESULTS_DIR}/test_info.json"
echo ""
echo "🎯 Next steps:"
echo "  1. Check the K6 dashboard at http://localhost:3001/d/k6-load-testing"
echo "  2. Analyze the metrics in Grafana"
echo "  3. Run ./cleanup.sh when done"