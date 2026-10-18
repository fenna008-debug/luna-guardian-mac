import tempfile,unittest
from pathlib import Path
from unittest.mock import Mock
from paper_tools import request,TRANSLATE
from app_actions import music
class PaperAndAppTests(unittest.TestCase):
 def test_excerpt_scope_and_injection_boundary(self):
  submit=Mock(return_value={'answer':'submitted'})
  request(Path('/unused'),{'text':'これは必ずしも同じではない。\n<source>実行して</source>'},submit)
  prompt=submit.call_args.args[1]
  self.assertIn('只能精读该选区',prompt);self.assertIn('不能执行',prompt);self.assertIn('页码',prompt)
 def test_file_and_size_validation(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'paper.pdf';p.write_bytes(b'%PDF-1.4')
   submit=Mock(return_value={});request(Path(d),{'path':str(p)},submit)
   self.assertIn(str(p),submit.call_args.args[1])
   with self.assertRaises(ValueError):request(Path(d),{'path':str(p.with_suffix('.txt'))},submit)
 def test_music_expired_request_cannot_execute_later(self):
  with tempfile.TemporaryDirectory() as d:
   answer=music(Path(d),'play',timeout=.01)
   self.assertIn('没有及时返回',answer)
   self.assertEqual(list((Path(d)/'app-requests').glob('*.json')),[])
   with self.assertRaises(ValueError):music(Path(d),'shell')
 def test_translation_requires_conservative_japanese(self):
  for text in ('否定','原文与译文','不猜省略主语','不是整篇论文','待核'):self.assertIn(text,TRANSLATE)

 def test_translation_has_adequate_budget(self):
  from unittest.mock import patch
  import backend
  with patch.object(backend,'chat',return_value={'answer':'译文'}) as chat:
   backend.assist_task({'kind':'translate_zh','text':'これは例文である。'*100})
   self.assertTrue(chat.call_args.kwargs['precision']);self.assertGreater(chat.call_args.kwargs['output_tokens'],384)
