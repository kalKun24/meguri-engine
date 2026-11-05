## 構文木を命令列（ExprProgram）に組み立てる。この段階で、名前の解決と、関数の許可・引数の数の検査を行う。
## 木の深さが深くても呼び出しの深さが増えないよう、再帰を使わず、明示的なスタックで木をたどる。
class_name ExprCompiler
extends RefCounted

const _BINARY_OPS: Dictionary = {
	"+": ExprProgram.Op.ADD,
	"-": ExprProgram.Op.SUB,
	"*": ExprProgram.Op.MUL,
	"/": ExprProgram.Op.DIV,
	"%": ExprProgram.Op.MOD,
	"<": ExprProgram.Op.LT,
	"<=": ExprProgram.Op.LE,
	">": ExprProgram.Op.GT,
	">=": ExprProgram.Op.GE,
	"==": ExprProgram.Op.EQ,
	"!=": ExprProgram.Op.NE,
}


## root を組み立てる。source は式の全文（エラーに入れる）、stocks はストック名をキーにした辞書、
## constants は定数名をキー、値を値にした辞書である。
## 失敗のとき result.error に、式の全文・位置・原因が入る。最初に見つけた誤りだけを返す。
static func compile(root: ExprNode, source: String, stocks: Dictionary, constants: Dictionary) -> ExprCompileResult:
	var result := ExprCompileResult.new()
	var program := ExprProgram.new()
	# 要素は [節, 子を処理済みか] である。
	var stack: Array = [[root, false]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: ExprNode = item[0]
		var children_done: bool = item[1]
		if children_done:
			_emit_operator(program, node)
			continue
		var problem := ""
		match node.kind:
			ExprNode.Kind.NUMBER:
				program.emit(ExprProgram.Op.PUSH_NUMBER, node.position, node.number)
			ExprNode.Kind.NAME:
				problem = _resolve_name(program, node, stocks, constants)
			ExprNode.Kind.UNARY, ExprNode.Kind.BINARY:
				stack.append([node, true])
				for i in range(node.children.size() - 1, -1, -1):
					stack.append([node.children[i], false])
			ExprNode.Kind.CALL:
				problem = _check_call(node)
				if problem.is_empty():
					stack.append([node, true])
					for i in range(node.children.size() - 1, -1, -1):
						stack.append([node.children[i], false])
		if not problem.is_empty():
			result.error = ExprSyntaxError.new(source, node.position, problem)
			return result
	result.ok = true
	result.program = program
	return result


static func _resolve_name(program: ExprProgram, node: ExprNode, stocks: Dictionary, constants: Dictionary) -> String:
	if ExprFunctions.is_allowed(node.name):
		return "'%s' は関数である。関数は () を付けて呼ぶ（例：%s）" % [node.name, _call_example(node.name)]
	if stocks.has(node.name):
		program.emit(ExprProgram.Op.PUSH_STOCK, node.position, 0.0, node.name)
		return ""
	if constants.has(node.name):
		program.emit(ExprProgram.Op.PUSH_NUMBER, node.position, constants[node.name])
		return ""
	return "未定義の名前：%s（式から参照できるのは、ストックと定数だけである）" % ModelCheck.escape(node.name)


static func _check_call(node: ExprNode) -> String:
	if not ExprFunctions.is_allowed(node.name):
		return "許可されていない関数：%s（使える関数は %s だけである）" % [
			ModelCheck.escape(node.name), ", ".join(ExprFunctions.names())
		]
	var expected: int = ExprFunctions.arity(node.name)
	if node.children.size() != expected:
		return "関数 %s の引数は %d 個である（実際は %d 個）" % [node.name, expected, node.children.size()]
	return ""


static func _call_example(function_name: String) -> String:
	var params: Array[String] = []
	for i in ExprFunctions.arity(function_name):
		params.append("x%d" % (i + 1))
	return "%s(%s)" % [function_name, ", ".join(params)]


# 子の命令を出し終えた後に、その節自身の命令を出す。
static func _emit_operator(program: ExprProgram, node: ExprNode) -> void:
	match node.kind:
		ExprNode.Kind.UNARY:
			program.emit(ExprProgram.Op.NEG, node.position)
		ExprNode.Kind.BINARY:
			program.emit(_BINARY_OPS[node.op], node.position)
		ExprNode.Kind.CALL:
			program.emit(ExprProgram.Op.CALL, node.position, 0.0, node.name, node.children.size())
