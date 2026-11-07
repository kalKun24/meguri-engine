# #23 implement の報告（原文）
- 作業ディレクトリ：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a2dbafa065a661fbc
- ブランチ：scrum/23（分岐元 scrum/11 の 1b7d6d0）。コミット：0922564

status: done
pbi: #23
branch: scrum/23（分岐元 scrum/11 の 1b7d6d0）。コミット：0922564 の1つ。作業ディレクトリ：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a2dbafa065a661fbc
tests: 407 件、すべて通過（分岐元は384件。追加は23件）。scripts/test.sh の ERROR は debugger ポートの既知2行だけ。それ以外の ERROR・WARNING・leaked・still in use は0件。不可視文字の grep は0件。
未追跡のファイルが1つある：demo/auxiliary_demo.gd.uid。#11 のデモの uid で、test.sh の実行で生成された。#11 側で未コミットだったもので、#23 では含めていない。

## summary
実装
- src/expr/expr_evaluator.gd
  - 評価の途中で、スタックと同じ長さの「名前のスタック」を持つ。
    - ストック・補助変数・定数の参照だけが名前を持つ。計算で作った値と NEG の結果は名前を持たない。
  - 除算・剰余・CALL（関数）が失敗するときに、原因の説明の後ろへ「（名前 = 値、名前 = 値）」を添える。
    - 例：`0 で割った：0.0 / 0.0（stock = 0.0、divisor = 0.0）`
    - 名前は `ModelCheck.escape(名前)`（既定32文字）を通す。
    - 同じ名前は1回だけ出す。名前を持つ値が無ければ何も添えない。
  - 説明は失敗した時だけ作る（`_describe`）。成功する演算では作らない。
- src/expr/expr_compiler.gd：定数を値に置き換えるときも、PUSH_NUMBER の names に定数名を入れる。
- src/expr/expr_program.gd：names の説明を更新した。
- test/expr/expr_error_names_test.gd（新規、23件）。
- demo/error_names_demo.gd（新規）。
- 名前を入れた文は、既存の呼び出し側の `escape_reason`（200字）と `limit_last_error`（1000字）を通る。呼び出し側は変えていない。
- 受け入れ基準1〜3は同じ evaluate に絡むため、1コミットにまとめた（T3-3）。

## demo
`godot --headless --path . -s res://demo/error_names_demo.gd`
- `stock / divisor`（両方0）：`ターン 1 の実行時エラー：フロー「f」の式の位置 6 で、0 で割った：0.0 / 0.0（stock = 0.0、divisor = 0.0） 式：stock / divisor`
- 剰余、`pow(stock, divisor)`、`sqrt(stock)` も同じ形で名前と値が出る。
- `stock / (divisor - divisor)` は、名前でない右辺を出さず `（stock = 5.0）` だけが出る。

## 列挙表（T4-1）
列挙のコマンド：`grep -nP '^\t"\w+": \d+,' src/expr/expr_functions.gd`。ARITY の9件で、`test_function_cases_cover_every_allowed_function` が `ExprFunctions.names()` と式の表のキーが一致することも確かめる。
全件のテストは `test_every_allowed_function_names_the_argument_values` で、失敗する式の表 `FUNCTION_CASES` を回す。

| 対象 | テスト名 |
|---|---|
| 除算 | test_division_names_the_stocks_and_values、test_division_names_only_the_operand_that_is_a_name、test_division_names_a_constant、test_division_names_an_auxiliary、test_the_same_name_is_shown_once、test_negated_name_is_not_shown_as_the_name、test_division_overflow_also_names_the_values、test_last_error_shows_the_names_for_a_stock_over_a_stock |
| 剰余 | test_modulo_names_the_stocks_and_values、test_last_error_shows_a_constant_and_an_auxiliary |
| べき乗（pow） | test_power_names_the_stocks_and_values、test_function_names_a_constant_and_an_auxiliary |
| min | test_every_allowed_function_names_the_argument_values（`min(pop, nan_stock)`） |
| max | 同上（`max(pop, nan_stock)`） |
| clamp | 同上（`clamp(nan_stock, 0, pop)`）、test_function_names_every_named_argument_in_order |
| abs | 同上（`abs(inf_stock)`） |
| floor | 同上（`floor(inf_stock)`） |
| round | 同上（`round(inf_stock)`） |
| ceil | 同上（`ceil(inf_stock)`） |
| sqrt | 同上（`sqrt(inf_stock)`）、デモ |
| pow | 同上（`pow(inf_stock, ten)`） |

参照の種類（ストック・定数・補助変数）はそれぞれ別のテストで確かめた。ストックは `test_division_names_the_stocks_and_values`、定数は `test_division_names_a_constant`、補助変数は `test_division_names_an_auxiliary`。補助変数は SimModel を通した `test_auxiliary_error_in_last_error_names_the_values` でも確かめた。

## 経路の表（T2-1、T4-2）
入口は、式（モデルの定義）と、ストック・定数・補助変数の値（計算結果）。出口は last_error（SimModel）と ExprEvalResult.message。

| 入口 → 出口 | 1 有限性 | 2 失敗の返し方 | 3 上限 | 4 エスケープ | 5 生のバイト列 | 6 長さ・組み合わせ | 7 処理量 |
|---|---|---|---|---|---|---|---|
| 名前で参照した値（ストック・定数・補助変数）→ 原因の演算の説明 | 値は演算前の値を表示する。非有限は `str()` が "inf"・"nan" と出す（test_every_allowed_function_names_the_argument_values）。止まる条件は変えていない。 | 失敗は ExprEvalResult.ok=false と message で返す。SimModel は `FAILED` と last_error を返し、状態を変えない。変更なし（test_last_error_shows_the_names_for_a_stock_over_a_stock が turn 0 のままを確かめる）。 | 名前は escape の既定32文字で省略する（test_long_name_is_shortened_by_the_escape_default）。1つの演算に添える名前は最大3個。説明全体は呼び出し側の escape_reason（200字）と limit_last_error（1000字）が守る。 | 名前は `ModelCheck.escape` を通す（test_name_is_escaped：U+202E、U+200B、バックスラッシュ）。呼び出し側で `escape_reason` を通す既存の経路は変えていない。 | 該当なし。名前は String で、新しい入口は無い。NUL と改行は escape の対象で、HostileValues の共有一覧で既に流している。 | 下の「列6」。 | 下の「列7」。 |
| 式の定数名 → 命令列の names | 該当なし。定数の値は組み立て時のまま。 | 該当なし。失敗する経路が増えない。 | 該当なし。名前は定義時に64文字以内に検査済み。 | 該当なし。名前は命令列の中で、出力の時に escape する。 | 該当なし。 | 該当なし。 | 該当なし。命令ごとに文字列1つを持つだけで、組み立ては O(命令数)。 |

### 列6：名前を入れた文の長さとエスケープの組み合わせ
- 敵対的な名前は、定義時の識別子の検査を通らない。そのため、評価器に ExprProgram を直接渡して流した。
- escape は文字数32で切る。U+202E は `\u{202E}` の8文字に伸びるので、名前1つで最大256文字になる。
- `test_escaped_names_with_the_reason_limit_never_cut_a_notation`
  - `(U+202E + バックスラッシュ)` を40回繰り返した名前（escape で256文字以上に伸びる）を2つ並べて pow で失敗させる。
  - 上限 200・60・100・137・199 で `escape_excerpt(..., false)` に通し、次の3点を確かめる。
    - 長さが上限以内である。
    - 末尾が「...」である。
    - 切った文を `\\` と `\u{…}` の1単位ずつ読み、表記の途中で終わっていない。
  - `escape_reason` で200字以内になることと、`limit_last_error` で1000字以内になることも確かめる。
  - 文に生の不可視文字が無いことは `HostileValues.find_raw_invisible` で確かめる。
- 名前の省略は escape の既定32文字を使い、`test_long_name_is_shortened_by_the_escape_default`（100文字の名前）で確かめた。

### 列7：処理量
- 想定する最大規模：式の長さの上限いっぱい（1000字以内）に、名前を多く参照する式を流す。
  - 異なるストック名を219個参照する。式は999字。最後の `pow(huge,huge)` で失敗する。
- 実測（この環境、300回平均、再現：`test_cost_of_a_cause_message_with_the_longest_expression_full_of_names` の print と、下の比較の方法）
  - 原因の文まで評価（失敗） 1回 = 0.79 ms。
  - 成功する同じ長さの式 1回 = 0.70 ms。
- 分岐元（scrum/11）の評価器との比較（scratchpad の一時スクリプト。テストには入れていない）
  - 名前が多い式、成功：旧 0.98 ms、新 0.68 ms。
  - 名前が多い式、失敗：旧 1.04〜1.17 ms、新 0.78 ms。
  - 数字だけの999字の式：旧 2.17 ms、新 1.40 ms。
- 新しい評価器の方が速い。旧は演算のたびに説明文を作っていた。新は失敗した時だけ作る。
- 名前を添える処理は、失敗した1回の演算で最大3個の名前に対する O(1) である。式の長さに比例して増えるのは、名前のスタックの追加と取り出しだけである。
- テストは1回あたり 50 ms 未満を上限に置いた。

## assumptions
- 名前を添える対象は、基準に書かれた除算・剰余・べき乗（pow）・関数呼び出しに限った。乗算などのオーバーフローには添えていない。基準に無いためである。
- 「べき乗」は、式にべき乗の演算子が無い（`**` は構文に無い）ので、関数 pow を指すと解釈した。
- 名前を持つのは、名前で直接参照した値だけである。`-pop` や `pop - 1` のような計算した値は名前を持たない。
- 同じ名前は1回だけ出す。例：`stock / stock` は `（stock = 0.0）`。
- 名前の省略は escape の既定（32文字）を使った。
- 補助変数の値は `auxiliaries` の辞書から引く（#11）。補助変数の式の中で起きた失敗も、フローの式と同じ形で名前を添える。
- 添える表記は基準の例に合わせ、全角の括弧と読点で「（stock = 0.0、divisor = 0.0）」とした。
- 値の表示は既存の `_fmt`（`str(value)`）のままにした。
- 基準の T2-1 の経路の表は、上の「経路の表」に書いた。
- addons/gdUnit4 は元のリポジトリからコピーした（git の対象外）。

## unresolved
- 既存の `_fmt` は、1e300 のような大きな値を300桁の数字で出す。この値が原因の演算に入ると、説明が `escape_reason` の200字上限に当たり、名前と値が「...」で切れて見えなくなる。例：`pow(1e300, …)`。
  - 値の表示形式は、基準の外にあるので変えていない。
  - 名前を値より前に出す、あるいは値を短く表示するなどの案がある。PO か次のリファインメントで決めたい。
- 分岐元は #22・#11 に積む前提で作った。マージの順序は #22、#11、#23 とする。衝突しうるのは、#11 が触る evaluate の `auxiliaries` の行だけで、この PBI はそこを変えていない。
