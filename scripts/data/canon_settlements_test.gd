extends RefCounted
class_name CanonSettlementTestData

# Minimal Canon test settlement payload used by test-only map generation.

const TEST_SETTLEMENT_1_ELEMENT_ID: String = "settlement_test_1"
const TEST_SETTLEMENT_1_NAME: String = "Test Settlement 1"
const TEST_SETTLEMENT_1_STORAGE_ID: String = "infra_storage_1"

const TEST_ELEMENTS: Array[Dictionary] = [
	{
		"element_id": TEST_SETTLEMENT_1_ELEMENT_ID,
		"element_type": "settlement",
		"element_name": TEST_SETTLEMENT_1_NAME,
		"owner_faction_id": "faction_a",
		"population": {"free": 10, "slave": 0, "starving_free": 0, "starving_slave": 0},
		"infrastructure_ids": [
			TEST_SETTLEMENT_1_STORAGE_ID,
		],
		"resource_holdings": [],
	},
]

const TEST_INFRASTRUCTURES: Array[Dictionary] = [
	{
		"infrastructure_id": TEST_SETTLEMENT_1_STORAGE_ID,
		"element_id": TEST_SETTLEMENT_1_ELEMENT_ID,
		"type": "storage",
		"workers": 1,
		"storage_capacity": 100.0,
		"stored_food": 20.0,
		"stored_ore": 0,
		"stored_rare_ore": 0,
		"stored_metal": 0,
		"stored_rare_metal": 0,
	},
]
