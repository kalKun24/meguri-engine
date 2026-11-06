## 敵対的な値の共有一覧（HostileValues）を、外部由来の値を受け取る公開関数に全件流すテスト（T2-1）。
## 対象：SimModel の add_stock・add_constant・add_flow・add_flow_expr・get_stock・get_constant・has_stock、ExprParser.parse。
## 各呼び出しについて、次を確かめる。
##   - 落ちない
##   - 失敗なら last_error が空でなく、生の不可視文字を含まない。モデルは変わらない
##   - 成功なら last_error が空である
##   - 落ちずに返る（時間のかかる入力でも返る）
class_name HostileInputTest
extends GdUnitTestSuite


func _new_model() -> SimModel:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	return model


# モデルの外から見える状態。失敗のとき、変わっていてはならない。
func _snapshot(model: SimModel) -> String:
	return "%s|%d|%s" % [model.get_stock_names(), model.get_turn(), model.get_stock("a").value]


func _check_result(model: SimModel, code: Error, before: String, label: String) -> void:
	var raw := HostileValues.find_raw_invisible(model.last_error)
	assert_str(raw).override_failure_message("%s：last_error に %s" % [label, raw]).is_empty()
	if code == OK:
		assert_str(model.last_error).override_failure_message("%s：成功なのに last_error が残っている" % label).is_empty()
	else:
		assert_str(model.last_error).override_failure_message("%s：失敗なのに last_error が空" % label).is_not_empty()
		assert_str(_snapshot(model)).override_failure_message("%s：失敗なのにモデルが変わった" % label).is_equal(before)


func test_add_stock_with_hostile_names() -> void:
	for label: String in HostileValues.strings():
		var model := _new_model()
		var before := _snapshot(model)
		var code := model.add_stock(HostileValues.strings()[label], 1.0)
		_check_result(model, code, before, "add_stock 名前 " + label)


func test_add_constant_with_hostile_names() -> void:
	for label: String in HostileValues.strings():
		var model := _new_model()
		var before := _snapshot(model)
		var code := model.add_constant(HostileValues.strings()[label], 1.0)
		_check_result(model, code, before, "add_constant 名前 " + label)


func test_blank_and_invisible_only_names_are_rejected() -> void:
	var blanks: Array[String] = ["", " ", char(0x200B), char(0x200B).repeat(10), char(0x202E), char(0x3000), char(0x3164)]
	for name_value in blanks:
		var model := _new_model()
		assert_int(model.add_stock(name_value, 1.0)).is_equal(ERR_INVALID_PARAMETER)
		assert_int(model.add_constant(name_value, 1.0)).is_equal(ERR_INVALID_PARAMETER)
		assert_int(model.add_flow(name_value, "", "a", 1.0)).is_equal(ERR_INVALID_PARAMETER)
		assert_int(model.add_flow_expr(name_value, "", "a", "1")).is_equal(ERR_INVALID_PARAMETER)


func test_add_with_hostile_floats() -> void:
	for label: String in HostileValues.floats():
		var value: float = HostileValues.floats()[label]
		var model := _new_model()
		var before := _snapshot(model)
		_check_result(model, model.add_stock("s", value), before, "add_stock " + label)
		assert_int(model.add_stock("s", value)).is_equal(ERR_INVALID_PARAMETER)
		_check_result(model, model.add_constant("c", value), before, "add_constant " + label)
		assert_int(model.add_constant("c", value)).is_equal(ERR_INVALID_PARAMETER)
		_check_result(model, model.add_flow("f", "", "a", value), before, "add_flow " + label)
		assert_int(model.add_flow("f", "", "a", value)).is_equal(ERR_INVALID_PARAMETER)


func test_add_flow_with_hostile_strings() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := _new_model()
		var before := _snapshot(model)
		_check_result(model, model.add_flow(value, "", "a", 1.0), before, "add_flow 名前 " + label)
		model = _new_model()
		_check_result(model, model.add_flow("f", value, "a", 1.0), before, "add_flow 流出元 " + label)
		model = _new_model()
		_check_result(model, model.add_flow("f", "a", value, 1.0), before, "add_flow 流入先 " + label)


func test_add_flow_expr_with_hostile_strings() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := _new_model()
		var before := _snapshot(model)
		_check_result(model, model.add_flow_expr(value, "", "a", "1"), before, "add_flow_expr 名前 " + label)
		model = _new_model()
		_check_result(model, model.add_flow_expr("f", value, "a", "1"), before, "add_flow_expr 流出元 " + label)
		model = _new_model()
		_check_result(model, model.add_flow_expr("f", "a", value, "1"), before, "add_flow_expr 流入先 " + label)
		model = _new_model()
		_check_result(model, model.add_flow_expr("f", "", "a", value), before, "add_flow_expr 式 " + label)


# 式が受理された場合も、validate() と step() のエラー文に生の不可視文字が出ない。
func test_validate_and_step_with_hostile_strings() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := _new_model()
		var code := model.add_flow_expr("f", "", "a", value)
		var validated := model.validate()
		assert_str(HostileValues.find_raw_invisible(model.last_error)).override_failure_message("validate 式 " + label).is_empty()
		if code == OK and validated != OK:
			assert_str(model.last_error).is_not_empty()
		var stepped := model.step()
		assert_str(HostileValues.find_raw_invisible(model.last_error)).override_failure_message("step 式 " + label).is_empty()
		if stepped != OK:
			assert_str(model.last_error).is_not_empty()
			assert_int(model.get_turn()).is_equal(0)
			assert_float(model.get_stock("a").value).is_equal(1.0)

		# 名前に使った場合の validate() と step()
		var named := _new_model()
		if named.add_flow_expr(value, "", "a", "zz") == OK:
			assert_int(named.validate()).is_equal(ERR_INVALID_DATA)
			assert_str(HostileValues.find_raw_invisible(named.last_error)).override_failure_message("validate 名前 " + label).is_empty()
			assert_str(named.last_error).is_not_empty()


func test_get_with_hostile_names() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := _new_model()
		var stock := model.get_stock(value)
		assert_bool(stock.error != OK).override_failure_message("get_stock " + label).is_true()
		assert_float(stock.value).is_equal(0.0)
		assert_str(model.last_error).is_not_empty()
		assert_str(HostileValues.find_raw_invisible(model.last_error)).override_failure_message("get_stock " + label).is_empty()
		var constant := model.get_constant(value)
		assert_bool(constant.error != OK).is_true()
		assert_str(HostileValues.find_raw_invisible(model.last_error)).override_failure_message("get_constant " + label).is_empty()
		assert_bool(model.has_stock(value)).is_false()


func test_parse_with_hostile_strings() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var result: ExprParseResult = ExprParser.new().parse(value)
		if result.ok:
			assert_object(result.error).is_null()
			continue
		assert_object(result.root).is_null()
		assert_object(result.error).is_not_null()
		var formatted: String = result.error.format()
		# 行区切りの改行だけは、format() が意図して出す。行ごとに調べる。
		assert_int(formatted.split("\n").size()).override_failure_message("format() の行数 " + label).is_equal(3)
		for line in formatted.split("\n"):
			assert_str(HostileValues.find_raw_invisible(line)).override_failure_message("format() " + label).is_empty()
		assert_str(HostileValues.find_raw_invisible(result.error.message)).override_failure_message("message " + label).is_empty()


# 足すと無限大になる有限の2数でも、step() が止まり、状態を変えない。
func test_overflow_pairs_stop_the_turn() -> void:
	for pair: Array in HostileValues.overflow_pairs():
		var model := SimModel.new()
		assert_int(model.add_stock("a", pair[0])).is_equal(OK)
		assert_int(model.add_flow("f", "", "a", pair[1])).is_equal(OK)
		assert_int(model.step()).is_equal(FAILED)
		assert_str(model.last_error).is_not_empty()
		assert_int(model.get_turn()).is_equal(0)
		assert_float(model.get_stock("a").value).is_equal(pair[0])

		# 式で書いた場合
		var expr_model := SimModel.new()
		assert_int(expr_model.add_stock("a", pair[0])).is_equal(OK)
		assert_int(expr_model.add_constant("k", pair[1])).is_equal(OK)
		assert_int(expr_model.add_flow_expr("f", "", "a", "k")).is_equal(OK)
		assert_int(expr_model.step()).is_equal(FAILED)
		assert_int(expr_model.get_turn()).is_equal(0)
		assert_float(expr_model.get_stock("a").value).is_equal(pair[0])


# --- #29：エラー文に出す式の長さの上限（不変条件6）---

func _assert_bounded(text: String, label: String) -> void:
	assert_int(text.length()).override_failure_message("%s：エラー文が %d 文字（上限 %d）" % [label, text.length(), ModelCheck.MAX_ERROR_OUTPUT_LENGTH]).is_less_equal(ModelCheck.MAX_ERROR_OUTPUT_LENGTH)
	assert_str(HostileValues.find_raw_invisible(text.replace("\n", ""))).override_failure_message("%s：生の不可視文字" % label).is_empty()


# 基準：共有一覧の全件を式として渡しても、last_error が上限以内で、生の不可視文字が無い。
func test_error_text_length_is_bounded_for_every_hostile_string() -> void:
	for label: String in HostileValues.strings():
		var value: String = HostileValues.strings()[label]
		var model := _new_model()
		model.add_flow_expr("f", "", "a", value)
		_assert_bounded(model.last_error, "add_flow_expr " + label)
		model.validate()
		_assert_bounded(model.last_error, "validate " + label)
		model.step()
		_assert_bounded(model.last_error, "step " + label)
		var action_model := _new_model()
		action_model.add_action("act", value, ["a = 1"])
		_assert_bounded(action_model.last_error, "add_action 条件 " + label)
		action_model.add_action("act", "1", ["a = " + value])
		_assert_bounded(action_model.last_error, "add_action 効果の式 " + label)
		action_model.add_action("act", "1", [value])
		_assert_bounded(action_model.last_error, "add_action 効果全体 " + label)
		action_model.apply_action("act")
		_assert_bounded(action_model.last_error, "apply_action " + label)
		var result: ExprParseResult = ExprParser.new().parse(value)
		if not result.ok:
			_assert_bounded(result.error.format(), "format " + label)


# 基準：構文エラーの式が10万文字でも、不可視文字10万字でも、抜粋になり、位置の数字が出る。
func test_syntax_error_shows_excerpt_and_position() -> void:
	for source: String in [" ".repeat(10) + "x".repeat(100000), char(0x200B).repeat(100000)]:
		var model := _new_model()
		assert_int(model.add_flow_expr("f", "", "a", source)).is_equal(ERR_PARSE_ERROR)
		assert_str(model.last_error).contains("...")
		assert_str(model.last_error).contains("位置")
		assert_int(model.last_error.length()).is_less_equal(ModelCheck.MAX_ERROR_OUTPUT_LENGTH)
		_assert_bounded(model.last_error, "10万文字")


# 基準：実行時・条件・組み立て時に、上限を超える長い式（上限内で通る式）を出すときも、抜粋になる。
func test_long_valid_expression_is_excerpted_in_runtime_errors() -> void:
	var long_zero: String = "0" + " + 0".repeat(200)
	var model := _new_model()
	assert_int(model.add_flow_expr("f", "", "a", long_zero + " + 1 / 0")).is_equal(OK)
	assert_int(model.step()).is_equal(FAILED)
	assert_str(model.last_error).contains("...")
	_assert_bounded(model.last_error, "step 実行時エラー")
	var unknown := _new_model()
	assert_int(unknown.add_flow_expr("f", "", "a", long_zero + " + nothing")).is_equal(OK)
	assert_int(unknown.validate()).is_equal(ERR_INVALID_DATA)
	assert_str(unknown.last_error).contains("...")
	_assert_bounded(unknown.last_error, "validate")
	var action_model := _new_model()
	assert_int(action_model.add_action("act", long_zero, ["a = 1"])).is_equal(OK)
	assert_int(action_model.apply_action("act")).is_equal(ERR_UNAVAILABLE)
	assert_str(action_model.last_error).contains("...")
	_assert_bounded(action_model.last_error, "apply_action 条件")
	assert_int(action_model.add_action("act2", "1", ["a = " + long_zero + " + 1 / 0"])).is_equal(OK)
	assert_int(action_model.apply_action("act2")).is_equal(FAILED)
	_assert_bounded(action_model.last_error, "apply_action 効果")
	var bad_effect := _new_model()
	assert_int(bad_effect.add_action("act", "1", [long_zero])).is_equal(ERR_INVALID_PARAMETER)
	assert_str(bad_effect.last_error).contains("...")
	_assert_bounded(bad_effect.last_error, "add_action 効果の形")


# 基準：構文エラーの ^ は、抜粋の中の position の文字の下に来る（位置が遠くても抜粋に入る）。
func test_syntax_error_format_caret_in_excerpt() -> void:
	var source: String = "1 + ".repeat(100) + "$" + " + 1".repeat(100)
	var result: ExprParseResult = ExprParser.new().parse(source)
	assert_bool(result.ok).is_false()
	var lines := result.error.format().split("\n")
	assert_int(lines.size()).is_equal(3)
	assert_str(lines[1]).starts_with("  ...")
	assert_str(lines[1]).ends_with("...")
	assert_str(lines[1].substr(lines[2].length() - 1, 1)).is_equal("$")
	assert_int(lines[1].length()).is_less_equal(ModelCheck.MAX_MESSAGE_EXPRESSION_LENGTH + 8)
