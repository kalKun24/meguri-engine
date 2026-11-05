# Sprint 1 のデモ
## ゴール
スプリントの終わりに、PO は README の手順でテストを流して全件の通過を確かめ、ストックがフローでターンごとに一斉に動く様子と、書き間違えた式の誤りが位置つきで指摘される様子を、デモ用のスクリプトで見られる。

## 動かし方
```
bash .scrum/demos/sprint-1/demo.sh [コードのディレクトリ]
```
- コードのディレクトリを省かないと、リポジトリの直下のコードを動かす。
- 前提：Godot 4.7.1 が `~/.local/bin/godot` にあること、gh CLI（`gh auth login` 済み）があること。gdUnit4 が無ければ、場面 1 で `scripts/setup.sh` が導入する（`git`、`curl`、`unzip`、`sha512sum` が要る）。
- 所要時間：1 分ほど（setup が走る場合は、ダウンロードの分が増える）。
- 待つ場面は無く、最後まで進んで終わる。`--rehearse` を渡しても同じである。

## 台本
| # | PO の操作 | 期待する結果 | PBI |
|---|---|---|---|
| 1 | README の手順で `scripts/test.sh` を実行する | すべてのテストが通ったと表示される（48 件、0 failures、`Exit code: 0`） | #1 |
| 2 | PR の Checks 欄と、意図的に失敗させたときの記録を開く（draft PR #13 と、3 つの run の URL） | 成功 2 件（success）と失敗 1 件（failure）が Actions に出ている | #1 |
| 3 | デモ用のスクリプト（`demo/stock_flow_demo.gd`）で A→B→C のモデルを 3 ターン進める | 各ターンのストックの値と、turn_finished で受け取ったターン番号が表示される | #2 |
| 4 | フローの定義順を入れ替えたモデルで 3 と同じことをする（同じスクリプトの 2 つ目の出力） | 3 と同じ値が表示される | #2 |
| 5 | 式のデモ用スクリプト（`demo/expr_parse_demo.gd`）に、正しい式と誤った式（`population * `、`a.b`、`OS.get_name()`、閉じていない括弧）を渡す | 正しい式は構文木が表示され、誤った式は原因と文字位置つきのエラーが表示される | #9 |

場面 2 で見る URL：
- draft PR：https://github.com/kalKun24/meguri-engine/pull/13
- 成功 run：https://github.com/kalKun24/meguri-engine/actions/runs/42022965513 、https://github.com/kalKun24/meguri-engine/actions/runs/42023246682
- 失敗させた run：https://github.com/kalKun24/meguri-engine/actions/runs/42023098068

場面 5 で自分の式を試すには、次を実行する。
```
godot --headless --path <コードのディレクトリ> -s res://demo/expr_parse_demo.gd -- "a + b" "f(1,"
```

## 後片付け
- テストのレポート `reports/` は、`demo.sh` が元から無かった場合だけ、終了時に消す。
- `scripts/setup.sh` が入れたもの（`addons/gdUnit4/`、`~/.local/opt/godot/`）は、git の管理外のまま残る。不要なら手で消す。
