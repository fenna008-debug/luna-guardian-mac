import unittest,tempfile,time
from pathlib import Path
from unittest.mock import patch
import notebook,maintenance,backend as b
class NotebookTests(unittest.TestCase):
 def setUp(self):self.tmp=tempfile.TemporaryDirectory();self.base=Path(self.tmp.name)
 def tearDown(self):self.tmp.cleanup()
 def test_memory_roundtrip_and_dedup(self):
  r=notebook.manage(self.base,{'op':'add','kind':'memory','text':'我喜欢日本文学'})
  self.assertTrue(notebook.manage(self.base,{'op':'add','kind':'memory','text':'我喜欢日本文学'})['duplicate'])
  notebook.manage(self.base,{'op':'update','kind':'memory','id':r['id'],'text':'我喜欢唐话词汇','status':'saved'})
  self.assertIn('唐话',notebook.context(self.base,'唐话'))
  self.assertTrue(notebook.manage(self.base,{'op':'delete','kind':'memory','id':r['id']})['deleted'])
  self.assertEqual(notebook.manage(self.base,{'op':'list'})['items'],[])
 def test_task_not_implicitly_done(self):
  r=notebook.manage(self.base,{'op':'add','kind':'task','text':'核对论文'})
  self.assertEqual(notebook.manage(self.base,{'op':'list','kind':'task'})['items'][0]['status'],'pending')
  notebook.manage(self.base,{'op':'update','kind':'task','id':r['id'],'status':'done'})
  self.assertNotIn('核对论文',notebook.context(self.base))
 def test_reject_secret_memory(self):
  with self.assertRaises(ValueError):notebook.manage(self.base,{'op':'add','text':'密码：do-not-store'})
 def test_maintenance_preserves_memory_and_chat(self):
  store={'chat.json':[{'text':'visible history'}],'tool-events.json':{'items':[{'at':time.time()-9*86400},{'at':time.time()}]}}
  maintenance.tick(lambda k,d:store.get(k,d),lambda k,v:store.update({k:v}))
  self.assertEqual(len(store['tool-events.json']['items']),1)
  self.assertEqual(store['chat.json'][0]['text'],'visible history');self.assertEqual(store['context-window.json']['start'],1)
class RoutingPolicy(unittest.TestCase):
 def setUp(self):self.tmp=tempfile.TemporaryDirectory();self.old=b.BASE;b.BASE=Path(self.tmp.name)
 def tearDown(self):b.BASE=self.old;self.tmp.cleanup()
 def test_low_complexity_never_codex(self):
  with patch.object(b,'chat',side_effect=[{'answer':'{"is_action":true,"needs_tools":true,"complexity":"low"}'},{'answer':'普通建议'}]),patch('handoff.submit') as submit:
   b.routed_chat('帮我检查程序');submit.assert_not_called()
 def test_weather_uses_local_llm(self):
  with patch.object(b,'weather',return_value={'city':'大阪','current':{}}),patch.object(b,'chat',return_value={'answer':'大阪天气结果'}),patch('handoff.submit') as submit:
   self.assertEqual(b.routed_chat('今天天气怎么样')['answer'],'大阪天气结果');submit.assert_not_called()
  self.assertNotIn('tool',b.read('chat.json',[])[0])
  self.assertEqual(b.read('tool-events.json',{})['items'][0]['tool'],'日常查询')
 def test_explicit_memory_without_llm(self):
  with patch.object(b,'chat') as chat:
   b.routed_chat('记住：我偏爱简洁回答');chat.assert_not_called()
  self.assertIn('简洁回答',notebook.context(b.BASE))
