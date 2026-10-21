extends Node

# Autoload qui parle avec la manette Arduino par le port série (115200 bauds).
#
# Ce que l'Arduino envoie :
#   VITESSE:<-50 à 100>      la glissière
#   GOUVERNAIL:<-50 à 50>    l'encodeur (gauche = négatif)
#   BTN:1  BTN:2  BTN:ENC    les boutons
#
# Ce qu'on envoie à l'Arduino :
#   F<0-100>   jauge d'essence
#   L / R      choc à gauche / à droite (vibreur + une LED de vie en moins)
#   Z          nouvelle partie (3 LEDs + jauge pleine)

signal connecte
signal deconnecte

const BAUDS := 115200
const NOMS_PORTS := ["usbmodem", "usbserial", "ttyACM", "ttyUSB", "COM"]

# quel numéro correspond à quel bouton (à inverser si c'est dans l'autre sens)
const BOUTON_GAUCHE := "2"  # relancer la partie, comme la touche R
const BOUTON_DROIT := "1"   # interagir, comme la touche E

# l'Arduino renvoie BTN:x en boucle quand on reste appuyé :
# on ne compte qu'un appui si le bouton a été relâché au moins ce temps
const TEMPS_RELACHE := 0.3

var serie
var est_connecte := false
var manette_active := false  # true si on a lancé le jeu avec le bouton Arduino

var vitesse := 0     # -50 à 100
var gouvernail := 0  # -50 à 50

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
	elif cle == "BTN":
		_appui_bouton(valeur)


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
