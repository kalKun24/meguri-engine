## TextPlayer のアクション選択と、町のアクションのテスト。シーンを使わない。
## T2-1 の経路：テキスト入力（行の長さの上限・共有一覧）、アクションの選択（共有一覧）、表示（ラベル・名前の共有一覧）。
class_name TextPlayerActionTest
extends GdUnitTestSuite


func _play(inputs: Array[String], overrides: Dictionary = {}, model_out: Array = []) -> BufferTextPlayIO:
	var model := TownModel.new().build(overrides)
	assert_object(model).is_not_null()
	model_out.append(model)
	var io := BufferTextPlayIO.new(inputs)
	TextPlayer.new(model, io, TownModel.LABELS, TownModel.ACTION_LABELS, TownModel.PARAM_LABELS).run()
	return io


func _text(io: BufferTextPlayIO) -> String:
	return "\n".join(io.outputs)


func _value(model: SimModel, name_value: String) -> float:
	return (model.get_stock(name_value) if model.has_stock(name_value) else model.get_constant(name_value)).value


func _count_unknown(io: BufferTextPlayIO) -> int:
	return io.outputs.filter(func(l: String) -> bool: return l.begins_with("分からない入力")).size()


# --- 町のアクション ---

func test_town_defines_expand_farmland_and_tax_actions() -> void:
	var model := TownModel.new().build()
	assert_array(model.get_action_names()).is_equal(["expand_farmland", "raise_tax", "lower_tax"] as Array[String])


func test_expand_farmland_spends_money_and_adds_farmland() -> void:
	var model := TownModel.new().build()
	assert_int(model.apply_action("expand_farmland")).is_equal(OK)
	assert_float(_value(model, "money")).is_equal(50.0)
	assert_float(_value(model, "farmland")).is_equal(120.0)


func test_expand_farmland_gets_more_expensive_each_time() -> void:
	var model := TownModel.new().build({"money": 1000.0})
	var costs: Array[float] = []
	for i in 4:
		costs.append(_value(model, "farmland_cost"))
		assert_int(model.apply_action("expand_farmland")).is_equal(OK)
	assert_float(costs[0]).is_equal(50.0)
	assert_float(costs[1]).is_equal_approx(60.0, 1e-9)
	assert_float(costs[2]).is_equal_approx(72.0, 1e-9)
	assert_float(costs[3]).is_equal_approx(86.4, 1e-9)
	assert_float(_value(model, "money")).is_equal_approx(1000.0 - 50.0 - 60.0 - 72.0 - 86.4, 1e-9)


func test_expand_farmland_fails_without_money_and_changes_nothing() -> void:
	var model := TownModel.new().build({"money": 49.0})
	assert_int(model.apply_action("expand_farmland")).is_equal(ERR_UNAVAILABLE)
	assert_float(_value(model, "money")).is_equal(49.0)
	assert_float(_value(model, "farmland")).is_equal(100.0)
	assert_float(_value(model, "farmland_cost")).is_equal(50.0)
	assert_int(model.get_turn()).is_equal(0)


func test_tax_rate_stays_in_range_and_limit_is_reported_as_unavailable() -> void:
	var model := TownModel.new().build()
	var applied := 0
	model.action_applied.connect(func(_n: String) -> void: applied += 1)
	var last := OK
	for i in 20:
		last = model.apply_action("raise_tax")
		if last != OK:
			break
	assert_int(last).is_equal(ERR_UNAVAILABLE)
	assert_str(model.last_error).contains("tax_rate < tax_max")
	assert_float(_value(model, "tax_rate")).is_equal(1.0)
	var applied_at_limit := applied
	assert_int(model.apply_action("raise_tax")).is_equal(ERR_UNAVAILABLE)
	assert_int(applied).is_equal(applied_at_limit)
	for i in 20:
		last = model.apply_action("lower_tax")
		if last != OK:
			break
	assert_int(last).is_equal(ERR_UNAVAILABLE)
	assert_str(model.last_error).contains("tax_rate > tax_min")
	assert_float(_value(model, "tax_rate")).is_equal(0.0)


func test_tax_change_changes_money_growth_from_next_step() -> void:
	var base := TownModel.new().build()
	var raised := TownModel.new().build()
	raised.apply_action("raise_tax")
	base.step()
	raised.step()
	assert_float(_value(raised, "money")).is_greater(_value(base, "money"))


func test_actions_do_not_change_default_trajectory() -> void:
	# アクションを定義しただけでは推移が変わらない（ターン12の既定値。#20 のゴールデン値と同じ）。
	var model := TownModel.new().build()
	for i in 12:
		model.step()
	assert_float(_value(model, "population")).is_equal_approx(113.67389510213232, 1e-9)
	assert_float(_value(model, "food")).is_equal_approx(100.0, 1e-9)
	assert_float(_value(model, "money")).is_equal_approx(181.4140193878175, 1e-9)


# --- テキスト入力の選び方 ---

func test_select_by_number_runs_action_without_advancing_turn() -> void:
	var models: Array = []
	var io := _play(["1", "q"] as Array[String], {}, models)
	var model: SimModel = models[0]
	assert_int(model.get_turn()).is_equal(0)
	assert_float(_value(model, "farmland")).is_equal(120.0)
	assert_str(_text(io)).contains("「畑を広げる」を実行した")
	assert_str(_text(io)).contains("畑 100.00 → 120.00")
	assert_str(_text(io)).contains("ターンは進んでいない")


func test_select_by_action_name_and_label() -> void:
	var models: Array = []
	_play(["expand_farmland", "畑を広げる", "q"] as Array[String], {"money": 200.0}, models)
	assert_float(_value(models[0], "farmland")).is_equal(140.0)


func test_failed_action_shows_reason_and_does_not_advance() -> void:
	var models: Array = []
	var io := _play(["1", "1", "q"] as Array[String], {}, models)
	var model: SimModel = models[0]
	assert_int(model.get_turn()).is_equal(0)
	assert_float(_value(model, "farmland")).is_equal(120.0)
	assert_str(_text(io)).contains("「畑を広げる」を実行できない")
	assert_str(_text(io)).contains("条件を満たさない")
	assert_str(_text(io)).contains("money >= farmland_cost")


func test_play_continues_after_failed_action() -> void:
	var models: Array = []
	_play(["1", "1", "", "q"] as Array[String], {}, models)
	assert_int(models[0].get_turn()).is_equal(1)


func test_enter_only_advances_and_q_ends() -> void:
	var models: Array = []
	_play(["", "", "q", ""] as Array[String], {}, models)
	assert_int(models[0].get_turn()).is_equal(2)


func test_invalid_numbers_are_unknown_input() -> void:
	var models: Array = []
	var io := _play(["0", "4", "-1", "+1", "01x", "999999999999999999999", "１", "q"] as Array[String], {}, models)
	assert_int(models[0].get_turn()).is_equal(0)
	assert_float(_value(models[0], "farmland")).is_equal(100.0)
	assert_int(_count_unknown(io)).is_equal(7)


func test_menu_is_shown_at_start() -> void:
	var io := _play(["q"] as Array[String])
	assert_str(_text(io)).contains("1: 畑を広げる")
	assert_str(_text(io)).contains("2: 税率を上げる")
	assert_str(_text(io)).contains("3: 税率を下げる")


# --- T2-1：行の長さの上限 ---

func test_line_longer_than_limit_is_truncated() -> void:
	# 上限を超えた分は切り詰める。先頭が "1" でも、続きが残れば番号として読めず、分からない入力になる。
	# 切り詰めた後が上限以内で番号になる場合は、その番号として読む。
	var long_line := "1" + "0".repeat(TextPlayIO.MAX_LINE_LENGTH * 10)
	var models: Array = []
	var io := _play([long_line, "q"] as Array[String], {}, models)
	assert_float(_value(models[0], "farmland")).is_equal(100.0)
	assert_int(_count_unknown(io)).is_equal(1)
	for line in io.outputs:
		assert_int(line.length()).is_less(TextPlayIO.MAX_LINE_LENGTH + 100)


func test_text_after_the_limit_is_dropped() -> void:
	var line := " ".repeat(TextPlayIO.MAX_LINE_LENGTH) + "1"
	var models: Array = []
	_play([line, "q"] as Array[String], {}, models)
	# 切り詰めた結果が空白だけなので Enter として進み、"1" のアクションは実行されない。
	assert_int(models[0].get_turn()).is_equal(1)
	assert_float(_value(models[0], "farmland")).is_equal(100.0)


# --- T2-1：共有一覧 ---

func test_hostile_strings_as_input_never_crash_or_leak_raw_characters() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var models: Array = []
		var io := _play([value, "q"] as Array[String], {}, models)
		var model: SimModel = models[0]
		for line in io.outputs:
			assert_str(HostileValues.find_raw_invisible(line)).override_failure_message("入力 %s：出力に %s" % [label, HostileValues.find_raw_invisible(line)]).is_empty()
		assert_float(_value(model, "farmland")).override_failure_message("入力 %s で畑が変わった" % label).is_equal(100.0)
		if model.get_turn() == 0:
			assert_float(_value(model, "money")).override_failure_message("入力 %s でお金が変わった" % label).is_equal(100.0)
		assert_int(model.get_turn()).override_failure_message("入力 " + label).is_less_equal(1)


func test_hostile_strings_as_labels_are_escaped_in_menu_status_and_result() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := TownModel.new().build()
		var io := BufferTextPlayIO.new(["1", "1", "99", "q"] as Array[String])
		TextPlayer.new(model, io, {"population": value, "food": value, "money": value}, {"expand_farmland": value, "raise_tax": value}, {"farmland": value, "tax_rate": value}).run()
		for line in io.outputs:
			assert_str(HostileValues.find_raw_invisible(line)).override_failure_message("表示名 %s：出力に %s" % [label, HostileValues.find_raw_invisible(line)]).is_empty()


func test_hostile_strings_as_action_names_are_escaped() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := SimModel.new()
		model.add_stock("s", 1.0)
		if model.add_action(value, "s > 5", ["s = s + 1"]) != OK:
			continue
		var io := BufferTextPlayIO.new(["1", value, "q"] as Array[String])
		TextPlayer.new(model, io).run()
		for line in io.outputs:
			assert_str(HostileValues.find_raw_invisible(line)).override_failure_message("アクション名 %s：出力に %s" % [label, HostileValues.find_raw_invisible(line)]).is_empty()


func test_hostile_floats_are_refused_before_reaching_the_display() -> void:
	for label: String in HostileValues.floats():
		var model := SimModel.new()
		assert_int(model.add_stock("s", HostileValues.floats()[label])).is_equal(ERR_INVALID_PARAMETER)
