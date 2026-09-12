shader_type spatial;

// La tuta da gara: il corpo base (Quaternius) ha addosso solo la pelle, e la
// tuta gliela mettiamo qui. La maschera dice dove resta la pelle (la testa,
// bianco) e dove va la tuta (tutto il resto, nero); il colore della tuta e' un
// parametro, cosi' ogni concorrente ha il suo senza una texture in piu'.
// Le pieghe e la lucentezza restano quelle del corpo: normale e rugosita'
// sono le sue.

uniform sampler2D base : source_color, filter_linear_mipmap;
uniform sampler2D maschera : hint_default_white, filter_linear_mipmap;
uniform sampler2D normale : hint_normal, filter_linear_mipmap;
uniform sampler2D rugosita : hint_default_white, filter_linear_mipmap;
uniform vec4 tuta : source_color = vec4(0.2, 0.4, 1.0, 1.0);
uniform vec4 dettaglio : source_color = vec4(0.06, 0.06, 0.09, 1.0);

void fragment() {
	vec4 b = texture(base, UV);
	float pelle = texture(maschera, UV).r;
	// L'ombra cotta nella texture del corpo modella anche la tuta.
	float luce = dot(b.rgb, vec3(0.333));
	// Poca, di proposito: la texture del corpo disegna i muscoli, e una tuta li copre.
	float ombra = 0.82 + 0.3 * luce;
	// Le pieghe della normale disegnano cuciture scure sulla tuta.
	vec3 n = texture(normale, UV).rgb;
	float cucitura = smoothstep(0.35, 0.0, abs(n.r - 0.5) + abs(n.g - 0.5));
	vec3 colore_tuta = mix(dettaglio.rgb, tuta.rgb * ombra, clamp(cucitura + 0.75, 0.0, 1.0));
	ALBEDO = mix(colore_tuta, b.rgb, pelle);
	// Sotto la tuta le normali si appiattiscono: e' stoffa, non pelle dipinta.
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), n, pelle);
	ROUGHNESS = mix(0.5, texture(rugosita, UV).r, pelle);
	SPECULAR = mix(0.55, 0.4, pelle);
}
