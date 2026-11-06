## エラー文に出す式の長さの上限のデモ。巨大な式を渡しても、last_error が上限以内の抜粋になり、位置が数字で出る。
## 実行：godot --headless --path . -s res://demo/excerpt_demo.gd
## 不可視文字は、文字コードから char() で作る（ソースに生の文字を書かない）。
extends SceneTree


func _init() -> void:
	print("上限：式の抜粋 %d 文字、原因 %d 文字、last_error 1件 %d 文字（どれもエスケープ後の長さ）" % [
		ModelCheck.MAX_EXPRESSION_EXCERPT_LENGTH, ModelCheck.MAX_MESSAGE_REASON_LENGTH, ModelCheck.MAX_LAST_ERROR_LENGTH
	])

	print("")
	print("== 1. add_flow_expr に巨大な式を渡す ==")
	_add_flow_expr("10万文字の式", "x".repeat(100000))
	_add_flow_expr("U+200B の10万字", char(0x200B).repeat(100000))
	_add_flow_expr("タグ文字 U+E0041 の10万字（エスケープで10倍）", char(0xE0041).repeat(100000))

	print("")
	print("== 2. 上限内で通る長い式が、後で失敗する（位置が抜粋の外にある） ==")
	var long_zero: String = "0" + " + 0".repeat(200)
	var model := SimModel.new()
	model.add_stock("food", 10.0)
	model.add_flow_expr("f", "", "food", long_zero + " + 1 / 0")
	_show("step（0 除算）", model.step(), model)
	var action_model := SimModel.new()
	action_model.add_stock("food", 10.0)
	action_model.add_action("buy", long_zero, ["food = 1"])
	_show("apply_action（条件を満たさない）", action_model.apply_action("buy"), action_model)
	_show("add_action（効果が「対象名 = 式」の形でない）", action_model.add_action("bad", "1", [long_zero]), action_model)

	print("")
	print("== 3. ExprParser の構文エラー（位置が抜粋の外なら、^ の行は出ない） ==")
	var parser := ExprParser.new()
	var near: ExprParseResult = parser.parse("1 + " + char(0x200B) + "$")
	print(near.error.format())
	print("")
	var far: ExprParseResult = parser.parse("1 + ".repeat(100) + "$")
	print(far.error.format())
	quit()


func _add_flow_expr(label: String, expression: String) -> void:
	var model := SimModel.new()
	model.add_stock("food", 10.0)
	_show("%s（式の長さ %d）" % [label, expression.length()], model.add_flow_expr("f", "", "food", expression), model)


func _show(label: String, code: Error, model: SimModel) -> void:
	print("%s -> %s\n  last_error（%d 文字）：%s" % [label, error_string(code), model.last_error.length(), model.last_error])
