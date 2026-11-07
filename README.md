# Meguri

ストック&フローで動くシミュレーションゲームを作るための、Godot 4 用の基盤である。目的・範囲・技術方針は `.scrum/inception-deck.md` に書かれている。

## 固定している版

CI と手元で、次の同じ版を使う。更新は PBI として計画して行う。

| 対象 | 版 | 備考 |
|---|---|---|
| Godot | 4.7.1 stable（標準ビルド、Linux x86_64） | .NET（mono）版は使わない |
| gdUnit4 | タグ `v6.2.3` | gdUnit4 の `v6.2.x` が対応する Godot は 4.5〜4.7.1 である |
| GitHub Actions の Action | `actions/checkout` v7.0.1（コミット `3d3c42e5aac5ba805825da76410c181273ba90b1`） | |
| GitHub Actions の実行環境 | `ubuntu-24.04` | |

版は `scripts/setup.sh`（Godot と gdUnit4）と `.github/workflows/test.yml`（Action と実行環境）に書いてある。CI も手元と同じ `scripts/setup.sh` と `scripts/test.sh` を呼ぶので、Godot と gdUnit4 の版は1か所（`scripts/setup.sh`）にしかない。

gdUnit4 公式の GitHub Action（`gdUnit4-action`）は使わない。gdUnit4 v6 では、この Action がヘッドレスで動かず仮想ディスプレイを使うことと、Godot と gdUnit4 の版を Action の入力に別に書く必要があることによる。

## 手順（Linux x86_64）

必要なもの：`git`、`curl`、`unzip`、`sha512sum`。sudo は要らない。

1. クリーンな clone を作る。
   ```
   git clone https://github.com/kalKun24/meguri-engine.git
   cd meguri-engine
   ```
2. Godot と gdUnit4 を導入する。Godot は `~/.local/opt/godot/4.7.1-stable/` に入り、`~/.local/bin/godot` にシンボリックリンクが張られる。gdUnit4 は `addons/gdUnit4/` に入る（git の管理外）。Godot の zip は SHA-512 を確かめてから展開する。
   ```
   scripts/setup.sh
   ```
3. `~/.local/bin` が `PATH` に入っていることを確かめる。
   ```
   godot --version
   ```
   `4.7.1.stable` で始まる表示になる。
4. テストを実行する。`godot --headless` で `test/` のテストを回す。
   ```
   scripts/test.sh
   ```
   すべて通ると、最後に `Exit code: 0` と、`0 failures` を含む `Overall Summary` が表示される。1件でも失敗すると、終了コードが 0 以外になる（`echo $?` で確かめられる）。
   - `ERROR: The remote port number must be between 1 and 65535` と `Unable to connect to host '127.0.0.1:0'` が出るが、問題ではない。gdUnit4 が、デバッガに繋がないようにわざと使っているポートである。

テスト結果は `reports/` に出る（git の管理外）。

## テスト

- テストは gdUnit4 で書き、`test/` に置く。

## デモ

どれも画面なしで動く。

### ストックとフロー

`demo/stock_flow_demo.gd` は、A→B→C の2本のフローを持つ `SimModel` を3ターン進め、各ターンのストックと `turn_finished` のターン番号を表示する。フローの定義順を入れ替えたモデルでも同じ値になる。

```
godot --headless --path . -s res://demo/stock_flow_demo.gd
```

### 壊れた値の検査

`demo/model_validation_demo.gd` は、NaN の初期値、無限大の量、空の名前、制御文字を含む名前、未定義の名前の取得を `SimModel` に渡す。どれも `Error` と、制御文字を `\u{XXXX}` にエスケープした理由が表示される。最後に正しい定義を1つ行い、`last_error` が空に戻ることを見る。

```
godot --headless --path . -s res://demo/model_validation_demo.gd
```

### 式のパーサ

`demo/expr_parse_demo.gd` で、`src/expr/` の式のパーサ（自前の字句解析と構文解析。評価はしない）を試せる。正しい式は構文木（S 式）、誤った式は原因と文字位置つきのエラーが表示される。

```
godot --headless --path . -s res://demo/expr_parse_demo.gd
godot --headless --path . -s res://demo/expr_parse_demo.gd -- "a + b" "f(1,"
```

2行目のように `--` の後ろに式を並べると、その式を調べる。

### 式で書くフローの量

`demo/flow_expression_demo.gd` は、フローの量を式で書いた `SimModel`（`add_flow_expr`）を試す。次の4点を表示する。

1. 人口が増えると食料が減るモデルを3ターン進め、式どおりに値が変わる。
2. `1/2` が 0.5 になる（すべて float で評価する）。
3. 許可されていない関数、未定義の名前、`OS.get_name()`、`()` なしの `min`、`Vector2(1, 2)`、引数の数の誤り、400 桁の数が、式の抜粋と文字位置つきのエラーになる。
4. 0 除算がターン番号つきの実行時エラーになり、そのターンではストックの値もターン番号も変わらない。

```
godot --headless --path . -s res://demo/flow_expression_demo.gd
```

### プレイヤーのアクション

`demo/action_demo.gd` は、お金を払って farmland を増やすアクション（`add_action`・`apply_action`）を試す。次の4点を表示する。

1. お金が足りるとき、実行できて、次のターンの生産が増える。`action_applied` のシグナルを受け取った表示も出る。
2. 1ターンに何回でも実行でき、費用は毎回かかる。
3. お金が足りないとき、理由つきのエラーになり、お金も farmland も変わらない。
4. 未定義のアクションは、エラーになる。

```
godot --headless --path . -s res://demo/action_demo.gd
```

### 見えない文字のエスケープ

`demo/escape_demo.gd` は、U+202E（右から左）、U+200B（ゼロ幅）、U+00AD（ソフトハイフン）、異体字選択子、タグ文字を含むストック名や式を、`SimModel` と式のパーサに渡す。どのエラー文でも、それらが `\u{XXXX}` の形で見える。構文エラーの `^` は、エスケープ後の式の文字の下に来る。

```
godot --headless --path . -s res://demo/escape_demo.gd
```

エスケープの対象は、`ModelCheck.ESCAPE_RANGES`（コードポイントの範囲表）で決める。表は `scripts/gen_invisible_ranges.py` で生成する（Unicode 16.0.0）。

### エラー文に出す式の長さの上限

`demo/excerpt_demo.gd` は、10万文字の式と、不可視文字 10万字の式を `add_flow_expr` に渡す。さらに、上限内で通る長い式が実行時に失敗する場合と、アクションの条件・効果が失敗する場合も試す。どの `last_error` も、式を先頭の抜粋に切り、末尾を「...」にする。位置は数字で出る。

```
godot --headless --path . -s res://demo/excerpt_demo.gd
```

- 式の抜粋は 200 文字まで（`ModelCheck.MAX_EXPRESSION_EXCERPT_LENGTH`）。原因の説明も 200 文字まで（`MAX_MESSAGE_REASON_LENGTH`）。長さは、エスケープした後で数える。`\u{XXXX}` の表記は、途中で切らない。
- `last_error` 1件の全体は 1000 文字まで（`MAX_LAST_ERROR_LENGTH`）。
- 位置が抜粋の外にあるときは、位置の数字だけが残る。`ExprSyntaxError.format()` の `^` の行も、このときは出ない。
- 式をエラー文に出すときは、`ModelCheck.escape_expression()` を使う。式の全文を出す関数は無い。

### テキスト版の小さな町

`demo/text_town.gd` は、人口・食料・お金の3つのストックを持つ仮モデル（`src/sample/town_model.gd`）を、画面なしで1ターンずつ動かす。仮モデルは GDScript のコードで書いてあり、モデルの定義形式は M2 で決める。

```
godot --headless --path . -s res://demo/text_town.gd
```

- 起動すると、使えるアクションの一覧（番号つき）と、ターン0の状態が `0: 人口=100.0, 食料=120.0, お金=100.0` の形で表示される。
- Enter（空行）で次のターンに進み、毎ターン同じ形で1行表示される。数値は小数第1位までである。
- アクションは、**番号**（`1`）、**アクション名**（`expand_farmland`）、**表示名**（`畑を広げる`）のどれかを打って選ぶ。アクションを実行してもターンは進まない。何回でも選べる。
  - `1` 畑を広げる：お金 50 を払い、畑が 20 増える。広げるたびに値段が 1.2 倍になる。
  - `2` 税率を上げる：税率が 0.1 上がる（上限 1.0）。
  - `3` 税率を下げる：税率が 0.1 下がる（下限 0.0）。
- 実行できないとき（お金が足りない、税率が上限・下限にある）は、理由が表示され、ターンは進まない。入力待ちに戻る。
- 分からない入力（アクションにない番号や名前）は、何もせずに、一覧をもう一度表示する。
- `q` で終わる。標準入力が終わった（EOF）ときも終わる。
- 1行は 200 文字までで、超えた分は切り詰める（標準入力では、メモリを使わないよう、超えた分を読み捨てる）。
- 入力を決めて試すときは、入力ファイル（例：Enter 2 回、`1`、Enter 3 回、`q`）を作り、`< ファイル` で渡す。

```
godot --headless --path . -s res://demo/text_town.gd < input.txt
```

### 自動実行（N ターン回して CSV に出す）

`demo/auto_run_demo.sh` は、プレイヤーなしでモデルを N ターン回し、各ターンの全ストックの値を CSV に出す入口（`src/auto_run/auto_run_main.gd`）を試す。次の6点を表示する。

1. サンプルの町を、シード 1 で 30 ターン回し、CSV を標準出力に出す。
2. 同じ指定で2回回してファイルに出し、`cmp` でバイト単位の一致を確かめる。
3. 上限を超える N（100001）が、標準エラーに理由が出て、終了コード 2 になる。
4. `build` の無いクラスが、終了コード 2 になる。
5. 実行時エラー（ターン 4 で 0 除算）が、そのターンまでの CSV を標準出力に、理由を標準エラーに分けて出し、終了コード 1 になる。
6. 出力先の親ディレクトリが無いと、終了コード 3 になる。

```
demo/auto_run_demo.sh
```

入口を直接呼ぶときは、次のようにする。`--` より後ろが入口の引数である。`--no-header` を付けないと、Godot のバナーが標準出力に混ざって、CSV の先頭に入る。

```
godot --headless --no-header --path . -s res://src/auto_run/auto_run_main.gd -- --model=res://src/sample/town_model.gd --turns=30 --seed=1 --out=town.csv
```

**引数**（すべて `--名前=値` の形で、順序は問わない。同じ引数を2回書くとエラーになる）

| 引数 | 必須 | 意味 |
|---|---|---|
| `--model=パス` | 必須 | `build()`（引数なしで呼べるもの）を持ち、`SimModel` を返す GDScript のクラス。`res://` の下の `.gd` に限り、256 文字まで。NUL・制御文字・不可視文字・バックスラッシュ・`..` を含むパスは断る。`RefCounted` のクラスに限る。**指定した GDScript のコードを実行する**ので、信頼できるモデルだけを指定する |
| `--turns=N` | 必須 | 回すターン数。1 以上 100000 以下の整数。（N+1）×ストックの数が 1,000,000 を超える指定は、実行の前にエラーにする |
| `--seed=S` | 省略時は 0 | 整数（符号を除いて 18 桁まで）。モデルの `set_seed()` に渡す（戻り値は `Error`。終わったモデルには渡せず `ERR_LOCKED` になる）。シードを使う処理は #34 から入る |
| `--out=ファイル` | 省略時は標準出力 | CSV を書くファイル |

**出力先のファイル**

- 既にあるファイルは、確認せずに**上書き**する（短くなったときに古い内容は残らない）。
- 親ディレクトリが無いときは、作らずに**エラー**にする（終了コード 3）。ディレクトリを指定したときと、書き込みに失敗したときも同じ。
- 空白だけのパス、1024 文字を超えるパス、制御文字・不可視文字を含むパス、`res://` と `uid://` で始まるパス（ソースを上書きしないため）は断る。
- 書き込みの途中で失敗すると、途中までの内容が残ることがある。
- `--out` を付けたとき、標準出力には何も出ない。

**終了コード**

| コード | 意味 | CSV |
|---|---|---|
| 0 | 成功（勝利・敗北で N の前にゲームが終わったときも含む。そこまでの CSV を出す） | 出す |
| 1 | 実行時エラー（0 除算、ストックが NaN・無限大になる、など）で途中で止まった | そのターンまでを出す |
| 2 | 引数・モデルの誤り、上限の超過 | 出さない |
| 3 | 出力先に書けない | 書けなかった |

理由は標準エラーに「エラー：…」の1行で出す。CSV には混ぜない。利用者由来の文字（パス、ストック名など）は、不可視文字を `\u{XXXX}` にエスケープし、長いものは省いて出す。

**CSV の形**

- 1行目は見出し（`turn` と、ストックの名前を定義順に並べたもの）。2行目以降が、ターン 0（初期値）から N までの行である。
- 行の終わりは CRLF（RFC 4180）。文字コードは UTF-8。
- 値は、読み戻すと同じ値になる最短の表記で出す（`%.1f` のように丸めない）。文字列化は `CsvFormat.format_float()` の1か所にある。表記は Godot の版で決まるので、バイト単位で同じになるのは、同じ Godot の版・同じモデル・同じシード・同じ N のときである。
- 名前は、カンマ・引用符を含むとき RFC 4180 に従って `"` で囲み、中の `"` を二重にする。先頭（空白を除く）が `=` `+` `-` `@` のときは、表計算ソフトが式として扱わないよう、先頭に `'` を足す。不可視文字・制御文字・改行は `\u{XXXX}` にエスケープし、バックスラッシュは二重にする（`CsvFormat.escape_field()`）。値の列には `'` を足さない。
- GDScript の文字列には NUL を入れられない（Godot が U+FFFD に置き換える）。不正な UTF-8 の引数も同じで、置き換えられた後の文字列として検査される。

コードから使うときは、`AutoRunner.new().run(model, turns, seed)` が `AutoRunResult`（`rows`・`stock_names`・`error`・`message`・`seed`・`game_result`・`to_csv()`）を返す。ターンは `SimModel.advance_turn()` で進める。

モデルに勝利・敗北の条件があり、N に達する前にゲームが終わったときは、そこで止まる。CSV の最終行は終了したターン、終了コードは 0 で、終わった理由は標準エラーに「ゲームが終わった：勝利（条件「…」、ターン …）」の1行で出る。詳しくは次の節を見る。

### 勝利と敗北の条件

`demo/end_condition_demo.gd` は、勝利と敗北の条件を式で書いたモデルを自動で回す。次の5点を表示する。

1. 「人口が 120 以上」で勝利するモデルが、30 ターンの指定でも勝利のターン（4）で止まり、勝利と条件の名前が出る。
2. 「お金が 0 以下」で敗北するモデルが、敗北のターンで止まる。
3. 同じターンに勝利と敗北が成り立つモデルで、既定は敗北になり、`set_simultaneous_priority("victory")` で勝利に変わる。
4. 終わった後に `step()`・`advance_turn()`・`apply_action()` を呼ぶと、`ERR_LOCKED`（Locked）と「ゲームは終了している」が返り、ストックの値が変わらない。
5. 自動実行の入口（`AutoRunCli`）で、N の前に終わると、終了コード 0、最終行は終了したターン、理由は標準エラーに出る。

```
godot --headless --path . -s res://demo/end_condition_demo.gd
```

使い方（コードから）

```gdscript
model.add_victory_condition("人口が120以上", "population >= 120")
model.add_defeat_condition("お金が0以下", "money <= 0")
model.set_simultaneous_priority(GameResult.OUTCOME_VICTORY)  # 省くと、同時のときは敗北を採る
model.game_ended.connect(_on_game_ended)  # (outcome: String, condition_name: String, turn: int)
model.advance_turn()
var result: GameResult = model.get_result()  # outcome は "victory"・"defeat"・"pending"
```

- 条件は式で書き、ストックと定数を参照できる。0 以外なら成り立つ。名前はストック・定数・フロー・アクションと同じ名前空間にあり、個数は `ModelCheck.MAX_DEFINITIONS`（1000）を共有する。式が参照するストックと定数は、先に定義する。
- 判定は、`advance_turn()` が成功したターンの最後に1回だけ行う。ターン 0（初期状態）、`apply_action()` の直後、`step()` では判定しない。ゲームを進める入口は `advance_turn()` である。
- 同じターンに勝利と敗北が成り立ったら、`set_simultaneous_priority()` で決めた側を採る（既定は敗北）。同じ種類の中では、定義の順で最初に成り立ったものを採る。
- `game_ended` は `turn_finished` の後に発火する。
- 終わった後の `step()`・`advance_turn()`・`apply_action()` は `ERR_LOCKED` を返し、状態を変えない。`last_error` は「ゲームは終了している」である。
- 終わった後は、モデルを変える関数もすべて `ERR_LOCKED` を返し、状態を変えない。対象は `add_stock`・`add_constant`・`add_flow`・`add_flow_expr`・`add_auxiliary`・`add_action`・`add_victory_condition`・`add_defeat_condition`・`set_simultaneous_priority`・`set_seed`・`validate` である。`game_ended` や `turn_finished` の受け手の中から呼んでも同じである。読むだけの関数（`get_*`・`has_*`・`is_ended` など）は終わった後も使える。
- `set_seed()` は `Error` を返す。成功すると `OK` を返して `last_error` を空にし、終わった後は `ERR_LOCKED` を返して種を変えない。
- 条件の式の評価に失敗したら（0 除算、NaN・無限大）、そのターン全体（ストック・定数・ターン番号・乱数の状態）を取り消し、`FAILED` を返す。ゲームは終わらない。判定では、成り立つ条件が先に見つかっても、すべての条件を評価する。
- テキスト版（`TextPlayer`）は、ゲームが終わると結果を表示して終わる。

## CI

`.github/workflows/test.yml` が、PR と `main` への push のたびに、`scripts/setup.sh` と `scripts/test.sh` を実行する。失敗したテストがあると、ジョブが失敗になる。
