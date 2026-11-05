## プレイヤーのアクションのデモ。お金を払って farmland を増やす。
## お金が足りるとき実行でき次のターンの生産が増えること、足りないとき理由つきのエラーで何も変わらないこと、
## action_applied のシグナルを受け取ることを見る。
## 実行：godot --headless --path . -s res://demo/action_demo.gd
extends SceneTree


func _init() -> void:
	var model := SimModel.new()
	model.add_stock("money", 120.0)
	model.add_stock("farmland", 1.0)
	model.add_constant("price", 50.0)
	model.add_flow_expr("harvest", "", "money", "farmland * 10")
	var code := model.add_action("buy_farmland", "money >= price", ["money = money - price", "farmland = farmland + 1"])
	print("定義：add_action = %s  アクション = %s" % [error_string(code), model.get_action_names()])
	model.action_applied.connect(func(action_name: String) -> void: print("  [シグナル] action_applied(%s)" % action_name))

	print("1. お金が足りるとき（price = 50）")
	_show(model)
	print("  apply_action = %s" % error_string(model.apply_action("buy_farmland")))
	_show(model)
	print("  次のターンの生産：farmland 2 * 10 = +20 のはず")
	model.step()
	_show(model)

	print("2. 1 ターンに何回でも実行でき、費用は毎回かかる")
	print("  apply_action = %s" % error_string(model.apply_action("buy_farmland")))
	_show(model)

	print("3. お金が足りないとき（理由つきのエラーで、何も変わらない）")
	var code_short := model.apply_action("buy_farmland")
	var message := model.last_error
	print("  apply_action = %s" % error_string(code_short))
	print("  last_error: %s" % message)
	_show(model)

	print("4. 未定義のアクション")
	var code_unknown := model.apply_action("build_castle")
	print("  apply_action = %s  last_error: %s" % [error_string(code_unknown), model.last_error])
	quit()


func _show(model: SimModel) -> void:
	print("  ターン %d：money = %s  farmland = %s" % [model.get_turn(), model.get_stock("money").value, model.get_stock("farmland").value])
