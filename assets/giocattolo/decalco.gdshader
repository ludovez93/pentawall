shader_type spatial;

// Le decalcomanie dell'arena-giocattolo (tappa 10, blocco D, `tools/prepara_decalchi.py`).
// Il foglio ha due maschere: nel rosso la parte bianca della grafica, nel verde la
// grafica col contorno. Il colore del contorno arriva sui vertici: è quello dei bordi
// del muro su cui sta. Senza luce, come le scritte dell'arena di prima.
render_mode unshaded, cull_back;

uniform sampler2D foglio : hint_default_black, filter_linear_mipmap, repeat_disable;
// A ridosso della camera si diradano come il muro su cui stanno (`Arena.sfuma`), con lo
// stesso rumore dei materiali di Godot: così cadono gli stessi puntini.
uniform float sfuma_da = 0.0;
uniform float sfuma_a = 0.001;

void fragment() {
	float vicino = clamp(smoothstep(sfuma_da, sfuma_a, length(VERTEX)), 0.0, 1.0);
	const vec3 magia = vec3(0.06711056, 0.00583715, 52.9829189);
	if (vicino < 0.001 || vicino < fract(magia.z * fract(dot(FRAGCOORD.xy, magia.xy)))) {
		discard;
	}
	vec4 t = texture(foglio, UV);
	// I colori dei vertici sono scritti in sRGB: si portano nella luce lineare.
	vec3 c = COLOR.rgb;
	vec3 bordo = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
	// Il bianco resta sotto la soglia del bagliore, che è del dardo.
	ALBEDO = mix(bordo, vec3(0.86), smoothstep(0.3, 0.7, t.r));
	ALPHA = t.g;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
