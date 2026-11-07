## #39 のデモ：アクションの効果でも、ストックの上限・下限が守られることを見る。
## 実行：godot --headless --path . -s res://demo/action_range_demo.gd
extends SceneTree


func _init() -> void:
	var model := SimModel.new()
	model.add_stock("food", 50.0, StockRange.between(0.0, 100.0))
	model.add_stock("gold", 50.0)
	model.add_action("feast", "1", ["food = food + 1000", "gold = gold + 1000"])
	model.add_action("famine", "1", ["food = food - 1000", "gold = gold - 1000"])
	print("food（下限 0、上限 100）= %s、gold（範囲なし）= %s" % [model.get_stock("food").value, model.get_stock("gold").value])
	for action_name in ["feast", "famine"]:
		var code := model.apply_action(action_name)
		print("%s: %s -> food = %s、gold = %s" % [action_name, error_string(code), model.get_stock("food").value, model.get_stock("gold").value])
	quit()
