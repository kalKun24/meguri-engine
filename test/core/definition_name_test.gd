## ストック・定数・フローの定義の名前の規則（#22）のテスト。シーンを使わない。
## 規則：半角英数字と _ だけ。先頭は数字にしない。空白だけ・不可視文字だけ・前後に空白がある名前は拒否する。
class_name DefinitionNameTest
extends GdUnitTestSuite

## 名前を受け取る定義の関数。add_flow と add_flow_expr は流出元か流入先が要るので、ストック "s" を先に定義する。
const DEFINERS: Array[String] = ["add_stock", "add_constant", "add_flow", "add_flow_expr"]
const VALID_NAMES: Array[String] = ["pop", "_a", "A1", "x_2", "Population_2024", "a"]


func _define(model: SimModel, definer: String, name_value: String) -> Error:
	match definer:
		"add_stock":
			return model.add_stock(name_value, 1.0)
		"add_constant":
			return model.add_constant(name_value, 1.0)
		"add_flow":
			return model.add_flow(name_value, "", "s", 1.0)
		"add_flow_expr":
			return model.add_flow_expr(name_value, "", "s", "1")
	fail("未知の定義関数：" + definer)
	return FAILED


func _model() -> SimModel:
	var model := SimModel.new()
	model.add_stock("s", 0.0)
	return model


func _bad_names() -> Dictionary:
	var all: Dictionary = {
		"日本語": "人口",
		"全角の英字": char(0xFF21) + char(0xFF22),
		"空白だけ": "   ",
		"不可視文字だけ": char(0x200B),
		"前に空白": " pop",
		"後ろに空白": "pop ",
		"途中に空白": "a b",
		"先頭が数字": "1abc",
		"数字だけ": "123",
		"ハイフン": "a-b",
		"ドット": "a.b",
		"記号": "=cmd",
		"改行": "a" + char(0x0A) + "b",
		"U+202E を含む": "a" + char(0x202E) + "b",
		"日本語の表示名のような名前": "人口（万人）",
	}
	return all


func test_valid_names_are_accepted_by_every_definer() -> void:
	for definer in DEFINERS:
		for name_value in VALID_NAMES:
			var model := _model()
			assert_int(_define(model, definer, name_value)).is_equal(OK)
			assert_str(model.last_error).is_empty()


func test_bad_names_are_rejected_by_every_definer_and_model_is_unchanged() -> void:
	for definer in DEFINERS:
		var bad: Dictionary = _bad_names()
		for label: String in bad:
			var model := _model()
			assert_int(_define(model, definer, bad[label])).is_equal(ERR_INVALID_PARAMETER)
			assert_str(model.last_error).is_not_empty()
			assert_array(model.get_stock_names()).is_equal(["s"])


func test_blank_and_invisible_only_names_are_rejected_as_empty() -> void:
	for definer in DEFINERS:
		for name_value in ["", " ", "   ", char(0x200B), char(0x3000), char(0x202E)]:
			var model := _model()
			assert_int(_define(model, definer, name_value)).is_equal(ERR_INVALID_PARAMETER)
			assert_str(model.last_error).contains("が空である")


func test_every_hostile_string_is_rejected_by_every_definer() -> void:
	var strings: Dictionary = HostileValues.strings()
	for definer in DEFINERS:
		for label: String in strings:
			var model := _model()
			var code: Error = _define(model, definer, strings[label])
			assert_int(code).is_equal(ERR_INVALID_PARAMETER)
			assert_str(HostileValues.find_raw_invisible(model.last_error)).is_empty()
			assert_int(model.last_error.length()).is_less_equal(ModelCheck.MAX_LAST_ERROR_LENGTH)


func test_error_names_the_bad_character_position_and_the_rule() -> void:
	var model := _model()
	assert_int(model.add_stock("人口", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_str(model.last_error).contains("位置 0")
	assert_str(model.last_error).contains("人")
	assert_str(model.last_error).contains("名前は半角英数字と _ だけで書く（先頭は数字にできない）")
	assert_int(model.add_constant("rate%", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_str(model.last_error).contains("位置 4")
	assert_int(model.add_stock("1abc", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_str(model.last_error).contains("先頭に数字は置けない")


func test_whitespace_around_a_name_is_not_trimmed() -> void:
	var model := _model()
	assert_int(model.add_stock(" pop", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_stock("pop ", 1.0)).is_equal(ERR_INVALID_PARAMETER)
	assert_int(model.add_stock("pop", 1.0)).is_equal(OK)


func test_check_identifier_is_shared_and_returns_empty_for_a_good_name() -> void:
	assert_str(ModelCheck.check_identifier("helper_1", "補助変数名")).is_empty()
	assert_str(ModelCheck.check_identifier("人口", "補助変数名")).contains("補助変数名に使えない文字")
	assert_str(ModelCheck.check_identifier("", "補助変数名")).contains("補助変数名が空である")
	assert_str(ModelCheck.check_identifier("a".repeat(ModelCheck.MAX_NAME_LENGTH + 1))).contains("長すぎる")


func test_name_start_and_char_use_ascii_only() -> void:
	assert_bool(ModelCheck.is_name_start(0x5F)).is_true()
	assert_bool(ModelCheck.is_name_start(0x30)).is_false()
	assert_bool(ModelCheck.is_name_char(0x30)).is_true()
	assert_bool(ModelCheck.is_name_char(0xFF21)).is_false()
	assert_bool(ModelCheck.is_name_char(0x4EBA)).is_false()


func test_actions_and_conditions_keep_their_free_form_names() -> void:
	# 範囲外：アクションと終了条件の名前は式から参照されない。表示にも使うので、今の規則のままとする。
	var model := _model()
	assert_int(model.add_action("植える", "1", ["s = s + 1"])).is_equal(OK)
	assert_int(model.add_victory_condition("豊かな町", "s > 100")).is_equal(OK)


func test_definers_list_covers_every_add_function_that_defines_a_stock_constant_or_flow() -> void:
	# 列挙の漏れを防ぐ。SimModel のソースから、ストック・定数・フローを定義する公開関数を拾い、DEFINERS と突き合わせる。
	var source: String = FileAccess.get_file_as_string("res://src/core/sim_model.gd")
	var regex := RegEx.new()
	regex.compile("(?m)^func (add_(?:stock|constant|flow)\\w*)\\(")
	var found: Array[String] = []
	for match in regex.search_all(source):
		found.append(match.get_string(1))
	found.sort()
	var expected: Array[String] = DEFINERS.duplicate()
	expected.sort()
	assert_array(found).is_equal(expected)
