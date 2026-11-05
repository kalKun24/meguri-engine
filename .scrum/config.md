# Scrum config
- backend: github
- capacity: 10
- base_branch: main
- sprint: 1
- github.repo: kalKun24/meguri-engine

## Definition of Done
- 受け入れ基準をすべて満たし、各基準に対応するテストがある
- 既存を含むすべてのテストが通る
- code-review 枠と security-review 枠（extra-review 枠がいればそれも）の Agent が approve している
- UI を含む PBI は UI 仕様と一致している
- スプリントのデモの台本どおりに動く（リハーサルで確かめる）

## DoD 変更案
### T1-3: デモの出力に ERROR と WARNING が無いことを DoD にする（Sprint 1 の振り返りより）
- 追加する DoD の文面案：「PBI のデモ用スクリプトを `godot --headless` で実行したとき、出力に ERROR と WARNING が無い。ただし、README に理由を注記した既知の出力は除く」
- なぜ（根本原因）: PO に見せるデモの出力が乱れていないことを、DoD もレビューの基準も定めていない。そのため、#2 のデモのリーク警告は、実装時に unresolved として報告され、code-review も原因を特定していたのに、should のまま approve された。警告はリハーサルで初めて止まり、統合後の手直しに Agent を2回起動した（約10万 tokens）。
- 誰が: implement 枠（実行した出力を報告に貼る）、code-review 枠（同じコマンドで実行し、ERROR か WARNING があれば must にする）
- いつ: デモ用スクリプトを含む PBI の、実装の完了時とレビュー時
- どこで: `demo/` のスクリプトと、実装・レビューの報告
- 何を: デモ用スクリプトを実行し、出力に ERROR と WARNING が無いことを確かめる。
- どうやって: 報告に貼った出力を `ERROR` と `WARNING` で検索し、1件でも見つかれば DoD を満たさないとする。gdUnit4 の debugger ポートの出力のように、README に理由を注記したものは除く。
- 効果の確認: スプリント2のリハーサルで、出力の乱れによる不一致が0件であり、デモが原因の手直しが0回であれば、効果ありとする。
- 行き先: DoD 変更案（スプリント2の計画で PO が採否を決める）
