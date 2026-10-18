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

class DirectHandoff(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.base=Path(self.temp.name)
 def tearDown(self):self.temp.cleanup()
 def test_validation(self):
  for value in ('',' '*3,'a'*8001,None):
   with self.assertRaises(ValueError):handoff.submit(self.base,value,'test')
 def test_cancel_marks_exact_job_without_signalling_arbitrary_pid(self):
  ident='a'*32;job=self.base/'codex-jobs'/ident;job.mkdir(parents=True)
  handoff.write(self.base/'codex-status.json',{'id':ident,'state':'running','pid':1})
  self.assertTrue(handoff.cancel(self.base)['requested']);self.assertTrue((job/'cancel.json').exists())
  handoff.write(self.base/'codex-status.json',{'id':ident,'state':'completed'})
  self.assertFalse(handoff.cancel(self.base)['requested'])
 def test_cancel_before_runner_starts_never_launches_cli(self):
  ident='b'*32;job=self.base/'codex-jobs'/ident;job.mkdir(parents=True)
  handoff.write(job/'request.json',{'id':ident,'message':'test','reason':'test'})
  handoff.write(job/'cancel.json',{})
  with patch.object(handoff.subprocess,'Popen') as launch:handoff.run(self.base,ident);launch.assert_not_called()
  self.assertEqual(handoff.read(job/'result.json')['state'],'cancelled')
 def test_progress_keeps_raw_commands_out_of_status(self):
  s={};handoff.progress({'type':'thread.started','thread_id':'abc'},s)
  handoff.progress({'type':'item.started','item':{'type':'command_execution','command':'private command'}},s)
  self.assertEqual(s['threadId'],'abc');self.assertNotIn('private',str(s))
 def test_direct_entry_bypasses_chat_classifier(self):
  with patch.object(b,'BASE',self.base),patch.object(b,'chat') as chat,patch.object(handoff,'submit',return_value={'answer':'queued'}) as submit:
   b.dispatch('codexSubmit',{'message':'查看天气程序代码'})
   chat.assert_not_called();submit.assert_called_once()
 def test_explicit_weather_delegation_does_not_get_swallowed(self):
  with patch.object(b,'BASE',self.base),patch.object(b,'weather') as weather,patch.object(handoff,'submit',return_value={'answer':'queued','handoff':{}}) as submit:
   b.routed_chat('交给 Codex：查询天气')
   weather.assert_not_called();submit.assert_called_once()
 def test_running_cancel_terminates_process_and_records_receipt(self):
  import threading,time,os
  ident='c'*32;job=self.base/'codex-jobs'/ident;job.mkdir(parents=True)
  handoff.write(job/'request.json',{'id':ident,'message':'test','reason':'test'})
  cli=self.base/'fake-codex';cli.write_text('#!'+sys.executable+'\nimport time,os,json\nprint(json.dumps({"type":"thread.started","thread_id":"test-thread"}),flush=True)\ntime.sleep(20)\n');cli.chmod(0o700)
  with patch.object(handoff,'CLI',cli):
   runner=threading.Thread(target=handoff.run,args=(self.base,ident));runner.start()
   try:
    for _ in range(100):
     if handoff.read(self.base/'codex-status.json',{}).get('threadId')=='test-thread':break
     time.sleep(.02)
    self.assertTrue(handoff.cancel(self.base)['requested']);runner.join(5)
    self.assertFalse(runner.is_alive());self.assertEqual(handoff.read(job/'result.json')['state'],'cancelled')
   finally:
    if runner.is_alive():handoff.cancel(self.base);runner.join(5)
 def test_second_job_rejected_while_running(self):
  handoff.write(self.base/'codex-status.json',{'state':'running'})
  with self.assertRaises(ValueError):handoff.submit(self.base,'new task','test')
 def test_launch_failure_does_not_leave_permanent_queued_state(self):
  with patch.object(handoff.subprocess,'Popen',side_effect=OSError('launch failed')):
   with self.assertRaises(OSError):handoff.submit(self.base,'test','test')
  self.assertEqual(handoff.read(self.base/'codex-status.json')['state'],'failed')
