extends Node
class_name Wallet

# {currency_id: amount}
var _balances: Dictionary = {}

signal balance_changed(currency: String, amount: int)

func deposit(currency: String, amount: int) -> bool:
	if currency.is_empty() or amount <= 0:
		return false
	var new_amt: int = int(_balances.get(currency, 0)) + amount
	_balances[currency] = new_amt
	balance_changed.emit(currency, new_amt)
	return true

func withdraw(currency: String, amount: int) -> bool:
	if currency.is_empty() or amount <= 0:
		return false
	var cur: int = int(_balances.get(currency, 0))
	if cur < amount:
		return false
	cur -= amount
	_balances[currency] = cur
	balance_changed.emit(currency, cur)
	return true

func balance(currency: String) -> int:
	return int(_balances.get(currency, 0))

func save_data() -> Dictionary:
	return {"balances": _balances.duplicate(true)}

func load_data(data: Dictionary) -> bool:
	_balances = data.get("balances", {}).duplicate(true)
	return true
