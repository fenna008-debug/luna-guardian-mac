"""Private, owner-paired QQ/WeChat bridge to the installed Mac Luna backend."""

import asyncio
import hashlib
import hmac
import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

from astrbot.api.event import AstrMessageEvent, filter
from astrbot.api.message_components import File, Record
from astrbot.api.star import Context, Star, StarTools
from astrbot.core.utils.astrbot_path import get_astrbot_temp_path

from .media import receive


class LunaBridge(Star):
    def __init__(self, context: Context):
        super().__init__(context)
        self.state_path = StarTools.get_data_dir("luna_mac_bridge") / "owner.json"
        self.lock = asyncio.Lock()
        self.last_voice = 0.0

    @filter.event_message_type(filter.EventMessageType.ALL, priority=10000)
    async def incoming(self, event: AstrMessageEvent):
        if event.get_platform_name() not in {"weixin_oc", "qq_official"}:
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
                        "我是露娜，你的 AI 桌面助手。QQ/微信已配对，可以聊天、记忆、添加待办。QQ 还支持语音和 PDF、Word、文本文件。"
                    )
                )
                event.stop_event()
                return
            if state["owner"] != sender or state.get("platform") != platform:
                return
            components = event.get_messages()
            attachments = [c for c in components if isinstance(c, (File, Record))]
            if len(message) > 6000 or len(attachments) > 1:
                await event.send(
                    event.plain_result("每次请发一份附件或不超过 6000 字的文字。")
                )
                return
            if not message and not attachments:
                await event.send(
                    event.plain_result("请发送文字、语音或 PDF、DOCX、文本文件。")
                )
                return
            job = Path(tempfile.mkdtemp(prefix="luna-", dir=self.state_path.parent))
            job.chmod(0o700)
            try:
                is_record = bool(attachments and isinstance(attachments[0], Record))
                is_audio = is_record or bool(
                    attachments
                    and Path(attachments[0].name or "").suffix.lower()
                    in {".wav", ".mp3", ".m4a", ".ogg", ".amr", ".silk"}
                )
                if attachments:
                    await event.send(
                        event.plain_result(
                            "收到，我先听一下。"
                            if is_audio
                            else "收到文件，正在阅读正文。"
                        )
                    )
                    item = attachments[0]
                    source = (
                        (item.url or item.file or "")
                        if is_record
                        else (item.url or item.file_ or "")
                    )
                    name = "voice.wav" if is_record else (item.name or "attachment")
                    path = await receive(
                        source, name, job, Path(get_astrbot_temp_path())
                    )
                    result = await self.run_worker(
                        "media_worker.py",
                        {
                            "action": "asr" if is_audio else "file",
                            "path": str(path),
                            "job": str(job),
                            "message": message,
                        },
                        120,
                    )
                    if result.get("error"):
                        await event.send(event.plain_result(result["error"]))
                        return
                    if is_audio:
                        message = result["transcript"]
                        await event.send(event.plain_result("我听到的是：" + message))
                    else:
                        await event.send(event.plain_result(result["answer"][:3500]))
                        await event.send(
                            event.chain_result(
                                [
                                    File(
                                        name=Path(result["file"]).name,
                                        file=result["file"],
                                    )
                                ]
                            )
                        )
                        return
                voice_test = message.strip() == "测试露娜语音"
                result = (
                    {"answer": "贵安。我是露娜，这是我的语音测试。"}
                    if voice_test
                    else await self.run_worker("worker.py", {"message": message}, 65)
                )
                answer = str(result.get("answer", "暂时没有收到回复，请稍后再试。"))
                await event.send(event.plain_result(answer[:3500]))
                if "导出" in message or "发成文件" in message or len(answer) > 3500:
                    report = job / "露娜回复.txt"
                    report.write_text(answer, encoding="utf-8")
                    await event.send(
                        event.chain_result([File(name=report.name, file=str(report))])
                    )
                if result.get("error"):
                    return
                wants_voice = is_audio or any(
                    word in message for word in ("语音", "念给我", "说给我听")
                )
                if wants_voice and event.get_platform_name() == "qq_official":
                    if time.monotonic() - self.last_voice < 60:
                        await event.send(
                            event.plain_result("刚刚处理过语音，这次先用文字回复你。")
                        )
                        return
                    self.last_voice = time.monotonic()
                    await event.send(
                        event.plain_result("日语语音正在生成，中文回复已经发出。")
                    )
                    voice = await self.run_worker(
                        "media_worker.py",
                        {
                            "action": "voice",
                            "text": answer,
                            "job": str(job),
                            "diagnostic": voice_test,
                        },
                        125,
                    )
                    if voice.get("voice"):
                        await event.send(
                            event.plain_result("语音字幕：" + voice["caption"])
                        )
                        await event.send(
                            event.chain_result([Record.fromFileSystem(voice["voice"])])
                        )
                    else:
                        await event.send(
                            event.plain_result(
                                voice.get("error", "这次语音没有生成，文字回复已保留。")
                            )
                        )
            except (ValueError, OSError, asyncio.TimeoutError):
                await event.send(
                    event.plain_result(
                        "这次处理暂未完成。请检查附件格式，或稍后再试；没有转交 Codex。"
                    )
                )
            finally:
                shutil.rmtree(job, ignore_errors=True)
                event.stop_event()

    async def run_worker(self, script, payload, timeout):
        process = await asyncio.create_subprocess_exec(
            sys.executable,
            str(Path(__file__).with_name(script)),
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
            env={**os.environ, "OPENBLAS_NUM_THREADS": "1", "OMP_NUM_THREADS": "1"},
            start_new_session=True,
        )
        try:
            output, _ = await asyncio.wait_for(
                process.communicate(json.dumps(payload).encode()), timeout
            )
            return json.loads(output)
        finally:
            if process.returncode is None:
                import signal

                os.killpg(process.pid, signal.SIGKILL)
                await process.wait()
