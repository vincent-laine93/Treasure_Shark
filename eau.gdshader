shader_type spatial;

uniform vec4 couleur_profonde : source_color = vec4(0.01, 0.12, 0.25, 1.0);
uniform vec4 couleur_claire : source_color = vec4(0.0, 0.45, 0.55, 1.0);
uniform vec4 couleur_ciel : source_color = vec4(0.65, 0.85, 1.0, 1.0);
uniform vec4 couleur_ecume : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform float hauteur_vagues = 0.35;
uniform float vitesse = 1.0;
uniform float ecume = 0.6;
uniform vec3 position_bateau = vec3(0.0);
uniform vec2 avant_bateau = vec2(0.0, -1.0);
// demi-largeur et demi-longueur de la coque : pas d'eau dedans
uniform vec2 taille_coque = vec2(1.15, 2.85);
uniform sampler2D normale1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normale2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D bruit_ecume : filter_linear_mipmap, repeat_enable;

varying float h;
varying vec3 pos_monde;

// Une vague : direction, longueur (m), force. Ajoute sa hauteur et renvoie sa pente.
vec2 vague(vec2 p, vec2 dir, float longueur, float amp, float t, inout float hh) {
	float k = 6.2832 / longueur;
	float vit = sqrt(9.8 / k);
	vec2 d = normalize(dir);
	float f = k * (dot(d, p) - vit * t);
	hh += amp * sin(f);
	return d * k * amp * cos(f);
}

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME * vitesse;
	float hh = 0.0;
	vec2 pente = vec2(0.0);
	pente += vague(p, vec2(1.0, 0.3), 40.0, 1.0, t, hh);
	pente += vague(p, vec2(0.6, 1.0), 25.0, 0.6, t, hh);
	pente += vague(p, vec2(-0.4, 0.9), 15.0, 0.35, t, hh);
	// eau calme autour du bateau
	float calme = smoothstep(6.0, 16.0, distance(p, position_bateau.xz));
	hh *= calme;
	pente *= calme;
	h = hh;
	VERTEX.y += hh * hauteur_vagues;
	NORMAL = normalize(vec3(-pente.x * hauteur_vagues, 1.0, -pente.y * hauteur_vagues));
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = pos_monde.xz;
	// on ne dessine pas l'eau dans la coque du bateau
	vec2 d = p - position_bateau.xz;
	float en_long = dot(d, avant_bateau);
	float en_large = dot(d, vec2(-avant_bateau.y, avant_bateau.x));
	if (abs(en_large) < taille_coque.x && abs(en_long) < taille_coque.y) {
		discard;
	}
	// petites rides
	vec2 uv1 = p * 0.06 + vec2(TIME * 0.03, TIME * 0.02);
	vec2 uv2 = p * 0.11 - vec2(TIME * 0.02, TIME * 0.035);
	NORMAL_MAP = mix(texture(normale1, uv1).rgb, texture(normale2, uv2).rgb, 0.5);
	NORMAL_MAP_DEPTH = 1.0;
	// couleur : creux foncés, crêtes claires, reflet du ciel au loin
	float reflet = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 eau = mix(couleur_profonde.rgb, couleur_claire.rgb, clamp(0.5 + h * 0.35, 0.0, 1.0));
	eau = mix(eau, couleur_ciel.rgb, reflet * 0.6);
	// écume sur les crêtes
	float e = smoothstep(0.9, 1.6, h + texture(bruit_ecume, p * 0.08 + TIME * 0.01).r * 0.8) * ecume;
	ALBEDO = mix(eau, couleur_ecume.rgb, e);
	ROUGHNESS = mix(0.02, 0.6, e);
	SPECULAR = 0.5;
}