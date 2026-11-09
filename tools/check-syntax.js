// Syntax check of the app's main inline <script> (the last one in index.html): node tools/check-syntax.js
const fs = require('fs'), path = require('path'), os = require('os'), {execFileSync} = require('child_process');
const html = fs.readFileSync(path.resolve(__dirname, '..', 'index.html'), 'utf8');
const start = html.lastIndexOf('<script>'), end = html.indexOf('</script>', start);
if(start < 0 || end < 0) throw new Error('Inline script not found');
const tmp = path.join(os.tmpdir(), 'dziennik-inline-check.js');
fs.writeFileSync(tmp, html.slice(start + '<script>'.length, end));
execFileSync(process.execPath, ['--check', tmp], {stdio:'inherit'});
console.log('Syntax OK');
