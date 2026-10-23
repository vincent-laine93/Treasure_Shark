extends Area3D

# Un jerrican qui flotte. Quand le bateau passe dessus on récupère de l'essence.

@export var essence := 25.0

var temps = randf() * 10


func _ready():
	add_to_group("jerricans")
	body_entered.connect(_on_body_entered)


func _process(delta):
	temps += delta
	$Modele.position.y = 0.35 + sin(temps * 2) * 0.15
	$Modele.rotate_y(delta * 1.5)


func _on_body_entered(corps):
	if not corps is Bateau:
		return
	corps.carburant = min(corps.carburant + essence, Bateau.CARBURANT_MAX)
	Sons.jouer("SFX_Fuel_Collected")
	get_tree().get_first_node_in_group("joueur").annoncer("Jerrican récupéré : +" + str(int(essence)) + " d'essence !")
	get_tree().get_first_node_in_group("missions").jerrican_ramasse()
	queue_free()
