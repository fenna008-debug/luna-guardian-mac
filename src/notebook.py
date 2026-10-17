"""Local, editable user-approved memories and tasks; no model/embedding daemon."""
import sqlite3,time,os,re

def connect(base):
 path=base/'notebook.sqlite';db=sqlite3.connect(path,timeout=3);db.row_factory=sqlite3.Row
 db.execute('CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY,kind TEXT NOT NULL,text TEXT NOT NULL,status TEXT NOT NULL,created REAL NOT NULL,updated REAL NOT NULL)');os.chmod(path,0o600);return db

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
   now=time.time();cur=db.execute('INSERT INTO notes(kind,text,status,created,updated) VALUES(?,?,?,?,?)',(kind,text,'pending' if kind=='task' else 'saved',now,now));return {'id':cur.lastrowid,'saved':True}
  ident=int(p.get('id',0))
  if action=='delete':
   cur=db.execute('DELETE FROM notes WHERE id=? AND kind=?',(ident,kind));return {'deleted':cur.rowcount==1}
  if action=='update':
   status=p.get('status','pending')
   if status not in ('pending','in_progress','done','saved'):raise ValueError('未知状态')
   text=str(p.get('text','')).strip()[:1500]
   if text:cur=db.execute('UPDATE notes SET text=?,status=?,updated=? WHERE id=? AND kind=?',(text,status,time.time(),ident,kind))
   else:cur=db.execute('UPDATE notes SET status=?,updated=? WHERE id=? AND kind=?',(status,time.time(),ident,kind))
   return {'updated':cur.rowcount==1}
  raise ValueError('未知操作')

def context(base,query=''):
 with connect(base) as db:
  rows=db.execute("SELECT kind,text,status FROM notes WHERE kind='memory' OR status!='done' ORDER BY updated DESC LIMIT 100").fetchall()
 def score(row):
  value=row['text'].lower();q=query.lower();pairs={q[i:i+2] for i in range(max(0,len(q)-1))}
  return sum(1 for pair in pairs if pair in value)+(1 if row['kind']=='task' else 0)
 selected=sorted(rows,key=score,reverse=True)[:6]
 return '\n'.join(f"{r['kind']} [{r['status']}]: {r['text']}" for r in selected)[:1400]
