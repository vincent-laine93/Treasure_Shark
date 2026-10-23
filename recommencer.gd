extends CanvasLayer

# R : "Voulez-vous recommencer ?" (R oui, E non)
# Sert aussi pour le game over et la fin, là seul R marche.

var fond: ColorRect
var message: Label
var partie_perdue := false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # pour que ça marche quand le jeu est en pause
	layer = 10

	fond = ColorRect.new()
	fond.color = Color(Couleurs.FONCEE, 0.75)
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	fond.hide()

	message = Label.new()
	message.text = "Voulez-vous recommencer ?\n\nR : oui        E : non"
	message.add_theme_font_size_override("font_size", 64)
	message.add_theme_color_override("font_outline_color", Couleurs.FONCEE)
	message.add_theme_constant_override("outline_size", 10)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.add_child(message)


func _unhandled_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.physical_keycode == KEY_R:
		get_viewport().set_input_as_handled()
		if fond.visible:
			get_tree().paused = false
			get_tree().reload_current_scene()
		else:
			fond.show()
			get_tree().paused = true

	elif event.physical_keycode == KEY_E and fond.visible and not partie_perdue:
		get_viewport().set_input_as_handled()
		fond.hide()
		await get_tree().process_frame  # sinon le joueur reçoit aussi le E
		get_tree().paused = false


func game_over(titre := "GAME OVER", texte := "Tu n'as plus de vie..."):
	partie_perdue = true
	message.text = titre + "\n\n"
	if texte != "":
		message.text += texte + "\n\n"
	message.text += "R : recommencer"
	message.add_theme_color_override("font_color", Couleurs.IMPORTANTE)
	message.add_theme_color_override("font_outline_color", Couleurs.SECONDAIRE)
	fond.show()
	get_tree().paused = true


func fin(titre: String, texte: String):
	partie_perdue = true
	message.text = titre + "\n\n" + texte + "\n\nR : rejouer"
	message.add_theme_color_override("font_color", Couleurs.IMPORTANTE)
	message.add_theme_constant_override("outline_size", 16)
	fond.color = Color(Couleurs.FONCEE, 0.45)  # plus clair pour voir la statue
	fond.show()
