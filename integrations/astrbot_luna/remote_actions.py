"""Explicit owner-private commands. No model output is executed as a command."""
import fcntl
import hashlib
import json
import re
import time
from datetime import datetime, timedelta, timezone

class TaskAcknowledgement(str):
    def __new__(cls,text,job_id):
        value=super().__new__(cls,text);value.job_id=job_id;return value

HELP = '''我是露娜，你可以直接这样和我说：
• 看看电脑状况：实际检查 CPU、内存、磁盘和电池
• 告诉我具体任务，或说“这个交给Codex做”；复杂任务我会判断是否需要转交
• “办得怎么样了”“结果呢”“停下刚才的任务”
• 查看记忆 / 记住：内容 / 修改记忆 3：新内容 / 忘记记忆 3
• 我的待办 / 添加待办：内容 / 完成待办 3 / 重新打开待办 3
• 搜索：关键词（返回网页摘要与来源）
• 今日运势（查看桌宠当天已抽的签）
• 今天读了什么（当天读书节选与感想）
• 天气、语音回复，或发 PDF / Word / 文本让我读

工作在后台进行，我会把结果带回 QQ；也可问“结果呢”，“发成文件”可导出。修改原文件仍受执行权限限制。待办是记录，标记完成不代表我执行过。'''


def day(now=None):
    return (datetime.fromtimestamp(time.time() if now is None else now, timezone(timedelta(hours=9))) - timedelta(hours=4)).strftime('%Y-%m-%d')


def command(message, backend):
    from notebook import manage
    import handoff
    base=backend.BASE
    m=message.strip().rstrip('。！!')
    if m in ('帮助','菜单','功能','功能菜单','你能做什么','QQ功能','qq功能'):return HELP
    from delegation import prepare
    def delegate(plan):
        if plan.get('question'):return plan['question']
        try:r=handoff.submit(base,plan['task'],'已配对用户通过 QQ/微信私聊提交：'+plan['reason'])
        except ValueError:return '上一件事还在处理，暂时没有再提交。你可以问我“办得怎么样了”。'
        job=r['handoff']['id'];handoff.write(base/'remote-codex.json',{'id':job,'created':time.time()})
        return TaskAcknowledgement('这件事我已经交给 Codex 去做了。你继续忙，我拿到结果就告诉你。',job)
    history=handoff.read(base/'remote-dialogue.json',[])
    plan=prepare(m,history,only_explicit=True)
    if plan:return delegate(plan)
    if m in ('办得怎么样了','那件事做完了吗','结果呢','进度呢','有结果了吗'):m='Codex结果'
    if m in ('停下刚才的任务','取消刚才的任务','别做了'):m='取消Codex任务'
    if re.fullmatch(r'(?:查看)?(?:Codex|任务)(?:进度|状态|结果)(?:[，, ]*(?:发成文件|导出))?',m,re.I) or m in ('取消Codex任务','停止Codex任务','取消codex任务'):
        ref=handoff.read(base/'remote-codex.json',{});ident=ref.get('id','')
        if not re.fullmatch('[a-f0-9]{32}',ident):return '还没有从 QQ/微信提交过 Codex 任务。可以发“交给Codex：具体任务”。'
        job=base/'codex-jobs'/ident
        if m.lower() in ('取消codex任务','停止codex任务'):
            with (base/'codex-jobs'/'submit.lock').open('a') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX)
                s=handoff.read(base/'codex-status.json',{})
                if s.get('id')!=ident or s.get('state') not in ('queued','running'):return '这项远程任务已结束，没有停止其他桌面任务。'
                handoff.write(job/'cancel.json',{'requested':time.time()})
            return '已请求停止任务 '+ident[:8]+'。发“Codex进度”确认最终状态。'
        s=handoff.read(job/'result.json',{})
        if not s:
            current=handoff.read(base/'codex-status.json',{})
            s=current if current.get('id')==ident else handoff.read(job/'request.json',{})
        labels={'queued':'已排队','running':'执行中','completed':'执行结束','failed':'未完成','cancelled':'已取消'}
        return ('你交代的事有结果了：\n' if s.get('state')=='completed' else '这件事'+labels.get(s.get('state'),'状态未知')+'：\n')+str(s.get('summary','尚无回执'))
    if m in ('查看记忆','我的记忆','你记得什么','记忆列表'):
        rows=manage(base,{'kind':'memory','op':'list'})['items']
        if not rows:return '长期记忆目前为空。发“记住：内容”就能保存，并与桌宠共用。'
        return '长期记忆（与 Mac 桌宠共用）：\n'+'\n'.join(f"#{r['id']} {r['text']}\n来源：{r.get('source','未记录')}" for r in rows[:30])+'\n可用“修改记忆 编号：内容”或“忘记记忆 编号”。'
    match=re.fullmatch(r'修改记忆\s*#?(\d+)\s*[：:]\s*(.+)',m,re.S)
    if match:
        r=manage(base,{'kind':'memory','op':'update','id':int(match[1]),'text':match[2],'status':'saved'})
        if r['updated']:
            from notebook import connect
            with connect(base) as db:db.execute("UPDATE notes SET source=? WHERE id=? AND kind='memory' AND text=?",('你在 QQ/微信私聊明确修改',int(match[1]),match[2][:1500]))
        return '这条长期记忆已修改，桌宠会使用新内容。' if r['updated'] else '没找到该记忆编号，请先发“查看记忆”。'
    match=re.fullmatch(r'忘记记忆\s*#?(\d+)',m)
    if match:
        r=manage(base,{'kind':'memory','op':'delete','id':int(match[1])})
        return '已删除这条长期记忆。' if r['deleted'] else '没找到该记忆编号。'
    if m in ('我的待办','查看待办','待办列表','我的任务'):
        rows=manage(base,{'kind':'task','op':'list'})['items'];labels={'pending':'待办','in_progress':'进行中','done':'已标记完成'}
        return '待办记录：\n'+'\n'.join(f"#{r['id']} [{labels.get(r['status'],r['status'])}] {r['text']}" for r in rows[:30]) if rows else '还没有待办。可以发“添加待办：内容”。'
    match=re.fullmatch(r'(完成待办|重新打开待办)\s*#?(\d+)',m)
    if match:
        status='done' if match[1]=='完成待办' else 'pending'
        r=manage(base,{'kind':'task','op':'update','id':int(match[2]),'status':status})
        return ('已标记完成。这是更新待办记录，不代表露娜执行过该任务。' if status=='done' else '已重新放回待办。') if r['updated'] else '没找到该待办编号。'
    match=re.fullmatch(r'(?:帮我)?(?:搜索|搜一下|查一下)[：:，, ]+(.+)',m,re.S)
    if match:
        from web_tools import search
        try:data=search(match[1])
        except Exception:return '这次没有取得联网搜索结果，不能当作已经查到。请稍后再试。'
        return '联网搜索结果（网页摘要，不代表读过全文）：\n\n'+'\n\n'.join(r['title']+'\n'+r['snippet'][:350]+'\n'+r['url'] for r in data['results'])
    if m in ('今日运势','今天的运势','我的运势','今日签','今天抽的签'):
        d=backend.read('fortune.json',{})
        if d.get('date')!=day():return '今天还没有抽签。请在 Mac 桌宠抽取；QQ 会显示同一支签，每日凌晨4点换日，不会另抽覆盖。'
        return '今日运势 · '+str(d.get('title',''))+'\n'+str(d.get('text',''))+'\n与桌宠共用，凌晨4点换日。'
    if m in ('今天读了什么','今日读书','读书记录','今天看了什么书'):
        rows=backend.read('reading-log.json',[])
        rows=[r for r in rows if isinstance(r,dict) and day(r.get('time',0))==day()]
        if not rows:return '今天暂时没有读书记录；每天凌晨4点换日。'
        return '今天的读书记录（节选，不代表整本读完）：\n\n'+'\n\n'.join(str(r.get('title',''))+' · '+str(r.get('scope',''))+'\n'+str(r.get('reflection',''))+'\n'+str(r.get('url','')) for r in rows[:5])
    plan=prepare(m,history,backend.chat)
    return delegate(plan) if plan else None


def handle(message, backend, request_id=''):
    """Serialize remote mutations; identical delivered message IDs cannot execute twice."""
    import handoff
    base=backend.BASE
    with (base/'remote-actions.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        key=hashlib.sha256(request_id.encode()).hexdigest() if request_id else ''
        cache=handoff.read(base/'remote-request-receipts.json',{})
        if key and key in cache:return cache[key]['answer']
        answer=command(message,backend)
        if key and answer is not None:
            cache[key]={'answer':answer,'at':time.time()}
            cache=dict(sorted(cache.items(),key=lambda item:item[1]['at'],reverse=True)[:100])
            handoff.write(base/'remote-request-receipts.json',cache)
        return answer
