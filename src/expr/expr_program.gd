## 構文木を、評価できる形（後置記法の命令列）に組み立てたもの。ExprCompiler が作り、ExprEvaluator が評価する。
class_name ExprProgram
extends RefCounted

## 命令の種類。
enum Op {
	PUSH_NUMBER, PUSH_STOCK, NEG,
	ADD, SUB, MUL, DIV, MOD,
	LT, LE, GT, GE, EQ, NE,
	CALL,
	PUSH_AUXILIARY,
}

## 命令の列。
var ops: Array[Op] = []
## PUSH_NUMBER の値。定数は組み立て時に値へ置き換える。それ以外の命令では 0.0 である。
var numbers: PackedFloat64Array = PackedFloat64Array()
## PUSH_STOCK のストック名、PUSH_AUXILIARY の補助変数名、CALL の関数名。名前で値を引く命令は、この列の名前で引く。それ以外の命令では空である。
var names: Array[String] = []
## 命令のもとになった節の、式の中の位置。
var positions: PackedInt32Array = PackedInt32Array()
## CALL の引数の数。それ以外の命令では 0 である。
var arg_counts: PackedInt32Array = PackedInt32Array()


## 命令を1つ足す。
func emit(op: Op, pos: int, number: float = 0.0, op_name: String = "", arg_count: int = 0) -> void:
	ops.append(op)
	numbers.append(number)
	names.append(op_name)
	positions.append(pos)
	arg_counts.append(arg_count)
