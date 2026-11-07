# Sprint 5
- phase: review
- goal: スプリントの終わりに、PO は、補助変数を使ったモデルが定義の順に関わらず同じ値になることと、上限・下限でストックが止まることを確かめられる。式や名前の書き間違いと実行時エラーでは、直し方と原因の名前が示される。
- started: 2026-11-07T13:26:32+09:00
- base_branch: main

## 対象 PBI
| PBI | points | ui | 担当構成 | 状態 | 差し戻し | ブランチ | 作業ディレクトリ |
|---|---|---|---|---|---|---|---|
| #22 | 3 | no | game-developer → code-reviewer・security-auditor | approved | 0 | scrum/22 | /home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-ae258dc778111e4dc |
| #7 | 2 | no | game-developer → code-reviewer・security-auditor・data-scientist | approved | 0 | scrum/7 | /home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a83712e3a57400491 |
| #11 | 3 | no | game-developer → code-reviewer・security-auditor・data-scientist | approved | 0 | scrum/11 | /home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a57a1eeef4078e632 |
| #23 | 2 | no | game-developer → code-reviewer・security-auditor | approved | 0 | scrum/23 | /home/kal24hi/Projects/meguri-engine/.claude/worktrees/agent-a2dbafa065a661fbc |

## デモ台本
| # | PO の操作 | 期待する結果 | PBI |
|---|---|---|---|
| 0 | `scripts/test.sh` を実行する | すべてのテストが通る | — |
| 1 | `0 < x < 10`、`人口 * 0.02`、`1e3`、`2x` の式と、「人口」や空白だけの名前のストックを渡す | それぞれ位置つきで、直し方を示すエラーが出る。`(a < b) < c` は通る | #22 |
| 2 | 下限0・上限100の食料と、下限の無いお金を持つモデルを進める | 食料は 0 と 100 で止まり、お金は負まで減る。下限が上限より大きい設定はエラーになる | #7 |
| 3 | 補助変数の定義の順だけを変えた2つのモデルを回し、循環するモデルも渡す | 2つは同じ値になる。循環は `a -> b -> a` の経路を含むエラーになる。町のゴールデン値は変わらない | #11 |
| 4 | `stock / divisor` で divisor が 0 のモデルを回す | 実行時エラーに `0.0 / 0.0（stock = 0.0、divisor = 0.0）` のように名前と値が出る | #23 |

## 実行計画
- 依存と積み重ね：
  - #22 と #7 は `main` から分岐し、並べて進める。
  - #11 は `scrum/22` から分岐する。補助変数の名前にも、#22 の名前の規則がかかるためである。
  - #23 は `scrum/11` から分岐する。評価器（ExprNode・ExprProgram・ExprEvaluator）の同じ箇所を触るためである。
  - 積み重ねの順：main → scrum/22 → scrum/11 → scrum/23。前の PBI を却下すると、後ろの PBI もそのままではマージできない。
- 同時に走らせる数：3（T3-3）。
- extra-review（T4-3）：
  - #22：不要（エラー文と名前の検査だけで、計算・出力形式を変えない）。
  - #7：要（ストックの値の更新と clamp の計算を変える）。
  - #11：要（計算の順を変え、町のゴールデン値に関わる）。
  - #23：不要（実行時エラーの文だけを変える）。
- 依頼に入れること：
  - 最初に `gh issue view <番号> --repo kalKun24/meguri-engine --json title,body,comments` で本文を読み、取れなければ blocked で報告する（T4-1）。
  - 「全」「すべて」「各」の基準は列挙表を付ける（T4-1）。
  - 経路の表は T4-2 の7列で作る。
  - レビューの依頼には、報告を保存したファイルのパスを示し、表を写さない（T4-3）。再レビューは must と差分だけにする。
  - 受け入れ基準ごとにコミットする（T3-3）。

## 持ち越した should の採否（T2-2）
| 指摘 | 元の PBI | 行き先 | 採否 |
|---|---|---|---|
| escape_reason（escape_backslash=false）がエスケープの表記の途中で切る | #29（security） | #22 | 採用（受け入れ基準に追記） |
| TownModel のフローの定義を公開し、ゴールデン値のテストが `_flows` を読まないようにする | #20（code） | #11 | 採用（受け入れ基準に追記） |
| 逆順で完全一致を求めるテストは加算の順に依存するので、フローが3本以上になれば見直す | #20（extra） | #11 | 採用（受け入れ基準に追記） |
| 終了後に get_rng() の乱数を進めない | #37 のリファインメント | #34 | 対象外（#34 を計画に入れるときに PO が決める） |

## Agent 実行ログ
| PBI | Agent | 目的 | tokens | tool_uses | 所要時間 |
|---|---|---|---|---|---|
| #7 | game-developer | implement | 92275 | 54 | 349s |
| #7 | security-auditor | review | 41643 | 13 | 71s |
| #7 | code-reviewer | review | 41457 | 14 | 93s |
| #7 | data-scientist | review | 26526 | 7 | 31s |
| #7 | game-developer | rework（テストだけ） | 96875 | 8 | 96s |
| #7 | data-scientist | review（再判定、差分だけ） | 29874 | 2 | 14s |
| #22 | game-developer | implement | 119072 | 62 | 809s |
| #22 | code-reviewer | review | 51001 | 16 | 107s |
| #22 | security-auditor | review | 53236 | 24 | 397s |
| #11 | game-developer | implement | 125238 | 39 | 452s |
| #11 | data-scientist | review | 36959 | 7 | 46s |
| #11 | security-auditor | review | 38474 | 12 | 89s |
| #11 | code-reviewer | review | 58806 | 21 | 161s |
| #23 | game-developer | implement | 118153 | 69 | 568s |
| #23 | security-auditor | review | 38069 | 21 | 83s |
| #23 | code-reviewer | review | 29103 | 12 | 94s |
| 統合 | game-developer | demo（競合の解消を含む） | 59133 | 22 | 220s |

## 記録
- 計画の前のリファインメント（2026-11-07）：#36・#37 を 5pt で ready にした。#12 は PO の保留（#8 の後）のため new のまま残した。見積りの起動は1回（59,204 tokens、18 tool_uses、81秒）で、この表には含めない。
- DoD 変更案・チーム編成の変更案は無かった。
- 飛ばした PBI：#34（5pt）と #37（5pt）は、取ると容量 10pt を超える。#37 は #34 より先に行う。

### #7 implement の報告
- 原文：/home/kal24hi/Projects/meguri-engine/.scrum/sprints/sprint-5-reports/7-implement.md
- status: done。コミット2つ（516c845 clamp の lo>hi、c69fa32 基準1〜6）。テスト 346 件、ERROR は既知の2行だけ。
- 基準1〜6は add_stock と _apply_flows の同じ流れに絡むため、1コミットにまとめた（T3-3、理由は報告にある）。
- assumptions：範囲は add_stock の引数（StockRange）で渡し、後から変える関数を持たない。step() も範囲を守る。上限のあるストックでは、合計が +INF でも収めた後が有限なら成功する。
- unresolved：apply_action() は範囲に収めない。フローの無いストックは範囲外のまま残りうる。Overflow は CLAMP だけである。
- 作業ディレクトリに、テストのための addons/gdUnit4 へのシンボリックリンクが未追跡で残っている。
- レビュー：code と security を起動した。extra（data-scientist）は、同時に3つまで（T3-3）のため、枠が空いてから起動する。

### #7 レビュー
- security：approve。must 0、should 2（新規）。
  - 経路の表の全行に値を流した（非有限の下限・上限の 8×8、境界の初期値、1e308＋1e308、敵対的な名前、clamp(1,5,0)）。結果は表と一致した。
  - should：apply_action が範囲に収めない（food=1050 を実測）。フローの無いストックは範囲外のまま残る → 新規改善 PBI
  - should：StockRange.apply は NaN を素通しし、check_finite に頼る。Overflow を足すと順序が崩れやすい → #8 の受け入れ基準
- code：approve。must 0、should 2（新規）。テスト 346 件を再実行し、前後の git status に差は無かった。原文の表を読み、空欄が無いことを確かめた。
  - should：apply_action が範囲に収めない → 新規改善 PBI（security と重なる。T1-2 により、改善 PBI を作る）
  - should：基準1〜6を1コミットにまとめた（基準1・5は先に分けられた）→ 対応不要。T3-3 の判定に記録する
- extra：approve。must 0、should 2（新規）。計算の順序、削った量が消えること、範囲の無いモデル（町のゴールデン値）の経路が変わらないことを確かめた。
  - should：test_values_stay_within_range_over_many_turns は境界に届かず、clamp を外しても通る → #7 の受け入れ基準
  - should：境界に張り付いた値は厳密に比べ、許容誤差は範囲の途中の値だけに使う → #7 の受け入れ基準
- 判定：3枠すべて approve で approved にした。行き先が #7 自身の should 2件（テストだけ）は、元の developer に手直しを頼んだ。差し戻しには数えない。確かめは差分だけにする（T4-3）。
- テストの手直し：f9e678c（c69fa32..HEAD はこの1コミットだけ）。基準6のテストを、下限に張り付く run と上限に張り付く run に分けた。境界のターンは厳密に比べる。テスト 347 件、ERROR は既知の2行だけ。
  - 振り返りの材料：SendMessage で再開した developer は、8 tool_uses の小さな作業でも 96,875 tokens を使った。再開の費用は、元の文脈の大きさで決まる。
- extra の再判定（差分だけ）：approve。should 2件は解消した。新しい指摘は無い。29,874 tokens で、初回（26,526）とほぼ同じだった。再開した Agent は元の文脈を読み直すので、範囲を絞っても tokens は下がらなかった（T4-3 の判定の材料）。
- should の行き先（T1-2）：
  - apply_action が範囲に収めない（code・security が重ねて出した）→ 新規改善 PBI #39 を作った（new、priority:5）。
  - StockRange.apply が NaN を素通しする（security）→ #8 にコメントした。
  - 基準1〜6を1コミット（code）→ 対応不要。
  - 基準6のテスト2件（extra）→ #7 の中で直した。

### #22 implement の報告
- 原文：/home/kal24hi/Projects/meguri-engine/.scrum/sprints/sprint-5-reports/22-implement.md
- status: done。コミット3つ（70b3fe0 基準1・5、011044d 基準6、50adf90 基準2・3・4）。テスト 351 件、ERROR は既知の2行だけ。
- 列挙表は2つ（比較演算子6種類、定義の名前4関数）。定義の関数の一覧は、ソースを正規表現で読むテストで漏れを防ぐ。
- #11 から呼ぶ共通部品：ModelCheck.check_identifier、is_name_start、is_name_char、NAME_RULE_HINT。
- assumptions：アクション名と終了条件の名前は規則の対象外とした。表示名の API は足していない（方針だけを docstring に書いた）。test/fixtures/hostile_names_model.gd を、内部の _stocks に直接入れる形に変えた。
- unresolved：アクション名・終了条件の名前を規則の対象にするかは、PO の判断が要る。
- レビュー：code と security を起動した（extra は不要、実行計画のとおり）。#11 は、#22 の判定が出てから scrum/22 の上で起動する。

### #22 レビュー
- code：approve。must 0、should 1（新規）。テスト 351 件を再実行し、前後の git status に差は無かった。列挙のコマンドを自分でも実行し、2つの列挙表と一致した（T4-1）。原文の表に空欄は無かった。
  - 判断：フィクスチャの変更は基準5に反しない（テストの本体と期待は変わっていない）。アクション名・終了条件の名前を対象外にしたのは、基準4の範囲どおりで妥当である。
  - should：_escaped_unit_length の16進の判定に is_valid_hex_number() を使っていて、符号付き（`\u{-1}`）も受け入れる。今の入口からは届かない → 新規改善 PBI
- security：approve。must 0、should 0。escape_reason に11種類の不正な表記を、切れ目が200字の境界をまたぐすべての位置で流し、表記の途中で切れる例は0件だった。名前の規則は、U+0080・U+00A0・U+3000・サロゲート周辺など21文字と ASCII の境界で確かめた。列7は、5001字の式や10万字の名前を流して、1〜3 ms で打ち切られた。
- 判定：2枠とも approve で approved にした。差し戻し0回。
- should の行き先（T1-2）：16進の判定（code）→ 新規改善 PBI #40 を作った（new、priority:6）。
- #11 の implement を、scrum/22 の上で起動した。

### #11 implement の報告
- 原文：/home/kal24hi/Projects/meguri-engine/.scrum/sprints/sprint-5-reports/11-implement.md
- status: done。コミット3つ（5448264 基準1〜6、7f3d15b 町・フローの公開・死亡のテスト・逆順の見直し、1b7d6d0 デモ）。テスト 384 件、ERROR は既知の2行だけ。#20 のゴールデン値は期待値を変えずに通る。
- 列7：補助変数1000個の鎖で、validate 約20 ms、step 約10 ms。
- assumptions：アクションと終了条件の式からは、補助変数を参照できない（ターン開始時の値が古くなるため）。補助変数の値の getter は足していない。循環の経路は8個の名前まで示す。
- unresolved：#7 と `_apply_flows` が統合で衝突しうる（挿入4行と evaluate の引数1つ）。アクション・終了条件からの参照と、補助変数の値を出すかは、PO の判断が要る。
- レビュー：code・security・extra の3つを起動した。#23 は、#11 の判定が出てから scrum/11 の上で起動する。

### #11 レビュー
- extra：approve。must 0、should 2（新規）。差分の読解だけで確かめた。補助変数をターンの開始時に1回だけ求めること、定義順に依らないこと、ゴールデン値の期待値が変わらず `_flows` を読まなくなったこと、逆順の完全一致を残した判断、死亡のテストの強さを確かめた。
  - should：町の補助変数は deficit 1個なので、町の並べ替えは複数の補助変数の順序を保証しない → 対応不要（998個の鎖のテストが担う）
  - should：フローが2本以下という前提のテストが、定数 TownModel.FLOWS を数え、build() の結果を見ていない → #28 の受け入れ基準（町を触るときに併せて直す）
- security：approve。must 0、should 2（新規）。列7を実際に流した。990個の鎖は validate 約20〜30 ms、step 約10 ms で報告と一致した。長さ990の循環は8個で打ち切られ、last_error は64字だった。
  - should：モデル全体の命令数に上限が無い。ファンアウト（約9万命令）で step 約0.5〜0.75秒、上限まで使う最悪の場合は約2.5秒/ターンの見積り。他の制作者のモデルで100ターンを数分にできる → 新規改善 PBI
  - should：定数が変わるたびに全補助変数を組み立て直す（1000個で約34 ms/ターン、ファンアウトのモデルで validate 約0.8秒）→ 新規改善 PBI
  - 振り返りの材料：T4-2 の列7に当たる新規の指摘が2件（should）出た。報告の列7は鎖の規模だけを測り、命令数（式の長さ×個数）の最悪を測っていなかった。
- code：approve。must 0、should 3（新規）。テスト 384 件を再実行した。列挙のコマンドを自分でも実行し、7関数と5種類が表と一致した（T4-1）。
  - 判断：アクション・終了条件から補助変数を参照できなくしたのは、受け入れ基準を満たす（基準1は補助変数を書く式、基準3はフローの式を指す）。
  - 統合の見込み：`git merge-tree` で scrum/7 と比べた。衝突は sim_model.gd の2か所（メンバ宣言の隣り合う行、add_stock の署名と `_check_new_name` の `, true`）で、`_apply_flows` は自動で統合される。add_stock の衝突の主因は #22 と #7 の差である。
  - should：基準1・2は単独で通るのに、基準1〜6を1コミットにまとめた → 対応不要（T3-3 の「まとめてよい条件」を振り返りで扱う）
  - should：アクション・終了条件が補助変数を参照したときのエラーが「ストックと定数だけ」としか言わない → 新規改善 PBI
  - should：統合の衝突予測が実際と違う → 対応不要（統合時に手で解消する）
- 判定：3枠すべて approve で approved にした。差し戻し0回。
- should の行き先（T1-2）：
  - 命令数の上限と組み立て直し（security 2件）→ 新規改善 PBI #41（new、priority:4。#37 と同じ型）
  - 補助変数の参照のエラー文（code）と、参照を許すか・値を読む関数を持つか（implement の unresolved）→ 新規改善 PBI #42（new、priority:5）
  - 前提のテストが build() の結果を見ない（extra）→ #28 にコメントした
  - 町の並べ替え（extra）、1コミット（code）、衝突予測（code）→ 対応不要
- #23 の implement を、scrum/11 の上で起動した。

### #23 implement の報告
- 原文：/home/kal24hi/Projects/meguri-engine/.scrum/sprints/sprint-5-reports/23-implement.md
- status: done。コミット1つ（0922564、基準1〜3は同じ evaluate に絡むためまとめた）。テスト 407 件、ERROR は既知の2行だけ。
- 列挙表：除算・剰余・べき乗と、許可関数9件。列7：999字・219個の名前の式で、失敗 0.79 ms。説明文を失敗したときだけ作るように変え、分岐元より速くなった。
- assumptions：「べき乗」は関数 pow と解釈した。名前を持つのは直接参照した値だけである。表記は全角の括弧と読点にした。
- unresolved：1e300 のような値は300桁で出るので、名前と値が escape_reason の200字で切れて見えなくなる。値の表示形式は基準の外である。
- 統合時の注意：#11 のデモの uid（demo/auxiliary_demo.gd.uid）が未コミットで、test.sh の実行で生成される。統合ブランチで扱う。
- レビュー：code と security を起動した（extra は不要、実行計画のとおり）。

### #23 レビュー
- security：approve。must 0、should 2（新規）。名前に不可視文字・バックスラッシュを並べた ExprProgram を直接流し、上限 200〜60 で表記が途中で切れないことと生の不可視文字が0件であることを確かめた。列7は 895字・約200個の名前の式で 0.74 ms だった。
  - should：大きな値（1e300）は300桁で出て、名前と値が200字で切れて1つも出ない（implement の unresolved と同じ。実測で確かめた）→ 新規改善 PBI（#23 の基準を満たすかは PO の判断）
  - should：名前を32文字で省くので、先頭32文字が同じ別の名前は同じ表示になる → 対応不要
- code：approve。must 0、should 2（新規）。テスト 407 件を再実行し、列挙のコマンド（許可関数9件）が表と一致した。既存テストのファイルは変更0件だった。
  - 判断：「べき乗」を pow と解釈したのは妥当である。1e300 の件は、基準の例と文言は通常の値で満たすので should とする。
  - should：大きな値で名前と値が切れる（security と重なる）→ 新規改善 PBI
  - should：加減算・乗算のオーバーフローには名前を添えない（基準の範囲外）→ 新規改善 PBI
- 判定：2枠とも approve で approved にした。差し戻し0回。
- should の行き先（T1-2）：大きな値の表示とオーバーフローの名前（code・security）→ 新規改善 PBI #43（new、priority:5）。32文字の省略の重なり（security）→ 対応不要。

### 実行フェーズの終了
- 4件すべてが approved になった（差し戻し0回）。blocked は0件。
- 持ち越した should（T2-2）：#22 の escape_reason の切り方は解消した。#11 の2件（フローの公開、逆順の完全一致の見直し）も解消した。
- このスプリントで作った改善 PBI：#39（アクションと範囲）、#40（16進の判定）、#41（命令数の上限）、#42（補助変数の参照）、#43（原因の値の表示）。コメントした PBI：#8、#28。
- phase を demo にした。

### デモの準備
- 統合ブランチ：scrum/sprint-5。作業ディレクトリ：/home/kal24hi/Projects/meguri-engine/.claude/worktrees/sprint-5。取り込みの順：scrum/22 → 11 → 23 → 7。
- #7 の取り込みで sim_model.gd と expr_evaluator.gd が競合し、implement 枠が解消した（bda49a8）。clamp の lo > hi のエラーは #23 の形に合わせ、名前と値を添えるようにした。統合後のテストは 437 件、ERROR は既知の2行だけ。
- デモ：/home/kal24hi/Projects/meguri-engine/.scrum/demos/sprint-5/（README.md、demo.sh、rehearsal.md）。回：1。
- リハーサル：1度目の通しで5場面すべてが一致した。
- phase を review にした。
