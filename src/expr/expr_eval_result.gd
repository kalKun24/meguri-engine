## ExprEvaluator.evaluate() の結果である。成功なら value、失敗なら position と message が入る。
class_name ExprEvalResult
extends RefCounted

## 成功したか。
var ok: bool = false
## 成功したときの値。有限である。失敗のときは 0.0 であり、意味を持たない。
var value: float = 0.0
## 失敗したときの、原因の演算の式の中の位置。
var position: int = 0
## 失敗したときの、原因の演算の説明（例：「0 で割った：1.0 / 0.0」）。
var message: String = ""
