# #45 implement の報告（原文）
- 作業ディレクトリ：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a56abb94a16498ac6
- ブランチ：scrum/45（分岐元 scrum/37 の bf24868）。コミット：ff99f33、04fca11

status: done
コミット：ff99f33（基準1：上限と拒否）、04fca11（基準2：測定デモと add_* のドキュメント）

## summary
- `ModelCheck.MAX_TOTAL_OPS = 100000`（仮の値のまま採用。根拠は列7）。
- 補助変数・フロー（式のもの）・勝利/敗北の条件の式の命令数の合計に上限をかけた。
  - 数えるのは定義した時点である。`ExprCompiler.count_ops(root)`（構文木の節の数。節1つにつき命令が1つ出るので、組み立てた `program.ops.size()` と一致する。テストで確認）。
  - 合計は `SimModel._total_ops` に持つ。
- `add_auxiliary`・`add_flow_expr`・`add_victory_condition`・`add_defeat_condition` は、パース後、状態を変える前に検査する。
  - 超えるなら `ERR_OUT_OF_MEMORY`。last_error は「補助変数「x」を足すと、モデル全体の命令数が上限を超える（上限 100000、実際 100899。この式は 999 命令）」の形である。
  - 実際の数は足した後の合計である。モデルは変わらず、名前も登録されない。
  - 凍結（ERR_LOCKED）の検査が先にある。
- `validate()` には検査を足していない。数えるのは定義時で、add_* が拒否するので、validate 時点で合計は必ず上限以内である。issue の「add_* か validate」は add_* 側で満たした。
- `apply_action`・`_evaluate_now` には手を入れていない（#39 と競合しない）。
- `demo/ops_limit_demo.gd` を足した。

## T1-2 の should への対応
- 条件の命令数にも同じ上限をかけた（`test_conditions_alone_are_limited`）。
- null の扱い：数えるのは定義時の構文木の節の数であり、`program` の有無・新旧に依らない。
  - テスト：`test_null_and_stale_programs_do_not_change_the_count`、`test_limit_still_applies_while_some_programs_are_null`、`test_total_equals_sum_of_built_programs`。
- 上限の根拠：
  - security の実測は、990条件×1000文字（約 99 万命令）で毎ターン約 5.9 秒、評価時にだけ失敗する条件の再試行も毎回約 5.9 秒。約 6 マイクロ秒/命令である。
  - 100000 命令なら、同じ形で約 0.58 秒に収まる（下の実測）。再試行も同じ約 0.6 秒で止まる。
  - 命令数に対して時間は線形である（10000 命令で約 31〜57 ms）。
  - 仮の 10 万を維持した。

## 経路の表（T5-1。列1〜7）
| 入口 → 出口 | 1 有限性 | 2 失敗の返し方 | 3 上限 | 4 エスケープ | 5 生のバイト列 | 6 出力の長さ・組み合わせ | 7 処理量 |
|---|---|---|---|---|---|---|---|
| 補助変数・フロー・条件の式 → add_* の命令数の検査 → ERR_OUT_OF_MEMORY と last_error | 該当なし（数値を作らず整数を数える） | ERR_OUT_OF_MEMORY と last_error。成功で last_error を空にする。モデルは変わらない（`_state` の前後比較） | 合計 100000 命令（`MAX_TOTAL_OPS`）。1個の式は 1000 文字（既存）なので、1個は 1000 命令以下 | 名前は `ModelCheck.escape`（既存の `_fail` の経路）。式は出さず、数字だけ出す | 該当なし（名前は既存の検査を通る。エスケープ済み） | `limit_last_error`（1000 文字）に収まる。数字と名前だけの短い文 | 下の節 |
| 構文木 → count_ops | 該当なし（整数の加算） | 該当なし（失敗しない） | 木の節の数。式の長さの上限（1000 文字）で抑えられる | 該当なし（出力しない） | 該当なし | 該当なし | O(節の数)。明示的なスタックで、再帰を使わない |
| 命令数の合計（`_total_ops`）→ 保存される状態 | 該当なし（int。上限の検査を通ってから足す） | 該当なし | 100000 | 該当なし | 該当なし | 該当なし | O(1) |
| アクションの式 → 評価のたびに組み立て | 既存 | 既存 | 下の「アクションの式」 | 既存 | 既存 | 既存 | 下の「アクションの式」 |

## 列7の規模と実測（T5-1）
測定の再現：`godot --headless --path . -s res://demo/ops_limit_demo.gd -- [--turns=3] [--ops=100000]`

| 軸 | 上限の値 | 備考 |
|---|---|---|
| 個数 | 定義 1000（ストック・定数・フローを含む。実際の式は 990 個ほど） | 変更前から |
| 1個あたりの大きさ | 式 1000 文字 → 最大約 1000 命令 | 変更前から |
| 参照の広がり | 1つの名前（定数 k・補助変数 base）を全員が参照 | 定数が変わると、全条件を組み立て直す（#46 の範囲） |
| 積（変更前） | 990 × 1000 = 約 99 万命令 | 毎ターン約 5.9 秒（security の実測）。上限なし |
| 積（変更後） | 合計 100000 命令で止まる | 下の実測 |

上限いっぱい（命令数 約 10 万）の実測（3 ターン、1ターンの時間）：

| 形 | 命令数 | 1ターン目（組み立てを含む） | 2ターン目以降 |
|---|---|---|---|
| 1 補助変数 100 個×999 命令（大きさの最大） | 99900 | 約 565 ms | 約 163〜184 ms |
| 2 補助変数 990 個ほど×99 命令（個数の最大） | 98010 | 約 566 ms | 約 165〜169 ms |
| 3 ファンアウト：base を 999 個の補助変数が参照 | 96129 | 約 586 ms | 約 164 ms |
| 4 条件 100 個×約 1000 命令、毎ターン定数 k が変わる | 約 99700 | 約 558 ms | 約 558〜587 ms |
| 5 条件 990 個×99 命令、毎ターン k が変わる | 98010 | 約 558 ms | 約 563〜602 ms |

- 最悪は形4・5の約 0.58 秒/ターン（100 ターンで約 1 分）。変更前の 5.9 秒の約 1/10 である。
- 積は `MAX_TOTAL_OPS` で止まっている。「上限なし」ではない。
- 形4・5 の時間は、#46 で減らせる。この PBI の範囲外である。

### アクションの式
- アクションは評価のたびに組み立てる。1回の `apply_action` の最悪は、実行条件 1 つと効果 50 個、各 1000 文字で、約 51000 命令。1回あたり約 0.3 秒である（推定。直接は測っていない）。
- モデル全体の命令数には足されない。評価は呼ばれたアクションの 1 回分だけである。
- 既存の上限（MAX_ACTION_EFFECTS）で 1 回は有界なので、合計の上限には含めなかった。1ターンに何回でも `apply_action` を呼べば、その分かかる。

## 列挙表（T4-1）
列挙のコマンド：`grep -nE '^func (add_auxiliary|add_flow_expr|add_victory_condition|add_defeat_condition)|^func _add_condition' src/core/sim_model.gd`。結果は 5 件（`_add_condition` は勝利と敗北の共通）。

| 対象 | テスト名（test/core/sim_model_ops_limit_test.gd） |
|---|---|
| add_auxiliary | test_one_over_limit_is_rejected_for_each_kind（"補助変数"）、test_exactly_at_limit_is_accepted、test_rejection_then_smaller_definition_succeeds |
| add_flow_expr | test_one_over_limit_is_rejected_for_each_kind（"フロー"） |
| add_victory_condition | test_one_over_limit_is_rejected_for_each_kind（"勝利条件"） |
| add_defeat_condition | test_one_over_limit_is_rejected_for_each_kind（"敗北条件"）、test_conditions_alone_are_limited |
| 4種の合計 | test_total_counts_all_four_kinds |

## テスト
- 482 件（#37 の 470 件に新規 12 件）、0 failures。ERROR は既知の 2 行だけ。WARNING・leaked・still in use は 0 件。
- `git status --short` はテストの前後で変わらない。
- 不可視文字の Grep：変更したファイルで 0 件。

## guard を外したときの確認（コミットに残していない）
- `_check_total_ops` の判定を外すと、`test_one_over_limit_is_rejected_for_each_kind` が落ちた（ほかに 23 件）。
- `_total_ops += ops` の3か所を外すと、`test_exactly_at_limit_is_accepted` が落ちた。

## demo
`godot --headless --path . -s res://demo/ops_limit_demo.gd -- --turns=3`
- 上限いっぱいまで補助変数を足し、次の定義が Out of memory で拒否される（last_error に「上限 100000、実際 100899」）。
- 条件とフローも同じく拒否される。合計は変わらない。
- 5 つの形のターンごとの ms が出る。

## assumptions
- 数えるのは構文木の節の数（= 組み立てた命令の数）である。
- エラーコードは、定義の個数の上限と同じ `ERR_OUT_OF_MEMORY` にした。
- 実際の数は「足した後の合計」である。
- アクションの式は合計に含めない。
- 上限は 100000 のまま。
- `validate()` には上限の検査を足していない（add_* で必ず止まるため）。

## unresolved
- should（自分で報告）：アクションの式は、合計の上限に入っていない。1回の `apply_action` は最大約 5.1 万命令（約 0.3 秒）で有界だが、呼ぶ回数に上限は無い。合計に入れるかは PO の判断である。
- 形4・5（毎ターン定数が変わる）の約 0.58 秒/ターンは、上限だけでは減らない。#46 の範囲である。

---
# 手直し（差し戻し1回目）の報告（原文の要点。コミット 4b61cad）
- 指摘（security の must）：アクションの式が合計の上限に入らない。50効果×各1000字のアクションで1件あたり約63MB・約0.66秒。アクション数は名前の上限1000まで増やせる。
- 差分：add_action で、全効果のパースが終わった後・状態を変える前に、実行条件と全効果の命令数を count_ops で合算し、_check_total_ops で検査する。超えるなら ERR_OUT_OF_MEMORY（「アクション「x」を足すと、モデル全体の命令数が上限を超える（上限 100000、実際 N。この式は M 命令）」）。凍結の検査が先。
- テスト：488 件、失敗0。ERROR は既知の2行だけ、WARNING・leaked 0。
  - 追加：test_every_expression_defining_function_is_in_the_enumeration（get_method_list から add_* で引数名が expression か condition の関数を拾い、列挙と一致することを確かめる。5関数）、test_actions_alone_are_limited、test_action_counts_together_with_other_kinds、test_action_exactly_at_limit_and_one_over、test_rejected_action_leaves_the_model_unchanged、test_frozen_model_reports_locked_before_ops_limit_for_action。
  - 変更：test_total_counts_all_four_kinds を test_total_counts_all_five_kinds に改名し、アクションも数える期待に直した。test_one_over_limit_is_rejected_for_each_kind にアクションを足した。
- 実測（demo/ops_limit_demo.gd -- --turns=1 --ops=1000）：50効果×各999字＋条件 "1" のアクションは 49951 命令。受け付けたのは2個（合計 99906）、3個目は拒否（実際 149857）。定義の合計 2.13秒、拒否の1回 0.76秒。静的メモリの増加は 125.5 MB（受け付けた2個分。拒否した分は残らない）。
- ガードを外す確認：add_action の _check_total_ops を外すと4件が落ちた。
- 経路の表の変わった行（アクションの式 → last_error・保存される状態）：列2 ERR_OUT_OF_MEMORY と last_error、拒否でモデル不変。列3 実行条件と全効果の合計を MAX_TOTAL_OPS にかける。列4 アクション名は escape。列7 個数（1000）× 大きさ（50効果×1000字）× 参照の広がり（ストックと定数だけ）の積が 100000 命令で止まる。
- should（自分で報告）：パースの後に検査するので、拒否される呼び出しにも1回約0.76秒かかる（保存量は増えない）。既存の4関数と同じ構造である。
