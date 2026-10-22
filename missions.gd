extends Node

# Le déroulement de la partie, en suivant le script (les textes sont dans scenario.gd) :
# l'intro, les missions dans l'ordre, les répliques de Marcel,
# le game over "panne sèche" et la fin.
# La mission en cours est affichée en haut à droite.

const DISTANCE_SORTIE_CABANE := 6.0
const DISTANCE_ARRIVEE_STATUE := 40.0
const DISTANCE_MARCHE_STATUE := 30.0
const ESSENCE_BASSE := 25.0
const BROUILLARD := 0.004
const VITESSE_ECRITURE := 0.045  # secondes par lettre, pour le texte de l'intro

var numero := 0  # mission en cours
var temps_de_jeu := 0.0
var en_intro := false
var partie_finie := false
var gilet_trouve := false
var coffres_vides := 0
var jerrican_dit := false
var essence_basse_dite := false
var marche_dite := false
var vue_fin: Camera3D  # caméra de l'épilogue

var objectif: Label
var intro: ColorRect
var intro_texte: Label
var passer: Label
var sous_titres

@onready var joueur = get_node("../Joueur")
@onready var bateau = get_node("../Bateau")
@onready var cabane: Node3D = get_node("../Cabane")
@onready var statue: Node3D = get_node("../Ocean/IleStatue/StatueLiberte")
@onready var recommencer = get_node("../Recommencer")
@onready var environnement: Environment = get_node("../WorldEnvironment").environment


func _ready():
	add_to_group("missions")
	sous_titres = preload("res://sous_titres.gd").new()
	add_child(sous_titres)
	_creer_interface()

	# ambiance grise et brumeuse
	environnement.fog_enabled = true
	environnement.fog_light_color = Color(0.62, 0.66, 0.7)
	environnement.fog_density = BROUILLARD
	environnement.fog_sky_affect = 0.0  # le brouillard reste sur la mer, on garde le ciel

	_afficher_objectif()
	_jouer_intro()


func _process(delta):
	if vue_fin != null:
		vue_fin.look_at(statue.global_position + Vector3.UP * 11)

	if en_intro:
		return
	if partie_finie:
		return

	temps_de_jeu += delta
	var mission := mission_en_cours()

	if mission == "sortir" and joueur.global_position.distance_to(cabane.global_position) > DISTANCE_SORTIE_CABANE:
		valider("sortir")

	# le moteur cale pile quand le bateau arrive contre l'île de la statue
	if mission == "statue" and joueur.dans_bateau and _distance_statue() < DISTANCE_ARRIVEE_STATUE:
		if joueur.peut_descendre():
			valider("statue")
			bateau.carburant = 0.0
			sous_titres.dire(Scenario.ARRIVEE_STATUE)

	if mission == "poser" and not joueur.dans_bateau and not marche_dite and _distance_statue() < DISTANCE_MARCHE_STATUE:
		marche_dite = true
		sous_titres.dire(Scenario.MARCHE_STATUE)

	_surveiller_essence()


func mission_en_cours() -> String:
	if numero >= Scenario.MISSIONS.size():
		return ""
	return Scenario.MISSIONS[numero]["id"]


func valider(id: String):
	if id != mission_en_cours():
		return
	numero += 1
	_afficher_objectif()
	if id == "bateau":
		sous_titres.dire(Scenario.DEPART_BATEAU)


func _afficher_objectif():
	if numero >= Scenario.MISSIONS.size():
		objectif.text = ""
	else:
		objectif.text = "Mission : " + Scenario.MISSIONS[numero]["objectif"]


func _distance_statue() -> float:
	var ecart: Vector3 = statue.global_position - joueur.global_position
	ecart.y = 0
	return ecart.length()


# ---------- appelé par le joueur et les objets ----------

func coffre_ouvert(objet: String):
	if objet == joueur.OBJET_CARBURANT:
		valider("jerrican")
	elif objet == joueur.OBJET_VICTOIRE:
		gilet_trouve = true
		sous_titres.dire(Scenario.GILET)
		valider("gilet")
	elif gilet_trouve:
		joueur.annoncer("Le coffre est vide...")
	else:
		# les coffres vides ont leur réplique dans l'ordre où on les ouvre
		coffres_vides += 1
		if coffres_vides == 1:
			joueur.annoncer("Tu as trouvé : " + Scenario.OBJET_COFFRE_1)
			sous_titres.dire(Scenario.COFFRE_1)
		elif coffres_vides == 2:
			joueur.annoncer("Tu as trouvé : " + Scenario.OBJET_COFFRE_2)
			sous_titres.dire(Scenario.COFFRE_2)
		else:
			joueur.annoncer("Le coffre est vide...")


func jerrican_ramasse():
	if not jerrican_dit:
		jerrican_dit = true
		sous_titres.dire(Scenario.JERRICAN)


# ---------- essence ----------

func _surveiller_essence():
	if not joueur.dans_bateau:
		return

	if bateau.carburant < ESSENCE_BASSE and not essence_basse_dite:
		essence_basse_dite = true
		sous_titres.dire(Scenario.ESSENCE_BASSE)
	if bateau.carburant > ESSENCE_BASSE * 2:
		essence_basse_dite = false

	# plus d'essence en pleine mer = game over (sauf en arrivant à la statue)
	if bateau.carburant <= 0 and mission_en_cours() != "poser":
		_game_over_panne()


func _game_over_panne():
	partie_finie = true
	joueur.bloque = true
	sous_titres.dire(Scenario.GAME_OVER_PANNE, true)
	# Marcel dérive seul dans le brouillard
	var tween := create_tween()
	tween.tween_property(environnement, "fog_density", BROUILLARD * 6, 4.0)
	await sous_titres.fini
	recommencer.game_over(Scenario.TEXTE_GAME_OVER_PANNE, "")


# ---------- intro ----------
# scène 1 : écran noir avec le texte tapé à la machine, puis la voix off de Marcel.
# Le joueur ne peut pas bouger avant la fin (E pour passer).

func _jouer_intro():
	en_intro = true
	joueur.bloque = true
	intro.show()
	passer.show()
	intro_texte.visible_characters = 0

	while en_intro and intro_texte.visible_characters < Scenario.INTRO_TEXTE.length():
		intro_texte.visible_characters += 1
		await get_tree().create_timer(VITESSE_ECRITURE).timeout

	if en_intro:
		await get_tree().create_timer(2.5).timeout
	if en_intro:
		var tween := create_tween()
		tween.tween_property(intro, "modulate:a", 0.0, 1.5)
		await tween.finished
		intro.hide()
	if en_intro:
		sous_titres.dire(Scenario.INTRO)
		await sous_titres.fini
	_fin_intro()


func _input(event):
	if en_intro and event.is_action_pressed("interagir"):
		_fin_intro()


func _fin_intro():
	if not en_intro:
		return
	en_intro = false
	joueur.bloque = false
	intro.hide()
	passer.hide()
	if sous_titres.est_en_train_de_parler():
		sous_titres.dire([], true)  # on coupe la voix off si on a passé l'intro


# ---------- fin ----------

# appelé quand le gilet est sur la statue
func lancer_epilogue(vue: Camera3D):
	valider("poser")
	partie_finie = true
	vue_fin = vue

	# une lumière jaune s'allume sur la statue et chasse la brume
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Couleurs.IMPORTANTE
	lumiere.omni_range = 60
	lumiere.light_energy = 0
	statue.add_child(lumiere)
	lumiere.position = Vector3(0, 14, 0)
	var tween := create_tween().set_parallel()
	tween.tween_property(environnement, "fog_density", 0.0, 4.0)
	tween.tween_property(lumiere, "light_energy", 6.0, 3.0)

	# la caméra recule lentement
	var arrivee := vue.global_position + vue.global_transform.basis.z * 45 + Vector3.UP * 12
	var recul := create_tween()
	recul.tween_property(vue, "global_position", arrivee, 30.0).set_trans(Tween.TRANS_SINE)

	sous_titres.dire(Scenario.EPILOGUE, true)
	await sous_titres.fini
	var minutes := int(temps_de_jeu) / 60
	var secondes := int(temps_de_jeu) % 60
	recommencer.fin(Scenario.TEXTE_FIN, "Temps de jeu : %d min %02d s" % [minutes, secondes])


# ---------- affichage ----------

func _creer_interface():
	var calque := CanvasLayer.new()
	add_child(calque)
	objectif = Label.new()
	objectif.add_theme_font_size_override("font_size", 32)
	objectif.add_theme_color_override("font_color", Couleurs.IMPORTANTE)
	objectif.add_theme_color_override("font_outline_color", Couleurs.FONCEE)
	objectif.add_theme_constant_override("outline_size", 8)
	objectif.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objectif.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	objectif.offset_left = -900
	objectif.offset_right = -30
	objectif.offset_top = 20
	calque.add_child(objectif)

	# écran noir de l'intro, par-dessus tout le reste
	var calque_intro := CanvasLayer.new()
	calque_intro.layer = 20
	add_child(calque_intro)
	intro = ColorRect.new()
	intro.color = Color.BLACK
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	calque_intro.add_child(intro)
	intro_texte = Label.new()
	intro_texte.text = Scenario.INTRO_TEXTE
	intro_texte.add_theme_font_size_override("font_size", 48)
	intro_texte.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	intro_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_texte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_texte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.add_child(intro_texte)
	passer = Label.new()
	passer.text = "E : passer"
	passer.add_theme_font_size_override("font_size", 24)
	passer.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	passer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	passer.offset_left = -200
	passer.offset_top = -60
	calque_intro.add_child(passer)
	intro.hide()
	passer.hide()
