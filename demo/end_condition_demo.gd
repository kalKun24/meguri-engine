## 勝利と敗北の条件のデモ。条件を式で書いたモデルを自動で回し、止まったターンと結果を見る。
## 1. 「人口が 120 以上で勝利」で、勝利のターンに止まる。
## 2. 「お金が 0 以下で敗北」で、敗北のターンに止まる。
## 3. 同じターンに両方が成り立つモデルで、優先の設定（既定は敗北）を変えると結果が変わる。
## 4. 終わった後に step・advance_turn・apply_action を呼ぶと「ゲームは終了している」になり、値が変わらない。
## 5. 自動実行の入口（AutoRunCli）が、N の前に終わると、終了コード 0・最終行は終了したターン・理由は標準エラーに出る。
## 実行：godot --headless --path . -s res://demo/end_condition_demo.gd
extends SceneTree


func _init() -> void:
	print("== 1. 勝利：人口が 120 以上（人口は毎ターン +5、30 ターン回す指定）==")
	var win := _town(5.0, 5.0)
	_run(win, 30)

	print("== 2. 敗北：お金が 0 以下（お金は毎ターン -30、30 ターン回す指定）==")
	var lose := _town(1.0, 30.0)
	_run(lose, 30)

	print("== 3. 同じターンに両方が成り立つ（ターン 2 で人口 120、お金 0）==")
	var both := _town(10.0, 50.0)
	print("  優先の既定：%s" % both.get_simultaneous_priority())
	_run(both, 30)
	var both_victory := _town(10.0, 50.0)
	both_victory.set_simultaneous_priority(GameResult.OUTCOME_VICTORY)
	print("  優先を victory にすると：")
	_run(both_victory, 30)

	print("== 4. 終わった後に呼ぶ（上の 1. のモデル。ターン %d で勝利済み）==" % win.get_turn())
	_show(win)
	print("  step()         = %s  last_error: %s" % [error_string(win.step()), win.last_error])
	print("  advance_turn() = %s  last_error: %s" % [error_string(win.advance_turn()), win.last_error])
	print("  apply_action() = %s  last_error: %s" % [error_string(win.apply_action("donate")), win.last_error])
	_show(win)

	print("== 5. 自動実行の入口（--turns=30 で、ターン 5 に勝利するモデル）==")
	var cli := AutoRunCli.new(_print_stdout, _print_stderr)
	var code := cli.execute(PackedStringArray(["--model=res://test/fixtures/ending_model.gd", "--turns=30", "--seed=1"]))
	print("  終了コード：%d" % code)
	quit()


func _print_stdout(text: String) -> void:
	for line in text.split("\r\n"):
		if not line.is_empty():
			print("  [標準出力] " + line)


func _print_stderr(text: String) -> void:
	print("  [標準エラー] " + text.trim_suffix("\n"))


# 人口 100（毎ターン growth 増える）、お金 100（毎ターン cost 減る）のモデル。条件は「人口 >= 120 で勝利」「お金 <= 0 で敗北」。
func _town(growth: float, cost: float) -> SimModel:
	var model := SimModel.new()
	model.add_stock("population", 100.0)
	model.add_stock("money", 100.0)
	model.add_flow("growth", "", "population", growth)
	model.add_flow("cost", "money", "", cost)
	model.add_victory_condition("人口が120以上", "population >= 120")
	model.add_defeat_condition("お金が0以下", "money <= 0")
	model.add_action("donate", "1", ["money = money + 1"])
	return model


# 自動実行で回し、止まったターンと結果を表示する。
func _run(model: SimModel, turns: int) -> void:
	var result := AutoRunner.new().run(model, turns)
	print("  要求 %d ターン → 実際に進んだのは %d ターン。最終行：%s" % [result.turns_requested, result.turns_completed, result.rows[result.rows.size() - 1]])
	var final := model.get_result()
	print("  結果：%s  条件：「%s」  ターン：%d" % [final.outcome_label(), final.condition_name, final.turn])


func _show(model: SimModel) -> void:
	print("  ターン %d：人口 = %s  お金 = %s" % [model.get_turn(), model.get_stock("population").value, model.get_stock("money").value])
