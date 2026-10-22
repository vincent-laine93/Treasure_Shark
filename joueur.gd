extends CharacterBody3D

# Le joueur à pied, en vue à la première personne.
# Flèches haut/bas pour avancer/reculer, gauche/droite pour tourner.
# E sert à tout : ouvrir un coffre, poser le gilet sur la statue,
# descendre du bateau, faire le plein et monter dans le bateau.

const VITESSE_MARCHE := 5.0
const VITESSE_ROTATION := 2.5
const SAUT := 4.5
const HAUTEUR_CHUTE := -5.0  # si on tombe plus bas, on revient au départ

const DISTANCE_MONTER := 6.0
const DISTANCE_DESCENDRE := 6.0
const RECUL_BORD := 2.0  # on pose le joueur un peu plus loin que le bord de l'île
const HAUTEUR_TERRE := 0.3  # plus bas que ça, c'est sous l'eau
const DISTANCE_COFFRE := 6.0
const DISTANCE_STATUE := 7.0

const VIES_MAX := 3
const ZONE_MORTE_GOUVERNAIL := 3  # crans à tourner avant que le personnage commence à tourner
const DUREE_MESSAGE := 3.0
const OBJET_VICTOIRE := "Gilet jaune"
const OBJET_CARBURANT := "Jerrican"

# caméra de la fin, devant la statue
const RECUL_VUE_STATUE := 26.0
const HAUTEUR_VUE_STATUE := 9.0
const HAUTEUR_REGARD_STATUE := 11.0
const DUREE_VOL_CAMERA := 2.5

@export var bateau: Bateau

var dans_bateau := false
var a_gagne := false
var bloque := false  # pendant l'intro et les écrans de fin, on ne bouge pas
var gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var point_depart: Vector3
var inventaire: Array[String] = []
var vies := VIES_MAX
var temps_message := 0.0
var milieu_gouvernail := 0  # position du gouvernail qui veut dire "tout droit" à pied

# les textes affichés à l'écran
var aide: Label
var message: Label
var inventaire_texte: Label
var vies_texte: Label
var essence_texte: Label

@onready var camera: Camera3D = $Camera
@onready var forme: CollisionShape3D = $CollisionShape3D
@onready var statue: Node3D = get_node("../Ocean/IleStatue/StatueLiberte")
@onready var gilet_statue: Node3D = statue.get_node("GiletStatue")


func _ready():
	add_to_group("joueur")  # pour que les requins puissent nous trouver
	Bateau.creer_touches()
	point_depart = global_position
	camera.make_current()
	_creer_interface()
	SerialManager.nouvelle_partie()  # rallume les 3 LEDs de la manette
	milieu_gouvernail = SerialManager.gouvernail


func _process(delta):
	# le message disparaît tout seul au bout de quelques secondes
	if temps_message > 0:
		temps_message -= delta
		if temps_message <= 0:
			message.text = ""


func _physics_process(delta):
	if a_gagne or bloque:
		return

	if dans_bateau:
		global_position = bateau.global_position
	else:
		_marcher(delta)

	_interactions()
	_afficher_essence()


func _marcher(delta):
	if not is_on_floor():
		velocity.y -= gravite * delta
	elif Input.is_action_just_pressed("sauter"):
		velocity.y = SAUT

	var tourne := Input.get_axis("droite", "gauche")
	var marche := Input.get_axis("reculer", "avancer")
	# avec la manette : glissière pour avancer, gouvernail pour tourner
	# le gouvernail marche comme les flèches : tourné à droite du milieu on tourne à droite
	# à la même vitesse que la flèche, revenu au milieu on s'arrête
	if SerialManager.manette_active:
		var ecart := SerialManager.gouvernail - milieu_gouvernail
		if ecart >= ZONE_MORTE_GOUVERNAIL:
			tourne = -1.0
		elif ecart <= -ZONE_MORTE_GOUVERNAIL:
			tourne = 1.0
	if SerialManager.avance() != 0:
		marche = SerialManager.avance()

	rotate_y(tourne * VITESSE_ROTATION * delta)
	var direction := -transform.basis.z * marche
	velocity.x = direction.x * VITESSE_MARCHE
	velocity.z = direction.z * VITESSE_MARCHE
	move_and_slide()

	if global_position.y < HAUTEUR_CHUTE:
		global_position = point_depart
		velocity = Vector3.ZERO


# On regarde ce qu'il y a autour pour savoir ce que fait la touche E
func _interactions():
	var coffre = _coffre_proche()
	var pres_statue := false
	var pres_du_bateau := false
	var point_descente = null

	if dans_bateau:
		point_descente = _point_de_debarquement()
	else:
		pres_statue = _distance_a_plat(statue.global_position) < DISTANCE_STATUE
		pres_du_bateau = global_position.distance_to(bateau.global_position) < DISTANCE_MONTER

	var a_sec := bateau.carburant <= 0
	var a_le_gilet := inventaire.has(OBJET_VICTOIRE)
	var a_le_jerrican := inventaire.has(OBJET_CARBURANT)
	var appui := Input.is_action_just_pressed("interagir")

	if coffre != null:
		aide.text = "E : ouvrir le coffre"
		if appui:
			_ouvrir(coffre)

	elif pres_statue:
		if a_le_gilet:
			aide.text = "E : mettre le gilet jaune sur la statue"
			if appui:
				_gagner()
		else:
			aide.text = "Il te faut le gilet jaune, cherche dans les coffres !"

	elif point_descente != null:
		aide.text = "E : descendre sur l'île"
		if appui:
			_descendre(point_descente)

	elif pres_du_bateau and a_sec:
		if a_le_jerrican:
			aide.text = "E : faire le plein avec le jerrican"
			if appui:
				_faire_le_plein()
		else:
			aide.text = "Le bateau est à sec, trouve un jerrican sur l'île !"

	elif pres_du_bateau:
		aide.text = "E : monter dans le bateau"
		if appui:
			_monter()

	else:
		aide.text = ""


func _distance_a_plat(point: Vector3) -> float:
	var ecart := point - global_position
	ecart.y = 0
	return ecart.length()


func _regarder_vers(cible: Vector3):
	cible.y = global_position.y
	if global_position.distance_to(cible) > 0.01:
		look_at(cible)
	camera.rotation.x = 0


# ---------- bateau ----------

func _monter():
	_mission_faite("bateau")
	dans_bateau = true
	forme.disabled = true
	velocity = Vector3.ZERO
	bateau.prendre_commandes()


func _descendre(point: Vector3):
	# le gouvernail a servi à piloter : sa position actuelle devient le nouveau milieu
	milieu_gouvernail = SerialManager.gouvernail
	dans_bateau = false
	bateau.quitter_commandes()
	global_position = point
	forme.disabled = false
	# on tourne le dos au bateau
	_regarder_vers(point * 2 - bateau.global_position)
	camera.make_current()


func _faire_le_plein():
	inventaire.erase(OBJET_CARBURANT)
	_afficher_inventaire()
	bateau.faire_le_plein()
	_mission_faite("plein")
	_afficher_message("Le plein est fait ! Tu peux monter dans le bateau.")


# Cherche un endroit pour descendre autour du bateau.
# On essaie plusieurs directions, du plus près au plus loin.
# Il faut de la terre hors de l'eau au bord et un peu plus loin,
# sinon on tomberait dans l'eau ou dans un lagon.
func _point_de_debarquement():
	var distance := 1.0
	while distance <= DISTANCE_DESCENDRE:
		for i in 16:
			var direction := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 16)
			var bord = _sol_ile(bateau.global_position + direction * distance)
			var plus_loin = _sol_ile(bateau.global_position + direction * (distance + RECUL_BORD))
			if bord != null and plus_loin != null:
				return plus_loin + Vector3.UP * 0.1
		distance += 0.5
	return null


# Renvoie le sol d'une île à cet endroit, ou null s'il n'y a pas de terre
func _sol_ile(point: Vector3):
	var rayon := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 30, point + Vector3.DOWN * 5)
	rayon.exclude = [bateau.get_rid(), get_rid()]
	var touche := get_world_3d().direct_space_state.intersect_ray(rayon)
	if touche.is_empty():
		return null
	if not touche.collider.is_in_group("iles"):
		return null
	if touche.position.y < HAUTEUR_TERRE:
		return null
	return touche.position


# est-ce qu'on peut descendre du bateau ici ?
func peut_descendre() -> bool:
	return _point_de_debarquement() != null


# prévient missions.gd qu'on vient de faire quelque chose
func _mission_faite(id: String):
	var missions = get_tree().get_first_node_in_group("missions")
	if missions != null:
		missions.valider(id)


# ---------- coffres ----------

func _coffre_proche():
	var plus_proche = null
	var meilleure_distance := DISTANCE_COFFRE
	for coffre in get_tree().get_nodes_in_group("coffres"):
		if coffre.ouvert:
			continue
		var distance := _distance_a_plat(coffre.global_position)
		if distance < meilleure_distance:
			meilleure_distance = distance
			plus_proche = coffre
	return plus_proche


func _ouvrir(coffre):
	var objet: String = coffre.ouvrir()
	if objet != "":
		inventaire.append(objet)
		_afficher_inventaire()
		_afficher_message("Tu as trouvé : " + objet + " !")
	# missions.gd s'occupe des répliques de Marcel et des coffres vides
	var missions = get_tree().get_first_node_in_group("missions")
	if missions != null:
		missions.coffre_ouvert(objet)


# ---------- vies et victoire ----------

# cote : "gauche" ou "droite", pour faire vibrer le bon côté de la manette
func perdre_vie(raison := "Le requin t'a mordu !", cote := "gauche"):
	if cote == "gauche":
		SerialManager.choc_gauche()
	else:
		SerialManager.choc_droit()

	vies -= 1
	if vies < 0:
		vies = 0
	_afficher_vies()

	if vies == 0:
		# on attend un peu pour voir l'attaque avant le game over
		await get_tree().create_timer(1.2).timeout
		get_node("../Recommencer").game_over()
	elif vies == 1:
		_afficher_message(raison + " Plus que 1 vie")
	else:
		_afficher_message(raison + " Plus que " + str(vies) + " vies")


func _gagner():
	a_gagne = true
	aide.text = ""
	inventaire.erase(OBJET_VICTOIRE)
	_afficher_inventaire()

	var vue = await _filmer_statue_de_face()

	# le gilet apparaît sur la statue en grandissant
	gilet_statue.scale = Vector3.ONE * 0.01
	gilet_statue.show()
	var tween := create_tween()
	tween.tween_property(gilet_statue, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

	await get_tree().create_timer(0.7).timeout
	get_tree().get_first_node_in_group("missions").lancer_epilogue(vue)


# Une nouvelle caméra part de nos yeux et va se placer devant la statue.
# La statue regarde vers son axe Z.
func _filmer_statue_de_face():
	var vue := Camera3D.new()
	vue.fov = camera.fov
	get_parent().add_child(vue)
	vue.global_transform = camera.global_transform
	vue.make_current()

	var devant := statue.global_transform.basis.z
	devant.y = 0
	devant = devant.normalized()

	var pied := statue.global_position
	var position_finale := pied + devant * RECUL_VUE_STATUE + Vector3.UP * HAUTEUR_VUE_STATUE
	var arrivee := Transform3D(Basis(), position_finale)
	arrivee = arrivee.looking_at(pied + Vector3.UP * HAUTEUR_REGARD_STATUE)

	var tween := create_tween()
	tween.tween_property(vue, "global_transform", arrivee, DUREE_VOL_CAMERA).set_trans(Tween.TRANS_SINE)
	await tween.finished
	return vue


# ---------- affichage ----------

# pour que les autres objets (jerricans...) puissent afficher un message
func annoncer(texte: String):
	_afficher_message(texte)


func _afficher_message(texte: String):
	message.text = texte
	temps_message = DUREE_MESSAGE


func _afficher_inventaire():
	if inventaire.is_empty():
		inventaire_texte.text = "Inventaire : vide"
	else:
		inventaire_texte.text = "Inventaire : " + ", ".join(inventaire)


func _afficher_vies():
	vies_texte.text = "Vies : " + str(vies) + " / " + str(VIES_MAX)


func _afficher_essence():
	essence_texte.text = "Essence : " + str(ceili(bateau.carburant)) + " / " + str(int(Bateau.CARBURANT_MAX))
	# presque vide : l'essence passe dans la couleur secondaire et clignote
	if bateau.carburant < 25:
		essence_texte.add_theme_color_override("font_color", Couleurs.SECONDAIRE)
		essence_texte.modulate.a = 0.4 + 0.6 * abs(sin(Time.get_ticks_msec() / 150.0))
	else:
		essence_texte.add_theme_color_override("font_color", Couleurs.IMPORTANTE)
		essence_texte.modulate.a = 1.0


func _creer_interface():
	var calque := CanvasLayer.new()
	add_child(calque)

	var viseur := _creer_texte(calque, 32, Color.WHITE)
	viseur.text = "+"
	viseur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viseur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	viseur.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	aide = _creer_texte(calque, 40, Color.WHITE)
	aide.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	aide.offset_top = -140
	aide.offset_bottom = -80
	aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	message = _creer_texte(calque, 56, Couleurs.IMPORTANTE)
	message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	message.offset_top = 120
	message.offset_bottom = 200
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	inventaire_texte = _creer_texte(calque, 32, Color.WHITE)
	inventaire_texte.position = Vector2(30, 20)

	vies_texte = _creer_texte(calque, 32, Couleurs.IMPORTANTE)
	vies_texte.position = Vector2(30, 65)

	essence_texte = _creer_texte(calque, 32, Couleurs.IMPORTANTE)
	essence_texte.position = Vector2(30, 110)

	_afficher_inventaire()
	_afficher_vies()


func _creer_texte(calque: CanvasLayer, taille: int, couleur: Color) -> Label:
	var texte := Label.new()
	texte.add_theme_font_size_override("font_size", taille)
	texte.add_theme_color_override("font_color", couleur)
	texte.add_theme_color_override("font_outline_color", Couleurs.FONCEE)
	texte.add_theme_constant_override("outline_size", 8)
	calque.add_child(texte)
	return texte
