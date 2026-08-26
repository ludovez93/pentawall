class_name Strati
extends RefCounted

## Gli strati di collisione, con i numeri scritti in un posto solo.
##
## La regola del gioco sta qui: si rimbalza su ciò che è **sponda**, e tutto il
## resto ferma il dardo. Chi calcola una traiettoria cerca su tutti e guarda
## cosa ha trovato.

const MONDO := 1 << 0        ## 1 — le superfici su cui il proiettile rimbalza
const COMBATTENTI := 1 << 1  ## 2 — i corpi che combattono: chi gioca e gli avversari
const BERSAGLIO := 1 << 2    ## 4 — i bersagli del poligono
## 8 — superficie del mondo che **ferma** il dardo invece di rifletterlo. Nel
## poligono non c'è nessuno: là rimbalza tutto, e resta così. Serve dalla tappa 3,
## dove l'arena distingue le sponde dal resto — perché una geometria ricca in cui
## rimbalza qualunque sporgenza rende il rimbalzo un caso, non una bravura.
const OSTACOLO := 1 << 3

## Chi ferma il dardo invece di rifletterlo. È la distinzione che regge tutto il
## gioco: un avversario non è un muro, e un muro non fa punti.
const ASSORBE := BERSAGLIO | COMBATTENTI | OSTACOLO

## Dove si cammina e ci si sbatte contro. Rimbalzare e reggere il peso sono due
## mestieri diversi: una superficie può fare il secondo senza fare il primo.
const SOLIDO := MONDO | OSTACOLO

## Quello che un proiettile o una linea di mira devono vedere.
const TIRO := MONDO | ASSORBE
