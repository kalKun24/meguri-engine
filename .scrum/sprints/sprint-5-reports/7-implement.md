# #7 implement の報告（原文）
- 作業ディレクトリ：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a83712e3a57400491
- ブランチ：scrum/7（分岐元 main）

status: done
branch: scrum/7（分岐元 main）。コミット 2 つ：516c845（clamp の lo>hi）、c69fa32（基準1〜6）。
テスト：scripts/test.sh で 346 件、0 errors / 0 failures / 0 orphans。ERROR は既知の debugger ポート 2 行だけで、WARNING・leaked・still in use は 0 件。テスト前後で、未追跡のファイルは増えていない。不可視文字を扱う変更は無い。

## summary
- 新しい公開クラス src/core/stock_range.gd（class_name StockRange、RefCounted）。作った後は変えられず、変更用の関数も無い。
  - 作り方：StockRange.between(lo, hi)、at_least(lo)、at_most(hi)。
  - 読み出し：has_lower() / get_lower() / has_upper() / get_upper()。
  - 省略は has_* が false で表す。無限大の値では表さない。
  - 範囲を超えるときの扱いは enum StockRange.Overflow { CLAMP }。各ファクトリの末尾の引数で選ぶ（既定は CLAMP）。
  - #8 と #12 は、この enum に値を足せば済む。add_stock は未知の値を ERR_INVALID_PARAMETER にする。
  - apply(value) は範囲内に収めた値を返す。
- SimModel.add_stock(name, initial, stock_range: StockRange = null) に引数を追加した。既存の呼び出しは変わらない。get_stock_range(name) も追加した。範囲が無い、または未定義の名前なら null を返す。
- _apply_flows() で、ストックごとに「更新後の合計値 → StockRange.apply → check_finite」の順に処理する。
  - 反映は全ストックの検査後なので、失敗時に状態は変わらない。
  - advance_turn() は、_apply_flows と _judge の間に何も足していない。_apply_flows が #35 の snapshot の内側にあるので、判定が失敗しても範囲に収めた値ごと戻る。
  - #34 のイベントを入れる箇所のコメントは、そのまま残してある。
  - step() も同じ _apply_flows を通るので、範囲を守る。
- 組み立て時の検査（add_stock、ERR_INVALID_PARAMETER）は次のとおり。下限が上限より大きい、下限・上限が NaN/INF、初期値が範囲外、Overflow が未知。失敗したらモデルは変わらず、last_error はエスケープ済みで長さの上限内に収まる。
- src/expr/expr_evaluator.gd：clamp の lo > hi は実行時エラーにした。メッセージは「下限が上限より大きい：clamp(5.0, 10.0, 0.0)」の形で、位置は clamp の演算の位置になる。lo == hi は許す。
- ModelCheck には触れていない（#22 との衝突は無い）。

## 受け入れ基準とテスト（test/core/sim_model_range_test.gd、clamp は test/expr/expr_evaluator_test.gd）
1. 設定と省略：test_range_is_set_per_stock、test_omitted_range_is_expressed_without_infinity
2. 下限なしは負、上限なしは増え続ける：test_stock_without_lower_goes_negative、test_stock_without_range_goes_negative_and_grows_freely、test_stock_without_upper_grows_without_limit
3. 値を止める：test_stops_at_lower_when_consumption_is_high、test_stops_at_upper_when_production_is_high、test_clamps_the_sum_of_inflows_and_outflows_of_the_same_turn、test_clipped_amount_vanishes_and_goes_nowhere、test_step_also_clamps、test_expression_flow_reads_clamped_value_next_turn、test_overflow_policy_is_selectable_and_defaults_to_clamp
4. 収めた後が非有限なら実行時エラーで状態不変：test_non_finite_after_clamping_is_runtime_error_and_state_is_kept、test_nan_after_clamping_is_runtime_error、test_defeat_judgement_sees_clamped_values_and_failure_restores_state
5. 組み立て時の拒否と変更不可：test_lower_above_upper_is_invalid_parameter、test_initial_value_outside_range_is_invalid_parameter、test_non_finite_bounds_are_invalid_parameter、test_non_finite_initial_value_with_range_is_invalid_parameter、test_unknown_overflow_is_invalid_parameter、test_range_cannot_be_changed_after_setting、test_hostile_names_with_range_errors_are_escaped
6. 許容誤差 1e-9 で範囲内：test_values_stay_within_range_over_many_turns（300 ターン、小数の流量）
7. clamp の lo > hi：test_clamp_with_lower_above_upper_is_runtime_error_naming_the_operation、test_clamp_with_lower_equal_to_upper_is_allowed、test_clamp_with_lower_above_upper_from_stocks_is_runtime_error

コミットの分け方：基準1〜6は add_stock と _apply_flows の同じ流れに絡んで分けられないので、1 コミットにまとめた（T3-3）。基準7 は別コミットにした。

## 列挙表
受け入れ基準に「全」「すべて」「各」を含む箇所は、「同じターンのすべての流入と流出を合計して」だけである。これは対象の列挙ではなく計算の定義で、test_clamps_the_sum_of_inflows_and_outflows_of_the_same_turn が対応する。列挙表は対象外とする。

## 経路の表（T2-1/T4-2、7 列）
列の意味は、1=有限性、2=失敗の返し方、3=上限（長さ・個数・深さ）、4=エスケープ、5=生のバイト列、6=出力の長さと組み合わせ、7=処理量。

| 入口 → 出口 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| モデルの定義（add_stock の lo/hi/初期値）→ last_error | NaN/INF の下限・上限・初期値を ERR_INVALID_PARAMETER で拒否。test_non_finite_bounds_are_invalid_parameter、test_non_finite_initial_value_with_range_is_invalid_parameter（HostileValues.floats() 全件） | Error コードと last_error。成功で空になる。失敗時、モデルは変わらない | 範囲は 1 ストックにつき 2 値で個数が増えない。ストック数の上限は既存の MAX_DEFINITIONS | エラー文に出す利用者由来の文字列はストック名だけで、既存の escape を通す。test_hostile_names_with_range_errors_are_escaped（HostileValues.strings() 全件） | 該当なし。StockRange は float と enum だけで、文字列を受け取らない。名前は既存の経路 | MAX_LAST_ERROR_LENGTH 以下を同テストで確認。範囲の数値部分は str(float) で短く、切るのは limit_last_error 経由 | 該当なし。定義時の検査は O(1) |
| モデルの定義（Overflow）→ last_error | 該当なし。enum は整数 | 未知の値は ERR_INVALID_PARAMETER。test_unknown_overflow_is_invalid_parameter | 該当なし。整数 1 個 | 該当なし。出力は整数の数値だけ | 該当なし。整数 | 該当なし。固定長 | 該当なし。O(1) |
| 計算結果（_apply_flows の更新後の合計）→ 保存される状態（_stocks） | 収めた後の値を check_finite。非有限ならそのターンは FAILED で状態不変。test_non_finite_after_clamping_is_runtime_error_and_state_is_kept、test_nan_after_clamping_is_runtime_error。上限があって合計が INF のときは、収めた後が有限なので成功する（基準4 の「収めた後」どおり、test_infinity_that_clamping_makes_finite_is_not_an_error） | FAILED と last_error（ターン番号入り）。advance_turn は snapshot で復元。test_defeat_judgement_sees_clamped_values_and_failure_restores_state | ターン数・ストック数に上限は無く、既存の MAX_DEFINITIONS が上限になる | 該当なし。この経路は数値だけで、文字列を出さない（エラー文は下の行） | 該当なし。数値のみ | 該当なし。数値のみ | O(ストック数) の比較 2 回を追加しただけ。実測：300 ターン × 2 フロー式のモデルで test_values_stay_within_range_over_many_turns が数十 ms。ターンごとに条件を組み立て直す既存の処理の方が支配的で、今回は増えていない |
| 計算結果 → エラー文（last_error） | 非有限の値の文言は既存の check_finite | FAILED。成功で last_error が空になる | limit_last_error（1000 文字）を既存の _fail が適用 | ストック名は escape 済み | 該当なし。文字列は名前だけ | 既存の limit_last_error が表記の途中で切らない | 該当なし |
| 式（clamp(x, lo, hi)）→ ExprEvalResult.message → last_error | lo > hi は実行時エラー。NaN/INF は既存の演算ごとの検査 | ok=false と position/message を返す。NAN は返さない | 式の長さ・深さの上限は既存（変更なし） | message は数値だけ（str(float)）で、escape_reason を経由して last_error へ | 該当なし。式の文字列は既存のパーサ経路で、変更なし | 数値 3 個の description のみで短い。escape_reason が 200 文字で切る | O(1) の比較 1 回を CALL ごとに追加 |
| 標準入力、コマンドライン引数、ファイル、アクションの入力 → | 該当なし。この PBI は範囲の定義と更新だけで、これらの入口を触らない | 同左 | 同左 | 同左 | 同左 | 同左 | 同左 |

## assumptions
- add_stock に範囲を渡す形にした。範囲は組み立て時に 1 回だけ決め、後から変える関数は作っていない。基準の「変えられない」を、変更用 API が無いことで満たした。
- 「止めた値が非有限」の判定は、基準どおり収めた後の値で行う。上限があるストックでは、合計が +INF でも上限に収まって成功する。下限だけのストックで +INF なら、収めた後も INF なので FAILED になる。NaN は apply が素通しするので、必ず FAILED になる。
- step() も範囲を守る。範囲の処理を _apply_flows に置いたためである。基準は advance_turn を指すが、step() だけ範囲外になる状態を避けた。
- 初期値の検査の順は、非有限の下限・上限 → 下限 > 上限 → 初期値が範囲外とした。lo > hi のときに、より根本の原因を出すためである。
- 町のサンプル（TownModel）は触っていない（#28 の範囲）。町のアクションが使う clamp(tax_rate…, tax_min, tax_max) は lo <= hi のままで、既存のテストが通っている。
- worktree には addons/gdUnit4 が無かったので、元のリポジトリの addons/gdUnit4 へのシンボリックリンクを addons/gdUnit4 に作ってテストした。.gitignore の末尾スラッシュのせいで、このリンクは git に無視されず untracked に出る。コミットには含めていないが、作業ディレクトリには残っている。

## unresolved
- apply_action() は範囲に収めない。アクションの効果で、範囲つきストックを範囲外の値にできる（例：food = food + 1000）。範囲外の値は、そのストックにフローがある次のターンの更新で収まる。フローが無いストックは範囲外のまま残る。受け入れ基準に無いので足さなかった。足す場合は、PBI の基準に追記して、アクション適用時の値も範囲内に収めるか、範囲外ならアクションを拒否するかを決める必要がある。
- StockRange の範囲を超えるときの扱い（Overflow）は CLAMP だけである。#8 と #12 が値を足すとき、_apply_flows 側の分岐（現在は stock_range.apply を直接呼んでいる）を、Overflow ごとの処理に広げる。

## demo
下限 0・上限 100 の食料と、下限なしのお金を持つモデルを作って進める。例：
`var m := SimModel.new(); m.add_stock("food", 50.0, StockRange.between(0.0, 100.0)); m.add_stock("money", 0.0); m.add_flow("eat", "food", "", 20.0); m.add_flow("spend", "money", "", 30.0); for i in 5: m.advance_turn()`
- 食料は 30 → 10 → 0 → 0 と進み、0 で止まる。生産を消費より多くすると 100 で止まる。
- お金は -30, -60, … と負の値まで減っていく。
- `m.add_stock("x", 5.0, StockRange.between(10.0, 0.0))` は ERR_INVALID_PARAMETER を返し、last_error に「下限が上限より大きい」と出る。
- 式 `clamp(5, 10, 0)` を使うフローを進めると FAILED になり、last_error に「下限が上限より大きい：clamp(5.0, 10.0, 0.0)」と出る。
再現はテスト（scripts/test.sh、test/core/sim_model_range_test.gd）でもできる。

## 関係するファイル
- src/core/stock_range.gd
- src/core/sim_model.gd
- src/expr/expr_evaluator.gd
- test/core/sim_model_range_test.gd
- test/expr/expr_evaluator_test.gd
