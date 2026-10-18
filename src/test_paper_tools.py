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

class MusicIntentTests(unittest.TestCase):
 def test_direct_song_request_both_channels(self):
  from daily_actions import parse_song
  for m in ['播放《牵丝戏》','露娜，帮我放牵丝戏','用网易云播放牵丝戏','我想听牵丝戏']:
   self.assertEqual(parse_song(m),{'title':'牵丝戏','artist':''})
  self.assertEqual(parse_song('播放银临的《牵丝戏》'),{'title':'牵丝戏','artist':'银临'})
  self.assertEqual(parse_song('播放我的天空')['title'],'我的天空')
  for m in ['不要播放牵丝戏','你能不能做个播放音乐功能','怎么播放牵丝戏','播放视频','暂停音乐']:
   self.assertIsNone(parse_song(m))
 def test_qq_song_is_local_not_delegated(self):
  import sys
  sys.path.insert(0,str(Path(__file__).parents[1]/'integrations/astrbot_luna'))
  import remote_actions
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as d:
   backend=Mock();backend.BASE=Path(d)
   with patch('app_actions.music',return_value='已核对歌曲与播放进度') as player,patch('handoff.submit') as submit:
    result=remote_actions.command('帮我放《牵丝戏》',backend)
    self.assertIn('已核对',result);submit.assert_not_called()
    self.assertEqual(player.call_args.kwargs['query'],'牵丝戏')
 def test_translation_is_multilingual(self):
  self.assertIn('英语',TRANSLATE);self.assertIn('不反向翻译',TRANSLATE)

class TranslationStreamTests(unittest.TestCase):
 def test_complete_stream_and_unicode(self):
  import backend,io,json,time
  events=[{'choices':[{'delta':{'content':'两者都'},'finish_reason':None}]},{'choices':[{'delta':{'content':'须考虑。'},'finish_reason':None}]},{'choices':[{'delta':{},'finish_reason':'stop'}]}]
  raw=''.join('data: '+json.dumps(x,ensure_ascii=False)+'\n\n' for x in events)+'data: [DONE]\n\n'
  r=backend.read_chat_stream(io.BytesIO(raw.encode()),time.monotonic(),10)
  self.assertEqual(r['choices'][0]['message']['content'],'两者都须考虑。')
 def test_disconnect_and_tool_are_not_complete_translation(self):
  import backend,io,json,time
  for delta in ({'content':'不完整'}, {'tool_calls':[{'name':'delete'}]}):
   raw=('data: '+json.dumps({'choices':[{'delta':delta}]})+'\n').encode()
   with self.assertRaises(ValueError):backend.read_chat_stream(io.BytesIO(raw),time.monotonic(),10)
