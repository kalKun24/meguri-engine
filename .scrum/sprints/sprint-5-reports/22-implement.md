# #22 implement の報告（原文）
- 作業ディレクトリ：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-ae258dc778111e4dc
- ブランチ：scrum/22（分岐元 main の 404cc67）

status: done
pbi: #22
branch: scrum/22（分岐元 main の 404cc67）。コミット3つ：70b3fe0、011044d、50adf90
tests: 351 件、すべて通過（分岐元は317件、追加は34件）。scripts/test.sh の ERROR は debugger ポートの既知2行だけ。それ以外の ERROR・WARNING・leaked・still in use は0件。未追跡ファイルは新しいテストとデモ（.uid を含む）だけ。reports/ と addons/ は git の対象外。
不可視文字の混入: src・test・demo を grep -P で検索して0件。

## summary
- 比較の連なり
  - ExprParser は比較を1つまでにした。2つ目の比較演算子の位置でエラーにする。
  - メッセージは「比較は1つの式に1つまで」で、`(0 < x) * (x < 10)` の例を示す。
  - `(a < b) < c` は通る。
- 式の名前
  - ExprLexer は、非 ASCII で不可視文字ではない文字（`人口`、全角英字）を、その位置で名前の規則違反にする。
  - `$` `@` などの ASCII 記号と不可視文字は、従来の「使えない文字」のままにした。
- 数字の直後
  - `1e3`、`2x`、`0x10`、`1_000`、`1.5e3` は、英字か `_` の位置でエラーにする。
  - メッセージは指数表記が使えないことを述べ、`1000` と `2 * x` を示す。
- 定義の名前
  - `add_stock`、`add_constant`、`add_flow`、`add_flow_expr` に同じ規則を適用した。
  - 空白だけ、不可視文字だけ、前後に空白がある名前は拒否する。
  - メッセージには位置と文字（`'人'` のように引用符つき）、規則の文を入れる。
- #11 から呼ぶ共通部品（すべて `src/core/model_check.gd`）
  - `ModelCheck.check_identifier(name, what) -> String`：問題が無ければ空文字、あれば直し方つきの理由を返す。
  - `ModelCheck.is_name_start(code)`、`ModelCheck.is_name_char(code)`、定数 `ModelCheck.NAME_RULE_HINT`。
  - 式の字句解析も同じ関数を使うので、規則は1か所にある。
- escape_reason
  - `excerpt_at` は、`escape_backslash=false` のとき `\\` と `\u{XXXX}` を1単位として切る。
  - 判定は新しい `_escaped_unit_length` に共通化し、`limit_escaped` もこれを使う。
  - 閉じ括弧が無い、16進数でない、桁数が1〜6でない `\u{` は1文字として扱う。以前は、遠くの `}` まで1単位にしていた。
- デモ：`demo/name_rule_demo.gd` を新設した。`demo/expr_parse_demo.gd` の既定の式に、`0 < x < 10`、`(a < b) < c`、`(0 < x) * (x < 10)`、`人口 * 0.02`、`1e3`、`2x` を足した。

## demo
1. `godot --headless --path . -s res://demo/expr_parse_demo.gd`
   - `0 < x < 10`：位置6で「比較は1つの式に1つまで」と `(0 < x) * (x < 10)` の例が出る。
   - `(a < b) < c`：構文木 `(< (< a b) c)` が出る。
   - `人口 * 0.02`：位置0で、名前の規則を示すエラーになる。
   - `1e3` と `2x`：位置1で、指数表記が使えないことと `1000`、`2 * x` の書き方が出る。
2. `godot --headless --path . -s res://demo/name_rule_demo.gd`
   - `人口`、空白だけ、U+200B だけ、` pop`、`1st`、`rate%`、フロー名 `増加` が、それぞれ規則つきのエラーになる。
   - `population` と `growth_rate` は OK になる。

## 受け入れ基準とコミット
- 基準1（比較の連なり）と基準5（既存テスト2件の書き換え）：70b3fe0
- 基準6（escape_reason）：011044d
- 基準2・3・4：50adf90
- T3-3 への対応
  - 基準2・3・4は、`ModelCheck`、字句解析、`SimModel` の変更が絡んで分けにくいので、1コミットにまとめた。
  - 011044d の `model_check.gd` には、名前の規則の共通関数も入っている。同じファイルで、先に分けるとテストが通らない状態が残るためである。

## 列挙表（T4-1）
### 基準「6種類の比較演算子のどれでも」
- 列挙：`grep -n "LT\|LE\|GT\|GE\|EQ\|NE" src/expr/expr_parser.gd` の `_is_comparison` で6種類。テストの `OPERATORS` の件数も6で、`assert_int(OPERATORS.size()).is_equal(6)` で固定した。
- 演算子は6種類、組み合わせは6×6の36通りで、すべて1つのテストの中で回している。

| 対象 | テスト名 |
|---|---|
| `<` | ExprComparisonChainTest.test_every_pair_of_the_six_comparison_operators_is_rejected_at_the_second_one（`<` を1つ目、2つ目の両方で回す） |
| `<=` | 同上 |
| `>` | 同上 |
| `>=` | 同上 |
| `==` | 同上 |
| `!=` | 同上 |
| 単独の比較は通る（6種類） | ExprComparisonChainTest.test_single_comparison_is_unchanged |
| 題材の式（`0 < x < 10`、`a == b == c`、`a < b == c`、`a == b != c`） | test_examples_from_the_story_are_rejected |

### 基準「ストック・定数・フローの定義の名前」
- 列挙：`grep -nP "^func (add_(stock|constant|flow)\w*)\(" src/core/sim_model.gd` で4件（add_stock、add_constant、add_flow、add_flow_expr）。
- 漏れ防止：`test_definers_list_covers_every_add_function_that_defines_a_stock_constant_or_flow` がこのソースを同じ正規表現で読み、`DEFINERS` と一致することを確かめる。

| 対象 | テスト名（DefinitionNameTest） |
|---|---|
| add_stock | test_valid_names_are_accepted_by_every_definer、test_bad_names_are_rejected_by_every_definer_and_model_is_unchanged、test_blank_and_invisible_only_names_are_rejected_as_empty、test_every_hostile_string_is_rejected_by_every_definer（4件とも `DEFINERS` に add_stock を含む） |
| add_constant | 同上 |
| add_flow | 同上 |
| add_flow_expr | 同上 |

- 不可視文字だけの名前、空白だけの名前、前後に空白がある名前は、`test_bad_names_are_rejected_by_every_definer_and_model_is_unchanged`、`test_blank_and_invisible_only_names_are_rejected_as_empty`、`test_whitespace_around_a_name_is_not_trimmed` で確かめる。

## 経路の表（T2-1、T4-2）
- 入口は、定義の名前、式（演算子・名前・数）、原因の文。出口は、エラー文（last_error）と構文エラーの `format()`。
- 列1〜4は T2-1 の不変条件、列5は生のバイト列、列6は出力の長さと組み合わせ、列7は処理量。

| 入口 → 出口 | 1 有限性 | 2 失敗の返し方 | 3 上限 | 4 エスケープ | 5 生のバイト列 | 6 長さ・組み合わせ | 7 処理量 |
|---|---|---|---|---|---|---|---|
| 定義の名前（add_stock・add_constant・add_flow・add_flow_expr）→ last_error | 該当なし。名前は数値を扱わない。値の検査は既存の check_finite のまま。 | `ERR_INVALID_PARAMETER` と last_error。成功時は空にする（DefinitionNameTest）。失敗時はモデルが変わらない（同テスト）。 | 名前の長さ上限64は check_name が先に判定する（test_check_identifier_is_shared_and_returns_empty_for_a_good_name）。 | 位置の文字は `escape()` を通す。HostileValues の全件で生の不可視文字が0件（test_every_hostile_string_is_rejected_by_every_definer）。 | Godot の String は UTF-32 で、不正な UTF-8 は入口の外（ファイル・標準入力）で処理される。今回は新しい入口が無い。`char(0x0A)` を含む名前は test_bad_names_are_rejected_by_every_definer_and_model_is_unchanged、NUL は HostileValues に無いので該当なし。 | `escape()` は1文字だけを通す。last_error は `limit_last_error` で1000字以内（test_every_hostile_string_is_rejected_by_every_definer）。 | 名前は最大64字で、O(64)。長さ10万の名前は check_name で拒否され、規則の走査に入らない。実測は、10万字の名前を含む HostileValues 全件×4関数で、スイート全体が約27秒で変わらない。 |
| 式の名前（非 ASCII）→ 構文エラー | 該当なし。数値を作らない。 | 構文エラーを返す。`ExprParseResult` の ok が false、root が null（_error ヘルパで確認）。 | 式の長さ上限1000は既存のまま。 | 文字は `escape_expression` を通す（test_invisible_characters_in_a_name_are_escaped_in_the_message）。 | 該当なし。字句解析は String を受け取るので、バイト列の読み取りは入口の外。 | message は200字以内。固定文＋1文字なので、表記が切れることは無い。 | 字句解析1回でエラー位置まで。最大1000字で、O(n) のまま。 |
| 式（数字＋英字）→ 構文エラー | `1e3` は有限の数にならない前にエラーにする。巨大リテラルの有限性は既存の検査のまま。 | 構文エラーを返す（test_letter_or_underscore_right_after_a_number_is_rejected_at_that_letter）。 | 同上。 | 英字・`_` は ASCII だけで、エスケープ対象が出ない。 | 該当なし。 | 固定文で約100字。200字以内。 | O(n)。 |
| 式（比較の連なり）→ 構文エラー | 該当なし。 | 構文エラーを返す。 | 深さ上限は既存のまま。`(a < b < c)` のように入れ子の中でも拒否する（test_chain_inside_parentheses_and_call_arguments_is_rejected）。 | 演算子は ASCII だけ。 | 該当なし。 | 固定文＋演算子で、200字以内。 | 再帰下降で、O(n) のまま。 |
| 原因の文（式の構文・評価のメッセージ）→ last_error・format() | 該当なし。 | 該当なし。この経路は失敗を作らず、文を整える。 | 200字で切る。 | `escape_backslash=false` のとき、`\\` と `\u{XXXX}` を1単位として扱う。 | 該当なし。 | EscapeReasonTest：切れ目を1文字ずつずらして、本文が表記の並びになることを正規表現で確かめる。奇数個の `\` で終わらない。limit_escaped と同じ位置で切る。 | `excerpt_at` は limit に達した時点で止まる。10万字の入力も HostileValues 全件で通る（test_every_hostile_string_through_escape_reason_stays_within_the_limit）。 |

## 列7の規模と実測
- 今回の変更は、ターン数や要素数に比例する処理を持たない。
  - 名前の検査は、最大64字の走査。
  - 字句解析は、式の長さ1000字以内で、1字句あたりの判定が定数時間。
  - `excerpt_at` は、200字に達した時点で止める。
- 実測はテストの総時間で代えた。分岐元は約24秒、今回は約27秒。差は誤差で、新しい34件のテストが加えた時間を含む。
- 独立した測定スクリプトは置いていない。

## assumptions
- 名前の規則を適用するのは、ストック・定数・フローの定義の名前だけにした。
  - アクション名と終了条件の名前は、基準に無いので変えない。
  - これらは式から参照されず、画面の表示にも使うので、今の `check_name` のままとする。
  - `test_actions_and_conditions_keep_their_free_form_names` で、日本語名が通ることを固定した。
  - もし同じ規則を求めるなら、`_check_new_name(..., true)` に変えるだけで済む。
- 「表示に使う名前は、モデルとは別に持つ」は、ここでは設計の方針として扱い、API は足していない。
  - 受け入れ基準に表示名の API が無いためである。
  - ストックの表示名を持たせるかは、別の PBI で決める必要がある。
  - docstring にその方針を書いた。
- 非 ASCII の判定は「コードポイント 0x80 以上で、不可視文字でないもの」にした。不可視文字は従来の「使えない文字」エラーにして、`\u{XXXX}` の形で出す。
- `test/fixtures/hostile_names_model.gd` を、`add_stock` でなく内部の `_stocks` へ直接入れる形に直した。
  - 理由は、`=cmd` や `@sum` などの名前が、新しい規則で `add_stock` に拒否されるためである。
  - このフィクスチャを使う既存のテスト `test_hostile_names_in_header` は、変えずに通っている。CSV の見出しの防御は、規則を通らないモデルに対しても有効なまま確かめている。
  - 受け入れ基準の「既存テストを変えない」は、テスト本体を指すと解釈した。フィクスチャの変更は、テストの期待を変えない。
- 「何の `escape_reason` か」を確かめる新しいテストが、旧実装で失敗することは、旧実装で走らせて確かめてはいない。切れ目を1文字ずつずらすテストなので、旧実装なら表記の途中で切れて失敗する設計である。
- ワークツリーに `addons/`（gdUnit4）が無かったため、メインのリポジトリから `addons/` をコピーして実行した。`addons/` は git の対象外。

## unresolved
- 補助変数（#11）の名前は、`ModelCheck.check_identifier` を呼べば同じ規則になる。`SimModel._check_new_name(name, what, true)` も使える。これは `scrum/22` から分岐して積む前提で、この PBI の外。
- アクション名・終了条件の名前を、名前の規則の対象にするかは、PO の判断が要る（上の assumptions）。
