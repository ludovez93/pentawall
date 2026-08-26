class_name Strati
extends RefCounted

## Gli strati di collisione, con i numeri scritti in un posto solo.
##
## La regola del gioco sta qui: il MONDO riflette, tutto il resto assorbe.
## Chi calcola una traiettoria cerca su tutti e guarda cosa ha trovato.

const MONDO := 1 << 0        ## 1 — pareti, pavimento, pilastri: il proiettile ci rimbalza
const COMBATTENTI := 1 << 1  ## 2 — i corpi che combattono: chi gioca e gli avversari
const BERSAGLIO := 1 << 2    ## 4 — i bersagli del poligono

## Chi ferma il dardo invece di rifletterlo. È la distinzione che regge tutto il
## gioco: un avversario non è un muro, e un muro non fa punti.
const ASSORBE := BERSAGLIO | COMBATTENTI

## Quello che un proiettile o una linea di mira devono vedere.
const TIRO := MONDO | ASSORBE
