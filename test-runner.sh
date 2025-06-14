#!/bin/bash

set -e

# Cleanup function
cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    docker stop perf-lab-app perf-lab-nginx 2>/dev/null || true
    docker rm perf-lab-app perf-lab-nginx 2>/dev/null || true
    docker network rm perf-lab-network 2>/dev/null || true
    echo "✅ Cleanup completed!"
}

# Trap for automatic cleanup on error or interruption
trap cleanup EXIT INT TERM

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

# Export variable for docker-compose
export APP_IMAGE

echo "📦 Starting application..."
docker-compose up -d

echo "⏳ Waiting for services to start..."
sleep 10

echo "🔍 Checking application health status..."
timeout=30
counter=0

while [ $counter -lt $timeout ]; do
    if curl -s http://localhost:9999/health > /dev/null 2>&1; then
        echo "✅ Application health check passed!"
        break
    fi
    
    counter=$((counter + 1))
    sleep 1
    
    if [ $counter -eq $timeout ]; then
        echo "❌ Application failed to respond within ${timeout} seconds"
        echo "📋 App logs:"
        docker-compose logs app
        echo "📋 Service logs:"
        docker-compose logs nginx
        exit 1
    fi
done

echo ""
echo "🧪 Testing application endpoints..."

# Testar endpoint /health
echo "Testing /health:"
curl -s http://localhost:9999/health | jq . || echo "Response: $(curl -s http://localhost:9999/health)"

echo ""
echo "Testing /hello:"
curl -s http://localhost:9999/hello

echo ""
echo ""
echo "✅ Basic test completed successfully!"
echo "📊 Application is running at: http://localhost:9999"
echo ""
echo "🎯 Test will auto-cleanup when you press Ctrl+C"
echo "🛑 Or run: docker stop perf-lab-app perf-lab-nginx && docker rm perf-lab-app perf-lab-nginx"
echo ""
echo "Results saved to: ${RESULTS_DIR}"

# Save basic test information
cat > "${RESULTS_DIR}/test_info.json" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "app_image": "${APP_IMAGE}",
  "test_type": "basic_validation",
  "status": "completed"
}
EOF

echo "📝 Test info saved to ${RESULTS_DIR}/test_info.json"