import subprocess,json
from pathlib import Path
root=(Path.home()/'Library/Application Support/LunaCompanionMac/runtime')
out=Path(__file__).parent/'voices';out.mkdir(exist_ok=True)
lines={'rain':('雨が降っているようだな。出かけるなら、傘を忘れないように。','好像下雨了。要出门的话，别忘了带伞。'),'hot':('今日は暑いな。水を飲んで、少し涼んだらどうだ。','今天很热。喝点水，稍微凉快一下吧。'),'cold':('冷え込んできたな。薄着で無理をするんじゃないぞ。','天气冷下来了。别穿得太薄还勉强自己。'),'storm':('雷雨のようだ。外にいるなら、早めに安全な場所へ戻るといい。','好像有雷雨。如果在外面，就早点回安全的地方。'),'snow':('雪のようだな。出かけるなら、足元に気をつけるんだぞ。','好像下雪了。要出门的话，注意脚下。')}
(out/'captions.json').write_text(json.dumps({k:{'ja':v[0],'zh':v[1]} for k,v in lines.items()},ensure_ascii=False,indent=2))
for kind,(ja,zh) in lines.items():
 p=out/(kind+'.wav')
 if p.exists():continue
 r=subprocess.run([str(root/'speech-env/bin/python'),str(root/'synthesize.py')],input=json.dumps({'ja':ja,'output':str(p.resolve())}),text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240)
 (out/(kind+'.log')).write_text(r.stdout)
 print(kind,'OK' if r.returncode==0 and p.exists() else 'FAILED',flush=True)
