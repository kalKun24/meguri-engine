# Meguri

ストック&フローで動くシミュレーションゲームを作るための、Godot 4 用の基盤である。目的・範囲・技術方針は `.scrum/inception-deck.md` に書かれている。

## 構成の原則
- シミュレーションコアとゲーム層は、Godot の `Node` に依存しない `RefCounted` のクラスで書く。画面なし（`godot --headless`）でテストと実行ができる状態を保つ。
- 画面（UI シーン）は、コアとゲーム層の公開関数を呼び、シグナルで通知を受けるだけにする。画面にシミュレーションのロジックを書かない。
- モデルの定義形式は未決定である。読み込み部分は、形式を差し替えられるように、コアから分けて書く。
- 計算式の評価に `Expression` を使う場合は、`base_instance` を渡さず、使える関数と変数を許可リストで制限する。他の制作者が書いたモデルを読み込むためである。
- ランダムな処理は、シードを指定できる `RandomNumberGenerator` を使う。グローバルの `randi()` や `randf()` は使わない。

## GDScript の規約
Godot 4 の GDScript で書く。Godot 3 の書き方は使わない。

### 型
- 変数・引数・戻り値には、すべて型ヒントを付ける。
  ```gdscript
  var population: float = 100.0
  var stocks: Dictionary = {}
  var names: Array[String] = []

  func get_stock(stock_name: String) -> float:
      return stocks.get(stock_name, 0.0)
  ```
- 型が右辺から明らかな場合は `:=` を使ってよい。

### 命名
- クラスは PascalCase、関数と変数は snake_case、定数は CONSTANT_CASE にする。
- 外から使わないメンバは、名前の先頭に `_` を付ける。
- 公開するクラスには `class_name` を付ける。

### シグナル
- シグナルは引数に型を付けて宣言し、`emit()` で発火する。
- 接続は `signal_name.connect(callable)` の形で書く。
  ```gdscript
  signal turn_finished(turn: int)

  turn_finished.emit(current_turn)
  game.turn_finished.connect(_on_turn_finished)
  ```

### ドキュメント
- 公開するクラスと関数には、`##` のドキュメントコメントを書く。エディタ内のヘルプに表示されるためである。

### Godot 3 からの主な変更点
- `yield` は廃止された。`await` を使う。
- `connect("signal", self, "method")` は廃止された。`signal.connect(callable)` を使う。
- `instance()` は `instantiate()` になった。
- `export`・`onready`・`tool` は、`@export`・`@onready`・`@tool` の注釈になった。

## テスト
- テストは gdUnit4 で書き、`test/` に置く。
- コアとゲーム層のテストは、シーンを使わずに書く。画面のテストは gdUnit4 のシーンランナーを使う。

## 出典
GDScript の規約の一部は、[alexmeckes/godot-claude-skills](https://github.com/alexmeckes/godot-claude-skills) の `godot-code-gen`（MIT License）を元に、このプロジェクト向けに書き直したものである。
