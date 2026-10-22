extends StaticBody3D

# Un coffre qu'on ouvre avec E.
# En mer il flotte sur les vagues et coule quand on l'ouvre.
# Sur une île (sur_terre coché) il ne bouge pas et disparaît quand on l'ouvre.

const AMPLITUDE := 0.15
const PERIODE := 3.0

@export var contenu := ""  # vide = rien dedans
@export var sur_terre := false
@export var muet := false  # pas de son de trésor quand on s'approche

var ouvert := false
var temps := randf() * PERIODE  # pour que les coffres ne bougent pas tous en même temps
var son: Node3D = null

@onready var modele: Node3D = $Modele


func _ready():
	add_to_group("coffres")
	if not muet:
		son = Sons.ajouter_proximite(self, "tresor")


func _process(delta):
	if sur_terre:
		return
	temps += delta
	modele.position.y = sin(temps * TAU / PERIODE) * AMPLITUDE


func ouvrir() -> String:
	ouvert = true
	if son != null:
		son.queue_free()  # plus de son de trésor une fois ouvert
	Sons.jouer("tresor_ouvert")
	$CollisionShape3D.set_deferred("disabled", true)

	var tween := create_tween()
	if sur_terre:
		tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.8).set_delay(1.0)
	else:
		tween.tween_property(self, "position:y", position.y - 2.0, 3.0).set_delay(1.0)
	tween.tween_callback(hide)

	return contenu
