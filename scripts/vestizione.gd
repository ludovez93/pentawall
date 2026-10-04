class_name Vestizione
extends RefCounted

## La vestizione: superfici vere al posto delle tinte piatte, insegne che sono
## oggetti, neon e striscioni, corpi veri al posto delle capsule.
##
## Nasce con la tappa 7, blocco A, per **la prima immagine** (`PLAN.md`). Si
## applica a un'arena già costruita e non tocca né la fisica né le regole: i
## muri restano muri, le sponde restano sponde, cambia solo di che cosa sembrano
## fatti. Tutto il materiale è libero (`assets/LICENZE.md`): Kenney per corpi e
## blaster (CC0), ambientCG per le superfici (CC0), Google Fonts per i caratteri.

const MATERIALI := "res://assets/materials/ambientcg/"
const MODELLI := "res://assets/models/kenney/"
const CARATTERE_INSEGNE := "res://assets/font/RussoOne-Regular.ttf"
const MODELLI_UMANI := "res://assets/models/quaternius/base/"
const ANIMAZIONI_UMANE := "res://assets/models/quaternius/UAL1_Standard.glb"
const TUTA := "res://assets/materials/tuta.gdshader"
const CAPELLI := "res://assets/models/quaternius/capelli/"

## Il neon decorativo: viola. Non arancio (il dardo), non ciano (le sponde), non
## lime (gli avversari): i tre colori che parlano restano soltanto loro.
const NEON := Color(0.78, 0.36, 1.0)
const LISTELLO := 0.07

## Quale superficie veste quale tinta della pianta, e con che colore. La tinta
## moltiplica la texture, che è chiara: qui è più accesa di come si vedrà.
const VESTITI := {
	"moquette": {"cartella": "Carpet016", "passo": 2.2, "tinta": Color(0.50, 0.28, 0.88),
			"normale": 0.6, "metallo": 0.0},
	"ocra": {"cartella": "PaintedPlaster017", "passo": 2.0, "tinta": Color(0.96, 0.64, 0.22),
			"normale": 0.9, "metallo": 0.0},
	"mattone": {"cartella": "Bricks075A", "passo": 2.6, "tinta": Color(1.0, 0.40, 0.40),
			"normale": 0.8, "metallo": 0.0},
	"tribuna": {"cartella": "MetalPlates006", "passo": 2.4, "tinta": Color(0.50, 0.44, 0.96),
			"normale": 0.7, "metallo": 0.35},
	"soffitto": {"cartella": "MetalPlates006", "passo": 3.2, "tinta": Color(0.28, 0.28, 0.58),
			"normale": 0.5, "metallo": 0.35},
	# **I pavimenti delle ali** (tappa 8, blocco E): parquet da palestra a listelli,
	# appena tinto del colore dell'ala, al posto della superficie dei muri — fino al
	# 03/10/2026 l'ala mattone camminava sui mattoni. Il catino e il portico restano
	# moquette viola: sono il campo, con le linee.
	"parquet_ocra": {"cartella": "WoodFloor051", "passo": 2.8, "tinta": Color(1.0, 0.84, 0.60),
			"normale": 0.5, "metallo": 0.0},
	"parquet_mattone": {"cartella": "WoodFloor051", "passo": 2.8, "tinta": Color(1.0, 0.66, 0.56),
			"normale": 0.5, "metallo": 0.0},
	"parquet_tribuna": {"cartella": "WoodFloor051", "passo": 2.8, "tinta": Color(0.78, 0.74, 1.0),
			"normale": 0.5, "metallo": 0.0},
}

## L'altezza dei personaggi nei loro file: si scalano a quella del corpo.
const ALTEZZA_BLOCCHETTI := 0.67
const ALTEZZA_UMANI := 1.8

static var _pronti: Dictionary = {}
static var _carattere: Font = null


# ------------------------------------------------------------------ superfici

## Veste tutti i muri, i piani e le rampe dell'arena: chi ha addosso una tinta
## della pianta riceve la superficie corrispondente, con lo stesso colore.
static func vesti(arena: Node3D) -> void:
	var per_colore := {}
	for nome in Arena.TINTE:
		per_colore[Arena.TINTE[nome]] = nome
	var grana := Muratura.grana()
	for nodo in tutti(arena):
		if not (nodo is MeshInstance3D):
			continue
		var pezzo := nodo as MeshInstance3D
		var vecchio := pezzo.material_override as StandardMaterial3D
		if vecchio == null or vecchio.albedo_texture != grana:
			continue
		var nome: Variant = per_colore.get(vecchio.albedo_color)
		if nome == null:
			continue
		var pavimento := pezzo.get_parent() != null 				and pezzo.get_parent().is_in_group(Muratura.GRUPPO_PAVIMENTI)
		if pavimento and VESTITI.has("parquet_" + String(nome)):
			pezzo.material_override = materiale_di("parquet_" + String(nome))
		else:
			pezzo.material_override = materiale_di(String(nome))


## La superficie di una tinta, costruita una volta e prestata a tutti i pezzi:
## un materiale solo per tinta è anche meno lavoro per la scheda video.
static var _pixel_bianco: ImageTexture = null


## Un pixel bianco: la texture di chi non ne ha una ma deve usare lo stesso shader
## di chi ce l'ha.
static func _bianco() -> ImageTexture:
	if _pixel_bianco == null:
		var immagine := Image.create(1, 1, false, Image.FORMAT_L8)
		immagine.fill(Color.WHITE)
		_pixel_bianco = ImageTexture.create_from_image(immagine)
	return _pixel_bianco


static func materiale_di(nome: String) -> StandardMaterial3D:
	if _pronti.has(nome):
		return _pronti[nome]
	var v: Dictionary = VESTITI[nome]
	var cartella: String = MATERIALI + String(v["cartella"]) + "/"
	var m := StandardMaterial3D.new()
	m.albedo_color = v["tinta"]
	m.albedo_texture = load(cartella + "Color.jpg")
	m.normal_enabled = true
	m.normal_texture = load(cartella + "Normal.jpg")
	m.normal_scale = float(v["normale"])
	m.roughness = 1.0
	m.roughness_texture = load(cartella + "Roughness.jpg")
	m.metallic = float(v["metallo"])
	# Poco riflesso: la camera in terza persona guarda pavimenti e muri quasi di
	# taglio, e lì un materiale lucido riflette lo sfondo dell'arena, che è blu notte.
	# Il parquet usciva blu scuro con due righe di legno (visto il 03/10/2026).
	m.metallic_specular = 0.18 if String(nome).begins_with("parquet") else 0.3
	if String(nome).begins_with("parquet"):
		# Ruvidità uguale dappertutto, ma **con una texture** (un pixel bianco): senza
		# texture il parquet aveva uno shader suo, e sul telefono uno shader in più
		# sono cinque compilazioni (tappa 9). Bianco per 0,82 fa 0,82.
		m.roughness_texture = _bianco()
		m.roughness = 0.82
	# Proiezione dal mondo, uguale su scatole e su piani di forma qualunque: la
	# grana ha lo stesso passo dappertutto, e un muro lungo non la stira.
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / float(v["passo"])
	# Il filo di luce propria dei muri di prima, ma **attraverso la texture**: gli
	# angoli in ombra restano saturi senza che la superficie si appiattisca.
	m.emission_enabled = true
	m.emission = v["tinta"]
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.05
	_pronti[nome] = m
	return m


# ------------------------------------------------------------------ l'arena intera

## **L'arredo di tutta la palestra** (tappa 8, blocco E). Quello che l'angolo della
## prima immagine (12/09/2026) aveva da solo, esteso a tutta l'arena, più le cose
## che dicono «palazzetto» a colpo d'occhio:
## - il neon viola alla base dei quattro perimetri e una fascia a tre metri;
## - i cassoni **da palestra**: imbottitura in cima e due cinghie scure attorno;
## - le insegne della pianta come oggetti — pannello, cornice al neon, scritta;
## - le linee del campo a terra nel catino, e il nome del gioco dipinto in mezzo;
## - gli striscioni appesi nelle ali, nei colori dei concorrenti;
## - il tabellone sospeso sopra il catino, quattro schermi che dicono tempo e capo
##   classifica (lo aggiorna l'arena, `aggiorna_tabellone`).
## Tutto decoro: niente collisioni, niente su cui un dardo possa rimbalzare.
static func arreda_arena(arena: Node3D, pianta: Dictionary) -> Node3D:
	# Zoccoli e fascia sui perimetri: le facce interne stanno a ±33 metri.
	for lato in [
		{"centro": Vector3(0, 0, -32.95), "misura": Vector3(66.0, LISTELLO, LISTELLO)},
		{"centro": Vector3(0, 0, 32.95), "misura": Vector3(66.0, LISTELLO, LISTELLO)},
		{"centro": Vector3(32.95, 0, 0), "misura": Vector3(LISTELLO, LISTELLO, 66.0)},
		{"centro": Vector3(-32.95, 0, 0), "misura": Vector3(LISTELLO, LISTELLO, 66.0)},
	]:
		for quota in [0.10, 3.2, 7.6]:
			_striscia(arena, (lato["centro"] as Vector3) + Vector3(0, quota, 0), lato["misura"])

	for muro in pianta["muri"]:
		var nome := String(muro.get("nome", ""))
		if nome.contains("cassone") or nome.contains("cassa") or nome.contains("blocco") \
				or nome.contains("box"):
			_cassone_da_palestra(arena, muro)

	for insegna in pianta["insegne"]:
		var testo := String(insegna["testo"])
		var misura := float(insegna["misura"])
		var dove := Vector3(float(insegna["dove"][0]), float(insegna["quota"]), float(insegna["dove"][1]))
		_insegna(arena, testo, dove, float(insegna["giro"]),
				Vector2(float(testo.length()) * misura * 0.62 + misura * 0.9, misura * 1.35), misura)

	_campo_del_catino(arena)

	# Gli striscioni: due per ala, appesi al soffitto a otto metri, nei colori
	# delle tute. Girati verso il centro dell'arena.
	var colori := [Color(0.13, 0.36, 0.95), Color(0.84, 0.12, 0.20), Color(0.98, 0.80, 0.12),
			Color(0.90, 0.30, 0.64), Color(0.90, 0.91, 0.95), Color(0.15, 0.15, 0.18)]
	var posti := [
		[Vector3(-8.0, 7.9, -31.0), 180.0], [Vector3(14.0, 7.9, -31.0), 180.0],
		[Vector3(31.0, 7.9, -6.0), 270.0], [Vector3(31.0, 7.9, 6.0), 270.0],
		[Vector3(-31.0, 7.9, -14.0), 90.0], [Vector3(-31.0, 7.9, 14.0), 90.0],
	]
	for i in posti.size():
		_striscione(arena, posti[i][0], posti[i][1], colori[i % colori.size()])

	return _tabellone(arena)


## Un cassone da palestra al posto di una scatola: l'imbottitura in cima, più chiara,
## e due cinghie scure attorno ai fianchi. Stesse misure del muro: si sovrappone alla
## scatola smussata, appena più larga, e non cambia niente di ciò che si tocca.
static func _cassone_da_palestra(arena: Node3D, muro: Dictionary) -> void:
	var largo := float(muro["misura"][0])
	var fondo := float(muro["misura"][1])
	var alto := float(muro["alto"])
	var radice := Node3D.new()
	radice.position = Vector3(float(muro["centro"][0]), float(muro["quota"]), float(muro["centro"][1]))
	radice.rotation_degrees.y = float(muro.get("giro", 0))
	arena.add_child(radice)

	var cuscino := MeshInstance3D.new()
	cuscino.mesh = Muratura.scatola_smussata(Vector3(largo + 0.06, 0.32, fondo + 0.06), 0.14)
	cuscino.position = Vector3(0, alto - 0.13, 0)
	var pelle := StandardMaterial3D.new()
	pelle.albedo_color = Color(0.93, 0.86, 0.72)
	pelle.roughness = 0.55
	pelle.emission_enabled = true
	pelle.emission = Color(0.93, 0.86, 0.72)
	pelle.emission_energy_multiplier = 0.06
	cuscino.material_override = pelle
	cuscino.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(cuscino)

	var scuro := Muratura.tinta_unita(Color(0.10, 0.09, 0.14), 0.7)
	for quota in [alto * 0.34, alto * 0.62]:
		var cinghia := MeshInstance3D.new()
		cinghia.mesh = Muratura.scatola_smussata(Vector3(largo + 0.04, 0.07, fondo + 0.04), 0.3)
		cinghia.position = Vector3(0, quota, 0)
		cinghia.material_override = scuro
		cinghia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		radice.add_child(cinghia)


## Le linee del campo nel catino: un cerchio attorno al box, le due linee di metà
## campo spezzate dal box, e il nome del gioco dipinto a terra, che si legge dal
## ballatoio. Bianco sporco, appena luminoso: è vernice, non neon.
static func _campo_del_catino(arena: Node3D) -> void:
	var vernice := StandardMaterial3D.new()
	vernice.albedo_color = Color(0.93, 0.92, 0.98)
	vernice.roughness = 0.6
	vernice.emission_enabled = true
	vernice.emission = Color(0.93, 0.92, 0.98)
	vernice.emission_energy_multiplier = 0.25
	var quota := -2.0 + 0.012

	var cerchio := MeshInstance3D.new()
	var anello := TorusMesh.new()
	anello.inner_radius = 4.15
	anello.outer_radius = 4.32
	anello.rings = 64
	anello.ring_segments = 4
	cerchio.mesh = anello
	cerchio.scale = Vector3(1.0, 0.02, 1.0)
	cerchio.position = Vector3(0, quota, 0)
	cerchio.material_override = vernice
	cerchio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(cerchio)

	for tratto in [
		{"centro": Vector3(0, quota, -7.6), "misura": Vector3(0.16, 0.01, 6.2)},
		{"centro": Vector3(0, quota, 7.6), "misura": Vector3(0.16, 0.01, 6.2)},
		{"centro": Vector3(-7.6, quota, 0), "misura": Vector3(6.2, 0.01, 0.16)},
		{"centro": Vector3(7.6, quota, 0), "misura": Vector3(6.2, 0.01, 0.16)},
	]:
		var linea := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = tratto["misura"]
		linea.mesh = mesh
		linea.position = tratto["centro"]
		linea.material_override = vernice
		linea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arena.add_child(linea)

	var nome := Label3D.new()
	nome.text = "PENTAWALL"
	nome.font = carattere_insegne()
	nome.font_size = 160
	nome.pixel_size = 0.0046
	nome.position = Vector3(0, quota + 0.005, 8.6)
	nome.rotation_degrees = Vector3(-90, 0, 0)
	# Vernice consumata, non un'insegna: a piena luce si mangiava mezzo schermo. E
	# senza il contorno nero delle scritte, che a terra disegnava lettere vuote.
	nome.modulate = Color(0.86, 0.82, 1.0, 0.42)
	nome.outline_size = 0
	nome.shaded = false
	# A due facce come tutte le scritte dell'arena (vedi `_insegna`): da sotto la
	# copre il pavimento.
	nome.double_sided = true
	nome.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	arena.add_child(nome)


## **Il tabellone** sopra il catino: un cubo sospeso con quattro schermi, uno per
## lato, appeso al soffitto con quattro cavi. Dice il tempo e chi comanda — è la cosa
## che in un palazzetto si guarda alzando gli occhi, e qui si vede da tutte e quattro
## le ali. Torna il nodo da passare ad `aggiorna_tabellone`.
static func _tabellone(arena: Node3D) -> Node3D:
	var radice := Node3D.new()
	radice.name = "tabellone"
	radice.position = Vector3(0, 9.4, 0)
	arena.add_child(radice)

	var corpo := MeshInstance3D.new()
	corpo.mesh = Muratura.scatola_smussata(Vector3(5.2, 2.6, 5.2), 0.18)
	var lamiera := materiale_di("soffitto").duplicate() as StandardMaterial3D
	lamiera.albedo_color = Color(0.12, 0.11, 0.20)
	lamiera.emission_energy_multiplier = 0.0
	corpo.material_override = lamiera
	radice.add_child(corpo)

	var schermo_pelle := StandardMaterial3D.new()
	schermo_pelle.albedo_color = Color(0.03, 0.03, 0.08)
	schermo_pelle.emission_enabled = true
	schermo_pelle.emission = Color(0.10, 0.08, 0.30)
	schermo_pelle.emission_energy_multiplier = 0.6
	schermo_pelle.roughness = 0.2
	for giro in [0.0, 90.0, 180.0, 270.0]:
		var lato := Node3D.new()
		lato.rotation_degrees.y = giro
		radice.add_child(lato)
		var schermo := MeshInstance3D.new()
		var vetro := QuadMesh.new()
		vetro.size = Vector2(4.5, 2.0)
		schermo.mesh = vetro
		schermo.position = Vector3(0, 0, 2.62)
		schermo.material_override = schermo_pelle
		lato.add_child(schermo)
		for k in 2:
			var riga := Label3D.new()
			riga.name = "riga_%d" % k
			riga.font = carattere_insegne()
			riga.font_size = 120
			riga.pixel_size = 0.0068 if k == 0 else 0.0042
			riga.position = Vector3(0, 0.32 if k == 0 else -0.5, 2.64)
			riga.modulate = Color(1.0, 1.0, 1.0) if k == 0 else Color(0.80, 0.86, 1.0)
			riga.shaded = false
			# A due facce (vedi `_insegna`): da dietro la copre lo schermo.
			riga.double_sided = true
			riga.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			riga.text = "PENTAWALL" if k == 0 else "5 MURI"
			lato.add_child(riga)
		# La cornice al neon attorno allo schermo.
		for bordo in [
			{"pos": Vector3(0, 1.04, 2.63), "mis": Vector3(4.6, LISTELLO, LISTELLO)},
			{"pos": Vector3(0, -1.04, 2.63), "mis": Vector3(4.6, LISTELLO, LISTELLO)},
		]:
			var pezzo := MeshInstance3D.new()
			var tubo := BoxMesh.new()
			tubo.size = bordo["mis"]
			pezzo.mesh = tubo
			pezzo.position = bordo["pos"]
			pezzo.material_override = Muratura.acceso(NEON, 0.9)
			pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lato.add_child(pezzo)

	# I cavi: dal tabellone al soffitto del cuore, a dodici metri.
	for angolo in [Vector2(-2.2, -2.2), Vector2(2.2, -2.2), Vector2(2.2, 2.2), Vector2(-2.2, 2.2)]:
		var cavo := MeshInstance3D.new()
		var filo := CylinderMesh.new()
		filo.top_radius = 0.025
		filo.bottom_radius = 0.025
		filo.height = 1.4
		filo.radial_segments = 6
		cavo.mesh = filo
		cavo.position = Vector3(angolo.x, 2.0, angolo.y)
		cavo.material_override = lamiera
		cavo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		radice.add_child(cavo)
	return radice


## Scrive sul tabellone: la riga grande (il tempo) e quella piccola (chi comanda).
static func aggiorna_tabellone(tabellone: Node3D, grande: String, piccola: String) -> void:
	if tabellone == null:
		return
	for lato in tabellone.get_children():
		var r0 := lato.get_node_or_null("riga_0") as Label3D
		var r1 := lato.get_node_or_null("riga_1") as Label3D
		if r0 != null and r0.text != grande:
			r0.text = grande
		if r1 != null and r1.text != piccola:
			r1.text = piccola


# ------------------------------------------------------------------ arredo

## L'arredo dell'angolo nord-ovest, quello che si vede dalla sua partenza
## guardando verso il cuore: zoccoli e fasce al neon, le insegne come oggetti,
## due striscioni, l'anello della partenza. Coordinate dalla pianta
## (`arene/palestra.json`), scritte a mano perché è un angolo solo.
static func arreda_angolo(arena: Node3D) -> void:
	# La lampada di zona del nord-ovest era lime, che è il colore degli avversari
	# (decisione 15): qui diventa del neon, e con lei l'angolo.
	for nodo in tutti(arena):
		if nodo is OmniLight3D and (nodo as OmniLight3D).light_color.is_equal_approx(
				Color(0.62, 1.0, 0.45)):
			(nodo as OmniLight3D).light_color = NEON
			(nodo as OmniLight3D).light_energy = 2.2

	# Gli zoccoli: una riga di neon alla base dei muri dell'angolo.
	_striscia(arena, Vector3(-23.0, 0.10, -32.95), Vector3(20.0, LISTELLO, LISTELLO))   # perimetro nord
	_striscia(arena, Vector3(-32.95, 0.10, -23.0), Vector3(LISTELLO, LISTELLO, 20.0))   # perimetro ovest
	_striscia(arena, Vector3(-13.45, 0.10, -28.0), Vector3(LISTELLO, LISTELLO, 10.0))   # chiude verso l'angolo
	_striscia(arena, Vector3(-27.0, 0.10, -18.4), Vector3(10.0, LISTELLO, LISTELLO))    # il muro corto
	# La fascia a tre metri sui due perimetri: il segno da palestra.
	_striscia(arena, Vector3(-23.0, 3.2, -32.95), Vector3(20.0, LISTELLO, LISTELLO))
	_striscia(arena, Vector3(-32.95, 3.2, -23.0), Vector3(LISTELLO, LISTELLO, 20.0))

	# I tre cassoni: il bordo alto acceso, così si leggono come volumi anche da lontano.
	for cassone in [
		{"centro": Vector2(-22, -28), "misura": Vector2(5, 4), "alto": 2.6},
		{"centro": Vector2(-27, -24), "misura": Vector2(4, 4), "alto": 3.2},
		{"centro": Vector2(-18, -25), "misura": Vector2(3, 5), "alto": 2.2},
	]:
		_bordo(arena, cassone["centro"], cassone["misura"], float(cassone["alto"]) + 0.02)

	# L'insegna dell'angolo: sul muro che chiude verso l'angolo, faccia a ovest,
	# dove la si vede appena partiti. Dice la regola del gioco in due parole.
	_insegna(arena, "5 MURI", Vector3(-13.45, 5.0, -28.0), -90.0, Vector2(6.0, 1.9), 1.5)

	# L'insegna grande del cuore diventa un oggetto: pannello scuro, cornice al
	# neon, e la scritta che c'era già davanti.
	_pannello(arena, Vector3(0.0, 9.0, -11.55), 0.0, Vector2(15.5, 2.7))

	# Due striscioni appesi al soffitto dell'ala, rivolti verso la partenza.
	_striscione(arena, Vector3(-20.0, 7.9, -30.5), 225.0, Color(0.16, 0.30, 0.95))
	_striscione(arena, Vector3(-30.5, 7.9, -20.0), 225.0, Color(0.92, 0.22, 0.30))

	# L'anello della partenza, a terra.
	var anello := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 1.15
	toro.outer_radius = 1.32
	toro.rings = 48
	toro.ring_segments = 6
	anello.mesh = toro
	anello.position = Vector3(-29.0, 0.03, -29.0)
	anello.scale = Vector3(1.0, 0.18, 1.0)
	anello.material_override = Muratura.acceso(NEON, 0.7)
	anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(anello)

	# La luce del neon: le strisce fanno luce da sé ma non ne danno al pavimento,
	# quindi due lampade viola fanno il lavoro che nel mondo vero farebbero loro.
	_lampada(arena, Vector3(-23.0, 2.6, -30.5), NEON, 1.6, 13.0)
	_lampada(arena, Vector3(-16.0, 5.0, -28.0), NEON, 2.2, 10.0)


static func _striscia(arena: Node3D, centro: Vector3, misura: Vector3) -> void:
	var pezzo := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = misura
	pezzo.mesh = mesh
	pezzo.position = centro
	pezzo.material_override = Muratura.acceso(NEON, 0.85)
	pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(pezzo)


## Il bordo acceso sul perimetro alto di un cassone.
static func _bordo(arena: Node3D, centro: Vector2, misura: Vector2, quota: float) -> void:
	var mx := misura.x * 0.5
	var mz := misura.y * 0.5
	_striscia(arena, Vector3(centro.x, quota, centro.y - mz), Vector3(misura.x + LISTELLO, LISTELLO, LISTELLO))
	_striscia(arena, Vector3(centro.x, quota, centro.y + mz), Vector3(misura.x + LISTELLO, LISTELLO, LISTELLO))
	_striscia(arena, Vector3(centro.x - mx, quota, centro.y), Vector3(LISTELLO, LISTELLO, misura.y + LISTELLO))
	_striscia(arena, Vector3(centro.x + mx, quota, centro.y), Vector3(LISTELLO, LISTELLO, misura.y + LISTELLO))


## Un pannello scuro con la cornice al neon: il corpo di ogni insegna. `giro` è
## la rotazione attorno all'asse verticale; la faccia guarda verso **+Z** prima del
## giro, perché è da lì che una `Label3D` si legge dritta.
static func _pannello(arena: Node3D, dove: Vector3, giro: float, misura: Vector2) -> Node3D:
	var radice := Node3D.new()
	radice.position = dove
	radice.rotation_degrees.y = giro
	arena.add_child(radice)

	var fondo := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(misura.x, misura.y, 0.16)
	fondo.mesh = mesh
	var scuro := materiale_di("soffitto").duplicate() as StandardMaterial3D
	scuro.albedo_color = Color(0.13, 0.12, 0.22)
	scuro.emission_energy_multiplier = 0.0
	scuro.uv1_scale = Vector3.ONE / 1.4
	fondo.material_override = scuro
	radice.add_child(fondo)

	var s := LISTELLO * 1.4
	var mx := misura.x * 0.5
	var my := misura.y * 0.5
	for lato in [
		{"pos": Vector3(0, my, 0.06), "mis": Vector3(misura.x + s, s, s)},
		{"pos": Vector3(0, -my, 0.06), "mis": Vector3(misura.x + s, s, s)},
		{"pos": Vector3(-mx, 0, 0.06), "mis": Vector3(s, misura.y + s, s)},
		{"pos": Vector3(mx, 0, 0.06), "mis": Vector3(s, misura.y + s, s)},
	]:
		var pezzo := MeshInstance3D.new()
		var tubo := BoxMesh.new()
		tubo.size = lato["mis"]
		pezzo.mesh = tubo
		pezzo.position = lato["pos"]
		pezzo.material_override = Muratura.acceso(NEON, 0.9)
		pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		radice.add_child(pezzo)
	return radice


## Un'insegna intera: pannello, cornice e scritta.
static func _insegna(arena: Node3D, testo: String, dove: Vector3, giro: float,
		misura: Vector2, altezza_testo: float) -> void:
	var pannello := _pannello(arena, dove, giro, misura)
	var etichetta := Label3D.new()
	etichetta.text = testo
	etichetta.font = carattere_insegne()
	etichetta.font_size = 160
	etichetta.pixel_size = altezza_testo * 0.0062
	etichetta.position = Vector3(0, 0, 0.14)
	etichetta.modulate = Color(0.98, 0.90, 1.0)
	etichetta.outline_size = 22
	etichetta.outline_modulate = Color(NEON.r * 0.6, NEON.g * 0.4, NEON.b * 0.7, 1.0)
	etichetta.shaded = false
	# **A due facce**, come tutte le scritte dell'arena (tappa 9): a una faccia
	# avevano uno shader loro, e sul telefono uno shader in più sono cinque
	# compilazioni. Da dietro non si legge a specchio: la copre il pannello.
	etichetta.double_sided = true
	etichetta.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	pannello.add_child(etichetta)


## Uno striscione: un telo che pende dal soffitto, con una riga chiara in fondo
## e il nome del gioco. `dove` è il punto in cui è appeso.
static func _striscione(arena: Node3D, dove: Vector3, giro: float, colore: Color) -> void:
	var radice := Node3D.new()
	radice.position = dove
	radice.rotation_degrees.y = giro
	arena.add_child(radice)

	var telo := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.5, 3.4, 0.05)
	telo.mesh = mesh
	telo.position = Vector3(0, -1.7, 0)
	var stoffa := materiale_di("moquette").duplicate() as StandardMaterial3D
	stoffa.albedo_color = colore
	stoffa.emission = colore
	stoffa.emission_energy_multiplier = 0.12
	stoffa.uv1_scale = Vector3.ONE / 0.9
	telo.material_override = stoffa
	radice.add_child(telo)

	var riga := MeshInstance3D.new()
	var mesh_riga := BoxMesh.new()
	mesh_riga.size = Vector3(1.5, 0.16, 0.06)
	riga.mesh = mesh_riga
	riga.position = Vector3(0, -3.2, 0)
	riga.material_override = Muratura.acceso(Color(0.98, 0.96, 1.0), 0.55)
	riga.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(riga)

	var etichetta := Label3D.new()
	etichetta.text = "PENTAWALL"
	etichetta.font = carattere_insegne()
	etichetta.font_size = 160
	etichetta.pixel_size = 0.0019
	etichetta.position = Vector3(0, -2.85, 0.04)
	etichetta.modulate = Color(0.98, 0.96, 1.0)
	etichetta.shaded = false
	etichetta.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	radice.add_child(etichetta)


static func _lampada(arena: Node3D, dove: Vector3, colore: Color, forza: float, portata: float) -> void:
	var luce := OmniLight3D.new()
	luce.position = dove
	luce.light_color = colore
	luce.light_energy = forza
	luce.omni_range = portata
	luce.shadow_enabled = false
	arena.add_child(luce)


# ------------------------------------------------------------------ corpi

## Un corpo a blocchetti (Kenney, «Mini Characters»), scalato all'altezza data,
## con il blaster nella mano destra e la posa di chi lo tiene. `personaggio` è
## il suffisso del file: `male-a` … `male-f`, `female-a` … `female-f`.
static func corpo_blocchetti(personaggio: String, altezza: float, con_blaster := true) -> Node3D:
	var radice := Node3D.new()
	var scena: PackedScene = load(MODELLI + "mini/character-" + personaggio + ".glb")
	var corpo: Node3D = scena.instantiate()
	var scala := altezza / ALTEZZA_BLOCCHETTI
	corpo.scale = Vector3.ONE * scala
	# Il contorno cresce nello spazio del modello: chi lo costruisce deve sapere
	# di quanto il modello è ingrandito, o il filo diventa una fascia.
	radice.set_meta("scala", scala)
	# Nel file guarda verso +Z; da noi avanti è -Z.
	corpo.rotation_degrees.y = 180.0
	radice.add_child(corpo)

	var animatore := corpo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animatore != null:
		var posa := "holding-right" if con_blaster else "idle"
		if animatore.has_animation(posa):
			animatore.play(posa)

	if con_blaster:
		var scheletro := trova(corpo, "Skeleton3D") as Skeleton3D
		if scheletro != null:
			var attacco := BoneAttachment3D.new()
			attacco.bone_name = "arm-right"
			scheletro.add_child(attacco)
			var blaster: Node3D = (load(MODELLI + "blaster/blaster-a.glb") as PackedScene).instantiate()
			blaster.position = Vector3(0.0, 0.19, 0.0)
			blaster.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			blaster.scale = Vector3.ONE * 0.36
			attacco.add_child(blaster)
	return radice


## Un corpo umano (Quaternius, «Universal Base Characters», CC0), con le
## animazioni della libreria gemella (CC0): condividono lo stesso scheletro a
## sessantacinque ossa, quindi le animazioni si prestano al corpo così come sono.
## `personaggio` inizia per `male` o `female`.
static func corpo_umano(personaggio: String, altezza: float, colore: Color,
		con_blaster := true) -> Node3D:
	var radice := Node3D.new()
	var file := "Superhero_Female_FullBody" if personaggio.begins_with("female") 			else "Superhero_Male_FullBody"
	var scena: PackedScene = load(MODELLI_UMANI + file + ".gltf")
	var corpo: Node3D = scena.instantiate()
	var scala := altezza / ALTEZZA_UMANI
	corpo.scale = Vector3.ONE * scala
	corpo.rotation_degrees.y = 180.0
	radice.set_meta("scala", scala)
	radice.add_child(corpo)
	_vesti_di_tuta(corpo, file, colore)
	_pettina(corpo, "Hair_Long" if file.contains("Female") else "Hair_SimpleParted")

	var libreria: Node = (load(ANIMAZIONI_UMANE) as PackedScene).instantiate()
	var origine := libreria.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if origine != null:
		var animatore := AnimationPlayer.new()
		animatore.name = "AnimationPlayer"
		for nome in origine.get_animation_library_list():
			animatore.add_animation_library(nome, origine.get_animation_library(nome))
		corpo.add_child(animatore)
		var posa := "Pistol_Idle" if con_blaster else "Idle"
		if animatore.has_animation(posa):
			animatore.play(posa)
	libreria.free()

	if con_blaster:
		var scheletro := trova(corpo, "Skeleton3D") as Skeleton3D
		if scheletro != null:
			var attacco := BoneAttachment3D.new()
			attacco.bone_name = "hand_r"
			scheletro.add_child(attacco)
			var blaster: Node3D = (load(MODELLI + "blaster/blaster-a.glb") as PackedScene).instantiate()
			blaster.scale = Vector3.ONE * 0.7
			attacco.add_child(blaster)
	return radice


## La tuta da gara addosso al corpo base: il corpo nel pacchetto libero è nudo,
## e la tuta gliela mette uno shader — pelle dove la maschera è bianca (la
## testa), colore della squadra dappertutto altrove, con le pieghe e la
## lucentezza del corpo. Un colore per concorrente, senza una texture in più.
static func _vesti_di_tuta(corpo: Node3D, file: String, colore: Color) -> void:
	var sesso := "Female" if file.contains("Female") else "Male"
	var grande: MeshInstance3D = null
	var quanti := 0
	for nodo in tutti(corpo):
		if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh != null:
			var facce := (nodo as MeshInstance3D).mesh.get_faces().size()
			if facce > quanti:
				quanti = facce
				grande = nodo
	if grande == null:
		return
	var vecchio := grande.get_active_material(0) as BaseMaterial3D
	var materiale := ShaderMaterial.new()
	materiale.shader = load(TUTA)
	if vecchio != null:
		materiale.set_shader_parameter("base", vecchio.albedo_texture)
		materiale.set_shader_parameter("normale", vecchio.normal_texture)
		materiale.set_shader_parameter("rugosita", vecchio.roughness_texture)
	materiale.set_shader_parameter("maschera", load(MODELLI_UMANI + "Maschera_Testa_" + sesso + ".png"))
	materiale.set_shader_parameter("tuta", colore)
	grande.material_override = materiale


## I capelli: nel pacchetto stanno a parte, fermi nella posa di riposo del
## corpo. Si appendono all'osso della testa, spostati all'indietro di quanto la
## testa sta avanti a riposo: così seguono la testa da qualunque posa.
static func _pettina(corpo: Node3D, taglio: String) -> void:
	var scheletro := trova(corpo, "Skeleton3D") as Skeleton3D
	if scheletro == null:
		return
	var testa := scheletro.find_bone("Head")
	if testa < 0:
		return
	var scena: PackedScene = load(CAPELLI + taglio + ".gltf")
	if scena == null:
		return
	var attacco := BoneAttachment3D.new()
	attacco.bone_name = "Head"
	scheletro.add_child(attacco)
	var pettinatura: Node3D = scena.instantiate()
	pettinatura.transform = scheletro.get_bone_global_rest(testa).affine_inverse()
	attacco.add_child(pettinatura)


## I due gusci del contorno attorno a un corpo vero: lo stesso meccanismo della
## capsula dell'avversario (filo scuro attaccato, contorno acceso fuori), fatto
## per ogni pezzo di pelle del modello. Torna l'elenco che l'avversario tiene
## aggiornato fotogramma per fotogramma.
static func con_contorno(corpo: Node3D, scuro: Color, acceso: Color) -> Array:
	var contorni := []
	var scala: float = float(corpo.get_meta("scala", 1.0))
	for nodo in tutti(corpo):
		if not (nodo is MeshInstance3D):
			continue
		var pezzo := nodo as MeshInstance3D
		for guscio in [
			{"colore": scuro, "quota": Avversario.SPESSORE_FILO / scala},
			{"colore": acceso, "quota": 1.0 / scala},
		]:
			var copia := pezzo.duplicate() as MeshInstance3D
			var pelle := Avversario._pelle_alone(guscio["colore"])
			copia.material_override = pelle
			copia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pezzo.add_sibling(copia)
			contorni.append({"materiale": pelle, "quota": guscio["quota"]})
	return contorni


## La targhetta col nome sopra la testa: risponde a «chi mi ha preso?».
static func targhetta(chi: Node3D, nome: String, altezza: float, colore: Color) -> Label3D:
	var etichetta := Label3D.new()
	etichetta.text = nome
	etichetta.font = carattere_insegne()
	etichetta.font_size = 96
	etichetta.pixel_size = 0.0034
	etichetta.position = Vector3(0, altezza + 0.42, 0)
	etichetta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etichetta.modulate = colore
	etichetta.outline_size = 18
	etichetta.outline_modulate = Color(0.02, 0.02, 0.06, 0.9)
	etichetta.shaded = false
	etichetta.no_depth_test = false
	etichetta.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	chi.add_child(etichetta)
	return etichetta


# ------------------------------------------------------------------ attrezzi

static func carattere_insegne() -> Font:
	if _carattere != null:
		return _carattere
	var base: Font = load(CARATTERE_INSEGNE)
	if base is FontFile:
		var copia: FontFile = (base as FontFile).duplicate()
		copia.generate_mipmaps = true
		_carattere = copia
	else:
		_carattere = Muratura.carattere()
	return _carattere


## Tutti i discendenti di un nodo, in un elenco.
static func tutti(nodo: Node) -> Array:
	var elenco := []
	for figlio in nodo.get_children():
		elenco.append(figlio)
		elenco.append_array(tutti(figlio))
	return elenco


## Il primo discendente di una classe data.
static func trova(nodo: Node, classe: String) -> Node:
	for figlio in nodo.get_children():
		if figlio.is_class(classe):
			return figlio
		var dentro := trova(figlio, classe)
		if dentro != null:
			return dentro
	return null
