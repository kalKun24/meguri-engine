# Scrum config
- backend: github
- capacity: 10
- base_branch: main
- sprint: 2
- github.repo: kalKun24/meguri-engine

## Definition of Done
- 受け入れ基準をすべて満たし、各基準に対応するテストがある
- 既存を含むすべてのテストが通る
- code-review 枠と security-review 枠（extra-review 枠がいればそれも）の Agent が approve している
- UI を含む PBI は UI 仕様と一致している
- スプリントのデモの台本どおりに動く（リハーサルで確かめる）
- PBI のデモ用スクリプトを `godot --headless` で実行したとき、出力に ERROR と WARNING が無い。ただし、README に理由を注記した既知の出力は除く（Sprint 1 の振り返り T1-3。Sprint 2 の計画で PO が採用した）
