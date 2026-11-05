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

## CI

`.github/workflows/test.yml` が、PR と `main` への push のたびに、`scripts/setup.sh` と `scripts/test.sh` を実行する。失敗したテストがあると、ジョブが失敗になる。
