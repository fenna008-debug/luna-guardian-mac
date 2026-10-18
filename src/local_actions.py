"""Small, allowlisted computer actions from direct user chat only."""
import json,re,time,subprocess
from pathlib import Path
APPS={'计算器':'Calculator','日历':'Calendar','备忘录':'Notes','提醒事项':'Reminders','浏览器':'Safari','Safari':'Safari','QQ':'QQ','微信':'WeChat','音乐':'NeteaseMusic','网易云音乐':'NeteaseMusic'}
POWER={'关机':'shut down','重启':'restart','睡眠':'sleep'}
def handle(message,base,channel='desktop',runner=subprocess.run):
    from session_controls import handle as session_handle
    answer=session_handle(message,base,channel)
    if answer is not None:return answer
    from daily_actions import handle as daily_handle
    answer=daily_handle(message,base,runner)
    if answer is not None:return answer
    m=message.strip().rstrip('。！!？?');p=Path(base)/('local-action-'+channel+'.json')
    try:pending=json.loads(p.read_text())
    except (OSError,ValueError):pending={}
    if m in ('取消','取消关机','取消重启','先别关机','先别重启'):
        if p.exists():p.unlink()
        return '已取消，还没有执行系统操作。'
    confirmed=m in ('是的','确认','确认关机','确认重启','现在关机','现在重启','确定执行')
    action=None
    if confirmed:
        if pending.get('expires',0)>time.time() and pending.get('action') in POWER:
            action=pending['action'];p.unlink()
        elif m in ('确认关机','确认重启','确定执行'):
            return '没有待确认的操作，或确认已经过期。请重新告诉我要关机还是重启。'
    if action is None:
        if re.search(r'不要|不用|别|怎么|如何|为什么|比如|假设|代码|脚本|功能|修改',m):return None
        match=re.fullmatch(r'(?:请|你|帮我|替我|能不能|能|可以|现在|把电脑|一下|电脑|直接|给我|你帮我确认一下没问题|麻烦|吗|\s)*(关机|重启|睡眠)(?:一下|电脑|吗|吧|了|\s)*',m)
        if match:
            action=match[1]
            if action!='睡眠':
                p.write_text(json.dumps({'action':action,'expires':time.time()+120}));p.chmod(0o600)
                return '我可以直接'+action+'，不用交给 Codex。我无法确认所有应用的内容都已保存。请保存文件后回复“确认'+action+'”；两分钟内有效。'
        else:
            match=re.fullmatch(r'(?:请|帮我|替我)?打开(.+)',m)
            if match and match[1] in APPS:
                args=['/usr/bin/open','-a',APPS[match[1]]];label='打开'+match[1]
            elif m in ('静音','把声音关掉','取消静音'):
                args=['/usr/bin/osascript','-e','set volume output muted '+('false' if m=='取消静音' else 'true')];label=m
            else:
                volume=re.fullmatch(r'(?:把)?音量(?:调到|设为|设置为)(\d{1,3})(?:%|％)?',m)
                if not volume:return None
                n=int(volume[1])
                if not 0<=n<=100:return '音量可以设置为零到一百。'
                args=['/usr/bin/osascript','-e','set volume output volume '+str(n)];label='把音量设为'+str(n)
    if action:
        args=['/usr/bin/osascript','-e','tell application "System Events" to '+POWER[action]];label=action
    try:r=runner(args,capture_output=True,text=True,timeout=15)
    except (OSError,subprocess.TimeoutExpired):return '没有确认'+label+'成功。系统操作暂未完成。'
    if r.returncode:return label+'没有完成，系统未接受操作；如系统弹出自动化许可，需要在电脑上允许后重试。我没有转交给 Codex。'
    return '已向系统发送'+label+'请求。' + ('应用可能要求保存文件，请按系统提示处理。' if action in ('重启','关机') else '')
