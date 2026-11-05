## 実際の標準入出力を使う TextPlayIO。薄いラッパーであり、ロジックは持たない。
## OS.read_string_from_stdin() は、空行と EOF のどちらも空文字を返して区別できない。
## そのため、1 バイトずつ読んで改行までを1行にする。
class_name StdioTextPlayIO
extends TextPlayIO

## 1行として溜めるバイト数の上限。UTF-8 は1文字が最大4バイトである。
const MAX_LINE_BYTES: int = TextPlayIO.MAX_LINE_LENGTH * 4

var _eof: bool = false


## 標準入力から1行読む。EOF なら空文字を返し、is_eof() が true になる。
## 改行なしで入力が終わったときは、そこまでを1行として返し、次の呼び出しで EOF になる。
## 1行が MAX_LINE_BYTES を超えたら、超えた分は読み捨てて（改行までは読む）、メモリを使わない。
func read_line() -> String:
	var bytes := PackedByteArray()
	while true:
		var chunk := OS.read_buffer_from_stdin(1)
		if chunk.is_empty():
			if bytes.is_empty():
				_eof = true
			break
		if chunk[0] == 10:
			break
		if bytes.size() < MAX_LINE_BYTES:
			bytes.append(chunk[0])
	return bytes.get_string_from_utf8().strip_edges()


func is_eof() -> bool:
	return _eof


func write_line(text: String) -> void:
	print(text)
