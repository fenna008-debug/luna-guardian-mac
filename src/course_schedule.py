"""Local course reminders from verified, private schedule data; no model decisions."""
from datetime import datetime,timedelta
from zoneinfo import ZoneInfo
import json,re
from html.parser import HTMLParser
class TableText(HTMLParser):
 def __init__(self):super().__init__();self.rows=[];self.row=[];self.cell=None
 def handle_starttag(self,tag,attrs):
  if tag=='tr':self.row=[]
  if tag in ('td','th'):self.cell=[]
  if tag=='br' and self.cell is not None:self.cell.append('\n')
 def handle_data(self,data):
  if self.cell is not None:self.cell.append(data)
 def handle_endtag(self,tag):
  if tag in ('td','th') and self.cell is not None:self.row.append(re.sub(r'[ \t\r\f\v]+',' ',''.join(self.cell)).strip());self.cell=None
  if tag=='tr' and self.row:self.rows.append(self.row);self.row=[]
def html_rows(raw):
 for enc in ('utf-8-sig','cp932','utf-16'):
  try:text=raw.decode(enc);break
  except UnicodeError:continue
 else:raise ValueError('表格编码暂不支持')
 if '<table' not in text.lower():raise ValueError('不是HTML表格')
 p=TableText();p.feed(text);return p.rows

def tick(base,app='',now=None):
 from handoff import read,write
 now=now or datetime.now(ZoneInfo('Asia/Tokyo'));now=now.astimezone(ZoneInfo('Asia/Tokyo'))
 cfg=read(base/'course-schedule.json',{})
 if not cfg.get('enabled'):return {}
 day=now.date().isoformat();state=read(base/'course-notifications.json',{})
 if state.get('day')!=day:state={'day':day,'sent':[]}
 sent=set(state['sent']);minute=now.hour*60+now.minute
 for i,c in enumerate(cfg.get('courses',[])):
  if day not in c['dates']:continue
  start=sum(int(v)*n for v,n in zip(c['start'].split(':'),(60,1)));end=sum(int(v)*n for v,n in zip(c['end'].split(':'),(60,1)))
  key=str(i);kind=None
  if start-10<=minute<start and key+'remind' not in sent:kind='remind';text='还有'+str(start-minute)+'分钟上课：'+c['name']+'。'+c['start']+'开始，'+c['room']+'。'
  elif start<=minute<end and re.search(r'王者|原神|崩坏|Minecraft|League of Legends|Dota|游戏',app,re.I) and key+'warn' not in sent:kind='warn';text='现在是'+c['name']+'的上课时间。先把游戏放下，认真听课。'+c['end']+'下课再玩。'
  if kind:
   state['sent'].append(key+kind);write(base/'course-notifications.json',state)
   return {'kind':kind,'text':text}
 return {}
def summary(base):
 from handoff import read
 cfg=read(base/'course-schedule.json',{})
 if not cfg.get('courses'):return '还没有已核实的课表。'
 return '已保存的课表，均为日本时间；课前十分钟提醒：\n'+'\n'.join(c['weekday']+' '+c['start']+'—'+c['end']+' '+c['name']+'；'+c['room'] for c in cfg['courses'])+'\n按照已核对的学校授课日运行；临时停课或补课需要另行更新。'
