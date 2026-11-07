## 補助変数のデモ。定義の順を入れ替えても結果が同じこと、循環参照と、フローの量の参照が経路つきで拒否されること、
## 非有限になる補助変数が名前つきの実行時エラーになること、長さ1000の鎖の実測時間を見る。
## 実行：godot --headless --path . -s res://demo/auxiliary_demo.gd
extends SceneTree

const CHAIN_LENGTH: int = 1000


func _init() -> void:
	_show_order_independence()
	_show_cycle()
	_show_flow_reference()
	_show_runtime_error()
	_show_chain_timing()
	quit()


func _per_capita(reverse: bool) -> SimModel:
	var model := SimModel.new()
	model.add_stock("population", 50.0)
	model.add_stock("food", 200.0)
	model.add_stock("mood", 0.0)
	model.add_constant("k", 0.5)
	var definitions: Array[Array] = [
		["per_capita", "food / population"],
		["comfort", "per_capita * k + bonus"],
		["bonus", "min(per_capita, 3)"],
	]
	if reverse:
		definitions.reverse()
	for definition: Array in definitions:
		model.add_auxiliary(definition[0], definition[1])
	model.add_flow_expr("lift", "", "mood", "comfort")
	return model


func _show_order_independence() -> void:
	print("1. 補助変数の定義順だけを変えた 2 通り（per_capita, comfort, bonus と、その逆）")
	var forward := _per_capita(false)
	var reversed := _per_capita(true)
	for turn in 3:
		forward.step()
		reversed.step()
		print("  ターン %d：mood = %s と %s（%s）" % [
			turn + 1, forward.get_stock("mood").value, reversed.get_stock("mood").value,
			"同じ" if forward.get_stock("mood").value == reversed.get_stock("mood").value else "違う"
		])


func _show_cycle() -> void:
	print("2. 循環参照（a が b を、b が a を参照する）")
	var model := SimModel.new()
	model.add_auxiliary("a", "b + 1")
	model.add_auxiliary("b", "a + 1")
	print("  validate() = %s" % error_string(model.validate()))
	print("  %s" % model.last_error)
	var self_ref := SimModel.new()
	self_ref.add_auxiliary("s", "s * 2")
	self_ref.validate()
	print("  自己参照：%s" % self_ref.last_error)
	var long_cycle := SimModel.new()
	for i in 300:
		long_cycle.add_auxiliary("n%d" % i, "n%d" % ((i + 1) % 300))
	long_cycle.validate()
	print("  長さ300の循環：%s" % long_cycle.last_error)


func _show_flow_reference() -> void:
	print("3. 補助変数がフローの量を参照する")
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	model.add_flow_expr("growth", "", "s", "1")
	model.add_auxiliary("x", "growth * 2")
	print("  validate() = %s" % error_string(model.validate()))
	print("  %s" % model.last_error)


func _show_runtime_error() -> void:
	print("4. 補助変数が 0 で割る（ストック divisor が 1 ターン目に 0 になる）")
	var model := SimModel.new()
	model.add_stock("s", 10.0)
	model.add_stock("divisor", 1.0)
	model.add_stock("out", 0.0)
	model.add_auxiliary("ratio", "s / divisor")
	model.add_flow_expr("shrink", "divisor", "", "1")
	model.add_flow_expr("f", "", "out", "ratio")
	print("  ターン 1：%s、out = %s" % [error_string(model.step()), model.get_stock("out").value])
	print("  ターン 2：%s、turn = %d" % [error_string(model.step()), model.get_turn()])
	print("  %s" % model.last_error)


func _show_chain_timing() -> void:
	print("5. 長さ%dの鎖（a0 = 1、a1 = a0 + 1、...）の実測。validate と step 1 回ずつ" % CHAIN_LENGTH)
	for reverse: bool in [false, true]:
		var model := SimModel.new()
		for k in CHAIN_LENGTH:
			var i := CHAIN_LENGTH - 1 - k if reverse else k
			model.add_auxiliary("a%d" % i, "1" if i == 0 else "a%d + 1" % (i - 1))
		var start := Time.get_ticks_usec()
		var validated := model.validate()
		var validate_ms := (Time.get_ticks_usec() - start) / 1000.0
		start = Time.get_ticks_usec()
		var stepped := model.step()
		var step_ms := (Time.get_ticks_usec() - start) / 1000.0
		print("  %s：validate = %s（%.1f ms）、step = %s（%.1f ms）" % [
			"逆順" if reverse else "正順", error_string(validated), validate_ms, error_string(stepped), step_ms
		])
