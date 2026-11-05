# Sprint 2 のデモ
## ゴール
スプリントの終わりに、PO はテキスト版で小さな町を起動し、Enter でターンを進めて、人口・食料・お金が式どおりに変わっていく様子を見られる。壊れた値や危険な式を入れると、町が壊れる前にエラーで止まることも確かめられる。

## 動かし方
```
bash .scrum/demos/sprint-2/demo.sh [コードのディレクトリ] [--rehearse]
```
- コードのディレクトリを省くと、リポジトリの直下のコードを動かす。
- 前提：Godot 4.7.1 が `~/.local/bin/godot` にあること。gdUnit4 が無ければ、場面 0 で `scripts/setup.sh` が導入する（`git`、`curl`、`unzip`、`sha512sum` が要る）。
- 所要時間：1 分ほど（setup が走る場合は、ダウンロードの分が増える）。
- 場面 4 は、`--rehearse` が無ければ標準入力をつないだまま起動する。PO が Enter を押して 1 ターンずつ進め、`q` で終える。`--rehearse` を付けると、Enter 12 回と `q` を自動で入力して最後まで進む。
- 場面 4 を単独で動かすコマンド：
  ```
  godot --headless --path <コードのディレクトリ> -s res://demo/text_town.gd
  ```
- 既知の出力：場面 0 の `scripts/test.sh` の冒頭に、debugger ポートの `ERROR: The remote port number must be between 1 and 65535 ...` と `ERROR: Remote Debugger: Unable to connect to host '127.0.0.1:0'.` が出る。gdUnit4 のコマンドラインの仕様による既知の出力で、不具合ではない。これ以外に ERROR と WARNING は出ない。

## 台本
| # | PO の操作 | 期待する結果 | PBI |
|---|---|---|---|
| 0 | `scripts/test.sh` を実行する（demo.sh の最初に自動で実行される） | すべてのテストが通ったと表示される（124 件、0 failures、`Exit code: 0`） | 全体 |
| 1 | デモ用スクリプト（`demo/model_validation_demo.gd`）で、NaN の初期値・無限大の量・空の名前・未定義の名前の取得を SimModel に渡す | どれも Error と、制御文字をエスケープした理由が表示される。正しい定義の後は last_error が空に戻る | #16 |
| 2 | フローを式で書いたモデルを数ターン進める（`demo/flow_expression_demo.gd` の 1・2） | 式どおりに値が変わる（人口 100 → 110 → 121 → 133.1）。`1/2` は 0.5 になる | #10 |
| 3 | 0 除算の式や `OS.get_name()` を含むモデルを動かす（同じスクリプトの 3・4） | 0 除算はそのターンでエラーになり、ストックの値とターン番号は変わらない。`OS.get_name()` は組み立て時に位置つきエラーで拒否される | #10 |
| 4 | 上の「動かし方」の手順でテキスト版の町を起動し、Enter で 12 ターン進めて `q` で終える（`demo/text_town.gd`） | 毎ターン、人口・食料・お金が 1 行で表示され、変化していく | #4 |

## 後片付け
- テストのレポート `reports/` は、`demo.sh` が元から無かった場合だけ、終了時に消す。
- 一時ディレクトリ（場面 4 の入力ファイル）は、終了時に自動で消える。
- `scripts/setup.sh` が入れたもの（`addons/gdUnit4/`、`~/.local/opt/godot/`）は、git の管理外のまま残る。不要なら手で消す。
