class_name Bandiere
extends Node3D

## **Le sette bandiere della GARA** (tappa 11, blocco D1).
##
## Nel 1999 la SpeedBlast era sette bandiere da toccare in ordine, un passaggio solo:
## fuori ordine non contava, chi veniva eliminato ripartiva dall'ultima toccata, e vinceva
## il primo alla settima (`RICERCA-ORIGINALE.md` § 2). Qui ci sono le aste e i posti; le
## regole — chi ha toccato cosa, la classifica, la fine — le tiene l'arena, che conosce i
## concorrenti.
##
## I posti non stanno nella pianta ma in `arene/palestra_gara.json`: li ha misurati
## `tools/misura_bandiere.gd` sulla rete di cammino (tratti vicini a 40 m, 2,5 m liberi
## intorno a ogni asta in tutte le varianti dell'aspetto), e Ludovico li ha approvati il
## 13/10/2026 sull'immagine `ricerca-grezza/stato-2026-10-13/gara-bandiere.png`.
##
## I colori sono quelli del 1999, nello stesso ordine: blu, verde, giallo, arancio, rosso,
## viola e la settima d'oro (letti nelle sei mappe di gara, `RICERCA-ORIGINALE.md` § 2).
## Come sono fatte (*mio*): un'asta chiara col drappo del suo colore e il numero grande
## sopra; la settima tutta d'oro, asta compresa, perché il giallo della terza non le somigli.
## Quella che **tu** devi toccare adesso ha l'anello a terra e una colonna di luce nel suo
## colore, che si vede da tutta l'arena; quelle già toccate si spengono. Verde e blu sono
## anche il RADAR e il FULMINE: le distingue la forma, un'asta non è una palla che galleggia.
## Nessun materiale nuovo: lo stesso shader dei neon
## per drappi e anelli, quello del contorno dei corpi per la colonna, la targhetta dei nomi
## per i numeri — e l'arena le costruisce prima della vetrina, che le scalda.

const PERCORSO := "res://arene/palestra_gara.json"

## Quanto vicino all'asta si tocca la bandiera: in pianta e in altezza, dai piedi. Più
## largo del corpo (0,42) ma dentro i 2,5 m liberi che la misura ha garantito intorno.
const RAGGIO_TOCCO := 1.6
const ALTEZZA_TOCCO := 1.6

## La griglia di partenza: due file da tre, a due metri, col davanti verso la prima
## bandiera. A due metri e mezzo uno dei sei posti toccava un cassone (misura del 13/10).
const PASSO_GRIGLIA := 2.0

## Da quanto lontano dall'asta si riparte dopo un colpo: un passo verso la bandiera dopo,
## così non si nasce dentro l'asta e si guarda già dove andare.
const RIPARTENZA := 1.4

## Alta quanto due persone: da trenta metri, sotto lo schermo del telefono, un'asta di tre
## metri era un fiammifero (scatti del 23/10/2026).
const ALTA := 4.2
const COLORI: Array[Color] = [
	Color(0.18, 0.44, 1.0),   # blu
	Color(0.16, 0.84, 0.34),  # verde
	Color(1.0, 0.94, 0.30),   # giallo
	Color(1.0, 0.52, 0.10),   # arancio
	Color(1.0, 0.20, 0.20),   # rosso
	Color(0.66, 0.28, 1.0),   # viola
	Color(1.0, 0.72, 0.12),   # oro
]
const SPENTA := Color(0.36, 0.36, 0.44)

var _posti: Array[Vector3] = []
var _partenza := Vector3.ZERO
## Per ogni asta: `{"drappo", "anello", "numero", "acceso", "normale"}`.
var _aste: Array[Dictionary] = []
var _colonna: MeshInstance3D
var _anima: MeshInstance3D
var _pelle_colonna: StandardMaterial3D
var _pelle_anima: StandardMaterial3D
var _grigio: StandardMaterial3D


## Il percorso, letto dal suo file.
static func carica(percorso := PERCORSO) -> Dictionary:
	var letto: Variant = JSON.parse_string(FileAccess.get_file_as_string(percorso))
	assert(letto is Dictionary, "percorso della gara illeggibile: %s" % percorso)
	return letto as Dictionary


## Costruisce le aste nei posti del percorso. Restano spente finché non si corre.
func prepara(percorso: Dictionary) -> void:
	name = "bandiere"
	visible = false
	var p: Dictionary = percorso["partenza"]
	_partenza = Vector3(float(p["dove"][0]), float(p["quota"]), float(p["dove"][1]))
	for b in percorso["bandiere"]:
		_posti.append(Vector3(float(b["dove"][0]), float(b["quota"]), float(b["dove"][1])))
	_grigio = _per_vertice(Muratura.tinta_unita(SPENTA, 0.6))
	for i in _posti.size():
		_aste.append(_asta(i))
	# La colonna: un tubo largo e velato nel colore della bandiera, e dentro un'anima
	# stretta e chiara. Velata e basta, contro il cielo non si vedeva (scatto del 23/10/2026):
	# è l'anima chiara che la fa leggere come un fascio di luce.
	_pelle_colonna = Corpo.pelle_contorno(Color(1, 1, 1, 0.42))
	_pelle_colonna.grow_amount = 0.0
	_pelle_anima = Corpo.pelle_contorno(Color(1, 1, 1, 0.8))
	_pelle_anima.grow_amount = 0.0
	_colonna = _tubo(0.8, _pelle_colonna)
	_anima = _tubo(0.22, _pelle_anima)
	segna(0)


func quante() -> int:
	return _posti.size()


## Il piede dell'asta `i`: il pavimento dove sta.
func dove(i: int) -> Vector3:
	return _posti[i]


## Il centro della griglia di partenza.
func partenza() -> Vector3:
	return _partenza


## I sei posti della griglia.
func griglia() -> Array[Vector3]:
	return griglia_di_partenza(_partenza, _posti[0])


## Due file da tre a `PASSO_GRIGLIA`, col davanti verso la prima bandiera: i posti si
## contano dalla fila davanti, da sinistra. La usa anche `tools/misura_bandiere.gd`, che
## ha controllato posto per posto che ci stia un corpo.
static func griglia_di_partenza(centro: Vector3, prima: Vector3) -> Array[Vector3]:
	var avanti := Vector3(prima.x - centro.x, 0.0, prima.z - centro.z).normalized()
	var lato := Vector3(-avanti.z, 0.0, avanti.x)
	var posti: Array[Vector3] = []
	for fila in [0.5, -0.5]:
		for colonna in [-1.0, 0.0, 1.0]:
			posti.append(centro + avanti * fila * PASSO_GRIGLIA + lato * colonna * PASSO_GRIGLIA)
	return posti


## Il verso, in gradi come `Giocatore.punta`, per guardare da `da` verso `a`.
static func giro_verso(da: Vector3, a: Vector3) -> float:
	var d := a - da
	return rad_to_deg(atan2(-d.x, -d.z))


## Chi sta in `dove` (i piedi) tocca la bandiera `i`?
func tocca(i: int, piedi: Vector3) -> bool:
	var p := _posti[i]
	return Vector2(piedi.x - p.x, piedi.z - p.z).length() <= RAGGIO_TOCCO \
			and absf(piedi.y - p.y) <= ALTEZZA_TOCCO


## Dove si riparte dopo un colpo, avendo toccato per ultima la bandiera `i`: un passo
## verso la prossima, se lì c'è posto per un corpo, se no al piede dell'asta. Il verso
## guarda la prossima. `{"dove", "giro"}`, come i punti di rinascita.
func posto_di_ripartenza(i: int, spazio: PhysicsDirectSpaceState3D) -> Dictionary:
	var base := _posti[i]
	var dopo := _posti[mini(i + 1, _posti.size() - 1)]
	var verso := Vector3(dopo.x - base.x, 0.0, dopo.z - base.z)
	var dove := base
	if verso.length_squared() > 0.01:
		var provato := base + verso.normalized() * RIPARTENZA
		if _c_e_posto(provato, spazio):
			dove = provato
	return {"dove": dove + Vector3(0, 0.4, 0), "giro": giro_verso(dove, dopo)}


func _c_e_posto(piedi: Vector3, spazio: PhysicsDirectSpaceState3D) -> bool:
	var capsula := CapsuleShape3D.new()
	capsula.radius = Avversario.RAGGIO_CORPO
	capsula.height = Avversario.ALTEZZA_CORPO
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = capsula
	domanda.collision_mask = Strati.SOLIDO
	domanda.transform = Transform3D(Basis.IDENTITY, piedi + Vector3(0, Avversario.ALTEZZA_CORPO * 0.5 + 0.05, 0))
	return spazio.intersect_shape(domanda, 1).is_empty()


## Accese o spente tutte: si vedono solo in gara.
func mostra(accese: bool) -> void:
	visible = accese


## Quello che vede chi gioca: le bandiere prima di `prossima` già toccate e spente,
## `prossima` accesa con l'anello e la colonna, le altre in attesa. Oltre l'ultima, niente
## colonna: la gara è finita.
func segna(prossima: int) -> void:
	for i in _aste.size():
		var asta: Dictionary = _aste[i]
		var drappo := asta["drappo"] as MeshInstance3D
		var numero := asta["numero"] as Label3D
		if i < prossima:
			drappo.material_override = _grigio
			numero.modulate = Color(SPENTA.r, SPENTA.g, SPENTA.b, 0.95)
		elif i == prossima:
			drappo.material_override = asta["acceso"]
			numero.modulate = Color(1, 1, 1, 0.98)
		else:
			drappo.material_override = asta["normale"]
			numero.modulate = Color(1, 1, 1, 0.8)
		(asta["anello"] as Node3D).visible = i == prossima
	_colonna.visible = prossima < _aste.size()
	_anima.visible = _colonna.visible
	if _colonna.visible:
		for tubo in [_colonna, _anima]:
			(tubo as Node3D).position = _posti[prossima] + Vector3(0, ALTA_COLONNA * 0.5 + 0.02, 0)
		var colore := colore_di(prossima)
		_pelle_colonna.albedo_color = Color(colore.r, colore.g, colore.b, 0.42)
		var chiaro := colore.lerp(Color.WHITE, 0.6)
		_pelle_anima.albedo_color = Color(chiaro.r, chiaro.g, chiaro.b, 0.8)


const ALTA_COLONNA := 40.0


## Un tubo aperto, alto quanto la colonna. Senza tappi: quello di sotto starebbe in pari
## col pavimento, e due facce in pari lampeggiano (`LEARNED.md` § 49 e 63).
func _tubo(raggio: float, pelle: StandardMaterial3D) -> MeshInstance3D:
	var tubo := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = raggio
	cilindro.bottom_radius = raggio
	cilindro.height = ALTA_COLONNA
	cilindro.radial_segments = 16
	cilindro.rings = 1
	cilindro.cap_top = false
	cilindro.cap_bottom = false
	tubo.mesh = cilindro
	tubo.material_override = pelle
	tubo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tubo)
	return tubo


## Il colore di una bandiera, quello del 1999.
func colore_di(i: int) -> Color:
	return COLORI[clampi(i, 0, COLORI.size() - 1)]


## Un'asta: il palo, il drappo, il numero sopra e l'anello a terra. Il drappo guarda chi
## arriva dalla bandiera prima (o dalla partenza), così si legge di faccia e non di taglio.
func _asta(i: int) -> Dictionary:
	var radice := Node3D.new()
	radice.name = "bandiera_%d" % (i + 1)
	add_child(radice)
	radice.position = _posti[i]
	var prima := _partenza if i == 0 else _posti[i - 1]
	var arrivo := Vector3(prima.x - _posti[i].x, 0.0, prima.z - _posti[i].z)
	if arrivo.length_squared() > 0.01:
		radice.rotation.y = atan2(arrivo.x, arrivo.z)
	var colore := colore_di(i)

	var palo := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 0.08
	cilindro.bottom_radius = 0.1
	cilindro.height = ALTA
	cilindro.radial_segments = 10
	cilindro.rings = 1
	cilindro.cap_bottom = false
	palo.mesh = cilindro
	palo.position = Vector3(0, ALTA * 0.5, 0)
	var ultima := i == _posti.size() - 1
	palo.material_override = _per_vertice(Muratura.acceso(colore, 0.6) if ultima
			else Muratura.tinta_unita(Color(0.92, 0.92, 0.96), 0.4))
	radice.add_child(palo)

	# Il drappo appeso al palo, sul fianco: un telo un dito spesso, non un foglio senza
	# spessore che di taglio sparirebbe. Dietro, un telo bianco un poco più grande e più
	# sottile fa il bordo: un drappo blu davanti al cielo azzurro spariva (23/10/2026). Il
	# colorato è più spesso, così le sue facce stanno davanti al bianco da tutte e due le
	# parti, mai in pari.
	var drappo := MeshInstance3D.new()
	var telo := BoxMesh.new()
	telo.size = Vector3(2.0, 1.3, 0.07) if ultima else Vector3(1.7, 1.1, 0.07)
	drappo.mesh = telo
	drappo.position = Vector3(telo.size.x * 0.5 + 0.16, ALTA - telo.size.y * 0.5 - 0.14, 0)
	drappo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(drappo)
	var bordo := MeshInstance3D.new()
	var dietro := BoxMesh.new()
	dietro.size = telo.size + Vector3(0.22, 0.22, -0.03)
	bordo.mesh = dietro
	bordo.position = drappo.position
	bordo.material_override = _per_vertice(Muratura.acceso(Color(0.97, 0.97, 1.0), 0.55))
	bordo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(bordo)

	# Il numero sopra la punta, girato sempre verso chi guarda: la targhetta dei nomi,
	# grande, così non nasce uno shader nuovo.
	var numero := Avversario.targhetta("%d" % (i + 1))
	numero.font_size = 150
	if numero.fixed_size:
		numero.pixel_size = 0.0014
	else:
		numero.pixel_size = 0.011
	numero.outline_size = 30
	numero.position = Vector3(0, ALTA + 1.05, 0)
	radice.add_child(numero)

	var anello := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = RAGGIO_TOCCO - 0.14
	toro.outer_radius = RAGGIO_TOCCO
	toro.rings = 48
	toro.ring_segments = 6
	anello.mesh = toro
	anello.scale = Vector3(1.0, 0.2, 1.0)
	anello.position = Vector3(0, 0.05, 0)
	anello.material_override = _per_vertice(Muratura.acceso(colore, 0.85))
	anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(anello)

	return {"drappo": drappo, "anello": anello, "numero": numero,
			"acceso": _per_vertice(Muratura.acceso(colore, 0.9)),
			"normale": _per_vertice(Muratura.acceso(colore, 0.4))}


## La luce calcolata sui vertici, come tutti i pezzi dell'arena (`Arena._luce_per_vertice`).
## Si mette qui e non si lascia a lei, perché i drappi cambiano materiale in partita: un
## materiale rimasto per pixel sarebbe uno shader nuovo da compilare nel momento in cui
## tocchi una bandiera.
static func _per_vertice(materiale: StandardMaterial3D) -> StandardMaterial3D:
	materiale.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return materiale
