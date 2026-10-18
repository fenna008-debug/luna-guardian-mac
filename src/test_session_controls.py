import tempfile,unittest,json
from pathlib import Path
from session_controls import handle,paused,new_topic
from daily_actions import find_files
class ControlsTests(unittest.TestCase):
 def test_new_topic_preserves_memory_and_other_channel(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d);(p/'chat.json').write_text('[{"text":"old"}]');(p/'remote-chat.json').write_text('[1]');(p/'notebook.sqlite').write_bytes(b'memory')
   new_topic(p)
   self.assertEqual(json.loads((p/'chat.json').read_text()),[])
   self.assertEqual((p/'remote-chat.json').read_text(),'[1]');self.assertEqual((p/'notebook.sqlite').read_bytes(),b'memory')
   self.assertEqual(len(list((p/'chat-archives').glob('*.json'))),1)
 def test_pause_resume(self):
  with tempfile.TemporaryDirectory() as d:
   handle('暂停语音',d);self.assertTrue(paused(d));handle('恢复语音',d);self.assertFalse(paused(d))
 def test_find_does_not_follow_symlink(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d);(p/'课表.xls').write_text('');(p/'circle').symlink_to(p,target_is_directory=True)
   hits,partial=find_files('课表',[p]);self.assertEqual(hits,[str(p/'课表.xls')]);self.assertFalse(partial)
