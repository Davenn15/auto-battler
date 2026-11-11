extends SceneTree
## Turns a match_sim results folder into report.txt: how the strategies evolved, what the
## best one does, and which units, paths, keepsakes and habits win.
##   godot --headless --path . -s res://tools/match_report.gd -- <results folder>

var lines: PackedStringArray = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if not args.is_empty() else ""
	var matches := _read_jsonl(dir.path_join("matches.jsonl"))
	var finals := _read_jsonl(dir.path_join("final_matches.jsonl"))
	var history = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("history.json")))
	var champion = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("champion.json")))
	var gens := 0
	for m in matches:
		gens = maxi(gens, int(m["gen"]) + 1)
	var late := matches.filter(func(m): return int(m["gen"]) >= gens - maxi(floori(gens / 3.0), 1))

	_out("MATCH SIM REPORT  (%d matches over %d generations; 'late' = last %d generations, %d matches)" %
			[matches.size(), gens, maxi(floori(gens / 3.0), 1), late.size()])
	_evolution(history)
	_final(finals)
	_champion(champion)
	_match_shape(matches, late)
	_unit_tables(late, matches)
	_keepsakes(late)
	_habits(late)
	_combat_tables(matches)
	var f := FileAccess.open(dir.path_join("report.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("\n".join(lines))
	quit()


func _out(text: String = "") -> void:
	lines.append(text)


func _read_jsonl(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var parsed = JSON.parse_string(line)
		if parsed != null:
			out.append(parsed)
	return out


func _pct(x: float) -> String:
	return "%5.1f%%" % (x * 100.0)


# ---------- Sections ----------

func _evolution(history) -> void:
	_out()
	_out("== Evolution: fitness per generation (win share + HP margin / 640) ==")
	for h in history:
		var f: Array = h["fitness"]
		_out("  gen %2d   best %5.2f   median %5.2f   worst %5.2f" % [int(h["gen"]) + 1, f[0], f[floori(f.size() / 2.0)], f[f.size() - 1]])


func _final(finals: Array) -> void:
	var score := 0.0
	var hp_diff := 0.0
	for r in finals:
		var champ := "a" if int(r["a_id"]) == 0 else "b"
		var other := "b" if champ == "a" else "a"
		score += float(r[champ]["result"])
		hp_diff += float(r[champ]["hp"]) - float(r[other]["hp"])
	_out()
	_out("== Final: evolved champion vs the game's default strategy ==")
	if finals.is_empty():
		_out("  (no final matches)")
		return
	_out("  champion scored %.1f / %d (%s), average HP lead at the end %+.1f" %
			[score, finals.size(), _pct(score / finals.size()), hp_diff / finals.size()])


func _champion(g) -> void:
	_out()
	_out("== The champion strategy ==")
	for key in AiPolicy.RANGES:
		var r: Array = AiPolicy.RANGES[key]
		_out("  %-14s %6.2f   (default %.2f, range %.2f-%.2f)" % [key, g.get(key, r[0]), r[0], r[1], r[2]])
	var units: Array = g["units"].keys()
	units.sort_custom(func(a, b): return g["units"][a] > g["units"][b])
	_out("  Unit buy weights (x default):")
	for name in units:
		var p: Array = g["paths"][name]
		_out("    %-11s x%5.2f   level 1: %3d%% A   level 2: %3d%% first choice" % [name, g["units"][name], roundi(p[0] * 100), roundi(p[1] * 100)])
	var shards: Array = g["shards"].keys()
	shards.sort_custom(func(a, b): return g["shards"][a] > g["shards"][b])
	_out("  Shard buy weights: " + ", ".join(shards.map(func(s): return "%s x%.2f" % [s, g["shards"][s]])))


func _match_shape(all: Array, late: Array) -> void:
	_out()
	_out("== Match shape ==")
	for set_name in ["all", "late"]:
		var set_: Array = all if set_name == "all" else late
		var combats := 0.0
		var drawn := 0
		var reserve := 0.0
		var loose := 0.0
		var hp := 0.0
		for m in set_:
			combats += m["combats"].size()
			if float(m["a"]["result"]) == 0.5:
				drawn += 1
			for side in ["a", "b"]:
				reserve += float(m[side]["reserve_left"])
				loose += float(m[side]["loose_items"])
				hp += maxf(float(m[side]["hp"]), 0.0)
		var n := maxf(set_.size(), 1)
		_out("  %-4s  combats per match %.1f   drawn matches %d   Reserve unspent at end %.1f   loose items at end %.1f   winner HP left %.1f" %
				[set_name, combats / n, drawn, reserve / (2 * n), loose / (2 * n), hp / n])
	var lengths := {}
	for m in late:
		var c: int = m["combats"].size()
		lengths[c] = lengths.get(c, 0) + 1
	var keys := lengths.keys()
	keys.sort()
	_out("  late: matches lasting N combats: " + ", ".join(keys.map(func(k): return "%d: %d" % [k, lengths[k]])))
	var timeouts := 0
	var draws := 0
	var total := 0
	for m in all:
		for c in m["combats"]:
			total += 1
			if int(c["winner"]) == 0:
				draws += 1
			if float(c["time"]) >= 179.0:
				timeouts += 1
	_out("  combats: %d, drawn %d, hit the 180s safety limit %d" % [total, draws, timeouts])


## Units in the final armies: how often each appears and how its owners did.
func _unit_tables(late: Array, _all: Array) -> void:
	var units := {}
	var paths := {}
	var size_wins := {}
	var rows := {}
	for m in late:
		for side in ["a", "b"]:
			var result := float(m[side]["result"])
			var army: Array = m[side]["army"]
			var key := army.size()
			size_wins[key] = _add(size_wins.get(key, [0.0, 0]), result)
			for entry in army:
				var parts: PackedStringArray = entry.split("|")
				units[parts[0]] = _add(units.get(parts[0], [0.0, 0]), result)
				var path_key := "%s %s" % [parts[0], parts[1]]
				paths[path_key] = _add(paths.get(path_key, [0.0, 0]), result)
				var row_key := "%s row %s" % [parts[0], parts[3]]
				rows[row_key] = _add(rows.get(row_key, [0.0, 0]), result)
	var armies := late.size() * 2
	_out()
	_out("== Late final armies: units (share of armies that had it, owner's match win rate) ==")
	_table(units, armies)
	_out()
	_out("== Late final armies: unit + upgrade path (at least 8 armies) ==")
	_table(paths, armies, 8)
	_out()
	_out("== Late final armies: army size (number of units) ==")
	var sizes := size_wins.keys()
	sizes.sort()
	for s in sizes:
		_out("  %2d units: %4d armies, win %s" % [s, size_wins[s][1], _pct(size_wins[s][0] / size_wins[s][1])])


func _keepsakes(late: Array) -> void:
	var items := {}
	var equipped := 0
	for m in late:
		for side in ["a", "b"]:
			var result := float(m[side]["result"])
			for entry in m[side]["army"]:
				var parts: PackedStringArray = entry.split("|")
				if parts[4] == "":
					continue
				for item in parts[4].split("+"):
					equipped += 1
					var name := item if item != "" else "?"
					items[name] = _add(items.get(name, [0.0, 0]), result)
	_out()
	_out("== Late final armies: items on units (%d equipped) — count, owner's match win rate ==" % equipped)
	var keys := items.keys()
	keys.sort_custom(func(a, b): return items[a][1] > items[b][1])
	for k in keys:
		if items[k][1] >= 4:
			_out("  %-24s %4d   win %s" % [k, items[k][1], _pct(items[k][0] / items[k][1])])


## Shop habits of winners vs losers.
func _habits(late: Array) -> void:
	var keys := ["units", "upgrades", "buffs", "shards", "rerolls", "combines"]
	var win := {}
	var lose := {}
	var nw := 0
	var nl := 0
	var res_w := 0.0
	var res_l := 0.0
	for m in late:
		for side in ["a", "b"]:
			var r := float(m[side]["result"])
			if r == 0.5:
				continue
			var target := win if r == 1.0 else lose
			for k in keys:
				target[k] = target.get(k, 0.0) + float(m[side]["shop"].get(k, 0.0))
			if r == 1.0:
				nw += 1
				res_w += float(m[side]["reserve_left"])
			else:
				nl += 1
				res_l += float(m[side]["reserve_left"])
	_out()
	_out("== Late: shop habits per match, winners vs losers ==")
	for k in keys:
		_out("  %-9s winners %5.1f   losers %5.1f" % [k, win.get(k, 0.0) / maxf(nw, 1), lose.get(k, 0.0) / maxf(nl, 1)])
	_out("  Reserve left: winners %.1f   losers %.1f" % [res_w / maxf(nw, 1), res_l / maxf(nl, 1)])


## Every combat of every match: which units win fights, and how much an Aura lead matters.
func _combat_tables(all: Array) -> void:
	var units := {}
	var lead := {}
	var count := 0
	for m in all:
		for c in m["combats"]:
			var w := int(c["winner"])
			for side in ["a", "b"]:
				var result := 0.5 if w == 0 else (1.0 if (w == 1) == (side == "a") else 0.0)
				var seen := {}
				for entry in c[side + "_army"]:
					var name: String = entry.split("|")[0]
					if not seen.has(name):
						seen[name] = true
						units[name] = _add(units.get(name, [0.0, 0]), result)
			var diff := int(c["a_aura"]) - int(c["b_aura"])
			var bucket := clampi(diff, -6, 6)
			var a_result := 0.5 if w == 0 else (1.0 if w == 1 else 0.0)
			lead[bucket] = _add(lead.get(bucket, [0.0, 0]), a_result)
			count += 1
	_out()
	_out("== Every combat (%d): units fielded, and that side's combat win rate ==" % count)
	_table(units, count * 2)
	_out()
	_out("== Every combat: Aura lead of the bottom army (clamped to +-6) vs its win rate ==")
	var keys := lead.keys()
	keys.sort()
	for k in keys:
		_out("  lead %+d: %4d combats, win %s" % [k, lead[k][1], _pct(lead[k][0] / lead[k][1])])


func _add(pair: Array, result: float) -> Array:
	return [pair[0] + result, pair[1] + 1]


func _table(data: Dictionary, total: int, min_count: int = 1) -> void:
	var keys := data.keys().filter(func(k): return data[k][1] >= min_count)
	keys.sort_custom(func(a, b): return data[a][0] / data[a][1] > data[b][0] / data[b][1])
	for k in keys:
		_out("  %-20s in %s (%4d)   win %s" % [k, _pct(float(data[k][1]) / maxf(total, 1)), data[k][1], _pct(data[k][0] / data[k][1])])
