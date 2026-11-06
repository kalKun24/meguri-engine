# Scrum config
- backend: github
- capacity: 10
- base_branch: main
- sprint: 3
- github.repo: kalKun24/meguri-engine

## Definition of Done
- 受け入れ基準をすべて満たし、各基準に対応するテストがある
- 既存を含むすべてのテストが通る
- code-review 枠と security-review 枠（extra-review 枠がいればそれも）の Agent が approve している
- UI を含む PBI は UI 仕様と一致している
- スプリントのデモの台本どおりに動く（リハーサルで確かめる）
- PBI のデモ用スクリプトを `godot --headless` で実行したとき、出力に ERROR と WARNING が無い。ただし、README に理由を注記した既知の出力は除く（Sprint 1 の振り返り T1-3。Sprint 2 の計画で PO が採用した）

## DoD 変更案
### T3-1: テストの出力にも ERROR と WARNING が無いことを DoD にし、警告の原因は分岐元と比べてから書く（Sprint 3 の振り返りより）
- 変更する DoD の文面案：「PBI のデモ用スクリプトと `scripts/test.sh` を実行したとき、出力に ERROR と WARNING（ObjectDB の leak、resources still in use を含む）が無い。ただし、README に理由を注記した既知の出力は除く。警告が出たとき、その原因を変更の外（ツールなど）に求めるには、その PBI の分岐元で同じコマンドを実行した結果を添える」
- なぜ（根本原因）:
  - ラムダが RefCounted をつかんで参照が循環する欠陥が、繰り返し出ている。Sprint 1 ではデモで、Sprint 3 ではテストで出た。
  - T1-3 はデモの出力だけを対象にしていたので、テストの終了時に警告が出ても、実装は完了とみなされた。
  - #24 では、developer と security-review の2つが、分岐元と比べないまま原因を「gdUnit4」と書いた。比べて新しい欠陥だと特定したのは、code-review だけだった。
  - 「新しく出た警告か」を比べる手順が無く、原因の帰属が推測に任されていた。
- 誰が: implement 枠（実装の報告に、test.sh の終了時の出力を貼る）。code-review 枠（同じコマンドで確かめ、警告があれば must にする）
- いつ: すべての PBI の、実装の完了時とレビュー時
- どこで: `scripts/test.sh` とデモの出力、実装とレビューの報告
- 何を: test.sh とデモの出力を、`ERROR`・`WARNING`・`leaked`・`still in use` で検索する。既知の出力以外が1件でもあれば、DoD を満たさない。
- どうやって:
  - 警告の原因を外に求めるときは、分岐元の作業ディレクトリで同じコマンドを実行し、その件数を報告に書く。
  - implement の依頼に、GDScript の落とし穴を短く書いて渡す。
    - signal にラムダを接続するとき、RefCounted を捕捉しない。メンバ関数につなぎ、終わったら disconnect する。
    - ラムダは外のローカル変数を値で捕捉する。数えるときは配列やメンバ変数を使う。
- 効果の確認: Sprint 4 で次の2つを満たせば、効果ありとする。
  - テストの出力の警告が原因の差し戻しが0回であり、統合後のテストの出力に警告が0件である。
  - 原因を外に求めた報告に、すべて分岐元との比較が付いている。
- 行き先: DoD 変更案（Sprint 4 の計画で PO が採否を決める）
