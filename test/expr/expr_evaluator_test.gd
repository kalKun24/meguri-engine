## 式の組み立て（ExprCompiler）と評価（ExprEvaluator）のテスト。受け入れ基準ごとに分けて書く。
class_name ExprEvaluatorTest
extends GdUnitTestSuite

const STOCKS: Dictionary = {"pop": 100.0, "food": 40.0, "neg": -9.0}
const CONSTANTS: Dictionary = {"rate": 0.25, "big": 1e300}


# 構文解析から組み立てまでを行う。構文エラーは、テスト側の誤りとして失敗させる。
func _compile(source: String) -> ExprCompileResult:
	var parsed: ExprParseResult = ExprParser.new().parse(source)
	assert_bool(parsed.ok).is_true()
	return ExprCompiler.compile(parsed.root, source, STOCKS, CONSTANTS)


func _run(source: String) -> ExprEvalResult:
	var compiled := _compile(source)
	assert_bool(compiled.ok).is_true()
	return ExprEvaluator.evaluate(compiled.program, STOCKS)


func _value(source: String) -> float:
	var result := _run(source)
	assert_bool(result.ok).is_true()
	return result.value


func _compile_error(source: String) -> ExprSyntaxError:
	var compiled := _compile(source)
	assert_bool(compiled.ok).is_false()
	assert_object(compiled.program).is_null()
	assert_str(compiled.error.source).is_equal(source)
	return compiled.error


# --- 数値の評価 ---

func test_arithmetic_and_precedence() -> void:
	assert_float(_value("1 + 2 * 3")).is_equal(7.0)
	assert_float(_value("(1 + 2) * 3")).is_equal(9.0)
	assert_float(_value("10 - 4 - 3")).is_equal(3.0)
	assert_float(_value("-pop + 1")).is_equal(-99.0)


func test_names_resolve_to_stocks_and_constants() -> void:
	assert_float(_value("pop * rate")).is_equal(25.0)
	assert_float(_value("food - pop / 4")).is_equal(15.0)


func test_division_is_float() -> void:
	assert_float(_value("1/2")).is_equal(0.5)
	assert_float(_value("7 / 2")).is_equal(3.5)


func test_comparison_results_are_one_or_zero() -> void:
	assert_float(_value("1 < 2")).is_equal(1.0)
	assert_float(_value("2 < 1")).is_equal(0.0)
	assert_float(_value("2 <= 2")).is_equal(1.0)
	assert_float(_value("3 > 4")).is_equal(0.0)
	assert_float(_value("4 >= 4")).is_equal(1.0)
	assert_float(_value("pop == 100")).is_equal(1.0)
	assert_float(_value("pop != 100")).is_equal(0.0)
	assert_float(_value("(1 < 2) + (2 < 3)")).is_equal(2.0)


func test_modulo_is_float_fmod() -> void:
	assert_float(_value("5.5 % 2")).is_equal(1.5)
	assert_float(_value("-5 % 3")).is_equal(-2.0)
	assert_float(_value("5 % -3")).is_equal(2.0)


# --- 許可関数 ---

func test_allowed_functions() -> void:
	assert_float(_value("min(3, 2)")).is_equal(2.0)
	assert_float(_value("max(3, 2)")).is_equal(3.0)
	assert_float(_value("clamp(15, 0, 10)")).is_equal(10.0)
	assert_float(_value("clamp(-5, 0, 10)")).is_equal(0.0)
	assert_float(_value("clamp(5, 0, 10)")).is_equal(5.0)
	assert_float(_value("abs(-3.5)")).is_equal(3.5)
	assert_float(_value("floor(-2.5)")).is_equal(-3.0)
	assert_float(_value("ceil(2.1)")).is_equal(3.0)
	assert_float(_value("sqrt(16)")).is_equal(4.0)
	assert_float(_value("pow(2, 10)")).is_equal(1024.0)
	assert_float(_value("min(max(1, pop), 50)")).is_equal(50.0)


func test_round_goes_away_from_zero() -> void:
	assert_float(_value("round(2.5)")).is_equal(3.0)
	assert_float(_value("round(-2.5)")).is_equal(-3.0)
	assert_float(_value("round(2.4)")).is_equal(2.0)
	assert_float(_value("round(-2.4)")).is_equal(-2.0)
	assert_float(_value("round(0.5)")).is_equal(1.0)


func test_allowed_function_list_is_exactly_the_spec() -> void:
	var names := ExprFunctions.names()
	names.sort()
	assert_array(names).is_equal(["abs", "ceil", "clamp", "floor", "max", "min", "pow", "round", "sqrt"])


func test_wrong_argument_count_is_compile_error() -> void:
	var cases: Dictionary = {"min(1)": 0, "min(1, 2, 3)": 0, "abs()": 0, "abs(1, 2)": 0, "clamp(1, 2)": 0, "pow(2)": 0, "sqrt(1, 2)": 0}
	for source: String in cases:
		var error := _compile_error(source)
		assert_int(error.position).is_equal(0)
		assert_str(error.message).contains("引数")


func test_wrong_argument_count_reports_position_of_call() -> void:
	var error := _compile_error("1 + max(2)")
	assert_int(error.position).is_equal(4)


# --- 組み立て時のエラー ---

func test_disallowed_function_is_compile_error_with_position() -> void:
	var error := _compile_error("1 + foo(2)")
	assert_int(error.position).is_equal(4)
	assert_str(error.message).contains("許可されていない関数")
	assert_str(error.message).contains("foo")


func test_random_functions_are_not_allowed() -> void:
	for source: String in ["randf()", "randi()", "randf_range(0, 1)", "randi_range(0, 1)"]:
		assert_str(_compile_error(source).message).contains("許可されていない関数")


func test_type_constructors_are_rejected_as_disallowed_functions() -> void:
	var names: Array[String] = ["Vector2(1, 2)", "Vector3(1, 2, 3)", "Color(1, 1, 1)", "Rect2(1, 2, 3, 4)", "Transform2D(1, 2)", "Array()", "Dictionary()", "String(1)", "float(1)", "int(1)", "Object()", "Callable(1)"]
	for source in names:
		var error := _compile_error(source)
		assert_int(error.position).is_equal(0)
		assert_str(error.message).contains("許可されていない関数")


func test_global_functions_are_rejected() -> void:
	for source: String in ["print(1)", "load(1)", "preload(1)", "str(1)", "get_stock(1)", "lerp(1, 2, 3)", "sin(1)", "fmod(1, 2)", "snappedf(1, 2)"]:
		assert_str(_compile_error(source).message).contains("許可されていない関数")


func test_undefined_name_is_compile_error_with_position() -> void:
	var error := _compile_error("pop + missing * 2")
	assert_int(error.position).is_equal(6)
	assert_str(error.message).contains("未定義の名前")
	assert_str(error.message).contains("missing")


func test_bare_function_name_tells_how_to_fix() -> void:
	var error := _compile_error("1 + min")
	assert_int(error.position).is_equal(4)
	assert_str(error.message).contains("関数は () を付けて呼ぶ")
	assert_str(error.message).contains("min(x1, x2)")
	assert_str(_compile_error("round * 2").message).contains("関数は () を付けて呼ぶ")


func test_argument_names_are_resolved_too() -> void:
	var error := _compile_error("min(pop, nothing)")
	assert_int(error.position).is_equal(9)


func test_host_access_is_a_syntax_error() -> void:
	# 「.」は字句解析で拒否される。ホストのオブジェクトやメソッドには届かない。
	for source: String in ["OS.get_name()", "a.b", "pop.x", "Engine.get_version_info()"]:
		var parsed: ExprParseResult = ExprParser.new().parse(source)
		assert_bool(parsed.ok).is_false()
		assert_str(parsed.error.message).contains("'.'")
	assert_bool(ExprParser.new().parse("OS.get_name()").ok).is_false()
	assert_int(ExprParser.new().parse("1 + OS.get_name()").error.position).is_equal(6)


func test_nonfinite_number_literal_is_syntax_error_with_position() -> void:
	var source := "1 + " + "9".repeat(400)
	var parsed: ExprParseResult = ExprParser.new(1000).parse(source)
	assert_bool(parsed.ok).is_false()
	assert_int(parsed.error.position).is_equal(4)
	assert_str(parsed.error.message).contains("有限")
	# 有限の大きな数は通る。
	assert_bool(ExprParser.new().parse("1" + "0".repeat(300)).ok).is_true()


# --- 実行時エラー ---

func test_division_by_zero_is_runtime_error() -> void:
	var result := _run("pop / (food - 40)")
	assert_bool(result.ok).is_false()
	assert_float(result.value).is_equal(0.0)
	assert_int(result.position).is_equal(4)
	assert_str(result.message).contains("0 で割った")
	assert_str(result.message).contains("100.0 / 0.0")
	assert_bool(_run("0 / 0").ok).is_false()


func test_modulo_by_zero_is_runtime_error() -> void:
	var result := _run("5 % 0")
	assert_bool(result.ok).is_false()
	assert_str(result.message).contains("0 による剰余")
	assert_int(result.position).is_equal(2)
	assert_bool(_run("5 % (1 - 1)").ok).is_false()


func test_sqrt_of_negative_is_runtime_error_naming_the_operation() -> void:
	var result := _run("1 + sqrt(neg)")
	assert_bool(result.ok).is_false()
	assert_int(result.position).is_equal(4)
	assert_str(result.message).contains("NaN")
	assert_str(result.message).contains("sqrt(-9.0)")


func test_overflow_is_runtime_error_naming_the_operation() -> void:
	var result := _run("pow(10, 400)")
	assert_bool(result.ok).is_false()
	assert_str(result.message).contains("無限大")
	assert_str(result.message).contains("pow(10.0, 400.0)")
	var mul := _run("pop + big * big")
	assert_bool(mul.ok).is_false()
	assert_int(mul.position).is_equal(10)
	assert_str(mul.message).contains("*")
	assert_bool(_run("pow(0, -1)").ok).is_false()
	assert_bool(_run("pow(-8, 0.5)").ok).is_false()


func test_error_points_to_the_first_failing_operation() -> void:
	# 左の 1/0 が原因である。右の sqrt(-1) まで進まない。
	var result := _run("1 / 0 + sqrt(-1)")
	assert_int(result.position).is_equal(2)


# --- 長い式 ---

func test_long_left_associative_expression_does_not_hit_call_depth_limit() -> void:
	# 長さ 1000 字。木は左に約 500 段の深さになるが、組み立ても評価も反復で行う。
	var source := "1" + "+1".repeat(499) + " "
	assert_int(source.length()).is_equal(1000)
	assert_float(_value(source)).is_equal(500.0)
	var mixed := "pop" + "-1+1".repeat(249)
	assert_bool(mixed.length() <= 1000).is_true()
	assert_float(_value(mixed)).is_equal(100.0)


# --- clamp の下限と上限 ---

func test_clamp_with_lower_above_upper_is_runtime_error_naming_the_operation() -> void:
	var result := _run("1 + clamp(5, 10, 0)")
	assert_bool(result.ok).is_false()
	assert_int(result.position).is_equal(4)
	assert_str(result.message).contains("下限が上限より大きい")
	assert_str(result.message).contains("clamp(5.0, 10.0, 0.0)")


func test_clamp_with_lower_equal_to_upper_is_allowed() -> void:
	assert_float(_value("clamp(5, 3, 3)")).is_equal(3.0)


func test_clamp_with_lower_above_upper_from_stocks_is_runtime_error() -> void:
	var result := _run("clamp(pop, pop + 1, pop)")
	assert_bool(result.ok).is_false()
	assert_str(result.message).contains("下限が上限より大きい")
