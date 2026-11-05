# Sprint 1 のリハーサル
- 日時：2026-11-05T21:13:03+09:00
- 回：1
- 実行したコマンド：`bash .scrum/demos/sprint-1/demo.sh /home/kal24hi/Projects/meguri-engine/.claude/worktrees/sprint-1 --rehearse`（コード：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/sprint-1、統合ブランチ `scrum/sprint-1` のコミット 6afa2fb）
- 経緯：1度目の通しでは、場面3・4の終わりに `WARNING: 6 ObjectDB instances were leaked` と `ERROR: 2 resources still in use` が出たので「不一致」とした。原因は、デモのラムダが model を握る参照循環である。implement が `demo/stock_flow_demo.gd` を直し（6afa2fb）、2度目の通しで解消したことを確かめた。以下は2度目の結果である。

| # | 期待する結果 | 実際の出力（要点） | 判定 |
|---|---|---|---|
| 1 | すべてのテストが通ったと表示される | `48 test cases \| 0 errors \| 0 failures`、`Exit code: 0`、`scripts/test.sh の終了コード：0`。冒頭に debugger ポートの ERROR が2行出るが、gdUnit4 の仕様で README に注記がある | 一致 |
| 2 | 成功と失敗がそれぞれ Actions に出ている | run 42022965513 と 42023246682 が `結論：success`。run 42023098068 は `結論：failure`（「テストを実行する」の手順が exit code 100 で失敗） | 一致 |
| 3 | 各ターンのストックの値と、turn_finished のターン番号が表示される | `turn_finished(1): A=7.0 B=1.0 C=2.0`、`(2): A=4.0 B=2.0 C=4.0`、`(3): A=1.0 B=3.0 C=6.0` | 一致 |
| 4 | 3と同じ値が表示される | 定義順を B->C, A->B にしても、3ターンとも同じ値。終了時の WARNING と ERROR は出ない | 一致 |
| 5 | 正しい式は構文木、誤った式は原因と文字位置つきのエラーが表示される | `population * 0.02 + 1` → `(+ (* population 0.02) 1.0)`。`population * ` は位置13の終端エラー、`a.b` は位置1、`OS.get_name()` は位置2で `'.' は使えない`、`(1 + 2` は位置6で括弧が閉じていないエラー。いずれも `^` で位置を示す | 一致 |

## 出力の全文
場面1のテストの1件ずつの行（STARTED と PASSED が48件分、色の制御コードつき）は長いので省き、要点の行だけを残した。それ以外は出力をそのまま貼る。

```
コード：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/sprint-1

== 場面 1: README の手順でテストを実行する ==
ERROR: The remote port number must be between 1 and 65535 (inclusive).
   at: connect_to_host (core/io/stream_peer_tcp.cpp:69)
ERROR: Remote Debugger: Unable to connect to host '127.0.0.1:0'.
   at: create_tcp (core/debugger/remote_debugger_peer.cpp:247)
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org
GdUnit4 Comandline Tool
Scanning for test suites in: res://test
Run Test Suite: res://test/core/sim_model_test.gd
  （10件 PASSED。省略）
Statistics: 10 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED
Run Test Suite: res://test/expr/expr_parser_test.gd
  （36件 PASSED。省略）
Statistics: 36 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED
Run Test Suite: res://test/environment_test.gd
  （2件 PASSED。省略）
Statistics: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED
Overall Summary: 48 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (3/3)
Executed test cases : (48/48)
Exit code: 0
Run dispose test resources
scripts/test.sh の終了コード：0

== 場面 2: PR の Checks 欄と、意図的に失敗させたときの記録を開く ==
draft PR：https://github.com/kalKun24/meguri-engine/pull/13
--- 成功 run
URL：https://github.com/kalKun24/meguri-engine/actions/runs/42022965513

✓ scrum/1 test kalKun24/meguri-engine#13 · 42022965513
Triggered via pull_request about 16 minutes ago

JOBS
✓ test in 27s (ID 127230039931)
結論：success
--- 成功 run
URL：https://github.com/kalKun24/meguri-engine/actions/runs/42023246682

✓ scrum/1 test kalKun24/meguri-engine#13 · 42023246682
Triggered via pull_request about 14 minutes ago

JOBS
✓ test in 31s (ID 127231009495)
結論：success
--- 意図的に失敗させた run
URL：https://github.com/kalKun24/meguri-engine/actions/runs/42023098068

X scrum/1 test kalKun24/meguri-engine#13 · 42023098068
Triggered via pull_request about 15 minutes ago

JOBS
X test in 27s (ID 127230489432)
  ✓ Set up job
  ✓ Run actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
  ✓ Godot と gdUnit4 を導入する
  X テストを実行する
  ✓ Post Run actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
  ✓ Complete job

ANNOTATIONS
X Process completed with exit code 100.
結論：failure

== 場面 3: A→B→C のモデルを3ターン進める ==
== 場面 4: フローの定義順を入れ替えたモデルで同じことをする ==
(1回の実行で、定義順 A->B,B->C と B->C,A->B の2つを順に表示する)
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

定義順：A->B, B->C
  turn_finished(1): A=7.0 B=1.0 C=2.0
  turn_finished(2): A=4.0 B=2.0 C=4.0
  turn_finished(3): A=1.0 B=3.0 C=6.0
定義順：B->C, A->B
  turn_finished(1): A=7.0 B=1.0 C=2.0
  turn_finished(2): A=4.0 B=2.0 C=4.0
  turn_finished(3): A=1.0 B=3.0 C=6.0

== 場面 5: 正しい式と誤った式を式のパーサに渡す ==
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

式："population * 0.02 + 1"
  構文木：(+ (* population 0.02) 1.0)

式："2 + 3 * 4"
  構文木：(+ 2.0 (* 3.0 4.0))

式："-a * b"
  構文木：(* (neg a) b)

式："a - b - c"
  構文木：(- (- a b) c)

式："max(a, b + 1) >= 10"
  構文木：(>= (call max a (+ b 1.0)) 10.0)

式："population * "
構文エラー（位置 13）：式がここで終わっている。値（数・名前・括弧・関数呼び出し）が必要である
  population * 
               ^

式："a.b"
構文エラー（位置 1）：'.' は使えない。プロパティ参照とメソッド呼び出しは書けない。小数は '0.5' のように数字から書く
  a.b
   ^

式："OS.get_name()"
構文エラー（位置 2）：'.' は使えない。プロパティ参照とメソッド呼び出しは書けない。小数は '0.5' のように数字から書く
  OS.get_name()
    ^

式："(1 + 2"
構文エラー（位置 6）：括弧が閉じていない。位置 0 の '(' に対応する ')' が必要である
  (1 + 2
        ^

式：""
構文エラー（位置 0）：式が空である
  
  ^

式："name = "x""
構文エラー（位置 5）：'=' は使えない。代入は無い。等しいかを調べるときは '==' と書く
  name = "x"
       ^


(リハーサル：終了)
```
