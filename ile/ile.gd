extends StaticBody3D

# Une île du fichier iles.glb (les autres îles du fichier sont cachées).
# Le sol a déjà sa collision. Ici on en ajoute aux palmiers et aux roches
# pour ne pas passer à travers.

const DECOR_SOLIDE := ["palma tronco", "Rocher", "Box"]


func _ready():
	var iles = $Modele.get_child(0).get_children()
	for ile in iles:
		if not ile.visible:
			continue
		for objet in ile.find_children("*", "MeshInstance3D", true, false):
			if _flotte(objet.name):
				objet.queue_free()
			elif _est_solide(objet.name):
				_ajouter_collision(objet)


# les deux coffres en bois de l'île sud-est qui flottent au-dessus de l'eau
func _flotte(nom: String) -> bool:
	nom = nom.replace("_", "").replace(".", "")
	return "legno" in nom and (nom.begins_with("Cube000") or nom.begins_with("Cube001"))


func _est_solide(nom: String) -> bool:
	for debut in DECOR_SOLIDE:
		if nom.begins_with(debut):
			return true
	return false


func _ajouter_collision(objet: MeshInstance3D):
	var forme_objet: ConvexPolygonShape3D = objet.mesh.create_convex_shape(true, true)

	# on déplace les points de la forme à la place de l'objet
	# (mettre la place sur le nœud ne marche pas bien avec certaines échelles)
	var place := global_transform.affine_inverse() * objet.global_transform
	var points := PackedVector3Array()
	for p in forme_objet.points:
		points.append(place * p)

	var forme := ConvexPolygonShape3D.new()
	forme.points = points
	var collision := CollisionShape3D.new()
	collision.shape = forme
	add_child(collision)
