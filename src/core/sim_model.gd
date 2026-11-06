## ストック・フロー・定数を持ち、1ターンずつ一斉に更新するシミュレーションのコア。
## Node に依存しない。定義の読み込みはこのクラスの外で行い、add_* 関数を呼ぶ。
class_name SimModel
extends RefCounted

## step() で、すべてのストックへの反映が終わった後に発火する。turn は増えた後のターン番号である。
signal turn_finished(turn: int)

## apply_action() が成功し、効果をすべて反映した後に発火する。action_name は実行したアクションの名前である。
signal action_applied(action_name: String)

## 直近の定義・取得で起きたエラーの説明。エラーが無ければ空である。
var last_error: String = ""

var _stocks: Dictionary = {}
var _flows: Array[Dictionary] = []
var _constants: Dictionary = {}
var _names: Dictionary = {}
var _actions: Dictionary = {}
var _turn: int = 0
var _validated: bool = true
var _seed: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


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
## ここでは構文だけを検証する。ERR_PARSE_ERROR：構文エラー（last_error に式の抜粋・位置・原因が入る）。
## 名前の解決と引数の数の検証は、validate() が最初の step() の前にまとめて行う。
## そのほかのエラーは add_flow と同じである。失敗のとき、モデルは変わらない。
func add_flow_expr(flow_name: String, source: String, sink: String, expression: String) -> Error:
	var error := _check_new_flow(flow_name, source, sink)
	if error != OK:
		return error
	var parsed: ExprParseResult = ExprParser.new().parse(expression)
	if not parsed.ok:
		return _fail(ERR_PARSE_ERROR, "フロー「%s」の式に構文エラーがある（位置 %d）：%s 式：%s" % [
			ModelCheck.escape(flow_name), parsed.error.position, ModelCheck.escape_reason(parsed.error.message), ModelCheck.escape_expression(expression)
		])
	_names[flow_name] = true
	_flows.append({"name": flow_name, "source": source, "sink": sink, "amount": 0.0, "expression": expression, "root": parsed.root, "program": null})
	_validated = false
	return _succeed()


## 式のフローを組み立てる。すべての式について、名前の解決（ストックと定数だけを参照できる）、許可関数の検査、引数の数の検査を行う。
## 成功すると OK を返し、last_error を空にする。誤りがあれば ERR_INVALID_DATA を返し、
## last_error に、フロー名・式の抜粋（ModelCheck.MAX_EXPRESSION_EXCERPT_LENGTH 文字まで）・文字位置・原因を入れる。
## step() は、組み立てが済んでいなければ最初に自分で呼ぶ。定義を足した後は、次の step() でもう一度行う。
func validate() -> Error:
	for flow: Dictionary in _flows:
		if flow["expression"] == "":
			continue
		var compiled: ExprCompileResult = ExprCompiler.compile(flow["root"], flow["expression"], _stocks, _constants)
		if not compiled.ok:
			flow["program"] = null
			return _fail(ERR_INVALID_DATA, "フロー「%s」の式に誤りがある（位置 %d）：%s 式：%s" % [
				ModelCheck.escape(flow["name"]), compiled.error.position, ModelCheck.escape_reason(compiled.error.message), ModelCheck.escape_expression(flow["expression"])
			])
		flow["program"] = compiled.program
	_validated = true
	return _succeed()


## ゲームの1ターンの単位。いまは step() を呼ぶだけで、戻り値と失敗時の扱いも step() と同じである。
## テキスト版（TextPlayer）と自動実行（AutoRunner）は、step() ではなくこの関数を呼ぶ。
## 終了判定（#35）とイベント（#34）は、この関数の中に足す。
func advance_turn() -> Error:
	return step()


## 乱数の種を決める。以後、get_rng() の乱数列は、同じ種なら同じになる。種を決めないときの種は 0 である。
## 乱数を使う処理（#34 から）は、グローバルの randi() や randf() ではなく、get_rng() を使う。
func set_seed(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value


## 直近の set_seed() で決めた種を返す。実行の記録に残すために使う。
func get_seed() -> int:
	return _seed


## このモデルの乱数の持ち主を返す。種は set_seed() で決める。
func get_rng() -> RandomNumberGenerator:
	return _rng


## 1ターン進める。すべてのフローの量を更新前の値から求め、ストックに一斉に反映する。
## 成功すると OK を返し、last_error を空にして、turn_finished を発火する。
## 組み立てが済んでいなければ、先に validate() を行い、失敗ならそのエラーを返す。
## 実行時エラー（0 除算、式やストックの値が NaN・無限大になる）では FAILED を返し、last_error に
## ターン番号（これから進めるターン）、フロー名、式の抜粋、原因の演算を入れる。
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
				return _fail(FAILED, "ターン %d の実行時エラー：フロー「%s」の式の位置 %d で、%s 式：%s" % [
					turn, ModelCheck.escape(flow["name"]), evaluated.position, ModelCheck.escape_reason(evaluated.message), ModelCheck.escape_expression(flow["expression"])
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


## プレイヤーのアクションを定義する。アクションは、実行条件の式と、効果の並びを持つ。
## condition は式の文字列で、0 以外に評価されたとき実行できる。常に実行できるなら "1" と書く。
## effects は「対象名 = 式」の形の文字列の Array である（例：["money = money - 50", "farmland = farmland + 1"]）。
## 対象は、定義済みのストックか定数である。式からは、定義済みのストックと定数を参照できる。
## そのため、アクションは、使うストックと定数を定義した後に定義する。
## 式の評価と反映は apply_action() が行う。ここでは構文と名前を検査する。
## 成功すると OK を返し、last_error を空にする。失敗のとき、モデルは変わらない。
## ERR_INVALID_PARAMETER：名前が空または長すぎる、effects が空、個数が ModelCheck.MAX_ACTION_EFFECTS を超える、
## 効果が文字列でない、「対象名 = 式」の形でない、対象が存在しない、同じ対象が2回出る。
## ERR_PARSE_ERROR：条件または効果の式に構文エラーがある（last_error に式の抜粋・位置・原因が入る）。
## ERR_INVALID_DATA：式が未定義の名前や許可されていない関数を使っている。
## ERR_OUT_OF_MEMORY：定義の個数が上限（ModelCheck.MAX_DEFINITIONS）に達している。
## ERR_ALREADY_EXISTS：同名の定義（ストック・定数・フロー・アクション）がある、または式で使える関数と同名である。
## アクション名は、ストックなどと同じ名前空間にある。
func add_action(action_name: String, condition: String, effects: Array) -> Error:
	var error := _check_new_name(action_name, "アクション名")
	if error != OK:
		return error
	var escaped := ModelCheck.escape(action_name)
	if effects.is_empty():
		return _fail(ERR_INVALID_PARAMETER, "アクション「%s」に効果が無い" % escaped)
	if effects.size() > ModelCheck.MAX_ACTION_EFFECTS:
		return _fail(ERR_INVALID_PARAMETER, "アクション「%s」の効果が多すぎる（上限 %d 個、実際 %d 個）" % [escaped, ModelCheck.MAX_ACTION_EFFECTS, effects.size()])
	var label := "アクション「%s」の条件" % escaped
	var parsed := _parse_checked(condition, label)
	if parsed["error"] != OK:
		return parsed["error"]
	var condition_root: ExprNode = parsed["root"]
	var effect_list: Array[Dictionary] = []
	var seen: Dictionary = {}
	for effect in effects:
		if not effect is String:
			return _fail(ERR_INVALID_PARAMETER, "アクション「%s」の効果が文字列でない" % escaped)
		var effect_text: String = effect
		var equals: int = effect_text.find("=")
		if equals < 0:
			return _fail(ERR_INVALID_PARAMETER, "アクション「%s」の効果が「対象名 = 式」の形でない：%s" % [escaped, ModelCheck.escape_expression(effect_text)])
		var target: String = effect_text.substr(0, equals).strip_edges()
		var expression: String = effect_text.substr(equals + 1)
		if not _stocks.has(target) and not _constants.has(target):
			return _fail(ERR_INVALID_PARAMETER, "アクション「%s」の効果の対象が存在しない（ストックか定数を指す）：%s" % [escaped, ModelCheck.escape(target)])
		if seen.has(target):
			return _fail(ERR_INVALID_PARAMETER, "アクション「%s」の効果で、同じ対象が2回出る：%s" % [escaped, ModelCheck.escape(target)])
		seen[target] = true
		parsed = _parse_checked(expression, "アクション「%s」の効果「%s」の式" % [escaped, ModelCheck.escape(target)])
		if parsed["error"] != OK:
			return parsed["error"]
		effect_list.append({"target": target, "expression": expression, "root": parsed["root"]})
	_names[action_name] = true
	_actions[action_name] = {"condition": condition, "condition_root": condition_root, "effects": effect_list}
	return _succeed()


## アクションを実行する。ターンの合間に呼ぶ。効果はすぐストックと定数に反映され、次の step() から効く。
## 1ターンに何回でも実行でき、効果の式を毎回、その時点の値で評価する（費用も毎回かかる）。
## 効果の式はすべて、実行前の値で評価する。反映は全体が成功するか、全体が取り消されるかのどちらかである。
## 成功すると OK を返し、last_error を空にして、action_applied を発火する。
## ERR_INVALID_PARAMETER：名前が空である。ERR_DOES_NOT_EXIST：未定義のアクションである。
## ERR_UNAVAILABLE：実行条件を満たさない（last_error に条件の抜粋が入る）。
## FAILED：条件や効果の式の評価で、0 除算や、NaN・無限大が生じた（last_error に原因が入る）。
## 失敗のとき、ストックも定数もターン番号も変わらず、action_applied も発火しない。
func apply_action(action_name: String) -> Error:
	if action_name.is_empty():
		return _fail(ERR_INVALID_PARAMETER, "アクション名が空である")
	if not _actions.has(action_name):
		return _fail(ERR_DOES_NOT_EXIST, "未定義のアクション：%s" % ModelCheck.escape(action_name))
	var action: Dictionary = _actions[action_name]
	var escaped := ModelCheck.escape(action_name)
	var evaluated := _evaluate_now(action["condition_root"], action["condition"])
	if not evaluated.ok:
		return _fail(FAILED, "アクション「%s」の条件を評価できない（位置 %d）：%s 条件：%s" % [
			escaped, evaluated.position, ModelCheck.escape_reason(evaluated.message), ModelCheck.escape_expression(action["condition"])
		])
	if evaluated.value == 0.0:
		return _fail(ERR_UNAVAILABLE, "アクション「%s」を実行できない。条件を満たさない：%s" % [escaped, ModelCheck.escape_expression(action["condition"])])
	# 先にすべての効果を評価し、1つでも失敗したら何も反映しない。
	var new_values: Dictionary = {}
	for effect: Dictionary in action["effects"]:
		evaluated = _evaluate_now(effect["root"], effect["expression"])
		var target: String = effect["target"]
		if not evaluated.ok:
			return _fail(FAILED, "アクション「%s」の効果「%s」を評価できない（位置 %d）：%s 式：%s" % [
				escaped, ModelCheck.escape(target), evaluated.position, ModelCheck.escape_reason(evaluated.message), ModelCheck.escape_expression(effect["expression"])
			])
		var problem := ModelCheck.check_finite(evaluated.value, "アクション「%s」の効果「%s」の値" % [escaped, ModelCheck.escape(target)])
		if not problem.is_empty():
			return _fail(FAILED, problem)
		new_values[target] = evaluated.value
	for target: String in new_values:
		if _stocks.has(target):
			_stocks[target] = new_values[target]
		else:
			_constants[target] = new_values[target]
			# 式は定数の値を組み立て時に取り込むので、次の step() で組み立て直す。
			_validated = false
	_succeed()
	action_applied.emit(action_name)
	return OK


## アクションが定義されているかを返す。
func has_action(action_name: String) -> bool:
	return _actions.has(action_name)


## 定義済みのアクション名を、定義順に返す。
func get_action_names() -> Array[String]:
	var result: Array[String] = []
	for action_name: String in _actions:
		result.append(action_name)
	return result


## 式をパースして名前を検査する。{"error": Error, "root": ExprNode} を返す。失敗なら last_error を設定済みで、root は null である。
func _parse_checked(expression: String, label: String) -> Dictionary:
	var parsed: ExprParseResult = ExprParser.new().parse(expression)
	if not parsed.ok:
		return {"error": _fail(ERR_PARSE_ERROR, "%sに構文エラーがある（位置 %d）：%s 式：%s" % [
			label, parsed.error.position, ModelCheck.escape_reason(parsed.error.message), ModelCheck.escape_expression(expression)
		]), "root": null}
	# 名前の解決と関数の検査を、定義時の状態で行う。
	var compiled: ExprCompileResult = ExprCompiler.compile(parsed.root, expression, _stocks, _constants)
	if not compiled.ok:
		return {"error": _fail(ERR_INVALID_DATA, "%sに誤りがある（位置 %d）：%s 式：%s" % [
			label, compiled.error.position, ModelCheck.escape_reason(compiled.error.message), ModelCheck.escape_expression(expression)
		]), "root": null}
	return {"error": OK, "root": parsed.root}


## 構文木を、現在のストックと定数の値で組み立てて評価する。
func _evaluate_now(root: ExprNode, expression: String) -> ExprEvalResult:
	var compiled: ExprCompileResult = ExprCompiler.compile(root, expression, _stocks, _constants)
	if not compiled.ok:
		var failed := ExprEvalResult.new()
		failed.position = compiled.error.position
		failed.message = compiled.error.message
		return failed
	return ExprEvaluator.evaluate(compiled.program, _stocks)


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
	last_error = ModelCheck.limit_last_error(message)
	return code
