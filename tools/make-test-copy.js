// Builds test-build/: a copy of the site that talks to an in-memory mock instead of the real Supabase.
// Usage: node tools/make-test-copy.js   then   node tools/serve.js test-build 5179
const fs = require('fs'), path = require('path');
const repo = path.resolve(__dirname, '..'), out = path.join(repo, 'test-build');
const skip = new Set(['.git', '.github', 'tools', 'test-build', 'supabase', 'node_modules']);
fs.rmSync(out, {recursive:true, force:true});
fs.mkdirSync(out);
for(const name of fs.readdirSync(repo)){
  if(skip.has(name) || name.endsWith('.md')) continue;
  fs.cpSync(path.join(repo, name), path.join(out, name), {recursive:true});
}
let html = fs.readFileSync(path.join(repo, 'index.html'), 'utf8');
const before = html;
html = html.replace(/<script src="config\.js"><\/script>\s*/, '')
  .replace(/<script src="https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@[^"]+"><\/script>/, '<script src="mock-supabase.js"></script>');
if(html === before || !html.includes('mock-supabase.js')) throw new Error('Could not swap the Supabase scripts in index.html');
fs.writeFileSync(path.join(out, 'index.html'), html);
fs.copyFileSync(path.join(__dirname, 'mock-supabase.js'), path.join(out, 'mock-supabase.js'));
console.log('test-build ready. Log in with any e-mail and password test1234.');
