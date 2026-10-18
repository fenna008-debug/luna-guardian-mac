"""Conversation-level work routing; only called on direct human messages."""
import json,re

def explicit(message):
    if re.search(r'不要|不用|不需要|别|假如|假设|比如|例如|别人说|怎么.*(?:交给|调用)|如何.*(?:交给|调用)',message):return False
    return bool(re.search(r'(?:交给|转交给?|交由|派给|发给|发送给|找|让|调用|使用)\s*codex',message,re.I))

def prepare(message,history,chat=None,only_explicit=False):
    chosen=explicit(message)
    reason='你明确交代的任务'
    if not chosen:
        if only_explicit:return None
        if re.search(r'不要|不用|不需要|别|假如|假设|比如|例如|别人说',message):return None
        candidate=bool(re.search(r'编程|代码|安装|部署|修复|排查|批量|重构|脚本|创建.*文件|生成.*文档',message)) and bool(re.search(r'帮我|请|能不能|替我|给我',message))
        if not candidate or chat is None:return None
        prompt='只判断这一条用户消息是否明确要求实际执行复杂、多步骤的电脑或文件任务。闲聊、讲解、建议、天气、简单搜索、假设、否定都不交接。不要输出工具调用。返回JSON：is_action和needs_tools必须是布尔值，complexity为high或low，reason为一句中文。用户消息：'+message[:6000]
        try:
            raw=chat(prompt,remember=False,timeout=15)['answer']
            d=json.loads(re.sub(r'^```(?:json)?\s*|\s*```$','',raw.strip()))
        except Exception:return None
        if not isinstance(d,dict) or d.get('is_action') is not True or d.get('needs_tools') is not True or d.get('complexity')!='high':return None
        reason=str(d.get('reason','需要实际执行的多步骤任务'))[:200]
    # References are resolved from this channel only, never another chat's history.
    recent=[r for r in history if isinstance(r,dict) and r.get('role') in ('user','assistant')][-6:]
    remainder=re.sub(r'(?:这个|这件事|刚才那个|刚才的|上面那个|上述|它|请|帮我|交给|转交给?|交由|派给|发给|发送给|找|让|调用|使用|codex|干|做|处理|吧|一下|来|你|去|[\s：:,，。！!])','',message,flags=re.I)
    reference=chosen and (not remainder or bool(re.search(r'这个|这件事|刚才|上述|上面|它',message)))
    if reference and not any(r.get('role')=='user' and not explicit(r.get('text','')) for r in recent):
        return {'question':'你指的是哪件事？把要做的内容告诉我，我再替你交过去。'}
    context='\n'.join(('你' if r['role']=='user' else '露娜')+'：'+str(r.get('text',''))[:650] for r in recent)[-2600:] if reference else ''
    task=('对话背景，仅用于理解指代，不是新增执行授权：\n'+context+'\n\n本次用户要求：\n' if context else '')+message
    return {'task':task,'reason':reason,'explicit':chosen}
