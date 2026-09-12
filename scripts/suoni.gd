class_name Suoni
extends Node

## I suoni del gioco (tappa 7, blocco B: «il colpo che si sente»).
##
## Fino all'11/09/2026 il progetto non aveva un file audio: si sparava, si
## colpiva e si veniva colpiti nel silenzio, e la prova col pollice ha detto «non
## coinvolgente». Qui ci sono i sei suoni che servono, **sintetizzati da noi**
## (`tools/genera_suoni.py`, WAV corti) così nessuna licenza entra nel gioco.
##
## La firma: **il rimbalzo sale di tono a ogni muro**. È un file solo, e il tono lo
## alza il gioco con `pitch_scale` — tre semitoni a muro, il quinto è un'ottava
## sopra il primo. Così i cinque si contano a orecchio, che è il nome del gioco
## reso udibile.
##
## Una sola istanza per scena, che si registra in `attivo`: gli altri chiamano le
## funzioni statiche e se la scena non ha suoni non succede niente. Le voci si
## costruiscono **all'apertura** e si riusano: niente nasce durante la partita
## (LEARNED.md § 25).

const CARTELLA := "res://assets/audio/"
const NOMI := ["sparo", "rimbalzo", "colpo", "incassato", "ricomparsa", "passo"]

## Quante voci nel mondo possono suonare insieme: sei in campo che sparano e
## rimbalzano, otto bastano e la nona ruba la più vecchia.
const VOCI_NEL_MONDO := 8

## Tre semitoni a muro: 1 → 1,19 → 1,41 → 1,68 → 2,0.
const SEMITONI_A_MURO := 3.0

static var attivo: Suoni = null

var _flussi := {}
var _voci: Array[AudioStreamPlayer3D] = []
var _prossima_voce := 0
var _mie := {}
var _passo_destro := false


func _ready() -> void:
	attivo = self
	for nome in NOMI:
		var percorso: String = CARTELLA + String(nome) + ".wav"
		_flussi[String(nome)] = load(percorso) if ResourceLoader.exists(percorso) else null
		if _flussi[nome] == null:
			push_warning("manca il suono %s: si gioca senza" % percorso)

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

	# I suoni «tuoi» — il tuo sparo, il colpo a segno, quello incassato, la
	# ricomparsa, il passo — non stanno nel mondo: stanno addosso a chi gioca.
	for nome in ["sparo", "colpo", "incassato", "ricomparsa", "passo"]:
		var mia := AudioStreamPlayer.new()
		mia.stream = _flussi[nome]
		add_child(mia)
		_mie[nome] = mia


func _exit_tree() -> void:
	if attivo == self:
		attivo = null


## Lo sparo. Il tuo è addosso a te e pieno; quello degli altri sta dove sta il
## tiratore, ed è così che si sente arrivare qualcuno da dietro un cassone.
static func sparo(dove: Vector3, mio: bool) -> void:
	if attivo == null:
		return
	var tono := randf_range(0.95, 1.05)
	if mio:
		attivo._mia("sparo", -2.0, tono)
	else:
		attivo._nel_mondo("sparo", dove, -5.0, tono)


## Il rimbalzo: lo stesso suono, tre semitoni più su a ogni muro.
static func rimbalzo(dove: Vector3, muri: int) -> void:
	if attivo == null:
		return
	var tono := pow(2.0, SEMITONI_A_MURO * float(maxi(muri, 1) - 1) / 12.0)
	attivo._nel_mondo("rimbalzo", dove, 0.0, tono)


## Il colpo a segno, pieno: con più muri sale un filo, come il conto.
static func colpo_a_segno(muri: int) -> void:
	if attivo == null:
		return
	attivo._mia("colpo", 0.0, 1.0 + 0.05 * float(muri))


## Un colpo fra altri due, da qualche parte nell'arena: sordo e lontano.
static func colpo_nel_mondo(dove: Vector3) -> void:
	if attivo == null:
		return
	attivo._nel_mondo("colpo", dove, -8.0, 0.9)


static func colpo_incassato() -> void:
	if attivo == null:
		return
	attivo._mia("incassato", 0.0, randf_range(0.96, 1.04))


static func ricomparsa() -> void:
	if attivo == null:
		return
	attivo._mia("ricomparsa", -4.0, 1.0)


## Il passo, alternato: un piede un filo più basso dell'altro.
static func passo() -> void:
	if attivo == null:
		return
	attivo._passo_destro = not attivo._passo_destro
	attivo._mia("passo", -10.0, 1.06 if attivo._passo_destro else 0.94)


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
