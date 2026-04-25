extends RefCounted
class_name GalacticNameGenerator

const OBJECT_PLANET := "planet"
const OBJECT_SYSTEM := "system"
const OBJECT_MOON := "moon"
const OBJECT_SECTOR := "sector"
const OBJECT_CORPORATE_COLONY := "corporate_colony"

const _CORPORATE_TAGS: Array[String] = ["-Dyne", "-Tek", "-Corp", "-Extract"]
const _CORE_CLASSICAL_SUFFIXES: Array[Dictionary] = [
	{"v": "ia", "w": 1.5},
	{"v": "on", "w": 1.1},
	{"v": "um", "w": 0.9},
	{"v": "ara", "w": 1.1},
	{"v": "eus", "w": 0.8},
]
const _GENERIC_NUMERAL_SUFFIXES: Array[Dictionary] = [
	{"v": "I", "w": 1.0}, {"v": "II", "w": 0.95}, {"v": "III", "w": 0.9}, {"v": "IV", "w": 0.85},
	{"v": "V", "w": 0.82}, {"v": "VI", "w": 0.78}, {"v": "VII", "w": 0.73}, {"v": "VIII", "w": 0.7},
	{"v": "IX", "w": 0.66}, {"v": "X", "w": 0.62}, {"v": "XI", "w": 0.58}, {"v": "XII", "w": 0.55},
]
const _PLANET_SUFFIXES_BY_REGION: Dictionary = {
	"Core Worlds": ["a", "ia", "is", "on", "ar"],
	"Colonies": ["a", "en", "is", "or", "an"],
	"Inner Rim": ["a", "en", "or", "is", "el"],
	"Mid Rim": ["a", "or", "en", "al", "in"],
	"Outer Rim": ["a", "ok", "ar", "an", "ik"],
	"Expansion Region": ["a", "is", "or", "an", "et"],
	"Hutt Space": ["a", "uk", "og", "um", "ar"],
	"Unknown Regions": ["a", "ir", "or", "an", "ul"],
	"Deep Core": ["a", "ia", "is", "on", "ar"],
}
const _STRICT_REGIONS: Array[String] = ["Core Worlds", "Colonies", "Inner Rim", "Mid Rim", "Expansion Region", "Deep Core"]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_generated_name: String = ""

var _region_dispatch: Dictionary = {
	"Core Worlds": Callable(self, "_generate_core_worlds_name"),
	"Colonies": Callable(self, "_generate_colonies_name"),
	"Inner Rim": Callable(self, "_generate_inner_rim_name"),
	"Mid Rim": Callable(self, "_generate_mid_rim_name"),
	"Outer Rim": Callable(self, "_generate_outer_rim_name"),
	"Expansion Region": Callable(self, "_generate_expansion_region_name"),
	"Hutt Space": Callable(self, "_generate_hutt_space_name"),
	"Unknown Regions": Callable(self, "_generate_unknown_regions_name"),
	"Deep Core": Callable(self, "_generate_core_worlds_name"),
}

func _init(seed: int = 0) -> void:
	if seed == 0:
		_rng.seed = Time.get_unix_time_from_system() + Time.get_ticks_usec()
	else:
		_rng.seed = seed


func set_seed(seed: int) -> void:
	_rng.seed = seed


func generate_name(region, object_type, cultural_modifier = null, era = null) -> Dictionary:
	var normalized_region: String = _normalize_region(String(region))
	var normalized_type: String = String(object_type).strip_edges().to_lower()
	var modifier: Dictionary = cultural_modifier if cultural_modifier is Dictionary else {}
	var era_value: String = String(era) if era != null else ""
	var region_callable: Callable = _region_dispatch.get(normalized_region, Callable(self, "_generate_unknown_regions_name"))

	var base_result: Dictionary = region_callable.call(OBJECT_PLANET, modifier, era_value)
	var finalized: Dictionary = _apply_object_type_logic(base_result, normalized_region, normalized_type, modifier, era_value)
	if String(finalized.get("name", "")) == _last_generated_name:
		finalized = _apply_object_type_logic(region_callable.call(OBJECT_PLANET, modifier, era_value), normalized_region, normalized_type, modifier, era_value)
	_last_generated_name = String(finalized.get("name", ""))
	return finalized


func sample_region_outputs(region: String, count: int = 5) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for i in range(count):
		samples.append(generate_name(region, OBJECT_PLANET, {"ordinal_index": i + 1}))
	return samples


func _normalize_region(region: String) -> String:
	var trimmed: String = region.strip_edges()
	if trimmed.is_empty():
		return "Unknown Regions"
	return trimmed


func _apply_object_type_logic(base: Dictionary, region: String, object_type: String, modifier: Dictionary, era: String) -> Dictionary:
	match object_type:
		OBJECT_SYSTEM:
			return _generate_system_name(base, region, modifier, era)
		OBJECT_PLANET:
			return _generate_planet_name(base, region, modifier)
		OBJECT_MOON:
			return _generate_moon_name(base, region, modifier)
		OBJECT_SECTOR:
			return _generate_sector_name(base, region)
		OBJECT_CORPORATE_COLONY:
			return _generate_corporate_colony_name(base, region)
		_:
			return _generate_planet_name(base, region, modifier)


func _generate_planet_name(base: Dictionary, region: String, modifier: Dictionary) -> Dictionary:
	var parent_system: String = String(modifier.get("parent_system_name", "")).strip_edges()
	var ordinal_index: int = maxi(1, int(modifier.get("ordinal_index", 1)))
	var prefer_system_anchor: bool = not parent_system.is_empty() and _rng.randf() <= 0.55
	var candidate_name: String = String(base.get("name", ""))
	var pattern: String = "Regional"

	if prefer_system_anchor:
		candidate_name = _build_planet_name_from_system(parent_system, region, ordinal_index)
		pattern = "SystemAnchored"

	candidate_name = _sanitize_planet_name(candidate_name, region)
	if candidate_name.is_empty():
		candidate_name = _sanitize_planet_name("Nava", region)

	var out: Dictionary = base.duplicate(true)
	out["name"] = candidate_name
	out["structural_pattern"] = pattern
	return _with_metadata(out, region, OBJECT_PLANET)


func _generate_system_name(base: Dictionary, region: String, modifier: Dictionary, era: String) -> Dictionary:
	var capital_planet: String = String(modifier.get("capital_planet_name", "")).strip_edges()
	var parent_system: String = String(modifier.get("parent_system_name", "")).strip_edges()
	var mirror_name: String = capital_planet if not capital_planet.is_empty() else parent_system
	var use_mirror: bool = not mirror_name.is_empty() and _rng.randf() <= 0.30
	var base_name: String = String(base.get("name", ""))
	var system_root: String
	var pattern: String
	if use_mirror:
		system_root = mirror_name
		pattern = "Mirror"
	else:
		system_root = _build_distinct_system_root(base, base_name, region, era)
		pattern = "DistinctRoot"
	system_root = _normalize_system_root(system_root)
	var system_name: String = system_root
	var out: Dictionary = base.duplicate(true)
	out["name"] = system_name
	out["structural_pattern"] = pattern
	return _with_metadata(out, region, OBJECT_SYSTEM)


func _generate_moon_name(base: Dictionary, region: String, modifier: Dictionary) -> Dictionary:
	var parent_planet: String = String(modifier.get("parent_planet_name", "")).strip_edges()
	if parent_planet.is_empty():
		parent_planet = String(base.get("name", ""))
	var index: int = maxi(1, int(modifier.get("ordinal_index", _rng.randi_range(1, 30))))
	var use_roman: bool = _rng.randf() <= 0.65
	var moon_name: String
	if use_roman:
		moon_name = "%s %s" % [parent_planet, _to_roman(index)]
	else:
		moon_name = "%s %s" % [parent_planet, _short_alien_derivative(String(base.get("name", "")))]
	var out: Dictionary = base.duplicate(true)
	out["name"] = moon_name
	out["structural_pattern"] = "Parent+Roman" if use_roman else "Parent+AlienDerivative"
	return _with_metadata(out, region, OBJECT_MOON)


func _build_planet_name_from_system(system_name: String, region: String, ordinal_index: int) -> String:
	var root: String = _normalize_parent_root(system_name)
	if root.is_empty():
		return "Nava"

	var trimmed_root: String = root
	if trimmed_root.length() > 5:
		trimmed_root = trimmed_root.substr(0, 4 + (ordinal_index % 2))

	var suffix_pool_raw: Array = _PLANET_SUFFIXES_BY_REGION.get(region, ["a", "en", "or"]) as Array
	var suffix_pool: Array[Dictionary] = _to_weighted_strings(suffix_pool_raw)
	var suffix: String = String(_weighted_choice(suffix_pool))
	var combined: String = "%s%s" % [trimmed_root, suffix]
	return _capitalize_name(combined)


func _normalize_parent_root(value: String) -> String:
	var cleaned: String = value.strip_edges().to_lower()
	if cleaned.is_empty():
		return ""

	cleaned = cleaned.replace("-", "").replace("'", "").replace(" ", "")
	for suffix in ["prime", "system", "sector"]:
		if cleaned.ends_with(suffix) and cleaned.length() > suffix.length() + 2:
			cleaned = cleaned.substr(0, cleaned.length() - suffix.length())

	cleaned = _strip_trailing_roman(cleaned)
	if cleaned.length() > 2 and not _contains_vowel(cleaned):
		cleaned += "a"
	if cleaned.length() < 3:
		cleaned += "na"
	return _capitalize_name(cleaned)


func _strip_trailing_roman(value: String) -> String:
	var out: String = value
	while not out.is_empty() and ["i", "v", "x"].has(out.substr(out.length() - 1, 1)):
		out = out.substr(0, out.length() - 1)
	return out


func _sanitize_planet_name(value: String, region: String) -> String:
	var cleaned: String = value.strip_edges()
	if cleaned.is_empty():
		return ""

	cleaned = cleaned.replace(" Prime", "")
	cleaned = cleaned.replace(" prime", "")
	cleaned = _limit_punctuation(cleaned)
	cleaned = _trim_consonant_runs(cleaned)
	cleaned = _trim_repeated_vowels(cleaned)
	cleaned = _cap_rare_markers(cleaned, region)
	cleaned = _enforce_name_bounds(cleaned, 13)
	if not _contains_vowel(cleaned):
		cleaned += "a"
	if cleaned.length() < 4:
		cleaned += "ra"
	return _capitalize_name(cleaned)


func _limit_punctuation(value: String) -> String:
	var cleaned: String = value
	var hyphen_count: int = cleaned.count("-")
	var apostrophe_count: int = cleaned.count("'")
	if hyphen_count + apostrophe_count <= 1:
		return cleaned

	var first_hyphen: int = cleaned.find("-")
	var first_apostrophe: int = cleaned.find("'")
	var keep_hyphen: bool = first_hyphen != -1 and (first_apostrophe == -1 or first_hyphen < first_apostrophe)
	var keep_char: String = "-" if keep_hyphen else "'"
	var used_keep: bool = false
	var rebuilt: Array[String] = []
	for i in range(cleaned.length()):
		var ch: String = cleaned.substr(i, 1)
		if ch == "-" or ch == "'":
			if ch == keep_char and not used_keep:
				rebuilt.append(ch)
				used_keep = true
			continue
		rebuilt.append(ch)
	return "".join(rebuilt)


func _trim_consonant_runs(value: String) -> String:
	var rebuilt: Array[String] = []
	var run: int = 0
	for i in range(value.length()):
		var ch: String = value.substr(i, 1)
		if _is_letter(ch) and not _is_vowel(ch):
			run += 1
			if run > 2:
				continue
		else:
			run = 0
		rebuilt.append(ch)
	return "".join(rebuilt)


func _trim_repeated_vowels(value: String) -> String:
	var rebuilt: Array[String] = []
	var run: int = 0
	for i in range(value.length()):
		var ch: String = value.substr(i, 1)
		if _is_vowel(ch):
			run += 1
			if run > 2:
				continue
		else:
			run = 0
		rebuilt.append(ch)
	return "".join(rebuilt)


func _cap_rare_markers(value: String, region: String) -> String:
	var out: String = value
	var max_rare: int = 2
	if _STRICT_REGIONS.has(region):
		max_rare = 1
	var rare_tokens: Array[String] = ["qh", "zh", "gh", "q", "x", "z", "yy"]
	var rare_count: int = 0
	for token in rare_tokens:
		var search_from: int = 0
		while true:
			var idx: int = out.find(token, search_from)
			if idx == -1:
				break
			rare_count += 1
			if rare_count > max_rare:
				out = "%s%s%s" % [out.substr(0, idx), "n", out.substr(idx + token.length())]
				search_from = idx + 1
			else:
				search_from = idx + token.length()
	return out


func _contains_vowel(value: String) -> bool:
	for i in range(value.length()):
		if _is_vowel(value.substr(i, 1)):
			return true
	return false


func _is_vowel(ch: String) -> bool:
	return ["a", "e", "i", "o", "u", "A", "E", "I", "O", "U", "y", "Y"].has(ch)


func _is_letter(ch: String) -> bool:
	var lowered: String = ch.to_lower()
	return lowered >= "a" and lowered <= "z"


func _generate_sector_name(base: Dictionary, region: String) -> Dictionary:
	var smooth_root: String = _soften_for_sector(String(base.get("name", "")))
	var out: Dictionary = base.duplicate(true)
	out["name"] = "%s Sector" % smooth_root
	out["structural_pattern"] = "SmoothRoot+Sector"
	return _with_metadata(out, region, OBJECT_SECTOR)


func _generate_corporate_colony_name(base: Dictionary, region: String) -> Dictionary:
	var corporate_name: String = "%s%s" % [String(base.get("name", "")), _weighted_choice(_to_weighted_strings(_CORPORATE_TAGS))]
	var out: Dictionary = base.duplicate(true)
	out["name"] = corporate_name
	out["structural_pattern"] = "RegionalBase+CorporateTag"
	return _with_metadata(out, region, OBJECT_CORPORATE_COLONY)


func _mutate_system_root(root_name: String, region: String, era: String) -> String:
	if region == "Core Worlds" and _rng.randf() <= 0.55:
		return _attach_suffix(root_name, _core_suffixes(era), false)
	if _rng.randf() <= 0.30:
		return "%s Prime" % root_name
	return root_name


func _build_distinct_system_root(base: Dictionary, base_name: String, region: String, era: String) -> String:
	var candidate: String = _mutate_system_root(base_name, region, era)
	for _attempt in range(4):
		if _is_distinct_system_root(candidate, base_name):
			return candidate
		candidate = _generate_alt_system_root(base, region, era)
	return candidate


func _generate_alt_system_root(base: Dictionary, region: String, era: String) -> String:
	var profile: Dictionary = (base.get("phoneme_profile", {}) as Dictionary).duplicate(true)
	if profile.is_empty():
		var fallback: Dictionary = _region_dispatch.get(region, Callable(self, "_generate_unknown_regions_name")).call(OBJECT_PLANET, {}, era)
		return String(fallback.get("name", ""))
	var alt_result: Dictionary = _generate_with_profile(profile)
	return String(alt_result.get("name", ""))


func _is_distinct_system_root(candidate: String, base_name: String) -> bool:
	var cleaned_candidate: String = _normalize_system_root(candidate).to_lower()
	var cleaned_base: String = _normalize_system_root(base_name).to_lower()
	if cleaned_candidate == cleaned_base:
		return false
	if cleaned_candidate.begins_with(cleaned_base) or cleaned_base.begins_with(cleaned_candidate):
		return false
	return true


func _generate_core_worlds_name(_object_type: String, _modifier: Dictionary, era: String) -> Dictionary:
	var profile: Dictionary = {
		"region": "Core Worlds",
		"onset": _to_weighted_strings(["l", "r", "n", "m", "v", "s", "c", "t"]),
		"nucleus": _to_weighted_strings(["a", "e", "i", "o", "u", "ae", "ia", "eo"]),
		"coda": _to_weighted_strings(["n", "m", "r", "s", "l", "um", "on", ""]),
		"syllable_weights": [{"v": 2, "w": 0.58}, {"v": 3, "w": 0.30}, {"v": 4, "w": 0.12}],
		"hyphen_probability": 0.0,
		"apostrophe_probability": 0.0,
		"allow_clusters": false,
		"allow_repetition": false,
		"illegal_clusters": ["zx", "qk", "gh", "kk", "rrr"],
		"rare_phonemes": ["x", "q", "gh", "zh"],
		"classical_suffixes": _core_suffixes(era),
	}
	return _generate_with_profile(profile)


func _generate_colonies_name(_object_type: String, _modifier: Dictionary, era: String) -> Dictionary:
	var profile: Dictionary = _generate_core_worlds_name(OBJECT_PLANET, {}, era).get("phoneme_profile", {}).duplicate(true)
	profile["region"] = "Colonies"
	profile["onset"] = _to_weighted_strings(["l", "r", "n", "m", "v", "s", "d", "t", "k", "c"])
	profile["syllable_weights"] = [{"v": 2, "w": 0.72}, {"v": 3, "w": 0.28}]
	profile["compound_merge_probability"] = 0.18
	profile["minor_suffix_variation_probability"] = 0.08
	return _generate_with_profile(profile)


func _generate_inner_rim_name(_object_type: String, _modifier: Dictionary, _era: String) -> Dictionary:
	var profile: Dictionary = {
		"region": "Inner Rim",
		"onset": _to_weighted_strings(["b", "c", "d", "f", "g", "k", "l", "m", "n", "r", "s", "t", "v"]),
		"nucleus": _to_weighted_strings(["a", "e", "i", "o", "u", "ai", "ei", "oa"]),
		"coda": _to_weighted_strings(["n", "r", "t", "s", "k", "ld", "rd", ""]),
		"syllable_weights": [{"v": 2, "w": 0.52}, {"v": 3, "w": 0.38}, {"v": 4, "w": 0.10}],
		"hyphen_probability": 0.07,
		"apostrophe_probability": 0.03,
		"functional_suffix_probability": 0.20,
		"functional_suffixes": _to_weighted_strings(["port", "hold", "plex", "gate"]),
		"allow_clusters": true,
		"allow_repetition": false,
		"illegal_clusters": ["qq", "zx", "ghq"],
		"rare_phonemes": ["x", "q", "gh"],
	}
	return _generate_with_profile(profile)


func _generate_mid_rim_name(_object_type: String, _modifier: Dictionary, _era: String) -> Dictionary:
	var profile: Dictionary = {
		"region": "Mid Rim",
		"onset": _to_weighted_strings(["b", "g", "d", "k", "m", "n", "r", "s", "t", "v"]),
		"nucleus": _to_weighted_strings(["a", "e", "i", "o", "u", "ia", "oa"]),
		"coda": _to_weighted_strings(["n", "k", "d", "r", "th", ""]),
		"syllable_weights": [{"v": 2, "w": 0.64}, {"v": 3, "w": 0.36}],
		"hyphen_probability": 0.13,
		"apostrophe_probability": 0.04,
		"allow_clusters": true,
		"allow_repetition": false,
		"illegal_clusters": ["qq", "xx", "ghgh"],
		"rare_phonemes": ["x", "q", "gh"],
	}
	return _generate_with_profile(profile)


func _generate_outer_rim_name(_object_type: String, _modifier: Dictionary, _era: String) -> Dictionary:
	var profile: Dictionary = {
		"region": "Outer Rim",
		"onset": _to_weighted_strings(["k", "x", "q", "z", "gh", "r", "t", "m", "n", "v"]),
		"nucleus": _to_weighted_strings(["a", "e", "i", "o", "u", "aa", "oo", "ai"]),
		"coda": _to_weighted_strings(["k", "q", "x", "z", "n", "r", "th", "gh", ""]),
		"syllable_weights": [{"v": 1, "w": 0.28}, {"v": 2, "w": 0.45}, {"v": 3, "w": 0.27}],
		"hyphen_probability": 0.18,
		"apostrophe_probability": 0.20,
		"allow_clusters": true,
		"allow_repetition": false,
		"illegal_clusters": ["qqq", "ghgh", "xxx"],
		"rare_phonemes": ["x", "q", "gh", "zh"],
	}
	return _generate_with_profile(profile)


func _generate_expansion_region_name(_object_type: String, _modifier: Dictionary, _era: String) -> Dictionary:
	var profile: Dictionary = {
		"region": "Expansion Region",
		"onset": _to_weighted_strings(["a", "b", "c", "d", "f", "h", "k", "l", "m", "r", "s", "v"]),
		"nucleus": _to_weighted_strings(["a", "e", "i", "o", "u", "ae", "io"]),
		"coda": _to_weighted_strings(["n", "r", "t", "s", "m", "x", ""]),
		"syllable_weights": [{"v": 2, "w": 0.55}, {"v": 3, "w": 0.45}],
		"hyphen_probability": 0.09,
		"apostrophe_probability": 0.05,
		"allow_clusters": true,
		"allow_repetition": false,
		"illegal_clusters": ["qq", "zzq", "ghgh"],
		"rare_phonemes": ["x", "q", "gh"],
	}
	var out: Dictionary = _generate_with_profile(profile)
	var body_name: String = String(out.get("name", ""))
	if _rng.randf() <= 0.40:
		var prefixes: Array[String] = ["Aurek-", "BX-", "V-", "Rho-"]
		body_name = "%s%s" % [prefixes[_rng.randi_range(0, prefixes.size() - 1)], body_name]
	if _rng.randf() <= 0.30:
		body_name = "%s %s" % [body_name, _weighted_choice(_GENERIC_NUMERAL_SUFFIXES)]
	if _rng.randf() <= 0.22:
		body_name = "%s Prime" % body_name
	out["name"] = body_name
	out["structural_pattern"] = "Prefix+GeneratedName+OptionalNumeral"
	return out


func _generate_hutt_space_name(_object_type: String, _modifier: Dictionary, _era: String) -> Dictionary:
	var profile: Dictionary = {
		"region": "Hutt Space",
		"onset": _to_weighted_strings(["g", "b", "k", "h", "gr", "kr", "gg", "bb", "kk"]),
		"nucleus": _to_weighted_strings(["a", "o", "u", "aa", "uu", "oo"]),
		"coda": _to_weighted_strings(["g", "k", "bb", "gg", "rk", "m", ""]),
		"syllable_weights": [{"v": 2, "w": 0.40}, {"v": 3, "w": 0.42}, {"v": 4, "w": 0.18}],
		"hyphen_probability": 0.04,
		"apostrophe_probability": 0.06,
		"allow_clusters": true,
		"allow_repetition": true,
		"illegal_clusters": ["ia", "eus", "ara"],
		"rare_phonemes": ["x", "q", "zh"],
	}
	var out: Dictionary = _generate_with_profile(profile)
	if _rng.randf() <= 0.25:
		out["name"] = "%sa" % String(out.get("name", ""))
	return out


func _generate_unknown_regions_name(_object_type: String, _modifier: Dictionary, _era: String) -> Dictionary:
	var profile: Dictionary = {
		"region": "Unknown Regions",
		"onset": _to_weighted_strings(["zr", "qh", "x", "tl", "vr", "kz", "gh", "dr", "m", "n"]),
		"nucleus": _to_weighted_strings(["a", "e", "i", "o", "u", "ae", "ui", "oa", "yy"]),
		"coda": _to_weighted_strings(["q", "x", "zh", "r", "n", "th", "lk", ""]),
		"syllable_weights": [{"v": 3, "w": 0.45}, {"v": 4, "w": 0.35}, {"v": 5, "w": 0.20}],
		"hyphen_probability": 0.25,
		"apostrophe_probability": 0.35,
		"allow_clusters": true,
		"allow_repetition": false,
		"illegal_clusters": ["qqqq", "xxxx", "ghghgh"],
		"rare_phonemes": ["q", "x", "zh", "yy", "qh"],
	}
	return _generate_with_profile(profile)


func _generate_with_profile(profile: Dictionary) -> Dictionary:
	var syllable_count: int = int(_weighted_choice(profile.get("syllable_weights", [{"v": 2, "w": 1.0}])))
	var syllables: Array[String] = []
	var pattern_parts: Array[String] = []
	var rare_count: int = 0
	var allow_repeat: bool = bool(profile.get("allow_repetition", false))

	for _i in range(syllable_count):
		var syllable_data: Dictionary = _build_syllable(profile)
		var syllable: String = String(syllable_data.get("syllable", ""))
		var attempts: int = 0
		while attempts < 8 and (syllable.is_empty() or (not allow_repeat and syllables.has(syllable))):
			syllable_data = _build_syllable(profile)
			syllable = String(syllable_data.get("syllable", ""))
			attempts += 1
		if syllable.is_empty():
			syllable = "na"

		rare_count += int(syllable_data.get("rare_count", 0))
		if rare_count > 2:
			syllable = _remove_rare_markers(syllable, profile)
			rare_count = 2
		syllables.append(syllable)
		pattern_parts.push_back(String(syllable_data.get("pattern", "ON")))

	var name: String = "".join(syllables)
	name = _inject_punctuation(name, profile)

	if profile.has("classical_suffixes") and _rng.randf() <= 0.62:
		name = _attach_suffix(name, profile.get("classical_suffixes", []), false)

	if profile.has("minor_suffix_variation_probability") and _rng.randf() <= float(profile.get("minor_suffix_variation_probability", 0.0)):
		name = _attach_suffix(name, [{"v": "is", "w": 1.0}, {"v": "ar", "w": 0.8}, {"v": "et", "w": 0.7}], true)

	if profile.has("compound_merge_probability") and _rng.randf() <= float(profile.get("compound_merge_probability", 0.0)):
		var bridge: String = "" if _rng.randf() < 0.55 else "a"
		name = "%s%s%s" % [name, bridge, _capitalize_name(String(_build_syllable(profile).get("syllable", "na")))]

	if profile.has("functional_suffix_probability") and _rng.randf() <= float(profile.get("functional_suffix_probability", 0.0)):
		name = "%s-%s" % [name, _weighted_choice(profile.get("functional_suffixes", []))]

	name = _capitalize_name(name)
	name = _enforce_name_bounds(name)
	return {
		"name": name,
		"region": String(profile.get("region", "Unknown Regions")),
		"object_type": OBJECT_PLANET,
		"phoneme_profile": profile.duplicate(true),
		"structural_pattern": "%s syllables: %s" % [str(syllable_count), "-".join(pattern_parts)],
	}


func _build_syllable(profile: Dictionary) -> Dictionary:
	var onset: String = _weighted_choice(profile.get("onset", []))
	var nucleus: String = _weighted_choice(profile.get("nucleus", []))
	var coda: String = _weighted_choice(profile.get("coda", []))
	var include_coda: bool = not coda.is_empty() and _rng.randf() <= 0.60
	var allow_clusters: bool = bool(profile.get("allow_clusters", true))

	if not allow_clusters and onset.length() > 1:
		onset = onset.substr(0, 1)
	if include_coda and not allow_clusters and coda.length() > 1:
		coda = coda.substr(0, 1)

	var illegal_clusters: Array = profile.get("illegal_clusters", []) as Array
	if illegal_clusters.has(onset + coda):
		coda = ""
		include_coda = false

	var syllable: String = "%s%s%s" % [onset, nucleus, coda if include_coda else ""]
	var rare_count: int = _count_rare_phonemes(syllable, profile)
	var pattern: String = "ONC" if include_coda else "ON"
	if onset.is_empty():
		pattern = "NC" if include_coda else "N"
	return {
		"syllable": syllable,
		"rare_count": rare_count,
		"pattern": pattern,
	}


func _remove_rare_markers(syllable: String, profile: Dictionary) -> String:
	var result: String = syllable
	var rare_pool: Array = profile.get("rare_phonemes", []) as Array
	for rare in rare_pool:
		var marker: String = String(rare)
		if result.find(marker) != -1:
			result = result.replacen(marker, "n")
	return result


func _inject_punctuation(name: String, profile: Dictionary) -> String:
	var working: String = name
	var apostrophe_probability: float = float(profile.get("apostrophe_probability", 0.0))
	if apostrophe_probability > 0.0 and _rng.randf() <= apostrophe_probability and working.length() >= 4:
		var split_index: int = _rng.randi_range(1, working.length() - 2)
		working = "%s'%s" % [working.substr(0, split_index), working.substr(split_index)]

	var hyphen_probability: float = float(profile.get("hyphen_probability", 0.0))
	if hyphen_probability > 0.0 and _rng.randf() <= hyphen_probability and working.length() >= 6:
		var hyphen_index: int = _rng.randi_range(2, working.length() - 3)
		if working[hyphen_index - 1] != "'" and working[hyphen_index] != "'":
			working = "%s-%s" % [working.substr(0, hyphen_index), working.substr(hyphen_index)]

	return working


func _core_suffixes(era: String) -> Array[Dictionary]:
	var suffixes: Array[Dictionary] = _CORE_CLASSICAL_SUFFIXES.duplicate(true)
	if era == "Old Republic":
		for entry_v in suffixes:
			var entry: Dictionary = entry_v as Dictionary
			entry["w"] = float(entry.get("w", 1.0)) * 1.55
	return suffixes


func _with_metadata(data: Dictionary, region: String, object_type: String) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	out["region"] = region
	out["object_type"] = object_type
	if not out.has("phoneme_profile"):
		out["phoneme_profile"] = {}
	if not out.has("structural_pattern"):
		out["structural_pattern"] = "default"
	return out


func _capitalize_name(value: String) -> String:
	if value.is_empty():
		return value
	var pieces := value.split(" ", false)
	for i in range(pieces.size()):
		var p: String = pieces[i]
		if p.is_empty():
			continue
		var segments := p.split("-", false)
		for s in range(segments.size()):
			if segments[s].is_empty():
				continue
			segments[s] = segments[s].substr(0, 1).to_upper() + segments[s].substr(1).to_lower()
		pieces[i] = "-".join(segments)
	return " ".join(pieces)


func _soften_for_sector(value: String) -> String:
	var softened: String = value.replace("x", "s").replace("q", "k").replace("gh", "g")
	return softened.replace("-", "")


func _short_alien_derivative(base_name: String) -> String:
	var trimmed: String = base_name.strip_edges().replace(" ", "")
	if trimmed.length() <= 3:
		trimmed = "%sra" % trimmed
	var start: int = maxi(0, trimmed.length() - 3)
	return _capitalize_name("%s%s" % [trimmed.substr(start), ["ra", "qi", "vek", "tor"][_rng.randi_range(0, 3)]])


func _count_rare_phonemes(value: String, profile: Dictionary) -> int:
	var count: int = 0
	for rare_v in profile.get("rare_phonemes", []):
		var rare: String = String(rare_v)
		if value.find(rare) != -1:
			count += 1
	return count


func _attach_suffix(name: String, suffix_pool: Array, mutate_tail: bool) -> String:
	var suffix: String = _weighted_choice(suffix_pool)
	var base: String = name
	if mutate_tail and base.length() > 2:
		base = base.substr(0, base.length() - 1)
	return "%s%s" % [base, suffix]


func _normalize_system_root(value: String) -> String:
	var normalized: String = value.strip_edges()
	if normalized.is_empty():
		normalized = "Unnamed"

	if normalized.to_lower().ends_with(" system"):
		normalized = normalized.substr(0, normalized.length() - 7).strip_edges()
	normalized = _condense_repeated_words(normalized)
	normalized = _enforce_name_bounds(normalized, 24)
	if normalized.is_empty():
		normalized = "Unnamed"
	return normalized


func _condense_repeated_words(value: String) -> String:
	var words: Array[String] = []
	for word_v in value.split(" ", false):
		var word: String = String(word_v).strip_edges()
		if word.is_empty():
			continue
		if words.is_empty() or words[words.size() - 1].to_lower() != word.to_lower():
			words.append(word)
	return " ".join(words)


func _enforce_name_bounds(value: String, max_length: int = 22) -> String:
	if value.length() <= max_length:
		return value

	var shortened: String = value.substr(0, max_length)
	var last_separator: int = maxi(shortened.rfind(" "), shortened.rfind("-"))
	if last_separator >= 6:
		shortened = shortened.substr(0, last_separator)
	shortened = shortened.strip_edges()
	while shortened.ends_with("-"):
		shortened = shortened.substr(0, shortened.length() - 1).strip_edges()
	return shortened


func _weighted_choice(weighted_pool: Array) -> Variant:
	if weighted_pool.is_empty():
		return ""
	var total: float = 0.0
	for entry_v in weighted_pool:
		var entry: Dictionary = entry_v as Dictionary
		total += float(entry.get("w", 1.0))
	if total <= 0.0:
		return (weighted_pool[0] as Dictionary).get("v", "")

	var roll: float = _rng.randf() * total
	var running: float = 0.0
	for entry_v in weighted_pool:
		var entry: Dictionary = entry_v as Dictionary
		running += float(entry.get("w", 1.0))
		if roll <= running:
			return entry.get("v", "")
	return (weighted_pool[weighted_pool.size() - 1] as Dictionary).get("v", "")


func _to_weighted_strings(values: Array) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for i in range(values.size()):
		var v: Variant = values[i]
		if v is Dictionary:
			pool.append((v as Dictionary).duplicate(true))
		else:
			var weight: float = 1.0
			if i <= 2:
				weight = 1.2
			pool.append({"v": String(v), "w": weight})
	return pool


func _to_roman(value: int) -> String:
	var num: int = maxi(1, value)
	var chunks: Array[Dictionary] = [
		{"n": 1000, "r": "M"}, {"n": 900, "r": "CM"}, {"n": 500, "r": "D"}, {"n": 400, "r": "CD"},
		{"n": 100, "r": "C"}, {"n": 90, "r": "XC"}, {"n": 50, "r": "L"}, {"n": 40, "r": "XL"},
		{"n": 10, "r": "X"}, {"n": 9, "r": "IX"}, {"n": 5, "r": "V"}, {"n": 4, "r": "IV"}, {"n": 1, "r": "I"},
	]
	var out: String = ""
	for chunk_v in chunks:
		var chunk: Dictionary = chunk_v as Dictionary
		var n: int = int(chunk.get("n", 0))
		var r: String = String(chunk.get("r", ""))
		while num >= n:
			out += r
			num -= n
	return out
