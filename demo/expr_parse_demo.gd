## 式のパーサのデモ。正しい式は構文木を、誤った式は原因と文字位置つきのエラーを表示する。
## 実行：godot --headless --path . -s res://demo/expr_parse_demo.gd
## 式を指定する場合：godot --headless --path . -s res://demo/expr_parse_demo.gd -- "a + b" "f(1,"
extends SceneTree

const DEFAULT_EXPRESSIONS: Array[String] = [
	"population * 0.02 + 1",
	"2 + 3 * 4",
	"-a * b",
	"a - b - c",
	"max(a, b + 1) >= 10",
	"population * ",
	"a.b",
	"OS.get_name()",
	"(1 + 2",
	"",
	"name = \"x\"",
	"0 < x < 10",
	"(a < b) < c",
	"(0 < x) * (x < 10)",
	"人口 * 0.02",
	"1e3",
	"2x",
]


func _init() -> void:
	var expressions: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		expressions.append(arg)
	if expressions.is_empty():
		expressions = DEFAULT_EXPRESSIONS

	var parser := ExprParser.new()
	for source in expressions:
		print("式：\"%s\"" % source)
		var result: ExprParseResult = parser.parse(source)
		if result.ok:
			print("  構文木：%s" % result.root.to_text())
		else:
			print(result.error.format())
		print("")
	quit()
