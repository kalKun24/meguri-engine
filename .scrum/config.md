# Scrum config
- backend: github
- capacity: 10
- base_branch: main
- sprint: 6
- github.repo: kalKun24/meguri-engine

## Definition of Done
- 受け入れ基準をすべて満たし、各基準に対応するテストがある
- 既存を含むすべてのテストが通る
- code-review 枠と security-review 枠（extra-review 枠がいればそれも）の Agent が approve している
- UI を含む PBI は UI 仕様と一致している
- スプリントのデモの台本どおりに動く（リハーサルで確かめる）
- PBI のデモ用スクリプトと `scripts/test.sh` を実行したとき、出力に ERROR と WARNING（ObjectDB の leak、resources still in use を含む）が無い。ただし、README に理由を注記した既知の出力は除く。警告が出たとき、その原因を変更の外（ツールなど）に求めるには、その PBI の分岐元で同じコマンドを実行した結果を添える（Sprint 1 の振り返り T1-3 を、Sprint 3 の振り返り T3-1 で広げた。Sprint 4 の計画で PO が採用した）

## DoD 変更案
- （Sprint 6 の振り返り、T6-1）他の制作者のモデルを読み込む経路は、最悪の形で、定義の時間が10秒以内、定義の後に保存される量（静的メモリの増加）が1GB 以内に収まる。超える場合は、上限で拒否する。
  - 理由：#45 で、アクションの式の保存量に上限が無く、外挿で約60GB・約10分に達しうることが、security の実測で初めて分かった。「上限なし」の見積りを must にするかの天井が決まっていないため、判定がレビュアーの感覚になっていた。
  - 値（10秒・1GB）はスクラムマスターの仮置きである。PO が次の計画で採否と値を決める。
