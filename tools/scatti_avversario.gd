extends SceneTree

## Attrezzo di lavorazione: apre la sfida, la pilota da sola e salva una serie di
## scatti. Non fa parte del gioco.
##
## Serve perché di questa tappa metà si giudica solo guardandola: se l'avversario
## si distingue dal giocatore e dal dardo, se si capisce da che parte sta mirando,
## se il momento in cui schiva **si vede**. Tre difetti gravi della tappa 1 sono
## usciti solo dagli scatti, e nessuno dei tre dava un errore (LEARNED.md 14, 15).
##
## Uso:  godot --path . -s tools/scatti_avversario.gd
## Gli scatti finiscono in `scatti/`, che non entra nel repository.

const CARTELLA := "res://scatti"

## Il dardo vola a 19 m/s: a velocità normale, fra un fotogramma e l'altro fa
## mezzo metro e negli scatti non si becca mai.
const RALLENTATORE := 0.12

## La corsia usata per le pose: dritta, libera, e **senza il pilastro** che sta a
## x −6. Le prime inquadrature lo mettevano proprio dietro quello, e l'avversario
## non si vedeva affatto.
const CORSIA := -3.0

## Quanto dura l'annuncio grosso al centro dello schermo: si aspetta che sparisca,
## o si porta il colpo precedente dentro lo scatto seguente.
const ANNUNCIO := 1.7

var _poligono: Node
var _giocatore: Giocatore
var _bot: Avversario


func _initialize() -> void:
	seed(20260826)
	_lavora()


func _lavora() -> void:
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	_poligono = load("res://scenes/poligono.tscn").instantiate()
	root.add_child(_poligono)
	await _riposa(0.3)
	_giocatore = _poligono.call("giocatore")
	_poligono.call("avvia_sfida")
	await _riposa(ANNUNCIO)
	_bot = _poligono.call("avversario")

	# 1. Come si apre la sfida, in terza persona: i due in campo, e si deve capire
	#    in mezzo secondo chi è chi.
	_schiera(Vector3(CORSIA, 1.0, 8.0), Vector3(CORSIA, 0.2, -3.0), -3.0)
	await _riposa(0.5)
	await _scatta("20-sfida-apertura.png")

	# 2. L'avversario da vicino: casco, visiera, arma. È il momento in cui si vede
	#    se il cremisi litiga col colore riservato al dardo — e se si capisce da
	#    che parte sta guardando, perché è da lì che arriva il colpo.
	_giocatore.cambia_camera()
	_schiera(Vector3(CORSIA, 1.0, 4.4), Vector3(CORSIA, 0.2, 1.0), -1.0)
	await _riposa(0.6)
	await _scatta("21-avversario-di-faccia.png")

	# 3. La visuale di mira a distanza di combattimento: il mirino addosso a lui.
	_schiera(Vector3(CORSIA, 1.0, 7.0), Vector3(CORSIA, 0.2, -3.0), -2.0)
	await _riposa(0.5)
	await _scatta("22-prima-persona-sfida.png")

	# 4. Appena colpito, lampeggia. Senza, si vedrebbe un avversario incassare un
	#    colpo e non succedere niente. In prima persona, o il proprio corpo lo
	#    copre proprio nell'istante che conta.
	_schiera(Vector3(CORSIA, 1.0, 4.0), Vector3(CORSIA, 0.2, -2.0), -2.0)
	await _riposa(0.4)
	_bot.incassa(0, _giocatore)
	# Il lampeggio si accende fra il quarto e l'ottavo centesimo dopo il colpo.
	await _riposa(0.06)
	await _scatta("23-avversario-colpito.png")
	_giocatore.cambia_camera()
	await _riposa(ANNUNCIO)

	# 5. Il dardo in volo verso di lui, in terza persona: deve staccarsi dal fondo
	#    **e** dal rosso dell'avversario.
	_schiera(Vector3(CORSIA, 1.0, 6.0), Vector3(CORSIA + 2.6, 0.2, -3.0), -3.0)
	await _riposa(0.4)
	Engine.time_scale = RALLENTATORE
	_giocatore.spara()
	await _riposa(0.3)
	await _scatta("24-dardo-verso-avversario.png")
	Engine.time_scale = 1.0
	await _riposa(ANNUNCIO)

	# 6. La schivata, fotografata **mentre succede**. È la cosa che questa tappa
	#    deve far vedere: se non si legge, chi gioca crede di aver sbagliato mira.
	await _scatta_una_schivata()

	# 7. Lo schermo di gioco vero, con l'avversario che insegue: punteggio a due,
	#    livello, e i pulsanti nuovi. Su sei pollici la lettura è metà del lavoro.
	_bot.bersaglio = _giocatore
	_giocatore.global_position = Vector3(-9.0, 1.0, 6.5)
	await _riposa(1.4)
	_giocatore.punta(_verso(_giocatore.global_position, _bot.global_position), -3.0)
	await _riposa(0.08)
	await _scatta("26-schermo-di-gioco.png")

	print("scatti finiti in ", CARTELLA)
	quit(0)


## Gli spara addosso e fotografa **due volte dalla stessa inquadratura**: appena
## il dardo è partito, e a balzo iniziato. Uno scatto solo non racconta niente —
## un avversario che scarta, fermo in una fotografia, sembra semplicemente in
## piedi. È il confronto che fa vedere la schivata.
##
## Al livello duro e da undici metri: di lì la schivata riesce sempre, ed è la
## schivata che si vuole mostrare, non il caso limite — quello è roba da collaudo.
func _scatta_una_schivata() -> void:
	_poligono.call("cambia_livello")   # da medio a duro
	_schiera(Vector3(CORSIA, 1.0, 7.5), Vector3(CORSIA + 1.5, 0.2, -3.0), -3.0)
	await _riposa(ANNUNCIO)

	var centro := _bot.global_position + Vector3(0, Avversario.ALTEZZA_PETTO, 0)
	var da := centro + Vector3(2.5, 0.5, 10.0)
	Engine.time_scale = RALLENTATORE
	Proiettile.lancia(_poligono, da, (centro - da).normalized())
	await _riposa(0.08 / RALLENTATORE)
	await _scatta("25-schivata-prima.png")

	# Si aspetta l'esito — il balzo — non un numero di fotogrammi (LEARNED.md 17).
	var scadenza := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < scadenza and not _bot.in_schivata():
		await process_frame
	if not _bot.in_schivata():
		print("  ATTENZIONE: il balzo non è partito, lo scatto seguente non vale")
	# E poi si aspetta che il balzo sia a metà strada: sono ventisei centesimi di
	# **gioco**, non di orologio. Col rallentatore acceso valgono due secondi veri,
	# e il primo tentativo — un decimo di secondo d'orologio — fotografava un
	# avversario ancora fermo.
	await _riposa(0.26 / RALLENTATORE)
	await _scatta("25-schivata-dopo.png")
	Engine.time_scale = 1.0


## Mette i due in campo uno di fronte all'altro. L'avversario **guarda il
## giocatore**: in gioco lo fa da sé, seguendo la mira, ma qui è fermo — e un
## avversario girato di spalle nasconde proprio le cose che lo scatto deve
## mostrare, la visiera e l'arma.
func _schiera(dove_giocatore: Vector3, dove_bot: Vector3, pendenza: float) -> void:
	_giocatore.global_position = dove_giocatore
	_giocatore.punta(_verso(dove_giocatore, dove_bot), pendenza)
	_bot.bersaglio = null
	_bot.global_position = dove_bot
	_bot.velocity = Vector3.ZERO
	_bot.rotation.y = deg_to_rad(_verso(dove_bot, dove_giocatore))


## I gradi di rotazione che fanno guardare da `da` verso `a`.
func _verso(da: Vector3, a: Vector3) -> float:
	var d := a - da
	d.y = 0.0
	if d.length_squared() < 0.001:
		return 0.0
	return rad_to_deg(atan2(-d.x, -d.z))


func _riposa(secondi: float) -> void:
	var fine := Time.get_ticks_msec() + int(secondi * 1000.0)
	while Time.get_ticks_msec() < fine:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome, "  ", immagine.get_width(), "x", immagine.get_height())
