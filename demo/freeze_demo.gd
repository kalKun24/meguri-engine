## ゲーム終了後の凍結のデモ（#37）。勝利条件を持つ小さなモデルを終わるまで回し、その後にモデルを変える関数を順に呼ぶ。
## すべての行で ERR_LOCKED と「ゲームは終了している」が出て、状態の比較が「変わらない」になる。set_seed の後も get_seed() は変わらない。
## 実行：godot --headless --path . -s res://demo/freeze_demo.gd
extends SceneTree


func _init() -> void:
	var model := SimModel.new()
	model.add_stock("population", 100.0)
	model.add_constant("goal", 120.0)
	model.add_flow("growth", "", "population", 10.0)
	model.add_victory_condition("rich", "population >= goal")
	model.set_seed(7)
	while not model.is_ended():
		model.advance_turn()
	print("ターン %d で終了：%s（条件「%s」）、種 = %d" % [model.get_turn(), model.get_result().outcome, model.get_result().condition_name, model.get_seed()])
	var before := _state(model)
	var calls: Array[Array] = [
		["add_stock", ["new_stock", 1.0]],
		["add_constant", ["new_constant", 1.0]],
		["add_flow", ["new_flow", "", "population", 1.0]],
		["add_flow_expr", ["new_flow_expr", "", "population", "1 + 1"]],
		["add_auxiliary", ["new_auxiliary", "population + 1"]],
		["add_action", ["new_action", "1", ["population = population + 1"]]],
		["add_victory_condition", ["new_victory", "population > 0"]],
		["add_defeat_condition", ["new_defeat", "population < 0"]],
		["set_simultaneous_priority", ["victory"]],
		["set_seed", [99]],
		["validate", []],
	]
	for call in calls:
		var function_name: String = call[0]
		var code: Error = model.callv(function_name, call[1])
		var unchanged := _state(model) == before
		print("  %-26s = %-12s last_error: %s  状態：%s" % [function_name, error_string(code), model.last_error, "変わらない" if unchanged else "変わった（異常）"])
	print("set_seed(99) の後の get_seed() = %d" % model.get_seed())
	quit()


func _state(model: SimModel) -> String:
	return "%s|%s|%d|%s|%d|%d|%d|%d|%d|%d|%s" % [
		model._stocks, model._constants, model._flows.size(), model._actions.keys(), model._conditions.size(), model._auxiliaries.size(),
		model.get_seed(), model.get_turn(), model.get_rng().state, model._names.size(), model.get_simultaneous_priority(),
	]
