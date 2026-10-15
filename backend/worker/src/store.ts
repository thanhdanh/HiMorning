import type { Store, Transaction } from '../../functions/src/store.js';
export class DurableStore implements Store {
 constructor(private readonly storage:DurableObjectStorage){}
 async transaction<T>(operation:(tx:Transaction)=>Promise<T>):Promise<T> {
  return this.storage.transaction(async tx=>{
   const writes:Record<string,object>={};
   const value=await operation({
    get:async <U>(path:string)=>path in writes?structuredClone(writes[path]) as U:await tx.get<U>(path),
    set:(path,value)=>{writes[path]=structuredClone(value);},
   });
   if(Object.keys(writes).length)await tx.put(writes);
   return value;
  });
 }
}
export async function cleanup(storage:DurableObjectStorage,now=Date.now()) {
 let after:string|undefined,next=Infinity;
 while(true){
  const records=await storage.list<{deleteAt:Date}>({limit:256,...(after?{startAfter:after}:{})});
  const expired:string[]=[];
  for(const [key,value] of records){
   const expiry=value.deleteAt?.getTime();
   if(expiry<=now)expired.push(key);else if(Number.isFinite(expiry))next=Math.min(next,expiry);
   after=key;
  }
  if(expired.length)await storage.delete(expired);
  if(records.size<256)break;
 }
 if(Number.isFinite(next))await storage.setAlarm(Math.max(now+1000,next));
}
