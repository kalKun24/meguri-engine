## 自動実行のテスト用。a が毎ターン 1 増え、ターン 5 で勝利条件「reach」が成り立つモデル。
extends RefCounted


func build() -> SimModel:
	var model := SimModel.new()
	model.add_stock("a", 0.0)
	model.add_flow("tick", "", "a", 1.0)
	model.add_victory_condition("reach", "a >= 5")
	model.add_defeat_condition("never", "a < -1")
	return model
