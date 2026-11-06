class_name UpgradeCatalog
extends Resource
@export var upgrades: Array[UpgradeDefinition] = []

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for entry in upgrades:
		if entry == null or entry.id == &"" or ids.has(entry.id):
			errors.append("Identificador vacío o duplicado")
			continue
		ids[entry.id] = entry
		if entry.title.is_empty() or entry.initial_cost <= 0 or not is_finite(entry.cost_growth) or entry.cost_growth < 1 or entry.max_level < 1 or entry.max_level > 20 or entry.effects.is_empty():
			errors.append("Definición inválida: " + str(entry.id))
		for required in entry.required_any_effects:
			if required < 0 or required >= UpgradeEffect.Attribute.size():
				errors.append("Atributo requerido inválido: " + str(entry.id))
		for effect in entry.effects:
			if effect == null or not is_finite(effect.amount) or effect.amount <= 0 or (effect.attribute < 0 or effect.attribute >= UpgradeEffect.Attribute.size()) or effect.operation not in [0, 1]:
				errors.append("Efecto inválido: " + str(entry.id))
	for entry in upgrades:
		if entry == null:
			continue
		if entry.prerequisite != &"":
			if not ids.has(entry.prerequisite) or entry.prerequisite_level < 1:
				errors.append("Requisito inexistente: " + str(entry.id))
			elif entry.prerequisite_level > ids[entry.prerequisite].max_level:
				errors.append("Requisito inalcanzable: " + str(entry.id))
		var seen := {}
		var cursor = entry
		while cursor != null:
			if seen.has(cursor.id):
				errors.append("Ciclo de requisitos: " + str(entry.id))
				break
			seen[cursor.id] = true
			cursor = ids.get(cursor.prerequisite)
	return errors
