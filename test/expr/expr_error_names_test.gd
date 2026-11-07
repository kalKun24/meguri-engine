## 実行時エラーの「原因の演算」に、名前で参照した値の名前と値を添えるテスト（#23）。
## 対象は、除算、剰余、べき乗（pow）、関数呼び出し（許可関数の全件）である。
class_name ExprErrorNamesTest
extends GdUnitTestSuite

const STOCKS: Dictionary = {"stock": 0.0, "divisor": 0.0, "pop": 100.0, "huge": 1e300, "ten": 10.0, "inf_stock": INF, "nan_stock": NAN}
const CONSTANTS: Dictionary = {"rate": 0.0, "big": 1e300}
var BIG_TEXT: String = str(1e300)


func _run(source: String, auxiliaries: Dictionary = {}) -> ExprEvalResult:
	var parsed: ExprParseResult = ExprParser.new().parse(source)
	assert_bool(parsed.ok).is_true()
	var compiled: ExprCompileResult = ExprCompiler.compile(parsed.root, source, STOCKS, CONSTANTS, auxiliaries)
	assert_bool(compiled.ok).is_true()
	var values: Dictionary = {}
	for key: String in auxiliaries:
		values[key] = auxiliaries[key]
	return ExprEvaluator.evaluate(compiled.program, STOCKS, values)


# --- 除算・剰余 ---

func test_division_names_the_stocks_and_values() -> void:
	var result := _run("stock / divisor")
	assert_bool(result.ok).is_false()
	assert_str(result.message).is_equal("0 で割った：0.0 / 0.0（stock = 0.0、divisor = 0.0）")


func test_division_names_only_the_operand_that_is_a_name() -> void:
	assert_str(_run("pop / (divisor - 0)").message).is_equal("0 で割った：100.0 / 0.0（pop = 100.0）")
	assert_str(_run("pop / (divisor - divisor)").message).is_equal("0 で割った：100.0 / 0.0（pop = 100.0）")
	assert_str(_run("(pop - 1) / divisor").message).is_equal("0 で割った：99.0 / 0.0（divisor = 0.0）")


func test_division_without_any_name_is_unchanged() -> void:
	assert_str(_run("1 / 0").message).is_equal("0 で割った：1.0 / 0.0")


func test_division_names_a_constant() -> void:
	assert_str(_run("pop / rate").message).is_equal("0 で割った：100.0 / 0.0（pop = 100.0、rate = 0.0）")


func test_division_names_an_auxiliary() -> void:
	var result := _run("pop / ratio", {"ratio": 0.0})
	assert_str(result.message).is_equal("0 で割った：100.0 / 0.0（pop = 100.0、ratio = 0.0）")


func test_the_same_name_is_shown_once() -> void:
	assert_str(_run("stock / stock").message).is_equal("0 で割った：0.0 / 0.0（stock = 0.0）")


func test_negated_name_is_not_shown_as_the_name() -> void:
	# -pop は計算で作った値である。pop の値そのものではない。
	assert_str(_run("-pop / divisor").message).is_equal("0 で割った：-100.0 / 0.0（divisor = 0.0）")


func test_modulo_names_the_stocks_and_values() -> void:
	var result := _run("pop % divisor")
	assert_bool(result.ok).is_false()
	assert_str(result.message).is_equal("0 による剰余を求めた：100.0 % 0.0（pop = 100.0、divisor = 0.0）")
	assert_str(_run("5 % rate").message).is_equal("0 による剰余を求めた：5.0 % 0.0（rate = 0.0）")


func test_division_overflow_also_names_the_values() -> void:
	var result := _run("big / 0.000000000001")
	assert_bool(result.ok).is_false()
	assert_str(result.message).contains("無限大")
	assert_str(result.message).contains("（big = " + BIG_TEXT + "）")


# --- べき乗 ---

func test_power_names_the_stocks_and_values() -> void:
	var result := _run("pow(huge, ten)")
	assert_bool(result.ok).is_false()
	assert_str(result.message).is_equal("結果が 無限大 になった：pow(" + BIG_TEXT + ", 10.0)（huge = " + BIG_TEXT + "、ten = 10.0）")
	assert_str(_run("pow(big, 2)").message).contains("（big = " + BIG_TEXT + "）")


# --- 関数呼び出し（許可関数の全件） ---
# 列挙：grep -nP '^\t"\w+": \d+,' src/expr/expr_functions.gd（ARITY の9件）。
# それぞれの関数が、名前の付いた引数で失敗する式を使う。失敗しない引数の組は、その関数の式に使わない。
# min の第1引数 NaN は失敗しない（minf が第2引数を返す）ので、第2引数に NaN を渡す。

const FUNCTION_CASES: Dictionary = {
	"min": "min(pop, nan_stock)",
	"max": "max(pop, nan_stock)",
	"clamp": "clamp(nan_stock, 0, pop)",
	"abs": "abs(inf_stock)",
	"floor": "floor(inf_stock)",
	"round": "round(inf_stock)",
	"ceil": "ceil(inf_stock)",
	"sqrt": "sqrt(inf_stock)",
	"pow": "pow(inf_stock, ten)",
}


func test_function_cases_cover_every_allowed_function() -> void:
	var allowed := ExprFunctions.names()
	allowed.sort()
	var covered: Array = FUNCTION_CASES.keys()
	covered.sort()
	assert_array(covered).is_equal(allowed)
	assert_int(allowed.size()).is_equal(9)


func test_every_allowed_function_names_the_argument_values() -> void:
	for function_name: String in ExprFunctions.names():
		var source: String = FUNCTION_CASES[function_name]
		var result := _run(source)
		assert_bool(result.ok).override_failure_message("%s が失敗しない：%s" % [function_name, source]).is_false()
		assert_str(result.message).override_failure_message("%s：%s" % [function_name, result.message]).contains("%s(" % function_name)
		var expected_name := "nan_stock" if source.contains("nan_stock") else "inf_stock"
		assert_str(result.message).override_failure_message("%s：%s" % [function_name, result.message]).contains("（")
		assert_str(result.message).override_failure_message("%s：%s" % [function_name, result.message]).contains("%s = " % expected_name)


func test_function_names_every_named_argument_in_order() -> void:
	var result := _run("clamp(nan_stock, stock, pop)")
	assert_str(result.message).is_equal("結果が NaN になった：clamp(nan, 0.0, 100.0)（nan_stock = nan、stock = 0.0、pop = 100.0）")
	# 数値リテラルの引数は名前を持たない。
	assert_str(_run("clamp(nan_stock, 0, pop)").message).is_equal("結果が NaN になった：clamp(nan, 0.0, 100.0)（nan_stock = nan、pop = 100.0）")


func test_function_without_any_name_is_unchanged() -> void:
	assert_str(_run("sqrt(-1)").message).is_equal("結果が NaN になった：sqrt(-1.0)")
	assert_str(_run("pow(10, 400)").message).is_equal("結果が 無限大 になった：pow(10.0, 400.0)")


func test_function_names_a_constant_and_an_auxiliary() -> void:
	assert_str(_run("pow(big, 2)").message).is_equal("結果が 無限大 になった：pow(" + BIG_TEXT + ", 2.0)（big = " + BIG_TEXT + "）")
	assert_str(_run("pow(level, 2)", {"level": 1e300}).message).is_equal("結果が 無限大 になった：pow(" + BIG_TEXT + ", 2.0)（level = " + BIG_TEXT + "）")


func test_computed_argument_is_not_named() -> void:
	assert_str(_run("pow(huge * 1, 2)").message).is_equal("結果が 無限大 になった：pow(" + BIG_TEXT + ", 2.0)")


# --- 名前の escape と省略（評価器に直接渡した敵対的な名前） ---

func _program_dividing(name_value: String) -> ExprProgram:
	var program := ExprProgram.new()
	program.emit(ExprProgram.Op.PUSH_STOCK, 0, 0.0, name_value)
	program.emit(ExprProgram.Op.PUSH_NUMBER, 2, 0.0)
	program.emit(ExprProgram.Op.DIV, 1)
	return program


func test_name_is_escaped() -> void:
	var hostile := "a" + char(0x202E) + "b" + char(0x200B) + "c" + "\\" + "d"
	var result := ExprEvaluator.evaluate(_program_dividing(hostile), {hostile: 5.0})
	assert_bool(result.ok).is_false()
	assert_str(HostileValues.find_raw_invisible(result.message)).is_empty()
	assert_str(result.message).contains("a\\u{202E}b\\u{200B}c\\\\d = 5.0")


func test_long_name_is_shortened_by_the_escape_default() -> void:
	var long_name := "n".repeat(100)
	var result := ExprEvaluator.evaluate(_program_dividing(long_name), {long_name: 5.0})
	assert_str(result.message).contains("（%s... = 5.0）" % "n".repeat(ModelCheck.MAX_MESSAGE_NAME_LENGTH))
	assert_bool(result.message.contains("n".repeat(ModelCheck.MAX_MESSAGE_NAME_LENGTH + 1))).is_false()


# 切った文が、エスケープの表記（\\ と \u{…}）の途中で終わっていないことを確かめる。
func _assert_ends_on_a_unit_boundary(text: String) -> void:
	var i := 0
	while i < text.length():
		if text[i] == "\\":
			if i + 1 < text.length() and text[i + 1] == "\\":
				i += 2
				continue
			var close := text.find("}", i)
			assert_bool(i + 2 < text.length() and text[i + 1] == "u" and text[i + 2] == "{" and close > i).override_failure_message("表記の途中で切れている：位置 %d、末尾 %s" % [i, text.substr(maxi(0, text.length() - 20))]).is_true()
			if close < 0:
				return
			i = close + 1
			continue
		i += 1


func test_escaped_names_with_the_reason_limit_never_cut_a_notation() -> void:
	# 名前1つが escape で 32 文字 × 8 = 256 文字に伸びる。3 つ並ぶと 200 文字の上限を超える。
	var stocks: Dictionary = {}
	var hostile_names: Array[String] = []
	for k in 3:
		var hostile_name: String = (char(0x202E) + "\\").repeat(40) + str(k)
		hostile_names.append(hostile_name)
		stocks[hostile_name] = 1e300
	# pow(1e300, 1e300) で失敗させる。
	var pow_program := ExprProgram.new()
	pow_program.emit(ExprProgram.Op.PUSH_STOCK, 0, 0.0, hostile_names[0])
	pow_program.emit(ExprProgram.Op.PUSH_STOCK, 0, 0.0, hostile_names[1])
	pow_program.emit(ExprProgram.Op.CALL, 0, 0.0, "pow", 2)
	var result := ExprEvaluator.evaluate(pow_program, stocks)
	assert_bool(result.ok).is_false()
	assert_str(HostileValues.find_raw_invisible(result.message)).is_empty()
	for limit in [ModelCheck.MAX_MESSAGE_REASON_LENGTH, 60, 100, 137, 199]:
		var cut := ModelCheck.escape_excerpt(result.message, limit, false)
		assert_int(cut.length()).is_less_equal(limit)
		assert_bool(cut.ends_with("...")).is_true()
		_assert_ends_on_a_unit_boundary(cut.trim_suffix("..."))
	var reason := ModelCheck.escape_reason(result.message)
	assert_int(reason.length()).is_less_equal(ModelCheck.MAX_MESSAGE_REASON_LENGTH)
	_assert_ends_on_a_unit_boundary(reason.trim_suffix("..."))
	var last_error := ModelCheck.limit_last_error(reason)
	assert_int(last_error.length()).is_less_equal(ModelCheck.MAX_LAST_ERROR_LENGTH)


# --- SimModel を通した last_error ---

func test_last_error_shows_the_names_for_a_stock_over_a_stock() -> void:
	var model := SimModel.new()
	model.add_stock("stock", 0.0)
	model.add_stock("divisor", 0.0)
	model.add_stock("sink", 0.0)
	model.add_flow_expr("ratio", "", "sink", "stock / divisor")
	assert_int(model.step()).is_not_equal(OK)
	assert_str(model.last_error).contains("0 で割った：0.0 / 0.0（stock = 0.0、divisor = 0.0）")
	assert_int(model.get_turn()).is_equal(0)


func test_last_error_shows_a_constant_and_an_auxiliary() -> void:
	var model := SimModel.new()
	model.add_stock("pop", 100.0)
	model.add_stock("sink", 0.0)
	model.add_constant("rate", 0.0)
	model.add_auxiliary("level", "rate * 2")
	model.add_flow_expr("a", "", "sink", "pop % level")
	assert_int(model.step()).is_not_equal(OK)
	assert_str(model.last_error).contains("0 による剰余を求めた：100.0 % 0.0（pop = 100.0、level = 0.0）")
	var other := SimModel.new()
	other.add_stock("pop", 100.0)
	other.add_stock("sink", 0.0)
	other.add_constant("rate", 0.0)
	other.add_flow_expr("a", "", "sink", "pop / rate")
	assert_int(other.step()).is_not_equal(OK)
	assert_str(other.last_error).contains("（pop = 100.0、rate = 0.0）")


func test_auxiliary_error_in_last_error_names_the_values() -> void:
	var model := SimModel.new()
	model.add_stock("pop", 100.0)
	model.add_stock("sink", 0.0)
	model.add_stock("zero", 0.0)
	model.add_auxiliary("ratio", "pop / zero")
	model.add_flow_expr("a", "", "sink", "ratio")
	assert_int(model.step()).is_not_equal(OK)
	assert_str(model.last_error).contains("補助変数「ratio」")
	assert_str(model.last_error).contains("（pop = 100.0、zero = 0.0）")


# --- 列7：式の長さの上限いっぱいで、名前を多く参照する式 ---
# 式は1000字ちょうどで、異なるストック名を数百個参照する。最後の pow で失敗し、原因の文を作る。
# 実測は print に出す（再現：scripts/test.sh -a res://test/expr/expr_error_names_test.gd）。

func _many_names_model(count: int) -> Dictionary:
	var stocks: Dictionary = {}
	var terms := PackedStringArray()
	for k in count:
		stocks["s%d" % k] = 1.0
		terms.append("s%d" % k)
	stocks["huge"] = 1e300
	var source := "+".join(terms) + "+pow(huge,huge)"
	return {"stocks": stocks, "source": source}


func test_cost_of_a_cause_message_with_the_longest_expression_full_of_names() -> void:
	var count := 1
	var built := _many_names_model(count)
	# 式が 1000 字に収まる最大の個数を探す。
	while (_many_names_model(count + 1)["source"] as String).length() <= 1000:
		count += 1
	built = _many_names_model(count)
	var source: String = built["source"]
	var stocks: Dictionary = built["stocks"]
	assert_int(source.length()).is_less_equal(1000)
	var parsed: ExprParseResult = ExprParser.new().parse(source)
	assert_bool(parsed.ok).is_true()
	var compiled: ExprCompileResult = ExprCompiler.compile(parsed.root, source, stocks, {})
	assert_bool(compiled.ok).is_true()
	var repeat := 200
	var start := Time.get_ticks_usec()
	var result: ExprEvalResult = null
	for k in repeat:
		result = ExprEvaluator.evaluate(compiled.program, stocks)
	var per_run_ms := (Time.get_ticks_usec() - start) / 1000.0 / repeat
	assert_bool(result.ok).is_false()
	assert_str(result.message).contains("（huge = " + BIG_TEXT + "）")
	print("[列7] 式 %d 字、名前 %d 個、原因の文まで評価 1 回 = %.3f ms（%d 回の平均）" % [source.length(), count, per_run_ms, repeat])
	assert_float(per_run_ms).is_less(50.0)
	# 成功する式の評価にかかる時間（名前の追跡の費用を見る）。
	var ok_source := source.replace("+pow(huge,huge)", "")
	var ok_parsed: ExprParseResult = ExprParser.new().parse(ok_source)
	var ok_compiled: ExprCompileResult = ExprCompiler.compile(ok_parsed.root, ok_source, stocks, {})
	start = Time.get_ticks_usec()
	for k in repeat:
		ExprEvaluator.evaluate(ok_compiled.program, stocks)
	var ok_ms := (Time.get_ticks_usec() - start) / 1000.0 / repeat
	print("[列7] 成功する同じ長さの式の評価 1 回 = %.3f ms" % ok_ms)
	assert_float(ok_ms).is_less(50.0)
