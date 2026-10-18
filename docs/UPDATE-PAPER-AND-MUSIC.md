# Japanese paper reading and existing NetEase client

The macOS Services menu now accepts explicitly selected text with “用露娜翻译成中文” and “交给Codex精读选区”. Apps that do not expose text services, including some custom PDF views, may not show these entries. Scanned PDFs need OCR; there is no invisible background selection reader. Selections are limited to 6,000 characters. The pet menu also accepts an explicitly chosen PDF for a Codex reading task. Existing task receipts/cancellation remain in the notebook.

Translation uses a task-specific low-temperature request, an input-scaled output budget and explicit rejection of length-truncated output. Translation preserves original paragraphs, Chinese equivalents, terminology, references, negation and uncertainty. Japanese omissions and uncertain OCR must be marked rather than guessed. A selection is never claimed to represent a full paper. The reading handoff distinguishes PDF and printed page numbers and adapts to humanities arguments and primary sources. Requests reference the separately installed `codex-research` and `nature-reader` skills; the skills themselves are not bundled here. A prompt is not an accuracy benchmark; real paper-level validation is still required.

Sources reviewed for skill selection:
- https://github.com/LIU-31415/codex-research (evidence-led research)
- https://github.com/Ricardo-Vae/codex-research-skills/tree/main/skills/nature-skills/nature-reader (bilingual source maps)

Music controls target the existing `com.netease.163music` app and its native Controls menu, with exact allowlisted play, pause, next and previous actions. They require Guardian Accessibility permission, never use arbitrary model-generated scripts, and return command acceptance rather than asserting audio was heard. QQ and desktop share an expiring native request queue; requests expire instead of running unexpectedly after a late launch. No account is migrated and no substitute player is installed. Song search is not yet provided by this change.

The macOS menu-control approach was checked against the actual installed app, with these references as background only:
- https://gist.github.com/XSAM/f892974da3bde281cf7f58f49539ba6a
- https://gist.github.com/irmowan/8ec09ddc3ebde11bea7d321c3ee145fc

Validation: 87 backend tests, 52 QQ tests and native build passed. Services entries appeared in TextEdit and an actual selected Japanese passage reached Guardian. Direct playback via the existing NetEase menu changed the playback control and advanced the timestamp. End-to-end Guardian playback requires its own Accessibility authorization; Codex Computer Use permission does not grant Guardian permission. One direct translation request timed out; a successful service-level result and full-paper assessment must be reported separately.
