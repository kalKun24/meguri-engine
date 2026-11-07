## ストックの値の範囲（下限・上限）と、範囲を超えるときの扱い。作った後は変えられない。
## 下限・上限は省略でき、省略は「設定しない」で表す（無限大の値では表さない）。
## 値の検査（下限 <= 上限、非有限でないこと、初期値が範囲内であること）は、SimModel.add_stock が行う。
class_name StockRange
extends RefCounted

## 範囲を超えるときの扱い。#8（流出を減らす）と #12（流入を減らす）は、ここに値を足す。
enum Overflow {
	## 同じターンの流入と流出を合計して更新した後の値を、範囲内に収める。削った量はどこにも流れずに消える。
	CLAMP,
}

var _has_lower: bool = false
var _lower: float = 0.0
var _has_upper: bool = false
var _upper: float = 0.0
var _overflow: Overflow = Overflow.CLAMP


## 下限と上限の両方を設定した範囲を返す。
static func between(lower_value: float, upper_value: float, overflow: Overflow = Overflow.CLAMP) -> StockRange:
	var result := StockRange.new()
	result._has_lower = true
	result._lower = lower_value
	result._has_upper = true
	result._upper = upper_value
	result._overflow = overflow
	return result


## 下限だけを設定した範囲を返す。上限は設定しない。
static func at_least(lower_value: float, overflow: Overflow = Overflow.CLAMP) -> StockRange:
	var result := StockRange.new()
	result._has_lower = true
	result._lower = lower_value
	result._overflow = overflow
	return result


## 上限だけを設定した範囲を返す。下限は設定しない。
static func at_most(upper_value: float, overflow: Overflow = Overflow.CLAMP) -> StockRange:
	var result := StockRange.new()
	result._has_upper = true
	result._upper = upper_value
	result._overflow = overflow
	return result


## 下限があるかを返す。
func has_lower() -> bool:
	return _has_lower


## 下限を返す。has_lower() が false のときは 0.0 で、意味を持たない。
func get_lower() -> float:
	return _lower


## 上限があるかを返す。
func has_upper() -> bool:
	return _has_upper


## 上限を返す。has_upper() が false のときは 0.0 で、意味を持たない。
func get_upper() -> float:
	return _upper


## 範囲を超えるときの扱いを返す。
func get_overflow() -> Overflow:
	return _overflow


## value を範囲内に収めた値を返す。設定していない側には制限をかけない。範囲を超えない値は、そのまま返す。
func apply(value: float) -> float:
	var result: float = value
	if _has_lower and result < _lower:
		result = _lower
	if _has_upper and result > _upper:
		result = _upper
	return result
