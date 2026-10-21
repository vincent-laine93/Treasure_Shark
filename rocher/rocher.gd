extends StaticBody3D

# Un rocher dans l'eau.
# Au lancement on remplace sa texture par roche.gdshader
# pour que tous les rochers aient la même couleur.

const SHADER := preload("res://rocher/roche.gdshader")

@export var luminance_moyenne := 0.1  # plus c'est grand, plus le rocher sera sombre


func _ready():
	add_to_group("rochers")  # le bateau perd une vie s'il tape dedans
	for maillage in find_children("*", "MeshInstance3D", true, false):
		for i in maillage.mesh.get_surface_count():
			var ancien = maillage.get_active_material(i)
			if ancien is BaseMaterial3D:
				maillage.set_surface_override_material(i, _nouveau_materiau(ancien))


func _nouveau_materiau(ancien: BaseMaterial3D) -> ShaderMaterial:
	var materiau := ShaderMaterial.new()
	materiau.shader = SHADER
	materiau.set_shader_parameter("texture_albedo", ancien.albedo_texture)
	materiau.set_shader_parameter("luminance_moyenne", luminance_moyenne)
	if ancien.normal_enabled and ancien.normal_texture != null:
		materiau.set_shader_parameter("texture_normal", ancien.normal_texture)
		materiau.set_shader_parameter("a_normal", true)
	return materiau
