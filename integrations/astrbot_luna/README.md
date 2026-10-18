# Mac Luna AstrBot bridge

Tested with AstrBot v4.29.1 on Apple Silicon. Supports the official QQ WebSocket adapter (`qq_official`) and text-only personal WeChat (`weixin_oc`). Uses the installed `/Applications/露娜电脑管家.app` persona and model configuration; no model credential is copied into this plugin.

## Use

- Private owner-paired text chat, explicit memory updates, region updates, task creation and configured-city weather.
- Send one PDF, DOCX, TXT, Markdown, CSV or JSON file, up to 20 MB. PDF reading covers at most 12 pages and 12,000 characters; image-only PDFs need OCR first. DOCX includes paragraphs and tables, excluding image text. The returned report states its actual reading scope.
- When model summarization times out, the bot returns extracted text as a file and explicitly says no summary was generated.
- Send audio up to two minutes for local Whisper recognition. Recognition may contain errors. Requests containing “语音”, “念给我” or “说给我听” request a short Japanese Luna voice reply with Chinese captions. Voice generation needs the existing local Luna GPT-SoVITS installation. “测试露娜语音” uses a fixed, clearly identified test sentence to diagnose transport independently of the LLM.
- “发成文件” exports a reply. Voice jobs are serialized, rate-limited to one per minute, and stop at critical memory pressure or the process budget. Models are unloaded when the worker exits.

Long-term memories/tasks share the desktop SQLite notebook. Recent remote context is separate. Owner-paired requests such as “看看电脑状况” now perform a fresh read-only CPU, memory-pressure, disk, battery and process snapshot without asking the LLM to invent status. Paired private chat also supports memory edits/deletion, todo completion/reopening, public search, today’s existing fortune and reading records. Natural requests can delegate bounded work to Codex, query progress/results or cancel the same remote job. Referential requests use remote-channel context only. Codex writes remain limited to the job workspace with a ten-minute limit.

## Installation and boundaries

Install the Python sources and metadata into the isolated AstrBot `data/plugins/luna_mac_bridge` directory. Install `requirements.txt` in that instance's environment. Download `Systran/faster-whisper-tiny` into `$ASTRBOT_ROOT/models/whisper-tiny`. Configure AstrBot's FFmpeg path for outgoing QQ audio. Set `PYTHONDONTWRITEBYTECODE=1` to avoid modifying signed desktop resources. Keep dashboard bound to loopback with strong authentication and disable the ordinary AstrBot provider pipeline to prevent duplicate replies.

Provision `data/plugin_data/luna_mac_bridge/owner.json` with `{"pair_hash":"<SHA256 of a random one-time pairing phrase>"}`. Generate at least 96 bits of randomness locally. Send the phrase only to the intended bot. Pairing consumes it and binds sender plus platform. Groups and unpaired senders are ignored. Credentials, owner state, conversations, model weights and runtime logs must remain outside the repository.

Create an independent QQ official bot through AstrBot's QR flow. The account owner must complete the official login and confirmations. Do not reuse another instance's WeChat login: that may disconnect its existing bot.

## Verification and limitations

Real QQ text reply, audio attachment reception/transcription, and outgoing text-file transport were observed. A freshly synthesized four-second Japanese test reply and matching Chinese captions arrived in the real QQ conversation. General model calls have intermittent timeouts; a successful fixed voice test alone does not prove arbitrary model-generated speech. File fallback has a local integration check. Thirty-seven offline tests cover owner access, delivery, source restrictions, document parsing, remote actions, duplicate suppression, cancellation isolation and result callbacks. The latest natural delegation was tested with a real local Codex job and result readback. New completion callbacks were tested with mock events, not a new live QQ outbound delivery. A failed callback is not retried blindly; the owner can ask for the result.

Run `python -m unittest discover -s integrations/astrbot_luna -p 'test_*.py'` using the dedicated environment.

Official setup: https://github.com/AstrBotDevs/AstrBot/wiki/zh-platform-qqofficial-websockets

## Daily assistant additions

See [daily assistant update](../../docs/UPDATE-DAILY-ASSISTANT.md) for local actions, new topics, temporary speech pause, supported extra file types and current music limitations. Build the file OCR helper with `swiftc FileOCR.swift -o LunaFileOCR -framework Vision -framework ImageIO -framework AppKit` and place it beside the plugin Python sources. Install the current requirements in the AstrBot environment. The helper reads only the supplied image file and does not require screen-recording permission.
