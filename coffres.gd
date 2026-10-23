extends Node3D

# On cache le gilet dans un des coffres au hasard


func _ready():
	var coffre = get_children().pick_random()
	coffre.contenu = "Gilet jaune"
