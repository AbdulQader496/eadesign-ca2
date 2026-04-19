var http = require('http');
var url = require('url');
const { parse } = require('querystring');
var fs = require('fs');
const client = require('prom-client');

//Loading the config fileContents
const config = require('./config/config.json');
const defaultConfig = config.development;
global.gConfig = defaultConfig;

client.collectDefaultMetrics();
const frontendRequestCounter = new client.Counter({
	name: 'frontend_http_requests_total',
	help: 'Total number of HTTP requests handled by the frontend',
	labelNames: ['method', 'route', 'status_code']
});

//Generating some constants to be used to create the common HTML elements.
var header = '<!doctype html><html>'+
		     '<head>';
				
var body =  '</head><body><div id="container">' +
				 '<div id="logo">' + global.gConfig.app_name + '</div>' +
				 '<div id="space"></div>' +
				 '<div id="form">' +
				 '<form id="form" action="/" method="post"><center>'+
				 '<label class="control-label">Name:</label>' +
				 '<input class="input" type="text" name="name"/><br />'+			
				 '<label class="control-label">Ingredients:</label>' +
				 '<input class="input" type="text" name="ingredients" /><br />'+
				 '<label class="control-label">Prep Time:</label>' +
				 '<input class="input" type="number" name="prepTimeInMinutes" /><br />';

var submitButton = '<button class="button button1">Submit</button>' +
				   '</div></form>';
				   
var endBody = '</div></body></html>';				   

function renderRecipes(res, recipes, errorMessage) {
	res.write('<div id="space"></div>');
	res.write('<div id="logo">Your Previous Recipes</div>');
	res.write('<div id="space"></div>');

	if (errorMessage) {
		res.write('<div id="results">' + errorMessage + '</div>');
		res.write('<div id="space"></div>');
		res.end(endBody);
		return;
	}

	res.write('<div id="results">Name | Ingredients | PrepTime');
	res.write('<div id="space"></div>');

	for (let i = 0; i < recipes.length; i++) {
		res.write(recipes[i].name + ' | ' + recipes[i].ingredients + ' | ');
		res.write(recipes[i].prepTimeInMinutes + '<br/>');
	}

	res.write('</div><div id="space"></div>');
	res.end(endBody);
}


http.createServer(function (req, res) {
	console.log(req.url)

	if (req.url === '/metrics') {
		res.writeHead(200, { 'Content-Type': client.register.contentType });
		client.register.metrics()
			.then((metrics) => {
				frontendRequestCounter.inc({ method: req.method, route: '/metrics', status_code: '200' });
				res.end(metrics);
			})
			.catch(() => {
				frontendRequestCounter.inc({ method: req.method, route: '/metrics', status_code: '500' });
				res.statusCode = 500;
				res.end('Unable to collect metrics');
			});
		return;
	}

	//This validation needed to avoid duplicated (i.e., twice!) get / calls (due to the favicon.ico)
	if (req.url === '/favicon.ico') {
		 res.writeHead(200, {'Content-Type': 'image/x-icon'} );
		 frontendRequestCounter.inc({ method: req.method, route: '/favicon.ico', status_code: '200' });
		 res.end();
		 console.log('favicon requested');
	    }
	else
	{
		const routeLabel = req.method === 'POST' ? '/submit' : '/';
		res.writeHead(200, {'Content-Type': 'text/html'});
		frontendRequestCounter.inc({ method: req.method, route: routeLabel, status_code: '200' });
	
		var fileContents = fs.readFileSync('./public/default.css', {encoding: 'utf8'});
		res.write(header);
		res.write('<style>' + fileContents + '</style>');
		res.write(body);
		res.write(submitButton);

		const http = require('http');
		var timeout = 0
		
		// If POST, try saving the new recipe first (then still showing the existing recipes).
		//********************************************************
		if (req.method === 'POST') {

			timeout = 2000

			//Get the POST data
			//------------------------------
			var myJSONObject = {};
			var qs = require('querystring');

			let body = '';
			req.on('data', chunk => {
				body += chunk.toString();
			});
			req.on('end', () => {
				
				var post = qs.parse(body);
				myJSONObject["name"]=post["name"]
				myJSONObject["ingredients"]=post["ingredients"].split(',');
				myJSONObject["prepTimeInMinutes"]=post["prepTimeInMinutes"]
				
				//Send the data to the WS.
				//------------------------------
				const options = {
				  hostname: global.gConfig.webservice_host,
				  port: global.gConfig.webservice_port,
				  path: '/recipe',
				  method: 'POST',
				  json: true,   // <--Very important!!!
				};

				const req2 = http.request(options, (resp) => {
				  let data = '';

				  resp.on('data', (chunk) => {
					data += chunk;
				  });

				  resp.on('end', () => {
					//TODO: Check that there were no problems with the saving.
					console.log("Data Saved!");

					//res.write('<div id="space"></div>');
					//res.write('<div id="logo">New recipe saved successfully! </div>');
					//res.write('<div id="space"></div>');
					  });
				});
				req2.on('error', () => {
					console.log("Backend save request failed.");
				});
				req2.setHeader('content-type', 'application/json');
				req2.write(JSON.stringify(myJSONObject));	
				req2.end();
			});
					
		}
		//else
		//********************************************************			
		{
			//TODO: Check that there were no problems with the saving.
			if (req.method === 'POST') {
					res.write('<div id="space"></div>');
					res.write('<div id="logo">New recipe saved successfully! </div>');
					res.write('<div id="space"></div>');
			}

			//TODO: For simplicity, I opted for a timeout to wait for the save to be completed before reading the recipes (so that the recently saved one is there!). Better sync mechanisms can be used, such as Promises (https://alvarotrigo.com/blog/wait-1-second-javascript/)
			setTimeout(function(){

				const options = {
				  hostname: global.gConfig.webservice_host,
				  port: global.gConfig.webservice_port,
				  path: '/recipes',
				  method: 'GET',
				};

				const req = http.request(options, (resp) => {
				  let data = '';

				  resp.on('data', (chunk) => {
					data += chunk;
				  });

				  resp.on('end', () => {
					try {
						const myArr = JSON.parse(data);
						renderRecipes(res, myArr);
					} catch (err) {
						renderRecipes(res, [], 'Recipes are temporarily unavailable.');
					}
				  });
				});
				req.on('error', () => {
					renderRecipes(res, [], 'Backend is temporarily unavailable. Please try again shortly.');
				});
				req.end();

			}, timeout);

		}//end of "else"
	}}
).listen(global.gConfig.exposedPort);
