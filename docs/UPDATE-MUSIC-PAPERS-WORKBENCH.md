# Song requests, multilingual reading, and workbench

The desktop and paired QQ private chat now route explicit song requests to the installed NetEase player. Examples: “放《牵丝戏》” and “播放银临的《棠梨煎雪》”. The native controller replaces the search text, matches a song title and optional artist in the visible results, and requires the player title, artist when requested, pause button, and advancing playback position before reporting success. Requests expire and are serialized. A failed match or unavailable track does not count as playback. Generic small actions remain local. This uses the existing Accessibility authorization; ad-hoc signed app updates may require re-association in macOS Settings.

The background workbench replaces the text dump with four status cards: voice, window observation, computer care, and conversation/tasks. It uses larger text, consistent spacing, native icons, five-second refresh, and direct pause/resume/task/study controls. The conversational page receives no extra permanent task panel.

Translation now accepts other languages and outputs Simplified Chinese. It preserves original text, names, quotations, negation, qualifiers, and supplied page references. Academic requests use a neutral system prompt, low temperature, adequate output allowance, bounded sentence grouping, and SSE support. Incomplete streams and length-limited answers are not reported as complete translations. Completed groups before failure are retained locally as explicitly incomplete. Existing persona and Japanese voice remain unchanged for conversation.

Desktop PDF import and the QQ PDF worker share PDFKit extraction and local Vision OCR fallback for missing or damaged text layers. OCR output is marked for verification. The reader reports actual coverage: at most the first 12 pages and 12,000 characters; this is not whole-paper reading. Full-paper Codex handoff remains a separate explicit action. Private library files and model credentials are not included in this repository.

## Validation on the Mac

- 92 backend tests and 52 QQ integration tests passed; Swift build and code signature verified.
- Actual desktop song requests and actual messages in the paired QQ conversation played 银临《牵丝戏》 and then changed the player to 银临《棠梨煎雪》; QQ returned the verified result. QQ pause was also exercised.
- Native workbench screenshot checked for clipping, spacing, and legibility.
- Three real Zotero attachments tested for text extraction. PDFKit correctly extracted the readable Japanese article where pypdf produced corrupt glyphs; the scanned vocabulary table used OCR but requires manual verification of old characters and column order.
- A real Japanese introductory paragraph from PDF page 2 / printed page 4 translated successfully in 6.28 seconds, preserving the meaning that both sources must be considered. This was an excerpt test, not a claim to have checked the entire article.
- The longer English abstract still timed out, including a bounded grouped attempt. Short success and fast first-token output do not prove reliable completion of longer answers. Windows independently observed a stream stall too. Long-answer service reliability remains unresolved; partial output must not be presented as a complete translation.

Windows has received the requested feature scope, evidence, and limitations. Windows implementation and validation must be tracked separately from the Mac results.
