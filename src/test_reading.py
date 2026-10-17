import unittest,collections
import reading
class ReadingFeedback(unittest.TestCase):
 def setUp(self):
  self.store={'reading-log.json':[{'evidenceHash':'abc','title':'Test','quote':'source excerpt','reflection':'reflection'}]}
 def load(self,k,d):return self.store.get(k,d)
 def save(self,k,v):self.store[k]=v
 def test_comment_persists_and_adjusts_gently(self):
  result=reading.feedback({'hash':'abc','comment':'想看一点童话'},lambda *a,**k:{'answer':'{"reply":"嗯，下次读点别的。","weights":{"fantasy":1,"tea":-1,"unknown":10}}'},self.load,self.save)
  self.assertTrue(result['interpreted']);self.assertEqual(self.store['reading-preferences.json']['fantasy'],0.3);self.assertNotIn('unknown',self.store['reading-preferences.json'])
 def test_timeout_keeps_comment_without_inventing_preferences(self):
  def fail(*a,**k):raise TimeoutError()
  result=reading.feedback({'hash':'abc','comment':'很有趣'},fail,self.load,self.save)
  self.assertFalse(result['interpreted']);self.assertEqual(self.store['reading-comments.json'][0]['comment'],'很有趣');self.assertNotIn('reading-preferences.json',self.store)
 def test_unknown_record_rejected(self):
  with self.assertRaises(ValueError):reading.feedback({'hash':'unknown','comment':'hello'},None,self.load,self.save)
 def test_preference_changes_frequency_not_exclusivity(self):
  state={};counts=collections.Counter(reading.choose_source(state,{'fantasy':2,'tea':-2})['genre'] for _ in range(100))
  self.assertGreater(counts['fantasy'],counts['tea']);self.assertTrue(all(counts[g]>0 for g in ('fiction','fantasy','essay','tea')))
