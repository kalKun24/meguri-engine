## SimModel のデモ。A->B->C の2本のフローを3ターン進め、定義順を入れ替えたモデルでも同じ値になることを見る。
## 実行：godot --headless --path . -s res://demo/stock_flow_demo.gd
extends SceneTree


func _init() -> void:
	_run("定義順：A->B, B->C", false)
	_run("定義順：B->C, A->B", true)
	quit()


func _run(title: String, reverse: bool) -> void:
	var model := SimModel.new()
	model.add_stock("A", 10.0)
	model.add_stock("B", 0.0)
	model.add_stock("C", 0.0)
	if reverse:
		model.add_flow("b_to_c", "B", "C", 2.0)
		model.add_flow("a_to_b", "A", "B", 3.0)
	else:
		model.add_flow("a_to_b", "A", "B", 3.0)
		model.add_flow("b_to_c", "B", "C", 2.0)
	# ラムダが model をキャプチャすると参照循環になり、終了時に解放されない。メソッドに bind して接続する。
	model.turn_finished.connect(_on_turn_finished.bind(model))
	print(title)
	for i in 3:
		model.step()


func _on_turn_finished(turn: int, model: SimModel) -> void:
	print("  turn_finished(%d): A=%s B=%s C=%s" % [turn, model.get_stock("A"), model.get_stock("B"), model.get_stock("C")])
