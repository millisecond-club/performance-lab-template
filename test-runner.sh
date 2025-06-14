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

# Create results directory
mkdir -p "${RESULTS_DIR}"

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

echo "📊 Starting observability stack..."
docker-compose -f observability/docker-compose.yml up -d

echo "📦 Starting application stack..."
docker-compose up -d

echo ""
echo "📊 Monitor URLs (starting up):"
echo "  Grafana:      http://localhost:3001 (admin/admin)"
echo "  Prometheus:   http://localhost:9090"
echo "  Application:  http://localhost:9999"
echo ""

echo "⏳ Waiting for services to start..."
sleep 15

echo "🔍 Checking application health..."
timeout=30
counter=0

while [ $counter -lt $timeout ]; do
    if curl -s http://localhost:9999/health > /dev/null 2>&1; then
        echo "✅ Application is healthy!"
        break
    fi
    
    counter=$((counter + 1))
    sleep 1
    
    if [ $counter -eq $timeout ]; then
        echo "❌ Application failed to respond within ${timeout} seconds"
        echo "📋 App logs:"
        docker-compose logs app
        echo "📋 Reverse proxy logs:"
        docker-compose logs nginx
        exit 1
    fi
done

echo ""
echo "🧪 Testing endpoints via reverse proxy (port 9999)..."

# Test endpoint /health
echo "Testing /health:"
curl -s http://localhost:9999/health | jq . || echo "Response: $(curl -s http://localhost:9999/health)"

echo ""
echo "Testing /hello:"
curl -s http://localhost:9999/hello

echo ""
echo ""
echo "🚀 Running K6 load test..."
docker run --rm --network perf-lab-network \
  --user "$(id -u):$(id -g)" \
  -v "$(pwd)/k6:/scripts" \
  -v "$(pwd)/${RESULTS_DIR}:/results" \
  grafana/k6:latest run /scripts/load-test.js

echo ""
echo "📊 K6 Test Results Summary:"
echo "=========================="
if [ -f "${RESULTS_DIR}/k6-summary.txt" ]; then
    cat "${RESULTS_DIR}/k6-summary.txt"
else
    echo "⚠️  K6 summary file not found"
fi
echo ""

echo ""
echo "✅ Performance test completed successfully!"
echo ""
echo "📁 Results saved to: ${RESULTS_DIR}"
echo "🛑 To cleanup: ./cleanup.sh"
echo ""

# Save basic test information
cat > "${RESULTS_DIR}/test_info.json" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "app_image": "${APP_IMAGE}",
  "test_type": "k6_load_test",
  "status": "completed",
  "access_urls": {
    "application": "http://localhost:9999",
    "grafana": "http://localhost:3001",
    "prometheus": "http://localhost:9090"
  }
}
EOF

echo "📝 Test info saved to ${RESULTS_DIR}/test_info.json"