extends Node

@onready var fade_overlay = %FadeOverlay
@onready var StatusDot = %StatusDot
@onready var StatusLabel = %StatusLabel
@onready var StartButton = %StartButton

func _ready() -> void:
	SerialManager.connecte.connect(_on_arduino_connected)
	SerialManager.deconnecte.connect(_on_arduino_disconnected)

	if SerialManager.est_connecte:
		_on_arduino_connected()
	else:
		StatusDot.modulate = Color.RED
		StatusLabel.text = "Arduino Pas Connectée"
		StartButton.disabled = true

func _on_arduino_connected():
	StatusDot.modulate = Color.GREEN
	StatusLabel.text = "Arduino Connecté"
	StartButton.disabled = false

func _on_arduino_disconnected():
	StatusDot.modulate = Color.RED
	StatusLabel.text = "Déconnecté"
	StartButton.disabled = true

# même jeu, mais avec la manette
func _on_start_button_pressed() -> void:
	SerialManager.manette_active = true
	fade_overlay.modulate.a = 1
	get_tree().change_scene_to_file("res://monde.tscn")

func _on_start_clavier_souris_button_pressed() -> void:
	SerialManager.manette_active = false
	fade_overlay.modulate.a = 1
	get_tree().change_scene_to_file("res://monde.tscn")
