class_name Suoni
extends Node

## I suoni del gioco.
##
## Fino all'11/09/2026 il progetto non aveva un file audio; dal 12/09 ne aveva otto,
## sintetizzati da noi e mai ascoltati da nessuno. **Dal 03/10/2026 (tappa 8, blocco
## F) sono registrazioni vere**, tutte libere (CC0 o pubblico dominio: Kenney,
## OpenGameArt, Wikimedia Commons — origine e licenza di ognuna in
## `assets/LICENZE.md`), preparate tutte allo stesso modo da `tools/prepara_suoni.py`:
## lo sparo di un blaster giocattolo vero, il «tock» del rimbalzo, il colpo con il
## «ding» dei punti, i passi, il salto e l'atterraggio, l'annunciatore del conto
## alla rovescia, la folla sulle tribune, e la musica — una per l'ingresso, una per
## la partita, e una più tirata per l'ultimo minuto.
##
## La firma resta: **il rimbalzo sale di tono a ogni muro**. È un file solo, e il
## tono lo alza il gioco con `pitch_scale` — tre semitoni a muro, il quinto è
## un'ottava sopra il primo. Così i cinque si contano a orecchio, che è il nome del
## gioco reso udibile.
##
## Una sola istanza per scena, che si registra in `attivo`: gli altri chiamano le
## funzioni statiche e se la scena non ha suoni non succede niente. Le voci si
## costruiscono **all'apertura** e si riusano: niente nasce durante la partita
## (LEARNED.md § 25). L'annunciatore parla inglese: voci italiane libere non ce ne
## sono, e «three, two, one, go» lo capiscono tutti.

const CARTELLA := "res://assets/audio/"

## Tutti i suoni che il gioco usa, per nome. Il collaudo dell'arena controlla che
## si carichino tutti.
const NOMI := ["sparo", "rimbalzo", "colpo", "incassato", "ricomparsa", "salto",
		"atterraggio", "conto_3", "conto_2", "conto_1", "via", "voce_ultimo_minuto",
		"voce_tempo_scaduto", "voce_vinto", "voce_perso", "voce_potenziamento",
		"potenziamento", "potenziamento_fine", "tocco", "podio", "vittoria", "sconfitta",
		"passo_0", "passo_1", "passo_2", "passo_3", "passo_4", "folla", "esultanza",
		"musica_ingresso", "musica_partita", "musica_finale"]

## I suoni che stanno nel mondo — chi li sente li sente da dove succedono.
const NEL_MONDO := ["sparo", "rimbalzo", "colpo"]

## Quante voci nel mondo possono suonare insieme: sei in campo che sparano e
## rimbalzano, otto bastano e la nona ruba la più vecchia.
const VOCI_NEL_MONDO := 8

## Tre semitoni a muro: 1 → 1,19 → 1,41 → 1,68 → 2,0.
const SEMITONI_A_MURO := 3.0

## I livelli, in dB, misurati l'uno contro l'altro: i file escono tutti a −1 dB di
## picco, e chi suona più forte lo decide il gioco, qui.
const MUSICA_DB := -13.0
const MUSICA_INGRESSO_DB := -9.0
const FOLLA_DB := -21.0
const DISSOLVENZA_MUSICA := 0.9

static var attivo: Suoni = null

var _flussi := {}
var _voci: Array[AudioStreamPlayer3D] = []
var _prossima_voce := 0
var _mie := {}
var _ultimo_passo := -1
var _musica: Array[AudioStreamPlayer] = []
var _musica_accesa := 0
var _brano := ""
var _folla: AudioStreamPlayer


func _ready() -> void:
	attivo = self
	for nome in NOMI:
		var percorso: String = CARTELLA + String(nome) + ".ogg"
		var flusso: AudioStream = load(percorso) if ResourceLoader.exists(percorso) else null
		if flusso == null:
			push_warning("manca il suono %s: si gioca senza" % percorso)
		elif flusso is AudioStreamOggVorbis and (String(nome).begins_with("musica")
				or nome == "folla"):
			(flusso as AudioStreamOggVorbis).loop = true
		_flussi[String(nome)] = flusso

	for i in VOCI_NEL_MONDO:
		var voce := AudioStreamPlayer3D.new()
		# L'arena è larga sessantasei metri: un rimbalzo dall'altra parte si deve
		# sentire lontano, non sparire.
		voce.unit_size = 12.0
		voce.max_distance = 80.0
		voce.max_db = 3.0
		voce.attenuation_filter_cutoff_hz = 8000.0
		add_child(voce)
		_voci.append(voce)

	# I suoni «tuoi» non stanno nel mondo: stanno addosso a chi gioca. Uno per nome,
	# così due suoni diversi non si rubano la voce.
	for nome in NOMI:
		if String(nome).begins_with("musica") or nome == "folla" or nome == "rimbalzo":
			continue
		var mia := AudioStreamPlayer.new()
		mia.stream = _flussi[nome]
		add_child(mia)
		_mie[nome] = mia

	for i in 2:
		var lettore := AudioStreamPlayer.new()
		lettore.volume_db = -80.0
		add_child(lettore)
		_musica.append(lettore)
	_folla = AudioStreamPlayer.new()
	_folla.stream = _flussi.get("folla")
	_folla.volume_db = FOLLA_DB
	add_child(_folla)
	_scalda.call_deferred()


## Ogni suono suona una volta all'apertura, muto: la prima riproduzione di un Ogg
## prepara il suo decodificatore, e farla durante il primo rimbalzo vorrebbe dire
## pagarla in un fotogramma di gioco (`LEARNED.md` § 26).
func _scalda() -> void:
	for nome in NEL_MONDO:
		var voce := _voci[_prossima_voce]
		_prossima_voce = (_prossima_voce + 1) % _voci.size()
		voce.stream = _flussi.get(nome)
		voce.volume_db = -80.0
		if voce.stream != null:
			voce.play()
	for nome in _mie:
		var mia: AudioStreamPlayer = _mie[nome]
		if mia.stream != null:
			mia.volume_db = -80.0
			mia.play()


func _exit_tree() -> void:
	if attivo == self:
		attivo = null


# ------------------------------------------------------------------ la partita

## Lo sparo. Il tuo è addosso a te e pieno; quello degli altri sta dove sta il
## tiratore, ed è così che si sente arrivare qualcuno da dietro un cassone.
static func sparo(dove: Vector3, mio: bool) -> void:
	if attivo == null:
		return
	var tono := randf_range(0.93, 1.07)
	if mio:
		attivo._mia("sparo", -5.0, tono)
	else:
		attivo._nel_mondo("sparo", dove, -6.0, tono)


## Il rimbalzo: lo stesso suono, tre semitoni più su a ogni muro.
static func rimbalzo(dove: Vector3, muri: int) -> void:
	if attivo == null:
		return
	var tono := pow(2.0, SEMITONI_A_MURO * float(maxi(muri, 1) - 1) / 12.0)
	attivo._nel_mondo("rimbalzo", dove, -2.0, tono)


## Il colpo a segno, pieno, con il «ding» dei punti: con più muri sale un filo, come
## il conto. E dalle due sponde in su la folla se ne accorge.
static func colpo_a_segno(muri: int) -> void:
	if attivo == null:
		return
	attivo._mia("colpo", -1.0, 1.0 + 0.05 * float(muri))
	if muri >= 2:
		attivo._mia("esultanza", -9.0 + 1.5 * float(muri - 2), randf_range(0.96, 1.04))


## Un colpo fra altri due, da qualche parte nell'arena: sordo e lontano.
static func colpo_nel_mondo(dove: Vector3) -> void:
	if attivo == null:
		return
	attivo._nel_mondo("colpo", dove, -9.0, 0.88)


static func colpo_incassato() -> void:
	if attivo == null:
		return
	attivo._mia("incassato", 0.0, randf_range(0.95, 1.05))


static func ricomparsa() -> void:
	if attivo == null:
		return
	attivo._mia("ricomparsa", -6.0, 1.0)


## Il passo: cinque passi veri, mai lo stesso due volte di fila.
static func passo() -> void:
	if attivo == null:
		return
	var quale := randi() % 5
	if quale == attivo._ultimo_passo:
		quale = (quale + 1) % 5
	attivo._ultimo_passo = quale
	attivo._mia("passo_%d" % quale, -15.0, randf_range(0.94, 1.06))


static func salto() -> void:
	if attivo == null:
		return
	attivo._mia("salto", -16.0, randf_range(0.97, 1.03))


## L'atterraggio: più forte quanto più si è caduti (da 0 a 1).
static func atterraggio(forza: float) -> void:
	if attivo == null:
		return
	attivo._mia("atterraggio", lerpf(-16.0, -6.0, clampf(forza, 0.0, 1.0)), 1.0)


## Il conto alla rovescia del fischio d'inizio: l'annunciatore dice il numero.
static func conto(numero: int = 3) -> void:
	if attivo == null:
		return
	attivo._mia("conto_%d" % clampi(numero, 1, 3), -2.0, 1.0)


static func via() -> void:
	if attivo == null:
		return
	attivo._mia("via", 0.0, 1.0)
	attivo._mia("tocco", -6.0, 0.8)


## L'ultimo minuto: l'annunciatore lo dice, e la musica cambia brano.
static func ultimo_minuto() -> void:
	if attivo == null:
		return
	attivo._mia("voce_ultimo_minuto", -2.0, 1.0)
	musica("musica_finale")


## Fine partita: tempo scaduto, poi il verdetto — jingle e voce.
static func fine_partita(vinto: bool) -> void:
	if attivo == null:
		return
	ferma_la_musica()
	attivo._mia("voce_tempo_scaduto", -2.0, 1.0)
	var chi := attivo.get_instance_id()
	attivo.get_tree().create_timer(1.1).timeout.connect(func() -> void:
		var io := instance_from_id(chi) as Suoni
		if io == null or not is_instance_valid(io):
			return
		io._mia("vittoria" if vinto else "sconfitta", -3.0, 1.0)
		io._mia("voce_vinto" if vinto else "voce_perso", -1.0, 1.0)
		if vinto:
			io._mia("esultanza", -6.0, 1.0))


static func potenziamento(mio: bool) -> void:
	if attivo == null:
		return
	attivo._mia("potenziamento", -4.0 if mio else -14.0, 1.0)
	if mio:
		attivo._mia("voce_potenziamento", -2.0, 1.0)


static func potenziamento_finito() -> void:
	if attivo == null:
		return
	attivo._mia("potenziamento_fine", -7.0, 1.0)


static func tocco() -> void:
	if attivo == null:
		return
	attivo._mia("tocco", -8.0, 1.0)


# ------------------------------------------------------------------ musica e folla

## Un brano di sottofondo, in dissolvenza incrociata con quello di prima. Lo stesso
## brano chiesto due volte non riparte da capo.
static func musica(nome: String) -> void:
	if attivo == null or attivo._brano == nome:
		return
	var flusso: AudioStream = attivo._flussi.get(nome)
	if flusso == null:
		return
	attivo._brano = nome
	var vecchio := attivo._musica[attivo._musica_accesa]
	attivo._musica_accesa = 1 - attivo._musica_accesa
	var nuovo := attivo._musica[attivo._musica_accesa]
	nuovo.stream = flusso
	nuovo.volume_db = -60.0
	nuovo.play()
	var volume := MUSICA_INGRESSO_DB if nome == "musica_ingresso" else MUSICA_DB
	var giro := attivo.create_tween().set_parallel(true)
	giro.tween_property(nuovo, "volume_db", volume, DISSOLVENZA_MUSICA)
	giro.tween_property(vecchio, "volume_db", -60.0, DISSOLVENZA_MUSICA)
	giro.chain().tween_callback(vecchio.stop)


static func ferma_la_musica() -> void:
	if attivo == null:
		return
	attivo._brano = ""
	var giro := attivo.create_tween().set_parallel(true)
	for lettore in attivo._musica:
		giro.tween_property(lettore, "volume_db", -60.0, DISSOLVENZA_MUSICA)
	giro.chain().tween_callback(func() -> void:
		for lettore in attivo._musica:
			lettore.stop())


## Il brano che sta suonando: serve al collaudo.
static func brano() -> String:
	return "" if attivo == null else attivo._brano


## Il brusio delle tribune: c'è finché c'è la partita.
static func folla(accesa: bool) -> void:
	if attivo == null or attivo._folla == null or attivo._folla.stream == null:
		return
	if accesa and not attivo._folla.playing:
		attivo._folla.play(randf() * 40.0)
	elif not accesa:
		attivo._folla.stop()


# ------------------------------------------------------------------ meccanica

func _mia(nome: String, volume_db: float, tono: float) -> void:
	var voce: AudioStreamPlayer = _mie.get(nome)
	if voce == null or voce.stream == null:
		return
	voce.volume_db = volume_db
	voce.pitch_scale = tono
	voce.play()


## Una voce nel mondo: la prossima libera, o la più vecchia se sono tutte occupate.
func _nel_mondo(nome: String, dove: Vector3, volume_db: float, tono: float) -> void:
	var flusso: AudioStream = _flussi.get(nome)
	if flusso == null or _voci.is_empty():
		return
	var voce: AudioStreamPlayer3D = null
	for i in _voci.size():
		var candidata := _voci[(_prossima_voce + i) % _voci.size()]
		if not candidata.playing:
			voce = candidata
			_prossima_voce = (_prossima_voce + i + 1) % _voci.size()
			break
	if voce == null:
		voce = _voci[_prossima_voce]
		_prossima_voce = (_prossima_voce + 1) % _voci.size()
	voce.stream = flusso
	voce.global_position = dove
	voce.volume_db = volume_db
	voce.pitch_scale = tono
	voce.play()
