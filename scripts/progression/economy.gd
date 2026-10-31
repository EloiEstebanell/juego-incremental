extends RefCounted
const DEFAULT_CATALOG = preload("res://resources/upgrade_catalog.tres")
const LIMIT := 1000000000000
var catalog: UpgradeCatalog = DEFAULT_CATALOG
var balance: int = 0
var sold: int = 0
var levels: Dictionary = {}

func definition(id: StringName) -> UpgradeDefinition:
	for entry in catalog.upgrades:
		if entry.id == id:
			return entry
	return null

func level(id: StringName) -> int:
	return int(levels.get(str(id), 0))

func cost(entry: UpgradeDefinition) -> int:
	return int(minf(LIMIT, ceil(entry.initial_cost * pow(entry.cost_growth, level(entry.id)))))

func value(attribute: int, base: float, override_id: StringName = &"", override_level: int = -1) -> float:
	var added := 0.0
	var multiplied := 1.0
	for entry in catalog.upgrades:
		var count := override_level if entry.id == override_id else level(entry.id)
		for effect in entry.effects:
			if effect.attribute != attribute:
				continue
			if effect.operation == UpgradeEffect.Operation.ADD:
				added += effect.amount * count
			else:
				multiplied *= pow(effect.amount, count)
	return clampf((base + added) * multiplied, 0.05 if attribute == 2 else 0.0001, LIMIT)

func payout(override_id: StringName = &"", override_level: int = -1) -> int:
	return clampi(roundi(value(0, 100.0, override_id, override_level) * value(1, 1.0, override_id, override_level)), 1, LIMIT)

func reason(entry: UpgradeDefinition) -> String:
	if level(entry.id) >= entry.max_level:
		return "Nivel máximo"
	if entry.prerequisite != &"" and level(entry.prerequisite) < entry.prerequisite_level:
		var required := definition(entry.prerequisite)
		return "Requiere %s · nivel %d" % [required.title if required else str(entry.prerequisite), entry.prerequisite_level]
	if balance < cost(entry):
		return "Faltan " + money(cost(entry) - balance)
	return ""

func buy(id: StringName, expected_level: int) -> bool:
	var entry := definition(id)
	if entry == null or level(id) != expected_level or not reason(entry).is_empty():
		return false
	balance -= cost(entry)
	levels[str(id)] = expected_level + 1
	return true

static func money(units: int) -> String:
	# 10,000 integer units = one euro. Show fractions when they matter.
	return ("%.4f €" if units % 100 != 0 else "%.2f €") % (float(units) / 10000.0)

func snapshot() -> Dictionary:
	return {"balance": balance, "sold": sold, "levels": levels.duplicate()}

func restore(data: Dictionary) -> void:
	balance = int(data.balance)
	sold = int(data.sold)
	levels = data.levels.duplicate()

