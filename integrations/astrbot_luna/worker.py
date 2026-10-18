"""Run bounded text requests with Luna's existing persona, model and memory."""

import json
import re
import sys
from pathlib import Path


def _respond(message, request_id=""):
    resources = Path("/Applications/露娜电脑管家.app/Contents/Resources")
    sys.path.insert(0, str(resources))
    import backend

    from remote_actions import handle
    action = handle(message, backend, request_id)
    if action is not None:
        return action
    from computer_status import requested, report
    if requested(message):
        return report()

    original_model_read = backend.read

    def bounded_read(name, default):
        value = original_model_read(name, default)
        if name == "model.json":
            value = {
                **value,
                "extra_body": {**value.get("extra_body", {}), "max_tokens": 128},
            }
        return value

    backend.read = bounded_read
    from notebook import manage, remember_region

    region = remember_region(backend.BASE, message)
    if region:
        return "嗯，记住了，你的常住地区是" + region + "。"
    match = re.fullmatch(r"(?:请)?(?:记住|记一下|记下来)[：:，, ]?(.+)", message, re.S)
    if match:
        manage(backend.BASE, {"kind": "memory", "op": "add", "text": match[1].strip(), "source": "你在 QQ/微信私聊明确要求保存"})
        return "我记下了。Mac 上的长期记忆里也能看到。"
    match = re.fullmatch(
        r"(?:添加|新增|记个|记一个)(?:任务|待办)[：:，, ]?(.+)", message, re.S
    )
    if match:
        manage(backend.BASE, {"kind": "task", "op": "add", "text": match[1].strip()})
        return "已加入露娜的待办，还没有执行。"
    if re.search(
        r"^(?:请|帮我|替我)?(?:交给.*codex|调用.*codex|打开|关闭|删除|清理|安装|执行|运行)",
        message,
        re.I,
    ):
        return "这句话还没有执行。要交给工作助手，请明确发“交给Codex：具体任务”；也可以发“功能菜单”查看已接入的功能。"
    if re.search(r"天气|会下雨|气温|带伞", message):
        data = backend.weather()
        current = data["current"]
        return f"{data['city']}，{current['time']}：气温 {current['temperature_2m']}°C，体感 {current['apparent_temperature']}°C。来源：https://open-meteo.com/"
    # Keep the Remote context separate from simultaneous desktop writes while
    # sharing the same long-term SQLite notebook and model credentials.
    original_read, original_save = backend.read, backend.save
    names = {"chat.json", "context-window.json"}
    backend.read = lambda name, default: original_read(
        "remote-" + name if name in names else name, default
    )
    backend.save = lambda name, data: original_save(
        "remote-" + name if name in names else name, data
    )
    return backend.public_answer(backend.chat(message, timeout=45)["answer"], message)


def respond(message, request_id=""):
    answer=_respond(message,request_id)
    import backend,handoff,fcntl
    with (backend.BASE/'remote-dialogue.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        rows=handoff.read(backend.BASE/'remote-dialogue.json',[])
        if not request_id or not any(r.get('request_id')==request_id for r in rows):
            rows.extend([{'role':'user','text':message,'request_id':request_id},{'role':'assistant','text':str(answer)[:4000]}])
            handoff.write(backend.BASE/'remote-dialogue.json',rows[-40:])
    return answer


def task_result(job_id):
    if not re.fullmatch('[a-f0-9]{32}',job_id):raise ValueError('invalid task')
    resources=Path('/Applications/露娜电脑管家.app/Contents/Resources');sys.path.insert(0,str(resources))
    import backend,handoff
    job=backend.BASE/'codex-jobs'/job_id
    request=handoff.read(job/'request.json',{})
    if not str(request.get('reason','')).startswith('已配对用户通过 QQ/微信私聊提交：'):raise ValueError('not a remote task')
    result=handoff.read(job/'result.json',{})
    if result:return {'state':result.get('state','unknown'),'answer':str(result.get('summary','没有取得结果'))}
    current=handoff.read(backend.BASE/'codex-status.json',{})
    return {'state':current.get('state','unknown') if current.get('id')==job_id else 'unknown'}


if __name__ == "__main__":
    try:
        request = json.load(sys.stdin)
        if request.get('operation')=='taskResult':
            print(json.dumps(task_result(str(request.get('job_id',''))),ensure_ascii=False));sys.exit(0)
        message = str(request["message"]).strip()
        if not 1 <= len(message) <= 6000:
            raise ValueError("invalid message length")
        answer=respond(message,str(request.get('request_id','')))
        output={'answer':str(answer)}
        if getattr(answer,'job_id',None):output['watch_job']=answer.job_id
        print(json.dumps(output,ensure_ascii=False))
    except Exception:
        # Do not expose provider URLs, credentials or local paths to Remote.
        print(
            json.dumps(
                {
                    "answer": "这次没有取得完整回执。如果刚才交代了任务，请先问我“办得怎么样了”，避免重复提交。",
                    "error": True,
                },
                ensure_ascii=False,
            )
        )
