## 入力を配列で与え、出力を配列に溜める TextPlayIO。テストや、入力を決め打ちした実行に使う。
class_name BufferTextPlayIO
extends TextPlayIO

## write_line で書かれた行。
var outputs: Array[String] = []

var _inputs: Array[String] = []
var _position: int = 0
var _eof: bool = false


## inputs は、1行ずつの入力である。使い切った後の read_line() が EOF になる。
func _init(p_inputs: Array[String] = []) -> void:
	_inputs = p_inputs


func read_line() -> String:
	if _position >= _inputs.size():
		_eof = true
		return ""
	var line := _inputs[_position]
	_position += 1
	return line


func is_eof() -> bool:
	return _eof


func write_line(text: String) -> void:
	outputs.append(text)
