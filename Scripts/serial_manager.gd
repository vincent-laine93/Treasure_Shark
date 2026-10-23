extends Node

# Autoload qui lit la manette Arduino (port série, 115200 bauds).
#
# L'Arduino envoie :
#   VITESSE:-50 à 100       la glissière (en bateau)
#   GOUVERNAIL:-50 à 50     l'encodeur (tourne le bateau, ou la vue à pied)
#   JOY:x,y                 le joystick de -100 à 100 (à pied)
#   BTN:1  BTN:2            les boutons
#
# On envoie à l'Arduino :
#   F0 à F100   la jauge d'essence
#   L / R       choc à gauche / à droite (vibreur et une LED en moins)
#   Z           nouvelle partie

signal connecte
signal deconnecte

var serie = GdSerial.new()
var est_connecte := false
var manette_active := false  # true si on a lancé le jeu avec la manette

var vitesse := 0
var gouvernail := 0
var joystick := Vector2.ZERO

var texte_recu := ""
var temps_avant_essai := 0.0
var temps_verif := 0.0
var dernier_appui = {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # marche aussi quand le jeu est en pause
	serie.set_baud_rate(115200)
	serie.set_timeout(10)


func _process(delta):
	if not est_connecte:
		# on réessaie toutes les 2 secondes
		temps_avant_essai -= delta
		if temps_avant_essai <= 0:
			temps_avant_essai = 2.0
			_se_connecter()
		return

	# on vérifie que la carte est toujours branchée
	temps_verif -= delta
	if temps_verif <= 0:
		temps_verif = 1.0
		if not serie.is_open():
			_deconnexion()
			return

	while serie.bytes_available() > 0:
		texte_recu += serie.read_string(serie.bytes_available())

	while "\n" in texte_recu:
		var fin = texte_recu.find("\n")
		var ligne = texte_recu.substr(0, fin).strip_edges()
		texte_recu = texte_recu.substr(fin + 1)
		_lire_ligne(ligne)


func _se_connecter():
	for infos in serie.list_ports().values():
		var nom = infos["port_name"]
		if not ("usbmodem" in nom or "usbserial" in nom or "ttyACM" in nom or "ttyUSB" in nom or "COM" in nom):
			continue
		serie.set_port(nom)
		if serie.open():
			serie.clear_buffer()
			est_connecte = true
			texte_recu = ""
			print("Manette connectée sur ", nom)
			connecte.emit()
			return


func _deconnexion():
	est_connecte = false
	vitesse = 0
	gouvernail = 0
	joystick = Vector2.ZERO
	serie.close()
	print("Manette déconnectée")
	deconnecte.emit()


func _lire_ligne(ligne: String):
	var morceaux = ligne.split(":")
	if morceaux.size() < 2:
		return
	var valeur = morceaux[1]

	if morceaux[0] == "VITESSE":
		vitesse = clampi(valeur.to_int(), -50, 100)
	elif morceaux[0] == "GOUVERNAIL":
		gouvernail = clampi(valeur.to_int(), -50, 50)
	elif morceaux[0] == "JOY":
		var axes = valeur.split(",")
		if axes.size() == 2:
			joystick = Vector2(clampi(axes[0].to_int(), -100, 100), clampi(axes[1].to_int(), -100, 100)) / 100.0
	elif morceaux[0] == "BTN":
		_bouton(valeur)


func _bouton(bouton: String):
	# l'Arduino renvoie BTN en boucle quand on reste appuyé,
	# donc on ne compte un nouvel appui que si le dernier date de plus de 0,3 s
	var maintenant = Time.get_ticks_msec() / 1000.0
	var dernier = dernier_appui.get(bouton, -10.0)
	dernier_appui[bouton] = maintenant
	if maintenant - dernier < 0.3 or not manette_active:
		return

	# les boutons font comme les touches du clavier
	if bouton == "2":
		_appuyer(KEY_R)
	elif bouton == "1":
		_appuyer(KEY_E)


func _appuyer(touche):
	var appui = InputEventKey.new()
	appui.physical_keycode = touche
	appui.pressed = true
	Input.parse_input_event(appui)

	await get_tree().create_timer(0.1).timeout
	var relache = InputEventKey.new()
	relache.physical_keycode = touche
	relache.pressed = false
	Input.parse_input_event(relache)


# ---------- pour le jeu ----------

# de -1 (marche arrière) à 1 (à fond)
func avance() -> float:
	if not manette_active:
		return 0.0
	if vitesse > 0:
		return vitesse / 100.0
	return vitesse / 50.0


func deplacement() -> Vector2:
	if not manette_active:
		return Vector2.ZERO
	return joystick


# de -1 (gauche) à 1 (droite)
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
