
const CONFIG_KEY = 'pesticide-erp-supabase-config-v1';
const SHOP_KEY = 'pesticide-erp-shop-id-v1';
const TABLES = ['companies','products','customers','sales','payments','purchases','suppliers','expenses','movements','settings','users'];
let client = null;
let createClientFactory = null;
let currentUser = null;
let syncBusy = false;

function readConfig(){ try{return JSON.parse(localStorage.getItem(CONFIG_KEY)||'null')}catch{return null} }
async function makeClient(){
  const c=readConfig();
  if(!c?.url||!c?.key) throw new Error('Save your Supabase project URL and public anon/publishable key first.');
  if(!client){
    if(!createClientFactory){const mod=await import('https://esm.sh/@supabase/supabase-js@2');createClientFactory=mod.createClient;}
    client=createClientFactory(c.url,c.key,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
  }
  return client;
}
function localDb(){return new Promise((resolve,reject)=>{const r=indexedDB.open('PesticideShopERP',2);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)})}
function requestAll(store){return new Promise((resolve,reject)=>{const r=store.getAll();r.onsuccess=()=>resolve(r.result||[]);r.onerror=()=>reject(r.error)})}
function txDone(tx){return new Promise((resolve,reject)=>{tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error||new Error('Local database transaction aborted'))})}
async function getOutbox(){const db=await localDb();const tx=db.transaction('sync_outbox','readonly');const rows=await requestAll(tx.objectStore('sync_outbox'));db.close();return rows.sort((a,b)=>a.changedAt.localeCompare(b.changedAt))}
async function removeOutboxIfUnchanged(item){const db=await localDb();const tx=db.transaction('sync_outbox','readwrite');const store=tx.objectStore('sync_outbox');const r=store.get(item.id);r.onsuccess=()=>{if(r.result?.changedAt===item.changedAt)store.delete(item.id)};await txDone(tx);db.close()}
async function applyCloudRows(rows){
  const db=await localDb();
  window.__cloudApplying=true;
  try{
    for(const row of rows||[]){
      if(!TABLES.includes(row.table_name)) continue;
      const outboxTx=db.transaction('sync_outbox','readonly');
      const pending=await new Promise((resolve,reject)=>{const r=outboxTx.objectStore('sync_outbox').get(row.table_name+':'+row.record_id);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
      if(pending) continue; // Never overwrite a newer unsent local edit.
      const tx=db.transaction(row.table_name,'readwrite');
      if(row.deleted_at) tx.objectStore(row.table_name).delete(row.record_id);
      else tx.objectStore(row.table_name).put(row.payload);
      await txDone(tx);
    }
  } finally {window.__cloudApplying=false;db.close()}
}
async function localCounts(){const db=await localDb();const out={};for(const t of TABLES){const tx=db.transaction(t,'readonly');out[t]=(await requestAll(tx.objectStore(t))).length}db.close();return out}
async function queueAllLocal(){
  const db=await localDb();
  for(const t of TABLES){
    const read=db.transaction(t,'readonly');const rows=await requestAll(read.objectStore(t));
    for(const row of rows){const tx=db.transaction('sync_outbox','readwrite');tx.objectStore('sync_outbox').put({id:t+':'+row.id,table:t,recordId:row.id,payload:row,deleted:false,changedAt:new Date().toISOString()});await txDone(tx)}
  }
  db.close();
}
async function activeShop(){
  const c=await makeClient();
  let shopId=localStorage.getItem(SHOP_KEY);
  const {data,error}=await c.rpc('my_shops');
  if(error) throw error;
  if(!data?.length) return null;
  if(!shopId||!data.some(x=>x.shop_id===shopId)){shopId=data[0].shop_id;localStorage.setItem(SHOP_KEY,shopId)}
  return data.find(x=>x.shop_id===shopId)||data[0];
}
async function sync(){
  if(syncBusy) return {message:'A sync is already running.'};
  if(!navigator.onLine) throw new Error('You are offline. Changes are safely queued on this device and will sync when internet returns.');
  syncBusy=true;
  try{
    const c=await makeClient();
    const {data:{user},error:authErr}=await c.auth.getUser();
    if(authErr||!user) throw new Error('Sign in to your shop account before syncing.');
    const shop=await activeShop();
    if(!shop) throw new Error('No shop is linked to this account. The owner must create a shop or add this account as a team member.');
    const shopId=shop.shop_id;
    const queue=await getOutbox();let pushed=0;
    for(const item of queue){
      if(!TABLES.includes(item.table)) continue;
      const {error}=await c.rpc('sync_upsert_record',{p_shop_id:shopId,p_table_name:item.table,p_record_id:item.recordId,p_payload:item.payload,p_is_deleted:item.deleted});
      if(error) throw new Error(`Sync stopped at ${item.table}/${item.recordId}: ${error.message}`);
      await removeOutboxIfUnchanged(item);pushed++;
    }
    const {data:rows,error}=await c.rpc('sync_pull_records',{p_shop_id:shopId});
    if(error) throw error;
    await applyCloudRows(rows||[]);
    const remaining=(await getOutbox()).length;
    return {message:`Synced ${pushed} local change(s); received ${rows?.length||0} cloud record(s). ${remaining} change(s) remain queued.`,shop:shop.shop_name,role:shop.role};
  } finally {syncBusy=false}
}

const api={
  config:()=>readConfig(),
  async configure(url,key){if(!/^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(url))throw new Error('Enter a valid Supabase project URL, such as https://xxxx.supabase.co');if(!key||key.length<20)throw new Error('Enter the public anon/publishable key.');localStorage.setItem(CONFIG_KEY,JSON.stringify({url,key}));client=null;await makeClient();return true},
  async status(){const cfg=readConfig();if(!cfg)return {configured:false,online:navigator.onLine};try{const c=await makeClient();const {data:{session}}=await c.auth.getSession();currentUser=session?.user||null;let shop=null;if(currentUser){try{shop=await activeShop()}catch{}}return {configured:true,user:currentUser,shop,online:navigator.onLine}}catch{return {configured:false,online:navigator.onLine}}},
  async signUp(email,password){if(!email||!password||password.length<8)throw new Error('Enter a valid email and a password of at least 8 characters.');const c=await makeClient();const {data,error}=await c.auth.signUp({email,password});if(error)throw error;return {message:data.session?'Account created and signed in.':'Account created. Verify your email, then sign in.'}},
  async signIn(email,password){const c=await makeClient();const {data,error}=await c.auth.signInWithPassword({email,password});if(error)throw error;currentUser=data.user;const shop=await activeShop();window.erpSetUser?.(data.user,shop?.role||'Owner');if(shop&&navigator.onLine)await sync();return data.user},
  async signOut(){const c=await makeClient();const {error}=await c.auth.signOut();if(error)throw error;currentUser=null;window.erpSetUser?.(null,'Local mode');},
  async createShop(name){if(!name)throw new Error('Enter your shop name.');const c=await makeClient();const {data:{user}}=await c.auth.getUser();if(!user)throw new Error('Sign in first.');const {data,error}=await c.rpc('create_shop_and_owner',{p_shop_name:name});if(error)throw error;localStorage.setItem(SHOP_KEY,data);window.erpSetUser?.(user,'owner');await queueAllLocal();return data},
  async addMember(email,role){if(!email)throw new Error('Enter the staff member email.');const c=await makeClient();const {error}=await c.rpc('invite_shop_member',{p_email:email,p_role:role});if(error)throw error;},
  sync,
  async setShop(shopId){localStorage.setItem(SHOP_KEY,shopId);return sync()}
};
window.cloudERP=api;

window.addEventListener('online',()=>{if(readConfig())sync().then(r=>console.info('[ERP sync]',r.message)).catch(e=>console.warn('[ERP sync]',e.message))});
let syncTimer=null;
window.addEventListener('erp:local-change',()=>{if(syncTimer)clearTimeout(syncTimer);if(navigator.onLine&&readConfig())syncTimer=setTimeout(()=>sync().catch(e=>console.warn('[ERP sync]',e.message)),1200)});

// Restore auth state and synchronize in the background after a previously authenticated app comes online.
(async()=>{
  try{
    const c=readConfig()?await makeClient():null;
    if(c){
      c.auth.getSession().then(({data})=>{currentUser=data.session?.user||null;if(currentUser){activeShop().then(shop=>window.erpSetUser?.(currentUser,shop?.role||'Owner')).catch(()=>{});if(navigator.onLine)sync().catch(e=>console.warn('[ERP sync]',e.message))}});
      c.auth.onAuthStateChange((_event,session)=>{currentUser=session?.user||null;if(currentUser){activeShop().then(shop=>window.erpSetUser?.(currentUser,shop?.role||'Owner')).catch(()=>{});if(navigator.onLine)setTimeout(()=>sync().catch(e=>console.warn('[ERP sync]',e.message)),0)}else window.erpSetUser?.(null,'Local mode')});
    }
  }catch(e){console.warn('[ERP cloud]',e.message)}
})();
