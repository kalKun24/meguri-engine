## ストック・フロー・定数を持ち、1ターンずつ一斉に更新するシミュレーションのコア。
## Node に依存しない。定義の読み込みはこのクラスの外で行い、add_* 関数を呼ぶ。
## ゲームが終わった後（is_ended() が true）は、モデルを変える関数（add_*・set_*・validate・step・advance_turn・apply_action）がすべて ERR_LOCKED を返し、状態を変えない。読むだけの関数（get_*・has_*・is_ended）は変わらず使える。
class_name SimModel
extends RefCounted

## step() で、すべてのストックへの反映が終わった後に発火する。turn は増えた後のターン番号である。
signal turn_finished(turn: int)

## apply_action() が成功し、効果をすべて反映した後に発火する。action_name は実行したアクションの名前である。
signal action_applied(action_name: String)

## advance_turn() が成功したターンの最後に、勝利か敗北の条件が成り立ってゲームが終わったとき、turn_finished の後に1回だけ発火する。
## outcome は GameResult.OUTCOME_VICTORY か OUTCOME_DEFEAT、condition_name は決め手の条件の名前、turn は終わったターン番号である。
signal game_ended(outcome: String, condition_name: String, turn: int)

## 直近の定義・取得で起きたエラーの説明。エラーが無ければ空である。
var last_error: String = ""

var _stocks: Dictionary = {}
var _flows: Array[Dictionary] = []
var _constants: Dictionary = {}
## 補助変数。定義順に {name, expression, root, program, dependencies} を持つ。program と dependencies は validate() が作る。
var _auxiliaries: Array[Dictionary] = []
## 補助変数を求める順（_auxiliaries の添字）。依存される側が先に来る。validate() が作る。
var _auxiliary_order: Array[int] = []
## ストック名 -> StockRange。範囲を設定したストックだけを持つ。
var _ranges: Dictionary = {}
var _names: Dictionary = {}
var _actions: Dictionary = {}
## 勝利・敗北の条件。定義順に {name, outcome, expression, root, program} を持つ。program は validate() が作る命令列である。
var _conditions: Array[Dictionary] = []
## 条件の式を組み立てた回数（ExprCompiler.compile の呼び出し数）。組み立てがターン数に比例しないことを、テストで確かめるために数える。
var _condition_build_count: int = 0
## 勝利と敗北が同じターンに成り立ったときに採る側。
var _priority: String = GameResult.OUTCOME_DEFEAT
var _result: GameResult = GameResult.new()
var _turn: int = 0
var _validated: bool = true
## 補助変数・フロー・条件の式の命令数の合計。定義した時点で、構文木の節の数から数える（組み立ての成否や program の null に依らない）。
var _total_ops: int = 0
var _seed: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## ストックを定義する。成功すると OK を返し、last_error を空にする。
## stock_range は値の範囲（StockRange）である。null なら制限が無い（下限が無いストックは負の値をとれ、上限が無いストックは際限なく増える）。
## 範囲は、ここで設定した後に変えられない。範囲を設定したストックは、step() と advance_turn() が更新後の値を範囲内に収める。
## 名前が空、または ModelCheck.MAX_NAME_LENGTH（64 文字）を超える、初期値が NaN・無限大のときは ERR_INVALID_PARAMETER を返す。
## 名前は式から参照されるので、式の名前と同じ規則（半角英数字と _ だけ。先頭は数字にしない。前後の空白も不可）を守る。違反も ERR_INVALID_PARAMETER である。
## 表示に使う名前（日本語など）は、モデルとは別に持つ。
## 範囲が、下限が上限より大きい、下限か上限が NaN・無限大、初期値が範囲外、扱いが未知のときも ERR_INVALID_PARAMETER を返す。
## 定義の個数が ModelCheck.MAX_DEFINITIONS（1000 個。ストック・定数・フローの合計）に達していると ERR_OUT_OF_MEMORY を返す。
## 同名の定義がある、または式で使える関数（min など）と同名だと ERR_ALREADY_EXISTS を返す。失敗のとき、モデルは変わらない。
## ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
func add_stock(stock_name: String, initial_value: float, stock_range: StockRange = null) -> Error:
	if _result.is_ended():
		return _fail_ended()
	var error := _check_new_name(stock_name, "ストック名", true)
	if error != OK:
		return error
	var label := "ストック「%s」" % ModelCheck.escape(stock_name)
	var problem := ModelCheck.check_finite(initial_value, "%sの初期値" % label)
	if not problem.is_empty():
		return _fail(ERR_INVALID_PARAMETER, problem)
	if stock_range != null:
		problem = _check_range(stock_range, initial_value, label)
		if not problem.is_empty():
			return _fail(ERR_INVALID_PARAMETER, problem)
		_ranges[stock_name] = stock_range
	_names[stock_name] = true
	_stocks[stock_name] = initial_value
	_validated = false
	return _succeed()


## ストックの範囲を返す。範囲を設定していないストック、未定義の名前では null を返す。last_error は変えない。
func get_stock_range(stock_name: String) -> StockRange:
	return _ranges.get(stock_name, null)


## 定数を定義する。成功すると OK を返し、last_error を空にする。
## エラーの条件は add_stock と同じである（値が NaN・無限大のときも ERR_INVALID_PARAMETER。名前の規則も同じ）。
## ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
func add_constant(constant_name: String, value: float) -> Error:
	if _result.is_ended():
		return _fail_ended()
	var error := _check_new_name(constant_name, "定数名", true)
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
## ERR_INVALID_PARAMETER：フロー名が空・長すぎる・名前の規則（add_stock を参照）に反する、amount が NaN・無限大、存在しないストックを指す、流出元と流入先の両方が空。
## ERR_OUT_OF_MEMORY：定義の個数が上限（ModelCheck.MAX_DEFINITIONS）に達している。
## ERR_ALREADY_EXISTS：同名の定義がある、または式で使える関数と同名である。
## ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
func add_flow(flow_name: String, source: String, sink: String, amount: float) -> Error:
	if _result.is_ended():
		return _fail_ended()
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


## 補助変数を定義する。「1人あたりの食料」のような途中の値に名前を付け、フローの式や他の補助変数の式から名前で参照するために使う。
## 値は、ターンの開始時（更新前）に、依存の順で1度だけ求める。定義の順は結果に影響しない。
## 式からは、ストック・定数・他の補助変数を名前で参照でき、許可された関数（ExprFunctions）を呼べる。フローの量は参照できない。
## 参照できる補助変数は、フローの式と補助変数の式だけである。アクションの式と終了条件の式は、ターンの合間や最後に評価するので参照できない。
## 名前は、ストック・定数・フロー・許可関数と同じ名前空間にあり、重複は ERR_ALREADY_EXISTS になる。名前の規則は add_stock と同じである。
## ここでは名前の検査と構文だけを検証する。ERR_PARSE_ERROR：構文エラー。ERR_INVALID_PARAMETER：名前の誤り。ERR_OUT_OF_MEMORY：定義の個数が上限に達している。
## 名前の解決、フローの量を参照していないこと、循環参照が無いことは、validate() が最初の step() の前にまとめて検査する。
## 成功すると OK を返し、last_error を空にする。失敗のとき、モデルは変わらない。
## ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
func add_auxiliary(auxiliary_name: String, expression: String) -> Error:
	if _result.is_ended():
		return _fail_ended()
	var error := _check_new_name(auxiliary_name, "補助変数名", true)
	if error != OK:
		return error
	var parsed: ExprParseResult = ExprParser.new().parse(expression)
	if not parsed.ok:
		return _fail(ERR_PARSE_ERROR, "補助変数「%s」の式に構文エラーがある（位置 %d）：%s 式：%s" % [
			ModelCheck.escape(auxiliary_name), parsed.error.position, ModelCheck.escape_reason(parsed.error.message), ModelCheck.escape_expression(expression)
		])
	var ops := ExprCompiler.count_ops(parsed.root)
	var ops_error := _check_total_ops(ops, "補助変数「%s」" % ModelCheck.escape(auxiliary_name))
	if ops_error != OK:
		return ops_error
	_names[auxiliary_name] = true
	_total_ops += ops
	_auxiliaries.append({"name": auxiliary_name, "expression": expression, "root": parsed.root, "program": null, "dependencies": [] as Array[int]})
	_validated = false
	return _succeed()


## 量を式で書いたフローを定義する。引数の意味は add_flow と同じで、amount の代わりに式の文字列を渡す。
## 式からは、ストック・定数・補助変数を名前で参照でき、許可された関数（ExprFunctions）を呼べる。更新前の値で評価される。
## ここでは構文だけを検証する。ERR_PARSE_ERROR：構文エラー（last_error に式の抜粋・位置・原因が入る）。
## 名前の解決と引数の数の検証は、validate() が最初の step() の前にまとめて行う。
## そのほかのエラーは add_flow と同じである。失敗のとき、モデルは変わらない。
## ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
func add_flow_expr(flow_name: String, source: String, sink: String, expression: String) -> Error:
	if _result.is_ended():
		return _fail_ended()
	var error := _check_new_flow(flow_name, source, sink)
	if error != OK:
		return error
	var parsed: ExprParseResult = ExprParser.new().parse(expression)
	if not parsed.ok:
		return _fail(ERR_PARSE_ERROR, "フロー「%s」の式に構文エラーがある（位置 %d）：%s 式：%s" % [
			ModelCheck.escape(flow_name), parsed.error.position, ModelCheck.escape_reason(parsed.error.message), ModelCheck.escape_expression(expression)
		])
	var ops := ExprCompiler.count_ops(parsed.root)
	var ops_error := _check_total_ops(ops, "フロー「%s」" % ModelCheck.escape(flow_name))
	if ops_error != OK:
		return ops_error
	_names[flow_name] = true
	_total_ops += ops
	_flows.append({"name": flow_name, "source": source, "sink": sink, "amount": 0.0, "expression": expression, "root": parsed.root, "program": null})
	_validated = false
	return _succeed()


## 補助変数と式のフローを組み立てる。すべての式について、名前の解決（ストック・定数・補助変数を参照できる。補助変数はフローを参照できない）、
## 許可関数の検査、引数の数の検査を行い、補助変数の循環参照を探して、補助変数を求める順を決める。
## 成功すると OK を返し、last_error を空にする。誤りがあれば ERR_INVALID_DATA を返し、
## last_error に、補助変数名かフロー名・式の抜粋（ModelCheck.MAX_EXPRESSION_EXCERPT_LENGTH 文字まで）・文字位置・原因を入れる。
## 循環参照のときは、循環の経路（例：a -> b -> a）を入れる。経路は、先頭から ModelCheck.MAX_CYCLE_PATH_LENGTH 個の名前までを示し、残りは「...」で省く。
## 循環の検出と順序の計算は、再帰を使わない。
## step() は、組み立てが済んでいなければ最初に自分で呼ぶ。定義を足した後は、次の step() でもう一度行う。
## ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
func validate() -> Error:
	if _result.is_ended():
		return _fail_ended()
	var auxiliary_names: Dictionary = {}
	for auxiliary: Dictionary in _auxiliaries:
		auxiliary_names[auxiliary["name"]] = true
	var flow_names: Dictionary = {}
	for flow: Dictionary in _flows:
		flow_names[flow["name"]] = true
	var auxiliary_error := _compile_auxiliaries(auxiliary_names, flow_names)
	if auxiliary_error != OK:
		return auxiliary_error
	for flow: Dictionary in _flows:
		if flow["expression"] == "":
			continue
		var compiled: ExprCompileResult = ExprCompiler.compile(flow["root"], flow["expression"], _stocks, _constants, auxiliary_names)
		if not compiled.ok:
			flow["program"] = null
			return _fail(ERR_INVALID_DATA, "フロー「%s」の式に誤りがある（位置 %d）：%s 式：%s" % [
				ModelCheck.escape(flow["name"]), compiled.error.position, ModelCheck.escape_reason(compiled.error.message), ModelCheck.escape_expression(flow["expression"])
			])
		flow["program"] = compiled.program
	var condition_error := _compile_conditions()
	if condition_error != OK:
		return condition_error
	_validated = true
	return _succeed()


## 勝利・敗北の条件の式を組み立てて、結果の命令列を条件の "program" に持たせる。_judge() は毎ターン、これを評価するだけである。
## 組み立ては validate() の中で行い、_validated が false の間（定義が増えた、定数が変わった）だけやり直す。補助変数とフローの式と同じ仕組みである。
## 条件の式からは、ストックと定数だけを参照できる（補助変数とフローの量は参照できない）。
## 誤りがあれば last_error を設定して ERR_INVALID_DATA を返す。
func _compile_conditions() -> Error:
	for condition: Dictionary in _conditions:
		_condition_build_count += 1
		var compiled: ExprCompileResult = ExprCompiler.compile(condition["root"], condition["expression"], _stocks, _constants)
		if not compiled.ok:
			condition["program"] = null
			return _fail(ERR_INVALID_DATA, "%sの式に誤りがある（位置 %d）：%s 式：%s" % [
				_condition_label(condition), compiled.error.position, ModelCheck.escape_reason(compiled.error.message), ModelCheck.escape_expression(condition["expression"])
			])
		condition["program"] = compiled.program
	return OK


## エラー文に使う条件の呼び名（例：勝利条件「name」）を返す。名前はエスケープする。
func _condition_label(condition: Dictionary) -> String:
	return "%s「%s」" % ["勝利条件" if condition["outcome"] == GameResult.OUTCOME_VICTORY else "敗北条件", ModelCheck.escape(condition["name"])]


## 補助変数の式を組み立て、依存の順を決める。誤りがあれば last_error を設定して ERR_INVALID_DATA を返す。
func _compile_auxiliaries(auxiliary_names: Dictionary, flow_names: Dictionary) -> Error:
	_auxiliary_order = []
	var index_of: Dictionary = {}
	for i in _auxiliaries.size():
		index_of[_auxiliaries[i]["name"]] = i
	for auxiliary: Dictionary in _auxiliaries:
		var compiled: ExprCompileResult = ExprCompiler.compile(auxiliary["root"], auxiliary["expression"], _stocks, _constants, auxiliary_names, flow_names)
		if not compiled.ok:
			auxiliary["program"] = null
			return _fail(ERR_INVALID_DATA, "補助変数「%s」の式に誤りがある（位置 %d）：%s 式：%s" % [
				ModelCheck.escape(auxiliary["name"]), compiled.error.position, ModelCheck.escape_reason(compiled.error.message), ModelCheck.escape_expression(auxiliary["expression"])
			])
		auxiliary["program"] = compiled.program
		# 依存先は、命令列の中の補助変数の参照から、重複なしで集める。
		var dependencies: Array[int] = []
		var seen: Dictionary = {}
		var program: ExprProgram = compiled.program
		for i in program.ops.size():
			if program.ops[i] == ExprProgram.Op.PUSH_AUXILIARY and not seen.has(program.names[i]):
				seen[program.names[i]] = true
				dependencies.append(index_of[program.names[i]])
		auxiliary["dependencies"] = dependencies
	return _order_auxiliaries()


## 補助変数を依存の順に並べて _auxiliary_order に入れる。循環があれば、経路を含む last_error を設定して ERR_INVALID_DATA を返す。
## 深さ優先の探索を、再帰ではなく明示的なスタックで行う。長さ1000の鎖でも呼び出しの深さは増えない。
func _order_auxiliaries() -> Error:
	# 0：未訪問、1：探索中（スタックの上）、2：完了。
	var state: PackedInt32Array = PackedInt32Array()
	state.resize(_auxiliaries.size())
	var order: Array[int] = []
	for start in _auxiliaries.size():
		if state[start] != 0:
			continue
		state[start] = 1
		var path: Array[int] = [start]
		var cursors: Array[int] = [0]
		while not path.is_empty():
			var top: int = path[path.size() - 1]
			var cursor: int = cursors[cursors.size() - 1]
			var dependencies: Array[int] = _auxiliaries[top]["dependencies"]
			if cursor < dependencies.size():
				cursors[cursors.size() - 1] = cursor + 1
				var next: int = dependencies[cursor]
				if state[next] == 1:
					return _fail(ERR_INVALID_DATA, "補助変数に循環参照がある：%s" % _format_cycle(path.slice(path.find(next)), next))
				if state[next] == 0:
					state[next] = 1
					path.append(next)
					cursors.append(0)
			else:
				state[top] = 2
				order.append(top)
				path.pop_back()
				cursors.pop_back()
	_auxiliary_order = order
	return OK


## 循環の経路を「a -> b -> a」の形にする。名前が ModelCheck.MAX_CYCLE_PATH_LENGTH を超えるときは、先頭からその数だけ示して「...」で省く。
func _format_cycle(cycle: Array[int], closing: int) -> String:
	var names: Array[String] = []
	for index in cycle:
		names.append(ModelCheck.escape(_auxiliaries[index]["name"]))
	names.append(ModelCheck.escape(_auxiliaries[closing]["name"]))
	if names.size() <= ModelCheck.MAX_CYCLE_PATH_LENGTH:
		return " -> ".join(names)
	return " -> ".join(names.slice(0, ModelCheck.MAX_CYCLE_PATH_LENGTH)) + " -> ..."


## ゲームの1ターンの単位。テキスト版（TextPlayer）と自動実行（AutoRunner）は、step() ではなくこの関数を呼ぶ。
## 順序は「流れ → （イベント。#34）→ 終了判定」で、終了判定は成功したターンの最後に1回だけ行う。
## 成功すると OK を返し、last_error を空にして、turn_finished を発火し、ゲームが終わったなら、その後に game_ended を発火する。
## ゲームが既に終わっているときは、何もせず ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
## 流れの失敗は step() と同じである。条件の式の評価に失敗したとき（0 除算、NaN・無限大など）は FAILED を返し、
## そのターン全体を取り消す。ストック・定数・ターン番号・組み立て済みの印・乱数の状態を戻し、シグナルを出さず、ゲームも終わらない。
## シグナルは、ターンの成功が確定した後にまとめて出す。
func advance_turn() -> Error:
	if _result.is_ended():
		return _fail_ended()
	var snapshot := _take_snapshot()
	var code := _apply_flows()
	if code != OK:
		return code
	# #34 のイベントは、ここ（流れの後、終了判定の前）に足す。失敗したら _restore_snapshot(snapshot) で取り消す。
	var verdict := _judge(_turn)
	if verdict["error"] != OK:
		_restore_snapshot(snapshot)
		return verdict["error"]
	var outcome: String = verdict["outcome"]
	var condition_name: String = verdict["condition_name"]
	if outcome != GameResult.OUTCOME_PENDING:
		# 終了を先に確定する。turn_finished の受け手が step() などを呼んでも、終わった後の扱いになる。
		_result = GameResult.new(outcome, condition_name, _turn)
	_succeed()
	turn_finished.emit(_turn)
	if outcome != GameResult.OUTCOME_PENDING:
		game_ended.emit(outcome, condition_name, _turn)
	return OK


## 乱数の種を決める。以後、get_rng() の乱数列は、同じ種なら同じになる。種を決めないときの種は 0 である。
## 乱数を使う処理（#34 から）は、グローバルの randi() や randf() ではなく、get_rng() を使う。
## 成功すると OK を返し、last_error を空にする。ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
func set_seed(seed_value: int) -> Error:
	if _result.is_ended():
		return _fail_ended()
	_seed = seed_value
	_rng.seed = seed_value
	return _succeed()


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
## step() は流れだけを進め、勝利・敗北の判定はしない（判定は advance_turn() が行う）。
## ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
func step() -> Error:
	if _result.is_ended():
		return _fail_ended()
	var code := _apply_flows()
	if code != OK:
		return code
	_succeed()
	turn_finished.emit(_turn)
	return OK


## 流れを1ターン分、ストックに反映してターン番号を進める。シグナルは出さず、last_error も空にしない。
## 失敗のときは、何も変えない。
func _apply_flows() -> Error:
	if not _validated:
		var validation := validate()
		if validation != OK:
			return validation
	var turn: int = _turn + 1
	var calculated := _calculate_auxiliaries(turn)
	if calculated["error"] != OK:
		return calculated["error"]
	var auxiliary_values: Dictionary = calculated["values"]
	var deltas: Dictionary = {}
	for flow: Dictionary in _flows:
		var amount: float = flow["amount"]
		var program: ExprProgram = flow["program"]
		if program != null:
			var evaluated: ExprEvalResult = ExprEvaluator.evaluate(program, _stocks, auxiliary_values)
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
		# 同じターンの流入と流出を合計した後で、範囲内に収める。削った量はどこにも流れずに消える。
		var stock_range: StockRange = _ranges.get(stock_name, null)
		if stock_range != null:
			new_value = stock_range.apply(new_value)
		var problem := ModelCheck.check_finite(new_value, "ストック「%s」の更新後の値" % ModelCheck.escape(stock_name))
		if not problem.is_empty():
			return _fail(FAILED, "ターン %d の実行時エラー：%s" % [turn, problem])
		updated[stock_name] = new_value
	for stock_name: String in updated:
		_stocks[stock_name] = updated[stock_name]
	_turn = turn
	return OK


## 補助変数を、ターンの開始時（更新前）のストックから、依存の順に1度だけ求める。ストックなどは変えない。
## 返す Dictionary は "error"（Error）と "values"（補助変数名をキーにした辞書）を持つ。
## 値が非有限になる、0 で割るなどで求められないときは、補助変数の名前を含む last_error を設定して FAILED を返す。
func _calculate_auxiliaries(turn: int) -> Dictionary:
	var values: Dictionary = {}
	for index in _auxiliary_order:
		var auxiliary: Dictionary = _auxiliaries[index]
		var evaluated: ExprEvalResult = ExprEvaluator.evaluate(auxiliary["program"], _stocks, values)
		if not evaluated.ok:
			return {"error": _fail(FAILED, "ターン %d の実行時エラー：補助変数「%s」の式の位置 %d で、%s 式：%s" % [
				turn, ModelCheck.escape(auxiliary["name"]), evaluated.position, ModelCheck.escape_reason(evaluated.message), ModelCheck.escape_expression(auxiliary["expression"])
			]), "values": {}}
		values[auxiliary["name"]] = evaluated.value
	return {"error": OK, "values": values}


## 終了判定。すべての条件を定義順に評価し（1つでも評価に失敗したら、そこで失敗を返す）、決め手を選ぶ。
## 返す Dictionary は "error"、"outcome"、"condition_name" を持つ。成り立った条件が無ければ outcome は OUTCOME_PENDING である。
## 勝利と敗北の両方が成り立ったときは、_priority の側を採る。同じ種類の中では、定義の順で最初のものを採る。
func _judge(turn: int) -> Dictionary:
	var verdict: Dictionary = {"error": OK, "outcome": GameResult.OUTCOME_PENDING, "condition_name": ""}
	var first_victory: String = ""
	var first_defeat: String = ""
	for condition: Dictionary in _conditions:
		var condition_name: String = condition["name"]
		var label := _condition_label(condition)
		# 組み立て済みの命令列を評価するだけである。組み立ては validate() が行う（advance_turn() は流れの前に済ませている）。
		var evaluated: ExprEvalResult = ExprEvaluator.evaluate(condition["program"], _stocks)
		if not evaluated.ok:
			verdict["error"] = _fail(FAILED, "ターン %d の終了判定でエラー（ターンは取り消した）：%sの式の位置 %d で、%s 式：%s" % [
				turn, label, evaluated.position, ModelCheck.escape_reason(evaluated.message), ModelCheck.escape_expression(condition["expression"])
			])
			return verdict
		var problem := ModelCheck.check_finite(evaluated.value, "ターン %d の終了判定：%sの値" % [turn, label])
		if not problem.is_empty():
			verdict["error"] = _fail(FAILED, "%s（ターンは取り消した）" % problem)
			return verdict
		if evaluated.value == 0.0:
			continue
		if condition["outcome"] == GameResult.OUTCOME_VICTORY:
			if first_victory.is_empty():
				first_victory = condition_name
		elif first_defeat.is_empty():
			first_defeat = condition_name
	var victory_wins: bool = not first_victory.is_empty() and (first_defeat.is_empty() or _priority == GameResult.OUTCOME_VICTORY)
	if victory_wins:
		verdict["outcome"] = GameResult.OUTCOME_VICTORY
		verdict["condition_name"] = first_victory
	elif not first_defeat.is_empty():
		verdict["outcome"] = GameResult.OUTCOME_DEFEAT
		verdict["condition_name"] = first_defeat
	return verdict


## ターンを始める前の状態を控える。ターン全体を取り消すときに _restore_snapshot() で戻す。
func _take_snapshot() -> Dictionary:
	return {
		"stocks": _stocks.duplicate(),
		"constants": _constants.duplicate(),
		"turn": _turn,
		"validated": _validated,
		"rng_state": _rng.state,
	}


func _restore_snapshot(snapshot: Dictionary) -> void:
	_stocks = snapshot["stocks"]
	_constants = snapshot["constants"]
	_turn = snapshot["turn"]
	_validated = snapshot["validated"]
	_rng.state = snapshot["rng_state"]


func _fail_ended() -> Error:
	return _fail(ERR_LOCKED, "ゲームは終了している")


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
## ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
func add_action(action_name: String, condition: String, effects: Array) -> Error:
	if _result.is_ended():
		return _fail_ended()
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
## ゲームが既に終わっているときは、ERR_LOCKED を返す（last_error は「ゲームは終了している」）。アクションの直後には、終了判定をしない。
func apply_action(action_name: String) -> Error:
	if _result.is_ended():
		return _fail_ended()
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


## 勝利の条件を定義する。expression は式の文字列で、advance_turn() が成功したターンの最後に評価し、0 以外なら成り立つ。
## 式からは、定義済みのストックと定数を参照できる。そのため、使うストックと定数を定義した後に定義する。
## 成功すると OK を返し、last_error を空にする。失敗のとき、モデルは変わらない。
## ERR_INVALID_PARAMETER：名前が空または長すぎる。ERR_PARSE_ERROR：式に構文エラーがある。ERR_INVALID_DATA：式が未定義の名前や許可されていない関数を使っている。
## ERR_OUT_OF_MEMORY：定義の個数が上限（ModelCheck.MAX_DEFINITIONS）に達している。
## ERR_ALREADY_EXISTS：同名の定義（ストック・定数・フロー・アクション・条件）がある、または式で使える関数と同名である。
## 条件の名前は、ストックなどと同じ名前空間にあり、個数の上限も共有する。
## ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。add_defeat_condition も同じである。
func add_victory_condition(condition_name: String, expression: String) -> Error:
	return _add_condition(condition_name, expression, GameResult.OUTCOME_VICTORY, "勝利条件")


## 敗北の条件を定義する。引数・エラーは add_victory_condition と同じである。
func add_defeat_condition(condition_name: String, expression: String) -> Error:
	return _add_condition(condition_name, expression, GameResult.OUTCOME_DEFEAT, "敗北条件")


## 勝利と敗北が同じターンに成り立ったとき、どちらを採るかを決める。outcome は GameResult.OUTCOME_VICTORY か OUTCOME_DEFEAT である。
## 決めないときは、敗北を採る。成功すると OK を返し、last_error を空にする。
## それ以外の値（OUTCOME_PENDING を含む）は ERR_INVALID_PARAMETER を返し、設定は変わらない。
## ゲームが既に終わっているときは、何も変えずに ERR_LOCKED を返す（last_error は「ゲームは終了している」）。
func set_simultaneous_priority(outcome: String) -> Error:
	if _result.is_ended():
		return _fail_ended()
	if outcome != GameResult.OUTCOME_VICTORY and outcome != GameResult.OUTCOME_DEFEAT:
		return _fail(ERR_INVALID_PARAMETER, "優先する結果は victory か defeat にする：%s" % ModelCheck.escape(outcome))
	_priority = outcome
	return _succeed()


## 勝利と敗北が同じターンに成り立ったときに採る側（GameResult.OUTCOME_VICTORY か OUTCOME_DEFEAT）を返す。
func get_simultaneous_priority() -> String:
	return _priority


## アクションが定義されているかを返す。
func has_action(action_name: String) -> bool:
	return _actions.has(action_name)


## 定義済みのアクション名を、定義順に返す。
func get_action_names() -> Array[String]:
	var result: Array[String] = []
	for action_name: String in _actions:
		result.append(action_name)
	return result


func _add_condition(condition_name: String, expression: String, outcome: String, what: String) -> Error:
	if _result.is_ended():
		return _fail_ended()
	var error := _check_new_name(condition_name, "%s名" % what)
	if error != OK:
		return error
	var parsed := _parse_checked(expression, "%s「%s」の式" % [what, ModelCheck.escape(condition_name)])
	if parsed["error"] != OK:
		return parsed["error"]
	var ops := ExprCompiler.count_ops(parsed["root"])
	var ops_error := _check_total_ops(ops, "%s「%s」" % [what, ModelCheck.escape(condition_name)])
	if ops_error != OK:
		return ops_error
	_names[condition_name] = true
	_total_ops += ops
	_conditions.append({"name": condition_name, "outcome": outcome, "expression": expression, "root": parsed["root"], "program": null})
	_validated = false
	return _succeed()


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


## ゲームの結果を GameResult で返す。種類（GameResult.OUTCOME_VICTORY・OUTCOME_DEFEAT・OUTCOME_PENDING）、決め手の条件の名前、終わったターン番号を持つ。
## まだ終わっていないときは、種類が OUTCOME_PENDING、名前が空、ターンが 0 である。呼ぶたびに写しを返す。last_error は変えない。
func get_result() -> GameResult:
	return GameResult.new(_result.outcome, _result.condition_name, _result.turn)


## ゲームが終わっているかを返す。終わった後は、step()・advance_turn()・apply_action() が ERR_LOCKED を返す。
func is_ended() -> bool:
	return _result.is_ended()


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
## identifier が true のときは、式の名前と同じ規則（半角英数字と _、先頭は数字にしない）も適用する。式から参照される定義（ストック・定数・フロー）に使う。
func _check_new_name(name_value: String, what: String, identifier: bool = false) -> Error:
	var problem := ModelCheck.check_identifier(name_value, what) if identifier else ModelCheck.check_name(name_value, what)
	if not problem.is_empty():
		return _fail(ERR_INVALID_PARAMETER, problem)
	if _names.size() >= ModelCheck.MAX_DEFINITIONS:
		return _fail(ERR_OUT_OF_MEMORY, "定義の個数が上限（%d）に達している" % ModelCheck.MAX_DEFINITIONS)
	if _names.has(name_value):
		return _fail(ERR_ALREADY_EXISTS, "同名の定義がある：%s" % ModelCheck.escape(name_value))
	if ExprFunctions.is_allowed(name_value):
		return _fail(ERR_ALREADY_EXISTS, "式で使える関数と同名である：%s" % ModelCheck.escape(name_value))
	return OK


## 式を足すと、モデル全体の命令数が ModelCheck.MAX_TOTAL_OPS を超えるかを検査する。超えるなら ERR_OUT_OF_MEMORY で、上限と実際の数（足した後の合計）を last_error に出す。
## 検査だけで、何も変えない。
func _check_total_ops(ops: int, label: String) -> Error:
	if _total_ops + ops > ModelCheck.MAX_TOTAL_OPS:
		return _fail(ERR_OUT_OF_MEMORY, "%sを足すと、モデル全体の命令数が上限を超える（上限 %d、実際 %d。この式は %d 命令）" % [
			label, ModelCheck.MAX_TOTAL_OPS, _total_ops + ops, ops
		])
	return OK


## 範囲の設定を検査する。問題が無ければ空文字を返す。
func _check_range(stock_range: StockRange, initial_value: float, label: String) -> String:
	if stock_range.get_overflow() != StockRange.Overflow.CLAMP:
		return "%sの範囲の扱いが未知である：%d" % [label, stock_range.get_overflow()]
	var has_lower: bool = stock_range.has_lower()
	var has_upper: bool = stock_range.has_upper()
	if has_lower:
		var problem := ModelCheck.check_finite(stock_range.get_lower(), "%sの下限" % label)
		if not problem.is_empty():
			return problem
	if has_upper:
		var problem := ModelCheck.check_finite(stock_range.get_upper(), "%sの上限" % label)
		if not problem.is_empty():
			return problem
	if has_lower and has_upper and stock_range.get_lower() > stock_range.get_upper():
		return "%sの下限が上限より大きい（下限 %s、上限 %s）" % [label, str(stock_range.get_lower()), str(stock_range.get_upper())]
	if has_lower and initial_value < stock_range.get_lower():
		return "%sの初期値が下限を下回る（下限 %s、初期値 %s）" % [label, str(stock_range.get_lower()), str(initial_value)]
	if has_upper and initial_value > stock_range.get_upper():
		return "%sの初期値が上限を上回る（上限 %s、初期値 %s）" % [label, str(stock_range.get_upper()), str(initial_value)]
	return ""


## 新しいフローの名前と、流出元・流入先を検査する。問題が無ければ OK を返す。
func _check_new_flow(flow_name: String, source: String, sink: String) -> Error:
	var error := _check_new_name(flow_name, "フロー名", true)
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
