## モデル全体の命令数の上限（#45）のデモ。上限を超える定義の拒否と、上限いっぱいのモデル・ファンアウトのモデルの1ターンの時間を表示する。
## 時間の測定は T5-1 の列7の根拠である。個数×1個あたりの大きさ×参照の広がりの最悪の形を、上限（ModelCheck.MAX_TOTAL_OPS）の範囲で作る。
## 実行：godot --headless --path . -s res://demo/ops_limit_demo.gd -- [--turns=3] [--ops=100000]
## --ops は、時間を測るモデルの命令数である（既定は上限）。上限より小さい値で、命令数と時間の関係も測れる。
extends SceneTree


func _init() -> void:
	var turns := _arg("turns", 3)
	var ops := _arg("ops", ModelCheck.MAX_TOTAL_OPS)
	_show_rejection()
	print("")
	print("--- 1ターンの時間（命令数 %d、%d ターン）---" % [ops, turns])
	_measure("形1 補助変数 100 個×約 1000 命令（式の長さの最大）", _build_auxiliaries(ops, 999), turns, false)
	_measure("形2 補助変数 1000 個×約 100 命令（定義の個数の最大）", _build_auxiliaries(ops, 99), turns, false)
	_measure("形3 ファンアウト：1つの補助変数 base を 999 個の補助変数が参照", _build_fanout(ops), turns, false)
	_measure("形4 条件 100 個×約 1000 命令、毎ターン定数 k が変わる（全条件が k を参照）", _build_conditions(ops, 997), turns, true)
	_measure("形5 条件 990 個×約 100 命令、毎ターン定数 k が変わる（個数の最大）", _build_conditions(ops, 100), turns, true)
	quit()


func _arg(key: String, fallback: int) -> int:
	var prefix := "--%s=" % key
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return int(argument.trim_prefix(prefix))
	return fallback


# ちょうど ops 個の命令になる、s と k を交互に足した式。ops は奇数にそろえる。
func _expression(ops: int, tail: String = "") -> String:
	var odd := ops if ops % 2 == 1 else ops - 1
	var text := "s"
	var use_k := true
	for i in (odd - 1) / 2:
		text += "+k" if use_k else "+s"
		use_k = not use_k
	return text + tail


func _base_model() -> SimModel:
	var model := SimModel.new()
	model.add_stock("s", 1.0)
	model.add_constant("k", 1.0)
	model.add_flow("tick", "", "s", 1.0)
	model.add_action("bump", "1", ["k = k + 1"])
	return model


func _build_auxiliaries(total: int, per: int) -> SimModel:
	var model := _base_model()
	var i := 0
	var expression := _expression(per)
	while model._total_ops + per <= total and i < 990:
		if model.add_auxiliary("a%d" % i, expression) != OK:
			break
		i += 1
	return model


func _build_fanout(total: int) -> SimModel:
	var model := _base_model()
	model.add_auxiliary("base", _expression(99))
	var i := 0
	while model._total_ops + 100 <= total and i < 990:
		# base を参照する約 99 命令の式。
		if model.add_auxiliary("f%d" % i, "base" + _expression(97).substr(1)) != OK:
			break
		i += 1
	return model


func _build_conditions(total: int, per: int) -> SimModel:
	var model := _base_model()
	var i := 0
	var expression := _expression(per - 2, " < 0")
	while model._total_ops + per <= total and i < 990:
		if model.add_defeat_condition("c%d" % i, expression) != OK:
			break
		i += 1
	return model


func _show_rejection() -> void:
	var model := _base_model()
	var big := _expression(999)
	var count := 0
	while model.add_auxiliary("big%d" % count, big) == OK:
		count += 1
	print("--- 上限を超える定義の拒否 ---")
	print("上限 %d、受け付けた補助変数 %d 個（合計 %d 命令）" % [ModelCheck.MAX_TOTAL_OPS, count, model._total_ops])
	print("次の定義の結果：%s" % error_string(model.add_auxiliary("over", big)))
	print("last_error：%s" % model.last_error)
	var before := model._total_ops
	print("条件を足す：%s、フローを足す：%s" % [
		error_string(model.add_defeat_condition("over_c", _expression(199, " < 0"))),
		error_string(model.add_flow_expr("over_f", "", "s", big)),
	])
	print("モデルは変わらない：合計 %d -> %d 命令" % [before, model._total_ops])


func _measure(label: String, model: SimModel, turns: int, change_constant: bool) -> void:
	print("== %s：合計 %d 命令 ==" % [label, model._total_ops])
	var total := 0
	for turn in range(1, turns + 1):
		if change_constant:
			model.apply_action("bump")
		var started := Time.get_ticks_usec()
		var code := model.advance_turn()
		var elapsed := Time.get_ticks_usec() - started
		total += elapsed
		print("  ターン %d：%s、%.1f ms" % [turn, error_string(code), elapsed / 1000.0])
		if code != OK:
			print("  失敗：%s" % model.last_error)
			return
	print("  1ターンの平均：%.1f ms" % (total / 1000.0 / turns))
