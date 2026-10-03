shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Il pubblico delle tribune (tappa 8, blocco E): persone low-poly di Quaternius
// (CC0), sedute o che esultano, disegnate a centinaia in poche passate. Ogni
// persona e' diversa senza una texture in piu':
//  - COLOR (il colore dell'istanza) e' la maglietta;
//  - INSTANCE_CUSTOM.r sceglie la carnagione e il colore dei capelli,
//    .g i pantaloni e le scarpe, .b la fase del tifo, .a quanto si agita.
// `parte` dice che pezzo di persona sta disegnando questo materiale.

uniform int parte = 0; // 0 pelle, 1 maglietta, 2 pantaloni, 3 scarpe, 4 capelli
uniform float salto_max = 0.12; // metri, in alto quando esulta
// La verticale del mondo misurata nel modello (un metro di su), calcolata una volta
// dal codice: e' uguale per tutte le persone della stessa posa.
uniform vec3 su_modello = vec3(0.0, 1.0, 0.0);

varying vec4 v_dati;
varying vec4 v_maglia;

vec3 pelle(float t) {
	vec3 chiara = vec3(0.96, 0.80, 0.68);
	vec3 media = vec3(0.82, 0.60, 0.45);
	vec3 olivastra = vec3(0.64, 0.45, 0.31);
	vec3 scura = vec3(0.36, 0.24, 0.17);
	if (t < 0.33) return mix(chiara, media, t / 0.33);
	if (t < 0.66) return mix(media, olivastra, (t - 0.33) / 0.33);
	return mix(olivastra, scura, (t - 0.66) / 0.34);
}

vec3 capelli(float t) {
	float k = fract(t * 7.31);
	if (k < 0.3) return vec3(0.07, 0.05, 0.04);
	if (k < 0.55) return vec3(0.28, 0.17, 0.09);
	if (k < 0.75) return vec3(0.80, 0.64, 0.36);
	if (k < 0.88) return vec3(0.55, 0.20, 0.10);
	return vec3(0.70, 0.70, 0.72);
}

void vertex() {
	v_dati = INSTANCE_CUSTOM;
	v_maglia = COLOR;
	// Chi esulta salta sul posto, ognuno col suo tempo: il salto si fa nel mondo,
	// non nel modello, che ha la sua scala e il suo verso.
	float onda = max(0.0, sin(TIME * (6.0 + v_dati.b * 3.0) + v_dati.b * 40.0));
	VERTEX += su_modello * onda * onda * salto_max * v_dati.a;
}

void fragment() {
	vec3 c;
	if (parte == 0) {
		c = pelle(v_dati.r);
	} else if (parte == 1) {
		c = v_maglia.rgb;
	} else if (parte == 2) {
		float t = v_dati.g;
		c = t < 0.4 ? vec3(0.16, 0.22, 0.40) : (t < 0.7 ? vec3(0.08, 0.08, 0.10) : vec3(0.42, 0.40, 0.36));
	} else if (parte == 3) {
		c = fract(v_dati.g * 5.0) < 0.5 ? vec3(0.92, 0.92, 0.94) : vec3(0.10, 0.10, 0.12);
	} else {
		c = capelli(v_dati.r);
	}
	ALBEDO = c;
	ROUGHNESS = 0.85;
}
