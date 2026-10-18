"""Run bounded text requests with Luna's existing persona, model and memory."""

import json
import re
import sys
from pathlib import Path


def respond(message):
    from computer_status import requested, report
    if requested(message):
        return report()
    resources = Path("/Applications/露娜电脑管家.app/Contents/Resources")
    sys.path.insert(0, str(resources))
    import backend

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
        manage(backend.BASE, {"kind": "memory", "op": "add", "text": match[1].strip()})
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
        return "远程入口支持实际检查电脑状态、聊天、记忆、待办和天气；修改文件或设置请在 Mac 桌宠的“Codex任务”里提交。"
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
    return backend.chat(message, timeout=45)["answer"]


if __name__ == "__main__":
    try:
        request = json.load(sys.stdin)
        message = str(request["message"]).strip()
        if not 1 <= len(message) <= 6000:
            raise ValueError("invalid message length")
        print(json.dumps({"answer": respond(message)}, ensure_ascii=False))
    except Exception:
        # Do not expose provider URLs, credentials or local paths to Remote.
        print(
            json.dumps(
                {
                    "answer": "暂时无法完成这次请求，请稍后再试。没有自动转交 Codex。",
                    "error": True,
                },
                ensure_ascii=False,
            )
        )
