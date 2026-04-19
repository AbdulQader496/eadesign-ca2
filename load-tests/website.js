import http from 'k6/http';
import { check } from 'k6';

export const options = {
  vus: 20,
  iterations: 60000,
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<2000'],
  },
};

const targetUrl = (__ENV.TARGET_URL || 'http://20.49.254.4').replace(/\/$/, '');

export default function () {
  const homeResponse = http.get(`${targetUrl}/`);
  check(homeResponse, {
    'home returns 200': (response) => response.status === 200,
  });

  const apiResponse = http.get(`${targetUrl}/api/recipes`);
  check(apiResponse, {
    'recipes api returns 200': (response) => response.status === 200,
  });
}
