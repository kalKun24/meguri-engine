## 式の文字列を、1字句ずつ切り出す字句解析器である。
## Godot の Expression は使わない。
class_name ExprLexer
extends RefCounted

var _source: String = ""
var _pos: int = 0


## 解析する式を渡して初期化する。
func _init(source: String = "") -> void:
	_source = source
	_pos = 0


## 次の字句を返す。末尾では END を返し続ける。
## 解釈できない文字では、type が ERROR で text に原因の説明が入った字句を返す。
func next_token() -> ExprToken:
	while _pos < _source.length() and _is_space(_source[_pos]):
		_pos += 1
	var start: int = _pos
	if _pos >= _source.length():
		return ExprToken.new(ExprToken.Type.END, "", start)

	var c: String = _source[_pos]
	if _is_digit(c):
		return _read_number()
	if _is_name_start(c):
		return _read_name()

	var next_c: String = _source[_pos + 1] if _pos + 1 < _source.length() else ""
	match c:
		"+":
			return _simple(ExprToken.Type.PLUS, 1)
		"-":
			return _simple(ExprToken.Type.MINUS, 1)
		"*":
			return _simple(ExprToken.Type.STAR, 1)
		"/":
			return _simple(ExprToken.Type.SLASH, 1)
		"%":
			return _simple(ExprToken.Type.PERCENT, 1)
		"(":
			return _simple(ExprToken.Type.LPAREN, 1)
		")":
			return _simple(ExprToken.Type.RPAREN, 1)
		",":
			return _simple(ExprToken.Type.COMMA, 1)
		"<":
			if next_c == "=":
				return _simple(ExprToken.Type.LE, 2)
			return _simple(ExprToken.Type.LT, 1)
		">":
			if next_c == "=":
				return _simple(ExprToken.Type.GE, 2)
			return _simple(ExprToken.Type.GT, 1)
		"=":
			if next_c == "=":
				return _simple(ExprToken.Type.EQ, 2)
			return _error("'=' は使えない。代入は無い。等しいかを調べるときは '==' と書く")
		"!":
			if next_c == "=":
				return _simple(ExprToken.Type.NE, 2)
			return _error("'!' は使えない。論理演算子は無い。等しくないかを調べるときは '!=' と書く")
		".":
			return _error("'.' は使えない。プロパティ参照とメソッド呼び出しは書けない。小数は '0.5' のように数字から書く")
		"\"", "'":
			return _error("%s は使えない。文字列は書けない" % c)
		"[", "]", "{", "}":
			return _error("%s は使えない。配列・辞書・添字は書けない" % c)
		"&", "|":
			return _error("%s は使えない。論理演算子は、まだ扱わない" % c)
		"?", ":":
			return _error("%s は使えない。条件式は、まだ扱わない" % c)
		_:
			return _error("使えない文字 '%s' がある" % ModelCheck.escape_expression(c))


func _simple(type: ExprToken.Type, length: int) -> ExprToken:
	var token := ExprToken.new(type, _source.substr(_pos, length), _pos)
	_pos += length
	return token


func _error(message: String) -> ExprToken:
	var token := ExprToken.new(ExprToken.Type.ERROR, message, _pos)
	# 同じ文字で止まり続けないよう、1文字進める。
	_pos += 1
	return token


func _read_number() -> ExprToken:
	var start: int = _pos
	while _pos < _source.length() and _is_digit(_source[_pos]):
		_pos += 1
	# 小数点の次が数字のときだけ、小数として読む。
	if _pos + 1 < _source.length() and _source[_pos] == "." and _is_digit(_source[_pos + 1]):
		_pos += 1
		while _pos < _source.length() and _is_digit(_source[_pos]):
			_pos += 1
	var text: String = _source.substr(start, _pos - start)
	var value: float = text.to_float()
	if is_inf(value) or is_nan(value):
		# 400 桁の数のように、float に収まらないリテラルは拒否する（T1-1）。位置は数の先頭にする。
		_pos = start
		return _error("数値リテラルが大きすぎて、有限の数にならない（%d 桁）" % text.length())
	var token := ExprToken.new(ExprToken.Type.NUMBER, text, start)
	token.number = value
	return token


func _read_name() -> ExprToken:
	var start: int = _pos
	while _pos < _source.length() and (_is_name_start(_source[_pos]) or _is_digit(_source[_pos])):
		_pos += 1
	return ExprToken.new(ExprToken.Type.NAME, _source.substr(start, _pos - start), start)


func _is_space(c: String) -> bool:
	return c == " " or c == "\t" or c == "\n" or c == "\r"


func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


func _is_name_start(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"
