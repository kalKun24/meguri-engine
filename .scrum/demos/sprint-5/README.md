# Sprint 5 のデモ
## ゴール
スプリントの終わりに、PO は、補助変数を使ったモデルが定義の順に関わらず同じ値になることと、上限・下限でストックが止まることを確かめられる。式や名前の書き間違いと実行時エラーでは、直し方と原因の名前が示される。

## 動かし方
```
bash .scrum/demos/sprint-5/demo.sh [コードのディレクトリ] [--rehearse]
```
- コードのディレクトリを省くと、リポジトリの直下のコードを動かす。
- 前提：Godot 4.7.1 が `~/.local/bin/godot` にあること。gdUnit4 が無ければ、場面 0 で `scripts/setup.sh` が導入する（`git`、`curl`、`unzip`、`sha512sum` が要る）。
- 所要時間：1 分ほど。
- 待つ場面は無い。`--rehearse` は受け取るだけで、動作は変わらない。
- 場面ごとに単独で動かすコマンド：`godot --headless --path <コード> -s res://demo/<名前>.gd`（場面 1：`expr_parse_demo.gd`・`name_rule_demo.gd`、場面 2：`range_demo.gd`、場面 3：`auxiliary_demo.gd`、場面 4：`error_names_demo.gd`）。
- 既知の出力：場面 0 の `scripts/test.sh` の冒頭に、debugger ポートの `ERROR: The remote port number must be between 1 and 65535 ...` と `ERROR: Remote Debugger: Unable to connect to host '127.0.0.1:0'.` が出る。gdUnit4 の仕様による既知の出力で、不具合ではない。これ以外に ERROR と WARNING は出ない。
- 場面 1 の `構文エラー`、場面 2 の `Invalid parameter`・`Failed`、場面 3 の循環参照と `Failed`、場面 4 の実行時エラーは、誤った入力を渡したときの台本どおりの出力で、不具合ではない。

## 台本
| # | PO の操作 | 期待する結果 | PBI |
|---|---|---|---|
| 0 | `scripts/test.sh` を実行する（demo.sh の最初に自動で実行される） | すべてのテストが通る（437 件、0 failures、`Exit code: 0`）。ERROR は既知の 2 行だけ、WARNING・leaked・still in use は 0 件 | 全体 |
| 1 | `0 < x < 10`、`人口 * 0.02`、`1e3`、`2x` の式と、「人口」や空白だけの名前のストックを渡す（`demo/expr_parse_demo.gd`、`demo/name_rule_demo.gd`） | それぞれ位置つきで、直し方を示すエラーが出る（例：比較は 1 つまで。`(0 < x) * (x < 10)` のように書く／名前は半角英数字と _ だけで書く）。`(a < b) < c` は構文木になって通る | #22 |
| 2 | 下限 0・上限 100 の食料と、下限の無いお金を進める。下限が上限より大きい設定も渡す（`demo/range_demo.gd`） | 食料は増える側で 100、減る側で 0 に止まる。お金は 20、-10、-40、-70 と負まで減る。下限 100・上限 0 は `add_stock()` が `Invalid parameter` を返し、「下限が上限より大きい」と出る。式の `clamp` で下限が上限より大きいときも、名前と値つきの実行時エラーになる | #7 |
| 3 | 補助変数の定義の順だけを変えた 2 つのモデルを回し、循環するモデルも渡す。町のゴールデン値のテストを実行する（`demo/auxiliary_demo.gd`、`test/sample/town_golden_test.gd`） | 2 つは毎ターン同じ値になる（mood = 5、10、15）。循環は `a -> b -> a` の経路つきのエラーになる。町のゴールデン値のテスト 8 件が、#20 の期待値のまま通る | #11 |
| 4 | `stock / divisor` で divisor が 0 のモデルを回す（`demo/error_names_demo.gd`） | 実行時エラーに `0 で割った：0.0 / 0.0（stock = 0.0、divisor = 0.0）` のように、名前と値が出る。剰余・pow・sqrt も同様で、名前でない値（`divisor - divisor`）は名前を出さない | #23 |

## 後片付け
- 一時ファイルは `mktemp -d` の下に作り、終了時に自動で消える。
- テストのレポート `reports/` は、`demo.sh` の開始時に無かった場合だけ、終了時に消す。
- `scripts/setup.sh` が入れたもの（`addons/gdUnit4/`、`~/.local/opt/godot/`）は、git の管理外のまま残る。不要なら手で消す。
