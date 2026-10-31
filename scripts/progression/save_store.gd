extends RefCounted
const Economy = preload("res://scripts/progression/economy.gd")
var path := "res://saves/progress.json"
var writable := true
var notice := ""
var catalog: UpgradeCatalog = Economy.DEFAULT_CATALOG

func whole(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= maximum

func valid(data: Variant) -> bool:
	if not data is Dictionary or (data.get("version") != 1 and data.get("version") != 2):
		return false
	if data.version == 2:
		var office: Variant = data.get("office")
		if not office is Dictionary or not whole(office.get("cargo"), 3) or not office.get("enveloped") is bool:
			return false
		if office.cargo == 0 and office.enveloped:
			return false
	var finance: Variant = data.get("economy")
	if not finance is Dictionary or not whole(finance.get("balance"), Economy.LIMIT) or not whole(finance.get("sold"), 1000000000) or not finance.get("levels") is Dictionary:
		return false
	var allowed := {}
	for entry in catalog.upgrades:
		allowed[str(entry.id)] = entry.max_level
	for id in finance.levels:
		if not allowed.has(id) or not whole(finance.levels[id], allowed[id]):
			return false
	if not whole(data.get("next_serial"), 1000000000) or data.next_serial < 4:
		return false
	var papers: Variant = data.get("papers")
	if not papers is Array or papers.size() > 3:
		return false
	var ids := {}
	for paper in papers:
		if not paper is Dictionary or not whole(paper.get("serial"), 1000000000) or paper.serial < 1 or paper.serial >= data.next_serial or ids.has(paper.serial):
			return false
		ids[paper.serial] = true
		if not paper.get("position") is Array or paper.position.size() != 3 or not paper.get("marks") is Array or paper.marks.size() > 24:
			return false
		for coordinate in paper.position:
			if not (coordinate is float or coordinate is int) or not is_finite(coordinate):
				return false
		if absf(paper.position[0]) > 4.12 or absf(paper.position[2]) > 1.62 or paper.position[1] < 0 or paper.position[1] > 1:
			return false
		for mark in paper.marks:
			if not mark is Array or mark.size() != 2:
				return false
			for coordinate in mark:
				if not (coordinate is float or coordinate is int) or not is_finite(coordinate) or absf(coordinate) > 0.9:
					return false
	return true

func read_data(filename: String) -> Variant:
	if not FileAccess.file_exists(filename):
		return null
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data

func archive_file(filename: String) -> bool:
	if not FileAccess.file_exists(filename):
		return true
	return DirAccess.copy_absolute(filename, filename + ".preserved-" + str(Time.get_ticks_usec())) == OK

func load_game() -> Dictionary:
	writable = true
	notice = ""
	var data: Variant = read_data(path)
	if valid(data):
		return migrate(data)
	# A newer version or missing catalog IDs must not silently roll back to an old save.
	if incompatible(data):
		writable = false
		notice = "La partida usa datos incompatibles. Se conserva sin modificar."
		return {}
	var backup: Variant = read_data(path + ".bak")
	if valid(backup):
		writable = archive_file(path)
		notice = "Se ha recuperado la copia de respaldo. El archivo anterior se conserva."
		# Preserve the recovered backup until a valid primary exists again.
		return migrate(backup)
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		writable = false
		notice = "No se pudo cargar la partida. Los archivos se conservan; no se guardará encima."
	return {}

func save(data: Dictionary) -> bool:
	if not writable or not valid(data):
		return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or not valid(read_data(temporary)):
		return false
	if valid(read_data(path)) and DirAccess.copy_absolute(path, path + ".bak") != OK:
		return false
	return DirAccess.rename_absolute(temporary, path) == OK

func allow_new_game() -> bool:
	if not archive_file(path) or not archive_file(path + ".bak"):
		return false
	writable = true
	return true

func incompatible(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if (data.get("version", 1) != 1 and data.get("version", 1) != 2):
		return true
	if data.get("economy") is Dictionary and data.economy.get("levels") is Dictionary:
		var known := {}
		for entry in catalog.upgrades:
			known[str(entry.id)] = true
		for id in data.economy.levels:
			if not known.has(id):
				return true
	return false


func migrate(data: Dictionary) -> Dictionary:
	if data.version == 1:
		var updated := data.duplicate(true)
		updated.version = 2
		updated.office = {"cargo": 0, "enveloped": false}
		notice = "Partida anterior cargada: dinero y mejoras conservados."
		return updated
	return data
