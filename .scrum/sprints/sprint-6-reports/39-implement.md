# #39 implement の報告（原文）
- 作業ディレクトリ：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-ad46157f468b26ff9
- ブランチ：scrum/39（分岐元 dfba147）
- 注：経路の表は、列の定義が依頼に無かったため、実装者が独自の解釈で書いた。正しい定義での表は、この下の「経路の表（作り直し）」に足す。

status: done
PBI #39、ブランチ scrum/39（分岐元 dfba147）、コミット1つ。

## summary
- 変更は src/core/sim_model.gd の apply_action、「新しい値の反映」のループだけである（+8/-2行）。ストックへ反映する直前に、_ranges から StockRange を引き、あれば `stock_range.apply(new_value)` で1回だけ収める。フローの更新と同じ関数・同じ辞書である。
- validate・_judge・終了判定・#37 に関わる箇所には触れていない。action_applied の引数も変えていない。
- apply_action のドキュメントコメントに、範囲に収めることを1文足した。
- 追加：test/core/sim_model_action_range_test.gd（13件、.uid つき）。demo/action_range_demo.gd。
- コミットを1つにまとめた理由（T3-3）：全基準が同じ1箇所の変更で、分けられない。

## check_finite の位置
- 効果の値の check_finite は、収める前の評価ループにある（既存、位置は変えていない）。
- 範囲の端は add_stock が有限であることを検査済みで、収めた後の値はその範囲の中にある。そのため非有限にはならない。
- `food = pow(10, 400)`（無限大）は、収める前に FAILED で拒否され、ストックは変わらない（テスト済み）。

## 経路の表（実装者の独自の解釈。列の意味が T5-1 と異なる）
| 入口→出口 | 1 入力 | 2 検証 | 3 反映 | 4 通知 | 5 失敗時 | 6 判定への影響 | 7 処理量 |
|---|---|---|---|---|---|---|---|
| apply_action → 範囲つきストック | 効果の式の値 | 評価ループで check_finite。範囲の端は add_stock で検査済み | 反映の直前に StockRange.apply で1回収める。最後の効果が勝つ点は従来どおり | 収めたことは通知しない。action_applied は従来どおり | 非有限は収める前に FAILED で拒否し、全体を取り消す | 勝敗の判定は収めた後の値を見る（テスト済み） | 該当なし。効果は最大50個で、範囲の判定は O(1) |
| apply_action → 範囲なしのストック | 同上 | 同上 | 収めない（これまでどおり増える） | 同上 | 同上 | 同上 | 該当なし（同上） |
| apply_action → 定数 | 同上 | 同上 | 範囲を持たないので対象外。_validated = false も従来どおり | 同上 | 同上 | 該当なし。判定は次の step で組み立て直す | 該当なし（同上） |
| フローの更新（step） | 変更なし | 変更なし | 変更なし | 変更なし | 変更なし | 変更なし | 該当なし |

## 列挙表
受け入れ基準に「全」「すべて」「各」を含むものは無い。該当なし。

## tests
- 全体：450件（変更前 437件に13件を追加）、failures 0。
- test.sh の ERROR は2件で、冒頭の debugger ポートの既知の2行だけである。WARNING・leaked・still in use は0件。
- `git status --short` で、テスト前後に未追跡ファイルは増えていない。addons/gdUnit4 は元のリポジトリからコピーした（git の対象外）。
- 不可視文字の Grep：不可視文字を扱う変更ではないので実施していない。

## 受け入れ基準とテスト名
| 基準 | テスト |
|---|---|
| 上限を超える効果を収め、成功する | test_effect_above_upper_is_clamped_and_succeeds |
| 下限を割る効果を収め、成功する | test_effect_below_lower_is_clamped_and_succeeds |
| 範囲内の値は変えない | test_effect_inside_range_is_unchanged |
| 片側だけの範囲 | test_one_sided_ranges |
| 範囲なしのストックはこれまでどおり増える | test_stock_without_range_still_grows |
| フローの無いストックも範囲の外に残らない | test_stock_without_flow_is_clamped |
| action_applied の引数が変わらない | test_action_applied_signal_is_unchanged |
| 削った量は消える | test_clamped_amount_is_lost_not_carried |
| 複数の効果。評価は実行前の値で、収めるのは反映の1回だけ | test_effects_evaluate_with_unclamped_values_and_clamp_once_at_reflection |
| 定数は対象外 | test_effect_on_constant_is_not_clamped |
| 非有限は拒否され、何も変わらない | test_non_finite_effect_still_fails_and_changes_nothing |
| 勝敗の判定が範囲内の値を見る（勝利側） | test_victory_judgement_sees_clamped_value |
| 勝敗の判定が範囲内の値を見る（敗北側） | test_defeat_judgement_sees_clamped_value |

## ガードを外した確認
- 範囲に収める分岐（`if stock_range != null:`）を `if false and ...` に変えて、新しいテストファイルだけを実行した。
- 落ちたもの（報告では「7件」と書いているが、列挙は8件）：
  - test_effect_above_upper_is_clamped_and_succeeds
  - test_effect_below_lower_is_clamped_and_succeeds
  - test_one_sided_ranges
  - test_stock_without_flow_is_clamped
  - test_clamped_amount_is_lost_not_carried
  - test_effects_evaluate_with_unclamped_values_and_clamp_once_at_reflection
  - test_victory_judgement_sees_clamped_value
  - test_defeat_judgement_sees_clamped_value
- 通ったもの（意図どおり。範囲を使わない、または対象外の基準）：範囲内の値、範囲なしのストック、シグナル、定数、非有限。
- 一時的な変更は戻した。コミットには残していない。
- gdUnit は1スイートで最初の失敗で止まる。全体実行では1件しか見えないので、スイート単体で実行して確かめた。

## demo
`godot --headless --path . -s res://demo/action_range_demo.gd` を実行する。次の出力になる。
```
food（下限 0、上限 100）= 50.0、gold（範囲なし）= 50.0
feast: OK -> food = 100.0、gold = 1050.0
famine: OK -> food = 0.0、gold = 50.0
```

## assumptions
- 経路の表の列1〜7は、上のとおり私の解釈である。
- 「複数の効果は最後が勝つ」は、add_action が同じ対象を2回書くことを拒否している（既存）。そのため、収める1回が最後の値への1回になる。
- 敗北側の判定テストは、「food < 0」が収めた値 0 では成り立たないことを使った。

## unresolved
なし。#8 と文言を揃える件は、このPBIの範囲では StockRange 側の説明（「削った量は消える」）をそのまま使うことで足りると考えた。#8 の実装時に確認が要る。

## 経路の表（作り直し。T5-1 の定義による。コードとテストは変えていない）
前提：このPBIの変更は、apply_action が、範囲つきストックへの反映の直前に StockRange.apply を1回呼ぶことだけである。新しい入口も出口も増えていない。

| 入口 → 出口 | 1 有限性 | 2 失敗の返し方 | 3 上限 | 4 出力のエスケープ | 5 生のバイト列 | 6 出力の長さと組み合わせ | 7 処理量 |
|---|---|---|---|---|---|---|---|
| A. アクションの入力（効果の式の計算結果）→ 保存される状態（_stocks。範囲つき） | 変更あり。反映の直前に、既存の check_finite が NaN・無限大を FAILED で拒否する。範囲の端は add_stock が有限だけを受けるので、収めた後も有限になる。非有限なら状態は変わらない。テスト：test_non_finite_effect_still_fails_and_changes_nothing | 変更あり。範囲を超える値は、エラーにせず収めて OK を返す。成功時は _succeed が last_error を空にする。テスト：test_effect_above_upper_is_clamped_and_succeeds（last_error が空かも見る）、test_effect_below_lower_is_clamped_and_succeeds。全体が成功か全体取り消しかは変わらない | 該当なし。この行で増える外部由来の値は無い。効果の個数は MAX_ACTION_EFFECTS（50）で既存の add_action が止める。収める処理は個数を増やさない | 該当なし。この行の出口は保存される状態（数値）で、文字列を出さない | 該当なし。数値だけを扱い、バイト列を受けない | 該当なし。この行の出口は数値で、出力する文字列が無い | 変更あり、増加なし。収める処理は効果1個につき比較2回で、効果は50個まで。最悪の形は「50個の効果が、すべて範囲つきストック」で、比較100回であり、評価の費用に比べて無視できる。実測はしていない |
| B. アクションの入力（効果の式の計算結果）→ 保存される状態（_constants） | 変更なし。check_finite は同じ。テスト：test_non_finite_effect_fails_and_rolls_back（既存） | 変更なし。定数には範囲が無いので収めない。テスト：test_effect_on_constant_is_not_clamped | 該当なし。変更なし | 該当なし。出口が数値である | 該当なし。数値だけを扱う | 該当なし。出力する文字列が無い | 該当なし。変更なし。定数への反映は1個につき代入1回 |
| C. アクションの入力 → エラー文（last_error） | 変更なし。非有限の拒否の文は check_finite が作る | 変更なし。範囲を収めるのは失敗ではないので、新しいエラー文は増えていない。成功時に last_error が空になることは test_effect_above_upper_is_clamped_and_succeeds が確かめる | 変更なし。last_error は ModelCheck.limit_last_error（1000 文字）で切る既存の経路を通る | 変更なし。差分は新しい文字列を作らない。既存の文はアクション名・対象名・式を ModelCheck.escape / escape_expression / escape_reason に通す。テスト：test_error_message_escapes_control_characters、hostile_end_test、model_check_test | 変更なし。差分が文字列を足さない | 変更なし。既存の limit_last_error と escape_expression の上限（200 文字）のままで、差分は文を足さない | 該当なし。差分は文字列の処理を増やさない |
| D. 計算結果（収めた後のストック）→ 保存される状態、その後の終了判定 | 変更あり。収めた値は有限で、判定は有限の値を見る | 変更なし。判定の失敗は既存の経路。テスト：test_victory_judgement_sees_clamped_value、test_defeat_judgement_sees_clamped_value | 該当なし。条件の個数は既存の上限（MAX_DEFINITIONS）のまま | 該当なし。出口が数値である | 該当なし。数値だけを扱う | 該当なし。出力する文字列が無い | 変更なし。判定の評価回数は変わらない |
| E. モデルの定義・式・標準入力・コマンドライン引数・ファイル → ログ・標準出力・画面・ファイル | 該当なし。#39 は読み込み・保存・出力の経路に触れない | 該当なし。同上 | 該当なし。同上 | 該当なし。同上。demo/action_range_demo.gd は固定の文字列と数値だけを出す | 該当なし。同上 | 該当なし。同上 | 該当なし。同上 |

作り直しの中で気づいたこと（直していない）
- 列1：範囲の端が有限であることは add_stock の検査（既存）に依存する。apply_action 側にはコードによる再確認が無い。
- 列7：行Aの最悪の形（効果50個がすべて範囲つき）を実測するテストが無い。差分が積を変えないので、should 以下と判断する。
- 列2：「範囲つきの効果と、非有限で失敗する別の効果が同じアクションにあるとき、範囲つきのストックも変わらない」ことを確かめるテストが無い。
