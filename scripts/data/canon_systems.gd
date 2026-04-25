extends RefCounted
class_name CanonSystemData

const CanonSettlementData = preload("res://scripts/data/canon_settlements.gd")

# Canon star systems used to populate the Galaxy map.
#
# How to add a new system entry:
# 1) Add a new dictionary to SYSTEMS in alphabetical order by system_name.
# 2) Set system_name, region, and position for the system's galactic coordinates.
# 3) Add one or more planet dictionaries inside planets (name + planetary_type + optional moons).
# 4) Optionally add stars for binary systems in stars, and list hyperspace lanes in lanes.

const SYSTEMS: Array[Dictionary] = [
	{
		"system_name": "Alderaan",
		"region": "Core Worlds",
		"position": Vector2(1942.44, -89.52),
		"lanes": ["Commenor Run"],
		"planets": [
			{
				"name": "Alderaan",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Alpheridies",
		"region": "Expansion Region",
		"position": Vector2(5416.89, 2750.36),
		"lanes": [],
		"planets": [
			{
				"name": "Alpheridies",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Alsakan",
		"region": "Core Worlds",
		"position": Vector2(258.31, 163.75),
		"lanes": ["Perlimian Trade Route"],
		"planets": [
			{
				"name": "Alsakan",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Anaxes",
		"region": "Core Worlds",
		"position": Vector2(615.70, 374.39),
		"lanes": ["Perlimian Trade Route"],
		"planets": [
			{
				"name": "Anaxes",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Ando",
		"region": "Mid Rim",
		"position": Vector2(7887.52, -8964.55),
		"lanes": [],
		"planets": [
			{
				"name": "Ando",
				"planetary_type": "Oceanic World",
			},
		],
	},
	{
		"system_name": "Arkania",
		"region": "Colonies",
		"position": Vector2(1644.51, 1519.03),
		"lanes": [],
		"planets": [
			{
				"name": "Arkania",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Balmorra",
		"region": "Colonies",
		"position": Vector2(2801.73, -870.01),
		"lanes": [],
		"planets": [
			{
				"name": "Balmorra",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Balosar",
		"region": "Core Worlds",
		"position": Vector2(1013.95, -3776.22),
		"lanes": [],
		"planets": [
			{
				"name": "Balosar",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Botajef",
		"region": "Outer Rim",
		"position": Vector2(5171.65, 5272.20),
		"lanes": ["Hydian Way", "Salin Corridor", "Celanon Spur"],
		"planets": [
			{
				"name": "Botajef",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Bothawui",
		"region": "Mid Rim",
		"position": Vector2(9333.19, -6509.97),
		"lanes": ["Kaaga Run", "Manda Merchant Route", "Reena Trade Route", "Bothan Run"],
		"planets": [
			{
				"name": "Bothawui",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Brentaal IV",
		"region": "Core Worlds",
		"position": Vector2(907.48, 538.41),
		"lanes": ["Hydian Way", "Commenor Run", "Perlimian Trade Route"],
		"planets": [
			{
				"name": "Brentaal IV",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Byss",
		"region": "Deep Core",
		"position": Vector2(11830.86, 4249.51),
		"lanes": [],
		"planets": [
			{
				"name": "Byss",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Caamas",
		"region": "Core Worlds",
		"position": Vector2(1705.44, 106.30),
		"lanes": ["Commenor Run"],
		"planets": [
			{
				"name": "Caamas",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Cathar",
		"region": "Outer Rim",
		"position": Vector2(4268.69, 5622.43),
		"lanes": [],
		"planets": [
			{
				"name": "Cathar",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Centares",
		"region": "Mid Rim",
		"position": Vector2(9579.76, 3980.44),
		"lanes": ["Perlimian Trade Route", "Triellus Trade Route"],
		"planets": [
			{
				"name": "Centares",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Cerea",
		"region": "Mid Rim",
		"position": Vector2(-3636.41, -9964.51),
		"lanes": ["Cerean Reach"],
		"planets": [
			{
				"name": "Cerea",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Chad",
		"region": "Outer Rim",
		"position": Vector2(10065.14, 3958.71),
		"lanes": [],
		"planets": [
			{
				"name": "Chad",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Champala",
		"region": "Inner Rim",
		"position": Vector2(1070.59, 1939.60),
		"lanes": ["Hydian Way"],
		"planets": [
			{
				"name": "Champala",
				"planetary_type": "Oceanic World",
			},
		],
	},
	{
		"system_name": "Chandrila",
		"region": "Core Worlds",
		"position": Vector2(829.79, 488.34),
		"lanes": ["Perlimian Trade Route"],
		"planets": [
			{
				"name": "Chandrila",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Columex",
		"region": "Outer Rim",
		"position": Vector2(10132.07, 4916.87),
		"lanes": ["Perlimian Trade Route", "Salin Corridor"],
		"planets": [
			{
				"name": "Columex",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Concord Dawn",
		"region": "Outer Rim",
		"position": Vector2(5246.88, 3735.21),
		"lanes": [],
		"planets": [
			{
				"name": "Concord Dawn",
				"planetary_type": "Mineral-Rich Barren",
			},
		],
	},
	{
		"system_name": "Corellia",
		"region": "Core Worlds",
		"position": Vector2(2363.29, -2790.57),
		"lanes": ["Corellian Run", "Corellian Trade Spine"],
		"planets": [
			{
				"name": "Corellia",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Coruscant",
		"region": "Core Worlds",
		"position": Vector2(0.00, 0.00),
		"lanes": ["Perlimian Trade Route", "Corellian Run", "Namadii Corridor"],
		"planets": [
			{
				"name": "Coruscant",
				"planetary_type": "Ecumenopolis",
				"elements": CanonSettlementData.CORUSCANT_ELEMENTS,
				"infrastructures": CanonSettlementData.CORUSCANT_INFRASTRUCTURES,
			},
		],
	},
	{
		"system_name": "D'ian",
		"region": "Outer Rim",
		"position": Vector2(10994.54, 9057.75),
		"lanes": ["Hydian Way"],
		"planets": [
			{
				"name": "D'ian",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Dantooine",
		"region": "Outer Rim",
		"position": Vector2(14.70, 8378.27),
		"lanes": ["Nond"],
		"planets": [
			{
				"name": "Dantooine",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Dathomir",
		"region": "Outer Rim",
		"position": Vector2(4716.60, 5436.59),
		"lanes": [],
		"planets": [
			{
				"name": "Dathomir",
				"planetary_type": "Volcanic World",
			},
		],
	},
	{
		"system_name": "Devaron",
		"region": "Colonies",
		"position": Vector2(1805.72, -5596.76),
		"lanes": [],
		"planets": [
			{
				"name": "Devaron",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Dorin",
		"region": "Expansion Region",
		"position": Vector2(-2125.42, 2890.85),
		"lanes": ["Celanon Spur", "Namadii Corridor"],
		"planets": [
			{
				"name": "Dorin",
				"planetary_type": "Gas Giant (Habitat Moons)",
			},
		],
	},
	{
		"system_name": "Druckenwell",
		"region": "Mid Rim",
		"position": Vector2(6558.09, -8009.17),
		"lanes": ["Reena Trade Route", "Corellian Run"],
		"planets": [
			{
				"name": "Druckenwell",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Duro",
		"region": "Core Worlds",
		"position": Vector2(2356.53, -2801.96),
		"lanes": [],
		"planets": [
			{
				"name": "Duro",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Empress Teta (Koros Major)",
		"region": "Deep Core",
		"position": Vector2(29.80, -782.05),
		"lanes": [],
		"planets": [
			{
				"name": "Empress Teta (Koros Major)",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Gamor",
		"region": "Expansion Region",
		"position": Vector2(5253.68, -6620.71),
		"lanes": ["Corellian Run", "Gamor Run"],
		"planets": [
			{
				"name": "Gamor",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Geonosis",
		"region": "Outer Rim",
		"position": Vector2(9674.40, -10099.46),
		"lanes": ["Triellus Trade Route"],
		"planets": [
			{
				"name": "Geonosis",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Glee Ansel",
		"region": "Mid Rim",
		"position": Vector2(-2704.24, 3588.22),
		"lanes": [],
		"planets": [
			{
				"name": "Glee Ansel",
				"planetary_type": "Oceanic World",
			},
		],
	},
	{
		"system_name": "Iktotch",
		"region": "Expansion Region",
		"position": Vector2(5190.14, -6096.57),
		"lanes": [],
		"planets": [
			{
				"name": "Iktotch",
				"planetary_type": "Volcanic World",
			},
		],
	},
	{
		"system_name": "Ilum",
		"region": "Unknown Regions",
		"position": Vector2(-6195.20, 3684.63),
		"lanes": [],
		"planets": [
			{
				"name": "Ilum",
				"planetary_type": "Ice World",
			},
		],
	},
	{
		"system_name": "Iridonia",
		"region": "Mid Rim",
		"position": Vector2(-1731.82, 4403.40),
		"lanes": [],
		"planets": [
			{
				"name": "Iridonia",
				"planetary_type": "Volcanic World",
			},
		],
	},
	{
		"system_name": "Ithor",
		"region": "Mid Rim",
		"position": Vector2(1663.23, 4825.10),
		"lanes": ["Celanon Spur"],
		"planets": [
			{
				"name": "Ithor",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Kalee",
		"region": "Outer Rim",
		"position": Vector2(-2460.16, 8495.55),
		"lanes": [],
		"planets": [
			{
				"name": "Kalee",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Kamino",
		"region": "Outer Rim",
		"position": Vector2(10657.33, -7961.67),
		"lanes": [],
		"planets": [
			{
				"name": "Kamino",
				"planetary_type": "Oceanic World",
			},
		],
	},
	{
		"system_name": "Kashyyyk",
		"region": "Mid Rim",
		"position": Vector2(7087.76, 167.46),
		"lanes": ["Randon Run", "Great Kashyyyk Branch", "Trellen Trade Route"],
		"planets": [
			{
				"name": "Kashyyyk",
				"planetary_type": "Agri-World",
			},
			{
				"name": "Transhodan",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Kerkoidia",
		"region": "Expansion Region",
		"position": Vector2(4264.60, -8911.33),
		"lanes": [],
		"planets": [
			{
				"name": "Kerkoidia",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Kinyen",
		"region": "Expansion Region",
		"position": Vector2(161.25, -8909.49),
		"lanes": ["Great Gran Run", "Corellian Trade Spine"],
		"planets": [
			{
				"name": "Kinyen",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Klatooine",
		"region": "Hutt Space",
		"position": Vector2(11616.00, 1443.82),
		"lanes": [],
		"planets": [
			{
				"name": "Klatooine",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Korriban",
		"region": "Outer Rim",
		"position": Vector2(9254.62, 6991.44),
		"lanes": [],
		"planets": [
			{
				"name": "Korriban",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Kuat",
		"region": "Core Worlds",
		"position": Vector2(2789.98, -896.57),
		"lanes": [],
		"planets": [
			{
				"name": "Kuat",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Malachor V",
		"region": "Outer Rim",
		"position": Vector2(10801.71, 7867.55),
		"lanes": [],
		"planets": [
			{
				"name": "Malachor V",
				"planetary_type": "Volcanic World",
			},
		],
	},
	{
		"system_name": "Malastare",
		"region": "Mid Rim",
		"position": Vector2(3124.93, -10253.47),
		"lanes": ["Hydian Way"],
		"planets": [
			{
				"name": "Malastare",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Manaan",
		"region": "Inner Rim",
		"position": Vector2(4769.58, -2162.90),
		"lanes": [],
		"planets": [
			{
				"name": "Manaan",
				"planetary_type": "Oceanic World",
			},
		],
	},
	{
		"system_name": "Manda",
		"region": "Mid Rim",
		"position": Vector2(10231.89, -7563.65),
		"lanes": ["Manda Merchant Route"],
		"planets": [
			{
				"name": "Manda",
				"planetary_type": "Agri-Wold",
			},
		],
	},
	{
		"system_name": "Mandalore",
		"region": "Outer Rim",
		"position": Vector2(5451.78, 4083.17),
		"lanes": [],
		"planets": [
			{
				"name": "Mandalore",
				"planetary_type": "Mineral-Rich Barren",
			},
		],
	},
	{
		"system_name": "Molavar",
		"region": "Outer Rim",
		"position": Vector2(10984.37, -8374.63),
		"lanes": ["Triellus Trade Route", "Manda Merchant Route"],
		"planets": [
			{
				"name": "Molavar",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Mon Cala",
		"region": "Outer Rim",
		"position": Vector2(13608.12, 4951.81),
		"lanes": [],
		"planets": [
			{
				"name": "Mon Cala",
				"planetary_type": "Oceanic World",
			},
		],
	},
	{
		"system_name": "Naboo",
		"region": "Mid Rim",
		"position": Vector2(5016.62, -10608.46),
		"lanes": ["Enarc Run"],
		"planets": [
			{
				"name": "Naboo",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Nal Hutta",
		"region": "Hutt Space",
		"position": Vector2(10559.83, -3087.10),
		"lanes": ["Shag Pabol", "Pabol Hutta", "Ootmian Pabol"],
		"planets": [
			{
				"name": "Nal Hutta",
				"planetary_type": "Oceanic World",
			},
			{
				"name": "Nar Shaddaa",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Onderon",
		"region": "Inner Rim",
		"position": Vector2(5559.23, 261.08),
		"lanes": ["Lesser Lantillian Route"],
		"planets": [
			{
				"name": "Onderon",
				"planetary_type": "Agri-World",
			},
			{
				"name": "Dxun",
				"planetary_type": "Mineral-Rich Barren",
			},
		],
	},
	{
		"system_name": "Ord Mantell",
		"region": "Mid Rim",
		"position": Vector2(71.13, 3824.46),
		"lanes": ["Celanon Spur"],
		"planets": [
			{
				"name": "Ord Mantell",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Ossus",
		"region": "Outer Rim",
		"position": Vector2(10492.62, 4785.04),
		"lanes": [],
		"planets": [
			{
				"name": "Ossus",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Peragus II",
		"region": "Outer Rim",
		"position": Vector2(8717.40, 8899.66),
		"lanes": [],
		"planets": [
			{
				"name": "Peragus II",
				"planetary_type": "Mineral-Rich Barren",
			},
		],
	},
	{
		"system_name": "Quermia",
		"region": "Outer Rim",
		"position": Vector2(11426.25, 6944.72),
		"lanes": ["Perlimian Trade Route", "Overic Griplink"],
		"planets": [
			{
				"name": "Quermia",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Rodia",
		"region": "Outer Rim",
		"position": Vector2(8960.03, -9968.31),
		"lanes": [],
		"planets": [
			{
				"name": "Rodia",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Ryloth",
		"region": "Outer Rim",
		"position": Vector2(10069.18, -11430.32),
		"lanes": [],
		"planets": [
			{
				"name": "Ryloth",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Shili",
		"region": "Expansion Region",
		"position": Vector2(1054.10, 2844.68),
		"lanes": [],
		"planets": [
			{
				"name": "Shili",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Sleheyron",
		"region": "Hutt Space",
		"position": Vector2(11546.75, -339.46),
		"lanes": ["Pabol Sleheyron", "Pabol Hutta"],
		"planets": [
			{
				"name": "Sleheyron",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Sriluur",
		"region": "Outer Rim",
		"position": Vector2(11635.18, 1694.73),
		"lanes": ["Pabol Hutta"],
		"planets": [
			{
				"name": "Sriluur",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Sullust",
		"region": "Outer Rim",
		"position": Vector2(2340.41, -11719.53),
		"lanes": ["Rimma Trade Route"],
		"planets": [
			{
				"name": "Sullust",
				"planetary_type": "Volcanic World",
			},
		],
	},
	{
		"system_name": "Taris",
		"region": "Outer Rim",
		"position": Vector2(4077.09, 4354.77),
		"lanes": [],
		"planets": [
			{
				"name": "Taris",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Taris (Destroyed)",
		"region": "Outer Rim",
		"position": Vector2(4077.09, 4354.77),
		"lanes": [],
		"planets": [
			{
				"name": "Taris (Destroyed)",
				"planetary_type": "Destroyed",
			},
		],
	},
	{
		"system_name": "Tatooine",
		"region": "Outer Rim",
		"position": Vector2(9665.78, -10099.11),
		"lanes": ["Triellus Trade Route"],
		"planets": [
			{
				"name": "Tatooine",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Telos IV",
		"region": "Outer Rim",
		"position": Vector2(7619.19, 8564.88),
		"lanes": ["Hydian Way"],
		"planets": [
			{
				"name": "Telos IV",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Thakwaa",
		"region": "Outer Rim",
		"position": Vector2(-3658.12, -13782.79),
		"lanes": [],
		"planets": [
			{
				"name": "Thakwaa",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Toola",
		"region": "Outer Rim",
		"position": Vector2(11697.07, 6959.01),
		"lanes": [],
		"planets": [
			{
				"name": "Toola",
				"planetary_type": "Ice World",
			},
		],
	},
	{
		"system_name": "Tython",
		"region": "Deep Core",
		"position": Vector2(19.19, -1173.87),
		"lanes": [],
		"planets": [
			{
				"name": "Tython",
				"planetary_type": "Oceanic World",
			},
		],
	},
	{
		"system_name": "Uba IV",
		"region": "Mid Rim",
		"position": Vector2(-1631.75, 5066.33),
		"lanes": [],
		"planets": [
			{
				"name": "Uba IV",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Umbara",
		"region": "Inner Rim",
		"position": Vector2(6113.06, -277.35),
		"lanes": ["Trellen Trade Route"],
		"planets": [
			{
				"name": "Umbara",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Utapau",
		"region": "Outer Rim",
		"position": Vector2(3085.86, -14765.72),
		"lanes": [],
		"planets": [
			{
				"name": "Utapau",
				"planetary_type": "Rocky World",
			},
		],
	},
	{
		"system_name": "Vulta",
		"region": "Mid Rim",
		"position": Vector2(3796.74, 3795.87),
		"lanes": [],
		"planets": [
			{
				"name": "Vulta",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Wroona",
		"region": "Inner Rim",
		"position": Vector2(1459.47, -7762.69),
		"lanes": ["Rimma Trade Route", "Harrin Trade Corridor"],
		"planets": [
			{
				"name": "Wroona",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Yavin IV",
		"region": "Outer Rim",
		"position": Vector2(6875.93, 5980.07),
		"lanes": [],
		"planets": [
			{
				"name": "Yavin IV",
				"planetary_type": "Mineral-Rich Barren",
			},
		],
	},
	{
		"system_name": "Zeltros",
		"region": "Inner Rim",
		"position": Vector2(5295.28, -1043.53),
		"lanes": ["Lorell Route", "Trellen Trade Route", "Lesser Lantillian Route"],
		"planets": [
			{
				"name": "Zeltros",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Agamar",
		"region": "Outer Rim",
		"position": Vector2(2186.09, 6295.72),
		"lanes": ["Celanon Spur", "Braxant Run"],
		"planets": [
			{
				"name": "Agamar",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Arkanis",
		"region": "Outer Rim",
		"position": Vector2(9210.78, -10632.78),
		"lanes": ["Corellian Run", "Triellus Trade Route"],
		"planets": [
			{
				"name": "Arkanis",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Bandomeer",
		"region": "Mid Rim",
		"position": Vector2(4785.69, 4833.82),
		"lanes": ["Braxant Run", "Hydian Way"],
		"planets": [
			{
				"name": "Bandomeer",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Boonta",
		"region": "Outer Rim",
		"position": Vector2(11184.94, 2240.06),
		"lanes": ["Pabol Hutta", "Lesser Lantillian Route"],
		"planets": [
			{
				"name": "Boonta",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Charros IV",
		"region": "Outer Rim",
		"position": Vector2(9202.29, 1071.89),
		"lanes": ["Lesser Lantillian Route", "Great Kashyyyk Branch"],
		"planets": [
			{
				"name": "Charros IV",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Commenor",
		"region": "Colonies",
		"position": Vector2(3466.51, -1474.40),
		"lanes": ["Trellen Trade Route", "Commenor Run", "Quellor Run"],
		"planets": [
			{
				"name": "Commenor",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Daalang",
		"region": "Mid Rim",
		"position": Vector2(8505.58, -4079.64),
		"lanes": ["Trax Tube", "Gamor Run", "Bothan Run"],
		"planets": [
			{
				"name": "Daalang",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Denon",
		"region": "Inner Rim",
		"position": Vector2(3418.58, -4748.39),
		"lanes": ["Corellian Run", "Hydian Way"],
		"planets": [
			{
				"name": "Denon",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Eriadu",
		"region": "Outer Rim",
		"position": Vector2(2332.55, -12439.67),
		"lanes": ["Hydian Way", "Rimma Trade Route", "Nothoiin Corridor"],
		"planets": [
			{
				"name": "Eriadu",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Etti IV",
		"region": "Outer Rim",
		"position": Vector2(10953.72, 8971.99),
		"lanes": ["Hydian Way", "Shaltin Tunnels"],
		"planets": [
			{
				"name": "Etti IV",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Exodeen",
		"region": "Colonies",
		"position": Vector2(2980.11, -3116.69),
		"lanes": ["Nanth'ri Route", "Hydian Way"],
		"planets": [
			{
				"name": "Exodeen",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Gerrenthum",
		"region": "Outer Rim",
		"position": Vector2(-1353.62, -12610.64),
		"lanes": ["Corellian Trade Spine", "Nothoiin Corridor", "Cerean Reach"],
		"planets": [
			{
				"name": "Gerrenthum",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Gos Hutta",
		"region": "Hutt Space",
		"position": Vector2(11378.14, -1761.42),
		"lanes": ["Pabol Hutta"],
		"planets": [
			{
				"name": "Gos Hutta",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Gyndine",
		"region": "Expansion Region",
		"position": Vector2(4695.54, -3352.32),
		"lanes": ["Ootmian Pabol", "Nanth'ri Route"],
		"planets": [
			{
				"name": "Gyndine",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Kal'Shebbol",
		"region": "Outer Rim",
		"position": Vector2(2488.50, -16917.45),
		"lanes": ["Rimma Trade Route"],
		"planets": [
			{
				"name": "Kal'Shebbol",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Lantillies",
		"region": "Mid Rim",
		"position": Vector2(6464.84, 1829.19),
		"lanes": ["Randon Run", "Perlimian Trade Route"],
		"planets": [
			{
				"name": "Lantillies",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Lianna",
		"region": "Outer Rim",
		"position": Vector2(10569.36, 5566.06),
		"lanes": ["Shaltin Tunnels", "Perlimian Trade Route"],
		"planets": [
			{
				"name": "Lianna",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Nanth'ri",
		"region": "Mid Rim",
		"position": Vector2(7939.28, -3109.28),
		"lanes": ["Trax Tube", "Nanth'ri Route"],
		"planets": [
			{
				"name": "Nanth'ri",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Quellor",
		"region": "Colonies",
		"position": Vector2(3521.99, -3140.73),
		"lanes": ["Quellor Run", "Nanth'ri Route"],
		"planets": [
			{
				"name": "Quellor",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Randon",
		"region": "Mid Rim",
		"position": Vector2(7896.94, -523.33),
		"lanes": ["Ootmian Pabol", "Randon Run", "Trax Tube"],
		"planets": [
			{
				"name": "Randon",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Rorak IV",
		"region": "Hutt Space",
		"position": Vector2(11054.64, -3425.94),
		"lanes": ["Shag Pabol", "Gamor Run"],
		"planets": [
			{
				"name": "Rorak IV",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Terminus",
		"region": "Outer Rim",
		"position": Vector2(-1086.89, -16404.70),
		"lanes": ["Corellian Trade Spine", "Hydian Way"],
		"planets": [
			{
				"name": "Terminus",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Trellen",
		"region": "Core Worlds",
		"position": Vector2(2464.38, -1506.88),
		"lanes": ["Trellen Trade Route", "Hydian Way"],
		"planets": [
			{
				"name": "Trellen",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Uyter",
		"region": "Mid Rim",
		"position": Vector2(6793.06, 1078.55),
		"lanes": ["Randon Run", "Lesser Lantillian Route"],
		"planets": [
			{
				"name": "Uyter",
				"planetary_type": "Ecumenopolis",
			},
		],
	},
	{
		"system_name": "Yag'Dhul",
		"region": "Inner Rim",
		"position": Vector2(1297.19, -7347.95),
		"lanes": ["Rimma Trade Route", "Corellian Trade Spine"],
		"planets": [
			{
				"name": "Yag'Dhul",
				"planetary_type": "Industrial Wasteland",
			},
		],
	},
	{
		"system_name": "Zygerria",
		"region": "Outer Rim",
		"position": Vector2(10594.77, 8213.79),
		"lanes": ["Shaltin Tunnels"],
		"planets": [
			{
				"name": "Zygerria",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Arrgaw",
		"region": "Expansion Region",
		"position": Vector2(3329.95, -9085.79),
		"lanes": ["Harrin Trade Corridor", "Hydian Way"],
		"planets": [
			{
				"name": "Arrgaw",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Circumtore",
		"region": "Hutt Space",
		"position": Vector2(10630.46, -3666.77),
		"lanes": ["Gamor Run", "Hollastin Run", "Kaaga Run"],
		"planets": [
			{
				"name": "Circumtore",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Darkknell",
		"region": "Outer Rim",
		"position": Vector2(2830.10, -11318.87),
		"lanes": ["Hydian Way", "Triellus Trade Route"],
		"planets": [
			{
				"name": "Darkknell",
				"planetary_type": "Volcanic World",
			},
		],
	},
	{
		"system_name": "Enarc",
		"region": "Mid Rim",
		"position": Vector2(5111.92, -10741.88),
		"lanes": ["Enarc Run", "Triellus Trade Route"],
		"planets": [
			{
				"name": "Enarc",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Formos",
		"region": "Outer Rim",
		"position": Vector2(13404.81, -379.45),
		"lanes": ["Triellus Trade Route", "Pabol Sleheyron"],
		"planets": [
			{
				"name": "Formos",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Gamorr",
		"region": "Hutt Space",
		"position": Vector2(12682.17, -6473.34),
		"lanes": ["Triellus Trade Route"],
		"planets": [
			{
				"name": "Gamorr",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Kegan",
		"region": "Outer Rim",
		"position": Vector2(12926.06, 1343.56),
		"lanes": ["Triellus Trade Route"],
		"planets": [
			{
				"name": "Kegan",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Kira",
		"region": "Expansion Region",
		"position": Vector2(3785.01, -8985.73),
		"lanes": ["Enarc Run", "Harrin Trade Corridor"],
		"planets": [
			{
				"name": "Kira II",
				"planetary_type": "Mineral-Rich Barren",
			},
		],
	},
	{
		"system_name": "Lorta",
		"region": "Mid Rim",
		"position": Vector2(-1592.24, -11667.99),
		"lanes": ["Cerean Reach"],
		"planets": [
			{
				"name": "Lorta",
				"planetary_type": "Desert World",
			},
		],
	},
	{
		"system_name": "Milagro",
		"region": "Expansion Region",
		"position": Vector2(5402.98, -6763.66),
		"lanes": ["Harrin Trade Corridor", "Corellian Run"],
		"planets": [
			{
				"name": "Milagro",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Riflor",
		"region": "Mid Rim",
		"position": Vector2(-2747.75, -10474.36),
		"lanes": ["Cerean Reach"],
		"planets": [
			{
				"name": "Riflor",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Sy Myrth",
		"region": "Outer Rim",
		"position": Vector2(10501.60, 3763.46),
		"lanes": ["Triellus Trade Route", "Pabol Hutta"],
		"planets": [
			{
				"name": "Sy Myrth",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Syvris",
		"region": "Outer Rim",
		"position": Vector2(12730.16, -5171.59),
		"lanes": ["Triellus Trade Route", "Hollastin Run"],
		"planets": [
			{
				"name": "Syvris",
				"planetary_type": "Agri-World",
			},
		],
	},
	{
		"system_name": "Teth",
		"region": "Outer Rim",
		"position": Vector2(13678.13, -3152.87),
		"lanes": ["Triellus Trade Route", "Shag Pabol"],
		"planets": [
			{
				"name": "Teth",
				"planetary_type": "Forest World",
			},
		],
	},

]
