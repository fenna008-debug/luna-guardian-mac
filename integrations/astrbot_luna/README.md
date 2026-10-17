# Mac Luna AstrBot bridge

Tested with AstrBot v4.29.1 on Apple Silicon. This optional plugin connects the personal WeChat adapter (`weixin_oc`) to an installed `/Applications/露娜电脑管家.app`. It uses that app's local LLM settings and persona; no model API credential is copied into the plugin.

Supported: text chat, explicit memory updates, region updates, task creation, configured-city weather. Long-term memories and tasks share the desktop SQLite notebook. Recent chat context is separate to avoid simultaneous desktop/WeChat history writes. Images/files and outgoing voice are not implemented in this bridge. It does not invoke Codex or execute computer operations remotely.

Install `main.py`, `worker.py`, and `metadata.yaml` into the isolated AstrBot data/plugins/luna_mac_bridge directory. Bind the dashboard to 127.0.0.1, use strong authentication and disable the ordinary AstrBot provider pipeline. Keep runtime data outside this repository.

Before enabling WeChat, provision `data/plugin_data/luna_mac_bridge/owner.json` with `{"pair_hash":"<SHA256 of a random one-time pairing phrase>"}`. Generate the phrase locally with at least 96 bits of randomness; do not commit it. Send it only in your intended private bot conversation. Successful pairing permanently replaces the hash with the sender/platform identity. Unpaired senders, other platforms and group messages do not receive private data. Re-pair only by explicitly replacing this local owner state.

First log in to AstrBot and change its generated initial dashboard password yourself. Then create a Personal WeChat adapter using the official QR login flow. Use a distinct bot connection; do not import another instance's token. Whether the same WeChat bot can be logged into two instances simultaneously is not established by this integration.

A real Mac model round trip succeeded locally. Offline tests cover access control and reply delivery. Actual WeChat send/receive requires the user to complete QR login and pairing and has not yet been verified.

Run: `python3 -m unittest discover -s integrations/astrbot_luna -p 'test_*.py'`.

Official setup: https://github.com/AstrBotDevs/AstrBot/wiki/zh-platform-weixin_oc
