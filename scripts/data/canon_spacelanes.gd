extends RefCounted
class_name CanonSpacelaneData

# Canon hyperspace lane ordering used by Galaxy map generation.
# Categories 2 and 3 are intentionally left as templates for future use.

const CATEGORY_1: Array[Dictionary] = [
	{"lane": "Celanon Spur", "begins": "Dorin", "closes": "Botajef"},
	{"lane": "Braxant Run", "begins": "Agamar", "closes": "Bandomeer"},
	{"lane": "Commenor Run", "begins": "Brentaal IV", "closes": "Commenor"},
	{"lane": "Corellian Run", "begins": "Coruscant", "closes": "Arkanis"},
	{"lane": "Corellian Trade Spine", "begins": "Corellia", "closes": "Terminus"},
	{"lane": "Cerean Reach", "begins": "Cerea", "closes": "Gerrenthum"},
	{"lane": "Enarc Run", "begins": "Enarc", "closes": "Kira"},
	{"lane": "Gamor Run", "begins": "Gamor", "closes": "Rorak IV"},
	{"lane": "Great Gran Run", "begins": "Kinyen", "closes": "Kinyen"},
	{"lane": "Great Kashyyyk Branch", "begins": "Kashyyyk", "closes": "Charros IV"},
	{"lane": "Harrin Trade Corridor", "begins": "Wroona", "closes": "Milagro"},
	{"lane": "Hydian Way", "begins": "Etti IV", "closes": "Terminus"},
	{"lane": "Hollastin Run", "begins": "Circumtore", "closes": "Syvris"},
	{"lane": "Lesser Lantillian Route", "begins": "Zeltros", "closes": "Boonta"},
	{"lane": "Lorell Route", "begins": "Zeltros", "closes": "Zeltros"},
	{"lane": "Nanth'ri Route", "begins": "Quellor", "closes": "Nanth'ri"},
	{"lane": "Namadii Corridor", "begins": "Coruscant", "closes": "Dorin"},
	{"lane": "Nothoiin Corridor", "begins": "Eriadu", "closes": "Gerrenthum"},
	{"lane": "Nond", "begins": "Dantooine", "closes": "Dantooine"},
	{"lane": "Ootmian Pabol", "begins": "Nal Hutta", "closes": "Gyndine"},
	{"lane": "Overic Griplink", "begins": "Mon Cala", "closes": "Quermia"},
	{"lane": "Pabol Hutta", "begins": "Nal Hutta", "closes": "Sy Myrth"},
	{"lane": "Pabol Sleheyron", "begins": "Nal Hutta", "closes": "Sleheyron"},
	{"lane": "Perlimian Trade Route", "begins": "Coruscant", "closes": "Quermia"},
	{"lane": "Quellor Run", "begins": "Commenor", "closes": "Quellor"},
	{"lane": "Randon Run", "begins": "Randon", "closes": "Lantillies"},
	{"lane": "Rimma Trade Route", "begins": "Yag'Dhul", "closes": "Kal'Shebbol"},
	{"lane": "Salin Corridor", "begins": "Botajef", "closes": "Columex"},
	{"lane": "Shag Pabol", "begins": "Nal Hutta", "closes": "Teth"},
	{"lane": "Shaltin Tunnels", "begins": "Etti IV", "closes": "Zygerria"},
	{"lane": "Trellen Trade Route", "begins": "Trellen", "closes": "Kashyyyk"},
	{"lane": "Triellus Trade Route", "begins": "Darkknell", "closes": "Centares"},
	{"lane": "Trax Tube", "begins": "Randon", "closes": "Daalang"},
	{"lane": "Kaaga Run", "begins": "Bothawui", "closes": "Circumtore"},
	{"lane": "Manda Merchant Route", "begins": "Bothawui", "closes": "Molavar"},
	{"lane": "Reena Trade Route", "begins": "Bothawui", "closes": "Druckenwell"},
	{"lane": "Bothan Run", "begins": "Bothawui", "closes": "Daalang"},
]

const CATEGORY_2: Array[Dictionary] = []
const CATEGORY_3: Array[Dictionary] = []

const ALL_LANES: Array[Dictionary] = CATEGORY_1 + CATEGORY_2 + CATEGORY_3

static func get_lane_route(lane_name: String) -> Dictionary:
	for lane_data in ALL_LANES:
		if String(lane_data.get("lane", "")) == lane_name:
			return lane_data
	return {}
