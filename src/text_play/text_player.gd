## SimModel をテキストで動かす。
## 入力は1行ずつ読む。Enter（空行）で1ターン進め、番号か名前でアクションを実行し、q または EOF で終わる。
## 入出力は TextPlayIO を通すので、標準入出力でもテスト用の入出力でも動く。
## シミュレーションのロジックは持たず、SimModel の公開関数を呼ぶだけである。
class_name TextPlayer
extends RefCounted

## 終了を表す入力。
const QUIT_INPUT: String = "q"

## 番号で選ぶときに受け付ける桁数の上限。
const MAX_NUMBER_DIGITS: int = 6

var _model: SimModel
var _io: TextPlayIO
var _labels: Dictionary
var _action_labels: Dictionary
var _param_labels: Dictionary


## labels は、ストック名から表示名への辞書である。無いストックは、名前をそのまま表示する。
## action_labels は、アクション名から表示名への辞書である。
## param_labels は、アクションの実行で変わる値（定数やストック）の名前から表示名への辞書である。実行の前後の値を表示する。
## 表示名は、不可視文字をエスケープして出す。
func _init(model: SimModel, io: TextPlayIO, labels: Dictionary = {}, action_labels: Dictionary = {}, param_labels: Dictionary = {}) -> void:
	_model = model
	_io = io
	_labels = labels
	_action_labels = action_labels
	_param_labels = param_labels


## 現在の状態を1行で表示してから、入力を待つ。
## 空行ならターンを進める。番号か名前ならアクションを実行する（ターンは進まない）。q か EOF で OK を返して終わる。
## 分からない入力と、実行に失敗したアクションは、理由を表示して入力待ちに戻る（ターンは進まない）。
## step() が失敗したら、そのエラーコードを返して終わる（理由は表示済み。ターンは進まないので、入力待ちには戻らず終わる）。
func run() -> Error:
	_io.write_line("Enter で次のターンに進む。q で終わる。")
	_write_menu()
	_io.write_line(format_line())
	while true:
		var input := _read_input()
		if _io.is_eof() or input == QUIT_INPUT:
			return OK
		if input.is_empty():
			var code := _model.step()
			if code != OK:
				# get_stock() は成功すると last_error を空にするので、先に取っておく。
				var message := _model.last_error
				var attempted := _model.get_turn() + 1
				_io.write_line("ターン %d に進めようとしてエラーになった（%s）：%s" % [attempted, error_string(code), message])
				_io.write_line("ターンは進んでいない。いまの状態：%s" % format_line())
				return code
			_io.write_line(format_line())
			continue
		var action_name := resolve_action(input)
		if action_name.is_empty():
			_io.write_line("分からない入力：「%s」" % ModelCheck.escape(input))
			_write_menu()
			continue
		_apply(action_name)
	return OK


## 入力（番号かアクション名か表示名）から、アクション名を返す。当てはまらなければ空文字を返す。
## 番号は1から数え、get_action_names() の順である。
func resolve_action(input: String) -> String:
	var names := _model.get_action_names()
	if _is_number(input):
		var index := input.to_int()
		return names[index - 1] if index >= 1 and index <= names.size() else ""
	for action_name in names:
		if input == action_name or input == String(_action_labels.get(action_name, "")):
			return action_name
	return ""


## 「ターン数: 人口=…, 食料=…」の形で、すべてのストックを1行にして返す。数値は小数第1位まで。
func format_line() -> String:
	var parts: Array[String] = []
	for stock_name in _model.get_stock_names():
		var stock := _model.get_stock(stock_name)
		parts.append("%s=%s" % [_label(_labels, stock_name), ("%.1f" % stock.value) if stock.is_ok() else error_string(stock.error)])
	return "%d: %s" % [_model.get_turn(), ", ".join(parts)]


# 入力を1行読む。長さの上限（TextPlayIO.MAX_LINE_LENGTH）を超えた分は切り詰める。前後の空白は除く。
func _read_input() -> String:
	return _io.read_line().substr(0, TextPlayIO.MAX_LINE_LENGTH).strip_edges()


func _is_number(input: String) -> bool:
	if input.is_empty() or input.length() > MAX_NUMBER_DIGITS:
		return false
	for i in input.length():
		var code := input.unicode_at(i)
		if code < 0x30 or code > 0x39:
			return false
	return true


func _label(table: Dictionary, key_name: String) -> String:
	return ModelCheck.escape(String(table.get(key_name, key_name)), 0)


func _write_menu() -> void:
	var names := _model.get_action_names()
	if names.is_empty():
		return
	_io.write_line("アクション（番号か名前を入力する）：")
	for i in names.size():
		_io.write_line("  %d: %s" % [i + 1, _label(_action_labels, names[i])])


func _param_values() -> Dictionary:
	var values: Dictionary = {}
	for param_name: String in _param_labels:
		var value := _model.get_stock(param_name) if _model.has_stock(param_name) else _model.get_constant(param_name)
		values[param_name] = ("%.2f" % value.value) if value.is_ok() else error_string(value.error)
	return values


func _apply(action_name: String) -> void:
	var label := _label(_action_labels, action_name)
	var before := _param_values()
	var code := _model.apply_action(action_name)
	# get_stock() は成功すると last_error を空にするので、先に取っておく。
	var message := ModelCheck.escape(_model.last_error, 0, false)
	if code != OK:
		_io.write_line("「%s」を実行できない（%s）：%s" % [label, error_string(code), message])
		_io.write_line("ターンは進んでいない。いまの状態：%s" % format_line())
		return
	var after := _param_values()
	var changes: Array[String] = []
	for param_name: String in _param_labels:
		if before[param_name] == after[param_name]:
			continue
		changes.append("%s %s → %s" % [_label(_param_labels, param_name), before[param_name], after[param_name]])
	_io.write_line("「%s」を実行した。%s" % [label, "（" + "、".join(changes) + "）" if not changes.is_empty() else ""])
	_io.write_line("ターンは進んでいない。いまの状態：%s" % format_line())
