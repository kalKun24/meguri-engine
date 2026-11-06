## 自動実行の入口のテスト用。ターン 4 で 0 除算になるモデル（ターン 3 までは進む）。
extends RefCounted


func build() -> SimModel:
	var model := SimModel.new()
	model.add_stock("a", 3.0)
	model.add_stock("b", 0.0)
	model.add_flow("drain", "a", "", 1.0)
	model.add_flow_expr("bad", "", "b", "1 / a")
	return model
