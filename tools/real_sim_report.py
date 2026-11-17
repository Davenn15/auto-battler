"""Report for tools/real_sim results: faction winrates, unit / keepsake / Ascension winrate
deltas, upgrade paths and other patterns.

    python tools/real_sim_report.py tools/sim_results/real_<time>

Writes report.txt next to matches.jsonl and prints it. "Delta" = winrate of players who
had it minus winrate of comparable players who didn't (same faction for units and
faction Ascensions). The +/- is one standard error; treat anything inside about 2 of them
as noise.
"""
import json
import math
import sys
from collections import defaultdict

folder = sys.argv[1]
matches = [json.loads(line) for line in open(f"{folder}/matches.jsonl", encoding="utf-8") if line.strip()]
out = []
ABBR = {"Sword Court": "SC", "Obelisk": "OB", "Admonistration": "ADM"}


def say(text=""):
    out.append(text)


def se(p, n):
    return math.sqrt(max(p * (1 - p), 0.01) / max(n, 1))


def pct(x):
    return f"{x * 100:5.1f}%"


def delta_row(name, with_results, without_results, min_n):
    n1, n0 = len(with_results), len(without_results)
    if n1 < min_n or n0 < 3:
        return None
    w1, w0 = sum(with_results) / n1, sum(without_results) / n0
    d = w1 - w0
    err = math.sqrt(se(w1, n1) ** 2 + se(w0, n0) ** 2)
    flag = " **" if abs(d) > 2 * err else ""
    return (d, f"  {name:<28} {pct(w1)} (n={n1:<4}) vs {pct(w0)} without   delta {d * 100:+6.1f} ±{err * 100:4.1f}{flag}")


def table(title, rows, note=""):
    say(title)
    if note:
        say(note)
    rows = [r for r in rows if r is not None]
    rows.sort(key=lambda r: -r[0])
    for _, text in rows:
        say(text)
    say()


players = []   # (match, player dict, opponent dict)
for m in matches:
    a, b = m["players"]
    players.append((m, a, b))
    players.append((m, b, a))


def unit_name(entry):
    return entry.split("|")[0]


def unit_path(entry):
    return entry.split("|")[1]


def items_of(entry):
    text = entry.split("|")[4]
    return [i for i in text.split("+") if i]


# ---------- Overview ----------
say(f"REAL-GAME SIM REPORT: {len(matches)} matches, {len(players)} player results")
combats = [m["combats"] for m in matches]
secs = [m["seconds"] for m in matches]
draws = sum(1 for m in matches if m["players"][0]["result"] == 0.5)
say(f"Combats per match: avg {sum(combats) / len(combats):.1f} (min {min(combats)}, max {max(combats)});"
    f" draws {draws}; avg {sum(secs) / len(secs) / 60:.1f} min of simulation per match")
say()

# ---------- Factions ----------
say("FACTIONS")
cross = defaultdict(list)
mirror = defaultdict(int)
for m in matches:
    a, b = m["players"]
    if a["faction"] == b["faction"]:
        mirror[a["faction"]] += 1
    else:
        cross[a["faction"]].append(a["result"])
        cross[b["faction"]].append(b["result"])
for f, results in sorted(cross.items()):
    w = sum(results) / len(results)
    say(f"  {f:<14} {pct(w)} in {len(results)} cross-faction matches  (±{se(w, len(results)) * 100:.1f})")
for f, n in sorted(mirror.items()):
    say(f"  {f:<14} mirror matches: {n}")
seat = [m["players"][0]["result"] for m in matches]
say(f"  Seat check (player 0 fights at the bottom): {pct(sum(seat) / len(seat))} winrate")
say()

# ---------- Units (final armies) ----------
by_faction_players = defaultdict(list)
for m, p, o in players:
    by_faction_players[p["faction"]].append(p)
rows = []
pick_lines = []
for faction, group in sorted(by_faction_players.items()):
    names = sorted({unit_name(u) for p in group for u in p["army"]})
    for name in names:
        has = [p["result"] for p in group if any(unit_name(u) == name for u in p["army"])]
        hasnt = [p["result"] for p in group if not any(unit_name(u) == name for u in p["army"])]
        rows.append(delta_row(f"{name} ({ABBR.get(faction, faction[:2])})", has, hasnt, 8))
        pick_lines.append((len(has) / len(group), f"  {name:<14} ({ABBR.get(faction, faction[:2])}) in {pct(len(has) / len(group))} of final armies"))
table("UNITS: match winrate with the unit in the final army (vs same-faction players without it)", rows)

# Combat-level: fielded armies in every combat (many more samples).
rows = []
combat_samples = defaultdict(lambda: ([], []))   # (faction, unit) -> (with, without)
for m in matches:
    factions = [p["faction"] for p in m["players"]]
    for c in m["combat_log"]:
        if c["winner"] not in (1, 2, 0, -1):
            continue
        for side in range(2):
            won = 1.0 if c["winner"] == side + 1 else (0.5 if c["winner"] not in (1, 2) else 0.0)
            fielded = {unit_name(u) for u in c["armies"][side]}
            for (f, name) in [(factions[side], n) for n in fielded]:
                combat_samples[(f, name)][0].append(won)
for m in matches:
    factions = [p["faction"] for p in m["players"]]
    for c in m["combat_log"]:
        for side in range(2):
            won = 1.0 if c["winner"] == side + 1 else (0.5 if c["winner"] not in (1, 2) else 0.0)
            fielded = {unit_name(u) for u in c["armies"][side]}
            for (f, name) in list(combat_samples.keys()):
                if f == factions[side] and name not in fielded:
                    combat_samples[(f, name)][1].append(won)
for (f, name), (w, wo) in sorted(combat_samples.items()):
    rows.append(delta_row(f"{name} ({ABBR.get(f, f[:2])})", w, wo, 20))
table("UNITS: combat winrate when fielded (every combat; vs same-faction armies without it)", rows,
      "  (more samples, but early rounds weigh in; strong late units can look weaker here)")

say("UNITS: how often they end up in the final army")
for _, text in sorted(pick_lines, key=lambda r: -r[0]):
    say(text)
say()

# ---------- Upgrade paths ----------
say("UPGRADE PATHS (final armies, units with 8+ samples): winrate by first upgrade")
paths = defaultdict(lambda: defaultdict(list))
for m, p, o in players:
    for u in p["army"]:
        path = unit_path(u)
        branch = "base" if path == "base" else path[0]
        paths[unit_name(u)][branch].append(p["result"])
for name, branches in sorted(paths.items()):
    total = sum(len(v) for v in branches.values())
    if total < 8:
        continue
    parts = [f"{b}: {pct(sum(v) / len(v))} n={len(v)}" for b, v in sorted(branches.items())]
    say(f"  {name:<14} " + "   ".join(parts))
say()

# ---------- Keepsakes ----------
rows = []
shard_rows = []
all_items = sorted({i for m, p, o in players for u in p["army"] for i in items_of(u)})
for item in all_items:
    has = [p["result"] for m, p, o in players if any(item in items_of(u) for u in p["army"])]
    hasnt = [p["result"] for m, p, o in players if not any(item in items_of(u) for u in p["army"])]
    row = delta_row(item, has, hasnt, 10)
    (shard_rows if item.endswith("Shard") else rows).append(row)
table("KEEPSAKES: match winrate with it equipped in the final army (vs players without it)", rows)
table("SHARDS (loose stat items equipped)", shard_rows)

# ---------- Ascensions ----------
rows = []
pick_rate = []
names = sorted({a["name"] for m, p, o in players for a in p["ascensions"]} |
               {n for m, p, o in players for n in p["offers"]})
for name in names:
    offered = [(p, any(a["name"] == name for a in p["ascensions"])) for m, p, o in players if name in p["offers"]]
    if not offered:
        continue
    took = [p["result"] for p, t in offered if t]
    passed = [p["result"] for p, t in offered if not t]
    rows.append(delta_row(name, took, passed, 6))
    pick_rate.append((len(took) / len(offered), f"  {name:<28} offered {len(offered):<4} taken {pct(len(took) / len(offered))}"))
table("ASCENSIONS: match winrate when taken (vs players offered it who took something else)", rows,
      "  (an Ascension offered alongside better ones still counts as 'offered')")
say("ASCENSIONS: how often the computer takes it when offered")
for _, text in sorted(pick_rate, key=lambda r: -r[0]):
    say(text)
say()

# ---------- Other patterns ----------
say("OTHER PATTERNS")
first = []
for m in matches:
    log = m["combat_log"]
    if not log or log[0]["winner"] not in (1, 2):
        continue
    winner_side = log[0]["winner"] - 1
    first.append(m["players"][winner_side]["result"])
if first:
    say(f"  Winning the first combat -> match winrate {pct(sum(first) / len(first))} (n={len(first)})")
streak = defaultdict(list)
for m in matches:
    for side in range(2):
        wins = sum(1 for c in m["combat_log"][:3] if c["winner"] == side + 1)
        streak[wins].append(m["players"][side]["result"])
for wins in sorted(streak):
    v = streak[wins]
    say(f"  Won {wins} of the first 3 combats -> {pct(sum(v) / len(v))} (n={len(v)})")
winners = [p for m, p, o in players if p["result"] == 1.0]
losers = [p for m, p, o in players if p["result"] == 0.0]
if winners and losers:
    say(f"  Final army Aura: winners {sum(p['army_aura'] for p in winners) / len(winners):.1f}, losers {sum(p['army_aura'] for p in losers) / len(losers):.1f}")
    say(f"  Units in final army: winners {sum(len(p['army']) for p in winners) / len(winners):.1f}, losers {sum(len(p['army']) for p in losers) / len(losers):.1f}")
    say(f"  Keepsakes equipped: winners {sum(sum(len([i for i in items_of(u) if not i.endswith('Shard')]) for u in p['army']) for p in winners) / len(winners):.1f}, losers {sum(sum(len([i for i in items_of(u) if not i.endswith('Shard')]) for u in p['army']) for p in losers) / len(losers):.1f}")
    say(f"  Winner HP left: avg {sum(p['hp'] for p in winners) / len(winners):.1f}")
times = [c["time"] for m in matches for c in m["combat_log"]]
long_fights = sum(1 for t in times if t >= 179)
say(f"  Combat length: avg {sum(times) / len(times):.1f}s; {long_fights} of {len(times)} hit the time limit")
by_round = defaultdict(list)
for m in matches:
    for c in m["combat_log"]:
        by_round[c["round"]].append(c["time"])
say("  Avg combat length by round: " + ", ".join(f"R{r} {sum(v) / len(v):.0f}s" for r, v in sorted(by_round.items()) if len(v) >= 5))
say()

text = "\n".join(out)
open(f"{folder}/report.txt", "w", encoding="utf-8").write(text)
print(text)
