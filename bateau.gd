class_name Bateau
extends CharacterBody3D

const VITESSE_MAX := 15.0
const VITESSE_RECUL := 3.0
const ACCELERATION := 3.0
const RALENTISSEMENT := 2.0  # le bateau ralentit tout seul quand on lâche
const VITESSE_ROTATION := 5

# chocs contre les rochers
const VITESSE_CHOC := 2.0  # en dessous on ne perd pas de vie
const DELAI_CHOC := 2.0
const RECUL_CHOC := 2.0

# essence
const CARBURANT_MAX := 100.0
const CONSOMMATION := 1.0  # par seconde à fond : un plein dure 100 s de gaz

# caméra du pilote
const CAMERA_POSITION := Vector3(0, 1.6, 1.2)
const CAMERA_INCLINAISON := -6.0
const CAMERA_CHAMP := 80.0

@export var carburant := 0.0  # le bateau commence à sec

var vitesse := 0.0
var pilote_actif := false
var recharge_choc := 0.0
var essence_envoyee := -1  # dernière valeur envoyée à la jauge de la manette
var temps_partie := 0.0

@onready var camera: Camera3D = $CameraPilote
@onready var materiau_eau: ShaderMaterial = get_node("../Ocean").get_surface_override_material(0)


func _ready():
	# pas de gravité pour un bateau
	motion_mode = MOTION_MODE_FLOATING
	creer_touches()
	camera.position = CAMERA_POSITION
	camera.rotation_degrees = Vector3(CAMERA_INCLINAISON, 0, 0)
	camera.fov = CAMERA_CHAMP
	camera.near = 0.05


func faire_le_plein():
	carburant = CARBURANT_MAX


# la jauge de la manette suit l'essence (on n'envoie que quand le chiffre change)
func _envoyer_essence():
	# au début on laisse 1 s à la manette pour remettre sa jauge à zéro (commande Z)
	if temps_partie < 1.0:
		return
	var pourcentage := ceili(carburant / CARBURANT_MAX * 100)
	if pourcentage != essence_envoyee:
		essence_envoyee = pourcentage
		SerialManager.envoyer_essence(pourcentage)


func prendre_commandes():
	pilote_actif = true
	camera.rotation_degrees = Vector3(CAMERA_INCLINAISON, 0, 0)
	camera.make_current()


func quitter_commandes():
	pilote_actif = false
	vitesse = 0.0


func _physics_process(delta):
	recharge_choc -= delta
	temps_partie += delta

	var gaz := 0.0
	var direction := 0.0
	if pilote_actif:
		gaz = Input.get_axis("reculer", "avancer")
		direction = Input.get_axis("droite", "gauche")
		# avec la manette : glissière pour la vitesse, gouvernail pour tourner
		if SerialManager.avance() != 0:
			gaz = SerialManager.avance()
		if SerialManager.virage() != 0:
			direction = -SerialManager.virage()

	# plus d'essence = plus de moteur
	if carburant <= 0:
		gaz = 0.0
	carburant -= abs(gaz) * CONSOMMATION * delta
	if carburant < 0:
		carburant = 0.0
	_envoyer_essence()

	# Avancer / reculer
	# gaz va de -1 à 1 : au clavier c'est tout ou rien, avec la glissière on peut aller moins vite
	if gaz > 0:
		vitesse = move_toward(vitesse, gaz * VITESSE_MAX, ACCELERATION * delta)
	elif gaz < 0:
		vitesse = move_toward(vitesse, gaz * VITESSE_RECUL, ACCELERATION * delta)
	else:
		vitesse = move_toward(vitesse, 0.0, RALENTISSEMENT * delta)

	# Tourner (seulement si le bateau bouge, comme un vrai bateau)
	if abs(vitesse) > 0.2:
		var force = clamp(abs(vitesse) / 3.0, 0.3, 1.0)
		rotate_y(direction * VITESSE_ROTATION * force * sign(vitesse) * delta)

	# Déplacement
	velocity = -transform.basis.z * vitesse
	velocity.y = 0.0
	move_and_slide()
	# le bateau reste toujours sur l'eau : sinon en frottant le fond d'une île il glisse vers le haut
	global_position.y = 0.0

	# on dit à l'eau où est le bateau (eau calme autour et pas d'eau dans la coque)
	var avant := -transform.basis.z
	materiau_eau.set_shader_parameter("position_bateau", global_position)
	materiau_eau.set_shader_parameter("avant_bateau", Vector2(avant.x, avant.z).normalized())

	# Obstacles : on s'arrête si on fonce dedans, sinon on glisse le long
	var sens_marche := -transform.basis.z * signf(vitesse)
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_collider().is_in_group("rochers"):
			_choc_rocher(collision.get_position())
			break
		if sens_marche.dot(collision.get_normal()) < -0.7:
			vitesse = 0.0
			break
		vitesse *= 0.98


func _choc_rocher(point_choc: Vector3):
	if abs(vitesse) < VITESSE_CHOC:
		vitesse = 0.0
		return
	if pilote_actif and recharge_choc <= 0:
		recharge_choc = DELAI_CHOC
		# le bateau regarde vers -Z, donc x négatif = côté gauche
		var cote := "droite"
		if to_local(point_choc).x < 0:
			cote = "gauche"
		get_tree().get_first_node_in_group("joueur").perdre_vie("Ton bateau a heurté un rocher !", cote)
	# le bateau rebondit en arrière
	vitesse = -signf(vitesse) * RECUL_CHOC


# Crée les touches si elles n'existent pas déjà
# ZQSD ou flèches pour bouger, E pour interagir, Espace pour sauter
static func creer_touches():
	var touches := {
		"avancer": [KEY_W, KEY_UP],  # KEY_W = touche Z sur un clavier AZERTY
		"reculer": [KEY_S, KEY_DOWN],
		"gauche": [KEY_A, KEY_LEFT],  # KEY_A = touche Q sur un clavier AZERTY
		"droite": [KEY_D, KEY_RIGHT],
		"interagir": [KEY_E],
		"sauter": [KEY_SPACE],
	}
	for action in touches:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in touches[action]:
			var evenement := InputEventKey.new()
			evenement.physical_keycode = code
			InputMap.action_add_event(action, evenement)
