class_name Sons
extends Node

# Les sons FMOD du jeu : musique, vagues, vent, moteur, coeur
# et les bruits des objets proches (requins, rochers, coffres, jerricans).

# les GUID des sons dans la banque FMOD
const SONS := {
	"MUS_Loading": "{3dd47ded-b5d5-4cac-93f3-f6082483a077}",
	"Ocean_Waves": "{cdc061ac-ba45-4828-acd8-0c1d1ac00808}",
	"Ocean_Wind": "{71a33aa6-9c30-4f69-be2e-4e3059d2ae00}",
	"Boat_Engine": "{83ad2383-077f-4887-a054-3f13e40cb0fe}",
	"Boat_Engine_Start": "{50140472-4263-4eac-b8a0-d2906bca82b4}",
	"Boat_Engine_Stop": "{d6484032-eb6d-4c7f-9eae-08101f3c1430}",
	"SFX_Shark_Heartbeat_Loop": "{f357b030-ca6f-45fe-a03b-bf80bb8d42b1}",
	"SFX_Shark_Proximity": "{92a88772-225a-4508-a0ec-06f0b917e2a8}",
	"SFX_Shark_Attack": "{91b8ff5e-4ec1-450d-bed5-7692f9500562}",
	"SFX_Fuel_Proximity": "{368ef13c-4b73-4654-9196-6fda519710bb}",
	"SFX_Fuel_Collected": "{35df4f39-683c-4f3c-83e4-8c20a1a5ee74}",
	"SFX_Treasure_Proximity": "{665ae482-e6f9-4aa3-9e68-b1cb12994fbb}",
	"SFX_Treasure_Collected": "{ed370a8e-5d8c-4aa8-a521-b424963aedca}",
	"SFX_Rocks_Waves_Loop": "{0b3caeea-bcf0-44b8-a5e6-27e2d93519be}",
	"SFX_Writing_Machine": "{53d03908-3a88-498c-946f-6c7ae5275af0}",
	"SFX_Victory": "{9698ccf0-d8d9-4466-94dd-abe64b24d08a}",
}

var musique: FmodEvent
var vagues: FmodEvent
var vent: FmodEvent
var moteur: FmodEvent
var coeur: FmodEvent

var demarre := false
var coupe := false
var moteur_allume := false
var coeur_allume := false
var musique_allumee := false
var volume := 1.0  # baisse quand Marcel parle
var volume_musique := 0.0  # la musique part quand on monte dans le bateau
var bruits := {}  # objet -> son FMOD

@onready var joueur = get_node("../Joueur")
@onready var bateau = get_node("../Bateau")
@onready var missions = get_node("../Missions")
@onready var oreilles = $Oreilles


static func creer(nom: String) -> FmodEvent:
	return FmodServer.create_event_instance_with_guid(SONS[nom])


# joue un son une seule fois, par exemple Sons.jouer("SFX_Victory")
static func jouer(nom: String, volume_son := 1.0):
	var son = creer(nom)
	son.volume = volume_son
	son.start()
	son.release()


# on coupe tout quand on a gagné
static func couper_tout(arbre: SceneTree):
	arbre.get_first_node_in_group("sons").couper()


func _ready():
	add_to_group("sons")
	musique = creer("MUS_Loading")
	vagues = creer("Ocean_Waves")
	vent = creer("Ocean_Wind")
	moteur = creer("Boat_Engine")
	coeur = creer("SFX_Shark_Heartbeat_Loop")


func _process(delta):
	if coupe:
		return
	# rien pendant l'écran noir du début
	if missions.ecran_noir:
		return
	if not demarre:
		demarre = true
		vagues.start()
		vent.start()

	# les oreilles suivent la caméra
	var camera = get_viewport().get_camera_3d()
	if camera != null:
		oreilles.global_transform = camera.global_transform

	# quand Marcel parle on baisse tout, et au départ en bateau on n'entend que lui
	var cible := 1.0
	if missions.sous_titres.voix_en_cours():
		cible = 0.3
	if missions.depart_en_cours:
		cible = 0.0
	volume = move_toward(volume, cible, delta * 2)

	# la musique seulement à pied
	if joueur.dans_bateau:
		volume_musique = move_toward(volume_musique, 0.0, delta / 2)
	else:
		volume_musique = move_toward(volume_musique, 1.0, delta / 2)
	if volume_musique > 0 and not musique_allumee:
		musique.start()
		musique_allumee = true
	if volume_musique == 0 and musique_allumee:
		musique.stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)
		musique_allumee = false
	musique.volume = 0.8 * volume_musique * volume

	# l'eau est plus discrète en bateau, et pas de vagues dans la cabane
	var eau := 1.0
	if joueur.dans_bateau:
		eau = 0.5
	if missions.en_intro:
		eau = 0.0
	vagues.volume = 0.25 * eau * volume
	vent.volume = 0.2 * eau * volume
	# les vagues et le vent sont partout autour de nous
	vagues.set_3d_attributes(oreilles.global_transform)
	vent.set_3d_attributes(oreilles.global_transform)

	var vitesse = abs(bateau.vitesse) / Bateau.VITESSE_MAX * 100
	vent.set_parameter_by_name("Boat_Speed", vitesse)
	moteur.set_parameter_by_name("Boat_Speed", vitesse)
	moteur.volume = 0.45 * volume
	_moteur()
	_coeur()

	# pas de bruits d'objets pendant les cinématiques
	if missions.en_intro or missions.depart_en_cours:
		_couper_bruits()
	else:
		_bruits_proches()


# le moteur démarre quand on monte dans le bateau et cale quand on descend ou qu'il n'y a plus d'essence
func _moteur():
	var allume = bateau.pilote_actif and not bateau.en_attente and bateau.carburant > 0
	if allume and not moteur_allume:
		jouer("Boat_Engine_Start", 0.4)
		moteur.start()
	if not allume and moteur_allume:
		moteur.stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)
		jouer("Boat_Engine_Stop", 0.4)
	moteur_allume = allume
	if not allume:
		return
	# le moteur reste collé à nos oreilles, sinon il s'éloigne quand le bateau avance
	moteur.set_3d_attributes(oreilles.global_transform)
	# si le son s'est arrêté tout seul, on le relance tant qu'on navigue
	if moteur.get_playback_state() == FmodServer.FMOD_STUDIO_PLAYBACK_STOPPED:
		moteur.start()


# le coeur bat de plus en plus fort quand un requin s'approche du bateau
func _coeur():
	var danger := 0.0
	if joueur.dans_bateau:
		for requin in get_tree().get_nodes_in_group("requins"):
			var distance = requin.global_position.distance_to(bateau.global_position)
			danger = max(danger, (1 - distance / 50.0) * 100)
	coeur.set_parameter_by_name("Shark_Danger", danger)
	coeur.volume = volume
	if danger > 0 and not coeur_allume:
		coeur.start()
		coeur_allume = true
	if danger <= 0 and coeur_allume:
		coeur.stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)
		coeur_allume = false


func _bruits_proches():
	_bruit("requins", "SFX_Shark_Proximity", 45.0, 2.5)
	_bruit("rochers", "SFX_Rocks_Waves_Loop", 30.0, 1.5)
	_bruit("coffres", "SFX_Treasure_Proximity", 90.0, 1.5)  # on entend les coffres de loin
	_bruit("jerricans", "SFX_Fuel_Proximity", 25.0, 1.5)

	# on arrête les sons des jerricans ramassés et des coffres ouverts
	for objet in bruits.keys():
		if not is_instance_valid(objet) or ("ouvert" in objet and objet.ouvert):
			_couper_bruit(objet)


# plus on est près de l'objet, plus son bruit est fort
func _bruit(groupe: String, nom: String, rayon: float, volume_max: float):
	for objet in get_tree().get_nodes_in_group(groupe):
		if "muet" in objet and objet.muet:
			continue
		if "ouvert" in objet and objet.ouvert:
			continue
		var distance = _distance(objet)
		if distance > rayon:
			if bruits.has(objet):
				_couper_bruit(objet)
			continue
		if not bruits.has(objet):
			bruits[objet] = creer(nom)
			bruits[objet].start()
		var son = bruits[objet]
		son.volume = (1 - distance / rayon) * volume_max * volume
		# on met le son tout près de nous mais dans la direction de l'objet,
		# comme ça c'est nous qui choisissons le volume et FMOD fait juste gauche / droite
		var direction = (objet.global_position - oreilles.global_position).normalized()
		son.set_3d_attributes(Transform3D(Basis(), oreilles.global_position + direction * 2))


func _distance(objet) -> float:
	return objet.global_position.distance_to(oreilles.global_position)


func _couper_bruit(objet):
	bruits[objet].stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)
	bruits[objet].release()
	bruits.erase(objet)


func _couper_bruits():
	for objet in bruits.keys():
		_couper_bruit(objet)


func couper():
	coupe = true
	for son in [musique, vagues, vent, moteur, coeur]:
		son.stop(FmodServer.FMOD_STUDIO_STOP_ALLOWFADEOUT)
	_couper_bruits()


# quand on recommence la partie il faut arrêter les sons sinon ils continuent
func _exit_tree():
	_couper_bruits()
	for son in [musique, vagues, vent, moteur, coeur]:
		son.stop(FmodServer.FMOD_STUDIO_STOP_IMMEDIATE)
		son.release()
