extends Node3D

# Le requin fait des allers-retours entre deux points.
# S'il touche le bateau quand on est dedans, il attaque et on perd une vie.

@export var distance := 30.0
@export var vitesse := 4.0
@export var direction := Vector3(1, 0, 0)
@export var vitesse_virage := 3.0
@export var delai_entre_attaques := 3.0

var point_a: Vector3
var point_b: Vector3
var cible: Vector3
var attaque_en_cours := false
var recharge := 0.0

@onready var anim: AnimationPlayer = find_child("AnimationPlayer", true, false)
@onready var morsure: Area3D = $Morsure


func _ready():
	add_to_group("requins")  # sons.gd fait battre le cœur quand on est près
	Sons.ajouter_proximite(self, "requin")
	direction.y = 0
	point_a = global_position
	point_b = point_a + direction.normalized() * distance
	cible = point_b
	rotation.y = _angle_vers(cible)
	anim.get_animation("nage").loop_mode = Animation.LOOP_LINEAR
	anim.play("nage")


# angle pour que la tête du requin regarde vers le point
# (dans le modèle la tête est du côté +Z)
func _angle_vers(point: Vector3) -> float:
	var vers := point - global_position
	return atan2(vers.x, vers.z)


func _physics_process(delta):
	recharge -= delta
	if attaque_en_cours:
		return

	_verifier_morsure()

	# il tourne vers la cible et n'avance que quand il est presque en face
	# comme ça au bout il fait demi-tour sur place
	var angle := _angle_vers(cible)
	rotation.y = rotate_toward(rotation.y, angle, vitesse_virage * delta)
	if abs(angle_difference(rotation.y, angle)) < 0.3:
		global_position = global_position.move_toward(cible, vitesse * delta)

	# arrivé au bout : on repart dans l'autre sens
	if global_position.distance_to(cible) < 0.01:
		if cible == point_b:
			cible = point_a
		else:
			cible = point_b


func _verifier_morsure():
	if recharge > 0:
		return
	var joueur = get_tree().get_first_node_in_group("joueur")
	if joueur == null or not joueur.dans_bateau:
		return
	for corps in morsure.get_overlapping_bodies():
		if corps is Bateau:
			_attaquer(corps, joueur)
			return


func _attaquer(bateau: Bateau, joueur):
	attaque_en_cours = true
	rotation.y = _angle_vers(bateau.global_position)
	anim.play("attaque")
	Sons.jouer("requin_attaque")
	# de quel côté du bateau est le requin (le bateau regarde vers -Z)
	var cote := "droite"
	if bateau.to_local(global_position).x < 0:
		cote = "gauche"
	joueur.perdre_vie("Le requin t'a mordu !", cote)
	await anim.animation_finished
	anim.play("nage")
	recharge = delai_entre_attaques
	attaque_en_cours = false
