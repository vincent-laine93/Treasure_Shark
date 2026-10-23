extends CanvasLayer

# Les sous-titres en bas de l'écran, une réplique après l'autre.
# Si une réplique a un fichier de voix on le joue.
# Quand une voix dure plusieurs répliques, les suivantes ont "" à la place du fichier.

signal fini

var file_attente = []
var temps_restant := 0.0
var durees = []  # combien de temps on affiche chaque réplique de la voix en cours

var bandeau: VBoxContainer
var nom: Label
var texte: Label
var voix: AudioStreamPlayer


func _ready():
	layer = 5
	bandeau = VBoxContainer.new()
	bandeau.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bandeau.offset_left = 200
	bandeau.offset_right = -200
	bandeau.offset_top = -300
	bandeau.offset_bottom = -170
	bandeau.alignment = BoxContainer.ALIGNMENT_END
	add_child(bandeau)
	bandeau.hide()

	nom = _creer_texte(30, Couleurs.IMPORTANTE)
	texte = _creer_texte(36, Color.WHITE)
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	voix = AudioStreamPlayer.new()
	voix.volume_db = 6.0
	add_child(voix)


# interrompre = true pour couper ce qui est en train d'être dit
func dire(repliques: Array, interrompre := false):
	if interrompre:
		file_attente.clear()
		durees.clear()
		voix.stop()
	file_attente.append_array(repliques)
	if interrompre or not bandeau.visible:
		_replique_suivante()


func est_en_train_de_parler() -> bool:
	return bandeau.visible


func voix_en_cours() -> bool:
	return voix.playing


func _process(delta):
	if bandeau.visible:
		temps_restant -= delta
		if temps_restant <= 0:
			_replique_suivante()


func _replique_suivante():
	if file_attente.is_empty():
		# on attend que la voix soit finie avant d'enlever le sous-titre
		if voix.playing:
			temps_restant = voix.stream.get_length() - voix.get_playback_position() + 0.3
			return
		bandeau.hide()
		fini.emit()
		return

	var replique = file_attente.pop_front()
	nom.text = replique[0]
	texte.text = replique[1]
	bandeau.show()
	temps_restant = 2.5 + replique[1].length() * 0.06

	if replique.size() < 3:
		return
	if replique[2] != "":
		voix.stream = load(replique[2])
		voix.play()
		_calculer_durees(replique)
	if not durees.is_empty():
		temps_restant = durees.pop_front()


# on partage la durée de la voix entre ses répliques, selon le nombre de lettres
func _calculer_durees(premiere):
	var textes = [premiere[1]]
	for suivante in file_attente:
		if suivante.size() < 3 or suivante[2] != "":
			break
		textes.append(suivante[1])
	var lettres = 0
	for t in textes:
		lettres += t.length()
	durees.clear()
	for t in textes:
		durees.append(voix.stream.get_length() * t.length() / lettres)
	durees[-1] += 0.3


func _creer_texte(taille, couleur) -> Label:
	var label = Label.new()
	label.add_theme_font_size_override("font_size", taille)
	label.add_theme_color_override("font_color", couleur)
	label.add_theme_color_override("font_outline_color", Couleurs.FONCEE)
	label.add_theme_constant_override("outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bandeau.add_child(label)
	return label
