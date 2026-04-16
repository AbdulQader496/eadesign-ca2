const assert = require('assert');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { spawn } = require('child_process');

const configPath = path.join(__dirname, '..', 'config', 'config.json');

describe('frontend smoke test', function () {
  this.timeout(15000);

  let backendServer;
  let frontendProcess;
  let originalConfig;

  before((done) => {
    originalConfig = fs.readFileSync(configPath, 'utf8');
    fs.writeFileSync(
      configPath,
      JSON.stringify(
        {
          development: {
            config_id: 'development',
            app_name: 'Recipe Tracker',
            webservice_host: '127.0.0.1',
            webservice_port: '18080',
            exposedPort: '22137'
          }
        },
        null,
        2
      )
    );

    backendServer = http.createServer((req, res) => {
      if (req.url === '/recipes' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify([
          { name: 'toast', ingredients: ['bread'], prepTimeInMinutes: 5 }
        ]));
        return;
      }

      if (req.url === '/recipe' && req.method === 'POST') {
        req.resume();
        res.writeHead(201, { 'Content-Type': 'application/json' });
        res.end('1');
        return;
      }

      res.writeHead(404);
      res.end();
    });

    backendServer.listen(18080, '127.0.0.1', () => {
      frontendProcess = spawn('node', ['fe-server.js'], {
        cwd: path.join(__dirname, '..'),
        stdio: 'ignore'
      });

      setTimeout(done, 1500);
    });
  });

  after((done) => {
    fs.writeFileSync(configPath, originalConfig);

    if (frontendProcess) {
      frontendProcess.kill();
    }

    if (backendServer) {
      backendServer.close(done);
      return;
    }

    done();
  });

  it('loads the homepage successfully', (done) => {
    http.get('http://127.0.0.1:22137', (res) => {
      let body = '';

      res.on('data', (chunk) => {
        body += chunk;
      });

      res.on('end', () => {
        assert.strictEqual(res.statusCode, 200);
        assert.match(body, /Recipe Tracker/);
        assert.match(body, /Your Previous Recipes/);
        done();
      });
    }).on('error', done);
  });
});
