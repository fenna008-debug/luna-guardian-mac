"""Read-only public GitHub watcher. Never sends comments to an LLM or executes them."""
import json,time,urllib.request,urllib.parse,urllib.error
REPO='fenna008-debug/luna-guardian-mac'
ROOT='https://api.github.com/repos/'+REPO
PAGE='https://github.com/'+REPO
SOURCES={'issues':'新 Issue / PR','issues/comments':'Issue / PR 留言','pulls/comments':'代码评审留言','comments':'提交留言'}
class NoRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,*args,**kwargs):return None

def fetch(path):
 # All endpoints are fixed in this module, no tokens or user-controlled hosts.
 request=urllib.request.Request(ROOT+path,headers={'Accept':'application/vnd.github+json','User-Agent':'LunaGuardian-repository-watch','X-GitHub-Api-Version':'2022-11-28'})
 with urllib.request.build_opener(NoRedirect()).open(request,timeout=7) as response:
  raw=response.read(2_000_001);link=response.headers.get('Link','')
 if len(raw)>2_000_000:raise ValueError('GitHub response too large')
 return json.loads(raw),link

def recent(source,get):
 query='?per_page=100'+('&state=all&sort=created&direction=desc' if source=='issues' else '&sort=created&direction=desc' if source!='comments' else '')
 rows,links=get('/'+source+query)
 if not isinstance(rows,list):raise ValueError('Invalid GitHub list')
 # Commit comments are oldest first. Retrieve the final page, rather than
 # silently stopping at the oldest 100 comments. No arbitrary Link URL fetch.
 if source=='comments' and 'rel="last"' in links:
  import re
  match=re.search(r'<([^>]+)>; rel="last"',links)
  if match:
   page=int(urllib.parse.parse_qs(urllib.parse.urlsplit(match.group(1)).query)['page'][0])
   rows,_=get('/comments?per_page=100&page='+str(page))
   if page>1:
    prior,_=get('/comments?per_page=100&page='+str(page-1));rows=prior+rows
 return rows

def tick(load,save,get=fetch,now=None):
 now=time.time() if now is None else now
 state=load('github-watch.json',{});pending=state.get('pending',[])
 if now<state.get('next',0):return {'pending':pending,'checked':state.get('checked'),'error':state.get('error')}
 state['next']=now+900;errors=[]
 def add(ident,text,url=PAGE):
  if any(r['id']==ident for r in pending):return
  pending.append({'id':ident,'text':text,'url':url,'at':now})
 try:
  repo,_=get('');stars=int(repo['stargazers_count'])
  if 'stars' in state and stars>state['stars']:add('stars:'+str(now),f'仓库的 Star 增加了 {stars-state["stars"]} 个，现在有 {stars} 个。有人在关注我们呢。')
  state['stars']=stars
 except Exception:errors.append('仓库统计暂未取得')
 cursors=state.setdefault('cursors',{})
 for source,label in SOURCES.items():
  try:
   rows=recent(source,get);ids=[int(r['id']) for r in rows];old=cursors.get(source)
   if old is not None:
    new=[r for r in rows if int(r['id'])>old]
    if new:add(source+':'+str(max(int(r['id']) for r in new)),f'仓库有 {len(new)} 条{label}，去 GitHub 看看吧。')
   cursors[source]=max(ids+[old or 0])
  except Exception:errors.append(label+'暂未取得')
 state['pending']=pending[-100:];state['checked']=now
 state['error']='；'.join(errors)
 state['failures']=min(4,state.get('failures',0)+1) if errors else 0
 if errors:state['next']=now+min(7200,900*2**state['failures'])
 save('github-watch.json',state)
 return {'pending':state['pending'],'checked':now,'error':state['error']}

def acknowledge(load,save,ids):
 state=load('github-watch.json',{});ack=set(str(x) for x in ids)
 rows=state.get('pending',[]);done=[r for r in rows if r['id'] in ack]
 log=load('github-watch-notifications.json',[]);save('github-watch-notifications.json',(done+log)[:100])
 state['pending']=[r for r in rows if r['id'] not in ack];save('github-watch.json',state)
 return {'acknowledged':len(done)}
