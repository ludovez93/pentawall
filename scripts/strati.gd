class_name Strati
extends RefCounted

## Gli strati di collisione, con i numeri scritti in un posto solo.
##
## La regola del gioco sta qui: il MONDO riflette, il BERSAGLIO assorbe.
## Chi calcola una traiettoria cerca su tutti e due e guarda cosa ha trovato.

const MONDO := 1 << 0      ## 1 — pareti, pavimento, pilastri: il proiettile ci rimbalza
const GIOCATORE := 1 << 1  ## 2 — il corpo di chi gioca
const BERSAGLIO := 1 << 2  ## 4 — bersagli, e dalla tappa 2 i bot: il proiettile ci si ferma

## Quello che un proiettile o una linea di mira devono vedere.
const TIRO := MONDO | BERSAGLIO
