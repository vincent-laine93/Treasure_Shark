extends Node

# Le déroulement de la partie : l'intro, les missions dans l'ordre,
# ce que dit Marcel, la panne d'essence et la fin.
# Les textes sont dans scenario.gd.

var numero := 0  # numéro de la mission en cours
var temps_de_jeu := 0.0
var en_intro := false
var ecran_noir := true
var depart_en_cours := false
var partie_finie := false
var gilet_trouve := false
var coffres_vides := 0
var jerrican_dit := false
var essence_basse_dite := false
var marche_dite := false
var vue_fin: Camera3D
var machine_a_ecrire: FmodEvent

var objectif: Label
var intro: ColorRect
var intro_texte: Label
var passer: Label
var sous_titres

@onready var joueur = get_node("../Joueur")
@onready var bateau = get_node("../Bateau")
@onready var cabane = get_node("../Cabane")
@onready var statue = get_node("../Ocean/IleStatue/StatueLiberte")
@onready var recommencer = get_node("../Recommencer")
@onready var environnement: Environment = get_node("../WorldEnvironment").environment


func _ready():
	add_to_group("missions")
	sous_titres = preload("res://sous_titres.gd").new()
	add_child(sous_titres)
	_creer_interface()

	# on copie l'environnement sinon quand on rejoue il n'y a plus de brouillard
	environnement = environnement.duplicate()
	get_node("../WorldEnvironment").environment = environnement
	environnement.fog_enabled = true
	environnement.fog_light_color = Color(0.62, 0.66, 0.7)
	environnement.fog_density = 0.004
	environnement.fog_sky_affect = 0.0

	_afficher_objectif()
	_jouer_intro()


func _process(delta):
	if vue_fin != null:
		vue_fin.look_at(statue.global_position + Vector3.UP * 11)
	if en_intro or partie_finie:
		return

	temps_de_jeu += delta
	var mission = mission_en_cours()

	if mission == "sortir" and joueur.global_position.distance_to(cabane.global_position) > 6:
		valider("sortir")

	# arrivé à l'île de la statue, le moteur cale
	if mission == "statue" and joueur.dans_bateau and distance_statue(joueur) < 40 and joueur.peut_descendre():
		valider("statue")
		bateau.carburant = 0.0
		if gilet_trouve:
			Sons.jouer("SFX_Victory")
		sous_titres.dire(Scenario.ARRIVEE_STATUE)

	if mission == "poser" and not joueur.dans_bateau and not marche_dite and distance_statue(joueur) < 30:
		marche_dite = true
		sous_titres.dire(Scenario.MARCHE_STATUE)

	_verifier_essence()


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
		_depart_bateau()


# la première fois qu'on monte dans le bateau, Marcel parle et on ne peut pas bouger
func _depart_bateau():
	depart_en_cours = true
	joueur.bloque = true
	bateau.en_attente = true
	sous_titres.dire(Scenario.DEPART_BATEAU)
	await sous_titres.fini
	depart_en_cours = false
	joueur.bloque = false
	bateau.en_attente = false


func _afficher_objectif():
	if numero >= Scenario.MISSIONS.size():
		objectif.text = ""
	else:
		objectif.text = "Mission : " + Scenario.MISSIONS[numero]["objectif"]


# distance sans compter la hauteur
func distance_statue(objet) -> float:
	var ecart = statue.global_position - objet.global_position
	ecart.y = 0
	return ecart.length()


func coffre_ouvert(objet: String):
	if objet == "Jerrican":
		valider("jerrican")
	elif objet == "Gilet jaune":
		gilet_trouve = true
		sous_titres.dire(Scenario.GILET)
		valider("gilet")
	elif gilet_trouve:
		joueur.annoncer("Le coffre est vide...")
	else:
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


# l'essence ne compte que quand on est en bateau et pas encore à la statue
func _verifier_essence():
	if not joueur.dans_bateau or distance_statue(bateau) < 40:
		return

	if bateau.carburant < 25 and not essence_basse_dite:
		essence_basse_dite = true
		sous_titres.dire(Scenario.ESSENCE_BASSE)
	if bateau.carburant > 50:
		essence_basse_dite = false

	if bateau.carburant <= 0 and mission_en_cours() != "poser":
		_panne_seche()


func _panne_seche():
	partie_finie = true
	joueur.bloque = true
	sous_titres.dire(Scenario.GAME_OVER_PANNE, true)
	var tween = create_tween()
	tween.tween_property(environnement, "fog_density", 0.024, 4.0)
	await sous_titres.fini
	recommencer.game_over(Scenario.TEXTE_GAME_OVER_PANNE, "")


# ---------- intro ----------

func _jouer_intro():
	en_intro = true
	joueur.bloque = true
	intro.show()
	passer.show()
	intro_texte.visible_characters = 0

	# le texte s'écrit lettre par lettre avec le bruit de machine à écrire
	machine_a_ecrire = Sons.creer("SFX_Writing_Machine")
	machine_a_ecrire.start()
	while en_intro and intro_texte.visible_characters < Scenario.INTRO_TEXTE.length():
		intro_texte.visible_characters += 1
		await get_tree().create_timer(0.045).timeout
	_arreter_machine_a_ecrire()

	if en_intro:
		await get_tree().create_timer(2.5).timeout
	if en_intro:
		var tween = create_tween()
		tween.tween_property(intro, "modulate:a", 0.0, 1.5)
		await tween.finished
		intro.hide()
		ecran_noir = false
	if en_intro:
		sous_titres.dire(Scenario.INTRO)
		await sous_titres.fini
	_fin_intro()


func _arreter_machine_a_ecrire():
	if machine_a_ecrire != null:
		machine_a_ecrire.stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)
		machine_a_ecrire.release()
		machine_a_ecrire = null


# E pour passer l'intro
func _input(event):
	if en_intro and event.is_action_pressed("interagir"):
		_fin_intro()


func _fin_intro():
	if not en_intro:
		return
	en_intro = false
	ecran_noir = false
	_arreter_machine_a_ecrire()
	joueur.bloque = false
	intro.hide()
	passer.hide()
	if sous_titres.est_en_train_de_parler():
		sous_titres.dire([], true)


# ---------- fin ----------

func dissiper_brouillard():
	var tween = create_tween().set_parallel()
	tween.tween_property(environnement, "fog_density", 0.0, 5.0)
	tween.tween_property(environnement, "volumetric_fog_density", 0.0, 5.0)
	await tween.finished
	environnement.fog_enabled = false
	environnement.volumetric_fog_enabled = false


func lancer_epilogue(vue: Camera3D):
	valider("poser")
	partie_finie = true
	vue_fin = vue

	# une lumière jaune s'allume sur la statue
	var lumiere = OmniLight3D.new()
	lumiere.light_color = Couleurs.IMPORTANTE
	lumiere.omni_range = 60
	lumiere.light_energy = 0
	statue.add_child(lumiere)
	lumiere.position = Vector3(0, 14, 0)
	create_tween().tween_property(lumiere, "light_energy", 6.0, 3.0)

	# la caméra recule doucement
	var arrivee = vue.global_position + vue.global_transform.basis.z * 45 + Vector3.UP * 12
	create_tween().tween_property(vue, "global_position", arrivee, 30.0).set_trans(Tween.TRANS_SINE)

	sous_titres.dire(Scenario.EPILOGUE, true)
	await sous_titres.fini
	var minutes = int(temps_de_jeu) / 60
	var secondes = int(temps_de_jeu) % 60
	recommencer.fin(Scenario.TEXTE_FIN, "Temps de jeu : %d min %02d s" % [minutes, secondes])


# ---------- affichage ----------

func _creer_interface():
	var calque = CanvasLayer.new()
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

	# l'écran noir du début
	var calque_intro = CanvasLayer.new()
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
