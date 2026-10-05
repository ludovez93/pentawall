extends SceneTree

## Attrezzo di lavorazione: **il lampeggio delle cime** (05/10/2026, dal telefono: *«le
## parti superiori di alcune forme lampeggiavano veloci»*). Una faccia doppia in uno
## scatto fermo non si riconosce: lampeggia quando la camera si muove. Qui la camera sta
## in alto sopra l'ala ocra, guarda le cime dei moduli e scatta sei fotogrammi spostandosi
## di tre millimetri alla volta: dove due facce stanno in pari, da un fotogramma all'altro
## il colore cambia; dove no, si spostano solo i contorni.
##   godot --path . --resolution 854x390 -s tools/scatti_cime.gd -- <prefisso>
## Escono `scatti/cime-<prefisso>-<n>.png`.

const CARTELLA := "res://scatti"


func _initialize() -> void:
	_lavora()


func _lavora() -> void:
	var argomenti := OS.get_cmdline_user_args()
	var prefisso := argomenti[0] if argomenti.size() > 0 else "prova"
	var di_prima := Aspetto.scelta()
	Aspetto.scegli(Aspetto.GIOCATTOLO)
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	var arena: Node3D = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = 0.65
	for i in 30:
		await process_frame
	# Senza interfaccia: il contatore dei fotogrammi cambia a ogni scatto.
	for figlio in arena.find_children("*", "CanvasLayer", true, false):
		(figlio as CanvasLayer).visible = false
	var occhio := Camera3D.new()
	occhio.near = 0.05
	occhio.far = 220.0
	occhio.fov = 70.0
	arena.add_child(occhio)
	occhio.make_current()
	var partenza := Vector3(0.0, 22.0, -2.0)
	for n in 6:
		occhio.global_position = partenza + Vector3(0.003, 0.0, 0.002) * float(n)
		occhio.look_at(Vector3(0.0, 0.0, -22.0))
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/cime-%s-%d.png" % [CARTELLA, prefisso, n])
	Aspetto.scegli(di_prima)
	print("fatto: cime-%s" % prefisso)
	quit()
