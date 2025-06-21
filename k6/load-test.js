import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 5 },   // Ramp up to 5 users
    { duration: '20s', target: 10 },  // Stay at 10 users
    { duration: '10s', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must be below 500ms
    http_req_failed: ['rate<0.1'],    // Error rate must be below 10%
  },
  ext: {
    loadimpact: {
      distribution: {
        'amazon:us:ashburn': { loadZone: 'amazon:us:ashburn', percent: 100 },
      },
    },
  },
};

export default function () {
  // Test main endpoint
  const response = http.get('http://perf-lab-nginx:9999/hello');

  check(response, {
    'status is 200': (r) => r.status === 200,
    'response has message': (r) => r.json('message') === 'world',
    'response time < 200ms': (r) => r.timings.duration < 200,
  });

  sleep(1);
}

export function handleSummary(data) {
  const resultsDir = __ENV.RESULTS_DIR || '/shared/results';

  return {
    [`${resultsDir}/k6-summary.json`]: JSON.stringify(data, null, 2),
    [`${resultsDir}/k6-summary.txt`]: textSummary(data, { indent: ' ', enableColors: false }),
  };
}

function textSummary(data, options = {}) {
  const indent = options.indent || '';
  const enableColors = options.enableColors || false;

  let summary = `${indent}📊 K6 Test Results Summary:\n`;
  summary += `${indent}==========================\n`;
  summary += `${indent}Total Requests: ${data.metrics.http_reqs.values.count}\n`;
  summary += `${indent}Failed Requests: ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%\n`;
  summary += `${indent}Average Duration: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
  summary += `${indent}95th Percentile: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  summary += `${indent}Max Duration: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms\n`;
  summary += `${indent}Requests/sec: ${data.metrics.http_reqs.values.rate.toFixed(2)}\n`;
  summary += `${indent}Data Received: ${(data.metrics.data_received.values.count / 1024).toFixed(2)} KB\n`;
  summary += `${indent}Virtual Users: ${data.metrics.vus.values.value}\n`;
  summary += `${indent}Test Duration: ${data.state.testRunDurationMs / 1000}s\n`;

  return summary;
}