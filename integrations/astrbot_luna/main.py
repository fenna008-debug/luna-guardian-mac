"""Private, owner-paired WeChat bridge to the installed Mac Luna backend."""

import asyncio
import hashlib
import hmac
import json
import os
import sys
from pathlib import Path

from astrbot.api.event import AstrMessageEvent, filter
from astrbot.api.star import Context, Star, StarTools


class LunaBridge(Star):
    def __init__(self, context: Context):
        super().__init__(context)
        self.state_path = StarTools.get_data_dir("luna_mac_bridge") / "owner.json"
        self.lock = asyncio.Lock()

    @filter.event_message_type(filter.EventMessageType.ALL, priority=10000)
    async def incoming(self, event: AstrMessageEvent):
        if event.get_platform_name() != "weixin_oc":
            return
        # Always stop the general agent pipeline on this private channel.
        event.stop_event()
        if event.get_group_id():
            return
        sender = str(event.get_sender_id())
        platform = str(event.get_platform_id())
        message = event.message_str.strip()
        async with self.lock:
            try:
                state = json.loads(self.state_path.read_text())
            except (OSError, ValueError):
                return
            if not state.get("owner"):
                expected = state.get("pair_hash", "")
                supplied = hashlib.sha256(message.encode()).hexdigest()
                if not expected or not hmac.compare_digest(expected, supplied):
                    return
                state = {"owner": sender, "platform": platform}
                temporary = self.state_path.with_suffix(".tmp")
                temporary.write_text(json.dumps(state))
                temporary.chmod(0o600)
                temporary.replace(self.state_path)
                await event.send(
                    event.plain_result(
                        "我是露娜，你的 AI 桌面助手。微信已配对，可以在这里聊天、记忆和添加待办。"
                    )
                )
                event.stop_event()
                return
            if state["owner"] != sender or state.get("platform") != platform:
                return
            if not message or len(message) > 6000:
                await event.send(
                    event.plain_result(
                        "请发送 1—6000 字的文字；这版微信桥接暂不处理附件。"
                    )
                )
                event.stop_event()
                return
            process = await asyncio.create_subprocess_exec(
                sys.executable,
                str(Path(__file__).with_name("worker.py")),
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
                env={**os.environ, "OPENBLAS_NUM_THREADS": "1"},
            )
            try:
                output, _ = await asyncio.wait_for(
                    process.communicate(json.dumps({"message": message}).encode()), 65
                )
                result = json.loads(output)
                answer = str(result.get("answer", "暂时没有收到回复，请稍后再试。"))
            except (asyncio.TimeoutError, ValueError, OSError):
                if process.returncode is None:
                    process.kill()
                    await process.wait()
                answer = "模型暂时没有及时回复，请稍后再试。没有自动转交 Codex。"
            await event.send(event.plain_result(answer[:8000]))
            event.stop_event()
