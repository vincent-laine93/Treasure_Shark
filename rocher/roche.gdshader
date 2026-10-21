shader_type spatial;

// Shader pour tous les rochers : on garde le relief de la texture
// mais on met la même couleur de pierre partout.
// Près de l'eau la pierre est plus sombre et un peu verte.

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool a_normal = false;

uniform vec4 teinte : source_color = vec4(0.4, 0.385, 0.36, 1.0);
uniform float luminance_moyenne = 0.1;
uniform float contraste = 0.8;

uniform float hauteur_mouillee = 1.2;
uniform vec4 couleur_algues : source_color = vec4(0.22, 0.3, 0.2, 1.0);

varying float hauteur_monde;

void vertex() {
	hauteur_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	// on prend juste la luminosité de la texture, pas sa couleur
	vec3 c = texture(texture_albedo, UV).rgb;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722)) / max(luminance_moyenne, 0.001);
	l = clamp(mix(1.0, l, contraste), 0.15, 2.2);
	vec3 pierre = teinte.rgb * l;

	// partie mouillée près de l'eau
	float mouille = 1.0 - smoothstep(0.0, hauteur_mouillee, hauteur_monde);
	pierre = mix(pierre, pierre * couleur_algues.rgb * 1.6, mouille * 0.7);

	ALBEDO = pierre;
	ROUGHNESS = mix(0.92, 0.35, mouille);
	if (a_normal) {
		NORMAL_MAP = texture(texture_normal, UV).rgb;
	}
}
