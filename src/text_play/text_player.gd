## SimModel をテキストで動かす。Enter（または q 以外の入力）で1ターン進め、q または EOF で終わる。
## 入出力は TextPlayIO を通すので、標準入出力でもテスト用の入出力でも動く。
class_name TextPlayer
extends RefCounted

## 終了を表す入力。
const QUIT_INPUT: String = "q"

var _model: SimModel
var _io: TextPlayIO
var _labels: Dictionary


## labels は、ストック名から表示名への辞書である。無いストックは、名前をそのまま表示する。
func _init(model: SimModel, io: TextPlayIO, labels: Dictionary = {}) -> void:
	_model = model
	_io = io
	_labels = labels


## 現在の状態を1行で表示してから、入力を待ってターンを進める。q か EOF で OK を返して終わる。
## step() が失敗したら、そのエラーコードを返して終わる（理由は表示済み。ターンは進まないので、入力待ちには戻らず終わる）。
func run() -> Error:
	_io.write_line("Enter で次のターンに進む。q で終わる。")
	_io.write_line(format_line())
	while true:
		var input := _io.read_line()
		if _io.is_eof() or input.strip_edges() == QUIT_INPUT:
			return OK
		var code := _model.step()
		if code != OK:
			# get_stock() は成功すると last_error を空にするので、先に取っておく。
			var message := _model.last_error
			var attempted := _model.get_turn() + 1
			_io.write_line("ターン %d に進めようとしてエラーになった（%s）：%s" % [attempted, error_string(code), message])
			_io.write_line("ターンは進んでいない。いまの状態：%s" % format_line())
			return code
		_io.write_line(format_line())
	return OK


## 「ターン数: 人口=…, 食料=…」の形で、すべてのストックを1行にして返す。数値は小数第1位まで。
func format_line() -> String:
	var parts: Array[String] = []
	for stock_name in _model.get_stock_names():
		var label := String(_labels.get(stock_name, ModelCheck.escape(stock_name, 0)))
		var stock := _model.get_stock(stock_name)
		parts.append("%s=%s" % [label, ("%.1f" % stock.value) if stock.is_ok() else error_string(stock.error)])
	return "%d: %s" % [_model.get_turn(), ", ".join(parts)]
