import unittest
from unittest.mock import Mock
from delegation import prepare,explicit
class DelegationTests(unittest.TestCase):
 def test_explicit_reference_keeps_channel_context(self):
  plan=prepare('这个交给codex干',[{'role':'user','text':'我想做一个统计茶叶库存的脚本。'},{'role':'assistant','text':'可以按品种汇总。'}])
  self.assertIn('茶叶库存',plan['task']);self.assertIn('本次用户要求',plan['task'])
 def test_reference_without_context_asks(self):
  self.assertIn('question',prepare('这个交给Codex做',[]))
 def test_specific_request_needs_no_old_history(self):
  self.assertIn('task',prepare('交给Codex：创建一个测试文件',[]))
 def test_negative_and_explanations_never_delegate(self):
  for s in ['不要交给codex干','如何调用Codex','别人说交给Codex做','比如交给Codex做']:
   self.assertFalse(explicit(s));self.assertIsNone(prepare(s,[],Mock()))
 def test_complexity_decision_requires_real_booleans(self):
  for value in ['{"is_action":"true","needs_tools":true,"complexity":"high"}','not json','[]']:
   self.assertIsNone(prepare('帮我修复这个程序',[],Mock(return_value={'answer':value})))
  self.assertIsNotNone(prepare('帮我修复这个程序',[],Mock(return_value={'answer':'{"is_action":true,"needs_tools":true,"complexity":"high"}'})))
 def test_smalltalk_never_calls_classifier(self):
  chat=Mock();self.assertIsNone(prepare('今天看什么书',[],chat));chat.assert_not_called()

class NaturalSendTests(unittest.TestCase):
    def test_qq_send_and_help(self):
        from delegation import explicit,prepare
        self.assertTrue(explicit('你根据课表来提醒我，把这个发给codex叫她修改你'))
        self.assertTrue(explicit('这个任务有困难就找codex帮助'))
        self.assertFalse(explicit('不要发给codex'))
        self.assertIsNotNone(prepare('把课表提醒发给codex修改',[],only_explicit=True))
