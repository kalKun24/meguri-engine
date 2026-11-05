## ExprCompiler.compile() の結果である。成功なら program、失敗なら error に位置と原因が入る。
class_name ExprCompileResult
extends RefCounted

## 成功したか。
var ok: bool = false
## 成功したときの命令列。失敗のときは null である。
var program: ExprProgram = null
## 失敗したときのエラー。成功のときは null である。
var error: ExprSyntaxError = null
