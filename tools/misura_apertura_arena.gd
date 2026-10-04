extends "res://scripts/arena.gd"

## L'arena con un cronometro su ogni passo di `_ready` e di `entra_in_campo`: gli
## stessi metodi, nello stesso ordine di `Arena`. La usa `tools/misura_apertura.gd`.
## Se `Arena._ready` o `Arena.entra_in_campo` cambiano, questa va rimessa al passo.

var _t := 0


func _passo(nome: String) -> void:
	var adesso := Time.get_ticks_usec()
	if _t != 0:
		print("    %-26s %7.1f ms" % [nome, (adesso - _t) / 1000.0])
	_t = Time.get_ticks_usec()


func _ready() -> void:
	_passo("")
	_pianta = carica_pianta()
	_ambiente()
	_costruisci()
	_passo("costruisci (muri, sponde)")
	Vestizione.vesti(self)
	_passo("vesti")
	_tabellone = Vestizione.arreda_arena(self, _pianta)
	_passo("arreda (insegne, tabellone)")
	_pubblico()
	_passo("pubblico")
	_rete_di_cammino()
	_luci()
	_prepara_gli_anelli()
	add_child(Scintille.new())
	_potenziamenti = Potenziamenti.new()
	_potenziamenti.name = "potenziamenti"
	add_child(_potenziamenti)
	_potenziamenti.concorrenti = _corpi_in_campo
	_potenziamenti.prepara(POTENZIAMENTI)
	_potenziamenti.preso.connect(_su_potenziamento_preso)
	_potenziamenti.finito.connect(_su_potenziamento_finito)
	_passo("rete, luci, scintille, palle")
	_giocatore = Giocatore.new()
	add_child(_giocatore)
	_giocatore.preso_da.connect(_su_colpo_valido.bind(_giocatore))
	_mettiti_alla_partenza(0)
	_passo("giocatore")
	entra_in_campo()
	_passo("entra in campo")
