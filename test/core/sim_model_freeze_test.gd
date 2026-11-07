## ゲームが終わった後の凍結（#37）のテスト。
## 終わった後は、モデルを変える公開関数がすべて ERR_LOCKED を返し、last_error が「ゲームは終了している」になり、状態が変わらない。
## 対象は、機械的に列挙する：src/core/sim_model.gd の公開関数のうち、名前が add_・set_ で始まるものと validate。
## 列挙の結果と、このファイルの _CALLS の対象が一致することを test_every_mutating_function_is_covered が確かめる。
## シグナルは、メンバ関数につないで数える（ラムダに model を捕捉させない）。
class_name SimModelFreezeTest
extends GdUnitTestSuite

const LOCKED_MESSAGE: String = "ゲームは終了している"

## 対象の関数名 -> 引数が正しく、終了前なら成功する呼び出し。
const _CALLS: Dictionary = {
	"add_stock": ["fresh_stock", 1.0],
	"add_constant": ["fresh_constant", 1.0],
	"add_flow": ["fresh_flow", "", "population", 1.0],
	"add_flow_expr": ["fresh_flow_expr", "", "population", "1 + 1"],
	"add_auxiliary": ["fresh_auxiliary", "population + 1"],
	"add_action": ["fresh_action", "1", ["population = population + 1"]],
	"add_victory_condition": ["fresh_victory", "population > 0"],
	"add_defeat_condition": ["fresh_defeat", "population < 0"],
	"set_simultaneous_priority": ["victory"],
	"set_seed": [99],
	"validate": [],
}

var _model: SimModel = null
var _during_turn_finished: Array[int] = []
var _during_game_ended: Array[int] = []


func after_test() -> void:
	if _model != null:
		if _model.turn_finished.is_connected(_on_turn_finished):
			_model.turn_finished.disconnect(_on_turn_finished)
		if _model.game_ended.is_connected(_on_game_ended):
			_model.game_ended.disconnect(_on_game_ended)
	_model = null
	_during_turn_finished.clear()
	_during_game_ended.clear()


func _on_turn_finished(_turn: int) -> void:
	_during_turn_finished.append(_model.add_stock("late_in_turn_finished", 1.0))


func _on_game_ended(_outcome: String, _condition_name: String, _turn: int) -> void:
	_during_game_ended.append(_model.add_stock("late_in_game_ended", 1.0))
	_during_game_ended.append(_model.add_victory_condition("late_victory", "population > 0"))
	_during_game_ended.append(_model.set_seed(5))
	_during_game_ended.append(_model.validate())


# 人口が毎ターン 10 増え、ターン 2 に人口 120 で勝利する。定義の種類をひととおり持つ。
func _ended_model() -> SimModel:
	var model := SimModel.new()
	model.add_stock("population", 100.0, StockRange.between(0.0, 1000.0))
	model.add_constant("goal", 120.0)
	model.add_flow("growth", "", "population", 10.0)
	model.add_auxiliary("double", "population * 2")
	model.add_action("bonus", "1", ["population = population + 1"])
	model.add_victory_condition("rich", "population >= goal")
	model.add_defeat_condition("broke", "population <= 0")
	model.set_seed(7)
	assert_int(model.advance_turn()).is_equal(OK)
	assert_int(model.advance_turn()).is_equal(OK)
	assert_bool(model.is_ended()).is_true()
	return model


# ストック・定数・フロー・アクション・条件・優先・シード・補助変数・範囲・ターン・乱数の状態を、1つの文字列にする。
func _state(model: SimModel) -> String:
	var flows: Array[String] = []
	for flow: Dictionary in model._flows:
		flows.append("%s:%s:%s:%s:%s" % [flow["name"], flow["source"], flow["sink"], flow["amount"], flow["expression"]])
	var auxiliaries: Array[String] = []
	for auxiliary: Dictionary in model._auxiliaries:
		auxiliaries.append("%s=%s" % [auxiliary["name"], auxiliary["expression"]])
	var conditions: Array[String] = []
	for condition: Dictionary in model._conditions:
		conditions.append("%s:%s:%s" % [condition["name"], condition["outcome"], condition["expression"]])
	return "stocks=%s|constants=%s|flows=%s|auxiliaries=%s|actions=%s|conditions=%s|priority=%s|seed=%d|rng=%d|ranges=%s|names=%s|turn=%d|result=%s" % [
		model._stocks, model._constants, flows, auxiliaries, model._actions.keys(), conditions, model.get_simultaneous_priority(),
		model.get_seed(), model.get_rng().state, model._ranges.keys(), model._names.keys(), model.get_turn(), model.get_result().outcome,
	]


func _call(model: SimModel, function_name: String) -> Error:
	return model.callv(function_name, _CALLS[function_name]) as Error


func _assert_frozen(function_name: String) -> void:
	var model := _ended_model()
	var before := _state(model)
	# 終了前なら成功する呼び出しであることを確かめる。そうでないと、凍結以外の理由で失敗しても気づけない。
	var fresh := SimModel.new()
	fresh.add_stock("population", 100.0)
	assert_int(_call(fresh, function_name)).override_failure_message("%s：終了前の呼び出しが成功しない（%s）" % [function_name, fresh.last_error]).is_equal(OK)
	model.last_error = ""
	assert_int(_call(model, function_name)).override_failure_message(function_name + " が ERR_LOCKED でない").is_equal(ERR_LOCKED)
	assert_str(model.last_error).is_equal(LOCKED_MESSAGE)
	assert_str(_state(model)).override_failure_message(function_name + " が状態を変えた").is_equal(before)
	# 2回目も同じである（次の操作も ERR_LOCKED）。
	assert_int(_call(model, function_name)).is_equal(ERR_LOCKED)
	assert_str(_state(model)).is_equal(before)


# --- 列挙表の対象（関数ごとのテスト） ---

func test_frozen_add_stock() -> void:
	_assert_frozen("add_stock")


func test_frozen_add_constant() -> void:
	_assert_frozen("add_constant")


func test_frozen_add_flow() -> void:
	_assert_frozen("add_flow")


func test_frozen_add_flow_expr() -> void:
	_assert_frozen("add_flow_expr")


func test_frozen_add_auxiliary() -> void:
	_assert_frozen("add_auxiliary")


func test_frozen_add_action() -> void:
	_assert_frozen("add_action")


func test_frozen_add_victory_condition() -> void:
	_assert_frozen("add_victory_condition")


func test_frozen_add_defeat_condition() -> void:
	_assert_frozen("add_defeat_condition")


func test_frozen_set_simultaneous_priority() -> void:
	_assert_frozen("set_simultaneous_priority")


func test_frozen_set_seed() -> void:
	_assert_frozen("set_seed")


func test_frozen_validate() -> void:
	_assert_frozen("validate")


# sim_model.gd の公開関数から、モデルを変えるもの（add_・set_ で始まるものと validate）を列挙し、_CALLS と一致させる。
func test_every_mutating_function_is_covered() -> void:
	var found: Array[String] = []
	for method: Dictionary in SimModel.new().get_script().get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("add_") or method_name.begins_with("set_") or method_name == "validate":
			found.append(method_name)
	found.sort()
	var covered: Array[String] = []
	for function_name: String in _CALLS:
		covered.append(function_name)
		assert_bool(has_method("test_frozen_" + function_name)).override_failure_message("test_frozen_%s が無い" % function_name).is_true()
	covered.sort()
	assert_array(found).is_equal(covered)
	assert_int(found.size()).is_equal(11)


# --- 読むだけの関数は凍結しない ---

func test_read_functions_still_work_after_end() -> void:
	var model := _ended_model()
	var before := _state(model)
	assert_bool(model.is_ended()).is_true()
	assert_int(model.get_stock("population").error).is_equal(OK)
	assert_float(model.get_stock("population").value).is_equal(120.0)
	assert_int(model.get_constant("goal").error).is_equal(OK)
	assert_bool(model.has_stock("population")).is_true()
	assert_bool(model.has_action("bonus")).is_true()
	assert_str(model.get_result().condition_name).is_equal("rich")
	assert_int(model.get_turn()).is_equal(2)
	assert_int(model.get_seed()).is_equal(7)
	assert_str(model.last_error).is_empty()
	assert_str(_state(model)).is_equal(before)


# --- 受け手の中から呼んでも凍結される ---

func test_frozen_inside_game_ended_receiver() -> void:
	_model = SimModel.new()
	_model.add_stock("population", 100.0)
	_model.add_flow("growth", "", "population", 10.0)
	_model.add_victory_condition("rich", "population >= 120")
	_model.game_ended.connect(_on_game_ended)
	assert_int(_model.advance_turn()).is_equal(OK)
	assert_int(_model.advance_turn()).is_equal(OK)
	assert_bool(_model.is_ended()).is_true()
	assert_array(_during_game_ended).is_equal([ERR_LOCKED, ERR_LOCKED, ERR_LOCKED, ERR_LOCKED])
	assert_bool(_model.has_stock("late_in_game_ended")).is_false()
	assert_int(_model.get_seed()).is_equal(0)


func test_frozen_inside_turn_finished_receiver_of_the_ending_turn() -> void:
	_model = SimModel.new()
	_model.add_stock("population", 100.0)
	_model.add_flow("growth", "", "population", 10.0)
	_model.add_victory_condition("rich", "population >= 120")
	_model.turn_finished.connect(_on_turn_finished)
	# ターン 1 は終わっていないので、受け手の add_stock は通る。
	assert_int(_model.advance_turn()).is_equal(OK)
	assert_bool(_model.is_ended()).is_false()
	assert_array(_during_turn_finished).is_equal([OK])
	# ターン 2 で終わる。turn_finished の受け手が呼んだ add_stock は凍結される。
	assert_int(_model.advance_turn()).is_equal(OK)
	assert_bool(_model.is_ended()).is_true()
	assert_int(_during_turn_finished.size()).is_equal(2)
	assert_int(_during_turn_finished[1]).is_equal(ERR_LOCKED)


# --- set_seed は Error を返す ---

func test_set_seed_returns_ok_and_clears_last_error() -> void:
	var model := SimModel.new()
	model.add_stock("a", 1.0)
	model.add_stock("a", 1.0)
	assert_str(model.last_error).is_not_empty()
	assert_int(model.set_seed(42)).is_equal(OK)
	assert_str(model.last_error).is_empty()
	assert_int(model.get_seed()).is_equal(42)


func test_set_seed_accepts_extreme_values_and_returns_ok() -> void:
	var model := SimModel.new()
	for value: int in [0, -1, 9223372036854775807, -9223372036854775807 - 1]:
		assert_int(model.set_seed(value)).is_equal(OK)
		assert_int(model.get_seed()).is_equal(value)


func test_set_seed_after_end_keeps_seed_and_rng() -> void:
	var model := _ended_model()
	var rng_state := model.get_rng().state
	assert_int(model.set_seed(123)).is_equal(ERR_LOCKED)
	assert_str(model.last_error).is_equal(LOCKED_MESSAGE)
	assert_int(model.get_seed()).is_equal(7)
	assert_int(model.get_rng().state).is_equal(rng_state)
