# Performance Lab Template

Base template for creating individual performance labs. This template provides common infrastructure to test applications and measure performance metrics.

## 🎯 Goal

Create a standardized environment to:
- Run applications in containers with resource limits
- Perform load testing
- Collect performance metrics
- Compare results

## 📋 Prerequisites

- Docker & Docker Compose
- curl (for basic testing)
- jq (for JSON formatting, optional)

## 🚀 How to use

### 1. Run basic test
```bash
./test-runner.sh <application-image>
```

Example:
```bash
./test-runner.sh simple-sinatra-app:latest
```

### 2. Stop environment
The test runner includes automatic cleanup. The environment will be cleaned up when:
- Test completes successfully
- Script is interrupted (Ctrl+C)
- An error occurs

Manual cleanup (if needed):
```bash
docker stop perf-lab-app perf-lab-nginx
docker rm perf-lab-app perf-lab-nginx
docker network rm perf-lab-network
```

## 🏗️ Architecture

The template uses **Nginx as a reverse proxy** to standardize the interface:

```
[Client] → [Nginx :9999] → [Your App :any-port]
```

## 📁 Structure

```
performance-lab-template/
├── README.md              # This file
├── docker-compose.yml     # Container orchestration
├── test-runner.sh         # Main execution script (with auto-cleanup)
├── nginx/                 # Nginx reverse proxy configuration
│   └── nginx.conf
├── k6/                    # Load test scripts (future step)
├── prometheus/            # Metrics configuration (future step)
├── grafana/               # Dashboards (future step)
└── results/               # Test results
    └── YYYYMMDD_HHMMSS/   # Timestamped folder for each execution
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

You can adjust these values in `docker-compose.yml`.

## 📈 Next Steps

This template is under iterative development. Upcoming features:
- [ ] K6 integration for load testing
- [ ] Prometheus metrics
- [ ] Grafana visualization
- [ ] Automated performance reports

## 🧪 Testing the Template

To validate the template works:

1. Build an example application that implements the required endpoints
2. Run: `./test-runner.sh your-app:latest`  
3. Verify endpoints respond correctly via port 9999
4. Confirm results are saved in `results/`
5. Test auto-cleanup by pressing Ctrl+C during execution

### Expected Output
```bash
./test-runner.sh hello-world-ruby
🚀 Performance Lab Test Runner
===============================================
App Image: hello-world-ruby
...
✅ Application is responding via nginx!
🧪 Testing endpoints via nginx (port 9999)...
✅ Basic test completed successfully!
📊 Application is running at: http://localhost:9999
```