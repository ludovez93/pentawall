class_name Palle
extends Node3D

## **Le palle, le porte e i cannoni della PALLA** (tappa 11, blocco D2).
##
## Dal 1999 (`RICERCA-ORIGINALE.md` § 2, letto nei file): sei palle colorate e la dorata;
## le colorate escono in campo da cannoni scelti a caso; si raccolgono passandoci sopra e se
## ne portano più d'una; in porta **non si portano, si lanciano**; lanciata addosso a un altro
## gliela consegni; chi muore le perde tutte, che cadono lì; ogni 30 secondi il gioco
## rimette in campo quelle che mancano.
##
## Qui sta la meccanica — chi prende cosa, dove girano le palle portate, il gol, il lancio
## ad arco e la sua traiettoria, le palle perse. Le regole che parlano di punti e di fine
## partita (la dorata, chi ha le sei) le tiene l'arena, che conosce i concorrenti.
##
## I posti delle porte e dei cannoni stanno in `arene/palestra_palla.json`, misurati da
## `tools/misura_porte.gd`. Le porte guardano il campo con la schiena contro un muro; i
## cannoni sono due per ala.

signal presa(chi: Node3D, palla: Palla)
## Una palla è entrata in porta. `autore`: chi l'ha lanciata, se qualcuno.
signal in_porta(palla: Palla, autore: Node3D)

const PERCORSO := "res://arene/palestra_palla.json"

## Quanto vicino si passa per prendere una palla: in pianta dal corpo, e in altezza dai
## piedi fino a sopra la testa (una palla lanciata addosso si prende al volo).
const RAGGIO_PRESA := 1.15
const ALTEZZA_PRESA := 2.3

## La porta: bocca larga quattro metri e alta due e mezzo, profonda uno e sessanta.
const LARGA := 4.0
const ALTA := 2.5
const FONDA := 1.6
const SPESSORE := 0.14

## Dopo un gol la palla riesce da un cannone a caso dopo tanti secondi.
const RITORNO := 1.5
## Ogni quanto si cercano le palle perse (incastrate, fuori dalla rete, sotto l'arena): il
## numero del 1999.
const CONTROLLO := 30.0
## Una palla libera che nessuno tocca per tanto torna da un cannone: rotolata in un posto da
## cui nessuno la va a prendere.
const DIMENTICATA := 60.0

## Il lancio: tanto veloce e tanto sopra la mira. Sul piano arriva a una ventina di metri.
const VELOCITA_LANCIO := 17.0
const ARCO_GRADI := 16.0
## Il passo della traiettoria disegnata, e quanti passi al massimo.
const PASSO_TRAIETTORIA := 1.0 / 20.0
const PASSI_TRAIETTORIA := 60

## Come esce dal cannone: in alto e un poco di lato, a caso.
const SPINTA_CANNONE := 8.5
const SBANDATA_CANNONE := 2.6

var concorrenti: Callable = func() -> Array: return []
var _palle: Array[Palla] = []
## Ogni porta: `{"bocca": Vector3, "verso": Vector3, "base": Transform3D}`. La base ha
## l'origine al centro della bocca, a terra, e +Z verso il campo.
var _porte: Array[Dictionary] = []
var _cannoni: Array[Vector3] = []
var _bocche: Array[Node3D] = []
var _ritorni: Array[Dictionary] = []
var _orologio := 0.0
var _controllo := CONTROLLO
var _attiva := false
var _ultimo_cannone := -1


static var _da_evitare: Array = []


## **Un oggetto in `p` ingombra la PALLA?** Le prove dell'arena aperta (GONFIABILE, PISTA)
## posano i loro oggetti in campo prima che porte e cannoni esistessero: il collaudo li ha
## trovati sopra cinque cannoni e nella corsia di una porta (23/10/2026). Un oggetto largo
## `mezzo` non sta a meno di 2,6 m da un cannone né nella corsia davanti a una porta (dieci
## metri e mezzo, larga quanto la porta più un margine), porta compresa.
static func ingombra(p: Vector2, mezzo: float) -> bool:
	if _da_evitare.is_empty():
		var percorso := carica()
		for c in percorso["cannoni"]:
			_da_evitare.append([Vector2(float(c["dove"][0]), float(c["dove"][1])), Vector2.INF, 2.6])
		for porta in percorso["porte"]:
			var bocca := Vector2(float(porta["bocca"][0]), float(porta["bocca"][1]))
			var verso := Vector2(float(porta["verso"][0]), float(porta["verso"][1])).normalized()
			_da_evitare.append([bocca - verso * (FONDA + 0.2), bocca + verso * 10.5, LARGA * 0.5 + 0.4])
	for e in _da_evitare:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var vicino := a if b == Vector2.INF else Geometry2D.get_closest_point_to_segment(p, a, b)
		if p.distance_to(vicino) < float(e[2]) + mezzo:
			return true
	return false


static func carica(percorso := PERCORSO) -> Dictionary:
	var letto: Variant = JSON.parse_string(FileAccess.get_file_as_string(percorso))
	assert(letto is Dictionary, "porte e cannoni illeggibili: %s" % percorso)
	return letto as Dictionary


func prepara(percorso: Dictionary) -> void:
	name = "palle"
	visible = false
	for p in percorso["porte"]:
		var bocca := Vector3(float(p["bocca"][0]), float(p["quota"]), float(p["bocca"][1]))
		var verso := Vector3(float(p["verso"][0]), 0.0, float(p["verso"][1])).normalized()
		var base := Transform3D(Basis.looking_at(-verso, Vector3.UP), bocca)
		_porte.append({"bocca": bocca, "verso": verso, "base": base})
		_porta(base)
	for c in percorso["cannoni"]:
		var dove := Vector3(float(c["dove"][0]), float(c["quota"]), float(c["dove"][1]))
		_cannoni.append(dove)
		_cannone(dove)
	for i in Palla.VALORI.size():
		_palle.append(Palla.crea(self, i))


## Accese o spente: si vedono solo nella PALLA. Spente, le palle escono dal campo e le porte
## smettono di fermare qualcosa.
func mostra(accese: bool) -> void:
	visible = accese
	for porta in get_children():
		if porta is StaticBody3D:
			(porta as StaticBody3D).collision_layer = Strati.OSTACOLO if accese else 0
	if not accese:
		_attiva = false
		_ritorni.clear()
		for palla in _palle:
			palla.fuori_campo()


## Una partita nuova: tutte fuori, poi le sei colorate escono dai cannoni, ognuna da uno
## diverso. La dorata aspetta il suo momento.
func riparti() -> void:
	_attiva = true
	_orologio = 0.0
	_controllo = CONTROLLO
	_ritorni.clear()
	var giro := range(_cannoni.size())
	giro.shuffle()
	for palla in _palle:
		palla.fuori_campo()
	for i in Palla.DORATA:
		_dal_cannone(_palle[i], int(giro[i % giro.size()]))


## La partita è finita: le palle restano dove sono, e nessuno prende più niente.
func ferma() -> void:
	_attiva = false
	_ritorni.clear()


func palle() -> Array[Palla]:
	return _palle


func dorata() -> Palla:
	return _palle[Palla.DORATA]


func porte() -> Array[Dictionary]:
	return _porte


func cannoni() -> Array[Vector3]:
	return _cannoni


## Le palle che porta `chi`, nell'ordine in cui le ha prese.
func portate_da(chi: Object) -> Array[Palla]:
	var sue: Array[Palla] = []
	for palla in _palle:
		if palla.portata_da == chi:
			sue.append(palla)
	return sue


## Esce da un cannone a caso fra `dopo` secondi (subito con zero).
func fai_uscire(palla: Palla, dopo := 0.0) -> void:
	palla.fuori_campo()
	if dopo <= 0.0:
		_dal_cannone(palla, _cannone_a_caso())
	else:
		_ritorni.append({"palla": palla, "quando": _orologio + dopo})


## Chi è colpito perde tutte le palle che porta: cadono dove stava, con un saltello.
func lascia_tutte(chi: Node3D) -> void:
	var sue := portate_da(chi)
	for i in sue.size():
		var giro := TAU * float(i) / float(maxi(sue.size(), 1)) + randf() * 0.6
		var spinta := Vector3(cos(giro) * 2.2, 4.0, sin(giro) * 2.2)
		sue[i].in_campo_da(chi.global_position + Vector3(0, 1.0, 0), spinta, null, _orologio, chi)


## La palla che `chi` lancerebbe adesso: la prima che porta fra quelle che non ha ancora
## segnato (`segnate`: gli indici), e se le ha segnate tutte la prima che porta.
func prossima(chi: Object, segnate: Array) -> Palla:
	var sue := portate_da(chi)
	for palla in sue:
		if not segnate.has(palla.indice):
			return palla
	return sue[0] if not sue.is_empty() else null


## Lancia `palla` da dove sta `chi`, con la velocità data. Da quel momento è lui l'autore.
func lancia(chi: Node3D, palla: Palla, velocita: Vector3) -> void:
	if palla == null or palla.portata_da != chi:
		return
	palla.in_campo_da(da_dove_si_lancia(chi, velocita), velocita, chi, _orologio)


## Da dove parte una palla lanciata: davanti al petto, nel verso del lancio.
func da_dove_si_lancia(chi: Node3D, velocita: Vector3) -> Vector3:
	var avanti := Vector3(velocita.x, 0.0, velocita.z)
	if avanti.length_squared() < 0.001:
		avanti = -chi.global_transform.basis.z
	return chi.global_position + Vector3(0, 1.35, 0) + avanti.normalized() * 0.75


## La velocità del lancio di chi gioca: dove guarda, sollevato di `ARCO_GRADI`.
static func velocita_del_lancio(mira: Vector3) -> Vector3:
	var orizzontale := Vector3(mira.x, 0.0, mira.z)
	if orizzontale.length_squared() < 0.0001:
		orizzontale = Vector3.FORWARD
	var asse := orizzontale.normalized().cross(Vector3.UP).normalized()
	return mira.normalized().rotated(asse, deg_to_rad(ARCO_GRADI)) * VELOCITA_LANCIO


## La velocità con cui una palla lanciata da `da` arriva in `a`, con l'arco basso, alla
## velocità del lancio; `Vector3.INF` se è troppo lontano. È il conto degli avversari.
static func velocita_verso(da: Vector3, a: Vector3) -> Vector3:
	var piano := Vector3(a.x - da.x, 0.0, a.z - da.z)
	var x := piano.length()
	var y := a.y - da.y
	if x < 0.1:
		return Vector3.INF
	var v := VELOCITA_LANCIO
	var g := Palla.GRAVITA
	var dentro := v * v * v * v - g * (g * x * x + 2.0 * y * v * v)
	if dentro < 0.0:
		return Vector3.INF
	var angolo := atan((v * v - sqrt(dentro)) / (g * x))
	return piano.normalized() * v * cos(angolo) + Vector3.UP * v * sin(angolo)


## La strada che farà una palla lanciata da `da` con `velocita`, fino al primo urto: la
## stessa caduta e lo stesso freno della palla vera, a passi di un ventesimo. L'ultimo punto
## è dove sta il centro della palla quando batte.
##
## Scorre una **sfera grande quanto la palla**, non un raggio: la palla è larga ottanta
## centimetri, e un raggio sottile passava di fianco a un oggetto che la palla vera prendeva
## di striscio (collaudo nelle prove dell'arena aperta, 23/10/2026).
func traiettoria(da: Vector3, velocita: Vector3) -> PackedVector3Array:
	var punti := PackedVector3Array([da])
	var spazio := get_world_3d().direct_space_state
	var sfera := SphereShape3D.new()
	sfera.radius = Palla.RAGGIO
	var domanda := PhysicsShapeQueryParameters3D.new()
	domanda.shape = sfera
	domanda.collision_mask = Strati.SOLIDO
	var p := da
	var v := velocita
	var passo := PASSO_TRAIETTORIA
	var smorzo := 1.0 - Palla.FRENO_IN_VOLO * passo
	for i in PASSI_TRAIETTORIA:
		v.y -= Palla.GRAVITA * passo
		v *= smorzo
		var tratto := v * passo
		domanda.transform = Transform3D(Basis.IDENTITY, p)
		domanda.motion = tratto
		var quanto := spazio.cast_motion(domanda)
		if quanto[0] < 1.0:
			punti.append(p + tratto * float(quanto[0]))
			return punti
		p += tratto
		punti.append(p)
	return punti


## Se `dove` è dentro la bocca di una porta: l'indice della porta, o -1.
func porta_di(dove: Vector3) -> int:
	for i in _porte.size():
		var locale: Vector3 = (_porte[i]["base"] as Transform3D).affine_inverse() * dove
		if absf(locale.x) < LARGA * 0.5 and locale.y > 0.0 and locale.y < ALTA \
				and locale.z < -0.15 and locale.z > -FONDA:
			return i
	return -1


## Il punto davanti a una porta da cui tirare, a `quanto` metri dalla bocca, e il centro
## della bocca a cui mirare.
func davanti_alla_porta(i: int, quanto: float) -> Vector3:
	return (_porte[i]["bocca"] as Vector3) + (_porte[i]["verso"] as Vector3) * quanto


func centro_della_porta(i: int) -> Vector3:
	return (_porte[i]["bocca"] as Vector3) - (_porte[i]["verso"] as Vector3) * (FONDA * 0.5) \
			+ Vector3(0, ALTA * 0.45, 0)


func _physics_process(delta: float) -> void:
	if not _attiva:
		return
	_orologio += delta
	for i in range(_ritorni.size() - 1, -1, -1):
		if float(_ritorni[i]["quando"]) <= _orologio:
			var palla: Palla = _ritorni[i]["palla"]
			_ritorni.remove_at(i)
			_dal_cannone(palla, _cannone_a_caso())
	var corpi: Array = concorrenti.call()
	for palla in _palle:
		if not palla.libera():
			continue
		palla.ferma_da += delta
		# In porta: si segna. Dentro la porta non si prende, o chi ci passa davanti la
		# ruberebbe al gol.
		if porta_di(palla.global_position) >= 0:
			var autore := palla.lanciata_da
			palla.fuori_campo()
			in_porta.emit(palla, autore)
			continue
		for corpo in corpi:
			if not (corpo is Node3D) or not is_instance_valid(corpo):
				continue
			var piedi := (corpo as Node3D).global_position
			var su := palla.global_position.y - piedi.y
			if su < -0.6 or su > ALTEZZA_PRESA:
				continue
			if Vector2(palla.global_position.x - piedi.x, palla.global_position.z - piedi.z).length() > RAGGIO_PRESA:
				continue
			if not palla.si_prende(corpo as Node3D, _orologio):
				continue
			palla.prendi(corpo as Node3D)
			presa.emit(corpo, palla)
			break
	_controllo -= delta
	if _controllo <= 0.0:
		_controllo = CONTROLLO
		_cerca_le_perse()


## Le palle portate stanno sulla schiena di chi le porta, impilate come uno zaino, e
## girano su sé stesse. Fino al primo scatto (23/10/2026) giravano intorno al corpo, e in
## terza persona passavano fra la camera e il bersaglio, coprendo anche l'arco del lancio.
func _process(_delta: float) -> void:
	var per_chi := {}
	for palla in _palle:
		if palla.portata_da == null:
			continue
		if not is_instance_valid(palla.portata_da):
			palla.in_campo_da(palla.global_position, Vector3.ZERO, null, _orologio)
			continue
		var chiave := palla.portata_da.get_instance_id()
		var quante: int = per_chi.get(chiave, 0)
		per_chi[chiave] = quante + 1
		var base := palla.portata_da.global_transform.basis
		var dietro := Vector3(base.z.x, 0.0, base.z.z).normalized()
		var lato := Vector3(base.x.x, 0.0, base.x.z).normalized()
		var dove := palla.portata_da.global_position + dietro * 0.5 				+ lato * (0.17 if quante % 2 == 0 else -0.17) 				+ Vector3(0, 1.0 + 0.3 * float(quante), 0)
		palla.segui(dove)
		palla.rotation.y = _orologio * 2.0 + float(quante)


## **Le palle perse** tornano da un cannone: sotto l'arena, lontane dalla rete di cammino (su
## un muro, incastrate) o ferme da un minuto senza che nessuno le tocchi.
func _cerca_le_perse() -> void:
	var mappa := get_world_3d().navigation_map
	var rete := not NavigationServer3D.map_get_regions(mappa).is_empty()
	for palla in _palle:
		if not palla.libera():
			continue
		var dove := palla.global_position
		var persa := dove.y < -6.0 or palla.ferma_da > DIMENTICATA
		if not persa and rete:
			persa = NavigationServer3D.map_get_closest_point(mappa, dove).distance_to(dove) > 2.2
		if persa:
			_dal_cannone(palla, _cannone_a_caso())


func _cannone_a_caso() -> int:
	if _cannoni.size() <= 1:
		return 0
	var quale := randi() % _cannoni.size()
	if quale == _ultimo_cannone:
		quale = (quale + 1) % _cannoni.size()
	_ultimo_cannone = quale
	return quale


func _dal_cannone(palla: Palla, quale: int) -> void:
	if _cannoni.is_empty():
		return
	var bocca := _cannoni[quale] + Vector3(0, 1.3, 0)
	var giro := randf() * TAU
	var spinta := Vector3(cos(giro) * SBANDATA_CANNONE, SPINTA_CANNONE, sin(giro) * SBANDATA_CANNONE)
	palla.in_campo_da(bocca, spinta, null, _orologio)
	Scintille.presa(bocca, palla.colore)


# ------------------------------------------------------------------ l'aspetto

## Una porta: due pali e la traversa al neon, i fianchi, il tetto e il fondo scuri. Ferma
## dardi e palle come un muro (`Strati.OSTACOLO`), e la bocca resta aperta.
func _porta(base: Transform3D) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "porta_%d" % _porte.size()
	corpo.collision_layer = 0
	corpo.collision_mask = 0
	add_child(corpo)
	corpo.global_transform = base
	var fondo := Bandiere._per_vertice(Muratura.tinta_unita(Color(0.08, 0.08, 0.16), 0.8))
	var cornice := Bandiere._per_vertice(Muratura.acceso(Color(0.96, 0.96, 1.0), 0.75))
	var mezzo := LARGA * 0.5 + SPESSORE * 0.5
	# Il fondo, i fianchi e il tetto: dentro la bocca, dietro i pali.
	_pezzo(corpo, Vector3(0, ALTA * 0.5, -FONDA + SPESSORE * 0.5), Vector3(LARGA + SPESSORE * 2.0, ALTA, SPESSORE), fondo)
	_pezzo(corpo, Vector3(-mezzo, ALTA * 0.5, -FONDA * 0.5), Vector3(SPESSORE, ALTA, FONDA), fondo)
	_pezzo(corpo, Vector3(mezzo, ALTA * 0.5, -FONDA * 0.5), Vector3(SPESSORE, ALTA, FONDA), fondo)
	_pezzo(corpo, Vector3(0, ALTA + SPESSORE * 0.5, -FONDA * 0.5), Vector3(LARGA + SPESSORE * 2.0, SPESSORE, FONDA), fondo)
	# La cornice accesa sulla bocca, un dito più fuori dei fianchi: mai due facce in pari.
	_pezzo(corpo, Vector3(-mezzo, ALTA * 0.5 + 0.06, 0.02), Vector3(SPESSORE + 0.06, ALTA + 0.12, 0.1), cornice)
	_pezzo(corpo, Vector3(mezzo, ALTA * 0.5 + 0.06, 0.02), Vector3(SPESSORE + 0.06, ALTA + 0.12, 0.1), cornice)
	_pezzo(corpo, Vector3(0, ALTA + SPESSORE * 0.5 + 0.03, 0.02), Vector3(LARGA + SPESSORE * 2.0 + 0.06, SPESSORE + 0.06, 0.1), cornice)
	# La scritta sopra la traversa.
	var scritta := Label3D.new()
	scritta.text = "PORTA"
	scritta.font = Vestizione.carattere_insegne()
	scritta.font_size = 120
	scritta.pixel_size = 0.006
	scritta.modulate = Color(0.96, 0.96, 1.0)
	scritta.outline_size = 0
	scritta.shaded = false
	scritta.double_sided = true
	scritta.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	scritta.position = Vector3(0, ALTA + 0.75, 0.08)
	corpo.add_child(scritta)


func _pezzo(corpo: StaticBody3D, centro: Vector3, misura: Vector3, materiale: StandardMaterial3D) -> void:
	var vista := MeshInstance3D.new()
	var scatola := BoxMesh.new()
	scatola.size = misura
	vista.mesh = scatola
	vista.position = centro
	vista.material_override = materiale
	corpo.add_child(vista)
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = misura
	forma.shape = box
	forma.position = centro
	corpo.add_child(forma)


## Un cannone: un mortaio basso, scuro, con l'anello acceso in bocca. Niente collisione: è
## piccolo, e la rete di cammino non lo conosce.
func _cannone(dove: Vector3) -> void:
	var radice := Node3D.new()
	radice.name = "cannone_%d" % _cannoni.size()
	add_child(radice)
	radice.position = dove
	var scuro := Bandiere._per_vertice(Muratura.tinta_unita(Color(0.12, 0.12, 0.22), 0.6))
	var base := MeshInstance3D.new()
	var piede := CylinderMesh.new()
	piede.top_radius = 0.55
	piede.bottom_radius = 0.7
	piede.height = 0.4
	piede.radial_segments = 16
	piede.cap_bottom = false
	base.mesh = piede
	base.position = Vector3(0, 0.2, 0)
	base.material_override = scuro
	radice.add_child(base)
	var tubo := MeshInstance3D.new()
	var canna := CylinderMesh.new()
	canna.top_radius = 0.42
	canna.bottom_radius = 0.36
	canna.height = 0.8
	canna.radial_segments = 16
	canna.cap_top = false
	tubo.mesh = canna
	tubo.position = Vector3(0, 0.78, 0)
	tubo.material_override = scuro
	radice.add_child(tubo)
	var anello := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.36
	toro.outer_radius = 0.47
	toro.rings = 24
	toro.ring_segments = 6
	anello.mesh = toro
	anello.position = Vector3(0, 1.2, 0)
	anello.material_override = Bandiere._per_vertice(Muratura.acceso(Color(0.96, 0.96, 1.0), 0.8))
	radice.add_child(anello)
