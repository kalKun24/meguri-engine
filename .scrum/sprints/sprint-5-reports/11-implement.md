# #11 implement の報告（原文）
- 作業ディレクトリ：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a57a1eeef4078e632
- ブランチ：scrum/11（分岐元 scrum/22 の 50adf90）。コミット：5448264、7f3d15b、1b7d6d0

status: done
pbi: #11
branch: scrum/11（分岐元 scrum/22 の 50adf90）。コミット3つ：5448264（補助変数の本体）、町の書き直し（2つ目）、デモ（3つ目）。作業ディレクトリ：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a57a1eeef4078e632
tests: 384 件、すべて通過（分岐元 scrum/22 は351件、追加は33件）。scripts/test.sh の ERROR は debugger ポートの既知2行だけ。それ以外の ERROR・WARNING・leaked・still in use は0件。test.sh の前後で git status は変わらない（clean）。addons/ は元のリポジトリからコピーした（git の対象外）。
不可視文字の混入：src・test・demo の *.gd を grep -P で検索して0件。
#20 のゴールデン値は変えていない。TownModel を deficit に書き直した後も test_default_town_matches_python_golden_values と test_no_food_town_matches_python_golden_values が、期待値を変えずに通っている。

## summary
- 追加した公開 API：`SimModel.add_auxiliary(name, expression) -> Error`
  - 名前は `_check_new_name(name, "補助変数名", true)` を呼ぶ。`ModelCheck.check_identifier` と同じ規則で、規則を二重に持たない。
  - 構文エラーは `ERR_PARSE_ERROR`。名前の解決、フロー参照、循環は `validate()` で検査する（`add_flow_expr` と同じ形）。
- 評価器の変更（#23 が名前で値を引ける形）
  - `ExprProgram.Op.PUSH_AUXILIARY` を enum の末尾に足した。値は `names[i]`（補助変数名）で引く。
  - `ExprCompiler.compile(root, source, stocks, constants, auxiliaries = {}, flow_names = {})`：既存の呼び出しは変わらない。
  - `ExprEvaluator.evaluate(program, stocks, auxiliaries = {})`：補助変数の値は「名前 → 値」の辞書で渡す。
- 計算の流れ
  - `validate()`：補助変数を組み立て、重複なしで依存先を集める。次に、明示的なスタックによる深さ優先で、依存される側が先に来る順を決める。再帰は使わない。
  - `_apply_flows()`：`var turn` の直後に `_calculate_auxiliaries(turn)` を呼ぶ。返った値の辞書を、フローの `ExprEvaluator.evaluate(program, _stocks, auxiliary_values)` に渡す。#7 の統合で衝突しうる箇所は、この挿入4行と evaluate の引数1つだけ。`_apply_flows` のそれ以外は変えていない。
- エラーの形
  - 循環：`補助変数に循環参照がある：a -> b -> a`（`ERR_INVALID_DATA`）。自己参照は `s -> s`。
  - 経路は `ModelCheck.MAX_CYCLE_PATH_LENGTH`（8）個の名前まで示し、残りは `-> ...` で省く。
  - フロー参照：`補助変数「x」の式に誤りがある（位置 0）：'growth' はフローである。フローの量は参照できない`。
  - 非有限・0除算：`ターン 2 の実行時エラー：補助変数「ratio」の式の位置 2 で、0 で割った：...`（`FAILED`）。補助変数はフローの反映より前に求めるので、状態は変わらない（`advance_turn` でも同じ）。
- 町（TownModel）
  - `TownModel.AUXILIARIES`（`deficit`）と `TownModel.FLOWS`（6本）を公開の定数にした。`build()` はこの2つから定義する。
  - deaths と expenses は `deficit` を参照する。consumption は、元から不足分を持っていなかった。
- ゴールデン値のテスト（`test/sample/town_golden_test.gd`）
  - `_flows` の `get()` と式の二重化（`DEFICIT`、`_flows_in_town_order`）を削除した。`TownModel.FLOWS` と `AUXILIARIES` から組み直す。
  - 補助変数をフローの後に定義する組み直しも足した。
- 死亡のテスト（`test/text_play/text_player_test.gd` の `test_deaths_grow_when_food_is_short`）
  - food = 10、0、10000 のそれぞれで、人口の変化から逆算した死亡量を、式から求めた期待値と `1e-9` で比べる形に書き直した。
  - 不足がある場合の追加の死亡が `starvation_rate * 不足分` になることも比べる。
- 逆順の完全一致のテストの見直し（基準）
  - deficit を補助変数にしたので、ストックに触れるフローは3本以上にならない。population：births・deaths、food：production・consumption、money：taxes・expenses で、どれも2本である。
  - 0.0 に2項を足す順は交換できるので、完全一致は成り立つままである。テストは変えない。
  - 前提が壊れたときに気づけるよう、`test_exact_equality_premise_each_stock_has_at_most_two_flows` を足した。`FLOWS` から数え、3本以上なら失敗して、許容誤差への切り替えを促す。
- デモ：`demo/auxiliary_demo.gd` を新設した。

## demo
`godot --headless --path . -s res://demo/auxiliary_demo.gd`
1. 定義順だけを変えた2通りで、ターン1〜3の mood が `5.0 と 5.0（同じ）`、`10.0 と 10.0（同じ）`、`15.0 と 15.0（同じ）` と出る。
2. a と b が互いを参照すると `補助変数に循環参照がある：a -> b -> a` が出る。自己参照は `s -> s`。長さ300の循環は先頭8個で `...` と省かれる。
3. 補助変数がフロー growth を参照すると、フローの量は参照できないというエラーが出る。
4. 補助変数 ratio が 0 で割ると、ターン2が Failed になり、turn は 1 のまま、`補助変数「ratio」` を含む文が出る。
5. 長さ1000の鎖の validate と step の実測が出る（下の列7）。

## 受け入れ基準とコミット
- 基準1〜6は1コミット（5448264）にまとめた（T3-3）。`add_auxiliary`、`validate`、`_apply_flows` の先頭の計算が同じ関数に絡み、先に分けると中途半端な状態でテストが通らないためである。
- 町の書き直し・フローの公開・死亡のテスト・逆順の見直しが2つ目のコミット。デモが3つ目。

## 列挙表（T4-1）
「同じ名前空間で重複禁止」の対象は、他の定義の種類の全件である。
- 列挙：`grep -nP "^func (add_\w+)\(" src/core/sim_model.gd` で、名前を取る定義が add_stock、add_constant、add_flow、add_flow_expr、add_action、add_victory_condition、add_defeat_condition、add_auxiliary の8件。add_auxiliary を除く7件が、補助変数の名前と衝突しないことを確かめる対象になる。
- 補助変数から見た相手の列挙は、ストック・定数・フロー・許可関数・補助変数の5種類。

| 対象 | テスト名（SimModelAuxiliaryTest） |
|---|---|
| 補助変数 × ストック・定数・フロー・許可関数（min）・補助変数の同名 | test_auxiliary_name_conflicts_with_every_other_kind_of_name |
| add_stock | test_other_definitions_cannot_reuse_an_auxiliary_name |
| add_constant | 同上 |
| add_flow | 同上 |
| add_flow_expr | 同上 |
| add_action | 同上 |
| add_victory_condition | 同上 |
| add_defeat_condition | 同上 |
| 名前の規則は ModelCheck.check_identifier と同じ | test_auxiliary_name_rule_is_the_same_as_the_shared_check、test_auxiliary_name_follows_the_identifier_rule_for_every_hostile_string（HostileValues.strings() の全件） |
| 定義の個数の上限を共有 | test_auxiliary_counts_toward_the_definition_limit |

## 経路の表（T2-1、T4-2）
入口は、補助変数の名前と式（モデルの定義）と、ストックの値（計算結果）。出口は、`last_error`、ストックの状態。

| 入口 → 出口 | 1 有限性 | 2 失敗の返し方 | 3 上限 | 4 エスケープ | 5 生のバイト列 | 6 長さ・組み合わせ | 7 処理量 |
|---|---|---|---|---|---|---|---|
| 補助変数の名前（add_auxiliary）→ last_error | 該当なし。名前は数値を扱わない。 | `ERR_INVALID_PARAMETER`、`ERR_ALREADY_EXISTS`、`ERR_OUT_OF_MEMORY` と last_error。失敗時はモデルが変わらない（test_auxiliary_name_follows_the_identifier_rule_for_every_hostile_string が、拒否の後に add_auxiliary("ok", "1") が通ることまで確かめる）。成功時は last_error を空にする。 | 名前の長さ上限64と定義の個数上限1000は共通部品が判定する（test_auxiliary_counts_toward_the_definition_limit）。 | 位置の文字を `escape()` に通す（共通部品）。HostileValues 全件で `limit_last_error` 内に収まることを確かめた。 | Godot の String は UTF-32 で、バイト列の読み取りは入口の外。新しい入口は無い。NUL と改行は HostileValues の「改行を含む」で流す。 | `limit_last_error` で1000字以内（同テスト）。 | 名前は最大64字で O(64)。長さ10万の名前は check_name で拒否され、規則の走査に入らない。 |
| 補助変数の式（add_auxiliary）→ last_error | 巨大リテラルの有限性は既存の検査のまま。 | 構文エラーは `ERR_PARSE_ERROR` と last_error（test_auxiliary_syntax_error_is_reported_when_defined）。モデルは変わらない。 | 式の長さ上限1000と深さ上限は ExprParser の既存のまま。 | 式の抜粋は `escape_expression`、原因は `escape_reason` を通す（add_flow_expr と同じ書式）。 | 該当なし。字句解析は String を受け取る。 | 式の抜粋200字、原因200字、全体1000字は既存の共通部品が守る。 | 式1本あたり O(式の長さ)。 |
| 補助変数の式（validate）→ last_error | 該当なし。この段階は数値を作らない。 | 名前の未解決、フロー参照、循環は `ERR_INVALID_DATA` と last_error。状態は変えない（test_step_returns_the_same_error_and_changes_nothing）。 | 経路の名前の数は `MAX_CYCLE_PATH_LENGTH`（8）で打ち切る（test_cycle_path_length_is_limited_by_the_constant、test_long_cycle_path_is_shortened_from_the_head）。 | 経路の名前は `escape()` を通す。名前は識別子の規則を通っているので、通常は変わらない。 | 該当なし。 | 長さ1000の循環でも last_error は1000字以内（test_cycle_closing_a_chain_of_1000_is_detected）。 | 下の「列7の規模と実測」。 |
| ストックの値・補助変数の式（ターン開始時）→ last_error・ストック | 式の途中の値、補助変数の値が非有限になれば、その演算で止める（test_non_finite_auxiliary_stops_the_turn_with_its_name_and_keeps_the_state、test_overflowing_auxiliary_is_reported_by_name）。 | `FAILED` と last_error。ストック・ターン番号は変わらない。`advance_turn` でも、ゲームは終わらない（test_auxiliary_error_in_advance_turn_leaves_the_game_unchanged）。 | 式の長さは定義時の上限のまま。 | 補助変数名と式は `escape`・`escape_expression`・`escape_reason` を通す。 | 該当なし。 | 実行時の文は `limit_last_error` で1000字以内。 | 下の「列7の規模と実測」。 |
| 補助変数の値 → フローの式（ストックの状態） | フローの式の評価と、更新後のストックの `check_finite` は既存のまま。 | 補助変数の失敗は上の行のとおり、フローの反映より前に返る。 | 該当なし。 | 該当なし。この経路は値だけで、文字列を出さない。 | 該当なし。 | 該当なし。 | 補助変数の個数に比例して、1ターンの先頭で1回ずつ評価する。 |

## 列7の規模と実測（再現：`godot --headless --path . -s res://demo/auxiliary_demo.gd` の節5、およびテスト）
- 想定する最大の規模：補助変数1000個の鎖。`MAX_DEFINITIONS`（1000）まで補助変数だけで使い切る規模である。
- 実測（デモの節5、この環境）
  - 定義順どおり：validate 19.3 ms、step 9.2 ms。
  - 逆順：validate 21.5 ms、step 12.7 ms。
- テストでの確認
  - test_chain_of_1000_does_not_fail_in_either_definition_order：正順・逆順の両方で validate と step が成功する。
  - test_chain_of_1000_gives_the_same_flow_result_whichever_way_it_is_defined：998個の鎖を正順・逆順に定義して、フロー量が `998.0` で完全に一致する。このテストは、ストックとフローを加えて1000個の定義の上限に収めた。
  - test_cycle_closing_a_chain_of_1000_is_detected：1000個の鎖が閉じた循環になっていても検出する。
  - 3本とも、再帰に頼らないことの確認を兼ねる。
- 計算量
  - 循環の検出と順序の計算：O(補助変数の数 + 参照の数)。
  - 毎ターンの評価：O(命令の総数)。
  - `_validated` が false になるたび（アクションで定数が変わったとき）、全補助変数を組み立て直す。1000個で約20 ms。
- 測定した規模での1ターンは10 ms 前後で、T4-2 の想定（100ターン）では約1秒に収まる。100ターンの通し測定はしていない。1ターンの実測からの見積りである。
- スイート全体の時間は、約27秒のまま（#22 の報告と同じ）。

## assumptions
- 補助変数を参照できる式は、フローの式と補助変数の式だけにした。
  - アクションの式と終了条件の式は、ターンの合間か、フローの反映後に評価する。補助変数の値はターンの開始時に求めたものなので、そこで参照させると古い値を見せてしまう。
  - そのため、アクションと終了条件が補助変数を参照すると `ERR_INVALID_DATA`（未定義の名前）になる。test_action_and_condition_expressions_cannot_reference_auxiliaries で固定した。
  - 参照させたいときは、別の PBI で、評価の時点を決める必要がある。
- 補助変数の値を外から読む公開関数（getter）は足していない。基準に無いためである。値は、フローを通したストックで確かめる。#23 が値を名前で引くときは、`_calculate_auxiliaries` が返す「名前 → 値」の辞書を使える。
- 補助変数どうしの依存順は、深さ優先の完了順で決める。値は依存の順で決まるので、定義順で結果は変わらない。同じ入力で順序も決まる（定義順と参照の出現順に従う）。
- フロー名への参照は、補助変数の式でだけ専用のエラー文にした。フローの式やアクションの式での未定義の名前の文は、補助変数があるときだけ「ストックと定数と補助変数」と変わる。
- 経路の長さ上限は 8 個の名前とした。基準の「一定の数」が未指定のため、`ModelCheck.MAX_CYCLE_PATH_LENGTH` に置いた。
- 補助変数が、ストック・定数・フロー・補助変数の合計で定義の個数の上限1000を共有する。
- `addons/gdUnit4` は元のリポジトリからコピーした（git の対象外）。

## unresolved
- #7（StockRange）との統合：`_apply_flows` の衝突しうる箇所は、`calculated` から `auxiliary_values` を取る4行と、evaluate の引数1つ。範囲に収める処理は、統合の側で deltas の反映部分に入れればよい。
- アクションと終了条件から補助変数を参照できるようにするか、PO の判断が要る（assumptions の1項目め）。
- 補助変数の値を画面や CSV に出すか（getter の要否）は、基準に無いので決めていない。
