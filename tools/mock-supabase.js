window.DGS_CONFIG = { supabaseUrl: 'https://test.supabase.co', supabaseKey: 'test-key' };
window.supabase = { createClient(){
  const db = {tickets:[], journal:[], evidence:[], settings:[], commissions:[]};
  const user = {id:'u1', email:'test@example.com'};
  let session = null; const listeners = [];
  const emit = () => listeners.forEach(f => f('X', session));
  const clone = x => JSON.parse(JSON.stringify(x));
  function qb(table){
    let op = 'select', payload = null, filters = [], maybe = false, range = null;
    const api = {
      select(){ return api; }, insert(p){ op = 'insert'; payload = p; return api; }, update(p){ op = 'update'; payload = p; return api; },
      delete(){ op = 'delete'; return api; }, upsert(p){ op = 'upsert'; payload = p; return api; },
      eq(k, v){ filters.push([k, v]); return api; }, range(a, b){ range = [a, b]; return api; },
      single(){ return api; }, maybeSingle(){ maybe = true; return api; },
      then(res, rej){ try{ res(exec()); }catch(e){ rej(e); } }
    };
    const match = x => filters.every(([k, v]) => x[k] === v);
    function exec(){
      const rows = db[table], now = new Date().toISOString();
      if(op === 'select'){ let r = rows.filter(match); if(range) r = r.slice(range[0], range[1] + 1); if(maybe) return {data:r[0] ? clone(r[0]) : null, error:null}; return {data:r.map(clone), error:null}; }
      if(op === 'insert'){ const row = Object.assign({id:crypto.randomUUID(), user_id:user.id, created_at:now}, clone(payload)); rows.push(row); return {data:clone(row), error:null}; }
      if(op === 'update'){ const r = rows.find(match); Object.assign(r, clone(payload)); return {data:clone(r), error:null}; }
      if(op === 'delete'){ db[table] = rows.filter(x => !match(x)); return {data:null, error:null}; }
      if(op === 'upsert'){ const i = rows.findIndex(x => x.user_id === payload.user_id); if(i >= 0) Object.assign(rows[i], payload); else rows.push(Object.assign({}, payload)); return {data:null, error:null}; }
    }
    return api;
  }
  window.__mockdb = db;
  return {
    from: qb,
    auth: {
      onAuthStateChange(f){ listeners.push(f); return {data:{subscription:{unsubscribe(){}}}}; },
      async getSession(){ return {data:{session}}; },
      async signInWithPassword({password}){ if(password !== 'test1234') return {error:{message:'Invalid login credentials'}}; session = {user}; setTimeout(emit, 0); return {error:null}; },
      async signOut(){ session = null; setTimeout(emit, 0); return {error:null}; }
    },
    storage: { from(){ return {
      async upload(){ return {error:null}; },
      async remove(){ return {error:null}; },
      async createSignedUrls(paths){ return {data:paths.map(p => ({path:p, signedUrl:'/icon-512.png'})), error:null}; }
    }; } }
  };
} };
