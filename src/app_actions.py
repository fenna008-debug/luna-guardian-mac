"""Request only explicit allowlisted native app controls from the running Guardian."""
import time,uuid,json
from pathlib import Path
from session_controls import write

def music(base,action,timeout=12,query="",artist=""):
 if action not in ('play','pause','next','previous','search_play'):raise ValueError('不支持的音乐操作')
 if action=='search_play':
  if not query.strip() or len(query)>120 or len(artist)>80:raise ValueError('请提供简短的歌名与歌手')
  timeout=max(timeout,40)
 folder=Path(base)/'app-requests';folder.mkdir(mode=0o700,exist_ok=True)
 ident=uuid.uuid4().hex;request=folder/(ident+'.json');response=folder/(ident+'.result.json')
 expires=time.time()+timeout
 write(request,{'action':action,'expires':expires,'query':query,'artist':artist})
 try:
  while time.time()<expires:
   if response.exists():
    return json.loads(response.read_text())['answer']
   time.sleep(.15)
  return '露娜本机没有及时返回音乐操作结果，尚未确认成功。请确认桌宠正在运行。'
 finally:
  request.unlink(missing_ok=True);response.unlink(missing_ok=True)
