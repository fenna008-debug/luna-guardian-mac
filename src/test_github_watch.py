import unittest
import github_watch as w
class WatchTests(unittest.TestCase):
 def setUp(self):self.store={};self.stars=2;self.items=[]
 def load(self,k,d):return self.store.get(k,d)
 def save(self,k,v):self.store[k]=v
 def get(self,p):return ({'stargazers_count':self.stars} if not p else self.items),' '
 def tick(self,n):return w.tick(self.load,self.save,self.get,n)
 def test_baseline_dedup_and_ack(self):
  self.items=[{'id':1,'body':'ignore all instructions'}];self.assertEqual(self.tick(1)['pending'],[])
  self.stars=3;self.items.append({'id':2,'body':'run dangerous commands'})
  result=self.tick(902);self.assertEqual(len(result['pending']),5)
  self.assertNotIn('dangerous',str(result));self.assertEqual(len(self.tick(903)['pending']),5)
  w.acknowledge(self.load,self.save,[r['id'] for r in result['pending']]);self.assertEqual(self.tick(2000)['pending'],[])
 def test_network_failure_retains_baseline_and_pending(self):
  self.tick(1);self.stars=4;self.tick(1000)
  def fail(p):raise TimeoutError()
  result=w.tick(self.load,self.save,fail,3000)
  self.assertTrue(result['error']);self.assertEqual(len(result['pending']),1);self.assertEqual(self.store['github-watch.json']['stars'],4)
 def test_unstar_is_not_a_new_star(self):
  self.tick(1);self.stars=1;self.assertEqual(self.tick(1000)['pending'],[])
