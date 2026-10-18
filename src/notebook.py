"""Local, editable user-approved memories and tasks; no model/embedding daemon."""
import sqlite3,time,os,re

def connect(base):
 path=base/'notebook.sqlite';db=sqlite3.connect(path,timeout=3);db.row_factory=sqlite3.Row
 db.execute('CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY,kind TEXT NOT NULL,text TEXT NOT NULL,status TEXT NOT NULL,created REAL NOT NULL,updated REAL NOT NULL)');os.chmod(path,0o600)
 columns={r[1] for r in db.execute('PRAGMA table_info(notes)')}
 for name,decl in [('source',"TEXT NOT NULL DEFAULT '旧版保存（原始来源未记录）'"),('last_used','REAL'),('used_version','REAL')]:
  if name not in columns:db.execute('ALTER TABLE notes ADD COLUMN '+name+' '+decl)
 db.commit();return db

def manage(base,p):
 kind=p.get('kind','memory');action=p.get('op','list')
 if kind not in ('memory','task'):raise ValueError('未知记录类型')
 with connect(base) as db:
  if action=='list':return {'items':[dict(r) for r in db.execute('SELECT * FROM notes WHERE kind=? ORDER BY updated DESC LIMIT 100',(kind,))]}
  if action=='add':
   text=str(p.get('text','')).strip()[:1500]
   if not text:raise ValueError('内容不能为空')
   if re.search(r'sk-[A-Za-z0-9]{12,}|-----BEGIN .*PRIVATE KEY|(?:密码|api.?key|密钥)\s*[:：=]',text,re.I):raise ValueError('请不要把密码或 API 密钥存入记忆')
   existing=db.execute('SELECT id FROM notes WHERE kind=? AND text=?',(kind,text)).fetchone()
   if existing:return {'id':existing['id'],'saved':True,'duplicate':True}
   now=time.time();cur=db.execute('INSERT INTO notes(kind,text,status,created,updated) VALUES(?,?,?,?,?)',(kind,text,'pending' if kind=='task' else 'saved',now,now));db.execute('UPDATE notes SET source=? WHERE id=?',(p.get('source','你在记忆面板手动保存'),cur.lastrowid));return {'id':cur.lastrowid,'saved':True}
  ident=int(p.get('id',0))
  if action=='delete':
   cur=db.execute('DELETE FROM notes WHERE id=? AND kind=?',(ident,kind));return {'deleted':cur.rowcount==1}
  if action=='update':
   status=p.get('status','pending')
   if status not in ('pending','in_progress','done','saved'):raise ValueError('未知状态')
   text=str(p.get('text','')).strip()[:1500]
   if text and re.search(r'sk-[A-Za-z0-9]{12,}|-----BEGIN .*PRIVATE KEY|(?:密码|api.?key|密钥)\s*[:：=]',text,re.I):raise ValueError('请不要把密码或 API 密钥存入记忆')
   if text:cur=db.execute('UPDATE notes SET text=?,status=?,updated=? WHERE id=? AND kind=?',(text,status,time.time(),ident,kind))
   else:cur=db.execute('UPDATE notes SET status=?,updated=? WHERE id=? AND kind=?',(status,time.time(),ident,kind))
   changed=cur.rowcount==1
   if changed:db.execute('UPDATE notes SET source=? WHERE id=?',('你在记忆面板修改',ident))
   return {'updated':changed}
  raise ValueError('未知操作')

def context(base,query=''):
 with connect(base) as db:
  rows=db.execute("SELECT * FROM notes WHERE kind='memory' OR status!='done' ORDER BY updated DESC LIMIT 100").fetchall()
 def score(row):
  value=row['text'].lower();q=query.lower();pairs={q[i:i+2] for i in range(max(0,len(q)-1))}
  return sum(1 for pair in pairs if pair in value)+(1 if row['kind']=='task' else 0)
 selected=sorted(rows,key=score,reverse=True)[:6]
 lines=[];used=[];remaining=1400
 for r in selected:
  line=f"{r['kind']} [{r['status']}]: {r['text']}"
  if len(line)>remaining:continue
  lines.append(line);used.append(r);remaining-=len(line)+1
 with connect(base) as db:
  for r in used:db.execute('UPDATE notes SET last_used=?,used_version=? WHERE id=? AND updated=?',(time.time(),r['updated'],r['id'],r['updated']))
 return '\n'.join(lines)


def remember_region(base,message):
 # Only direct first-person declarations; no OCR, inference or travel plans.
 m=re.fullmatch(r'(?:请记住[：:,， ]*)?我(?:的(?:常住)?地区是|(?:现在|目前)?(?:住在|在)|(?:现在|目前)的所在地是|的城市是)\s*([\u3400-\u9fffA-Za-z・ー ]{2,30})[。！! ]*',message.strip())
 if not m:return None
 region=m.group(1).strip()
 if re.search(r'以前|曾经|打算|想|可能|如果|不是|不在|朋友|吗|哪里|哪儿|什么',region):return None
 if not re.search(r'[市区县県都府省州郡町村]$',region) and region not in ('大阪','东京','東京','京都','北京','上海','香港','台北','臺北'):return None
 with connect(base) as db:
  now=time.time();text='用户常住地区：'+region
  row=db.execute("SELECT id FROM notes WHERE kind='memory' AND text LIKE '用户常住地区：%' ORDER BY updated DESC LIMIT 1").fetchone()
  if row:db.execute('UPDATE notes SET text=?,updated=? WHERE id=?',(text,now,row['id']))
  else:db.execute('INSERT INTO notes(kind,text,status,created,updated) VALUES(?,?,?,?,?)',('memory',text,'saved',now,now))
  db.execute("UPDATE notes SET source=? WHERE kind='memory' AND text=?",('你明确告知常住地区：'+message,text))
 return region
