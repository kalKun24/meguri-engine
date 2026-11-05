## 式のパーサ（ExprParser）のテスト。受け入れ基準ごとに分けて書く。
class_name ExprParserTest
extends GdUnitTestSuite

const SRC_DIR: String = "res://src/expr"


# 構文木を S 式にして返す。構文エラーなら "ERR" を返す。
func _tree(source: String) -> String:
	var result: ExprParseResult = ExprParser.new().parse(source)
	return result.root.to_text() if result.ok else "ERR"


func _error(source: String, parser: ExprParser = null) -> ExprSyntaxError:
	var p: ExprParser = parser if parser != null else ExprParser.new()
	var result: ExprParseResult = p.parse(source)
	assert_bool(result.ok).is_false()
	assert_object(result.root).is_null()
	return result.error


# --- 文法：受け付ける式 ---

func test_parses_number_and_name() -> void:
	assert_str(_tree("42")).is_equal("42.0")
	assert_str(_tree("0.02")).is_equal("0.02")
	assert_str(_tree("population")).is_equal("population")
	assert_str(_tree("_a1")).is_equal("_a1")


func test_parses_demo_expression() -> void:
	var result: ExprParseResult = ExprParser.new().parse("population * 0.02 + 1")
	assert_bool(result.ok).is_true()
	assert_object(result.error).is_null()
	assert_str(result.root.to_text()).is_equal("(+ (* population 0.02) 1.0)")


func test_node_fields() -> void:
	var root: ExprNode = ExprParser.new().parse("a + f(1, b)").root
	assert_int(root.kind).is_equal(ExprNode.Kind.BINARY)
	assert_str(root.op).is_equal("+")
	assert_int(root.children.size()).is_equal(2)
	assert_int(root.children[0].kind).is_equal(ExprNode.Kind.NAME)
	assert_str(root.children[0].name).is_equal("a")
	var call: ExprNode = root.children[1]
	assert_int(call.kind).is_equal(ExprNode.Kind.CALL)
	assert_str(call.name).is_equal("f")
	assert_int(call.children.size()).is_equal(2)
	assert_int(call.children[0].kind).is_equal(ExprNode.Kind.NUMBER)
	assert_float(call.children[0].number).is_equal(1.0)


func test_parses_all_binary_operators() -> void:
	for op in ["+", "-", "*", "/", "%", "<", "<=", ">", ">=", "==", "!="]:
		assert_str(_tree("a %s b" % op)).is_equal("(%s a b)" % op)


func test_parses_without_spaces_and_with_whitespace() -> void:
	assert_str(_tree("a+b*c")).is_equal("(+ a (* b c))")
	assert_str(_tree("  a \t+\n b ")).is_equal("(+ a b)")
	assert_str(_tree("a<=b")).is_equal("(<= a b)")


func test_parses_function_calls() -> void:
	assert_str(_tree("f()")).is_equal("(call f)")
	assert_str(_tree("f(a)")).is_equal("(call f a)")
	assert_str(_tree("max(a, b + 1, -c)")).is_equal("(call max a (+ b 1.0) (neg c))")
	assert_str(_tree("f(g(1), h(2, 3)) * 2")).is_equal("(* (call f (call g 1.0) (call h 2.0 3.0)) 2.0)")


# --- 優先順位と結合規則 ---

func test_multiplication_binds_tighter_than_addition() -> void:
	assert_str(_tree("2 + 3 * 4")).is_equal("(+ 2.0 (* 3.0 4.0))")
	assert_str(_tree("2 * 3 + 4")).is_equal("(+ (* 2.0 3.0) 4.0)")


func test_parentheses_override_precedence() -> void:
	assert_str(_tree("(2 + 3) * 4")).is_equal("(* (+ 2.0 3.0) 4.0)")


func test_binary_operators_are_left_associative() -> void:
	assert_str(_tree("a - b - c")).is_equal("(- (- a b) c)")
	assert_str(_tree("a / b / c")).is_equal("(/ (/ a b) c)")
	assert_str(_tree("a / b * c % d")).is_equal("(% (* (/ a b) c) d)")
	assert_str(_tree("a - b + c")).is_equal("(+ (- a b) c)")


func test_unary_minus_binds_tighter_than_binary_operators() -> void:
	assert_str(_tree("-a * b")).is_equal("(* (neg a) b)")
	assert_str(_tree("-a + b")).is_equal("(+ (neg a) b)")
	assert_str(_tree("a - -b")).is_equal("(- a (neg b))")
	assert_str(_tree("a * -b")).is_equal("(* a (neg b))")
	assert_str(_tree("--a")).is_equal("(neg (neg a))")
	assert_str(_tree("-(a + b)")).is_equal("(neg (+ a b))")
	assert_str(_tree("-f(x)")).is_equal("(neg (call f x))")


func test_comparison_has_lowest_precedence_and_is_left_associative() -> void:
	assert_str(_tree("a + 1 < b * 2")).is_equal("(< (+ a 1.0) (* b 2.0))")
	assert_str(_tree("a < b == c")).is_equal("(== (< a b) c)")
	assert_str(_tree("a == b != c")).is_equal("(!= (== a b) c)")
	assert_str(_tree("-a >= -b")).is_equal("(>= (neg a) (neg b))")


# --- 文法に無いものは構文エラー ---

func test_rejects_unsupported_syntax() -> void:
	var cases: Dictionary = {
		"a.b": 1,
		"OS.get_name()": 2,
		"\"abc\"": 0,
		"'abc'": 0,
		"[1, 2]": 0,
		"a[0]": 1,
		"{}": 0,
		"a = 1": 2,
		"a && b": 2,
		"a || b": 2,
		"!a": 0,
		"a ? b : c": 2,
		"$x": 0,
		"a $ b": 2,
		"1.": 1,
		".5": 0,
		"Vector2(1, 2).x": 13,
	}
	for source in cases:
		var err: ExprSyntaxError = _error(source)
		assert_str(err.source).is_equal(source)
		assert_int(err.position).is_equal(cases[source])
		assert_str(err.message).is_not_empty()


func test_type_constructor_without_property_is_just_a_call() -> void:
	# 型コンストラクタという区別は文法に無い。Vector2(1, 2) は名前つきの関数呼び出しとして読める。
	# 実際に呼べるかは、関数の許可リストを持つ評価側（#10）で決める。
	assert_str(_tree("Vector2(1, 2)")).is_equal("(call Vector2 1.0 2.0)")


func test_rejects_whole_number_forms_not_in_grammar() -> void:
	assert_str(_tree("1e3")).is_equal("ERR")
	assert_str(_tree("0x10")).is_equal("ERR")


# --- 構文エラーの内容 ---

func test_error_has_source_position_and_message() -> void:
	var err: ExprSyntaxError = _error("population * ")
	assert_str(err.source).is_equal("population * ")
	assert_int(err.position).is_equal(13)
	assert_str(err.message).contains("終わっている")


func test_trailing_operator_is_error_at_end() -> void:
	assert_int(_error("a +").position).is_equal(3)
	assert_int(_error("a <").position).is_equal(3)
	assert_int(_error("-").position).is_equal(1)


func test_empty_string_is_error_at_zero() -> void:
	var err: ExprSyntaxError = _error("")
	assert_int(err.position).is_equal(0)
	assert_str(err.message).contains("空")
	assert_str(err.source).is_equal("")


func test_whitespace_only_is_empty_error() -> void:
	var err: ExprSyntaxError = _error("   ")
	assert_int(err.position).is_equal(3)
	assert_str(err.message).contains("空")


func test_unclosed_parenthesis_reports_end_and_open_position() -> void:
	var err: ExprSyntaxError = _error("(a + b")
	assert_int(err.position).is_equal(6)
	assert_str(err.message).contains("閉じていない")
	assert_str(err.message).contains("位置 0")
	err = _error("2 * (a + (b)")
	assert_int(err.position).is_equal(12)
	assert_str(err.message).contains("位置 4")


func test_unclosed_call_is_error() -> void:
	var err: ExprSyntaxError = _error("f(a, b")
	assert_int(err.position).is_equal(6)
	assert_str(err.message).contains("閉じていない")


func test_unexpected_closing_parenthesis() -> void:
	assert_int(_error("a)").position).is_equal(1)
	assert_int(_error(")").position).is_equal(0)
	assert_int(_error("()").position).is_equal(1)


func test_unknown_characters_report_their_position() -> void:
	assert_int(_error("a $ b").position).is_equal(2)
	assert_str(_error("a $ b").message).contains("$")
	assert_int(_error("a\"b").position).is_equal(1)
	assert_str(_error("a\"b").message).contains("文字列")
	assert_int(_error("a.b").position).is_equal(1)
	assert_str(_error("a.b").message).contains("'.'")
	assert_int(_error("a # b").position).is_equal(2)


func test_missing_operator_between_values() -> void:
	var err: ExprSyntaxError = _error("a b")
	assert_int(err.position).is_equal(2)
	err = _error("2 (3)")
	assert_int(err.position).is_equal(2)


func test_bad_call_arguments() -> void:
	assert_int(_error("f(,)").position).is_equal(2)
	assert_int(_error("f(1,)").position).is_equal(4)
	assert_int(_error("f(1 2)").position).is_equal(4)
	assert_int(_error("f(1,").position).is_equal(4)


func test_earliest_error_wins() -> void:
	# 位置 2 の `*` が先に見つかる。後ろの `$` は報告しない。
	var err: ExprSyntaxError = _error("a * * $")
	assert_int(err.position).is_equal(4)
	err = _error("$ + * ")
	assert_int(err.position).is_equal(0)


func test_error_format_shows_position_and_source() -> void:
	var text: String = _error("a $ b").format()
	assert_str(text).contains("位置 2")
	assert_str(text).contains("a $ b")
	assert_str(text).contains("\n    ^")


func test_parser_is_reusable_after_error() -> void:
	var parser := ExprParser.new()
	assert_bool(parser.parse("a +").ok).is_false()
	var result: ExprParseResult = parser.parse("a + b")
	assert_bool(result.ok).is_true()
	assert_object(result.error).is_null()
	assert_str(result.root.to_text()).is_equal("(+ a b)")


# --- 上限 ---

func test_default_limits() -> void:
	var parser := ExprParser.new()
	assert_int(parser.max_length).is_equal(1000)
	assert_int(parser.max_depth).is_equal(50)


func test_length_limit() -> void:
	var ok_source: String = "a".repeat(1000)
	assert_bool(ExprParser.new().parse(ok_source).ok).is_true()
	var err: ExprSyntaxError = _error("a".repeat(1001))
	assert_int(err.position).is_equal(1000)
	assert_str(err.message).contains("長すぎる")
	assert_int(err.source.length()).is_equal(1001)


func test_length_limit_is_configurable() -> void:
	var parser := ExprParser.new(5, 50)
	assert_bool(parser.parse("a + b").ok).is_true()
	assert_int(_error("a + bc", parser).position).is_equal(5)


func test_depth_limit_for_parentheses() -> void:
	var ok_source: String = "(".repeat(50) + "1" + ")".repeat(50)
	assert_bool(ExprParser.new().parse(ok_source).ok).is_true()
	var deep: String = "(".repeat(51) + "1" + ")".repeat(51)
	var err: ExprSyntaxError = _error(deep)
	assert_int(err.position).is_equal(50)
	assert_str(err.message).contains("深すぎる")


func test_depth_limit_for_calls_and_unary_minus() -> void:
	var calls_ok: String = "f(".repeat(50) + "1" + ")".repeat(50)
	assert_bool(ExprParser.new().parse(calls_ok).ok).is_true()
	assert_str(_error("f(".repeat(51) + "1" + ")".repeat(51)).message).contains("深すぎる")
	assert_bool(ExprParser.new().parse("-".repeat(50) + "a").ok).is_true()
	assert_str(_error("-".repeat(51) + "a").message).contains("深すぎる")


func test_depth_limit_is_configurable() -> void:
	var parser := ExprParser.new(1000, 2)
	assert_bool(parser.parse("((1))").ok).is_true()
	assert_str(_error("(((1)))", parser).message).contains("深すぎる")


func test_flat_long_chain_is_not_deep() -> void:
	# 左結合の連なりは入れ子の深さに数えない。
	var source: String = "a" + " + a".repeat(200)
	assert_bool(ExprParser.new().parse(source).ok).is_true()


# --- Expression を使っていない ---

func test_does_not_use_godot_expression_class() -> void:
	var regex := RegEx.create_from_string("\\bExpression\\b")
	var dir := DirAccess.open(SRC_DIR)
	assert_object(dir).is_not_null()
	var checked: int = 0
	for file_name in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		checked += 1
		var text: String = FileAccess.get_file_as_string("%s/%s" % [SRC_DIR, file_name])
		for line in text.split("\n"):
			# コメントは除く。コードに Expression が出たら失敗にする。
			var code: String = line.split("#")[0]
			assert_object(regex.search(code)).is_null()
	assert_int(checked).is_greater(0)


# --- RefCounted で、Node に依存しない ---

func test_classes_are_ref_counted_not_nodes() -> void:
	for obj in [ExprParser.new(), ExprLexer.new(""), ExprNode.new(), ExprToken.new(), ExprSyntaxError.new(), ExprParseResult.new()]:
		assert_bool(obj is RefCounted).is_true()
		assert_bool(obj is Node).is_false()
