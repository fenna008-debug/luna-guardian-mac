"""One bounded local synthesis. Never keep models resident or queue speech."""
import fcntl,json,os,subprocess,time
from pathlib import Path
ROOT=Path.home()/'Library/Application Support/LunaCompanionMac/runtime'
def synthesize(base,request):
 ja=str(request.get('ja',''));zh=str(request.get('zh',''))
 if not 1<=len(ja)<=100 or not 1<=len(zh)<=120:raise ValueError('语音文本过长')
 lock=(ROOT.parent/'voice-bridge/play.lock').open('a')
 try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
 except BlockingIOError:raise ValueError('语音正在处理')
 def pressure():
  return subprocess.run(['/usr/sbin/sysctl','-n','kern.memorystatus_vm_pressure_level'],capture_output=True,text=True,timeout=2).stdout.strip()
 if pressure()=='4':raise ValueError('严重内存压力，保留文字')
 target=base/'dialogue.wav';target.unlink(missing_ok=True)
 env={**os.environ,'OMP_NUM_THREADS':'1','MKL_NUM_THREADS':'1'}
 p=subprocess.Popen([str(ROOT/'speech-env/bin/python'),str(Path(__file__).with_name('synthesize_once.py'))],stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,text=True,env=env)
 try:
  p.stdin.write(json.dumps({'ja':ja,'output':str(target)}));p.stdin.close();start=time.monotonic()
  while p.poll() is None:
   time.sleep(.75)
   rss=subprocess.run(['/bin/ps','-o','rss=','-p',str(p.pid)],capture_output=True,text=True,timeout=2).stdout.strip()
   if pressure()=='4' or int(rss or 0)>2300000 or time.monotonic()-start>85:raise ValueError('本次语音超出资源预算，保留文字')
  if p.returncode or not target.exists():raise ValueError('语音未生成，保留文字')
  return {'path':str(target),'ja':ja,'zh':zh}
 finally:
  if p.poll() is None:
   p.terminate()
   try:p.wait(timeout=2)
   except subprocess.TimeoutExpired:p.kill();p.wait()
  lock.close()
