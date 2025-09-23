extends Resource
class_name LootTable

@export var entries: Array = [] # Array of {id: String, weight: float, min: int, max: int}

func roll_one(rng_seed: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	var total: float = 0.0
	for e in entries:
		total += float(e.get("weight", 0.0))
	if total <= 0.0:
		return {}
	var pick := rng.randf() * total
	var acc: float = 0.0
	for e in entries:
		acc += float(e.get("weight", 0.0))
		if pick <= acc:
			var min_q: int = int(e.get("min", 1))
			var max_q: int = int(e.get("max", 1))
			var qty: int = rng.randi_range(min_q, max_q)
			return {"id": String(e.get("id", "")), "quantity": qty}
	return {}
