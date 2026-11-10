extends SceneTree

## Collaudo del **giocatore pilotato** (tappa 11, blocco G; `LEARNED.md` § 72).
##
## Dal telefono, il 24/10/2026: *«Quando testi, non muovi mai il personaggio perché?»*.
## Fino a qui i collaudi spostavano il personaggio a mano o lo parcheggiavano sotto
## l'arena, e le partite intere le giocavano solo gli avversari. Qui il personaggio si
## muove **solo con i tocchi del telefono**: la leva sulla metà sinistra, il pollice
## destro che trascina per girare e mirare, i tocchi su FUOCO, SALTA e LANCIA. Si entra
## dalla Home toccando la modalità e GIOCA.
##
## Il pilota sa dove andare (la meta la legge dal gioco, come chi gioca legge la freccia)
## e si fa la strada sulla rete degli avversari; poi ci va come un giocatore: gira la
## visuale verso il prossimo punto della strada e spinge la leva in avanti. Salta solo se
## resta fermo spingendo, e ogni salto si conta: gli avversari non saltano mai, quindi la
## strada non lo chiede.
##
## I finti eventi del mouse sono spenti: sul telefono il personaggio li scarta, sul PC
## sparerebbero e girerebbero la visuale. I pulsanti prendono il tocco anche col secondo
## dito (provato il 24/10/2026).
##
## Uso (vuole la finestra):
##   godot --path . --resolution 1280x585 --fixed-fps 30
##       -s tools/prova_pilotato.gd -- <gara|palla|scontro> [variante] [senza_leva] [video] [avversari]
## Esce con 0 se verde, con 1 se rosso. `senza_leva` è la controprova: deve dare rosso.
## `avversari` vale per la GARA: senza, gli avversari si tolgono al VIA e la prova dice solo
## se la strada si corre col pollice; con, restano in pista ed è la gara com'è nel gioco
## (il pilota non spara e non schiva: conta i colpi che prende e le bandiere di tutti).
##
## Le misure della tappa 12 (blocco 0), stampate nel diario e in fondo:
## - **ogni colpo preso**: chi ha tirato e da quanti metri; in GARA anche le bandiere dei
##   due. In fondo, in GARA: quando si tocca la prima bandiera, quanti colpi si sono presi
##   prima, e la serie più fitta dallo stesso avversario in sei secondi;
## - **ogni bersaglio bonus preso**: chi, quanto, a che secondo; in fondo i punti dai dischi;
## - **ogni cartello al centro** (l'annuncio grande), e in fondo quanti «COLPITO DA …» sono
##   stati coperti da un altro prima dei loro 1,6 s e quanti «TI HANNO SUPERATO» sono
##   usciti nel primo mezzo minuto: i due numeri del blocco F;
## - nello SCONTRO, **i secondi con almeno un avversario sullo schermo** (dentro
##   l'inquadratura e senza muri in mezzo) entro 15 m — dove si spegne il contorno — ed
##   entro 40 m, dove si spegne il nome nell'arena aperta. La distanza è quella della
##   camera dal mezzo del corpo, la stessa con cui l'avversario spegne contorno e nome.
## Con `video` salva un fotogramma per giro in `scatti/pilotato-<modo>-<variante>/`, da
## montare con ffmpeg a 30 al secondo. Il registratore di Godot (`--write-movie`) non va:
## scrive alla misura base del progetto, 1280 × 720, e taglia i lati dello schermo del
## telefono (provato il 24/10/2026). Con `--fixed-fps` il salvataggio non tocca il tempo
## del gioco.

const DITO_LEVA := 0
const DITO_MIRA := 1
const DITO_TASTO := 2

## Dove si appoggiano i pollici, in frazioni dello schermo. Il destro scivola dentro il
## suo riquadro; quando ne esce si alza e si riappoggia, come fa un pollice vero.
const LEVA := Vector2(0.15, 0.74)
const MIRA := Vector2(0.66, 0.42)
const RIQUADRO_MIRA := Rect2(0.54, 0.24, 0.26, 0.40)
## Quanto trascina al massimo un pollice in un fotogramma, in punti della tela: a 30
## fotogrammi al secondo sono circa tre radianti al secondo di giro.
const PASSO_MASSIMO := 28.0

const VICINO := 0.9           ## metri: un punto della strada è raggiunto
const RICALCOLO := 0.5        ## secondi fra due strade
const FERMO_SALTA := 0.6      ## secondi fermo spingendo, poi salta
const FERMO_ROSSO := 2.0      ## secondi fermo spingendo: rosso
const PENDENZA_IN_CORSA := -6.0
const SOTTO_L_ARENA := -8.0   ## il pavimento più basso è il catino, a −2

const TEMPI := {"gara": 120.0, "palla": 90.0, "scontro": 60.0}

## La PALLA: da quanto lontano dalla bocca si tira, e quanto si prova a mirare prima di
## avvicinarsi.
const DISTANZE_DI_TIRO := [10.0, 7.0, 5.0]
const PAZIENZA_DI_MIRA := 5.0
## Lo SCONTRO: da quanto si spara, e quanto deve stare vicino al mirino il petto.
const PORTATA := 16.0
const CENTRATO := 14.0

var _modo := "gara"
var _senza_leva := false
var _arena: Arena
var _tu: Giocatore
var _comandi: Comandi
var _vista := Vector2.ZERO
var _fattore := Vector2.ONE

var _leva_giu := false
var _mira_giu := false
var _mira_punto := Vector2.ZERO
var _mira_percorso := 0.0
var _tasto_su_fra := 0
var _tasto_punto := Vector2.ZERO

var _strada := PackedVector3Array()
var _passo := 0
var _ricalcolo := 0.0
var _meta := Vector3.INF

var _tempo := 0.0
var _fermo := 0.0
var _prossimo_salto := 0.0
var _salti: Array[String] = []
var _rosso := ""
var _verde := false
var _video := ""
var _finito := false

# La PALLA.
var _distanza_di_tiro := 0
var _mirando := 0.0
var _lanci := 0
## Dopo un LANCIA si guarda la palla partire: il pulsante scatta al rilascio, e senza
## questa pausa la prima prova lo toccava due volte di fila.
var _dopo_il_lancio := 0.0
var _gol := 0
# Lo SCONTRO.
var _ricarica := 0.0
var _colpi := 0
var _a_segno := 0
var _marcatore_prima := 0.0
# La GARA con gli avversari in pista.
var _con_avversari := false
var _colpito := 0
# Le misure della tappa 12: i colpi presi (`{"t", "chi"}`), la prima bandiera, i punti dai
# dischi per nome, i secondi con un avversario in vista entro 15 e 40 m.
var _presi: Array[Dictionary] = []
var _prima_bandiera := -1.0
var _dai_dischi := {}
var _in_vista_15 := 0.0
var _in_vista_40 := 0.0
# I cartelli al centro: `{"t", "testo"}`. Uno nuovo si riconosce dal suo tempo che risale.
var _annunci: Array[Dictionary] = []
var _resta_annuncio := 0.0


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	_modo = argomenti[0] if argomenti.size() > 0 else "gara"
	_senza_leva = argomenti.has("senza_leva")
	_con_avversari = _modo == "gara" and argomenti.has("avversari")
	var aspetto_di_prima := Aspetto.scelta()
	var modalita_di_prima := Modalita.scelta()
	if argomenti.size() > 1 and argomenti[1].is_valid_int():
		Aspetto.scegli(int(argomenti[1]))
	var quale: int = {"gara": Modalita.GARA, "palla": Modalita.PALLA, "scontro": Modalita.SCONTRO}[_modo]
	Input.emulate_mouse_from_touch = false
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.75
	print("pilotato: %s in %s%s" % [_modo, Aspetto.nome(), " (senza leva)" if _senza_leva else ""])
	if argomenti.has("video"):
		_video = "res://scatti/pilotato-%s-%d" % [_modo, Aspetto.scelta()]
		_registra()

	# La Home: si tocca la modalità, poi GIOCA quando l'arena è pronta.
	Modalita.scegli(Modalita.SCONTRO)
	var ingresso: Node = load("res://scenes/ingresso.tscn").instantiate()
	root.add_child(ingresso)
	current_scene = ingresso
	await _riposa(8)
	_vista = root.get_visible_rect().size
	_fattore = Vector2(DisplayServer.window_get_size()) / _vista
	await _tocca((ingresso.get("_modalita") as Array)[quale])
	var scadenza := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < scadenza and ingresso.get("_arena_pronta") == null:
		await process_frame
	await _riposa(4)
	await _tocca(ingresso.get("_gioca"))
	scadenza = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < scadenza and not (current_scene is Arena):
		await process_frame
	if not (current_scene is Arena):
		_fine("GIOCA non ha aperto l'arena", aspetto_di_prima, modalita_di_prima)
		return
	_arena = current_scene as Arena
	_tu = _arena.giocatore()
	_comandi = _arena.get("_comandi")
	_tu.preso_da.connect(_su_colpo_preso)
	for bonus in _arena.bersagli_bonus():
		bonus.preso.connect(_su_disco.bind(bonus))
	if _modo == "palla":
		_arena.palle().in_porta.connect(_su_gol)
		_arena.palle().presa.connect(_su_presa)
	scadenza = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < scadenza and _arena.conto_alla_rovescia() > 0.0:
		await process_frame
	if _modo == "gara" and not _con_avversari:
		# Gli avversari fuori: la GARA dice se la strada si corre col pollice. Dopo il
		# VIA, perché il VIA li accende (la prima prova li aveva fermati prima, e uno ha
		# vinto la gara).
		for chi: Avversario in _arena.avversari():
			chi.process_mode = Node.PROCESS_MODE_DISABLED
			chi.global_position = Vector3(0, -80, 0)
	_diario("VIA")

	# I due pollici giù, come chi comincia a giocare.
	_appoggia_la_mira()
	if not _senza_leva:
		_tocco(DITO_LEVA, _punto(LEVA), true)
		_leva_giu = true

	var limite: float = TEMPI[_modo]
	while _rosso == "" and not _verde and _tempo < limite:
		var passo := root.get_process_delta_time()
		_tempo += passo
		_un_fotogramma(passo)
		await process_frame
		if bool(_arena.get("_finita")) and not _verde and _rosso == "":
			break
	# La settima bandiera chiude la partita nello stesso fotogramma in cui si tocca.
	if _modo == "gara" and _arena.bandiere_di(_tu) >= _arena.bandiere().quante() and _rosso == "":
		_verde = true
		_diario("settima bandiera: %.1f s, %d salti" % [_tempo, _salti.size()])
	# PALLA e SCONTRO si giocano per tutto il loro tempo: il verde si decide alla fine.
	if _rosso == "" and _modo == "palla":
		_verde = _gol > 0
		if not _verde:
			_rosso = "nessun gol in %.0f s (%d lanci)" % [_tempo, _lanci]
	if _rosso == "" and _modo == "scontro":
		_verde = _a_segno > 0
		if not _verde:
			_rosso = "nessun colpo a segno in %.0f s (%d colpi)" % [_tempo, _colpi]
	if _rosso == "" and not _verde and bool(_arena.get("_finita")):
		var righe: Array = _arena.get("_concorrenti")
		var bandiere := []
		for riga: Dictionary in righe:
			bandiere.append("%s %d" % [riga["nome"], int(riga.get("bandiere", 0))])
		_rosso = "la partita l'ha chiusa l'arena (tempo dell'arena %.1f; bandiere: %s)" % [
				float(_arena.get("_tempo")), ", ".join(PackedStringArray(bandiere))]
	if _rosso == "" and not _verde:
		_rosso = "non finita in %d secondi" % int(limite)
	_alza_tutto()
	await _riposa(20)
	_fine("", aspetto_di_prima, modalita_di_prima)


func _un_fotogramma(passo: float) -> void:
	_lascia_il_tasto()
	if _tu.global_position.y < SOTTO_L_ARENA:
		_rosso = "caduto sotto l'arena in %s" % _dove(_tu.global_position)
		return
	_guarda_il_cartello()
	# Ogni cinque secondi, dove sta e dove va: il diario dice cosa faceva fra un fatto e
	# l'altro.
	if int(_tempo / 5.0) != int((_tempo - passo) / 5.0):
		_diario("in %s, verso %s, a %.1f m/s" % [_dove(_tu.global_position),
				_dove(_meta) if _meta != Vector3.INF else "niente",
				Vector2(_tu.velocity.x, _tu.velocity.z).length()])
	match _modo:
		"gara":
			_gara()
		"palla":
			_palla(passo)
		"scontro":
			_scontro(passo)


# ------------------------------------------------------------------ le tre partite

func _gara() -> void:
	var b := _arena.bandiere()
	var toccate := _arena.bandiere_di(_tu)
	# Un colpo preso riporta all'ultima bandiera: il conto è quello dell'arena.
	if _arena.colpi_incassati(_tu) > _colpito:
		_colpito = _arena.colpi_incassati(_tu)
		_diario("riparte da %s (colpo %d)" % [_dove(_tu.global_position), _colpito])
	if toccate >= 1 and _prima_bandiera < 0.0:
		_prima_bandiera = _tempo
	if toccate >= b.quante():
		_verde = true
		_diario("settima bandiera: %.1f s, %d salti" % [_tempo, _salti.size()])
		return
	var meta := b.dove(toccate)
	if not meta.is_equal_approx(_meta):
		if _meta != Vector3.INF:
			_diario("bandiera %d" % toccate)
		_meta = meta
		_ricalcolo = 0.0
	_cammina()


func _palla(passo: float) -> void:
	var palle := _arena.palle()
	var portate := palle.portate_da(_tu)
	if portate.is_empty():
		_mirando = 0.0
		_distanza_di_tiro = 0
		var segnate := _arena.segnate_da(_tu)
		var vicina: Palla = null
		for palla in palle.palle():
			# Una palla caduta sotto l'arena non la vede nessuno: la riporta il cannone.
			if not palla.libera() or segnate.has(palla.indice) or palla.global_position.y < -4.0:
				continue
			if vicina == null or palla.global_position.distance_to(_tu.global_position) \
					< vicina.global_position.distance_to(_tu.global_position):
				vicina = palla
		if vicina == null:
			_leva(0.0)
			return
		_vai_a(vicina.global_position)
		return
	# Con la palla: la porta più vicina, e davanti a lei a qualche metro.
	var porta := 0
	if palle.centro_della_porta(1).distance_to(_tu.global_position) \
			< palle.centro_della_porta(0).distance_to(_tu.global_position):
		porta = 1
	var quanto: float = DISTANZE_DI_TIRO[mini(_distanza_di_tiro, DISTANZE_DI_TIRO.size() - 1)]
	var davanti := palle.davanti_alla_porta(porta, quanto)
	var piano := Vector2(davanti.x - _tu.global_position.x, davanti.z - _tu.global_position.z)
	if piano.length() > 1.5 and _mirando <= 0.0:
		_vai_a(davanti)
		return
	# Fermo davanti alla porta: si gira verso la bocca e si alza o abbassa la mira
	# finché l'anello dell'arco cade dentro. È l'arco che vede chi gioca.
	_leva(0.0)
	_mirando += passo
	var bocca := palle.centro_della_porta(porta)
	_metti_nel_mirino(bocca, false)
	var velocita := Palle.velocita_del_lancio(-_tu.camera().global_transform.basis.z)
	var strada := palle.traiettoria(palle.da_dove_si_lancia(_tu, velocita), velocita)
	var batte := strada[strada.size() - 1]
	var lancia: Button = _comandi.get("_lancia")
	_dopo_il_lancio = maxf(_dopo_il_lancio - passo, 0.0)
	if palle.porta_di(batte) == porta and lancia != null and lancia.visible and _tasto_su_fra == 0 \
			and _dopo_il_lancio <= 0.0:
		_dopo_il_lancio = 0.8
		_lanci += 1
		_diario("LANCIA da %.1f m" % Vector2(bocca.x - _tu.global_position.x,
				bocca.z - _tu.global_position.z).length())
		_premi(lancia)
		_mirando = 0.0
		return
	# Corto: si alza la mira; lungo, o sopra la porta: si abbassa. Di poco quando si è vicini:
	# a scatti fissi di un grado la mira scavalcava la bocca avanti e indietro, e nella prova
	# registrata del 24/10 non ha mai lanciato.
	var scarto := Vector2(batte.x - _tu.global_position.x, batte.z - _tu.global_position.z).length() \
			- Vector2(bocca.x - _tu.global_position.x, bocca.z - _tu.global_position.z).length()
	if batte.y > bocca.y + 1.2:
		scarto = maxf(scarto, 1.0)
	var dy := clampf(scarto * 1.2, -6.0, 6.0)
	if absf(dy) < 0.6:
		dy = signf(scarto) * 0.6
	_trascina_la_mira(Vector2(0, dy))
	if _mirando > PAZIENZA_DI_MIRA:
		_distanza_di_tiro += 1
		_mirando = 0.0
		_diario("nessun arco dentro la porta: ci si avvicina")


func _su_presa(chi: Node3D, palla: Palla) -> void:
	if chi == _tu:
		_diario("presa la palla %d" % palla.indice)


func _su_gol(_palla: Palla, autore: Node3D) -> void:
	if autore != _tu:
		return
	_gol += 1
	_diario("GOL (%d su %d lanci)" % [_gol, _lanci])


func _scontro(passo: float) -> void:
	_conta_chi_si_vede(passo)
	_ricarica = maxf(_ricarica - passo, 0.0)
	var marcatore := float(_comandi.get("_marcatore"))
	if marcatore > _marcatore_prima + 0.05:
		_a_segno += 1
		_diario("a segno (%d su %d colpi)" % [_a_segno, _colpi])
	_marcatore_prima = marcatore
	var bersaglio: Avversario = null
	for chi in _arena.avversari():
		if chi.global_position.y < SOTTO_L_ARENA:
			continue
		if bersaglio == null or chi.global_position.distance_to(_tu.global_position) \
				< bersaglio.global_position.distance_to(_tu.global_position):
			bersaglio = chi
	if bersaglio == null:
		_leva(0.0)
		return
	var petto := bersaglio.global_position + Vector3(0, 1.1, 0)
	var lontano := petto.distance_to(_tu.global_position)
	if lontano > PORTATA or not _si_vede(petto, bersaglio):
		_vai_a(bersaglio.global_position)
		return
	_leva(0.3)
	var scarto := _metti_nel_mirino(petto, true)
	if scarto.length() < CENTRATO and _ricarica <= 0.0 and _tasto_su_fra == 0:
		_colpi += 1
		_ricarica = 0.45
		_premi(_pulsante("FUOCO"))


# ------------------------------------------------------------------ le misure della tappa 12

## Un colpo preso, nell'istante in cui arriva: chi ha sparato è ancora dove stava, e chi è
## stato preso non è ancora ricomparso (la ricomparsa è differita). Conta quando conta per
## l'arena: dopo il VIA e prima della fine.
func _su_colpo_preso(chi: Object, _punti: int, _muri: int) -> void:
	if not _arena.in_sfida() or bool(_arena.get("_finita")) or _arena.conto_alla_rovescia() > 0.0:
		return
	var nome := _nome_di(chi)
	var metri := (chi as Node3D).global_position.distance_to(_tu.global_position) \
			if chi is Node3D else -1.0
	_presi.append({"t": _tempo, "chi": nome, "prima": _arena.bandiere_di(_tu) == 0})
	var bandiere := ""
	if _modo == "gara":
		bandiere = ", bandiere: TU %d, %s %d" % [_arena.bandiere_di(_tu), nome, _arena.bandiere_di(chi)]
	_diario("COLPITO DA %s a %.1f m%s" % [nome, metri, bandiere])


## Un bersaglio bonus preso da chiunque. Prima del VIA un disco non si lascia prendere
## (`BersaglioBonus.conta`), quindi qui arriva solo quello che vale. Doppio con i PUNTI
## DOPPI, come lo conta l'arena.
func _su_disco(chi: Object, punti: int, bonus: BersaglioBonus) -> void:
	var potenziamenti: Potenziamenti = _arena.get("_potenziamenti")
	if potenziamenti != null and potenziamenti.ha(chi, "doppio"):
		punti *= 2
	var nome := _nome_di(chi)
	_dai_dischi[nome] = int(_dai_dischi.get(nome, 0)) + punti
	_diario("disco da %d preso da %s (+%d)" % [bonus.valore, nome, punti])


## Un avversario è sullo schermo se il mezzo del corpo sta nell'inquadratura e fra la camera
## e lui non c'è un muro. Si conta il più vicino.
func _conta_chi_si_vede(passo: float) -> void:
	var camera := _tu.camera()
	var vicino := INF
	for chi in _arena.avversari():
		var mezzo := chi.global_position + Vector3(0, Avversario.ALTEZZA_CORPO * 0.5, 0)
		if not camera.is_position_in_frustum(mezzo) or not _si_vede(mezzo, chi):
			continue
		vicino = minf(vicino, camera.global_position.distance_to(mezzo))
	if vicino <= Avversario.PORTATA_ALONE:
		_in_vista_15 += passo
	if vicino <= Avversario.PORTATA_NOMI_APERTA:
		_in_vista_40 += passo


## Un cartello nuovo al centro: `Comandi.annuncia` rimette il suo tempo a 1,6 s, quindi
## basta vederlo risalire (anche quando il testo è lo stesso di prima).
func _guarda_il_cartello() -> void:
	var resta := float(_comandi.get("_tempo_avviso"))
	if resta > _resta_annuncio + 0.01 and _comandi.testo_annunciato() != "":
		_annunci.append({"t": _tempo, "testo": _comandi.testo_annunciato()})
		_diario("cartello: %s" % _comandi.testo_annunciato())
	_resta_annuncio = resta


## I due numeri del blocco F: i «COLPITO DA …» coperti da un altro cartello prima della
## loro fine, e i «TI HANNO SUPERATO» del primo mezzo minuto.
func _conto_dei_cartelli() -> String:
	var colpito := 0
	var coperti := 0
	var superato := 0
	for i in _annunci.size():
		var testo := String(_annunci[i]["testo"])
		if testo.begins_with("TI HANNO SUPERATO") and float(_annunci[i]["t"]) <= 30.0:
			superato += 1
		if testo.begins_with("COLPITO"):
			colpito += 1
			if i + 1 < _annunci.size() and float(_annunci[i + 1]["t"]) - float(_annunci[i]["t"]) < 1.6:
				coperti += 1
	return "cartelli %d · «COLPITO…» coperti prima della fine: %d su %d · «TI HANNO SUPERATO» nei primi 30 s: %d" \
			% [_annunci.size(), coperti, colpito, superato]


## Il numero più alto di colpi dallo stesso avversario dentro sei secondi.
func _serie_piu_fitta() -> String:
	var meglio := 0
	var chi_meglio := ""
	for i in _presi.size():
		var quanti := 0
		for j in range(i, _presi.size()):
			if _presi[j]["chi"] == _presi[i]["chi"] \
					and float(_presi[j]["t"]) - float(_presi[i]["t"]) < 6.0:
				quanti += 1
		if quanti > meglio:
			meglio = quanti
			chi_meglio = _presi[i]["chi"]
	return "%d di %s" % [meglio, chi_meglio] if meglio > 0 else "nessun colpo"


func _nome_di(chi: Object) -> String:
	if chi is Avversario:
		return (chi as Avversario).personaggio
	return "TU" if chi == _tu else "?"


# ------------------------------------------------------------------ camminare

## Verso un punto che si muove (una palla, un avversario): la strada si rifà spesso.
func _vai_a(dove: Vector3) -> void:
	if _meta == Vector3.INF or dove.distance_to(_meta) > 1.5:
		_meta = dove
		_ricalcolo = 0.0
	_cammina()


## Un passo sulla strada verso `_meta`: si gira la visuale verso il prossimo punto col
## pollice destro, e si spinge la leva tanto più quanto più si è girati giusti.
func _cammina() -> void:
	_ricalcolo -= root.get_process_delta_time()
	if _ricalcolo <= 0.0 or _strada.is_empty():
		_ricalcolo = RICALCOLO
		var mappa := _arena.get_world_3d().navigation_map
		_strada = NavigationServer3D.map_get_path(mappa, _tu.global_position, _meta, true)
		_passo = 0
	var qui := _tu.global_position
	while _passo < _strada.size() - 1 and Vector2(_strada[_passo].x - qui.x,
			_strada[_passo].z - qui.z).length() < VICINO:
		_passo += 1
	var prossimo := _meta if _strada.is_empty() else _strada[_passo]
	var verso := Vector2(prossimo.x - qui.x, prossimo.z - qui.z)
	if verso.length() < 0.05:
		_leva(0.0)
		return
	var sbaglio := _gira_verso(verso)
	var spinta := 1.0 if absf(sbaglio) < 0.6 else (0.4 if absf(sbaglio) < 1.2 else 0.0)
	_leva(spinta)
	_controlla_se_fermo(spinta)


## Gira la visuale verso `verso` (in pianta) e tiene la testa in corsa. Rende di quanto
## si è ancora storti, in radianti.
func _gira_verso(verso: Vector2) -> float:
	var voluto := atan2(-verso.x, -verso.y)
	var sbaglio := wrapf(voluto - _tu.global_rotation.y, -PI, PI)
	var scala := _scala()
	var dx := -sbaglio / (Comandi.SENSIBILITA * scala)
	var pendenza := rad_to_deg(float(_tu.get("_pendenza")))
	var dy := 0.0
	if absf(pendenza - PENDENZA_IN_CORSA) > 2.0:
		dy = -deg_to_rad(PENDENZA_IN_CORSA - pendenza) / (Comandi.SENSIBILITA * scala)
	_trascina_la_mira(Vector2(dx, dy))
	return sbaglio


## Porta `punto` sotto il mirino trascinando, guardando dove cade sullo schermo. Rende lo
## scarto rimasto, in punti della tela.
func _metti_nel_mirino(punto: Vector3, anche_in_alto: bool) -> Vector2:
	var camera := _tu.camera()
	if camera.is_position_behind(punto):
		var verso := Vector2(punto.x - _tu.global_position.x, punto.z - _tu.global_position.z)
		_gira_verso(verso)
		return Vector2.INF
	var scarto := camera.unproject_position(punto) - _vista * 0.5
	var focale := _vista.y * 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
	var guadagno := 0.8 / (focale * Comandi.SENSIBILITA * _scala())
	_trascina_la_mira(Vector2(scarto.x * guadagno, scarto.y * guadagno if anche_in_alto else 0.0))
	return scarto


func _si_vede(punto: Vector3, chi: Node3D) -> bool:
	var occhio := _tu.camera().global_position
	var domanda := PhysicsRayQueryParameters3D.create(occhio, punto, Strati.SOLIDO)
	var urto := _arena.get_world_3d().direct_space_state.intersect_ray(domanda)
	return urto.is_empty() or urto.get("collider") == chi


func _controlla_se_fermo(spinta: float) -> void:
	var corsa := Vector2(_tu.velocity.x, _tu.velocity.z).length()
	if spinta < 0.5 or corsa > 0.6:
		_fermo = 0.0
		_prossimo_salto = FERMO_SALTA
		return
	_fermo += root.get_process_delta_time()
	if _fermo >= FERMO_ROSSO:
		_rosso = "fermo %.1f s spingendo, in %s" % [_fermo, _dove(_tu.global_position)]
	elif _fermo >= _prossimo_salto and _tasto_su_fra == 0:
		_prossimo_salto += FERMO_SALTA
		_salti.append("%.1f s in %s" % [_tempo, _dove(_tu.global_position)])
		_diario("salta per sbloccarsi, in %s" % _dove(_tu.global_position))
		_premi(_pulsante("SALTA"))


# ------------------------------------------------------------------ i pollici

func _leva(spinta: float) -> void:
	if not _leva_giu:
		return
	var centro := _punto(LEVA)
	_trascina(DITO_LEVA, centro + Vector2(0, -Comandi.RAGGIO_LEVA * spinta))


func _appoggia_la_mira() -> void:
	_mira_punto = _punto(MIRA)
	_mira_percorso = 0.0
	_tocco(DITO_MIRA, _mira_punto, true)
	_mira_giu = true


## Il pollice destro trascina di `quanto`, al massimo `PASSO_MASSIMO` per fotogramma.
## Uscito dal suo riquadro si alza (ha già trascinato: non è un colpo) e si riappoggia.
func _trascina_la_mira(quanto: Vector2) -> void:
	if not _mira_giu:
		return
	quanto = quanto.limit_length(PASSO_MASSIMO)
	if quanto.length() < 0.5:
		return
	var dove := _mira_punto + quanto
	var riquadro := Rect2(RIQUADRO_MIRA.position * _vista, RIQUADRO_MIRA.size * _vista)
	if not riquadro.has_point(dove) and _mira_percorso > Comandi.SOGLIA_TRASCINAMENTO * 2.0:
		_tocco(DITO_MIRA, _mira_punto, false)
		_appoggia_la_mira()
		return
	_trascina(DITO_MIRA, dove)
	_mira_percorso += quanto.length()
	_mira_punto = dove


## Un tocco su un pulsante con un terzo dito: giù adesso, su fra due fotogrammi.
func _premi(pulsante: Control) -> void:
	if pulsante == null or not pulsante.visible:
		return
	_tasto_punto = pulsante.get_global_rect().get_center()
	_tocco(DITO_TASTO, _tasto_punto, true)
	_tasto_su_fra = 2


func _lascia_il_tasto() -> void:
	if _tasto_su_fra <= 0:
		return
	_tasto_su_fra -= 1
	if _tasto_su_fra == 0:
		_tocco(DITO_TASTO, _tasto_punto, false)


func _tocca(pulsante: Control) -> void:
	var centro := pulsante.get_global_rect().get_center()
	_tocco(DITO_TASTO, centro, true)
	await _riposa(2)
	_tocco(DITO_TASTO, centro, false)
	await _riposa(2)


func _pulsante(nome: String) -> Button:
	for figlio in _comandi.get_children():
		if figlio is Button and String((figlio as Button).get_meta("nome", "")) == nome:
			return figlio
	return null


func _alza_tutto() -> void:
	if _leva_giu:
		_tocco(DITO_LEVA, _punto(LEVA), false)
		_leva_giu = false
	if _mira_giu:
		_tocco(DITO_MIRA, _mira_punto, false)
		_mira_giu = false


## I tocchi arrivano in punti della **finestra**, come dal telefono, e il motore li porta
## sulla tela: chi li scrivesse in punti della tela toccherebbe 1,85 volte più in là (la
## prima prova del 24/10/2026 toccava fuori dai pulsanti della Home).
func _tocco(dito: int, punto: Vector2, giu: bool) -> void:
	var evento := InputEventScreenTouch.new()
	evento.index = dito
	evento.position = punto * _fattore
	evento.pressed = giu
	Input.parse_input_event(evento)


var _ultimo := {}

func _trascina(dito: int, punto: Vector2) -> void:
	var evento := InputEventScreenDrag.new()
	evento.index = dito
	evento.position = punto * _fattore
	evento.relative = (punto - Vector2(_ultimo.get(dito, punto))) * _fattore
	_ultimo[dito] = punto
	Input.parse_input_event(evento)


# ------------------------------------------------------------------ servizio

func _scala() -> float:
	return _tu.camera().fov / float(_tu.get("_campo_terza"))


func _punto(frazione: Vector2) -> Vector2:
	return frazione * _vista


func _dove(p: Vector3) -> String:
	return "(%.1f; %.1f; %.1f)" % [p.x, p.y, p.z]


func _diario(testo: String) -> void:
	print("  %6.1f s  %s" % [_tempo, testo])


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


## Il video: la finestra com'è, un fotogramma per giro, dalla Home alla fine.
func _registra() -> void:
	DirAccess.make_dir_recursive_absolute(_video)
	for vecchio in DirAccess.get_files_at(_video):
		DirAccess.remove_absolute(_video + "/" + vecchio)
	var n := 0
	while not _finito:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("%s/%05d.jpg" % [_video, n], 0.9)
		n += 1


func _fine(errore: String, aspetto_di_prima: int, modalita_di_prima: int) -> void:
	_finito = true
	if errore != "":
		_rosso = errore
	Aspetto.scegli(aspetto_di_prima)
	Modalita.scegli(modalita_di_prima)
	match _modo:
		"gara":
			if _con_avversari and _arena != null:
				var righe: Array = _arena.get("_concorrenti")
				var bandiere := []
				for riga: Dictionary in righe:
					bandiere.append("%s %d bandiere (l'ultima a %.1f s) e %d colpi presi" % [riga["nome"],
							int(riga.get("bandiere", 0)), float(riga.get("quando", 0.0)),
							int(riga.get("colpito", 0))])
				print("a fine gara: %s" % "; ".join(PackedStringArray(bandiere)))
				var prima := 0
				for colpo in _presi:
					if bool(colpo["prima"]):
						prima += 1
				print("prima bandiera: %s · colpi presi prima della prima bandiera: %d · la serie più fitta in 6 s: %s"
						% ["a %.1f s" % _prima_bandiera if _prima_bandiera >= 0.0 else "mai", prima,
						_serie_piu_fitta()])
		"palla":
			print("lanci %d, gol %d" % [_lanci, _gol])
		"scontro":
			print("colpi %d, a segno %d" % [_colpi, _a_segno])
			print("un avversario sullo schermo: entro 15 m per %.1f s, entro 40 m per %.1f s, su %.1f s"
					% [_in_vista_15, _in_vista_40, _tempo])
	if _modo != "gara" and _arena != null:
		print("colpi presi %d · punti dai dischi: %s" % [_presi.size(),
				str(_dai_dischi) if not _dai_dischi.is_empty() else "nessuno"])
		# La classifica com'è quando il pilota smette: non è il risultato finale (§ 78).
		var pezzi := PackedStringArray()
		for riga in _arena.classifica():
			pezzi.append("%s %d" % [String(riga["nome"]), int(riga["punti"])])
		print("classifica a %.0f s: %s" % [_tempo, " · ".join(pezzi)])
	print(_conto_dei_cartelli())
	print("salti per sbloccarsi: %d%s" % [_salti.size(),
			("  — " + ", ".join(PackedStringArray(_salti))) if not _salti.is_empty() else ""])
	if _rosso != "":
		print("ROSSO: %s (%.1f s)" % [_rosso, _tempo])
		quit(1)
	else:
		print("VERDE: %s in %.1f s" % [_modo, _tempo])
		quit(0)
