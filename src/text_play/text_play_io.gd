## テキスト版の入出力の口。標準入出力の代わりに、テスト用の入出力などへ差し替えられる。
## このクラス自体は何も読まず、何も書かない。
class_name TextPlayIO
extends RefCounted


## 1行読んで返す。末尾の改行は含まない。入力が終わっていれば空文字を返し、is_eof() が true になる。
func read_line() -> String:
	return ""


## 入力が終わった（EOF）かを返す。read_line() が入力を読み切った後で true になる。
func is_eof() -> bool:
	return true


## 1行書く。末尾の改行は呼び出し側が付ける必要はない。
func write_line(_text: String) -> void:
	pass
