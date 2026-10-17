# 露娜电脑管家 · Luna Guardian for macOS

住在桌面上的樱小路露娜：透明聊天、日语语音与中文字幕、屏幕感知、读书分享、抽签和电脑照看。日常对话使用可更换的 LLM 服务，只有高复杂度的工具操作任务或明确指定时才交接本机 Codex。

## 使用

需要 macOS 14+、Xcode Command Line Tools（Swift）和 Python 3。当前在 Apple Silicon Mac 上验证。

```sh
python3 -m unittest discover -s src -p 'test_*.py'
python3 build.py
open "$HOME/Library/Caches/LunaGuardianBuild/露娜电脑管家.app"
```

素材放在 `assets/`；若下载的是 `assets.zip`，构建脚本会自动解压。构建不会安装或替换已有桌宠。确认后可把生成的 app 拖到“应用程序”。不要同时启动多个版本。

右键桌宠 → **模型与联网 → LLM 服务与模型**，填写 Base URL、模型 ID 和可选 API Key。支持 OpenAI Chat Completions 兼容接口，可连接 Qwen、DeepSeek、OpenAI 兼容服务、LM Studio、Ollama 兼容入口等；只支持其他原生协议的服务需先通过兼容网关。输入 `/v1` 基址或完整 `/chat/completions` URL，不要求所有供应商使用同一个模型名。

修改配置后下次请求立即生效。同地址留空保留密钥；改地址清除旧密钥；本地无认证接口可以不填密钥。原生 Responses/Anthropic 协议目前未实现。Codex 为独立操作入口，不会因普通聊天服务故障而偷偷代答。

## 内容索引

- [使用场景](docs/SCENARIOS.md)：聊天、读屏、读书、语音、天气、抽签、系统照看。
- [配置与隐私](docs/CONFIGURATION.md)：接口、人设、模型依赖和权限。
- [验证与限制](docs/VERIFICATION.md)：实际测到的结果及未覆盖部分。
- `src/`：Swift 原生桌宠、Python 后端、语音与交接程序、测试。
- `src/persona_luna.txt`：从既有露娜陪伴项目整理的人设，可独立编辑并重新构建。
- `assets/` 或 `assets.zip`：动画图、抽签数据、固定日语语音与字幕。

本仓库公开项目源码与使用说明。密钥、私人服务地址、聊天记录、屏幕记录、电脑诊断、模型权重及原论文不包含在内。

读书感想使用可点击的读书字幕入口，记忆和任务收进二级菜单；清理与诊断在后台，不占聊天界面。参考项目见 [REFERENCES](docs/REFERENCES.md)。

构建产物默认放在本机缓存目录，避免云盘给 app 加入扩展属性而破坏临时签名；可用 `LUNA_BUILD_DIR` 指定其他本地目录。

仓库动态提醒每 15 分钟检查公开 GitHub API，在桌宠气泡中显示 Star 数净增加、新 Issue/PR 和留言。初次检查仅建立基线，不补报历史。详情见 [配置与隐私](docs/CONFIGURATION.md)。

读书字幕可直接点开对应手记并留言；大小只通过菜单调整，不响应滚轮或捏合缩放。公开前检查见 [SECURITY](docs/SECURITY.md)。

读书分享的字幕 120 秒内未点击时收成小书本未读提示，进入手记后消失；重启保留未读状态。每篇手记显示实际联网阅读时间。
