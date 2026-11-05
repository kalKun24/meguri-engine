## 見えない文字のエスケープのデモ。エラー文で、見えない文字が \u{XXXX} の形になることを示す。
## 実行：godot --headless --path . -s res://demo/escape_demo.gd
## 不可視文字は、文字コードから char() で作る（ソースに生の文字を書かない）。
extends SceneTree


func _init() -> void:
	var rlo: String = char(0x202E)
	var zwsp: String = char(0x200B)
	var shy: String = char(0x00AD)
	var vs16: String = char(0xFE0F)
	var tag: String = char(0xE0041)

	print("== 1. ストック名・定数名・フロー名 ==")
	var model := SimModel.new()
	model.add_stock("food", 10.0)
	_show("add_stock（NaN）", model.add_stock("pop" + rlo + "x", NAN), model)
	_show("add_constant（無限大）", model.add_constant("k" + zwsp + "k", INF), model)
	_show("add_stock（U+200B だけ）", model.add_stock(zwsp, 1.0), model)
	_show("add_stock（空白だけ）", model.add_stock("   ", 1.0), model)
	_show("add_flow（流出元が無い）", model.add_flow("f", "no" + shy + "pe", "food", 1.0), model)
	_show("add_flow（流入先が無い）", model.add_flow("f", "food", "x" + vs16 + "y", 1.0), model)
	_show("add_stock（タグ文字）", model.add_stock("t" + tag + "t", NAN), model)
	_show("get_stock（未定義）", model.get_stock("a" + rlo + "b").error, model)

	print("")
	print("== 2. 式（add_flow_expr と validate） ==")
	var expr_model := SimModel.new()
	expr_model.add_stock("food", 10.0)
	_show("add_flow_expr（構文エラー）", expr_model.add_flow_expr("f" + rlo, "", "food", "1 + " + zwsp + "2"), expr_model)
	_show("add_flow_expr（名前に不可視文字）", expr_model.add_flow_expr("g" + rlo, "", "food", "missing"), expr_model)
	_show("validate（未定義の名前）", expr_model.validate(), expr_model)

	print("")
	print("== 3. ExprParser の構文エラー（^ の位置） ==")
	var sources: Array[String] = [
		"1" + char(0x09) + "$",
		"a" + rlo + "b",
		"x" + shy + zwsp + " + #",
		"a\\b",
	]
	var parser := ExprParser.new()
	for source in sources:
		var result: ExprParseResult = parser.parse(source)
		if result.ok:
			print("(構文エラーにならなかった)")
		else:
			print(result.error.format())
		print("")
	quit()


func _show(label: String, code: Error, model: SimModel) -> void:
	print("%s -> %s\n  %s" % [label, error_string(code), model.last_error])
