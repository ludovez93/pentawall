shader_type spatial;

// Le decalcomanie dell'arena-giocattolo (tappa 10, blocco D, `tools/prepara_decalchi.py`).
// Il foglio ha due maschere: nel rosso la parte bianca della grafica, nel verde la
// grafica col contorno. Il colore del contorno arriva sui vertici: è quello dei bordi
// del muro su cui sta. Senza luce, come le scritte dell'arena di prima.
render_mode unshaded, cull_back;

uniform sampler2D foglio : hint_default_black, filter_linear_mipmap, repeat_disable;

void fragment() {
	vec4 t = texture(foglio, UV);
	// I colori dei vertici sono scritti in sRGB: si portano nella luce lineare.
	vec3 c = COLOR.rgb;
	vec3 bordo = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
	// Il bianco resta sotto la soglia del bagliore, che è del dardo.
	ALBEDO = mix(bordo, vec3(0.86), smoothstep(0.3, 0.7, t.r));
	ALPHA = t.g;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
