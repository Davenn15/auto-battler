extends SceneTree
## Builds the computer player's keepsake lift table (KeepsakeLiftTable) from balance sim
## results. For every unit row in the sims' _units.csv files, it compares the result with
## what that unit usually gets carrying the same number of items at a similar ARV; each
## keepsake's lift on a unit is the average of that difference over the rows that carried it.
##
## Usage (from the project folder):
##   godot --headless --path . -s tools/keepsake_table.gd -- --in res://tools/sim_results/big_10k
## --in may be given several times (folders or _units.csv files).
## --out defaults to KeepsakeSense.LIFT_TABLE_PATH.

## Pairs need this many battles to count toward the table's spread.
const SPREAD_MIN_BATTLES := 50
## Width of the ARV buckets used for "a similar ARV".
const ARV_BUCKET := 8


func _init() -> void:
	var inputs: Array[String] = []
	var out := KeepsakeSense.LIFT_TABLE_PATH
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--in":
				i += 1
				inputs.append(args[i])
			"--out":
				i += 1
				out = args[i]
		i += 1
	if inputs.is_empty():
		push_error("keepsake_table: give at least one --in folder or _units.csv file.")
		quit(1)
		return
	var rows := []
	for input in inputs:
		for file in _csv_files(input):
			rows.append_array(_read_rows(file))
	print("keepsake_table: %d unit rows from %s" % [rows.size(), ", ".join(inputs)])
	if rows.is_empty():
		quit(1)
		return

	# What each unit usually gets, by item count and ARV bucket.
	var baseline := {}   # "unit|items|bucket" -> [total, count]
	for row in rows:
		var key: String = _baseline_key(row)
		var cell: Array = baseline.get(key, [0.0, 0])
		baseline[key] = [cell[0] + row["result"], cell[1] + 1]
	# Each pair's lift: the average result above that baseline.
	var sums := {}   # unit -> {keepsake -> [total, count]}
	for row in rows:
		var cell: Array = baseline[_baseline_key(row)]
		var residual: float = row["result"] - cell[0] / cell[1]
		var per_unit: Dictionary = sums.get(row["unit"], {})
		for keepsake in row["keepsakes"]:
			var pair: Array = per_unit.get(keepsake, [0.0, 0])
			per_unit[keepsake] = [pair[0] + residual, pair[1] + 1]
		sums[row["unit"]] = per_unit

	# How noisy one battle is (the spread of results around the baseline).
	var noise := 0.0
	for row in rows:
		var cell: Array = baseline[_baseline_key(row)]
		noise += pow(row["result"] - cell[0] / cell[1], 2)
	noise /= rows.size()
	# The pairs' averages spread out for two reasons: real differences, and chance from
	# having only so many battles each. Take away the chance part to get the real spread.
	var means: Array[float] = []
	var chance := 0.0
	for unit in sums:
		for keepsake in sums[unit]:
			var pair: Array = sums[unit][keepsake]
			if pair[1] >= SPREAD_MIN_BATTLES:
				means.append(pair[0] / pair[1])
				chance += noise / pair[1]
	chance = chance / maxf(means.size(), 1.0)
	var observed := _spread(means)
	var real := sqrt(maxf(observed * observed - chance, 0.0001))
	print("keepsake_table: pair averages spread %.3f, of which chance %.3f, real %.3f" % [observed, sqrt(chance), real])

	var table := KeepsakeLiftTable.new()
	for unit in sums:
		var per_unit := {}
		for keepsake in sums[unit]:
			var pair: Array = sums[unit][keepsake]
			var mean: float = pair[0] / pair[1]
			# How far to believe this pair's average: near 1 with many battles, near 0 with few.
			var reliability: float = real * real / (real * real + noise / pair[1])
			per_unit[keepsake] = [mean * reliability, pair[1], reliability, mean]
		table.lift[unit] = per_unit
	table.spread = real
	table.source = "%s; %d unit rows; built %s" % [", ".join(inputs), rows.size(), Time.get_datetime_string_from_system()]
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var error := ResourceSaver.save(table, out)
	if error != OK:
		push_error("keepsake_table: couldn't save %s (error %d)" % [out, error])
		quit(1)
		return
	print("keepsake_table: %d units, spread %.3f, saved %s" % [table.lift.size(), table.spread, out])
	_print_extremes(table)
	quit(0)


func _baseline_key(row: Dictionary) -> String:
	return "%s|%d|%d" % [row["unit"], row["keepsakes"].size(), floori(row["arv"] / float(ARV_BUCKET))]


func _csv_files(input: String) -> Array[String]:
	var files: Array[String] = []
	if input.ends_with(".csv"):
		files.append(input)
		return files
	for file in DirAccess.get_files_at(input):
		if file.ends_with("_units.csv"):
			files.append(input.path_join(file))
	return files


## Unit rows with a result: 1 win, 0 loss. Draws are left out.
func _read_rows(path: String) -> Array:
	var rows := []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("keepsake_table: can't open %s" % path)
		return rows
	var header := file.get_csv_line()
	var column := {}
	for i in header.size():
		column[header[i]] = i
	for needed in ["arv", "result", "unit", "keepsakes"]:
		if not column.has(needed):
			push_error("keepsake_table: %s has no '%s' column" % [path, needed])
			return rows
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < header.size():
			continue
		var result: String = line[column["result"]]
		if result != "win" and result != "loss":
			continue
		var names := []
		for part in line[column["keepsakes"]].split(";", false):
			var keepsake := part.strip_edges()
			if keepsake != "" and not names.has(keepsake):
				names.append(keepsake)
		rows.append({
			"unit": line[column["unit"]], "arv": int(line[column["arv"]]),
			"result": 1.0 if result == "win" else 0.0, "keepsakes": names,
		})
	return rows


func _spread(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.05
	var mean := 0.0
	for v in values:
		mean += v
	mean /= values.size()
	var square := 0.0
	for v in values:
		square += (v - mean) * (v - mean)
	return maxf(sqrt(square / values.size()), 0.001)


func _print_extremes(table: KeepsakeLiftTable) -> void:
	var pairs := []
	for unit in table.lift:
		for keepsake in table.lift[unit]:
			var entry: Array = table.lift[unit][keepsake]
			if entry[1] >= SPREAD_MIN_BATTLES:
				pairs.append([entry[0], unit, keepsake, entry[1]])
	pairs.sort_custom(func(a, b): return a[0] > b[0])
	print("Best pairs:")
	for pair in pairs.slice(0, 12):
		print("  %+.3f  %s + %s (%d)" % pair)
	print("Worst pairs:")
	for pair in pairs.slice(maxi(pairs.size() - 12, 0)):
		print("  %+.3f  %s + %s (%d)" % pair)
