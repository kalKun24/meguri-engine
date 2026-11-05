## ExprParser.parse() の結果である。成功なら root に構文木、失敗なら error に構文エラーが入る。
class_name ExprParseResult
extends RefCounted

## 成功したか。
var ok: bool = false
## 成功したときの構文木の根。失敗のときは null である。
var root: ExprNode = null
## 失敗したときの構文エラー。成功のときは null である。
var error: ExprSyntaxError = null
