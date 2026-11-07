## 比較を連ねた式の拒否（#22）のテスト。受け入れ基準ごとに分けて書く。
class_name ExprComparisonChainTest
extends GdUnitTestSuite

const OPERATORS: Array[String] = ["<", "<=", ">", ">=", "==", "!="]


func _parse(source: String) -> ExprParseResult:
	return ExprParser.new().parse(source)


func _error(source: String) -> ExprSyntaxError:
	var result: ExprParseResult = _parse(source)
	assert_bool(result.ok).is_false()
	assert_object(result.root).is_null()
	return result.error


## 6種類の比較演算子の、全36通りの組み合わせが、2つ目の演算子の位置で構文エラーになる。
func test_every_pair_of_the_six_comparison_operators_is_rejected_at_the_second_one() -> void:
	assert_int(OPERATORS.size()).is_equal(6)
	for first in OPERATORS:
		for second in OPERATORS:
			var source: String = "a %s b %s c" % [first, second]
			var err: ExprSyntaxError = _error(source)
			assert_int(err.position).is_equal(source.rfind(second))
			assert_str(err.message).contains(second)


func test_examples_from_the_story_are_rejected() -> void:
	assert_int(_error("0 < x < 10").position).is_equal(6)
	assert_int(_error("a == b == c").position).is_equal(7)
	assert_int(_error("a < b == c").position).is_equal(6)
	assert_int(_error("a == b != c").position).is_equal(7)


func test_error_says_one_comparison_per_expression_and_shows_the_parenthesized_form() -> void:
	var err: ExprSyntaxError = _error("0 < x < 10")
	assert_str(err.message).contains("比較は1つの式に1つまで")
	assert_str(err.message).contains("(0 < x) * (x < 10)")
	assert_str(err.format()).contains("(0 < x) * (x < 10)")


func test_three_comparisons_stop_at_the_second() -> void:
	assert_int(_error("a < b < c < d").position).is_equal(6)


func test_chain_inside_parentheses_and_call_arguments_is_rejected() -> void:
	assert_int(_error("(a < b < c)").position).is_equal(7)
	assert_int(_error("min(a, 0 < x < 10)").position).is_equal(13)
	assert_int(_error("1 + (a < b > c) * 2").position).is_equal(11)


func test_parenthesized_comparison_is_allowed() -> void:
	assert_str(_parse("(a < b) < c").root.to_text()).is_equal("(< (< a b) c)")
	assert_str(_parse("a < (b < c)").root.to_text()).is_equal("(< a (< b c))")
	assert_str(_parse("(a == b) != (c == d)").root.to_text()).is_equal("(!= (== a b) (== c d))")
	assert_str(_parse("(0 < x) * (x < 10)").root.to_text()).is_equal("(* (< 0.0 x) (< x 10.0))")


func test_example_form_evaluates_as_a_range_check() -> void:
	var source: String = "(0 < x) * (x < 10)"
	var compiled: ExprCompileResult = ExprCompiler.compile(_parse(source).root, source, {"x": 5.0}, {})
	assert_bool(compiled.ok).is_true()
	assert_float(ExprEvaluator.evaluate(compiled.program, {"x": 5.0}).value).is_equal(1.0)
	assert_float(ExprEvaluator.evaluate(compiled.program, {"x": 50.0}).value).is_equal(0.0)


func test_single_comparison_is_unchanged() -> void:
	for op in OPERATORS:
		assert_bool(_parse("a + 1 %s b * 2" % op).ok).is_true()
