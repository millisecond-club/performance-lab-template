# Performance Lab Template

Base template for creating individual performance labs. This template provides common infrastructure to test applications, run load tests, and measure performance metrics with observability.

## 🎯 Goal

Create a standardized environment to:
- Run applications in containers with resource limits
- Perform load testing with K6
- Collect and visualize performance metrics
- Compare results across different runs

## 📋 Prerequisites

- Docker & Docker Compose
- curl (for basic testing)
- jq (for JSON formatting, optional)

## 🚀 How to use

### 1. Run performance test
```bash
./test-runner.sh <application-image>
```

Example with the provided Ruby app:
```bash
# Clone and build example app
git clone https://github.com/millisecond-club/hello-world-ruby.git
cd hello-world-ruby
docker build -t hello-world-ruby .
cd ..

# Run performance test
./test-runner.sh hello-world-ruby
```

The test runner will:
- Start the application with reverse proxy
- Launch observability stack (Prometheus + Grafana)
- Run K6 load tests
- Display results summary
- Keep environment running for analysis

### 2. Monitor and analyze
Access the monitoring interfaces:
- **Application**: http://localhost:9999
- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090

### 3. Stop environment
```bash
./cleanup.sh
```

The environment runs persistently to allow real-time monitoring and analysis.

## 🏗️ Architecture

The template uses a **reverse proxy** to standardize the interface and includes full observability:

```
[Client] → [Reverse Proxy :9999] → [Your App :any-port]
                    ↓
[Prometheus] ← [Metrics] → [Grafana]
                    ↓
              [K6 Load Tests]
```

## 📁 Structure

```
performance-lab-template/
├── README.md              # This file
├── docker-compose.yml     # Application stack (app + reverse proxy)
├── test-runner.sh         # Main execution script (persistent mode)
├── cleanup.sh             # Environment cleanup script
├── nginx/                 # Reverse proxy configuration
│   └── nginx.conf
├── observability/         # Monitoring stack
│   ├── docker-compose.yml # Prometheus + Grafana
│   ├── prometheus/
│   │   └── prometheus.yml
│   └── grafana/
│       ├── datasources/
│       └── dashboards/
├── k6/                    # Load testing scripts
│   └── load-test.js
└── results/               # Test results
    └── YYYYMMDD_HHMMSS/   # Timestamped folder for each execution
        ├── k6-summary.json
        ├── k6-summary.txt
        └── test_info.json
```

## 🔧 Configuration

### Customizing for Different Apps
If your app runs on a different port, update `nginx/nginx.conf`:
```nginx
upstream app {
    server app:YOUR_APP_PORT;  # Change this line
}
```

### Resource Limits
By default, the application runs with:
- CPU: 0.5 cores (limit), 0.1 cores (reservation)
- Memory: 512MB (limit), 128MB (reservation)

### Load Testing
K6 configuration in `k6/load-test.js`:
- Duration: 40 seconds
- Virtual Users: 5 → 10 → 0 (ramp up/down)
- Target endpoint: `/hello`
- Thresholds: P95 < 500ms, error rate < 10%

You can adjust these values in their respective configuration files.

## 📊 Results

After running tests, you'll have:
- **Console summary** with key metrics
- **JSON results** for programmatic analysis  
- **Real-time dashboards** in Grafana
- **Historical metrics** in Prometheus
- **Test metadata** for comparison

### Expected Output
```bash
./test-runner.sh hello-world-ruby
🚀 Performance Lab Test Runner
===============================================
🌐 Creating network...
📊 Starting observability stack...
📦 Starting application stack...

📊 Monitor URLs (starting up):
  Grafana:      http://localhost:3001 (admin/admin)
  Prometheus:   http://localhost:9090
  Application:  http://localhost:9999

🚀 Running K6 load test...
📊 K6 Test Results Summary:
==========================
Total Requests: 220
Failed Requests: 0%
Average Duration: 45.23ms
95th Percentile: 67.89ms
Requests/sec: 5.50

✅ Performance test completed successfully!
```