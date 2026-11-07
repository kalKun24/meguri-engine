# スプリント6の implement への共通の依頼

- 枠：implement。`scrum-team:scrum-protocol` に従う。日本語・常体で書く。
- リポジトリ：/home/kal24hi/Projects/meguri-engine。base_branch は main。
- 読むもの（絶対パス）：
  - /home/kal24hi/Projects/meguri-engine/.scrum/config.md（DoD）
  - /home/kal24hi/Projects/meguri-engine/.scrum/agreements.md（T2-1、T4-1、T4-3、T5-1〜T5-3、T3-3 など）
  - /home/kal24hi/Projects/meguri-engine/.scrum/inception-deck.md
  - /home/kal24hi/Projects/meguri-engine/CLAUDE.md（構成の原則、GDScript の規約）

## 進め方
1. **最初に** `gh issue view <番号> --repo kalKun24/meguri-engine --json title,body,comments` で本文とコメントを読む。本文が取れなければ、作り始めずに `status: blocked` で報告する（T4-1）。
2. 指定された分岐元から、指定されたブランチ名で作業する。
3. 受け入れ基準を1つ満たすごとにコミットする。メッセージに満たした基準を書く。基準同士が同じ関数に絡んで分けられない場合は、先に骨組み（流れと失敗するテスト）をコミットしてから基準ごとに埋めるか、まとめた理由を報告に書く（T3-3）。
4. テストは `scripts/test.sh` で実行する。冒頭の debugger ポートの ERROR 2行は既知である。それ以外の ERROR・WARNING・leaked・still in use は0件にする。変更の外の原因だと考えるときは、分岐元で同じコマンドを実行して比べる（DoD）。
5. 実プロセスを起動するテストは、作業ディレクトリを一時ディレクトリにする。`scripts/test.sh` の前後で `git status --short` を比べ、未追跡のファイルが増えていないことを確かめる。

## 報告に必ず入れるもの
- 経路の表（T5-1。入口→出口の行×列1〜7。該当なしには理由を書く。空欄を残さない）。
- 受け入れ基準に「全」「すべて」「各」があれば、列挙表（列挙のコマンドと件数、`| 対象 | テスト名 |`）（T4-1）。
- 処理量のある変更は、列7に3つの軸（個数・1個あたりの大きさ・参照の広がり）の上限と、その積から導いた最悪の形の実測時間を書く。積がモデル全体の上限で止まっていなければ「上限なし」と書き、should として自分で報告する。測定はテストか demo のスクリプトで再現できる形にする（T5-1）。
- テストの件数と、test.sh の出力の ERROR・WARNING の件数。
- assumptions と unresolved。

## 落とし穴（過去のスプリントで起きたこと）
- RefCounted のモデルを捕まえたラムダをシグナルにつなぐと、循環参照でリークする。メンバ関数をつなぎ、テストの終わりで disconnect する。
- ラムダは外側のローカル変数を値で捕まえる。
- エスケープした文字列を長さで切るときは、`\\` と `\u{…}` を1単位として扱い、表記の途中で切らない。
- 受け入れ基準のテストは、ガード（範囲・上限・拒否の分岐）を外すと落ちることを、一時的に外して確かめる。結果はコミットに残さず、報告に1行ずつ書く。
