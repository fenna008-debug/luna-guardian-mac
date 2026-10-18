import sqlite3,tempfile,unittest
from datetime import datetime,timedelta,timezone
from pathlib import Path
import notebook,backend

class DailyMemoryTests(unittest.TestCase):
 def test_legacy_migration_and_recall_revision(self):
  with tempfile.TemporaryDirectory() as folder:
   base=Path(folder)
   with sqlite3.connect(base/'notebook.sqlite') as db:
    db.execute('CREATE TABLE notes(id INTEGER PRIMARY KEY,kind TEXT NOT NULL,text TEXT NOT NULL,status TEXT NOT NULL,created REAL NOT NULL,updated REAL NOT NULL)')
    db.execute("INSERT INTO notes VALUES(1,'memory','喜欢阅读','saved',1,1)")
   row=notebook.manage(base,{'op':'list'})['items'][0]
   self.assertEqual(row['created'],1);self.assertIn('旧版',row['source'])
   notebook.context(base,'阅读');row=notebook.manage(base,{'op':'list'})['items'][0]
   self.assertEqual(row['used_version'],row['updated']);self.assertIsNotNone(row['last_used'])
   notebook.manage(base,{'op':'update','id':1,'text':'喜欢画画','status':'saved'})
   row=notebook.manage(base,{'op':'list'})['items'][0];self.assertNotEqual(row['used_version'],row['updated'])
   notebook.context(base,'画画');row=notebook.manage(base,{'op':'list'})['items'][0];self.assertEqual(row['used_version'],row['updated'])
 def test_reading_boundary_does_not_filter_memory_or_fortune(self):
  zone=timezone(timedelta(hours=9));stamp=lambda h,m:datetime(2026,10,18,h,m,tzinfo=zone).timestamp()
  for name,key in [('reading-log.json','time'),('reading-comments.json','at')]:
   old={key:stamp(3,59)};new={key:stamp(4,0)}
   self.assertEqual(backend.reading_today(name,[old,new],stamp(4,0)),[new])
   self.assertEqual(backend.reading_today(name,[old],stamp(3,59)),[old])
  for name in ('fortune.json','chat.json'):
   data=[{'time':0}];self.assertEqual(backend.reading_today(name,data,stamp(4,0)),data)
 def test_internal_tool_text_is_not_execution(self):
  text='{"tool_name":"codex","arguments":{}}'
  self.assertNotIn('tool_name',backend.public_answer(text,'看看电脑状况'))
  self.assertEqual(backend.public_answer(text,'请展示JSON示例'),text)
