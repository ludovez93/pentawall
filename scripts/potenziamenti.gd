class_name Potenziamenti
extends Node3D

## **Le palle colorate** (tappa 8, blocco H).
##
## È l'unica cosa che Ludovico ricordava del gioco del 1999 prima ancora del nome:
## *«il personaggio si potenziava raccogliendo palle colorate»* (24/08/2026). Nel
## gioco non c'erano. Qui ci sono i due potenziamenti dell'originale
## (`RICERCA-ORIGINALE.md` § 7), sfere luminose che fluttuano e girano su un anello a
## terra, e si prendono passandoci sopra:
## - **PUNTI DOPPI** (nel 1999 *Double Damage*: da noi il danno sono i punti) — oro;
## - **TURBO** (nel 1999 *Mega Speed*) — magenta.
## Valgono per tutti: anche gli avversari ci vanno, se ci passano vicino.
##
## *Numeri nostri* (le partite del 1999 duravano dieci minuti, le nostre tre):
## punti doppi per 15 secondi (là 30), turbo per 5 secondi a velocità ×1,6 (là ×2),
## e la sfera ricompare dopo 40 secondi.

signal preso(chi: Node3D, tipo: String)
signal finito(chi: Node3D, tipo: String)

const TIPI := {
	"doppio": {"nome": "PUNTI DOPPI", "colore": Color(1.0, 0.80, 0.26), "durata": 15.0},
	"turbo": {"nome": "TURBO", "colore": Color(1.0, 0.30, 0.78), "durata": 5.0},
}
const SPINTA_TURBO := 1.6
const RICOMPARSA := 40.0
const RAGGIO_PRESA := 1.25
const ALTEZZA := 1.15

## Dove sono le sfere disponibili in questo momento: gli avversari le guardano per
## decidere se vale la pena andarle a prendere.
static var disponibili: Array[Vector3] = []

## Chi deve poter raccogliere: lo dà l'arena, perché i concorrenti li conosce lei.
var concorrenti: Callable = func() -> Array: return []

## `{"tipo", "dove", "nodo", "attesa"}` per sfera; `attesa` > 0 vuol dire «non c'è».
var _sfere: Array[Dictionary] = []
## Gli effetti in corso: `{id del corpo: {"doppio": secondi, "turbo": secondi}}`.
var _effetti := {}
var _tempo := 0.0
var _ricomparsa := RICOMPARSA


## Mette le sfere nei posti dati: `[{"tipo", "dove"}]`.
func prepara(posti: Array) -> void:
	for posto in posti:
		var nodo := _sfera(String(posto["tipo"]))
		add_child(nodo)
		nodo.global_position = posto["dove"]
		_sfere.append({"tipo": String(posto["tipo"]), "dove": posto["dove"], "nodo": nodo,
				"attesa": 0.0})
	_aggiorna_disponibili()


## Tutte di nuovo al loro posto, e nessuno potenziato: si riparte da zero.
func riparti() -> void:
	for sfera in _sfere:
		sfera["attesa"] = 0.0
		(sfera["nodo"] as Node3D).visible = true
	for chiave in _effetti.keys():
		var corpo := instance_from_id(int(chiave)) as Node3D
		if corpo != null:
			_applica_turbo(corpo, false)
			_aura(corpo, "", false)
	_effetti.clear()
	_aggiorna_disponibili()


## Quanto si aspetta prima che una sfera presa ricompaia. I collaudi lo abbassano.
func imposta_ricomparsa(secondi: float) -> void:
	_ricomparsa = maxf(secondi, 0.1)


## Ha i punti doppi adesso?
func ha(chi: Object, tipo: String) -> bool:
	if chi == null:
		return false
	var effetti: Dictionary = _effetti.get(chi.get_instance_id(), {})
	return float(effetti.get(tipo, 0.0)) > 0.0


## Quanto manca alla fine di un effetto, in secondi (zero se non c'è).
func resto(chi: Object, tipo: String) -> float:
	if chi == null:
		return 0.0
	var effetti: Dictionary = _effetti.get(chi.get_instance_id(), {})
	return float(effetti.get(tipo, 0.0))


func quante_disponibili() -> int:
	var conta := 0
	for sfera in _sfere:
		if float(sfera["attesa"]) <= 0.0:
			conta += 1
	return conta


func posti() -> Array:
	var fuori := []
	for sfera in _sfere:
		fuori.append({"tipo": sfera["tipo"], "dove": sfera["dove"]})
	return fuori


func _process(delta: float) -> void:
	_tempo += delta
	# Le sfere respirano e girano: si devono notare da lontano.
	for sfera in _sfere:
		var nodo := sfera["nodo"] as Node3D
		if not nodo.visible:
			continue
		var palla := nodo.get_node("palla") as Node3D
		palla.position.y = ALTEZZA + sin(_tempo * 2.2) * 0.14
		palla.rotation.y = _tempo * 1.6


func _physics_process(delta: float) -> void:
	# Le sfere prese ricompaiono.
	var cambiato := false
	for sfera in _sfere:
		if float(sfera["attesa"]) > 0.0:
			sfera["attesa"] = float(sfera["attesa"]) - delta
			if float(sfera["attesa"]) <= 0.0:
				(sfera["nodo"] as Node3D).visible = true
				Scintille.presa(sfera["dove"] + Vector3(0, ALTEZZA, 0), TIPI[sfera["tipo"]]["colore"])
				cambiato = true
	# Chi ci passa sopra la prende.
	for corpo in concorrenti.call():
		if not (corpo is Node3D) or not is_instance_valid(corpo):
			continue
		var dove := (corpo as Node3D).global_position
		for sfera in _sfere:
			if float(sfera["attesa"]) > 0.0:
				continue
			var centro: Vector3 = sfera["dove"]
			if Vector2(dove.x - centro.x, dove.z - centro.z).length() <= RAGGIO_PRESA \
					and absf(dove.y - centro.y) < 2.0:
				_prendi(corpo as Node3D, sfera)
				cambiato = true
	# Gli effetti scadono.
	for chiave in _effetti.keys():
		var effetti: Dictionary = _effetti[chiave]
		var corpo := instance_from_id(int(chiave)) as Node3D
		for tipo in effetti.keys():
			effetti[tipo] = float(effetti[tipo]) - delta
			if float(effetti[tipo]) <= 0.0:
				effetti.erase(tipo)
				if corpo != null and is_instance_valid(corpo):
					if tipo == "turbo":
						_applica_turbo(corpo, false)
					_aura(corpo, tipo, false)
					finito.emit(corpo, tipo)
		if effetti.is_empty():
			_effetti.erase(chiave)
	if cambiato:
		_aggiorna_disponibili()


func _prendi(corpo: Node3D, sfera: Dictionary) -> void:
	var tipo := String(sfera["tipo"])
	sfera["attesa"] = _ricomparsa
	(sfera["nodo"] as Node3D).visible = false
	var chiave := corpo.get_instance_id()
	if not _effetti.has(chiave):
		_effetti[chiave] = {}
	_effetti[chiave][tipo] = float(TIPI[tipo]["durata"])
	if tipo == "turbo":
		_applica_turbo(corpo, true)
	_aura(corpo, tipo, true)
	Scintille.presa(sfera["dove"] + Vector3(0, ALTEZZA, 0), TIPI[tipo]["colore"])
	preso.emit(corpo, tipo)


func _applica_turbo(corpo: Node3D, acceso: bool) -> void:
	if "spinta" in corpo:
		corpo.set("spinta", SPINTA_TURBO if acceso else 1.0)


## L'anello di luce ai piedi di chi è potenziato: si vede da lontano chi ha cosa.
func _aura(corpo: Node3D, tipo: String, accesa: bool) -> void:
	var vecchia := corpo.get_node_or_null("aura_potenziamento")
	if not accesa:
		if vecchia != null and (tipo == "" or vecchia.get_meta("tipo", "") == tipo):
			vecchia.queue_free()
		return
	if vecchia != null:
		vecchia.queue_free()
	var anello := MeshInstance3D.new()
	anello.name = "aura_potenziamento"
	anello.set_meta("tipo", tipo)
	var toro := TorusMesh.new()
	toro.inner_radius = 0.55
	toro.outer_radius = 0.68
	toro.rings = 32
	toro.ring_segments = 6
	anello.mesh = toro
	anello.scale = Vector3(1.0, 0.25, 1.0)
	anello.position = Vector3(0, 0.06, 0)
	anello.material_override = Muratura.acceso(TIPI[tipo]["colore"], 0.95)
	anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corpo.add_child(anello)


func _aggiorna_disponibili() -> void:
	var fuori: Array[Vector3] = []
	for sfera in _sfere:
		if float(sfera["attesa"]) <= 0.0:
			fuori.append(sfera["dove"])
	disponibili = fuori


func _exit_tree() -> void:
	disponibili = []


## Una sfera: la palla luminosa col suo nome sopra, e l'anello a terra che dice «qui».
func _sfera(tipo: String) -> Node3D:
	var dati: Dictionary = TIPI[tipo]
	var colore: Color = dati["colore"]
	var radice := Node3D.new()
	radice.name = "potenziamento_" + tipo

	var palla := Node3D.new()
	palla.name = "palla"
	palla.position = Vector3(0, ALTEZZA, 0)
	radice.add_child(palla)
	var guscio := MeshInstance3D.new()
	var sfera := SphereMesh.new()
	sfera.radius = 0.36
	sfera.height = 0.72
	sfera.radial_segments = 20
	sfera.rings = 10
	guscio.mesh = sfera
	var pelle := StandardMaterial3D.new()
	pelle.albedo_color = colore
	pelle.roughness = 0.15
	pelle.metallic = 0.3
	pelle.emission_enabled = true
	pelle.emission = colore
	# Accesa, ma sotto la soglia del bagliore: sopra l'uno ci va solo il dardo.
	# Senza il bordo di luce (`rim`) che aveva il 03/10/2026: era l'unico materiale
	# dell'arena ad averlo, e uno shader in più sono cinque compilazioni sul
	# telefono (tappa 9). La palla si vede perché è accesa, non per il bordo.
	pelle.emission_energy_multiplier = 0.9
	guscio.material_override = pelle
	guscio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	palla.add_child(guscio)

	var anello := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.75
	toro.outer_radius = 0.9
	toro.rings = 40
	toro.ring_segments = 6
	anello.mesh = toro
	anello.scale = Vector3(1.0, 0.2, 1.0)
	anello.position = Vector3(0, 0.04, 0)
	anello.material_override = Muratura.acceso(colore, 0.8)
	anello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	radice.add_child(anello)

	var nome := Label3D.new()
	nome.text = String(dati["nome"])
	nome.font = Comandi.carattere_titolo()
	nome.font_size = 64
	nome.pixel_size = 0.0035
	nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nome.modulate = colore
	nome.outline_size = 14
	nome.outline_modulate = Color(0.02, 0.02, 0.06, 0.85)
	nome.shaded = false
	nome.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	nome.position = Vector3(0, ALTEZZA + 0.75, 0)
	radice.add_child(nome)
	return radice
