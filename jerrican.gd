extends Area3D

# Un jerrican qui flotte sur l'eau.
# Quand le bateau passe dessus, il disparaît et on récupère de l'essence.

@export var essence := 25.0

var temps := randf() * 10.0  # pour qu'ils ne bougent pas tous en même temps

@onready var modele: Node3D = $Modele


func _ready():
	body_entered.connect(_on_body_entered)
	Sons.ajouter_proximite(self, "essence")


func _process(delta):
	# il monte et descend sur les vagues et tourne doucement pour qu'on le voie
	temps += delta
	modele.position.y = 0.35 + sin(temps * 2.0) * 0.15
	modele.rotate_y(delta * 1.5)


func _on_body_entered(corps):
	if not corps is Bateau:
		return
	corps.carburant = min(corps.carburant + essence, Bateau.CARBURANT_MAX)
	Sons.jouer("essence_ramassee")
	var joueur = get_tree().get_first_node_in_group("joueur")
	joueur.annoncer("Jerrican récupéré : +" + str(int(essence)) + " d'essence !")
	var missions = get_tree().get_first_node_in_group("missions")
	if missions != null:
		missions.jerrican_ramasse()
	queue_free()
