## 組み立て済みの式（ExprProgram）を、すべて float で評価する。
## 命令列を前から順に実行するだけで、再帰しない。長い式でも呼び出しの深さは増えない。
## 演算のたびに結果が有限かを検査し、NaN や無限大になった演算で止まる。
class_name ExprEvaluator
extends RefCounted


## program を評価する。stocks はストック名をキー、現在の値を値にした辞書である（読むだけで、変えない）。
## auxiliaries は補助変数名をキー、そのターンの値を値にした辞書で、補助変数を参照する式を評価するときに渡す。
## 値は名前で引くので、命令列の names と同じ名前の辞書を渡せば、評価の途中の値も名前で追える。
## 失敗のとき result.ok が false になり、result.position と result.message に原因の演算が入る。
static func evaluate(program: ExprProgram, stocks: Dictionary, auxiliaries: Dictionary = {}) -> ExprEvalResult:
	var result := ExprEvalResult.new()
	var stack: Array[float] = []
	# stack と同じ長さで、各値が「名前で参照した値」なら、その名前を持つ。計算で作った値は空文字である。
	var labels: Array[String] = []
	# CALL の引数と、その名前。命令ごとに作り直さないよう、ループの外に置く。
	var args: Array[float] = []
	var arg_labels: Array[String] = []
	for i in program.ops.size():
		var op: ExprProgram.Op = program.ops[i]
		var value: float = 0.0
		var left: float = 0.0
		var right: float = 0.0
		var left_label := ""
		var right_label := ""
		match op:
			ExprProgram.Op.PUSH_NUMBER:
				# 定数は組み立て時に値へ置き換えてあり、名前だけが names に残る。数値リテラルでは空である。
				stack.append(program.numbers[i])
				labels.append(program.names[i])
				continue
			ExprProgram.Op.PUSH_STOCK:
				stack.append(stocks[program.names[i]])
				labels.append(program.names[i])
				continue
			ExprProgram.Op.PUSH_AUXILIARY:
				stack.append(auxiliaries[program.names[i]])
				labels.append(program.names[i])
				continue
			ExprProgram.Op.NEG:
				value = -stack.pop_back()
				labels.pop_back()
				left = -value
			ExprProgram.Op.CALL:
				args.resize(program.arg_counts[i])
				arg_labels.resize(args.size())
				for k in range(args.size() - 1, -1, -1):
					args[k] = stack.pop_back()
					arg_labels[k] = labels.pop_back()
				# 下限が上限より大きい clamp は、黙って下限を返さず、実行時エラーにする。説明は失敗したときだけ作る。
				if program.names[i] == "clamp" and args[1] > args[2]:
					var clamp_description := _describe(program, i, left, right, left_label, right_label, args, arg_labels)
					return _fail(result, program.positions[i], "下限が上限より大きい：%s" % clamp_description)
				value = ExprFunctions.call_function(program.names[i], args)
			_:
				right = stack.pop_back()
				left = stack.pop_back()
				right_label = labels.pop_back()
				left_label = labels.pop_back()
				if (op == ExprProgram.Op.DIV or op == ExprProgram.Op.MOD) and right == 0.0:
					var what := "0 で割った" if op == ExprProgram.Op.DIV else "0 による剰余を求めた"
					var zero_description := _describe(program, i, left, right, left_label, right_label, args, arg_labels)
					return _fail(result, program.positions[i], "%s：%s" % [what, zero_description])
				value = _binary(op, left, right)
		if is_nan(value) or is_inf(value):
			var kind := "NaN" if is_nan(value) else "無限大"
			var description := _describe(program, i, left, right, left_label, right_label, args, arg_labels)
			return _fail(result, program.positions[i], "結果が %s になった：%s" % [kind, description])
		stack.append(value)
		labels.append("")
	result.ok = true
	result.value = stack[0]
	return result


## 原因の演算の説明を作る。失敗したときだけ呼ぶ。
## 除算・剰余・関数呼び出しは、名前で参照した値があれば「（名前 = 値、…）」を添える。
static func _describe(program: ExprProgram, i: int, left: float, right: float, left_label: String, right_label: String, args: Array[float], arg_labels: Array[String]) -> String:
	var op: ExprProgram.Op = program.ops[i]
	match op:
		ExprProgram.Op.NEG:
			return "-%s" % _fmt(left)
		ExprProgram.Op.CALL:
			var parts := PackedStringArray()
			for arg in args:
				parts.append(_fmt(arg))
			return "%s(%s)%s" % [program.names[i], ", ".join(parts), _named_values(arg_labels, args)]
	var text := "%s %s %s" % [_fmt(left), _symbol(op), _fmt(right)]
	if op == ExprProgram.Op.DIV or op == ExprProgram.Op.MOD:
		text += _named_values([left_label, right_label], [left, right])
	return text


static func _binary(op: ExprProgram.Op, left: float, right: float) -> float:
	match op:
		ExprProgram.Op.ADD:
			return left + right
		ExprProgram.Op.SUB:
			return left - right
		ExprProgram.Op.MUL:
			return left * right
		ExprProgram.Op.DIV:
			return left / right
		ExprProgram.Op.MOD:
			return fmod(left, right)
		ExprProgram.Op.LT:
			return 1.0 if left < right else 0.0
		ExprProgram.Op.LE:
			return 1.0 if left <= right else 0.0
		ExprProgram.Op.GT:
			return 1.0 if left > right else 0.0
		ExprProgram.Op.GE:
			return 1.0 if left >= right else 0.0
		ExprProgram.Op.EQ:
			return 1.0 if left == right else 0.0
		ExprProgram.Op.NE:
			return 1.0 if left != right else 0.0
	return 0.0


static func _symbol(op: ExprProgram.Op) -> String:
	match op:
		ExprProgram.Op.ADD:
			return "+"
		ExprProgram.Op.SUB:
			return "-"
		ExprProgram.Op.MUL:
			return "*"
		ExprProgram.Op.DIV:
			return "/"
		ExprProgram.Op.MOD:
			return "%"
		ExprProgram.Op.LT:
			return "<"
		ExprProgram.Op.LE:
			return "<="
		ExprProgram.Op.GT:
			return ">"
		ExprProgram.Op.GE:
			return ">="
		ExprProgram.Op.EQ:
			return "=="
		ExprProgram.Op.NE:
			return "!="
	return "?"


## 名前で参照した値を「（名前 = 値、名前 = 値）」の形にして返す。名前で参照した値が無ければ空文字を返す。
## 同じ名前は1回だけ出す。名前は ModelCheck.escape を通し、省略は escape の既定（32文字）に従う。
static func _named_values(labels: Array[String], values: Array[float]) -> String:
	var parts := PackedStringArray()
	var seen: Dictionary = {}
	for k in labels.size():
		var label: String = labels[k]
		if label.is_empty() or seen.has(label):
			continue
		seen[label] = true
		parts.append("%s = %s" % [ModelCheck.escape(label), _fmt(values[k])])
	if parts.is_empty():
		return ""
	return "（%s）" % "、".join(parts)


static func _fmt(value: float) -> String:
	return str(value)


static func _fail(result: ExprEvalResult, pos: int, message: String) -> ExprEvalResult:
	result.ok = false
	result.position = pos
	result.message = message
	return result
