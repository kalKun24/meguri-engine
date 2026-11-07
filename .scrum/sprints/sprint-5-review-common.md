# スプリント5のレビューへの共通の依頼

- `scrum-team:scrum-protocol` に従う。枠は依頼に書く。ファイルは変更しない（テストの実行と、一時ディレクトリでの確認はよい）。日本語・常体で書く。
- 読むもの（絶対パス）：
  - /home/kal24hi/Projects/meguri-engine/.scrum/config.md（DoD）
  - /home/kal24hi/Projects/meguri-engine/.scrum/agreements.md（T2-1、T4-1〜T4-3、T1-2、T2-2）
  - /home/kal24hi/Projects/meguri-engine/.scrum/inception-deck.md
  - /home/kal24hi/Projects/meguri-engine/CLAUDE.md
  - PBI の本文：`gh issue view <番号> --repo kalKun24/meguri-engine --json title,body,comments`
  - implement の報告の原文：依頼に書いたファイル。経路の表と列挙表はそこにある。スクラムマスターは表を写さない（T4-3）。空欄を指摘する前に、原文の表を確かめる。
- 差分は `git -C <作業ディレクトリ> diff <分岐元>..HEAD` で見る。

## 判定の基準
- must：受け入れ基準の未充足、DoD 違反、経路の表の空欄・誤った「該当なし」、表にある経路で列1〜7に反する実装（T4-2）、列挙表とテストの不一致（T4-1。code-review は列挙のコマンドを自分でも実行する）。
- should には、行の末尾に「→ 行き先」（`#<番号> の受け入れ基準`、`新規改善 PBI`、`対応不要（理由）`）を1つ書く（T1-2）。
- 下の「既知の should」と同じ指摘は新規として数えず、「既知: #<元の PBI>」と1行で書く（T2-2）。
- security-review は、表の経路と列7の規模に、実際に値を流して確かめる。

## 既知の should（スプリント5の時点）
- 終了後の凍結が add_* / set_seed に無い。条件を判定のたびに組み立て直す（約3.2秒/ターン、990条件）→ #37
- 出力ファイルがアトミックでない → #36
- escape_reason がエスケープの表記の途中で切る → #22（このスプリントで対応する）
- 終了後に get_rng() の乱数を進めない → #34
- step() が判定もイベントも通らない古い入口として残る → #34
- 完了の印と系列の取得 → #26
- 町の min の書き換え、人口の下限、overrides の検査 → #28

## 返答
scrum-protocol のレビューの書式（approve / request-changes、must・should、checks）で返す。
