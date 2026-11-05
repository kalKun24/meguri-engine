# Sprint 2 のリハーサル
- 日時：2026-11-05（スプリント2のデモ準備）
- 回：1
- 実行したコマンド：`bash .scrum/demos/sprint-2/demo.sh /home/kal24hi/Projects/meguri-engine/.claude/worktrees/sprint-2 --rehearse`（コード：統合ブランチ `scrum/sprint-2` の作業ディレクトリ /home/kal24hi/Projects/meguri-engine/.claude/worktrees/sprint-2、コミット 135bc9d）
- 1度目の通しで、すべての場面が一致した。出力の ERROR は、場面0の冒頭に出る gdUnit4 の debugger ポートの2行だけである。この2行は README に注記した既知の出力で、DoD の例外にあたる。WARNING は0件だった。

| # | 期待する結果 | 実際の出力（要点） | 判定 |
|---|---|---|---|
| 0 | すべてのテストが通る | `124 test cases \| 0 errors \| 0 failures`、`Exit code: 0` | 一致 |
| 1 | 壊れた定義はどれも Error と理由が出る。正しい定義の後は last_error が空に戻る | NaN の初期値・無限大の量・空の名前は `Invalid parameter`、未定義の名前の取得は `Does not exist` になった。制御文字は `x\u{000A}\u{202E}y` のようにエスケープされた。正しい定義は `OK` で、`last_error が空: true` と出た | 一致 |
| 2 | 式どおりに値が変わる。`1/2` は 0.5 | 人口 100→110→121→133.1、食料 1000→950→895→834.5。`1/2` を流入させた1ターン後の out = 0.5 | 一致 |
| 3 | 0 除算はそのターンでエラーになり、値とターン番号は変わらない。`OS.get_name()` は組み立て時に位置つきで拒否される | `OS.get_name()` は `[Parse error]` の位置2で拒否された。system・Vector2・未定義の名前・`min`・`min(1)`・400桁のリテラルも、位置つきで拒否された。0 除算は `step() = Failed` で、ターン番号は1、stock と divisor は 0.0 のまま変わらなかった。last_error は「ターン 2 の実行時エラー：…位置 6 で、0 で割った」 | 一致 |
| 4 | 毎ターン、人口・食料・お金が1行で表示され、変化する | 0〜12ターンを表示した。人口は 100.0→119.1（ターン3）→113.7、食料は 120.0→100.0、お金は 100.0→181.4 と変わり、q で終わった | 一致 |

## 出力の全文
場面0のテストの1件ずつの行は長いので省いた（124件、すべて PASSED）。それ以外は出力をそのまま貼る。

```
== 場面 0: README の手順でテストを実行する ==
ERROR: The remote port number must be between 1 and 65535 (inclusive).
ERROR: Remote Debugger: Unable to connect to host '127.0.0.1:0'.
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org
（124 件 PASSED。省略）
Overall Summary: 124 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Exit code: 0
scripts/test.sh の終了コード：0

== 場面 1: 壊れた定義（NaN の初期値・無限大の量・空の名前・未定義の名前）を SimModel に渡す ==
NaN の初期値 -> Invalid parameter / last_error="ストック「pop」の初期値が NaN である"
無限大の量 -> Invalid parameter / last_error="フロー「grow」の量が無限大である"
空の名前 -> Invalid parameter / last_error="ストック名が空である"
制御文字を含む名前の重複 -> Already exists / last_error="同名の定義がある：x\u{000A}\u{202E}y"
未定義の名前の取得 -> Does not exist / last_error="未定義のストック：no\u{0009}pe"
正しい定義 -> OK / last_error=""
  last_error が空: true

== 場面 2・3: フローを式で書いたモデルを進める。0 除算と OS.get_name() を含むモデルも動かす ==
1. 人口が増えると食料が減る（人口 += 人口 * 出生率、食料 -= 人口 * 1人あたりの消費量）
  ターン 0：人口 = 100.0  食料 = 1000.0
  ターン 1：人口 = 110.0  食料 = 950.0
  ターン 2：人口 = 121.0  食料 = 895.0
  ターン 3：人口 = 133.1  食料 = 834.5
2. すべて float で評価する
  1/2 を流入させた 1 ターン後の out = 0.5
3. 組み立て時のエラー（式の全文と文字位置つき）
  [Invalid data] フロー「f」の式に誤りがある（位置 4）：許可されていない関数：system（…）　式：1 + system(2)
  [Invalid data] フロー「f」の式に誤りがある（位置 13）：未定義の名前：lost_name（…）　式：population + lost_name
  [Parse error] フロー「f」の式に構文エラーがある（位置 2）：'.' は使えない。…　式：OS.get_name()
  [Invalid data] フロー「f」の式に誤りがある（位置 0）：'min' は関数である。関数は () を付けて呼ぶ（例：min(x1, x2)）　式：min
  [Invalid data] フロー「f」の式に誤りがある（位置 0）：許可されていない関数：Vector2（…）　式：Vector2(1, 2)
  [Invalid data] フロー「f」の式に誤りがある（位置 0）：関数 min の引数は 2 個である（実際は 1 個）　式：min(1)
  [Parse error] フロー「f」の式に構文エラーがある（位置 4）：数値リテラルが大きすぎて、有限の数にならない（400 桁）　式：1 + 9999…（省略）…9999
4. 0 除算は、ターン番号つきの実行時エラーになる。そのターンでは何も変わらない
  step() = OK  ターン番号 = 1  stock = 0.0  divisor = 0.0
  step() = Failed  ターン番号 = 1  stock = 0.0  divisor = 0.0
  last_error: ターン 2 の実行時エラー：フロー「share」の式の位置 6 で、0 で割った：0.0 / 0.0　式：stock / divisor

== 場面 4: テキスト版の町を起動し、Enter で 12 ターン進めて q で終える ==
起動するコマンド：godot --headless --path /home/kal24hi/Projects/meguri-engine/.claude/worktrees/sprint-2 -s res://demo/text_town.gd
(リハーサル：Enter 12 回と q を自動で入力する)
Enter で次のターンに進む。q で終わる。
0: 人口=100.0, 食料=120.0, お金=100.0
1: 人口=106.0, 食料=120.0, お金=110.0
2: 人口=112.4, 食料=114.0, お金=120.6
3: 人口=119.1, 食料=101.6, お金=131.8
4: 人口=117.5, 食料=100.0, お金=136.8
5: 人口=115.8, 食料=100.0, お金=141.5
6: 人口=114.9, 食料=100.0, お金=146.8
7: 人口=114.3, 食料=100.0, お金=152.3
8: 人口=114.0, 食料=100.0, お金=158.0
9: 人口=113.9, 食料=100.0, お金=163.8
10: 人口=113.8, 食料=100.0, お金=169.7
11: 人口=113.7, 食料=100.0, お金=175.5
12: 人口=113.7, 食料=100.0, お金=181.4

(リハーサル：終了)
```
（場面3の「（…）」は、許可関数の一覧を省いた印である。実際の出力には一覧が出る。）
