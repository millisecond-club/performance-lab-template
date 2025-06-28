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

### 1. Setup dependencies (one time)
```bash
./setup-deps.sh
```

This starts InfluxDB and Grafana for metrics collection and visualization.

### 2. Run performance tests
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

### 3. Analyze results
- **🎯 K6 Dashboard**: http://localhost:3001/d/k6-load-testing (real-time metrics)
- **📊 Grafana Home**: http://localhost:3001 (admin/admin)

### 4. Run more tests (optional)
```bash
./test-runner.sh another-app:latest
./test-runner.sh my-optimized-app:v2
```

Dependencies stay running between tests for faster execution and historical comparison.

### 5. Cleanup when done
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
├── setup-deps.sh                 # Setup dependencies (InfluxDB + Grafana)
├── test-runner.sh                # Main test execution
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

## 🔄 Workflow

### **Efficient Multi-Test Workflow**
```bash
# First time setup
./setup-deps.sh                    # ~60s - sets up InfluxDB + Grafana

# Fast test iterations  
./test-runner.sh my-app:v1         # ~45s - runs test, stops app
./test-runner.sh my-app:v2         # ~15s - deps already running!
./test-runner.sh other-app:latest  # ~15s - compare different apps

# View historical data in Grafana dashboard
# All test results are preserved for comparison

# Cleanup when completely done
./cleanup.sh                       # Option to keep or delete data
```

### **One-off Testing** 
```bash
./test-runner.sh my-app:latest     # Auto-starts deps if needed
./cleanup.sh                       # Cleanup everything
```

## 📊 Data Persistence

**InfluxDB stores all test data with automatic retention:**
- **Real-time**: 1 hour (for live dashboard)
- **Historical**: 7 days (for trend analysis)
- **Benefits**: Compare versions, track performance evolution, identify regressions

**When you restart dependencies**, all historical data is preserved for continued analysis.

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

## 📈 Dashboard Features

### Real-time K6 Dashboard
Pre-configured dashboard with:
- **Response Time** (average + P95)
- **Request Rate** (req/s)
- **Virtual Users** (active count + timeline)
- **Error Rate** (%)

### Historical Analysis
- Compare multiple test runs side-by-side
- Track performance trends over time
- Identify performance regressions
- Baseline vs optimized comparisons

## 📄 Results

### File Results
Each test creates timestamped results in `results/YYYYMMDD_HHMMSS/`:
- **JSON format** for programmatic analysis
- **Text format** for human reading
- **Metadata** with access URLs and test info

### Expected Output
```bash
./test-runner.sh hello-world-ruby

🚀 Performance Lab Test Runner
===============================================

✅ Dependencies already running and healthy

📦 Starting application...
📊 Monitor URLs:
  Application:  http://localhost:9999
  K6 Dashboard: http://localhost:3001/d/k6-load-testing

⏳ Waiting for application to start...
  ✅ Application is ready!

🚀 Running K6 load test with InfluxDB integration...

📊 K6 Test Results Summary:
==========================
Total Requests: 221
Failed Requests: 0.00%
Average Duration: 45.23ms
95th Percentile: 67.89ms
Requests/sec: 5.50

🛑 Stopping application (keeping dependencies running)...

✅ Performance test completed successfully!
📁 Results saved to: results/20250628_143022
```

## 🧹 Cleanup Options

The `./cleanup.sh` script offers two-step cleanup:

### Step 1: Stop containers
- Stops and removes all containers
- Removes Docker networks
- **Preserves** all test data automatically

### Step 2: Data cleanup (optional)
- Choose whether to delete InfluxDB data volume
- **Recommended**: Keep data for historical analysis
- Only delete for fresh start or disk space

## 🔍 Troubleshooting

**Port conflicts**: Ensure ports 3001, 8086, 9999 are available

**Dependencies not starting**: 
```bash
./setup-deps.sh  # Restart dependencies
```

**App endpoints**: Your app should expose `/health` and `/hello`, or modify the nginx config and K6 script accordingly

**Debug commands**:
```bash
# Check container status
docker ps | grep perf-lab

# View application logs
docker-compose logs app

# View dependency logs
docker-compose -f observability/docker-compose.yml logs

# Test InfluxDB connection
curl -s http://localhost:8086/ping
```

## 🎯 Usage Examples

### Compare App Versions
```bash
./setup-deps.sh
./test-runner.sh my-app:v1.0
./test-runner.sh my-app:v1.1
# View both results in Grafana dashboard for comparison
```

### Performance Regression Testing
```bash
./test-runner.sh my-app:baseline
# Make changes...
./test-runner.sh my-app:after-changes
# Dashboard shows if performance improved or regressed
```

### Different Load Patterns
```bash
# Test with different K6 configurations
./test-runner.sh my-app:latest  # Default load
# Edit k6/load-test.js for high load
./test-runner.sh my-app:latest  # High load test
```

## 🎯 Next Steps

1. **Run your first test**: `./test-runner.sh <your-app-image>`
2. **Explore the K6 dashboard** during test execution
3. **Compare multiple runs** to understand performance characteristics
4. **Customize load patterns** for your specific use cases
5. **Build your performance lab** using this template as foundation