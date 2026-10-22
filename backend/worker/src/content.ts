export function contentResponse(request:Request,pack:{version:number}):Response {
 if(request.method!=='GET'&&request.method!=='HEAD')return new Response(null,{status:405,headers:{Allow:'GET, HEAD'}});
 const headers={ETag:`"v${pack.version}"`,'Cache-Control':'public, max-age=3600'};
 if(request.headers.get('If-None-Match')===headers.ETag)return new Response(null,{status:304,headers});
 if(request.method==='HEAD')return new Response(null,{headers});
 return Response.json(pack,{headers});
}
