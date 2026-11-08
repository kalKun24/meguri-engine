# #37 implement の報告（原文）
- 作業ディレクトリ：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-aa9cf4f59d7aacd8b
- ブランチ：scrum/37（分岐元 dfba147）。コミット：67a66de、e6c37a5、bf24868

status: done
ブランチ：`scrum/37`（分岐元 dfba147）。worktree：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-aa9cf4f59d7aacd8b
コミット（3つ）：
- 67a66de：1ターンの時間を測るデモ（変更前の測定）
- e6c37a5：凍結と set_seed の戻り値（基準1・2）
- bf24868：条件の組み立ての使い回し（基準3・4）

## summary
- **凍結**：`is_ended()` が true のとき、`add_stock`・`add_constant`・`add_flow`・`add_flow_expr`・`add_action`・`add_victory_condition`・`add_defeat_condition`・`set_simultaneous_priority`・`set_seed`・`validate` が、何も変えずに ERR_LOCKED を返す。`last_error` は「ゲームは終了している」になる。
  - `add_victory_condition` と `add_defeat_condition` の guard は、共通の `_add_condition` の先頭にある。
  - 終了は `game_ended` と `turn_finished` の発火前に確定する。そのため、受け手の中から呼んでも凍結される（テストで確認）。
- **set_seed**：戻り値を `Error` にした。成功すると OK を返し、`last_error` を空にする。終了後は ERR_LOCKED を返し、種と乱数の状態を変えない。
  - 呼び出し元の `AutoRunner.run` は、戻り値が OK でなければ「種を決められない」として、何も実行せずに止まる（error は ERR_LOCKED）。
  - README を直した。呼び出し元は `auto_runner.gd` の1か所だけだった。
- **条件の組み立て**：`_compile_conditions()` を新設し、`validate()` から呼ぶ。
  - 結果の命令列は、条件の辞書の `"program"` に持つ。補助変数とフローの `"program"` と同じ形なので、#45 は `_conditions[i]["program"].ops.size()` で数えられる。
  - `_judge` は評価するだけにした。`_add_condition` で `_validated = false` にする。
  - 組み立てと無効化は `_validated` / `validate()` の1か所にある。#46 は、`validate()` の `_compile_conditions()` の呼び出しを依存ごとの組み立てに差し替えれば載る。
  - エラー文は、`_condition_label`（名前をエスケープ）と `escape_expression`（抜粋）を通す。
  - 組み立ての回数は `_condition_build_count` で数える。テストで読むための private の数え方である。
- apply_action の反映の部分と `_evaluate_now` には手を入れていない（#39 との競合を避けるため）。
- `demo/freeze_demo.gd`（凍結のデモ）と `demo/condition_perf_demo.gd`（1ターンの測定）を足した。

## 経路の表（T5-1）
列1 有限性、列2 失敗の返し方、列3 上限、列4 エスケープ、列5 生のバイト列、列6 出力の長さと組み合わせ、列7 処理量。

| 入口 → 出口 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| 終了後の add_*・set_*・validate → ERR_LOCKED と last_error | 該当なし（数値を受けても評価前に返す） | ERR_LOCKED と固定の文で返す。状態は変えない。`HostileValues` の敵対的な値でも変わらない（hostile_end_test 既存＋新規の列挙） | 該当なし（引数を見ない） | 固定の文だけを出す。入力は出さない | 該当なし（文字列を見ない） | 固定文（短い）。入力は含めない | 該当なし（O(1)） |
| set_seed(int) → Error | 該当なし（int） | OK / ERR_LOCKED、成功で last_error を空にする | 該当なし（int の全範囲を受ける。極値のテストあり） | 該当なし（出力に値を出さない） | 該当なし | 該当なし | O(1) |
| `--seed` → AutoRunner → set_seed の戻り値 | 該当なし | ERR_LOCKED を `AutoRunResult.error` と `message` に返す | CLI 側の桁数の上限は既存 | message は `model.last_error`（固定文）と `error_string` | 該当なし | `ModelCheck.limit_last_error` を通す | O(1) |
| add_*condition の式 → validate() の組み立て → 命令列 | 組み立ては数値を作らない。定数の取り込み値は定義時に有限と検査済み | 組み立ての誤りは ERR_INVALID_DATA と last_error。`program` は null にし、`_validated` は false のまま | 式 1000 文字・深さ 50（パーサの既存上限）、定義の個数 1000 | 名前を `ModelCheck.escape`、原因を `escape_reason`、式を `escape_expression` で出す（共有一覧を全件流すテストあり） | 該当なし（GDScript の String） | `limit_last_error` と式の抜粋の上限。761 文字の式と 64 文字の名前でテスト | 下の節 |
| _judge → 命令列の評価 → 結果 | 評価の結果は `check_finite` を通す（既存）。NaN・無限大でターンを取り消す（既存テストが通る） | FAILED でターン全体を取り消す（既存） | 条件 1000 個 | 名前はエスケープ（既存） | 該当なし | 既存の上限 | 下の節 |

## 列挙表（T4-1）
列挙のコマンド：`grep -nE '^func (add_|set_|validate)' src/core/sim_model.gd`。結果は 11 件。テスト `test_every_mutating_function_is_covered` が `get_script_method_list()` で同じ列挙を自動で行い、`_CALLS` と一致するかを確かめる。関数が増えると、このテストが落ちる。

| 対象 | テスト名（test/core/sim_model_freeze_test.gd） |
|---|---|
| add_stock | test_frozen_add_stock |
| add_constant | test_frozen_add_constant |
| add_flow | test_frozen_add_flow |
| add_flow_expr | test_frozen_add_flow_expr |
| add_auxiliary | test_frozen_add_auxiliary |
| add_action | test_frozen_add_action |
| add_victory_condition | test_frozen_add_victory_condition |
| add_defeat_condition | test_frozen_add_defeat_condition |
| set_simultaneous_priority | test_frozen_set_simultaneous_priority |
| set_seed | test_frozen_set_seed（ほかに test_set_seed_after_end_keeps_seed_and_rng） |
| validate | test_frozen_validate |

- 各テストは次の点を確かめる。
  - 終了前は成功する呼び出しであること。
  - 終了後は ERR_LOCKED を返し、`last_error` が「ゲームは終了している」であること。
  - ストック・定数・フロー・アクション・条件・優先・シード・補助変数・範囲・ターン・乱数の状態を前後で比べて、変わらないこと。
  - 2回目の呼び出しも ERR_LOCKED であること（「次の操作も ERR_LOCKED」）。
- 受け手の中からの呼び出し：`test_frozen_inside_game_ended_receiver`、`test_frozen_inside_turn_finished_receiver_of_the_ending_turn`。
- 読むだけの関数が使えること：`test_read_functions_still_work_after_end`。

## 列7の規模と実測（T5-1）
測定の再現：`godot --headless --path . -s res://demo/condition_perf_demo.gd -- [--length=761] [--turns=3]`

| 軸 | 上限の値 | 掛け合わせる相手 |
|---|---|---|
| 個数 | 条件 990 個（定義の合計が 1000 個。ストックと定数が最低でも数個要る） | 1個あたりの大きさ、参照の広がり、ターン数（最大 100000） |
| 1個あたりの大きさ | 式 1000 文字（パーサの上限）。issue の規模は 761 文字 | 個数、参照の広がり |
| 参照の広がり | 全条件が同じ定数 k を参照する。アクションが毎ターン k を変えると、全条件を組み立て直す。鎖は無い（条件は補助変数を参照できない） | 個数×大きさ。ターンごとに繰り返す |

- 積：条件 990 個 × 式 761 文字（最大 1000 文字）× 同じ定数を毎ターン変えて全条件が組み立て直し × 100 ターン。
- 最悪の形は2つあり、デモに両方を入れた。
  - 形A：定数が変わらない。
  - 形B：毎ターン、アクションが定数 k を変える（全条件が k を参照）。

実測（990 個、1ターンの平均。環境差とばらつきあり。1000 文字の変更前は2ターンだけの測定）：

| 形 | 式の長さ | 変更前（dfba147） | 変更後 |
|---|---|---|---|
| A | 761 | 4208 ms（4195, 4164, 4266） | 1ターン目 4486 ms（組み立てを含む）、2ターン目以降 約 1270 ms |
| A | 1000 | 約 5741〜9256 ms（2ターン） | 1ターン目 5936 ms、2ターン目以降 約 1720〜1750 ms |
| B | 761 | 4573 ms | 約 4620 ms（毎ターン 約 4500 ms で変わらず） |
| B | 1000 | 6127 ms | 約 6065 ms |

- 形Aは、組み立てがなくなって 2ターン目以降が約 1/3 になった。残りは評価の時間で、式が命令列になっても減らない。
- issue の「約3.2秒」とは環境の差がある。この環境の変更前は 4.2 秒だった。
- **形Bは変わらない**。定数が変わると、全条件を組み立て直す。
- **積はモデル全体の上限で止まっていない：「上限なし」**（should として自分で報告する）。
  - 評価も含めた1ターンが約 1.3〜4.6 秒で、100000 ターンなら数日になる。
  - #45（命令数の上限）と #46（依存する式だけを組み立て直す）の範囲である。

## テスト
- 件数：470 件（分岐元は 452 件。新規は freeze 14、condition_build 13、auto_runner 1）。0 failures、0 orphans。
- `scripts/test.sh` の ERROR は冒頭の debugger ポートの2行だけ。WARNING・leaked・still in use は 0 件。
- `git status --short` は、テストの前後で未追跡のファイルが増えていない（`.uid` と `addons/`、`reports/` は意図したもの、または git の対象外）。
- 不可視文字の Grep：変更したファイルで 0 件。テストの不可視文字は `char(0x…)` で作っている。

## guard を外したときの確認（結果はコミットに残していない）
- 凍結の guard を1つずつ外した。対応する `test_frozen_*` が10関数すべてで落ちた。
  - add_stock、add_constant、add_flow、add_flow_expr、add_auxiliary、add_action、`_add_condition`（victory 側）、set_simultaneous_priority、set_seed、validate。
- `_add_condition` の `_validated = false` を外すと、`test_condition_added_alone_after_validation_is_built` が落ちる。
- 毎ターン組み立て直す（`validate` の末尾で `_validated = false`）と、`test_conditions_are_built_once_not_per_turn` が落ちる。
- 組み立てエラーのエスケープを外すと、`test_build_error_escapes_name` が落ちる。
- 組み立てエラーの抜粋を外すと、`test_build_error_excerpts_long_expression_and_stays_within_limit` が落ちる。

## demo
- 凍結：`godot --headless --path . -s res://demo/freeze_demo.gd`。
  - ターン2で勝利して終わる。
  - その後に11個の関数を順に呼ぶ。全行が `Locked`、「ゲームは終了している」、状態「変わらない」と出る。
  - `set_seed(99)` の後も `get_seed() = 7` のままである。
- 時間：`godot --headless --path . -s res://demo/condition_perf_demo.gd -- --turns=3`。
  - 条件 990 個×761 文字で、形A・形Bのターンごとの ms が出る。
  - 変更前の値は、`git checkout dfba147` に demo だけを持ち込めば同じコマンドで並べて測れる。上の表に変更前の値を記録した。

## assumptions
- `add_auxiliary` も凍結の対象にした。issue の対象一覧には無いが、ストーリー「終了後はモデルが一切変わらない」と、列挙（`add_` で始まる公開関数）に含まれるためである。不要なら guard の1行と、テストの1行を外せばよい。
- `validate()` の凍結は、終了後に呼ぶと組み立て済みでも ERR_LOCKED を返す。`step`・`advance_turn` は終了後に先に ERR_LOCKED を返すので、内部の呼び出しとは衝突しない。
- ターンが失敗して取り消されると、スナップショットの復元で `_validated` が元の値（未組み立てなら false）に戻る。次のターンで組み立て直す。これは分岐元の設計のままで、失敗したターンの再試行でだけ起きる。
- 条件の式からは補助変数を参照できない。これは分岐元の動作のままである（`_parse_checked` と同じ名前空間）。
- 「後から足したストックの名前を使う条件」は、ストックを先に足し、その名前を使う条件を後から足す形と解釈した。条件は定義時に名前を検査するため、条件を先に定義して後からストックを足す形は成立しない。
- `_condition_build_count` は、テスト用の数え方として private のまま足した。公開 API は増やしていない。
- gdUnit4 は、この環境で、1つのテストが失敗するとスイートの残りを実行しなかった。guard を外す確認は、関数ごとに1回ずつ別の実行で行った。

## unresolved
- **should（自分で報告）**：列7が「上限なし」。形B（毎ターン定数が変わる）では 990 条件×761 文字で 1 ターン約 4.5 秒かかり、モデル全体の上限が無い。→ #45 の受け入れ基準（命令数の上限）と #46（依存する式だけを組み立て直す）。
- 評価時間（形Aで約 1.3 秒／ターン）は、組み立てを使い回しても残る。評価の速さは #45 の上限で間接的にしか抑えられない。
