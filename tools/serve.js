// Static server for local testing: node tools/serve.js <folder> [port]
const http = require('http'), fs = require('fs'), path = require('path');
const root = path.resolve(process.argv[2] || 'test-build'), port = Number(process.argv[3] || 5179);
const types = {'.html':'text/html; charset=utf-8', '.js':'text/javascript', '.css':'text/css; charset=utf-8', '.png':'image/png',
  '.jpg':'image/jpeg', '.svg':'image/svg+xml', '.webmanifest':'application/manifest+json', '.ttf':'font/ttf', '.txt':'text/plain; charset=utf-8'};
http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if(p.endsWith('/')) p += 'index.html';
  const f = path.join(root, path.normalize(p));
  if(!f.startsWith(root)){ res.writeHead(403); return res.end(); }
  fs.readFile(f, (err, data) => {
    if(err){ res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, {'Content-Type': types[path.extname(f)] || 'application/octet-stream'});
    res.end(data);
  });
}).listen(port, () => console.log('http://localhost:' + port + '/  (' + root + ')'));
