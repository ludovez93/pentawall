extends SceneTree

## Attrezzo di lavorazione: **la prima immagine della tappa 7**. Apre l'arena
## vera, la veste (`Vestizione`), mette un corpo vero al giocatore e a un
## avversario a quindici metri, accende l'interfaccia della partita al posto di
## quella di collaudo, e scatta dalla camera vera **alle misure del telefono**:
##
##   godot --path . --resolution 854x390 -s tools/scatti_vestito.gd -- blocchetti
##
## Il primo argomento è la variante dei corpi (`blocchetti` o `umani`); il secondo, se
## c'è, il nome del file. Vuole la finestra: senza schermo lo scatto resta
## appeso (STATUS.md, avvertenze).

const CARTELLA := "res://scatti"
const DISTANZA_AVVERSARIO := 15.0
const LIME := Color(0.60, 1.0, 0.24)
const SCURO := Color(0.03, 0.03, 0.06)

var _arena: Node
var _giocatore: Giocatore


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var variante := "blocchetti" if argomenti.is_empty() else String(argomenti[0])
	var nome_file := "A1-angolo-vestito-%s.png" % variante
	if argomenti.size() > 1:
		nome_file = String(argomenti[1])

	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	await _riposa(40)
	_giocatore = _arena.call("giocatore")
	print("finestra: ", DisplayServer.window_get_size())

	Vestizione.vesti(_arena)
	Vestizione.arreda_angolo(_arena)

	# Il giocatore alla partenza nord-ovest, che guarda verso il cuore.
	_metti(Vector3(-29.0, 0.0, -29.0), 225.0, -5.0)
	var corpo_mio := _corpo(variante, "male-b", Giocatore.ALTEZZA_CORPO)
	_giocatore.vesti_con(corpo_mio)
	var scheletro := Vestizione.trova(corpo_mio, "Skeleton3D") as Skeleton3D
	if scheletro != null:
		var ossa := []
		for i in scheletro.get_bone_count():
			ossa.append(scheletro.get_bone_name(i))
		print("ossa: ", ossa)
	await process_frame
	for nodo in Vestizione.tutti(corpo_mio):
		if nodo is BoneAttachment3D:
			print("attacco blaster a ", (nodo as BoneAttachment3D).global_position,
					" giocatore a ", _giocatore.global_position)

	# L'avversario **in piedi sul cassone** davanti alla partenza, a otto metri e
	# mezzo: dalla partenza ogni linea di vista a terra finisce contro un cassone
	# (sono lì per coprirla), e uno in piedi sulla copertura è una cosa che in
	# partita succede. La prova «capisci chi è senza leggere il nome?» si fa qui.
	var bot := Avversario.crea(_arena, Vector3(-20.8, 2.62, -27.4))
	bot.set_physics_process(false)
	await process_frame
	_guarda(bot, _giocatore.global_position)
	var corpo_bot := _corpo(variante, "female-a", Avversario.ALTEZZA_CORPO)
	bot.vesti_con(corpo_bot, Vestizione.con_contorno(corpo_bot, SCURO, LIME))
	Vestizione.targhetta(bot, "QUARZO", Avversario.ALTEZZA_CORPO, Color(0.96, 0.96, 0.92))

	var comandi := _comandi()
	comandi.modalita_partita("2:41", 3, 150)
	comandi.classifica([
		{"posizione": 1, "nome": "QUARZO", "punti": 275, "tu": false},
		{"posizione": 3, "nome": "TU", "punti": 150, "tu": true},
	])

	await _riposa(30)
	await _scatta(nome_file)

	# Il secondo scatto: lo stesso avversario a quattro metri, di fronte, **in
	# prima persona** — la vista con cui si mira, e l'unica in cui il proprio
	# corpo non copre quello che si guarda. Nel corridoio lungo il muro nord, che
	# dalla partenza è lo spazio libero.
	_giocatore.cambia_camera()
	_metti(Vector3(-29.0, 0.0, -29.0), -67.0, -2.0)
	var avanti := -_giocatore.global_transform.basis.z
	var destra := _giocatore.global_transform.basis.x
	# Un passo a destra dell'asse: il marcatore della mira resta sul muro e non
	# sulla faccia, che è quello che si vuole guardare.
	bot.global_position = _giocatore.global_position + avanti * 3.4 + destra * 0.75
	_guarda(bot, _giocatore.global_position)
	# A riposo, non in mira: in mira il blaster copre la faccia, ed è la faccia
	# che si vuole guardare da vicino.
	_posa(corpo_bot, ["Idle", "idle"])
	await _riposa(20)
	await _scatta(nome_file.replace(".png", "-vicino.png"))
	print("fatto.")
	quit()


func _corpo(variante: String, personaggio: String, altezza: float) -> Node3D:
	match variante:
		"umani":
			# La tuta: blu per chi gioca, cremisi per gli avversari (i colori di oggi).
			var colore := Color(0.16, 0.42, 0.95) if personaggio.begins_with("male") 					else Avversario.colore_squadra
			return Vestizione.corpo_umano(personaggio, altezza, colore)
		_:
			return Vestizione.corpo_blocchetti(personaggio, altezza)


## Mette un corpo in una posa, provando i nomi in ordine (ogni pacchetto ha i suoi).
func _posa(corpo: Node3D, nomi: Array) -> void:
	var animatore := corpo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animatore == null:
		return
	for nome in nomi:
		if animatore.has_animation(String(nome)):
			animatore.play(String(nome))
			return


## Gira un corpo verso un punto, sul piano: la faccia è -Z.
func _guarda(chi: Node3D, verso: Vector3) -> void:
	chi.look_at(Vector3(verso.x, chi.global_position.y, verso.z))


func _comandi() -> Comandi:
	for figlio in _arena.get_children():
		if figlio is Comandi:
			return figlio
	return null


func _metti(dove: Vector3, giro_gradi: float, pendenza_gradi: float) -> void:
	_giocatore.global_position = dove
	_giocatore.velocity = Vector3.ZERO
	_giocatore.punta(giro_gradi, pendenza_gradi)


func _riposa(fotogrammi: int) -> void:
	for i in fotogrammi:
		await process_frame


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var immagine := root.get_texture().get_image()
	immagine.save_png(CARTELLA + "/" + nome)
	print("  ", nome, "  ", immagine.get_width(), "x", immagine.get_height())
