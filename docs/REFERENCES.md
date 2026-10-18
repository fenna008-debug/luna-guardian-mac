# 参考项目

- AIRI：https://github.com/moeru-ai/airi — 参考角色陪伴、桌面入口与模块化能力的方向；没有引入其完整运行时。
- Mem0：https://github.com/mem0ai/mem0 — 参考独立持久记忆及按需提取，而不是不断追加完整聊天历史；本项目使用轻量 SQLite 自行实现。
- Deep Agents：https://github.com/langchain-ai/deepagents — 参考将复杂工具任务与普通对话区分的方向；本项目不依赖其框架。

上述项目是架构参考，不意味着本项目实现了它们全部能力，也没有将其代码或许可证套用到第三方角色素材。

本次参考：
- AAAAGENT：https://github.com/phoiex/AAAAGENT — 借鉴来源可追踪的记忆、过期回应失效和执行状态分离思路；本次实现为本项目 Swift/Python 代码，没有引入其运行时或复制其代码。该项目使用非商业及署名许可，不能按 MIT 项目对待。
- luna-sama：https://github.com/annali07/luna-sama — 参考自然简短的角色台词和本地日语语音方向；保留现有语音流程，不上传模型权重。


## Direct Codex dispatch (2026-10-18)

Reviewed [AAAAGENT by phoiex and contributors](https://github.com/phoiex/AAAAGENT), especially `code/desktop-pet/harness/codex-app.ts`: its existing-App thread dispatch uses a version-pinned private IPC protocol. Luna does not copy or use that protocol. Its independently implemented direct entry uses [official non-interactive Codex](https://learn.chatgpt.com/docs/non-interactive-mode) and JSONL events, retaining bounded workspace-write permissions and truthful completion/cancellation receipts. Reference project license: [AAAAGENT Noncommercial and Attribution License 1.0](https://github.com/phoiex/AAAAGENT/blob/main/LICENSE).
