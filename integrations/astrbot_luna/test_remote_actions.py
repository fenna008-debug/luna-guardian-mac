import json,sys,tempfile,types,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'src'))
import backend,notebook,handoff
import remote_actions as remote

class RemoteActionsTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.base=Path(self.tmp.name);self.old=backend.BASE;backend.BASE=self.base
 def tearDown(self):backend.BASE=self.old;self.tmp.cleanup()
 def call(self,text,ident=''):return remote.handle(text,backend,ident)
 def test_help_and_unknown(self):
  self.assertIn('办得怎么样了',self.call('功能菜单'));self.assertIsNone(self.call('你好'))
 def test_memory_edit_and_forget(self):
  r=notebook.manage(self.base,{'kind':'memory','op':'add','text':'喜欢茶','source':'test'})
  self.assertIn('喜欢茶',self.call('查看记忆'))
  self.assertIn('已修改',self.call(f"修改记忆 {r['id']}：喜欢红茶"))
  self.assertIn('喜欢红茶',self.call('查看记忆'))
  self.assertIn('已删除',self.call(f"忘记记忆 {r['id']}"))
  self.assertIn('目前为空',self.call('查看记忆'))
 def test_task_completion_is_only_a_record(self):
  r=notebook.manage(self.base,{'kind':'task','op':'add','text':'整理文章'})
  self.assertIn('整理文章',self.call('我的待办'))
  self.assertIn('不代表露娜执行过',self.call(f"完成待办 {r['id']}"))
  self.assertIn('重新放回',self.call(f"重新打开待办 {r['id']}"))
 def test_request_id_prevents_duplicate_execution(self):
  with patch.object(handoff,'submit',return_value={'handoff':{'id':'a'*32}}) as submit:
   first=self.call('交给Codex：写一个文件','event-1')
   self.assertEqual(first,self.call('交给Codex：写一个文件','event-1'))
   submit.assert_called_once()
 def test_queries_do_not_cancel_desktop_jobs(self):
  handoff.write(self.base/'remote-codex.json',{'id':'a'*32});(self.base/'codex-jobs').mkdir()
  handoff.write(self.base/'codex-status.json',{'id':'b'*32,'state':'running'})
  self.assertIn('没有停止其他桌面任务',self.call('取消Codex任务'))
  self.assertFalse((self.base/'codex-jobs'/('b'*32)/'cancel.json').exists())
 def test_remote_result_survives_next_desktop_job(self):
  ident='a'*32;job=self.base/'codex-jobs'/ident;job.mkdir(parents=True)
  handoff.write(self.base/'remote-codex.json',{'id':ident});handoff.write(job/'result.json',{'state':'completed','summary':'真实结果'})
  handoff.write(self.base/'codex-status.json',{'id':'b'*32,'summary':'桌面私人任务'})
  answer=self.call('Codex结果');self.assertIn('真实结果',answer);self.assertNotIn('桌面私人',answer)
 def test_cancel_only_assigned_job(self):
  ident='a'*32;(self.base/'codex-jobs'/ident).mkdir(parents=True)
  handoff.write(self.base/'remote-codex.json',{'id':ident});handoff.write(self.base/'codex-status.json',{'id':ident,'state':'running'})
  self.assertIn('已请求停止',self.call('取消Codex任务'));self.assertTrue((self.base/'codex-jobs'/ident/'cancel.json').exists())
 def test_fortune_does_not_redraw(self):
  backend.save('fortune.json',{'date':remote.day(),'title':'中吉','text':'慢慢来'})
  before=(self.base/'fortune.json').read_bytes()
  self.assertIn('中吉',self.call('今日运势'));self.assertEqual(before,(self.base/'fortune.json').read_bytes())
  backend.save('fortune.json',{'date':'2000-01-01','title':'旧签'})
  self.assertIn('还没有抽签',self.call('今日运势'))
 def test_day_at_four(self):
  from datetime import datetime,timezone,timedelta
  zone=timezone(timedelta(hours=9))
  self.assertEqual(remote.day(datetime(2026,10,18,3,59,tzinfo=zone).timestamp()),'2026-10-17')
  self.assertEqual(remote.day(datetime(2026,10,18,4,0,tzinfo=zone).timestamp()),'2026-10-18')
 def test_search_failure_not_hallucinated(self):
  with patch('web_tools.search',side_effect=ValueError):self.assertIn('没有取得',self.call('搜索：茶'))
 def test_no_task_from_negation_or_quoted_reference(self):
  with patch.object(handoff,'submit') as submit:
   self.assertIsNone(self.call('不要交给Codex：写文件'))
   self.assertIsNone(self.call('别人说“交给Codex：写文件”'))
   submit.assert_not_called()

 def test_natural_file_request_delegates_but_advice_does_not(self):
  with patch.object(handoff,'submit',return_value={'handoff':{'id':'a'*32}}) as submit,patch.object(backend,'chat',return_value={'answer':'{"is_action":true,"needs_tools":true,"route":"task","confidence":0.96}'}):
   self.assertIn('交给 Codex',self.call('帮我写一个整理文件的脚本'))
   self.assertIsNone(self.call('比如帮我写一个整理文件的脚本'))
   self.assertIsNone(self.call('不要帮我修改代码'))
   submit.assert_called_once()
