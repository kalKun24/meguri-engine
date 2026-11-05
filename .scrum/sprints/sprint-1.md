# Sprint 1
- phase: retrospective
- goal: スプリントの終わりに、PO は README の手順でテストを流して全件の通過を確かめ、ストックがフローでターンごとに一斉に動く様子と、書き間違えた式の誤りが位置つきで指摘される様子を、デモ用のスクリプトで見られる。
- started: 2026-11-05T20:51:41+09:00
- base_branch: main

## 対象 PBI
| PBI | points | ui | 担当構成 | 状態 | 差し戻し | ブランチ | 作業ディレクトリ |
|---|---|---|---|---|---|---|---|
| #1 | 3 | no | game-developer | accepted | 0 | scrum/1 | /home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a043281520f1928a3 |
| #2 | 3 | no | game-developer | accepted | 0 | scrum/2 | /home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a8ea8e9d4c5009fd8 |
| #9 | 3 | no | game-developer | accepted | 0 | scrum/9 | /home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-ad8d61f18b9368503 |

## デモ台本
| # | PO の操作 | 期待する結果 | PBI |
|---|---|---|---|
| 1 | README の手順でテストを実行する | すべてのテストが通ったと表示される | #1 |
| 2 | PR の Checks 欄と、意図的に失敗させたときの記録を開く | 成功と失敗がそれぞれ Actions に出ている | #1 |
| 3 | デモ用のスクリプトで A→B→C のモデルを3ターン進める | 各ターンのストックの値と、turn_finished で受け取ったターン番号が表示される | #2 |
| 4 | フローの定義順を入れ替えたモデルで3と同じことをする | 3と同じ値が表示される | #2 |
| 5 | 式のデモ用スクリプトに、正しい式と誤った式（`population * `、`a.b`、`OS.get_name()`、閉じていない括弧）を渡す | 正しい式は構文木が表示され、誤った式は原因と文字位置つきのエラーが表示される | #9 |

## 実行計画
- 3件とも ui: no のため、design 枠は使わない。implement は game-developer、レビューは code-reviewer・security-auditor・data-scientist が担う。
- #1 を先に作る。#2 と #9 は互いに依存しないため、#1 のブランチから積み重ねて並行して作る。
- #1 が却下された場合、#2 と #9 はそのままではマージできない。
- #1 では、Godot 本体と gdUnit4 を、システムではなくユーザのディレクトリ（`~/.local` の下など）に導入する（PO 承認済み）。
- 積み重ねの順序：`main` ← `scrum/1` ← `scrum/2`、`main` ← `scrum/1` ← `scrum/9`。#2 は `src/core/`、#9 は `src/expr/` に置き、衝突を避ける。
- 選ばなかった PBI：#10（入れると12ポイントで capacity 超過）、#11・#4（#10 に依存）、#7（入れると11ポイントで capacity 超過）。

## Agent 実行ログ
| PBI | Agent | 目的 | tokens | tool_uses | 所要時間 |
|---|---|---|---|---|---|
| #1 | game-developer | implement | 86681 | 64 | 433s |
| #1 | data-scientist | review | 19121 | 2 | 22s |
| #1 | security-auditor | review | 17663 | 6 | 27s |
| #1 | code-reviewer | review | 21933 | 9 | 77s |
| #2 | game-developer | implement | 31332 | 20 | 102s |
| #2 | security-auditor | review | 18893 | 6 | 30s |
| #2 | data-scientist | review | 24342 | 6 | 63s |
| #2 | code-reviewer | review | 26898 | 7 | 66s |
| #9 | game-developer | implement | 66034 | 32 | 253s |
| #9 | data-scientist | review | 21878 | 5 | 33s |
| #9 | code-reviewer | review | 35030 | 11 | 62s |
| #9 | security-auditor | review | 35241 | 10 | 74s |
| 統合 | game-developer | demo | 58433 | 30 | 153s |
| #2 | game-developer | rework | 74473 | 6 | 46s |
| #2 | code-reviewer | review | 27846 | 4 | 48s |

## 記録
- 計画は 2026-11-05 に PO が承認した。チーム編成と DoD の変更案は無かった。

### #1 implement の報告
- Godot 4.7.1 stable と gdUnit4 v6.2.3 に固定した。draft PR #13。CI の成功 run 42022965513・42023246682、失敗させた run 42023098068。
- assumptions：
  - 最新安定版は 4.7.2 だが、gdUnit4 v6.2.3 の対応表に無いため 4.7.1 を選んだ（PO 判断事項：レビューで示す）。
  - gdUnit4 公式の Action は使わず、CI も手元と同じ scripts/setup.sh・scripts/test.sh を呼ぶ。「Action の版の固定」は actions/checkout の SHA 固定で満たしたとみなした（PO 判断事項）。
  - gdUnit4 は git に含めず、setup.sh で導入する。README は Linux x86_64 のみである。
- unresolved：
  - テスト実行時に debugger ポートの ERROR 出力が出る（無害で、README に注記した）。
  - detached HEAD の案内が出る。
  - CI で毎回 Godot を DL する（キャッシュは無い）。
  - 4.7.2 への更新は別の PBI が要る。

### #1 レビュー（差し戻し0回で approved）
- code-review：approve。must 0、should 3（import の出力を捨てている、CI のキャッシュが無い、detached HEAD の案内）。
- security-review：approve。must 0、should 4（gdUnit4 をタグだけで固定しコミット SHA の照合が無い、SHA-512 の出所の記録が無い、checkout に `persist-credentials: false` が無い、`unzip -o` で上書き展開している）。
- extra-review：approve。must 0、should 4（シード再現テストにゴールデン値が無い、gdUnit4 のタグ固定、import の出力を捨てている、Python 側の版固定は検証機能の PBI で行う）。
- should の指摘は、改善 PBI の候補として振り返りで扱う。複数の枠が重ねて指摘した点は、gdUnit4 のコミット SHA 固定（2枠）と import の出力を捨てている点（2枠）である。

### #2 implement の報告
- `SimModel`（RefCounted）を src/core/sim_model.gd に作った。テストは12件（新規10件）が通った。デモは `godot --headless --path . -s res://demo/stock_flow_demo.gd` で実行する。
- assumptions：
  - 定数は定義と取得だけを行い、step では使わない。
  - ストックの負値は許す。
  - フローの量は定義時に固定する。
  - エラーは `Error` コードと `last_error` で返す。
- unresolved：
  - デモの終了時に ObjectDB leaked の警告が出る。
  - 未定義の名前を get_stock に渡すと、NAN と last_error を返す。この方式が妥当かを、レビューで判断してもらう。

### #2 レビュー（差し戻し0回で approved）
- code-review：approve。must 0、should 3。
  - デモの ObjectDB leaked は、ラムダの参照循環が原因と見られる。
  - get_stock の NAN 返しは許容する。ただし、has_stock で先に確かめる前提を docstring に書く。
  - 定義に失敗した後、同名で再定義できることのテストが無い。
- security-review：approve。must 0、should 5。
  - 空の名前を受け付ける。
  - NaN・無限大を受け付ける。
  - 定義数と名前の長さに上限が無い。これは形式の PBI で扱う。
  - last_error が成功時にクリアされない。
  - NAN で失敗を返すと、正規の値と区別できない。
- extra-review：approve。must 0、should 4。
  - float の加算順によって、最下位ビットに差が出る。
  - NaN・無限大を受け付ける。
  - step を「量の計算・集計・反映」の3段階に分けると、後続の PBI の差分が小さくなる。
  - 自己ループ・複数の流入出・負値・失敗時に状態が汚れないことのテストが無い。
- 3枠が重ねて指摘したのは、NaN・無限大の受け付けと last_error・NAN 返しの扱いである。#10（式の評価）で扱うのが自然なので、振り返りで改善 PBI か #10 への追記として提案する。

### #9 implement の報告
- src/expr/ に6つのクラスを作った（RefCounted）。テストは38件（新規36件）が通った。デモは `godot --headless --path . -s scripts/demo_expr_parse.gd` で実行する。
- assumptions：
  - 比較は左結合とした。
  - 名前は ASCII の文字だけを受け付ける。
  - 数値は `123` と `1.5` の形だけを受け付ける。
  - 深さとして数えるのは、括弧・関数呼び出し・単項 `-` である。
  - `Vector2(1, 2)` は構文上は受理する。拒否するのは #10 の評価側の役目とした。
- unresolved：
  - 式に日本語の名前を書けるようにするか（PO 判断事項）。
  - #10 で、エラー位置の持ち方を揃える必要がある。
  - デモの置き場所が、#2 の `demo/` と #9 の `scripts/` で揃っていない。

### #9 レビュー（差し戻し0回で approved）
- code-review：approve。must 0、should 3。
  - #2 と同じ場所に README の節を足しているので、マージ時に衝突する。
  - デモの置き場所を `demo/` に揃える必要がある。
  - `_describe` は軽微な点で、対応は要らない。
  - 型コンストラクタの拒否は、#10 の許可リストに引き継ぐ。
- security-review：approve。must 0、should 3。
  - 400 桁の数値リテラルが inf になる。
  - `format()` が改行などの制御文字をそのまま出力し、ログ注入の余地がある。
  - 左結合の連なりで、木の深さが約 500 になる。この点は #10 以降で、評価を反復で書くか前提として明記する。
  - 文字列から処理を呼べる経路は無いことを確かめた。
- extra-review：approve。must 0、should 4。
  - `1e3` と日本語の名前に対するエラー文面が分かりにくい。
  - `0 < x < 10` が黙って `(0<x)<10` になる（PO 判断事項）。
  - 巨大な数値が inf になる。
- 2枠が重ねて指摘したのは、巨大な数値リテラルが inf になる点である。#10 の受け入れ基準に「非有限のリテラルは位置つきエラー」を足すことを、振り返りで提案する。

### 実行フェーズの終了
- 3件とも、差し戻し0回で approved になった。blocked は無い。
- レビューで PO に示す判断事項：
  1. Godot を 4.7.1 に固定したこと（4.7.2 は gdUnit4 の対応表に無い）。
  2. gdUnit4 公式の Action を使わない CI にしたこと。
  3. 式に日本語の名前を書けるようにするか。
  4. 比較を連ねた式（`0 < x < 10`）をエラーにするか。

### デモの準備
- 統合ブランチ：`scrum/sprint-1`。作業ディレクトリは /home/kal24hi/Projects/meguri-engine/.claude/worktrees/sprint-1 である。
- 取り込みの順序は scrum/1 → scrum/2 → scrum/9（すべて `--no-ff`）である。
  - scrum/9 の取り込みで、README の「デモ」節が衝突した。implement が両方を残す形で解消した（3baef35）。
  - 同じコミットで、code-review の指摘どおり #9 のデモを `demo/expr_parse_demo.gd` に移した。
- 統合後のテストは48件で、すべて通った。
- デモの場所は .scrum/demos/sprint-1/（README.md、demo.sh、rehearsal.md）で、回は 1 である。
- リハーサル：
  - 1度目の通しで、場面3・4の終了時に ObjectDB leak の WARNING と ERROR が出たので、不一致とした。
  - implement が `demo/stock_flow_demo.gd` のシグナル接続を直した（6afa2fb）。code-review は approve で、should が1件ある（bind も model を強参照するので、警告が消えた理由をコメントで説明するか、disconnect する形にする）。
  - 2度目の通しでは、5場面すべてが一致した。

### スプリントレビュー
- PO が受け入れた。統合 PR #14 を main にマージした（8203e64）。#1・#2・#9 は PR の Closes で閉じた。
- マージ後に main でテストを実行し、48件すべてが通った（0 errors、0 failures）。
- PO の判断：
  1. 式の名前は半角英数字のままとし、エラー文面だけを直す。
  2. 比較を連ねた式（`0 < x < 10`）はエラーにする。
  3. 1と2に、`1e3` の文面の改善を合わせて、PBI #15「式の書き間違いを直し方の分かる言葉で知らせる」（new、priority:4）を作った。
  4. Godot 4.7.1 への固定と、手元と同じスクリプトで回す CI の形について、PO は「見直したい」と答えた。見直す中身は振り返りで PO に聞き、PBI にする。
- 後片付けとして、PBI と統合ブランチの worktree・ローカルブランチ・リモートブランチ（scrum/1・2・9・sprint-1）を削除した。draft PR #13 は、#14 のマージで中身が main に入ったため、GitHub 上でマージ済みの扱いになった。

## デモの判定
| 回 | 日時 | 判定 | PO の指摘 | 原因の PBI | 対応 |
|---|---|---|---|---|---|
| 1 | 2026-11-05T21:18:12+09:00 | 受け入れ | — | — | マージした |
