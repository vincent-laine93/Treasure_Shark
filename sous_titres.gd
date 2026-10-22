extends CanvasLayer

# Affiche les répliques en sous-titres, une par une, en bas de l'écran.
# Si une réplique a un fichier de voix (3e élément), on le joue.
# Un enregistrement peut couvrir plusieurs répliques : les suivantes ont "" en 3e élément
# ("la voix continue"), et le temps du son est partagé entre elles selon la longueur du texte.

signal fini  # quand toutes les répliques ont été affichées

const TEMPS_MINIMUM := 2.5
const TEMPS_PAR_LETTRE := 0.06

var file_attente := []
var temps_restant := 0.0
var durees_voix := []  # temps d'affichage des répliques suivantes qui partagent la voix en cours

var bandeau: VBoxContainer
var nom: Label
var texte: Label
var voix: AudioStreamPlayer


func _ready():
	_creer_interface()
	bandeau.hide()


# ajoute des répliques à la suite de celles en cours
# interrompre = true : on coupe ce qui est en train d'être dit (game over, fin...)
func dire(repliques: Array, interrompre := false):
	if interrompre:
		file_attente.clear()
		durees_voix.clear()
		voix.stop()
	for replique in repliques:
		file_attente.append(replique)
	if interrompre or not bandeau.visible:
		_replique_suivante()


func est_en_train_de_parler() -> bool:
	return bandeau.visible


# pour baisser la musique pendant que Marcel parle
func voix_en_cours() -> bool:
	return voix.playing


func _process(delta):
	if not bandeau.visible:
		return
	temps_restant -= delta
	if temps_restant <= 0:
		_replique_suivante()


func _replique_suivante():
	if file_attente.is_empty():
		# on laisse finir la voix avant d'enlever le dernier sous-titre
		if voix.playing:
			temps_restant = voix.stream.get_length() - voix.get_playback_position() + 0.3
			return
		bandeau.hide()
		fini.emit()
		return

	var replique: Array = file_attente.pop_front()
	nom.text = replique[0]
	texte.text = replique[1]
	bandeau.show()

	# temps d'affichage selon la longueur du texte
	temps_restant = TEMPS_MINIMUM + replique[1].length() * TEMPS_PAR_LETTRE

	var a_une_voix: bool = replique.size() >= 3 and replique[2] != "" and ResourceLoader.exists(replique[2])
	var suite_de_voix: bool = replique.size() >= 3 and replique[2] == ""
	if a_une_voix:
		voix.stream = load(replique[2])
		voix.play()
		_partager_voix(replique)
	if (a_une_voix or suite_de_voix) and not durees_voix.is_empty():
		temps_restant = durees_voix.pop_front()


# La voix qui commence couvre cette réplique et les suivantes marquées "".
# Chacune reste affichée une part du son proportionnelle à son nombre de lettres.
func _partager_voix(premiere: Array):
	var textes := [premiere[1]]
	for suivante in file_attente:
		if suivante.size() < 3 or suivante[2] != "":
			break
		textes.append(suivante[1])
	var lettres := 0
	for texte in textes:
		lettres += texte.length()
	durees_voix.clear()
	for texte in textes:
		durees_voix.append(voix.stream.get_length() * texte.length() / lettres)
	durees_voix[-1] += 0.3  # un petit temps après la fin de la voix


func _creer_interface():
	layer = 5

	bandeau = VBoxContainer.new()
	bandeau.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bandeau.offset_left = 200
	bandeau.offset_right = -200
	bandeau.offset_top = -300
	bandeau.offset_bottom = -170
	bandeau.alignment = BoxContainer.ALIGNMENT_END
	add_child(bandeau)

	nom = _creer_texte(30, Couleurs.IMPORTANTE)
	texte = _creer_texte(36, Color.WHITE)
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	voix = AudioStreamPlayer.new()
	voix.volume_db = 6.0  # plus fort que les sons du jeu
	add_child(voix)


func _creer_texte(taille: int, couleur: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", taille)
	label.add_theme_color_override("font_color", couleur)
	label.add_theme_color_override("font_outline_color", Couleurs.FONCEE)
	label.add_theme_constant_override("outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bandeau.add_child(label)
	return label
