class_name Apertura
extends RefCounted

## **L'arena aperta** (tappa 11, blocco C2, 11/10/2026): la prova di Fable per scegliere
## su scatti veri (`ricerca-grezza/stato-2026-10-11/fable-c2.md`).
##
## La palestra del 1999 è chiusa: perimetro di 12 metri, più di cento metri di muro alto
## 8-9 dentro, e in 3 scatti su 10 lo schermo del telefono era un muro (`c1-diagnosi.png`).
## I giochi del riferimento hanno barriere alla vita, e sopra il campo, chi gioca e il
## cielo. Qui la pianta **si apre in memoria**, per le varianti che lo chiedono
## (`Aspetto.apre_l_arena`): il file non cambia, e le altre varianti non se ne accorgono.
##
## La regola, sulle altezze e mai sulle impronte (le quote dei pavimenti sono tarate sul
## salto e non si toccano):
## - il perimetro scende a 4 metri;
## - i muri alti (da 6 metri in su) scendono a 2,4 sopra il pavimento di fuori;
## - restano a 6 le quattro torri, cioè i fianchi diagonali attorno al catino, e i
##   piloni, che a 6 diventano colonne da guardare da lontano;
## - i muri medi (2-4,5 m, quelli sottili) scendono a 1,25;
## - restano come sono i muri che reggono un piano, i blocchi (cassoni, box, gradinate,
##   che sono già gli oggetti di misura media) e i muretti bassi.
##
## E tre conseguenze, che Fable non aveva visto e la pianta sì:
## - **i parapetti sul perimetro**: con il bordo a 4 metri, dalle terrazze (3,5) e dal
##   ballatoio (7) si cadeva fuori dall'arena. Dove un piano alto tocca il perimetro, sopra
##   il perimetro sale un parapetto fino a 1,2 metri sopra quel piano;
## - **le sponde riappoggiate**: quelle appese in alto a un muro che si è abbassato
##   restavano nel vuoto. Scendono fin sulla cima nuova del muro che le porta, come
##   cartelloni in piedi sopra una barriera;
## - **i bersagli bonus** non stanno più in alto di 6 metri, e quelli sopra la cima del
##   loro muro hanno un palo (lo disegna `veste`).

const PERIMETRO := 4.0
const TORRE := 6.0
const ALTO := 2.4
const MEDIO := 1.25
const PARAPETTO := 1.2
const BONUS_MASSIMO := 6.0

## Le quattro torri: i fianchi diagonali che chiudono i passaggi attorno al catino.
const TORRI := ["galleria nord-ovest, fianco", "scala nord-est, fianco",
		"passaggio sud-est, fianco", "finestra sud-ovest, fianco"]

## Il colore del terreno di fuori: la sabbia del canyon, un poco più chiara delle rocce.
const SABBIA := Color(0.95, 0.72, 0.50)


static func apri(pianta: Dictionary) -> Dictionary:
	var aperta: Dictionary = pianta.duplicate(true)
	for m: Dictionary in aperta["muri"]:
		m["alto"] = _altezza(m, aperta)
	_parapetti(aperta)
	_sponde(aperta)
	_bonus(aperta)
	aperta["aperta"] = true
	return aperta


## L'altezza nuova di un muro, secondo la regola qui sopra.
static func _altezza(m: Dictionary, pianta: Dictionary) -> float:
	var nome := String(m.get("nome", ""))
	var quota := float(m["quota"])
	var alto := float(m["alto"])
	var lx := float(m["misura"][0])
	var lz := float(m["misura"][1])
	if alto <= MEDIO + 0.05 or _regge_un_piano(m, pianta):
		return alto
	if nome.begins_with("perimetro"):
		return PERIMETRO - quota
	if Arena._e_tondo(nome) and absf(lx - lz) < 0.01:
		return minf(alto, TORRE - quota)
	if nome in TORRI:
		return TORRE - quota
	if minf(lx, lz) >= 1.3:
		return alto
	if alto >= 6.0:
		return ALTO - minf(quota, 0.0)
	return MEDIO - minf(quota, 0.0)


## Un muro regge un piano se la sua cima sta sotto la lastra di quel piano (fra il fondo
## e il pavimento) e la sua impronta ci passa sotto. Le colonne del portico finiscono
## dentro la lastra del ballatoio, il sostegno della passerella in pari col pavimento.
static func _regge_un_piano(m: Dictionary, pianta: Dictionary) -> bool:
	var cima := float(m["quota"]) + float(m["alto"])
	var posto := Transform2D(-deg_to_rad(float(m.get("giro", 0.0))),
			Vector2(float(m["centro"][0]), float(m["centro"][1])))
	var meta := Vector2(float(m["misura"][0]), float(m["misura"][1])) * 0.5 - Vector2(0.05, 0.05)
	for zona: Dictionary in pianta["zone"]:
		var piano := float(zona["quota"])
		if piano <= 0.5 or cima < piano - Arena.SPESSORE_PIANO - 0.05 or cima > piano + 0.01:
			continue
		var contorno := _contorno(zona["poligono"])
		for fx in [-1.0, 0.0, 1.0]:
			for fz in [-1.0, 0.0, 1.0]:
				if Geometry2D.is_point_in_polygon(posto * Vector2(meta.x * fx, meta.y * fz), contorno):
					return true
	return false


## Dove un piano alto tocca il perimetro, un parapetto sul perimetro: parte un dito sotto
## la cima del perimetro e arriva a 1,2 metri sopra il piano. È più sottile del perimetro
## (70 cm contro 80) e ci sta dentro, così nessuna sua faccia sta in pari con le sue; e
## quello che corre da nord a sud è due centimetri più basso, perché agli angoli i due
## parapetti si incrociano.
static func _parapetti(pianta: Dictionary) -> void:
	var nuovi: Array = []
	var bordo := float(pianta["misura"]["larghezza"]) * 0.5
	for zona: Dictionary in pianta["zone"]:
		var piano := float(zona["quota"])
		if piano <= 0.5:
			continue
		var contorno := _contorno(zona["poligono"])
		for i in contorno.size():
			var da := contorno[i]
			var a := contorno[(i + 1) % contorno.size()]
			for asse in 2:
				var altro := 1 - asse
				if absf(da[asse]) < bordo - 0.5 or absf(da[asse] - a[asse]) > 0.01 \
						or absf(da[altro] - a[altro]) < 0.5:
					continue
				var segno := signf(da[asse])
				var centro := Vector2.ZERO
				centro[asse] = segno * (bordo + 0.4)
				centro[altro] = (da[altro] + a[altro]) * 0.5
				var misura := Vector2.ZERO
				misura[asse] = 0.7
				misura[altro] = absf(da[altro] - a[altro])
				var piede := PERIMETRO - 0.1
				nuovi.append({
					"nome": "parapetto sul perimetro, %s" % String(zona["nome"]),
					"centro": [centro.x, centro.y], "misura": [misura.x, misura.y],
					"quota": piede, "alto": piano + PARAPETTO - piede - (0.02 if asse == 0 else 0.0),
					"tinta": _tinta_del_perimetro(pianta, asse, segno),
				})
	(pianta["muri"] as Array).append_array(nuovi)


static func _tinta_del_perimetro(pianta: Dictionary, asse: int, segno: float) -> String:
	for m: Dictionary in pianta["muri"]:
		if String(m.get("nome", "")).begins_with("perimetro") \
				and signf(float(m["centro"][asse])) == segno and absf(float(m["centro"][asse])) > 1.0:
			return String(m["tinta"])
	return "ocra"


## Le sponde in piedi che stavano più in alto della cima nuova del loro muro scendono e ci
## si appoggiano sopra, quindici centimetri dentro (in pari, il fondo della sponda e la
## cima del muro lampeggerebbero). Il muro che le porta è quello, fra quelli che le
## stanno sotto e le toccano, con la cima più alta: sul perimetro, il parapetto.
static func _sponde(pianta: Dictionary) -> void:
	for s: Dictionary in pianta["sponde"]:
		if s.has("sdraiata"):
			continue
		var cima := _cima_sotto(pianta, Vector2(float(s["centro"][0]), float(s["centro"][1])),
				float(s["quota"]))
		if is_nan(cima):
			continue
		if float(s["quota"]) > cima - 0.2:
			s["quota"] = cima - 0.15


## I bonus non più in alto di 6 metri; sopra la cima del muro che li porta, un palo.
static func _bonus(pianta: Dictionary) -> void:
	for b: Dictionary in pianta.get("bonus", []):
		b["quota"] = minf(float(b["quota"]), BONUS_MASSIMO)
		var cima := _cima_sotto(pianta, Vector2(float(b["dove"][0]), float(b["dove"][1])),
				float(b["quota"]))
		if not is_nan(cima) and float(b["quota"]) - BersaglioBonus.RAGGIO > cima:
			b["palo_da"] = cima


## La cima più alta fra i muri che stanno sotto `quota` e arrivano a meno di 75 cm da
## `dove`; NAN se non ce n'è.
static func _cima_sotto(pianta: Dictionary, dove: Vector2, quota: float) -> float:
	var migliore := NAN
	for m: Dictionary in pianta["muri"]:
		if float(m["quota"]) > quota + 0.1:
			continue
		var locale := (dove - Vector2(float(m["centro"][0]), float(m["centro"][1]))) \
				.rotated(deg_to_rad(float(m.get("giro", 0.0))))
		var meta := Vector2(float(m["misura"][0]), float(m["misura"][1])) * 0.5
		if (locale.abs() - meta).max(Vector2.ZERO).length() > 0.75:
			continue
		var cima := float(m["quota"]) + float(m["alto"])
		if is_nan(migliore) or cima > migliore:
			migliore = cima
	return migliore


static func _contorno(punti: Array) -> PackedVector2Array:
	var fuori := PackedVector2Array()
	for p in punti:
		fuori.append(Vector2(float(p[0]), float(p[1])))
	return fuori


# ------------------------------------------------------------------ quello che si vede

## Quello che serve a tutte e due le prove: il terreno di fuori (a 12 metri il perimetro
## nascondeva che fuori non c'era niente) e i pali dei bonus.
static func veste(arena: Arena, materiale: Material) -> void:
	var getto := Giocattolo.Getto.new()
	var dentro := float(arena.pianta()["misura"]["larghezza"]) * 0.5 + 0.8
	var lontano := 320.0
	for k in 4:
		var giro := Transform2D(PI * 0.5 * float(k), Vector2.ZERO)
		getto.piatto(PackedVector2Array([giro * Vector2(-lontano, -lontano), giro * Vector2(lontano, -lontano),
				giro * Vector2(dentro, -dentro), giro * Vector2(-dentro, -dentro)]),
				-0.02, Vector3.UP, SABBIA)
	for b: Dictionary in arena.pianta().get("bonus", []):
		if not b.has("palo_da"):
			continue
		var piede := float(b["palo_da"]) - 0.1
		var cima := float(b["quota"])
		# Il palo sta dietro il disco, dalla parte del muro: il disco guarda verso `giro`.
		var dietro := Vector3(0, 0, -0.25).rotated(Vector3.UP, deg_to_rad(float(b["giro"])))
		getto.tondo(0.12, cima - piede, 0.03, Giocattolo.BLU, Transform3D(Basis(),
				Vector3(float(b["dove"][0]), piede, float(b["dove"][1])) + dietro), 10)
	Giocattolo._posa(arena, getto.mesh(), materiale, "terreno e pali")


# ------------------------------------------------------------------ gli oggetti in campo

## I posti per gli oggetti di misura media, sui pavimenti alla quota zero: a caso ma
## sempre uguali (`seme`), a `distanza` l'uno dall'altro, e lontani da quello che un
## oggetto non deve toccare o coprire — muri (con un passaggio largo `passaggio` più il
## mezzo oggetto), rampe e orli dei pavimenti, partenze e rinascite, sfere, sponde. Il
## catino resta libero: è della vasca o della pista, e della palla quando verrà.
static func posti_liberi(arena: Arena, quanti: int, distanza: float, mezzo: float,
		passaggio: float, seme: int) -> Array[Vector2]:
	var pianta := arena.pianta()
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var evitare: Array[Vector3] = []   # x, z, raggio
	for p: Dictionary in pianta["partenze"]:
		evitare.append(Vector3(float(p["dove"][0]), float(p["dove"][1]), 5.0))
	for r: Dictionary in arena.get("_rinascite"):
		evitare.append(Vector3((r["dove"] as Vector3).x, (r["dove"] as Vector3).z, 2.0))
	for s: Dictionary in arena.sfere_della_pianta():
		evitare.append(Vector3((s["dove"] as Vector3).x, (s["dove"] as Vector3).z, 3.5))
	var zone: Array = pianta["zone"]
	var fuori: Array[Vector2] = []
	for tentativo in quanti * 60:
		if fuori.size() >= quanti:
			break
		var p := Vector2(rng.randf_range(-39.0, 39.0), rng.randf_range(-39.0, 39.0))
		var ok := false
		for z in zone.size():
			if absf(float(zone[z]["quota"])) > 0.01:
				continue
			for pezzo: PackedVector2Array in arena.pezzi_della_zona(z):
				if Geometry2D.is_point_in_polygon(p, pezzo) and _lontano_dagli_orli(p, pezzo, mezzo + 0.5):
					ok = true
		if not ok or Giocattolo._dentro_un_muro(p, pianta, passaggio + mezzo) \
				or Giocattolo._sopra_una_rampa(p, pianta) or _sotto_un_piano_alto(p, pianta):
			continue
		if evitare.any(func(e: Vector3) -> bool: return p.distance_to(Vector2(e.x, e.y)) < e.z + mezzo):
			continue
		if _davanti_a_una_sponda(p, pianta, mezzo + 1.0):
			continue
		if fuori.any(func(q: Vector2) -> bool: return p.distance_to(q) < distanza):
			continue
		fuori.append(p)
	return fuori


## Un oggetto non sta a meno di `quanto` dalla faccia di una sponda: le sponde si misurano
## per quello che sono, un segmento lungo la loro larghezza (in piedi) o un quadrato (a
## terra), non un cerchio largo quanto loro.
static func _davanti_a_una_sponda(p: Vector2, pianta: Dictionary, quanto: float) -> bool:
	for s: Dictionary in pianta["sponde"]:
		var centro := Vector2(float(s["centro"][0]), float(s["centro"][1]))
		var meta := float(s["faccia"][0]) * 0.5
		if s.has("sdraiata"):
			var lato := Vector2(float(s["faccia"][0]), float(s["faccia"][1])) * 0.5
			if ((p - centro).abs() - lato).max(Vector2.ZERO).length() < quanto:
				return true
			continue
		var lungo := Vector2.RIGHT.rotated(-deg_to_rad(float(s.get("giro", 0.0))))
		var vicino := Geometry2D.get_closest_point_to_segment(p, centro - lungo * meta, centro + lungo * meta)
		if p.distance_to(vicino) < quanto:
			return true
	return false


static func _lontano_dagli_orli(p: Vector2, pezzo: PackedVector2Array, quanto: float) -> bool:
	for i in pezzo.size():
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pezzo[i],
				pezzo[(i + 1) % pezzo.size()])) < quanto:
			return false
	return true


## Sotto una terrazza o il ballatoio c'è poco spazio per la camera: niente oggetti.
static func _sotto_un_piano_alto(p: Vector2, pianta: Dictionary) -> bool:
	for zona: Dictionary in pianta["zone"]:
		if float(zona["quota"]) > 0.5 and Geometry2D.is_point_in_polygon(p, _contorno(zona["poligono"])):
			return true
	return false


## Un oggetto che ferma i corpi e i dardi come un muro (e che la rete di cammino conosce,
## perché si cuoce con lui). `forme`: `[[forma, posto]]` nello spazio dell'oggetto.
static func solido(arena: Node3D, posto: Transform3D, forme: Array, nome: String) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = nome
	corpo.collision_layer = Strati.OSTACOLO
	corpo.collision_mask = 0
	corpo.transform = posto
	for f: Array in forme:
		var forma := CollisionShape3D.new()
		forma.shape = f[0]
		forma.transform = f[1]
		corpo.add_child(forma)
	corpo.add_to_group(GRUPPO_OGGETTI)
	arena.add_child(corpo)
	return corpo


## Gli oggetti messi in campo dalle prove: il collaudo li conta.
const GRUPPO_OGGETTI := &"oggetti in campo"


static func scatola(misura: Vector3) -> BoxShape3D:
	var forma := BoxShape3D.new()
	forma.size = misura
	return forma


static func cilindro(raggio: float, alto: float) -> CylinderShape3D:
	var forma := CylinderShape3D.new()
	forma.radius = raggio
	forma.height = alto
	return forma
