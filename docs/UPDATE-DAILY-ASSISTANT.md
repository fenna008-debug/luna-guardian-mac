# Daily assistant update — 2026-10-18

Small, allowlisted actions now execute locally before delegation: open supported applications, set volume, mute, sleep, and confirmed shutdown/restart. Power confirmation expires in two minutes and is channel-specific and consumed once. Tests mock power actions; no live shutdown was performed. QQ implicit delegation requires high task complexity. Music defaults to NetEase, but this Mac build only requests opening the player: playback, pause, next-track and song search are NOT connected yet and return an honest limitation.

Filename search scans Desktop, Documents and Downloads with limits on time, entries and result count. It does not follow symlinks, read file contents, or search excluded application/dependency/Codex directories. No match means no match in the searched scope, not proof that no such file exists anywhere.

New topic archives recent conversation while preserving long-term memory, tasks, course schedule and fortune. Desktop and QQ contexts remain separate. Pause speech lasts fifteen minutes, can be resumed, and is shared by desktop and QQ. The background panel shows speech, observation, chat and computer-care state; it does not embed Codex into chat. Conversation text is 16 pt, with a solid dark surface.

Course schedules are local private data. Reminder checks use configured real teaching dates and run while Luna is running, awake and unlocked. A before-class reminder and a known-game foreground warning are each emitted once per course. Browser video/game inference is not claimed. The repository does not include the owner's timetable or memories.

QQ file extraction now covers HTML disguised as XLS (including Japanese encodings), BIFF XLS, XLSX/XLSM values, PPTX text/tables, HTML, RTF/DOC/ODT via macOS conversion, supported image OCR, and additional plain-text extensions. Existing PDF/DOCX handling remains. Limits and truncation are reported; scanned PDFs and embedded slide images are not OCR'd automatically. Mac file OCR requires compiling FileOCR.swift into LunaFileOCR in the plugin directory. Explicit document-memory requests use only actually extracted recent text and retain source provenance.

Validation: 81 backend tests, 52 QQ tests, Swift build, installed signature verification, real course-file extraction, live background-panel rendering and pause/resume controls. Power tests use a mock runner. No new real outbound QQ test was sent. Screen-capture authorization must be checked again after native app updates; its presence alone is not proof of a complete capture/OCR/model response.

The user asked Mac and Windows assistants to adopt the same capabilities and to explain needed updates and carry out authorized recoverable updates. This is a coordinated implementation requirement, not a claim that an unattended self-updater or arbitrary software-upgrade service already exists. Preserve each companion's persona, voice and stored data. Report actual installed results and unfinished items.
