/* Local-only photo storage: no fetch, upload or remote inference. */
(() => {
  let database;
  async function db() {
    if(database)return database;
    database=await new Promise((resolve,reject)=>{
      const r=indexedDB.open('mikro-local-v2',1);
      r.onupgradeneeded=()=>{for(const name of ['state','features','media'])r.result.createObjectStore(name);};
      r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);
    });return database;
  }
  const result=r=>new Promise((resolve,reject)=>{r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
  const done=tx=>new Promise((resolve,reject)=>{tx.oncomplete=resolve;tx.onabort=()=>reject(tx.error||Error('Local transaction aborted.'));tx.onerror=()=>reject(tx.error);});
  window.mikroReadState=async()=>{
    const d=await db(),tx=d.transaction(['state','features'],'readonly');
    const meta=await result(tx.objectStore('state').get('state'));if(!meta)return '';
    const store=tx.objectStore('features'),[keys,values]=await Promise.all([result(store.getAllKeys()),result(store.getAll())]);
    return JSON.stringify({...JSON.parse(meta),features:Object.fromEntries(keys.map((k,i)=>[k,JSON.parse(values[i])]))});
  };
  window.mikroWriteState=async(meta,patch,removed)=>{
    const d=await db(),tx=d.transaction(['state','features'],'readwrite'),complete=done(tx);
    tx.objectStore('state').put(meta,'state');const store=tx.objectStore('features');
    for(const [id,value] of Object.entries(JSON.parse(patch)))store.put(value,id);
    for(const id of JSON.parse(removed))store.delete(id);await complete;
  };
  window.mikroMedia=async()=>{
    const d=await db(),tx=d.transaction(['state','media'],'readonly');
    const mode=await result(tx.objectStore('state').get('imported')),values=await result(tx.objectStore('media').getAll());
    return JSON.stringify({imported:!!mode,items:values.map(({data,thumbnail,...meta})=>meta)});
  };
  window.mikroThumbnail=async id=>{
    const d=await db(),entry=await result(d.transaction('media').objectStore('media').get(id));
    if(!entry)throw Error('Imported photo is unavailable.');return new Uint8Array(entry.thumbnail);
  };
  window.mikroImport=async()=>{
    const input=document.createElement('input');input.type='file';input.multiple=true;input.accept='image/jpeg,image/png,image/webp';
    const files=await new Promise(resolve=>{input.onchange=()=>resolve([...input.files]);input.oncancel=()=>resolve([]);input.click();});
    let added=0,skipped=0;
    for(const file of files){
      if(file.size>32*1024*1024){skipped++;continue;}
      try{
        const bitmap=await createImageBitmap(file),scale=Math.min(1,1024/Math.max(bitmap.width,bitmap.height));
        const canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(bitmap.width*scale));canvas.height=Math.max(1,Math.round(bitmap.height*scale));
        canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);
        const thumbnail=await new Promise(resolve=>canvas.toBlob(resolve,'image/jpeg',.94));
        const data=await file.arrayBuffer(),digest=await crypto.subtle.digest('SHA-256',data),id=crypto.randomUUID();
        const entry={id,width:bitmap.width,height:bitmap.height,bytes:file.size,created:file.lastModified||Date.now(),
          hash:[...new Uint8Array(digest)].map(x=>x.toString(16).padStart(2,'0')).join(''),data,thumbnail:await thumbnail.arrayBuffer()};bitmap.close();
        const d=await db(),tx=d.transaction(['media','state'],'readwrite'),complete=done(tx);
        tx.objectStore('media').put(entry,id);tx.objectStore('state').put(true,'imported');await complete;added++;
      }catch(_){skipped++;}
    }return JSON.stringify({added,skipped});
  };
  window.mikroDelete=async raw=>{
    const d=await db(),deleted=[];
    for(const id of JSON.parse(raw)){
      const tx=d.transaction('media','readwrite'),complete=done(tx),store=tx.objectStore('media'),entry=await result(store.get(id));
      if(entry){store.delete(id);deleted.push(id);}await complete;
    }return JSON.stringify(deleted);
  };
})();
