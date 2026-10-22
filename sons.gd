class_name Sons
extends Node

# Tous les sons FMOD du jeu (banque "FMOD Banks/Desktop/Master.bank").
# Ici : la musique à pied, les vagues, le vent, le moteur du bateau et le cœur qui bat
# quand un requin approche.
# Les sons de proximité (jerricans, coffres, rochers, requins) sont posés sur les objets
# eux-mêmes avec Sons.ajouter_proximite() : on ne les entend que de près (RAYONS),
# très fort tout près, de plus en plus faible en s'éloignant, et du bon côté.
# Le mixage (voir VOLUMES et BAISSES) évite que les sons se marchent dessus :
# la musique baisse quand un objet est proche ou qu'un requin approche, et tout
# baisse un moment pour laisser passer une morsure, un choc ou un objet ramassé.
# Rien ne joue pendant l'écran noir du début, et tout se coupe quand on a gagné.

# nom dans le jeu : [chemin FMOD, guid]
const EVENEMENTS := {
	"musique": ["event:/MUS_Loading", "{3dd47ded-b5d5-4cac-93f3-f6082483a077}"],  # à pied sur les îles
	"musique_mer": ["event:/MUS_Gameplay_Loop", "{d9e1bc86-5c20-4eeb-b191-6ffd866c634e}"],  # dans le bateau
	"vagues": ["event:/Ocean_Waves", "{cdc061ac-ba45-4828-acd8-0c1d1ac00808}"],
	"vent": ["event:/Ocean_Wind", "{71a33aa6-9c30-4f69-be2e-4e3059d2ae00}"],
	"moteur": ["event:/Boat_Engine", "{83ad2383-077f-4887-a054-3f13e40cb0fe}"],
	"moteur_demarre": ["event:/Boat_Engine_Start", "{50140472-4263-4eac-b8a0-d2906bca82b4}"],
	"moteur_cale": ["event:/Boat_Engine_Stop", "{d6484032-eb6d-4c7f-9eae-08101f3c1430}"],
	"coeur": ["event:/SFX_Shark_Heartbeat_Loop", "{f357b030-ca6f-45fe-a03b-bf80bb8d42b1}"],
	"requin": ["event:/SFX_Shark_Proximity", "{92a88772-225a-4508-a0ec-06f0b917e2a8}"],
	"requin_attaque": ["event:/SFX_Shark_Attack", "{91b8ff5e-4ec1-450d-bed5-7692f9500562}"],
	"choc_rocher": ["event:/SFX_Shark_Attack", "{91b8ff5e-4ec1-450d-bed5-7692f9500562}"],  # même son pour l'instant
	"essence": ["event:/SFX_Fuel_Proximity", "{368ef13c-4b73-4654-9196-6fda519710bb}"],
	"essence_ramassee": ["event:/SFX_Fuel_Collected", "{35df4f39-683c-4f3c-83e4-8c20a1a5ee74}"],
	"tresor": ["event:/SFX_Treasure_Proximity", "{665ae482-e6f9-4aa3-9e68-b1cb12994fbb}"],
	"tresor_ouvert": ["event:/SFX_Treasure_Collected", "{ed370a8e-5d8c-4aa8-a521-b424963aedca}"],
	"rochers": ["event:/SFX_Rocks_Waves_Loop", "{0b3caeea-bcf0-44b8-a5e6-27e2d93519be}"],
	"machine_a_ecrire": ["event:/SFX_Writing_Machine", "{53d03908-3a88-498c-946f-6c7ae5275af0}"],  # écran noir du début
}

const DISTANCE_DANGER_REQUIN := 50.0  # le cœur commence à battre quand un requin est plus près

# distance (en mètres) à partir de laquelle on entend chaque son de proximité
const RAYONS := {
	"requin": 45.0,
	"rochers": 30.0,
	"tresor": 90.0,  # on entend les coffres de loin pour pouvoir les chercher à l'oreille
	"essence": 25.0,
}
# comment le son monte en s'approchant : 2 = discret de loin puis fort tout près,
# 1 = monte régulièrement (on l'entend déjà bien de loin)
const COURBES := {
	"requin": 1.5,
	"rochers": 2.0,
	"tresor": 1.2,
	"essence": 2.0,
}
# FMOD baisse déjà le son avec la distance (jusqu'à 100 m) : pour que ce soit nous qui
# décidions du volume, on lui fait croire que le son est toujours à cette distance
# (sa distance "minimum", où il est à fond), mais dans la vraie direction de l'objet.
const DISTANCE_FMOD := {
	"requin": 5.0,
	"rochers": 2.0,
	"tresor": 2.0,
	"essence": 2.0,
}
# volume collé à l'objet (1 = volume de la banque FMOD)
const VOLUME_TOUT_PRES := {
	"requin": 2.5,  # les requins doivent bien s'entendre
	"rochers": 1.5,
	"tresor": 1.5,
	"essence": 1.5,
}

# ---------- mixage ----------
# volume normal de chaque boucle (1 = volume de la banque FMOD)
const VOLUMES := {
	"musique": 0.8,
	"musique_mer": 1.0,  # la musique du bateau doit passer au-dessus du moteur et de l'eau
	"vagues": 0.25,  # l'eau reste en fond, sur les îles comme en bateau
	"vent": 0.2,
	"moteur": 0.45,  # pas de musique en bateau : le moteur peut être bien présent
	"coeur": 1.0,
}
# volume des sons joués une fois (ceux qui ne sont pas ici sont à 1)
const VOLUMES_UNIQUES := {
	"moteur_demarre": 0.4,
	"moteur_cale": 0.4,
}
# Quand un objet (requin, rocher, coffre, jerrican) est tout près, son son monte
# et ceux-là descendent jusqu'à : [musique, moteur, vagues et vent]
const BAISSE_OBJET_PROCHE := [0.4, 0.4, 0.7]
# Quand un requin fonce sur nous (on entend le cœur) : [musique, moteur, vagues et vent]
const BAISSE_DANGER := [0.35, 1.0, 0.8]  # le moteur ne baisse pas pour le cœur
# les sons importants font baisser tout le reste le temps qu'ils jouent :
# nom du son : [durée en secondes, musique, moteur / vagues / vent]
const BAISSES := {
	"requin_attaque": [4.0, 0.2, 0.45],
	"choc_rocher": [4.0, 0.2, 0.45],
	"tresor_ouvert": [3.0, 0.35, 0.65],
	"essence_ramassee": [1.5, 0.5, 0.8],
}
# pendant que Marcel parle, tout le reste baisse sans disparaître :
# [musique, moteur / vagues / vent, sons de proximité et cœur, sons joués une fois]
const BAISSE_VOIX := [0.25, 0.35, 0.4, 0.5]
const VITESSE_FONDU := 2.0  # pour que les volumes baissent et remontent en douceur
const MUSIQUE_EN_BATEAU := false  # true pour remettre MUS_Gameplay_Loop quand on navigue
const EAU_EN_BATEAU := 0.5  # en naviguant, les vagues et le vent sont encore plus discrets (×0,5)
const DUREE_FONDU_MUSIQUES := 2.0  # en secondes, passage de la musique des îles à celle du bateau

var demarre := false  # false tant que l'écran noir du début est affiché
var coupe := false  # true quand on a gagné : plus aucun son
var sons_proches := {}  # objet qui fait du bruit -> son FMOD en train de jouer
var sons_uniques := []  # sons joués une fois encore en cours (pour les baisser si Marcel parle)
var baisse_musique := 1.0  # où en est le volume de la musique (0 à 1), en douceur
var baisse_ambiance := 1.0  # pareil pour les vagues et le vent
var baisse_moteur := 1.0
var fondu_ile := 0.0  # 0 à 1 : la musique des îles s'en va en douceur quand on monte à bord
var fondu_mer := 0.0  # et celle du bateau arrive en même temps
var baisse_autour := 1.0  # sons de proximité et cœur : coupés pendant les cinématiques
var baisse_momentanee := [0.0, 1.0, 1.0]  # [temps restant, musique, ambiance] pendant un son important
var danger_requin := 0.0  # 0 à 100
var musique: FmodEvent
var musique_mer: FmodEvent
var vagues: FmodEvent
var vent: FmodEvent
var moteur: FmodEvent
var coeur: FmodEvent
var musique_joue := false
var musique_mer_joue := false
var moteur_tourne := false
var coeur_bat := false

@onready var joueur = get_node("../Joueur")
@onready var bateau: Bateau = get_node("../Bateau")
@onready var missions = get_node("../Missions")
@onready var oreilles: Node3D = $Oreilles


# Pose un son en boucle sur un objet. Il ne joue que quand on est assez près.
# Pour le couper (coffre ouvert...), il suffit de supprimer le point renvoyé.
static func ajouter_proximite(objet: Node3D, nom: String) -> Node3D:
	var point := Node3D.new()
	point.name = "Son_" + nom
	point.set_meta("nom", nom)
	point.add_to_group("sons_proximite")
	objet.add_child(point)
	return point


# Coupe tous les sons du jeu (appelé quand on a gagné)
static func couper_tout(arbre: SceneTree):
	var sons = arbre.get_first_node_in_group("sons")
	if sons != null:
		sons.couper()


# Joue un son une seule fois (jerrican ramassé, coffre ouvert, morsure...)
static func jouer(nom: String):
	var sons = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("sons")
	if sons != null:
		if sons.coupe:
			return  # on a gagné : plus aucun son
		sons.laisser_passer(nom)
		sons.jouer_une_fois(nom)
	else:
		FmodServer.play_one_shot_using_guid(EVENEMENTS[nom][1])


func jouer_une_fois(nom: String):
	var evenement := _creer(nom)
	evenement.set_meta("volume", VOLUMES_UNIQUES.get(nom, 1.0))
	evenement.volume = evenement.get_meta("volume")
	evenement.start()
	evenement.release()  # FMOD le supprimera tout seul à la fin
	sons_uniques.append(evenement)


# un son important va jouer : on baisse le reste pendant ce temps
func laisser_passer(nom: String):
	if not BAISSES.has(nom):
		return
	var baisse: Array = BAISSES[nom]
	# si un son plus important joue déjà, on garde la baisse la plus forte
	if baisse_momentanee[0] > 0 and baisse_momentanee[1] < baisse[1]:
		return
	baisse_momentanee = baisse.duplicate()


func _ready():
	add_to_group("sons")
	musique = _creer("musique")
	musique_mer = _creer("musique_mer")
	vagues = _creer("vagues")
	vent = _creer("vent")
	moteur = _creer("moteur")
	coeur = _creer("coeur")


func _creer(nom: String) -> FmodEvent:
	if EVENEMENTS[nom][1] == "":
		return null  # son pas encore fait
	return FmodServer.create_event_instance_with_guid(EVENEMENTS[nom][1])


func _process(delta):
	if coupe:
		return
	if not demarre:
		if missions.ecran_noir:
			return
		_demarrer()

	# les oreilles suivent la caméra active (celle du joueur à pied ou celle du pilote)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		oreilles.global_transform = camera.global_transform

	# la même musique sur toutes les îles à pied, et (plus tard) une autre sur l'eau
	fondu_ile = move_toward(fondu_ile, 0.0 if joueur.dans_bateau else 1.0, delta / DUREE_FONDU_MUSIQUES)
	fondu_mer = move_toward(fondu_mer, 1.0 if joueur.dans_bateau else 0.0, delta / DUREE_FONDU_MUSIQUES)
	var fondu_musique_mer := fondu_mer if MUSIQUE_EN_BATEAU else 0.0
	musique_joue = _jouer_ou_couper(musique, fondu_ile > 0, musique_joue)
	musique_mer_joue = _jouer_ou_couper(musique_mer, fondu_musique_mer > 0, musique_mer_joue)

	var vitesse := absf(bateau.vitesse) / Bateau.VITESSE_MAX * 100.0
	vent.set_parameter_by_name("Boat_Speed", vitesse)
	_moteur(bateau.pilote_actif and not bateau.en_attente and bateau.carburant > 0, vitesse)
	_coeur()

	# pendant l'intro dans la cabane et la réplique du départ en bateau,
	# on n'entend rien autour (ni objets proches, ni cœur)
	var cinematique: bool = missions.en_intro or missions.depart_en_cours
	var cible_autour := 1.0
	if missions.sous_titres.voix_en_cours():
		cible_autour = BAISSE_VOIX[2]
	if cinematique:
		cible_autour = 0.0
	baisse_autour = _fondu(baisse_autour, cible_autour, delta)

	# plus un objet est proche, plus son son monte et plus la musique baisse
	var proximite := _volumes_proximite()
	_mixer(proximite, delta)


# Règle le volume de toutes les boucles pour qu'elles ne se marchent pas dessus.
# La musique prend la baisse la plus forte entre : un objet proche, un requin proche,
# un son important qui joue. L'ambiance et le moteur ne baissent que pour les sons importants.
# Cinématiques : dans la cabane, seulement la musique et la voix (pas de vagues ni de vent) ;
# au départ en bateau, seulement la voix.
func _mixer(proximite: float, delta: float):
	baisse_momentanee[0] -= delta
	var pendant_son_important: bool = baisse_momentanee[0] > 0

	# chaque groupe prend la baisse la plus forte de ce qui se passe en ce moment
	var danger := danger_requin / 100.0
	var cibles := [1.0, 1.0, 1.0]  # [musique, moteur, vagues et vent]
	for i in 3:
		cibles[i] = minf(lerpf(1.0, BAISSE_OBJET_PROCHE[i], proximite), lerpf(1.0, BAISSE_DANGER[i], danger))
	if missions.sous_titres.voix_en_cours():
		cibles[0] = minf(cibles[0], BAISSE_VOIX[0])
		cibles[1] = minf(cibles[1], BAISSE_VOIX[1])
		cibles[2] = minf(cibles[2], BAISSE_VOIX[1])
	if pendant_son_important:
		cibles[0] = minf(cibles[0], baisse_momentanee[1])
		cibles[1] = minf(cibles[1], baisse_momentanee[2])
		cibles[2] = minf(cibles[2], baisse_momentanee[2])
	if missions.en_intro:
		cibles[2] = 0.0  # dans la cabane : la musique et la voix seulement
	if missions.depart_en_cours:
		cibles = [0.0, 0.0, 0.0]  # Marcel parle seul avant de partir
	# on baisse vite pour laisser passer le son, on remonte doucement
	baisse_musique = _fondu(baisse_musique, cibles[0], delta)
	baisse_moteur = _fondu(baisse_moteur, cibles[1], delta)
	baisse_ambiance = _fondu(baisse_ambiance, cibles[2], delta)

	_regler_volume(musique, "musique", baisse_musique * fondu_ile)
	_regler_volume(musique_mer, "musique_mer", baisse_musique * (fondu_mer if MUSIQUE_EN_BATEAU else 0.0))
	var eau := lerpf(1.0, EAU_EN_BATEAU, fondu_mer)  # suit le passage île -> bateau en douceur
	_regler_volume(vagues, "vagues", baisse_ambiance * eau)
	_regler_volume(vent, "vent", baisse_ambiance * eau)
	_regler_volume(moteur, "moteur", baisse_moteur)
	_regler_volume(coeur, "coeur", baisse_autour)

	# les sons joués une fois baissent aussi quand Marcel parle
	var volume_uniques := BAISSE_VOIX[3] if missions.sous_titres.voix_en_cours() else 1.0
	for evenement in sons_uniques.duplicate():
		if not evenement.is_valid():
			sons_uniques.erase(evenement)  # fini
		else:
			evenement.volume = evenement.get_meta("volume") * volume_uniques


func _fondu(actuel: float, cible: float, delta: float) -> float:
	var vitesse := VITESSE_FONDU
	if cible < actuel:
		vitesse *= 3.0
	return move_toward(actuel, cible, vitesse * delta)


func _regler_volume(evenement: FmodEvent, nom: String, baisse: float):
	if evenement != null:
		evenement.volume = VOLUMES[nom] * baisse


func _demarrer():
	demarre = true
	vagues.start()
	vent.start()


func couper():
	coupe = true
	for evenement in [musique, musique_mer, vagues, vent, moteur, coeur]:
		if evenement != null:
			evenement.stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)
	for point in sons_proches.keys():
		_couper_son_proche(point)


# démarre ou arrête une boucle quand il faut, renvoie si elle joue maintenant
func _jouer_ou_couper(evenement: FmodEvent, joue: bool, jouait: bool) -> bool:
	if evenement == null or joue == jouait:
		return jouait
	if joue:
		evenement.start()
	else:
		evenement.stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)
	return joue


# Pour chaque objet qui fait du bruit : on lance son son quand on entre dans son rayon,
# on le coupe quand on en sort, et entre les deux le volume suit la distance.
# Renvoie à quel point l'objet le plus proche est près (de 0 à 1), pour baisser la musique.
func _volumes_proximite() -> float:
	var plus_pres := 0.0
	var encore_la := {}
	for point in get_tree().get_nodes_in_group("sons_proximite"):
		var nom: String = point.get_meta("nom")
		var vers: Vector3 = point.global_position - oreilles.global_position
		var distance := vers.length()
		# 0 au bord du rayon, 1 collé à l'objet
		var pres := clampf(1.0 - distance / RAYONS[nom], 0.0, 1.0)
		if pres <= 0:
			continue
		encore_la[point] = true
		plus_pres = maxf(plus_pres, pow(pres, COURBES[nom]))  # la musique baisse selon le volume entendu

		var evenement: FmodEvent = sons_proches.get(point)
		if evenement == null:
			evenement = _creer(nom)
			evenement.start()
			sons_proches[point] = evenement
		evenement.volume = pow(pres, COURBES[nom]) * VOLUME_TOUT_PRES[nom] * baisse_autour
		# FMOD ne s'occupe que du côté d'où vient le son (gauche, droite, devant, derrière)
		var position_fmod: Vector3 = oreilles.global_position + vers.normalized() * DISTANCE_FMOD[nom]
		evenement.set_3d_attributes(Transform3D(Basis(), position_fmod))

	# les objets trop loin, ramassés ou ouverts : on coupe leur son
	for point in sons_proches.keys():
		if not encore_la.has(point):
			_couper_son_proche(point)
	return plus_pres * baisse_autour


func _couper_son_proche(point):
	var evenement: FmodEvent = sons_proches[point]
	evenement.stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)
	evenement.release()  # FMOD le supprime une fois le fondu fini
	sons_proches.erase(point)


# le moteur démarre en montant à bord, son bruit suit la vitesse,
# et il cale quand on descend ou quand il n'y a plus d'essence
func _moteur(tourne: bool, vitesse: float):
	moteur.set_parameter_by_name("Boat_Speed", vitesse)
	if tourne == moteur_tourne:
		return
	moteur_tourne = tourne
	if tourne:
		jouer("moteur_demarre")
		moteur.start()
	else:
		moteur.stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)
		jouer("moteur_cale")


# le cœur bat de plus en plus fort quand un requin approche du bateau
func _coeur():
	var danger := 0.0
	if joueur.dans_bateau:
		for requin in get_tree().get_nodes_in_group("requins"):
			var distance: float = requin.global_position.distance_to(bateau.global_position)
			danger = maxf(danger, (1.0 - distance / DISTANCE_DANGER_REQUIN) * 100.0)
	danger_requin = danger
	coeur.set_parameter_by_name("Shark_Danger", danger)
	if (danger > 0) == coeur_bat:
		return
	coeur_bat = danger > 0
	if coeur_bat:
		coeur.start()
	else:
		coeur.stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)


# quand on recommence la partie, on coupe les boucles sinon elles continuent
func _exit_tree():
	for point in sons_proches.keys():
		_couper_son_proche(point)
	for evenement in [musique, musique_mer, vagues, vent, moteur, coeur]:
		if evenement == null:
			continue
		evenement.stop(FmodServer.FMOD_STUDIO_STOP_IMMEDIATE)
		evenement.release()
