class_name Modalita
extends RefCounted

## **La modalità della partita** (tappa 11, blocco D, accettate il 05/10/2026). Nel 1999
## erano tre — PointBlast, SpeedBlast, BallBlast — e due giravano nella stessa arena
## (`RICERCA-ORIGINALE.md` § 2). Da noi: SCONTRO, la partita a punti di sempre, e GARA,
## sette bandiere in ordine (`Bandiere`).
##
## Si sceglie sulla Home, con la riga sopra GIOCA, e resta salvata sul telefono come
## l'aspetto: chi gioca la gara la ritrova la volta dopo.

const FILE := "user://modalita.cfg"
const NOMI: Array[String] = ["SCONTRO", "GARA"]
const SCONTRO := 0
const GARA := 1

static var _scelta := -1


## La modalità in uso: letta una volta dal telefono, poi tenuta in memoria.
static func scelta() -> int:
	if _scelta < 0:
		var cfg := ConfigFile.new()
		_scelta = int(cfg.get_value("modalita", "scelta", SCONTRO)) if cfg.load(FILE) == OK else SCONTRO
		_scelta = clampi(_scelta, 0, NOMI.size() - 1)
	return _scelta


static func scegli(quale: int) -> void:
	_scelta = clampi(quale, 0, NOMI.size() - 1)
	var cfg := ConfigFile.new()
	cfg.set_value("modalita", "scelta", _scelta)
	cfg.save(FILE)


static func nome() -> String:
	return NOMI[scelta()]
