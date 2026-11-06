## 自動実行のテスト用。ターン 2 で、名前に U+202E を含む敗北条件が成り立つモデル。不可視文字は char() で作る。
extends RefCounted

const NAME_PREFIX: String = "lose"


func build() -> SimModel:
	var model := SimModel.new()
	model.add_stock("a", 0.0)
	model.add_flow("tick", "", "a", 1.0)
	model.add_defeat_condition(NAME_PREFIX + char(0x202E) + "x", "a >= 2")
	return model
