## ストック・フロー・定数を持ち、1ターンずつ一斉に更新するシミュレーションのコア。
## Node に依存しない。定義の読み込みはこのクラスの外で行い、add_* 関数を呼ぶ。
class_name SimModel
extends RefCounted

## step() で、すべてのストックへの反映が終わった後に発火する。turn は増えた後のターン番号である。
signal turn_finished(turn: int)

## 直近の定義・取得で起きたエラーの説明。エラーが無ければ空である。
var last_error: String = ""

var _stocks: Dictionary = {}
var _flows: Array[Dictionary] = []
var _constants: Dictionary = {}
var _names: Dictionary = {}
var _turn: int = 0
var _validated: bool = true


## ストックを定義する。成功すると OK を返し、last_error を空にする。
## 名前が空、または ModelCheck.MAX_NAME_LENGTH（64 文字）を超える、初期値が NaN・無限大のときは ERR_INVALID_PARAMETER を返す。
## 定義の個数が ModelCheck.MAX_DEFINITIONS（1000 個。ストック・定数・フローの合計）に達していると ERR_OUT_OF_MEMORY を返す。
## 同名の定義がある、または式で使える関数（min など）と同名だと ERR_ALREADY_EXISTS を返す。失敗のとき、モデルは変わらない。
func add_stock(stock_name: String, initial_value: float) -> Error:
	var error := _check_new_name(stock_name, "ストック名")
	if error != OK:
		return error
	var problem := ModelCheck.check_finite(initial_value, "ストック「%s」の初期値" % ModelCheck.escape(stock_name))
	if not problem.is_empty():
		return _fail(ERR_INVALID_PARAMETER, problem)
	_names[stock_name] = true
	_stocks[stock_name] = initial_value
	_validated = false
	return _succeed()


## 定数を定義する。成功すると OK を返し、last_error を空にする。
## エラーの条件は add_stock と同じである（値が NaN・無限大のときも ERR_INVALID_PARAMETER）。
func add_constant(constant_name: String, value: float) -> Error:
	var error := _check_new_name(constant_name, "定数名")
	if error != OK:
		return error
	var problem := ModelCheck.check_finite(value, "定数「%s」の値" % ModelCheck.escape(constant_name))
	if not problem.is_empty():
		return _fail(ERR_INVALID_PARAMETER, problem)
	_names[constant_name] = true
	_constants[constant_name] = value
	_validated = false
	return _succeed()


## フローを定義する。source は流出元、sink は流入先のストック名で、片方は空文字でもよい。amount は毎ターン同じ量である。
## 量を式で書くときは add_flow_expr を使う。
## 成功すると OK を返し、last_error を空にする。
## ERR_INVALID_PARAMETER：フロー名が空または長すぎる、amount が NaN・無限大、存在しないストックを指す、流出元と流入先の両方が空。
## ERR_OUT_OF_MEMORY：定義の個数が上限（ModelCheck.MAX_DEFINITIONS）に達している。
## ERR_ALREADY_EXISTS：同名の定義がある、または式で使える関数と同名である。
func add_flow(flow_name: String, source: String, sink: String, amount: float) -> Error:
	var error := _check_new_flow(flow_name, source, sink)
	if error != OK:
		return error
	var problem := ModelCheck.check_finite(amount, "フロー「%s」の量" % ModelCheck.escape(flow_name))
	if not problem.is_empty():
		return _fail(ERR_INVALID_PARAMETER, problem)
	_names[flow_name] = true
	_flows.append({"name": flow_name, "source": source, "sink": sink, "amount": amount, "expression": "", "root": null, "program": null})
	_validated = false
	return _succeed()


## 量を式で書いたフローを定義する。引数の意味は add_flow と同じで、amount の代わりに式の文字列を渡す。
## 式からは、ストックと定数を名前で参照でき、許可された関数（ExprFunctions）を呼べる。更新前の値で評価される。
## ここでは構文だけを検証する。ERR_PARSE_ERROR：構文エラー（last_error に式の全文・位置・原因が入る）。
## 名前の解決と引数の数の検証は、validate() が最初の step() の前にまとめて行う。
## そのほかのエラーは add_flow と同じである。失敗のとき、モデルは変わらない。
func add_flow_expr(flow_name: String, source: String, sink: String, expression: String) -> Error:
	var error := _check_new_flow(flow_name, source, sink)
	if error != OK:
		return error
	var parsed: ExprParseResult = ExprParser.new().parse(expression)
	if not parsed.ok:
		return _fail(ERR_PARSE_ERROR, "フロー「%s」の式に構文エラーがある（位置 %d）：%s　式：%s" % [
			ModelCheck.escape(flow_name), parsed.error.position, ModelCheck.escape(parsed.error.message, 0), ModelCheck.escape(expression, 0)
		])
	_names[flow_name] = true
	_flows.append({"name": flow_name, "source": source, "sink": sink, "amount": 0.0, "expression": expression, "root": parsed.root, "program": null})
	_validated = false
	return _succeed()


## 式のフローを組み立てる。すべての式について、名前の解決（ストックと定数だけを参照できる）、許可関数の検査、引数の数の検査を行う。
## 成功すると OK を返し、last_error を空にする。誤りがあれば ERR_INVALID_DATA を返し、
## last_error に、フロー名・式の全文・文字位置・原因を入れる。
## step() は、組み立てが済んでいなければ最初に自分で呼ぶ。定義を足した後は、次の step() でもう一度行う。
func validate() -> Error:
	for flow: Dictionary in _flows:
		if flow["expression"] == "":
			continue
		var compiled: ExprCompileResult = ExprCompiler.compile(flow["root"], flow["expression"], _stocks, _constants)
		if not compiled.ok:
			flow["program"] = null
			return _fail(ERR_INVALID_DATA, "フロー「%s」の式に誤りがある（位置 %d）：%s　式：%s" % [
				ModelCheck.escape(flow["name"]), compiled.error.position, compiled.error.message, ModelCheck.escape(flow["expression"], 0)
			])
		flow["program"] = compiled.program
	_validated = true
	return _succeed()


## 1ターン進める。すべてのフローの量を更新前の値から求め、ストックに一斉に反映する。
## 成功すると OK を返し、last_error を空にして、turn_finished を発火する。
## 組み立てが済んでいなければ、先に validate() を行い、失敗ならそのエラーを返す。
## 実行時エラー（0 除算、式やストックの値が NaN・無限大になる）では FAILED を返し、last_error に
## ターン番号（これから進めるターン）、フロー名、式の全文、原因の演算を入れる。
## このとき、ストックは1つも更新せず、ターン番号も進めず、turn_finished も発火しない。
func step() -> Error:
	if not _validated:
		var validation := validate()
		if validation != OK:
			return validation
	var turn: int = _turn + 1
	var deltas: Dictionary = {}
	for flow: Dictionary in _flows:
		var amount: float = flow["amount"]
		var program: ExprProgram = flow["program"]
		if program != null:
			var evaluated: ExprEvalResult = ExprEvaluator.evaluate(program, _stocks)
			if not evaluated.ok:
				return _fail(FAILED, "ターン %d の実行時エラー：フロー「%s」の式の位置 %d で、%s　式：%s" % [
					turn, ModelCheck.escape(flow["name"]), evaluated.position, evaluated.message, ModelCheck.escape(flow["expression"], 0)
				])
			amount = evaluated.value
		if flow["source"] != "":
			deltas[flow["source"]] = deltas.get(flow["source"], 0.0) - amount
		if flow["sink"] != "":
			deltas[flow["sink"]] = deltas.get(flow["sink"], 0.0) + amount
	# 1つでも非有限になるストックがあれば、何も反映しない。
	var updated: Dictionary = {}
	for stock_name: String in deltas:
		var new_value: float = _stocks[stock_name] + deltas[stock_name]
		var problem := ModelCheck.check_finite(new_value, "ストック「%s」の更新後の値" % ModelCheck.escape(stock_name))
		if not problem.is_empty():
			return _fail(FAILED, "ターン %d の実行時エラー：%s" % [turn, problem])
		updated[stock_name] = new_value
	for stock_name: String in updated:
		_stocks[stock_name] = updated[stock_name]
	_turn = turn
	_succeed()
	turn_finished.emit(_turn)
	return OK


## ストックの現在の値を SimValue で返す。成功か失敗かは result.error で、値は result.value で受け取る。
## 未定義の名前は ERR_DOES_NOT_EXIST、空の名前は ERR_INVALID_PARAMETER になり、last_error に理由を入れる。
## 成功すると last_error を空にする。失敗のとき value は 0.0 で、NAN は返さない。
func get_stock(stock_name: String) -> SimValue:
	return _lookup(_stocks, stock_name, "ストック")


## ストックが定義されているかを返す。
func has_stock(stock_name: String) -> bool:
	return _stocks.has(stock_name)


## 定数の値を SimValue で返す。形とエラーは get_stock と同じである。
func get_constant(constant_name: String) -> SimValue:
	return _lookup(_constants, constant_name, "定数")


## 現在のターン番号を返す。初期状態は 0 である。
func get_turn() -> int:
	return _turn


## 定義済みのストック名を、定義順に返す。
func get_stock_names() -> Array[String]:
	var result: Array[String] = []
	for stock_name: String in _stocks:
		result.append(stock_name)
	return result


func _lookup(table: Dictionary, key: String, what: String) -> SimValue:
	if key.is_empty():
		_fail(ERR_INVALID_PARAMETER, "%s名が空である" % what)
		return SimValue.new(ERR_INVALID_PARAMETER)
	if not table.has(key):
		_fail(ERR_DOES_NOT_EXIST, "未定義の%s：%s" % [what, ModelCheck.escape(key)])
		return SimValue.new(ERR_DOES_NOT_EXIST)
	_succeed()
	return SimValue.new(OK, table[key])


## 新しい定義の名前を検査する。問題が無ければ OK を返す（last_error は変えない）。
func _check_new_name(name_value: String, what: String) -> Error:
	var problem := ModelCheck.check_name(name_value, what)
	if not problem.is_empty():
		return _fail(ERR_INVALID_PARAMETER, problem)
	if _names.size() >= ModelCheck.MAX_DEFINITIONS:
		return _fail(ERR_OUT_OF_MEMORY, "定義の個数が上限（%d）に達している" % ModelCheck.MAX_DEFINITIONS)
	if _names.has(name_value):
		return _fail(ERR_ALREADY_EXISTS, "同名の定義がある：%s" % ModelCheck.escape(name_value))
	if ExprFunctions.is_allowed(name_value):
		return _fail(ERR_ALREADY_EXISTS, "式で使える関数と同名である：%s" % ModelCheck.escape(name_value))
	return OK


## 新しいフローの名前と、流出元・流入先を検査する。問題が無ければ OK を返す。
func _check_new_flow(flow_name: String, source: String, sink: String) -> Error:
	var error := _check_new_name(flow_name, "フロー名")
	if error != OK:
		return error
	var escaped := ModelCheck.escape(flow_name)
	if source.is_empty() and sink.is_empty():
		return _fail(ERR_INVALID_PARAMETER, "流出元と流入先の両方が無いフロー：%s" % escaped)
	if not source.is_empty() and not _stocks.has(source):
		return _fail(ERR_INVALID_PARAMETER, "存在しない流出元のストック：%s" % ModelCheck.escape(source))
	if not sink.is_empty() and not _stocks.has(sink):
		return _fail(ERR_INVALID_PARAMETER, "存在しない流入先のストック：%s" % ModelCheck.escape(sink))
	return OK


func _succeed() -> Error:
	last_error = ""
	return OK


func _fail(code: Error, message: String) -> Error:
	last_error = message
	return code
