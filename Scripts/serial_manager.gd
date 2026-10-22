extends Node

# Autoload qui parle avec la manette Arduino par le port série (115200 bauds).
#
# Ce que l'Arduino envoie :
#   VITESSE:<-50 à 100>      la glissière (sert seulement en bateau)
#   GOUVERNAIL:<-50 à 50>    l'encodeur (gauche = négatif) : tourne le bateau, ou la vue à pied
#   JOY:<x>,<y>              le joystick, de -100 à 100 (zone morte déjà faite par l'Arduino),
#                            sert seulement à pied
#   BTN:1  BTN:2  BTN:ENC  BTN:JOY    les boutons
#
# Ce qu'on envoie à l'Arduino :
#   F<0-100>   jauge d'essence
#   L / R      choc à gauche / à droite (vibreur + une LED de vie en moins)
#   Z          nouvelle partie (3 LEDs + jauge pleine)

signal connecte
signal deconnecte
signal joystick_changed(vecteur: Vector2)  # x : droite, y : en avant, chacun de -1 à 1

const BAUDS := 115200
const NOMS_PORTS := ["usbmodem", "usbserial", "ttyACM", "ttyUSB", "COM"]

# quel numéro correspond à quel bouton (à inverser si c'est dans l'autre sens)
const BOUTON_GAUCHE := "2"  # relancer la partie, comme la touche R
const BOUTON_DROIT := "1"   # interagir, comme la touche E

# si le personnage recule quand on pousse le joystick vers l'avant, mettre true
const INVERSER_JOY_Y := false

# l'Arduino renvoie BTN:x en boucle quand on reste appuyé :
# on ne compte qu'un appui si le bouton a été relâché au moins ce temps
const TEMPS_RELACHE := 0.3

var serie
var est_connecte := false
var manette_active := false  # true si on a lancé le jeu avec le bouton Arduino

var vitesse := 0     # -50 à 100
var gouvernail := 0  # -50 à 50
var joystick := Vector2.ZERO  # -1 à 1 sur chaque axe (y positif = en avant)

var texte_recu := ""
var temps_avant_essai := 0.0
var temps_verif := 0.0
var dernier_appui := {}


func _ready():
	# continue à marcher quand le jeu est en pause (écran "recommencer")
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ARDUINO_PORT=tcp://127.0.0.1:5555 permet de tester sans carte avec un simulateur
	if _port_force().begins_with("tcp://"):
		serie = SerialTcpSimu.new()
	else:
		serie = GdSerial.new()
	serie.set_baud_rate(BAUDS)
	serie.set_timeout(10)


func _process(delta):
	if not est_connecte:
		temps_avant_essai -= delta
		if temps_avant_essai <= 0:
			temps_avant_essai = 2.0
			_essayer_de_se_connecter()
		return

	# de temps en temps on vérifie que la carte est toujours branchée
	temps_verif -= delta
	if temps_verif <= 0:
		temps_verif = 1.0
		if not serie.is_open():
			_perdre_connexion()
			return

	while serie.bytes_available() > 0:
		texte_recu += serie.read_string(serie.bytes_available())

	while "\n" in texte_recu:
		var fin := texte_recu.find("\n")
		var ligne := texte_recu.substr(0, fin).strip_edges()
		texte_recu = texte_recu.substr(fin + 1)
		if ligne != "":
			_lire_ligne(ligne)


func _essayer_de_se_connecter():
	for nom in _ports_possibles():
		serie.set_port(nom)
		if serie.open():
			serie.clear_buffer()
			est_connecte = true
			texte_recu = ""
			print("Manette connectée sur ", nom)
			connecte.emit()
			return


func _ports_possibles() -> Array:
	if _port_force() != "":
		return [_port_force()]
	var liste := []
	for infos in serie.list_ports().values():
		for morceau in NOMS_PORTS:
			if morceau in infos["port_name"]:
				liste.append(infos["port_name"])
				break
	return liste


func _port_force() -> String:
	return OS.get_environment("ARDUINO_PORT").strip_edges()


func _perdre_connexion():
	est_connecte = false
	vitesse = 0
	gouvernail = 0
	joystick = Vector2.ZERO
	serie.close()
	print("Manette déconnectée")
	deconnecte.emit()


func _lire_ligne(ligne: String):
	var morceaux := ligne.split(":")
	if morceaux.size() < 2:
		return
	var cle := morceaux[0]
	var valeur := morceaux[1]

	if cle == "VITESSE":
		vitesse = clampi(valeur.to_int(), -50, 100)
	elif cle == "GOUVERNAIL":
		gouvernail = clampi(valeur.to_int(), -50, 50)
	elif cle == "JOY":
		_lire_joystick(valeur)
	elif cle == "BTN":
		_appui_bouton(valeur)


# "x,y" de -100 à 100 -> Vector2 de -1 à 1
func _lire_joystick(valeur: String):
	var axes := valeur.split(",")
	if axes.size() != 2:
		return
	var nouveau := Vector2(clampi(axes[0].to_int(), -100, 100), clampi(axes[1].to_int(), -100, 100)) / 100.0
	if INVERSER_JOY_Y:
		nouveau.y = -nouveau.y
	if nouveau != joystick:
		joystick = nouveau
		joystick_changed.emit(joystick)


func _appui_bouton(bouton: String):
	var maintenant := Time.get_ticks_msec() / 1000.0
	var dernier: float = dernier_appui.get(bouton, -10.0)
	dernier_appui[bouton] = maintenant
	if maintenant - dernier < TEMPS_RELACHE:
		return  # c'est le même appui qui continue
	if not manette_active:
		return

	# les boutons font comme les touches du clavier, comme ça le reste du jeu ne change pas
	if bouton == BOUTON_GAUCHE:
		_appuyer_touche(KEY_R)
	elif bouton == BOUTON_DROIT:
		_appuyer_touche(KEY_E)


func _appuyer_touche(touche: Key):
	var appui := InputEventKey.new()
	appui.physical_keycode = touche
	appui.pressed = true
	Input.parse_input_event(appui)

	# on relâche un peu après, sinon le jeu n'a pas le temps de voir l'appui
	await get_tree().create_timer(0.1).timeout
	var relache := InputEventKey.new()
	relache.physical_keycode = touche
	relache.pressed = false
	Input.parse_input_event(relache)


# ---------- pour le jeu ----------

# entre -1 (marche arrière à fond) et 1 (en avant à fond)
func avance() -> float:
	if not manette_active:
		return 0.0
	if vitesse > 0:
		return vitesse / 100.0
	return vitesse / 50.0


# le joystick pour marcher : x de -1 (gauche) à 1 (droite), y de -1 (reculer) à 1 (avancer)
func deplacement() -> Vector2:
	if not manette_active:
		return Vector2.ZERO
	return joystick


# entre -1 (à gauche) et 1 (à droite)
func virage() -> float:
	if not manette_active:
		return 0.0
	return gouvernail / 50.0


func envoyer(commande: String):
	if est_connecte:
		serie.writeline(commande)


func envoyer_essence(pourcentage: int):
	envoyer("F" + str(clampi(pourcentage, 0, 100)))


func choc_gauche():
	envoyer("L")


func choc_droit():
	envoyer("R")


func nouvelle_partie():
	envoyer("Z")
