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

どちらも画面なしで動く。

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
3. 許可されていない関数、未定義の名前、`OS.get_name()`、`()` なしの `min`、`Vector2(1, 2)`、引数の数の誤り、400 桁の数が、式の全文と文字位置つきのエラーになる。
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

## CI

`.github/workflows/test.yml` が、PR と `main` への push のたびに、`scripts/setup.sh` と `scripts/test.sh` を実行する。失敗したテストがあると、ジョブが失敗になる。
