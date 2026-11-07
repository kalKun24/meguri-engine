## 組み立て済みの式（ExprProgram）を、すべて float で評価する。
## 命令列を前から順に実行するだけで、再帰しない。長い式でも呼び出しの深さは増えない。
## 演算のたびに結果が有限かを検査し、NaN や無限大になった演算で止まる。
class_name ExprEvaluator
extends RefCounted


## program を評価する。stocks はストック名をキー、現在の値を値にした辞書である（読むだけで、変えない）。
## 失敗のとき result.ok が false になり、result.position と result.message に原因の演算が入る。
static func evaluate(program: ExprProgram, stocks: Dictionary) -> ExprEvalResult:
	var result := ExprEvalResult.new()
	var stack: Array[float] = []
	for i in program.ops.size():
		var op: ExprProgram.Op = program.ops[i]
		var value: float = 0.0
		var description := ""
		match op:
			ExprProgram.Op.PUSH_NUMBER:
				stack.append(program.numbers[i])
				continue
			ExprProgram.Op.PUSH_STOCK:
				stack.append(stocks[program.names[i]])
				continue
			ExprProgram.Op.NEG:
				value = -stack.pop_back()
			ExprProgram.Op.CALL:
				var args: Array[float] = []
				args.resize(program.arg_counts[i])
				for k in range(args.size() - 1, -1, -1):
					args[k] = stack.pop_back()
				var parts := PackedStringArray()
				for arg in args:
					parts.append(_fmt(arg))
				description = "%s(%s)" % [program.names[i], ", ".join(parts)]
				# 下限が上限より大きい clamp は、黙って下限を返さず、実行時エラーにする。
				if program.names[i] == "clamp" and args[1] > args[2]:
					return _fail(result, program.positions[i], "下限が上限より大きい：%s" % description)
				value = ExprFunctions.call_function(program.names[i], args)
			_:
				var right: float = stack.pop_back()
				var left: float = stack.pop_back()
				var symbol := _symbol(op)
				description = "%s %s %s" % [_fmt(left), symbol, _fmt(right)]
				if (op == ExprProgram.Op.DIV or op == ExprProgram.Op.MOD) and right == 0.0:
					var what := "0 で割った" if op == ExprProgram.Op.DIV else "0 による剰余を求めた"
					return _fail(result, program.positions[i], "%s：%s" % [what, description])
				value = _binary(op, left, right)
		if is_nan(value) or is_inf(value):
			var kind := "NaN" if is_nan(value) else "無限大"
			return _fail(result, program.positions[i], "結果が %s になった：%s" % [kind, description])
		stack.append(value)
	result.ok = true
	result.value = stack[0]
	return result


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


static func _fmt(value: float) -> String:
	return str(value)


static func _fail(result: ExprEvalResult, pos: int, message: String) -> ExprEvalResult:
	result.ok = false
	result.position = pos
	result.message = message
	return result
