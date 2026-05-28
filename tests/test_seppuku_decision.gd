extends GutTest
## Tests for SeppukuDecision — personality-driven seppuku acceptance.


func _make_char(
	bushido: Enums.BushidoVirtue,
	honor: float = 5.0,
	shourido: Enums.ShouridoVirtue = Enums.ShouridoVirtue.NONE,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.bushido_virtue = bushido
	c.shourido_virtue = shourido
	c.honor = honor
	c.character_name = "Test"
	return c


# -- Bushido: all accept ----

func test_gi_accepts():
	var c := _make_char(Enums.BushidoVirtue.GI)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])
	assert_eq(r["reason"], "just_consequence")


func test_meiyo_accepts():
	var c := _make_char(Enums.BushidoVirtue.MEIYO)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])
	assert_eq(r["reason"], "seppuku_before_dishonor")


func test_chugi_accepts():
	var c := _make_char(Enums.BushidoVirtue.CHUGI)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])
	assert_eq(r["reason"], "lord_commanded_it")


func test_makoto_accepts():
	var c := _make_char(Enums.BushidoVirtue.MAKOTO)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])


func test_yu_accepts():
	var c := _make_char(Enums.BushidoVirtue.YU)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])


func test_jin_accepts():
	var c := _make_char(Enums.BushidoVirtue.JIN)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])


func test_rei_accepts():
	var c := _make_char(Enums.BushidoVirtue.REI)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])


# -- Honor rank 0: always refuses ----

func test_honor_rank_0_refuses():
	var c := _make_char(Enums.BushidoVirtue.GI, 0.0)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_false(r["accepts"])
	assert_eq(r["reason"], "no_honor_investment")


# -- Shourido: most refuse ----

func test_ketsui_refuses():
	var c := _make_char(Enums.BushidoVirtue.GI, 5.0, Enums.ShouridoVirtue.KETSUI)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_false(r["accepts"])
	assert_true(r["shourido"])


func test_kanpeki_refuses():
	var c := _make_char(Enums.BushidoVirtue.GI, 5.0, Enums.ShouridoVirtue.KANPEKI)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_false(r["accepts"])


func test_seigyo_refuses():
	var c := _make_char(Enums.BushidoVirtue.GI, 5.0, Enums.ShouridoVirtue.SEIGYO)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_false(r["accepts"])


func test_ishi_refuses():
	var c := _make_char(Enums.BushidoVirtue.GI, 5.0, Enums.ShouridoVirtue.ISHI)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_false(r["accepts"])


# -- Shourido: Dosatsu and Chishiki accept (no GDD honor gate) ----

func test_dosatsu_accepts():
	var c := _make_char(Enums.BushidoVirtue.GI, 3.5, Enums.ShouridoVirtue.DOSATSU)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])
	assert_eq(r["reason"], "shourido_calculated_acceptance")


func test_dosatsu_accepts_low_honor():
	var c := _make_char(Enums.BushidoVirtue.GI, 2.0, Enums.ShouridoVirtue.DOSATSU)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])


func test_chishiki_accepts():
	var c := _make_char(Enums.BushidoVirtue.GI, 4.5, Enums.ShouridoVirtue.CHISHIKI)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])


func test_chishiki_accepts_low_honor():
	var c := _make_char(Enums.BushidoVirtue.GI, 3.0, Enums.ShouridoVirtue.CHISHIKI)
	var r := SeppukuDecision.will_accept_seppuku(c)
	assert_true(r["accepts"])
