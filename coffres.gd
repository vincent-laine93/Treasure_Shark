extends Node3D

# Au début de la partie, on met le gilet dans un des coffres au hasard.

@export var objet_cache := "Gilet jaune"


func _ready():
	var coffre = get_children().pick_random()
	coffre.contenu = objet_cache
