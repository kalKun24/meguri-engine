## 式の文字列を構文木に変換する、再帰下降の構文解析器である。
## Godot の Expression は使わない。評価はしない。
##
## 文法（優先順位は上が低い）：
## [codeblock]
## comparison := additive ( ("<" | "<=" | ">" | ">=" | "==" | "!=") additive )*   左結合
## additive   := term ( ("+" | "-") term )*                                         左結合
## term       := unary ( ("*" | "/" | "%") unary )*                                 左結合
## unary      := "-" unary | primary
## primary    := NUMBER | NAME | NAME "(" [ comparison ( "," comparison )* ] ")" | "(" comparison ")"
## [/codeblock]
class_name ExprParser
extends RefCounted

## 式の長さの既定の上限（文字数）。
const DEFAULT_MAX_LENGTH: int = 1000
## 入れ子の深さの既定の上限。括弧・関数の引数・単項 `-` の重なりを数える。
const DEFAULT_MAX_DEPTH: int = 50

## 式の長さの上限（文字数）。
var max_length: int = DEFAULT_MAX_LENGTH
## 入れ子の深さの上限。
var max_depth: int = DEFAULT_MAX_DEPTH

var _source: String = ""
var _lexer: ExprLexer = null
var _token: ExprToken = null
var _error: ExprSyntaxError = null
var _depth: int = 0


func _init(p_max_length: int = DEFAULT_MAX_LENGTH, p_max_depth: int = DEFAULT_MAX_DEPTH) -> void:
	max_length = p_max_length
	max_depth = p_max_depth


## 式を構文木に変換する。構文エラーでは result.ok が false になり、result.error に位置と原因が入る。
func parse(source: String) -> ExprParseResult:
	_source = source
	_error = null
	_depth = 0
	var result := ExprParseResult.new()

	if source.length() > max_length:
		_fail(max_length, "式が長すぎる（%d 文字）。上限は %d 文字である" % [source.length(), max_length])
		result.error = _error
		return result

	_lexer = ExprLexer.new(source)
	_advance()
	if _error == null and _token.type == ExprToken.Type.END:
		_fail(_token.position, "式が空である")
	var root: ExprNode = null
	if _error == null:
		root = _parse_comparison()
	if _error == null and _token.type != ExprToken.Type.END:
		_fail(_token.position, "%s が余計にある。式がここで終わっているか、演算子が足りない" % _describe(_token))

	if _error != null:
		result.error = _error
		return result
	result.ok = true
	result.root = root
	return result


func _advance() -> void:
	_token = _lexer.next_token()
	if _token.type == ExprToken.Type.ERROR:
		_fail(_token.position, _token.text)


# 最初のエラーだけを残す。常に null を返すので、`return _fail(...)` と書ける。
func _fail(pos: int, message: String) -> ExprNode:
	if _error == null:
		_error = ExprSyntaxError.new(_source, pos, message)
	return null


func _describe(token: ExprToken) -> String:
	if token.type == ExprToken.Type.END:
		return "式の終わり"
	return "'%s'" % token.text


func _enter() -> bool:
	_depth += 1
	if _depth > max_depth:
		_fail(_token.position, "入れ子が深すぎる。上限は %d 段である" % max_depth)
		return false
	return true


func _leave() -> void:
	_depth -= 1


func _is_comparison(type: ExprToken.Type) -> bool:
	return (
		type == ExprToken.Type.LT or type == ExprToken.Type.LE
		or type == ExprToken.Type.GT or type == ExprToken.Type.GE
		or type == ExprToken.Type.EQ or type == ExprToken.Type.NE
	)


func _parse_comparison() -> ExprNode:
	var left: ExprNode = _parse_additive()
	while _error == null and _is_comparison(_token.type):
		var op_token: ExprToken = _token
		_advance()
		var right: ExprNode = _parse_additive()
		if _error != null:
			return null
		left = ExprNode.make_binary(op_token.text, left, right, op_token.position)
	return left if _error == null else null


func _parse_additive() -> ExprNode:
	var left: ExprNode = _parse_term()
	while _error == null and (_token.type == ExprToken.Type.PLUS or _token.type == ExprToken.Type.MINUS):
		var op_token: ExprToken = _token
		_advance()
		var right: ExprNode = _parse_term()
		if _error != null:
			return null
		left = ExprNode.make_binary(op_token.text, left, right, op_token.position)
	return left if _error == null else null


func _parse_term() -> ExprNode:
	var left: ExprNode = _parse_unary()
	while _error == null and (
		_token.type == ExprToken.Type.STAR
		or _token.type == ExprToken.Type.SLASH
		or _token.type == ExprToken.Type.PERCENT
	):
		var op_token: ExprToken = _token
		_advance()
		var right: ExprNode = _parse_unary()
		if _error != null:
			return null
		left = ExprNode.make_binary(op_token.text, left, right, op_token.position)
	return left if _error == null else null


func _parse_unary() -> ExprNode:
	if _token.type != ExprToken.Type.MINUS:
		return _parse_primary()
	var op_token: ExprToken = _token
	if not _enter():
		return null
	_advance()
	var operand: ExprNode = _parse_unary()
	_leave()
	if _error != null:
		return null
	return ExprNode.make_unary("-", operand, op_token.position)


func _parse_primary() -> ExprNode:
	var token: ExprToken = _token
	match token.type:
		ExprToken.Type.NUMBER:
			_advance()
			return ExprNode.make_number(token.number, token.position) if _error == null else null
		ExprToken.Type.NAME:
			_advance()
			if _error != null:
				return null
			if _token.type == ExprToken.Type.LPAREN:
				return _parse_call(token)
			return ExprNode.make_name(token.text, token.position)
		ExprToken.Type.LPAREN:
			return _parse_group(token)
		ExprToken.Type.END:
			return _fail(token.position, "式がここで終わっている。値（数・名前・括弧・関数呼び出し）が必要である")
		_:
			return _fail(token.position, "%s は、ここには置けない。値（数・名前・括弧・関数呼び出し）が必要である" % _describe(token))


func _parse_group(open_token: ExprToken) -> ExprNode:
	if not _enter():
		return null
	_advance()
	var inner: ExprNode = _parse_comparison()
	_leave()
	if _error != null:
		return null
	if _token.type != ExprToken.Type.RPAREN:
		return _fail(_token.position, "括弧が閉じていない。位置 %d の '(' に対応する ')' が必要である" % open_token.position)
	_advance()
	return inner if _error == null else null


func _parse_call(name_token: ExprToken) -> ExprNode:
	var open_token: ExprToken = _token
	if not _enter():
		return null
	_advance()
	var args: Array[ExprNode] = []
	if _error == null and _token.type != ExprToken.Type.RPAREN:
		while true:
			var arg: ExprNode = _parse_comparison()
			if _error != null:
				break
			args.append(arg)
			if _token.type == ExprToken.Type.COMMA:
				_advance()
				if _error != null:
					break
				continue
			break
	_leave()
	if _error != null:
		return null
	if _token.type != ExprToken.Type.RPAREN:
		return _fail(
			_token.position,
			"関数呼び出しの括弧が閉じていない。位置 %d の '(' に対応する ')' が必要である（引数は ',' で区切る）" % open_token.position
		)
	_advance()
	if _error != null:
		return null
	return ExprNode.make_call(name_token.text, args, name_token.position)
