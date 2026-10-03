shader_type spatial;

// La divisa da gara: il corpo base (Quaternius) ha addosso solo la pelle, e la
// divisa gliela mettiamo qui. Due maschere dicono cosa e' cosa:
//  - `maschera`: dove resta la pelle (la testa, bianco) e dove va la divisa;
//  - `divisa` (dal 03/10/2026, `tools/genera_maschere_divisa.py`): R le scarpe
//    (1 la tomaia, 0,5 la suola), G i guanti, B gli inserti su avambracci e
//    stinchi. Prima la tuta era una tinta sola dal collo ai piedi, mani e piedi
//    compresi: da vicino un manichino scalzo in calzamaglia.
// I colori sono parametri, cosi' ogni concorrente ha i suoi senza una texture
// in piu'. Le pieghe e la lucentezza restano quelle del corpo.

uniform sampler2D base : source_color, filter_linear_mipmap;
uniform sampler2D maschera : hint_default_white, filter_linear_mipmap;
uniform sampler2D divisa : hint_default_black, filter_linear_mipmap;
uniform sampler2D normale : hint_normal, filter_linear_mipmap;
uniform sampler2D rugosita : hint_default_white, filter_linear_mipmap;
uniform vec4 tuta : source_color = vec4(0.2, 0.4, 1.0, 1.0);
uniform vec4 secondo : source_color = vec4(0.95, 0.95, 0.97, 1.0);
uniform vec4 scarpe : source_color = vec4(0.93, 0.93, 0.95, 1.0);
uniform vec4 suola : source_color = vec4(0.07, 0.07, 0.09, 1.0);
uniform vec4 guanti : source_color = vec4(0.09, 0.09, 0.11, 1.0);
uniform vec4 dettaglio : source_color = vec4(0.06, 0.06, 0.09, 1.0);
// Il lampo del colpo incassato e il lampeggio dell'immunita': la divisa fa luce
// nel suo colore. Resta l'eccezione dichiarata alla regola «sopra l'uno solo il
// dardo» (DECISIONI.md § B): dura quanto l'urto.
uniform float lampo = 0.0;

void fragment() {
	vec4 b = texture(base, UV);
	float pelle = texture(maschera, UV).r;
	vec3 m = texture(divisa, UV).rgb;
	// L'ombra cotta nella texture del corpo modella anche la divisa.
	float luce = dot(b.rgb, vec3(0.333));
	// Poca, di proposito: la texture del corpo disegna i muscoli, e una tuta li copre.
	float ombra = 0.82 + 0.3 * luce;
	// Le pieghe della normale disegnano cuciture scure sulla tuta.
	vec3 n = texture(normale, UV).rgb;
	float cucitura = smoothstep(0.35, 0.0, abs(n.r - 0.5) + abs(n.g - 0.5));
	vec3 colore = mix(dettaglio.rgb, tuta.rgb * ombra, clamp(cucitura + 0.75, 0.0, 1.0));

	// Le tre zone, con una precedenza: sui bordi la maschera mescola i canali, e
	// senza precedenza nascerebbe un terzo colore che non e' di nessuno.
	float scarpa = step(0.3, m.r);
	float della_suola = scarpa * (1.0 - step(0.75, m.r));
	float guanto = (1.0 - scarpa) * step(0.5, m.g);
	float inserto = (1.0 - scarpa) * (1.0 - guanto) * step(0.5, m.b);
	colore = mix(colore, secondo.rgb * ombra, inserto);
	colore = mix(colore, guanti.rgb * ombra, guanto);
	colore = mix(colore, mix(scarpe.rgb, suola.rgb, della_suola) * ombra, scarpa);

	ALBEDO = mix(colore, b.rgb, pelle);
	// Sotto la divisa le normali si appiattiscono: e' stoffa, non pelle dipinta.
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), n, pelle);
	float ruvido = mix(0.5, 0.62, guanto);
	ruvido = mix(ruvido, 0.32, scarpa * (1.0 - della_suola));
	ROUGHNESS = mix(ruvido, texture(rugosita, UV).r, pelle);
	SPECULAR = mix(0.55, 0.4, pelle);
	EMISSION = mix(tuta.rgb, vec3(1.0), 0.35) * lampo * (1.0 - pelle * 0.6);
}
