# 1.9.1 — Natural conversation delegation

Luna accepts explicit Codex delegation with recent same-channel context, or classifies explicit complex action requests. Small talk, quoted instructions and malformed classifier results do not dispatch tasks. The chat has no task shortcut or persistent task card; execution history remains in the notebook. Persona, Japanese voice, memory, daily fortune and observation behavior are preserved.

QQ private owner routing adds memories, todos, search, existing fortune, reading records and background delegation with progress/cancel/result queries. Incoming request IDs suppress duplicate dispatches. Completion callbacks target the original private conversation and do not block later messages.

Validation: 72 desktop/backend tests, 37 bridge tests, native Swift build and code-sign verification, real local Codex job with file creation and result readback. No new live QQ outbound test was sent. Screen permission was reassociated after installation; permission alone does not establish a fresh end-to-end observation result.

Reference: AAAAGENT conversation/context/receipt concepts; independently implemented with official codex exec, without its private IPC implementation.
