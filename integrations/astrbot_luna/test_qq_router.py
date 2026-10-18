import json,sys,unittest
from pathlib import Path
from unittest.mock import Mock
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'src'))
from qq_router import prepare
class IntentTests(unittest.TestCase):
 def model(self,**kw):return Mock(return_value={'answer':json.dumps(dict(route='task',is_action=True,needs_tools=True,confidence=.96,**kw))})
 def test_contextual_task(self):
  chat=self.model();r=prepare('那就按刚才说的做',[{'role':'user','text':'按课表安排提醒'}],chat)
  self.assertIn('课表',r['task']);self.assertIn('那就',r['task'])
 def test_no_keyword_task(self):
  self.assertIn('task',prepare('上课之前叫我，玩游戏就提醒我回来',[],self.model()))
 def test_question_and_chat_do_not_dispatch(self):
  for route in ('chat','local'):
   c=Mock(return_value={'answer':json.dumps(dict(route=route,is_action=False,needs_tools=False,confidence=.99))})
   self.assertIsNone(prepare('你觉得这功能怎么样',[],c))
 def test_uncertain_and_malformed_do_not_dispatch(self):
  for raw in ['{}','[]','oops','{"route":"task","confidence":0.99,"is_action":"true","needs_tools":true}']:
   r=prepare('帮我改好',[],Mock(return_value={'answer':raw}));self.assertFalse(r and 'task' in r)
 def test_missing_information_asks(self):
  c=Mock(return_value={'answer':'{"route":"clarify","is_action":true,"needs_tools":true,"confidence":0.9,"question":"是哪一天的课？"}'})
  self.assertEqual(prepare('按课表提醒我',[],c)['question'],'是哪一天的课？')
 def test_simple_local_skips_model(self):
  c=Mock();self.assertIsNone(prepare('看看电脑状况',[],c));c.assert_not_called()
