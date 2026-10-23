class_name Bateau
extends CharacterBody3D

const VITESSE_MAX := 15.0
const VITESSE_RECUL := 3.0
const ACCELERATION := 3.0
const RALENTISSEMENT := 2.0
const VITESSE_ROTATION := 5
const CARBURANT_MAX := 100.0

@export var carburant := 0.0  # le bateau commence à sec

var vitesse := 0.0
var pilote_actif := false
var en_attente := false  # pendant que Marcel parle au départ
var temps_avant_choc := 0.0
var essence_envoyee := -1
var temps_partie := 0.0
var position_volant := 0.0
var sens_volant := 1.0
var angle_levier := 0.0

@onready var camera = $CameraPilote
@onready var eau: ShaderMaterial = get_node("../Ocean").get_surface_override_material(0)
@onready var volant = find_child("Volant", true, false)
@onready var levier = find_child("Levier", true, false)


func _ready():
	motion_mode = MOTION_MODE_FLOATING  # pas de gravité
	creer_touches()
	camera.position = Vector3(0, 1.6, 1.2)
	camera.rotation_degrees = Vector3(-6, 0, 0)
	camera.fov = 80
	camera.near = 0.05
	angle_levier = levier.rotation.z
	# le volant est peut-être monté à l'envers dans le modèle
	if volant.global_basis.z.dot(global_basis.z) < 0:
		sens_volant = -1.0


func prendre_commandes():
	pilote_actif = true
	camera.make_current()


func quitter_commandes():
	pilote_actif = false
	vitesse = 0.0


func _physics_process(delta):
	temps_avant_choc -= delta
	temps_partie += delta

	var gaz = 0.0
	var direction = 0.0
	if pilote_actif and not en_attente:
		gaz = Input.get_axis("reculer", "avancer")
		direction = Input.get_axis("droite", "gauche")
		# avec la manette : la glissière pour la vitesse et le gouvernail pour tourner
		if SerialManager.avance() != 0:
			gaz = SerialManager.avance()
		if SerialManager.virage() != 0:
			direction = -SerialManager.virage()

	# le volant tourne avec le gouvernail
	position_volant = move_toward(position_volant, direction, 4 * delta)
	if SerialManager.manette_active and pilote_actif:
		position_volant = direction
	volant.rotation.z = deg_to_rad(120) * position_volant * sens_volant

	# le levier suit la vitesse du bateau
	if vitesse >= 0:
		levier.rotation.z = angle_levier + deg_to_rad(30) * vitesse / VITESSE_MAX
	else:
		levier.rotation.z = angle_levier + deg_to_rad(30) * vitesse / VITESSE_RECUL

	# essence
	if carburant <= 0:
		gaz = 0.0
	carburant = max(carburant - abs(gaz) * delta, 0.0)
	_envoyer_essence()

	# avancer / reculer
	if gaz > 0:
		vitesse = move_toward(vitesse, gaz * VITESSE_MAX, ACCELERATION * delta)
	elif gaz < 0:
		vitesse = move_toward(vitesse, gaz * VITESSE_RECUL, ACCELERATION * delta)
	else:
		vitesse = move_toward(vitesse, 0.0, RALENTISSEMENT * delta)

	# on ne peut tourner que si le bateau avance
	if abs(vitesse) > 0.2:
		var force = clamp(abs(vitesse) / 3.0, 0.3, 1.0)
		rotate_y(direction * VITESSE_ROTATION * force * sign(vitesse) * delta)

	velocity = -transform.basis.z * vitesse
	move_and_slide()
	global_position.y = 0.0  # le bateau reste sur l'eau

	# l'eau a besoin de savoir où est le bateau (pour ne pas passer dans la coque)
	var avant = -transform.basis.z
	eau.set_shader_parameter("position_bateau", global_position)
	eau.set_shader_parameter("avant_bateau", Vector2(avant.x, avant.z).normalized())

	# si on fonce dans quelque chose on s'arrête, sinon on glisse le long
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("rochers"):
			_choc_rocher(collision.get_position())
			break
		if (-transform.basis.z * sign(vitesse)).dot(collision.get_normal()) < -0.7:
			vitesse = 0.0
			break
		vitesse *= 0.98


# la jauge de la manette (on attend 1 s au début, le temps que la manette se remette à zéro)
func _envoyer_essence():
	if temps_partie < 1.0:
		return
	var pourcentage = ceili(carburant)
	if pourcentage != essence_envoyee:
		essence_envoyee = pourcentage
		SerialManager.envoyer_essence(pourcentage)


func _choc_rocher(point: Vector3):
	if abs(vitesse) < 2:
		vitesse = 0.0
		return
	if pilote_actif and temps_avant_choc <= 0:
		temps_avant_choc = 2.0
		var cote = "droite"
		if to_local(point).x < 0:
			cote = "gauche"
		Sons.jouer("SFX_Shark_Attack")
		get_node("../Joueur").perdre_vie("Ton bateau a heurté un rocher !", cote)
	# le bateau rebondit en arrière
	vitesse = -sign(vitesse) * 2


# ZQSD ou flèches pour bouger, E pour interagir, Espace pour sauter
static func creer_touches():
	var touches = {
		"avancer": [KEY_W, KEY_UP],
		"reculer": [KEY_S, KEY_DOWN],
		"gauche": [KEY_A, KEY_LEFT],
		"droite": [KEY_D, KEY_RIGHT],
		"interagir": [KEY_E],
		"sauter": [KEY_SPACE],
	}
	for action in touches:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for touche in touches[action]:
			var evenement = InputEventKey.new()
			evenement.physical_keycode = touche
			InputMap.action_add_event(action, evenement)
