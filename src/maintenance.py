"""Small maintenance step on existing metrics timer; no extra resident process."""
import time
from datetime import datetime,timedelta

def tick(load,save):
 now=time.time();last=load('maintenance.json',{})
 if now-last.get('at',0)<900:return
 rows=load('tool-events.json',{}).get('items',[])
 save('tool-events.json',{'items':[r for r in rows if r.get('at',0)>now-7*86400][:100]})
 epoch=load('context-window.json',{});day=(datetime.now()-timedelta(hours=4)).date().isoformat()
 if epoch.get('day')!=day or (epoch.get('lastAt',0)>0 and now-epoch['lastAt']>21600):
  save('context-window.json',{'day':day,'start':len(load('chat.json',[])),'lastAt':now,'resetAt':now})
 save('maintenance.json',{'at':now,'toolRetentionDays':7,'contextRounds':3})
