"""Conversation and speech controls; durable memories are never cleared."""
import json,time,uuid,os
from pathlib import Path

def read(path,default):
    try:return json.loads(path.read_text())
    except (OSError,ValueError):return default

def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    tmp=path.with_name(path.name+'.'+uuid.uuid4().hex+'.tmp')
    tmp.write_text(json.dumps(data,ensure_ascii=False));tmp.chmod(0o600);os.replace(tmp,path)

def paused(base):
    return read(Path(base)/'voice-control.json',{}).get('pausedUntil',0)>time.time()

def new_topic(base,channel='desktop'):
    base=Path(base);prefix='remote-' if channel=='qq' else ''
    names=[prefix+'chat.json',prefix+'context-window.json']
    if channel=='qq':names+=['remote-dialogue.json','remote-last-document.json']
    archive={name:read(base/name,None) for name in names}
    write(base/'chat-archives'/(str(int(time.time()))+'-'+uuid.uuid4().hex+'.json'),archive)
    for name in names:write(base/name,[] if name.endswith(('chat.json','dialogue.json')) else {})
    return '新话题开始了。长期记忆、课表和今天的运势都还在，之前的聊天已归档。'

def handle(message,base,channel='desktop'):
    m=message.strip().rstrip('。！!？?')
    if m in ('新话题','开启新话题','开始新话题','换个话题','清空当前对话'):return new_topic(base,channel)
    if m in ('暂停语音','暂时别说话','先别说话','暂停语音十五分钟','暂停语音15分钟'):
        write(Path(base)/'voice-control.json',{'pausedUntil':time.time()+900})
        return '好，语音暂停十五分钟，文字聊天继续。你也可以随时说“恢复语音”。'
    if m in ('恢复语音','继续说话'):
        write(Path(base)/'voice-control.json',{'pausedUntil':0})
        return '语音暂停已解除。原有的静音设置保持不变。'
    return None
