extends CharacterBody3D

# Le joueur à pied, vue à la première personne.
# Flèches ou ZQSD pour bouger, E pour tout le reste.
# Avec la manette : le joystick pour avancer/reculer et tourner (le gouvernail tourne aussi).

const VITESSE_MARCHE := 5.0
const VITESSE_ROTATION := 2.5
const SAUT := 4.5
const VIES_MAX := 3

@export var bateau: Bateau

var dans_bateau := false
var a_gagne := false
var bloque := false  # pendant l'intro et les cinématiques
var gravite = ProjectSettings.get_setting("physics/3d/default_gravity")
var point_depart: Vector3
var inventaire = []
var vies := VIES_MAX
var temps_message := 0.0
var milieu_gouvernail := 0  # position du gouvernail quand on va tout droit

var aide: Label
var message: Label
var inventaire_texte: Label
var vies_texte: Label
var essence_texte: Label

@onready var camera = $Camera
@onready var forme = $CollisionShape3D
@onready var statue = get_node("../Ocean/IleStatue/StatueLiberte")
@onready var gilet_statue = statue.get_node("GiletStatue")
@onready var missions = get_node("../Missions")


func _ready():
	add_to_group("joueur")
	Bateau.creer_touches()
	point_depart = global_position
	camera.make_current()
	_creer_interface()
	SerialManager.nouvelle_partie()
	milieu_gouvernail = SerialManager.gouvernail


func _process(delta):
	# le message s'efface au bout de 3 secondes
	if temps_message > 0:
		temps_message -= delta
		if temps_message <= 0:
			message.text = ""


func _physics_process(delta):
	if a_gagne or bloque:
		aide.text = ""
		return
	if dans_bateau:
		global_position = bateau.global_position
	else:
		_marcher(delta)
	_touche_e()
	_afficher_essence()


func _marcher(delta):
	if not is_on_floor():
		velocity.y -= gravite * delta
	elif Input.is_action_just_pressed("sauter"):
		velocity.y = SAUT

	var tourne = Input.get_axis("droite", "gauche")
	var pas = Vector2(0, Input.get_axis("reculer", "avancer"))

	# avec la manette, on tourne quand le gouvernail est à plus de 3 crans du milieu
	if SerialManager.manette_active:
		var ecart = SerialManager.gouvernail - milieu_gouvernail
		if ecart >= 3:
			tourne = -1.0
		elif ecart <= -3:
			tourne = 1.0
	# le joystick : devant/derrière pour avancer/reculer, les côtés pour tourner
	var joystick = SerialManager.deplacement()
	if joystick != Vector2.ZERO:
		tourne = joystick.x
		pas = Vector2(0, joystick.y)

	rotate_y(tourne * VITESSE_ROTATION * delta)
	var devant = -global_basis.z
	var droite = global_basis.x
	var direction = devant * pas.y + droite * pas.x
	velocity.x = direction.x * VITESSE_MARCHE
	velocity.z = direction.z * VITESSE_MARCHE
	move_and_slide()

	# si on tombe dans l'eau on revient au départ
	if global_position.y < -5:
		global_position = point_depart
		velocity = Vector3.ZERO


# ce que fait la touche E selon où on est
func _touche_e():
	var appui = Input.is_action_just_pressed("interagir")
	var coffre = _coffre_proche()
	var sur_ile_statue = missions.distance_statue(self) < 40
	var pres_statue = not dans_bateau and missions.distance_statue(self) < 7
	var pres_du_bateau = not dans_bateau and global_position.distance_to(bateau.global_position) < 6
	var a_sec = bateau.carburant <= 0
	var point_descente = null
	if dans_bateau:
		point_descente = point_de_debarquement()

	# sur l'île de la statue on attend que Marcel ait fini de parler
	if sur_ile_statue and missions.sous_titres.est_en_train_de_parler():
		aide.text = ""
		return

	if coffre != null:
		aide.text = "E : ouvrir le coffre"
		if appui:
			_ouvrir(coffre)
	elif pres_statue:
		if inventaire.has("Gilet jaune"):
			aide.text = "E : mettre le gilet jaune sur la statue"
			if appui:
				_gagner()
		else:
			aide.text = "Il te faut le gilet jaune, cherche dans les coffres !"
	elif point_descente != null:
		aide.text = "E : descendre sur l'île"
		if appui:
			_descendre(point_descente)
	elif pres_du_bateau and a_sec and sur_ile_statue:
		aide.text = ""  # le bateau est à sec à la statue, c'est normal
	elif pres_du_bateau and a_sec:
		if inventaire.has("Jerrican"):
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


# ---------- bateau ----------

func _monter():
	missions.valider("bateau")
	dans_bateau = true
	forme.disabled = true
	velocity = Vector3.ZERO
	bateau.prendre_commandes()


func _descendre(point: Vector3):
	milieu_gouvernail = SerialManager.gouvernail
	dans_bateau = false
	bateau.quitter_commandes()
	global_position = point
	forme.disabled = false
	# on tourne le dos au bateau
	var cible = point * 2 - bateau.global_position
	cible.y = global_position.y
	look_at(cible)
	camera.make_current()


func _faire_le_plein():
	inventaire.erase("Jerrican")
	_afficher_inventaire()
	bateau.carburant = Bateau.CARBURANT_MAX
	Sons.jouer("SFX_Fuel_Collected")
	missions.valider("plein")
	_afficher_message("Le plein est fait ! Tu peux monter dans le bateau.")


# On cherche un endroit pour descendre tout autour du bateau.
# Il faut de la terre au bord et encore 2 m plus loin, sinon on tombe à l'eau.
func point_de_debarquement():
	var distance = 1.0
	while distance <= 6:
		for i in 16:
			var direction = Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 16)
			var bord = _sol(bateau.global_position + direction * distance)
			var plus_loin = _sol(bateau.global_position + direction * (distance + 2))
			if bord != null and plus_loin != null:
				return plus_loin + Vector3.UP * 0.1
		distance += 0.5
	return null


func peut_descendre() -> bool:
	return point_de_debarquement() != null


# renvoie le sol de l'île à cet endroit, ou null si c'est de l'eau
func _sol(point: Vector3):
	var rayon = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 30, point + Vector3.DOWN * 5)
	rayon.exclude = [bateau.get_rid(), get_rid()]
	var touche = get_world_3d().direct_space_state.intersect_ray(rayon)
	if touche.is_empty() or not touche.collider.is_in_group("iles") or touche.position.y < 0.3:
		return null
	return touche.position


# ---------- coffres ----------

func _coffre_proche():
	var plus_proche = null
	var meilleure_distance = 6.0
	for coffre in get_tree().get_nodes_in_group("coffres"):
		var ecart = coffre.global_position - global_position
		ecart.y = 0
		if not coffre.ouvert and ecart.length() < meilleure_distance:
			meilleure_distance = ecart.length()
			plus_proche = coffre
	return plus_proche


func _ouvrir(coffre):
	var objet = coffre.ouvrir()
	if objet != "":
		inventaire.append(objet)
		_afficher_inventaire()
		_afficher_message("Tu as trouvé : " + objet + " !")
	missions.coffre_ouvert(objet)


# ---------- vies et victoire ----------

func perdre_vie(raison: String, cote: String):
	if cote == "gauche":
		SerialManager.choc_gauche()
	else:
		SerialManager.choc_droit()

	vies = max(vies - 1, 0)
	_afficher_vies()
	if vies == 0:
		await get_tree().create_timer(1.2).timeout
		get_node("../Recommencer").game_over()
	elif vies == 1:
		_afficher_message(raison + " Plus que 1 vie")
	else:
		_afficher_message(raison + " Plus que " + str(vies) + " vies")


func _gagner():
	a_gagne = true
	Sons.couper_tout(get_tree())
	missions.dissiper_brouillard()
	aide.text = ""
	inventaire.erase("Gilet jaune")
	_afficher_inventaire()

	# une caméra part de nos yeux et va devant la statue
	var vue = Camera3D.new()
	vue.fov = camera.fov
	get_parent().add_child(vue)
	vue.global_transform = camera.global_transform
	vue.make_current()
	var devant = statue.global_basis.z
	devant.y = 0
	var pied = statue.global_position
	var arrivee = Transform3D(Basis(), pied + devant.normalized() * 26 + Vector3.UP * 9)
	arrivee = arrivee.looking_at(pied + Vector3.UP * 11)
	var tween = create_tween()
	tween.tween_property(vue, "global_transform", arrivee, 2.5).set_trans(Tween.TRANS_SINE)
	await tween.finished

	# le gilet apparaît sur la statue
	gilet_statue.scale = Vector3.ONE * 0.01
	gilet_statue.show()
	tween = create_tween()
	tween.tween_property(gilet_statue, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(0.7).timeout
	missions.lancer_epilogue(vue)


# ---------- affichage ----------

func annoncer(texte: String):
	_afficher_message(texte)


func _afficher_message(texte: String):
	message.text = texte
	temps_message = 3.0


func _afficher_inventaire():
	if inventaire.is_empty():
		inventaire_texte.text = "Inventaire : vide"
	else:
		inventaire_texte.text = "Inventaire : " + ", ".join(inventaire)


func _afficher_vies():
	vies_texte.text = "Vies : " + str(vies) + " / " + str(VIES_MAX)


func _afficher_essence():
	essence_texte.text = "Essence : " + str(ceili(bateau.carburant)) + " / 100"
	# presque plus d'essence : le texte clignote
	if bateau.carburant < 25:
		essence_texte.add_theme_color_override("font_color", Couleurs.SECONDAIRE)
		essence_texte.modulate.a = 0.4 + 0.6 * abs(sin(Time.get_ticks_msec() / 150.0))
	else:
		essence_texte.add_theme_color_override("font_color", Couleurs.IMPORTANTE)
		essence_texte.modulate.a = 1.0


func _creer_interface():
	var calque = CanvasLayer.new()
	add_child(calque)

	var viseur = _creer_texte(calque, 32, Color.WHITE)
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


func _creer_texte(calque, taille, couleur) -> Label:
	var texte = Label.new()
	texte.add_theme_font_size_override("font_size", taille)
	texte.add_theme_color_override("font_color", couleur)
	texte.add_theme_color_override("font_outline_color", Couleurs.FONCEE)
	texte.add_theme_constant_override("outline_size", 8)
	calque.add_child(texte)
	return texte
