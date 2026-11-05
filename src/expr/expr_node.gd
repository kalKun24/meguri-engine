## 式の構文木の1つの節である。
##
## 種類ごとに使う項目は次のとおり。
## - NUMBER：number
## - NAME：name
## - UNARY：op（"-"）、children[0]
## - BINARY：op（"+ - * / %" と比較演算子）、children[0] が左、children[1] が右
## - CALL：name（関数名）、children が引数（0 個以上）
class_name ExprNode
extends RefCounted

## 節の種類。
enum Kind { NUMBER, NAME, UNARY, BINARY, CALL }

## 節の種類。
var kind: Kind = Kind.NUMBER
## NUMBER の値。
var number: float = 0.0
## NAME の名前、または CALL の関数名。
var name: String = ""
## UNARY と BINARY の演算子。
var op: String = ""
## 子の節。
var children: Array[ExprNode] = []
## 式の中の開始位置（0 始まりの文字位置）。
var position: int = 0


## 数値リテラルの節を作る。
static func make_number(value: float, pos: int) -> ExprNode:
	var node := ExprNode.new()
	node.kind = Kind.NUMBER
	node.number = value
	node.position = pos
	return node


## 名前の節を作る。
static func make_name(ident: String, pos: int) -> ExprNode:
	var node := ExprNode.new()
	node.kind = Kind.NAME
	node.name = ident
	node.position = pos
	return node


## 単項演算の節を作る。
static func make_unary(operator: String, operand: ExprNode, pos: int) -> ExprNode:
	var node := ExprNode.new()
	node.kind = Kind.UNARY
	node.op = operator
	node.children = [operand]
	node.position = pos
	return node


## 二項演算（比較を含む）の節を作る。
static func make_binary(operator: String, left: ExprNode, right: ExprNode, pos: int) -> ExprNode:
	var node := ExprNode.new()
	node.kind = Kind.BINARY
	node.op = operator
	node.children = [left, right]
	node.position = pos
	return node


## 関数呼び出しの節を作る。
static func make_call(function_name: String, args: Array[ExprNode], pos: int) -> ExprNode:
	var node := ExprNode.new()
	node.kind = Kind.CALL
	node.name = function_name
	node.children = args
	node.position = pos
	return node


## 構文木を S 式の文字列にする。例：`population * 0.02 + 1` は `(+ (* population 0.02) 1.0)`。
## 単項 `-` は `(neg x)`、関数呼び出しは `(call f a b)` と書く。
func to_text() -> String:
	match kind:
		Kind.NUMBER:
			return str(number)
		Kind.NAME:
			return name
		Kind.UNARY:
			return "(neg %s)" % children[0].to_text()
		Kind.BINARY:
			return "(%s %s %s)" % [op, children[0].to_text(), children[1].to_text()]
		Kind.CALL:
			var parts: Array[String] = ["call", name]
			for child in children:
				parts.append(child.to_text())
			return "(%s)" % " ".join(parts)
	return ""
