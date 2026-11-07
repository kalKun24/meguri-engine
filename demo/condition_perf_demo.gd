## 終了条件の多いモデルで、1ターンにかかる時間を測るデモ（#37、T5-1 の列7）。
## 条件を CONDITIONS 個、1個あたり LENGTH 文字で持つモデルを、TURNS ターン回す。条件はどれも成り立たない。
## 形 A：ストックと定数が変わらない（組み立ての使い回しが効く形）。
## 形 B：毎ターンの前にアクションが定数 k を変える（定数が変わると、依存する式を組み立て直す形。条件のすべてが k を参照する、参照の広がりの最悪）。
## 実行：godot --headless --path . -s res://demo/condition_perf_demo.gd -- [--conditions=990] [--length=761] [--turns=3]
extends SceneTree


func _init() -> void:
	var conditions := _arg("conditions", 990)
	var length := _arg("length", 761)
	var turns := _arg("turns", 3)
	print("条件 %d 個、1個あたり %d 文字、%d ターン" % [conditions, length, turns])
	_measure("形 A：定数が変わらない", conditions, length, turns, false)
	_measure("形 B：毎ターン定数 k が変わる（全条件が k を参照）", conditions, length, turns, true)
	quit()


func _arg(key: String, fallback: int) -> int:
	var prefix := "--%s=" % key
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return int(argument.trim_prefix(prefix))
	return fallback


# s と k を交互に足した式を、ちょうど length 文字（奇数）にする。末尾に比較をつけられるよう、本体は length - 4 文字までにする。
func _expression(length: int) -> String:
	var text := "s"
	var use_k := true
	while text.length() + 2 <= length - 4:
		text += "+k" if use_k else "+s"
		use_k = not use_k
	return text + " < 0"


func _measure(label: String, conditions: int, length: int, turns: int, change_constant: bool) -> void:
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	model.add_constant("k", 1.0)
	model.add_flow("tick", "", "s", 1.0)
	model.add_action("bump", "1", ["k = k + 1"])
	var expression := _expression(length)
	for i in conditions:
		var code := model.add_defeat_condition("c%d" % i, expression)
		if code != OK:
			print("  条件 %d の定義に失敗：%s" % [i, model.last_error])
			return
	print("== %s（式の長さ %d）==" % [label, expression.length()])
	var total := 0
	for turn in range(1, turns + 1):
		if change_constant:
			model.apply_action("bump")
		var started := Time.get_ticks_usec()
		var code := model.advance_turn()
		var elapsed := Time.get_ticks_usec() - started
		total += elapsed
		print("  ターン %d：%s、%.1f ms" % [turn, error_string(code), elapsed / 1000.0])
	print("  1ターンの平均：%.1f ms" % (total / 1000.0 / turns))
