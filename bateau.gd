extends CharacterBody3D

const VITESSE_MAX := 15.0       # m/s en avant
const VITESSE_RECUL := 3.0     # m/s en arrière
const ACCELERATION := 3.0      # met ~3 s pour atteindre la vitesse max
const RALENTISSEMENT := 2.0    # le bateau ralentit tout seul quand on lâche
const VITESSE_ROTATION := 5  # vitesse de virage

# Caméra à la première personne : les yeux du pilote debout derrière le pupitre
# (repères du modèle : plancher ≈ 0 m, pare-brise ≈ 1,24 m, pupitre entre z = -1,2 et 0,3)
const CAMERA_POSITION := Vector3(0, 1.75, 1.2)  # (côté, hauteur des yeux, recul derrière le pupitre)
const CAMERA_INCLINAISON := -6.0                # en degrés : regarde légèrement vers l'eau devant
const CAMERA_CHAMP := 80.0                      # angle de vue en degrés

var vitesse := 0.0

@onready var camera: Camera3D = $CameraPilote


func _ready():
	# Mode prévu pour un objet sans sol (bateau, vaisseau) : pas de gravité ni de "sol"
	motion_mode = MOTION_MODE_FLOATING
	_creer_touches()
	camera.position = CAMERA_POSITION
	camera.rotation_degrees = Vector3(CAMERA_INCLINAISON, 0, 0)
	camera.fov = CAMERA_CHAMP
	camera.near = 0.05  # évite que le pare-brise tout proche soit "coupé"


func _physics_process(delta):
	# Avancer / reculer
	var gaz := Input.get_axis("reculer", "avancer")
	if gaz > 0:
		vitesse = move_toward(vitesse, VITESSE_MAX, ACCELERATION * delta)
	elif gaz < 0:
		vitesse = move_toward(vitesse, -VITESSE_RECUL, ACCELERATION * delta)
	else:
		vitesse = move_toward(vitesse, 0.0, RALENTISSEMENT * delta)

	# Tourner (seulement si le bateau bouge, comme un vrai bateau)
	var direction := Input.get_axis("droite", "gauche")
	if abs(vitesse) > 0.2:
		var force = clamp(abs(vitesse) / 3.0, 0.3, 1.0)
		rotate_y(direction * VITESSE_ROTATION * force * sign(vitesse) * delta)

	# Déplacement
	velocity = -transform.basis.z * vitesse
	velocity.y = 0.0
	move_and_slide()

	# Obstacle : arrêt net seulement si on le prend de face.
	# Si on le frotte de côté, on glisse le long en perdant un peu de vitesse
	# (sinon le bateau resterait collé et ne pourrait plus tourner).
	var sens_marche := -transform.basis.z * signf(vitesse)
	for i in get_slide_collision_count():
		var normale := get_slide_collision(i).get_normal()
		if sens_marche.dot(normale) < -0.7:
			vitesse = 0.0
			break
		vitesse *= 0.98


# Crée les actions avancer / reculer / gauche / droite si elles n'existent pas
# dans Projet > Paramètres du projet > Contrôles.
# Touches : ZQSD (clavier AZERTY) et flèches.
func _creer_touches():
	var touches := {
		"avancer": [KEY_W, KEY_UP],  # KEY_W physique = touche Z sur un clavier AZERTY
		"reculer": [KEY_S, KEY_DOWN],
		"gauche": [KEY_A, KEY_LEFT],  # KEY_A physique = touche Q sur un clavier AZERTY
		"droite": [KEY_D, KEY_RIGHT],
	}
	for action in touches:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in touches[action]:
			var evenement := InputEventKey.new()
			evenement.physical_keycode = code
			InputMap.action_add_event(action, evenement)
