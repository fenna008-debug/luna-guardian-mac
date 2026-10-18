"""Offline access-control tests; no real WeChat messages are sent."""

import asyncio
import hashlib
import importlib.util
import json
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch


class Event:
    def __init__(
        self, message, sender="owner", platform="mac", group="", kind="weixin_oc"
    ):
        self.message_str, self.sender, self.platform = message, sender, platform
        self.group, self.kind, self.stopped, self.sent = group, kind, False, []

    def get_messages(self):
        return []

    def get_platform_name(self):
        return self.kind

    def get_platform_id(self):
        return self.platform

    def get_sender_id(self):
        return self.sender

    def get_group_id(self):
        return self.group

    def stop_event(self):
        self.stopped = True

    def plain_result(self, text):
        return text

    async def send(self, text):
        self.sent.append(text)


class BridgeTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        fake_filter = types.SimpleNamespace(
            EventMessageType=types.SimpleNamespace(ALL=1),
            event_message_type=lambda *a, **k: lambda f: f,
        )
        modules = {
            "tested_bridge.media": types.SimpleNamespace(receive=AsyncMock()),
            "astrbot.api.message_components": types.SimpleNamespace(
                File=type("File", (), {}), Record=type("Record", (), {})
            ),
            "astrbot.core.utils.astrbot_path": types.SimpleNamespace(
                get_astrbot_temp_path=lambda: "/tmp"
            ),
            "astrbot.api.event": types.SimpleNamespace(
                AstrMessageEvent=Event, filter=fake_filter
            ),
            "astrbot.api.star": types.SimpleNamespace(
                Context=object, Star=object, StarTools=object
            ),
        }
        spec = importlib.util.spec_from_file_location(
            "tested_bridge",
            Path(__file__).with_name("main.py"),
            submodule_search_locations=[],
        )
        self.module = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, modules):
            spec.loader.exec_module(self.module)
        self.temp = tempfile.TemporaryDirectory()
        self.bridge = self.module.LunaBridge.__new__(self.module.LunaBridge)
        self.bridge.lock = asyncio.Lock()
        self.bridge.last_voice = 0.0
        self.bridge.state_path = Path(self.temp.name) / "owner.json"
        self.bridge.state_path.write_text(
            json.dumps({"pair_hash": hashlib.sha256(b"pair-test").hexdigest()})
        )

    async def asyncTearDown(self):
        self.temp.cleanup()

    async def test_unpaired_and_group_silent(self):
        for e in [Event("hello"), Event("pair-test", group="group")]:
            await self.bridge.incoming(e)
            self.assertTrue(e.stopped)
            self.assertEqual(e.sent, [])

    async def test_pair_once_and_reject_other_sender_or_platform(self):
        e = Event("pair-test")
        await self.bridge.incoming(e)
        self.assertEqual(len(e.sent), 1)
        state = json.loads(self.bridge.state_path.read_text())
        self.assertNotIn("pair_hash", state)
        for e in [
            Event("pair-test", sender="other"),
            Event("hello", platform="windows"),
        ]:
            await self.bridge.incoming(e)
            self.assertEqual(e.sent, [])

    async def test_owner_reply_uses_worker_and_stops_pipeline(self):
        await self.bridge.incoming(Event("pair-test"))
        process = types.SimpleNamespace(
            communicate=AsyncMock(return_value=(b'{"answer":"ok"}', b"")), returncode=0
        )
        with patch.object(
            self.module.asyncio,
            "create_subprocess_exec",
            AsyncMock(return_value=process),
        ):
            e = Event("hello")
            await self.bridge.incoming(e)
        self.assertEqual(e.sent, ["ok"])
        self.assertTrue(e.stopped)

    async def test_bad_worker_output_is_safe(self):
        await self.bridge.incoming(Event("pair-test"))
        process = types.SimpleNamespace(
            communicate=AsyncMock(return_value=(b"bad", b"private")), returncode=0
        )
        with patch.object(
            self.module.asyncio,
            "create_subprocess_exec",
            AsyncMock(return_value=process),
        ):
            e = Event("hello")
            await self.bridge.incoming(e)
        self.assertEqual(len(e.sent), 1)
        self.assertNotIn("private", e.sent[0])

    async def test_other_platform_untouched(self):
        e = Event("hello", kind="webchat")
        await self.bridge.incoming(e)
        self.assertFalse(e.stopped)
        self.assertEqual(e.sent, [])


if __name__ == "__main__":
    unittest.main()

class WorkReceiptTests(BridgeTests):
    async def test_completion_returns_to_same_conversation(self):
        e=Event('任务')
        self.bridge.run_worker=AsyncMock(return_value={'state':'completed','answer':'已生成文件'})
        with patch.object(self.module.asyncio,'sleep',AsyncMock()):
            await self.bridge.watch_work(e,'a'*32)
        self.assertEqual(e.sent,['你交代的事有结果了：\n已生成文件'])
    async def test_uncertain_send_not_replayed(self):
        e=Event('任务');e.send=AsyncMock(side_effect=OSError('network'))
        self.bridge.run_worker=AsyncMock(return_value={'state':'completed','answer':'完成'})
        with patch.object(self.module.asyncio,'sleep',AsyncMock()):
            await self.bridge.watch_work(e,'a'*32)
        self.assertEqual(e.send.call_count,1)
    async def test_nonowner_never_dispatches_work(self):
        await self.bridge.incoming(Event('pair-test'))
        self.bridge.run_worker=AsyncMock()
        await self.bridge.incoming(Event('这个交给Codex干',sender='other',kind='qq_official'))
        self.bridge.run_worker.assert_not_called()
