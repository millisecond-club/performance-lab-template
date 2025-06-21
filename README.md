# Performance Lab Template

Base template for creating individual performance labs with real-time observability and load testing.

## 🎯 Goal

Create a standardized environment to:
- Run applications in containers with resource limits
- Perform load testing with K6 and real-time metrics
- Visualize performance data in Grafana dashboards
- Store results for analysis and comparison

## 📋 Prerequisites

- Docker & Docker Compose
- curl (for basic testing)

## 🚀 Quick Start

### 1. Run performance test
```bash
./test-runner.sh <application-image>
```

Example:
```bash
# Clone and build example app
git clone https://github.com/millisecond-club/hello-world-ruby.git
cd hello-world-ruby
docker build -t hello-world-ruby .
cd ..

# Run performance test
./test-runner.sh hello-world-ruby
```

### 2. Monitor results
- **K6 Dashboard**: http://localhost:3001/d/k6-load-testing (real-time metrics)
- **Grafana**: http://localhost:3001 (admin/admin)
- **Application**: http://localhost:9999

### 3. Cleanup
```bash
./cleanup.sh
```

## 🏗️ Architecture

```
[Client] → [Reverse Proxy :9999] → [Your App]
                    ↓
[K6 Load Tests] → [InfluxDB] → [Grafana Dashboard]
                    ↓
              [Result Files]
```

## 📁 Structure

```
performance-lab-template/
├── test-runner.sh                # Main execution script
├── cleanup.sh                    # Environment cleanup
├── docker-compose.yml            # Application stack
├── nginx/nginx.conf              # Reverse proxy config
├── k6/load-test.js               # Load test script
├── observability/                # Monitoring stack
│   ├── docker-compose.yml        # InfluxDB + Grafana + K6
│   ├── influxdb/init.sql         # Database setup
│   └── grafana/                  # Dashboards & datasources
└── results/                      # Test results (timestamped)
    └── YYYYMMDD_HHMMSS/
        ├── k6-summary.json       # Structured metrics
        ├── k6-summary.txt        # Human-readable summary
        └── test_info.json        # Test metadata
```

## 🔧 Configuration

### Different App Ports
Update `nginx/nginx.conf` if your app runs on a different port:
```nginx
upstream app {
    server app:YOUR_APP_PORT;  # Change this line
}
```

### Load Test Parameters
Modify `k6/load-test.js`:
```javascript
stages: [
  { duration: '10s', target: 5 },   // Ramp up
  { duration: '20s', target: 10 },  // Stay at load
  { duration: '10s', target: 0 },   // Ramp down
],
```

### Resource Limits
Application runs with:
- CPU: 0.5 cores (limit), 0.1 cores (reservation)
- Memory: 512MB (limit), 128MB (reservation)

## 📊 Results

### Real-time Dashboard
Pre-configured K6 dashboard with:
- **Response Time** (average + P95)
- **Request Rate** (req/s)
- **Virtual Users** (active count + timeline)
- **Error Rate** (%)

### File Results
Each test creates timestamped results:
- **JSON format** for programmatic analysis
- **Text format** for human reading
- **Metadata** with access URLs

### Expected Output
```bash
./test-runner.sh hello-world-ruby

🚀 Performance Lab Test Runner
===============================================

📊 Monitor URLs:
  K6 Dashboard: http://localhost:3001/d/k6-load-testing
  Application:  http://localhost:9999

🚀 Running K6 load test...

     ✓ status is 200
     ✓ response has message
     ✓ response time < 200ms

📊 K6 Test Results Summary:
==========================
Total Requests: 221
Failed Requests: 0.00%
Average Duration: 45.23ms
95th Percentile: 67.89ms
Requests/sec: 5.50

✅ Performance test completed successfully!
📁 Results saved to: results/20250621_143022
```

## 🧹 Cleanup

```bash
./cleanup.sh
```

Options to:
- Remove all containers
- Preserve or delete InfluxDB data
- Clean up Docker networks

## 🔍 Troubleshooting

**Port conflicts**: Ensure ports 3001, 8086, 9999 are available

**App endpoints**: Your app should expose `/health` and `/hello`, or modify the nginx config and K6 script accordingly

**Debug commands**:
```bash
# Check container status
docker ps | grep perf-lab

# View application logs
docker-compose logs app

# Test InfluxDB connection
curl -s http://localhost:8086/ping
```

## 🎯 Next Steps

1. Run your first test with a sample application
2. Explore the real-time K6 dashboard during test execution
3. Customize load patterns for your specific use case
4. Compare results across different test runs