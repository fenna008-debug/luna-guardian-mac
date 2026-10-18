import tempfile,unittest
from pathlib import Path
from unittest.mock import Mock
from local_actions import handle
class LocalActionsTests(unittest.TestCase):
 def test_power_confirm_is_local_and_once(self):
  with tempfile.TemporaryDirectory() as d:
   r=Mock(return_value=Mock(returncode=0))
   self.assertIn('确认重启',handle('你能重启一下电脑吗',Path(d),runner=r));r.assert_not_called()
   self.assertIn('已向系统发送',handle('是的',Path(d),runner=r));r.assert_called_once()
   self.assertIsNone(handle('是的',Path(d),runner=r));r.assert_called_once()
 def test_no_implicit_power_or_false_success(self):
  with tempfile.TemporaryDirectory() as d:
   r=Mock(return_value=Mock(returncode=1))
   self.assertIsNone(handle('怎么关机',Path(d),runner=r));r.assert_not_called()
   handle('关机',Path(d),runner=r)
   self.assertIsNone(handle('是的',Path(d),'qq',runner=r));r.assert_not_called()
   self.assertIn('没有完成',handle('确认关机',Path(d),runner=r))
 def test_simple_actions(self):
  with tempfile.TemporaryDirectory() as d:
   r=Mock(return_value=Mock(returncode=0))
   self.assertIn('音量',handle('音量调到30',Path(d),runner=r))
   self.assertIn('打开计算器',handle('打开计算器',Path(d),runner=r))
