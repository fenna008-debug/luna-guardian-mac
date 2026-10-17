"""One bounded local synthesis. Never keep models resident or queue speech."""

import fcntl
import json
import os
import subprocess
import time
from pathlib import Path

ROOT = Path.home() / "Library/Application Support/LunaCompanionMac/runtime"


def synthesize(base, request):
    ja = str(request.get("ja", ""))
    zh = str(request.get("zh", ""))
    if not 1 <= len(ja) <= 100 or not 1 <= len(zh) <= 120:
        raise ValueError("语音文本过长")
    lock = (ROOT.parent / "voice-bridge/play.lock").open("a")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise ValueError("语音正在处理")

    def pressure():
        return subprocess.run(
            ["/usr/sbin/sysctl", "-n", "kern.memorystatus_vm_pressure_level"],
            capture_output=True,
            text=True,
            timeout=2,
        ).stdout.strip()

    if pressure() == "4":
        raise ValueError("严重内存压力，保留文字")
    target = base / "dialogue.wav"
    target.unlink(missing_ok=True)
    env = {**os.environ, "OMP_NUM_THREADS": "1", "MKL_NUM_THREADS": "1"}
    p = subprocess.Popen(
        [
            str(ROOT / "speech-env/bin/python"),
            str(
                Path(
                    "/Applications/露娜电脑管家.app/Contents/Resources/synthesize_once.py"
                )
            ),
        ],
        stdin=subprocess.PIPE,
        stdout=(base / "synthesis.log").open("w"),
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
    )
    try:
        p.stdin.write(json.dumps({"ja": ja, "output": str(target)}))
        p.stdin.close()
        start = time.monotonic()
        while p.poll() is None:
            time.sleep(0.75)
            rss = subprocess.run(
                ["/bin/ps", "-o", "rss=", "-p", str(p.pid)],
                capture_output=True,
                text=True,
                timeout=2,
            ).stdout.strip()
            if (
                pressure() == "4"
                or int(rss or 0) > 4200000
                or time.monotonic() - start > 85
            ):
                (base / "limit.json").write_text(
                    json.dumps(
                        {
                            "rssKB": int(rss or 0),
                            "pressure": pressure(),
                            "seconds": time.monotonic() - start,
                        }
                    )
                )
                raise ValueError("本次语音达到内存或时间上限，保留文字")
        if p.returncode or not target.exists():
            raise ValueError("语音未生成，保留文字")
        return {"path": str(target), "ja": ja, "zh": zh}
    finally:
        if p.poll() is None:
            p.terminate()
            try:
                p.wait(timeout=2)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait()
        lock.close()
