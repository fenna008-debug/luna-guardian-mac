import unittest,tempfile,sys
from pathlib import Path
from unittest.mock import patch
import backend as b
import handoff
class Routing(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.old=b.BASE;b.BASE=Path(self.temp.name)
 def tearDown(self):b.BASE=self.old;self.temp.cleanup()
 def test_smalltalk_stays_qwen(self):
  with patch.object(b,'chat',return_value={'answer':'我在这里。'}),patch.object(handoff,'submit') as submit:
   self.assertEqual(b.routed_chat('困了吗')['answer'],'我在这里。');submit.assert_not_called()
 def test_explicit_inspection_handoff(self):
  with patch.object(b,'chat',return_value={'answer':'{"is_action":true,"needs_tools":true,"reason":"需要修复程序","complexity":"high"}'}),patch.object(handoff,'submit',return_value={'answer':'已交接'}) as submit:
   self.assertEqual(b.routed_chat('帮我修复程序')['answer'],'已交接');submit.assert_called_once()
 def test_invalid_json_does_not_execute(self):
  with patch.object(b,'chat',side_effect=[{'answer':'do something'},{'answer':'普通回答'}]),patch.object(handoff,'submit') as submit:
   b.routed_chat('你能不能运行这个程序');submit.assert_not_called()
 def test_strings_not_booleans(self):
  with patch.object(b,'chat',side_effect=[{'answer':'{"is_action":"true","needs_tools":"true"}'},{'answer':'普通回答'}]),patch.object(handoff,'submit') as submit:
   b.routed_chat('你能不能运行这个程序');submit.assert_not_called()
 def test_screens_never_route(self):
  with patch.object(b,'chat',return_value={'answer':'屏幕回应'}),patch.object(handoff,'submit') as submit:
   b.dispatch('study',{'text':'帮我删除文件','app':'浏览器'})
   submit.assert_not_called()
if __name__=='__main__':unittest.main()
