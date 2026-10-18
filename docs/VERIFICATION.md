# 验证与限制

既有 1.7.2 实机记录：原生 Swift 构建成功；31 项后端测试通过；普通窗口及音乐窗口自动 OCR 后，实际日语语音完成并显示中文字幕；一次语音约 10.6 秒。GPT-SoVITS 单次进程组峰值约 1.18 GiB。Codex 只读检查任务曾返回结果。原始记录含个人信息，不放入仓库。

1.8.0 新增：共享完整露娜人设、通用 OpenAI 兼容接口、无密钥本地模式、换地址清除旧密钥、阻止 API 重定向、闲聊省去额外分类调用、限制历史长度及输出预算、记录不含正文与密钥的最近请求时长。阅读感想共用同一 LLM 配置。

超时排查实测：TCP 建连约 0.13–0.19 秒；极短回复约 0.5 秒；任务分类约 1.72 秒；一次非流式普通回复超过 20 秒未完成；随后同类短流式请求首字约 1.02 秒、总计约 1.54 秒。证明服务可连接但响应有波动，不能仅据此断言服务器排队、负载或具体网络原因。未取得服务端日志。

限制：兼容协议不等于验证过所有供应商；生产聊天目前仍等待完整正文，未逐字显示。并非每项生活动作都有逐帧实机回归；自动关闭闲置应用未做破坏性验证。“凶”的独立固定音频尚未提供。阅读来源当前为四个已验证的公开来源，不是无限自主浏览。动态语音依赖外部本机模型环境。签名变化可能影响录屏权限。

最新源码：40 项测试通过，包括记忆增改删及去重、任务初始状态、工具记录过期清理保留聊天、天气不交接 Codex、低复杂度任务不交接、普通聊天只发一次模型请求。新的人设与本机时钟实测约 1.18 秒返回正确日期时间。原生 AppKit 手记窗口与书签入口随本版本构建。

留言和偏好测试加入后共 44 项通过；验证了失败保留评论、不擅自生成偏好、微调频率仍保留多样性。两个新增文学来源实际读取到 40 段和 18 段可用正文。新版替换后曾使录屏授权失效；已在系统设置移除旧条目、重新添加当前 app 并按系统提示重开，最终 CGPreflightScreenCaptureAccess 返回 true。

留言解释与偏好调整真实模型集成测试成功，约 2.42 秒；测试使用临时数据，没有修改用户阅读偏好。最终原生界面验证六组菜单和读书留言输入框均存在。

## 1.8.1

50 项 Python 测试通过。覆盖自然语言地区的实际数据库保存/更新、旅行/引述/否定不入库、编辑记忆拦截密钥、仓库提醒首次基线、去重、确认显示、取消 Star 与断网保留。新增提醒不调用模型。读书字幕直接进入对应手记，移除单独书本标记与滚轮/捏合缩放。

最终补充：54 项测试通过；包括译文与感想分离、旧手记补译保留原阅读时间、模型失败不写入假译文。读书字幕 120 秒，点击立即收起；未读提示进入手记后清除。

## 1.9.0 上传验证

57 项 Python 回归测试通过，包括新增的旧版记忆迁移、调用版本追踪、凌晨4点阅读清理和工具文本过滤。更新后的 build.py 包含 Daily.swift，已完整构建并通过签名验证。界面与播放验证、跨日限制见 [更新说明](UPDATE-1.9.0.md)。


## Direct Codex entry and QQ health snapshot (2026-10-18)

66 desktop Python tests and 17 bridge tests passed. Native Swift build and signature validation passed. A real background Codex job created and reread a receipt file; the native pet entry delivered a separate real completion into chat without opening Codex UI. Native immediate cancellation prevented a queued submission; runner cancellation tests verified a running child is terminated before a cancelled receipt is recorded.

The QQ paired-owner handler was exercised locally through its real worker, returning live system metrics to a mocked QQ event. This is not a claim that a new QQ network message was sent during the test. Worker files are loaded per request, so the installed bridge picks up the update without a bot restart. Only read-only snapshots are exposed remotely. No machine metrics, owner identifiers, credentials or logs are included in this repository.
