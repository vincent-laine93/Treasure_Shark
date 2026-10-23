extends StaticBody3D

# Un coffre qu'on ouvre avec E.
# En mer il flotte et coule quand on l'ouvre, sur une île il rétrécit et disparaît.

@export var contenu := ""
@export var sur_terre := false
@export var muet := false  # pas de son quand on s'approche

var ouvert := false
var temps = randf() * 3  # pour que les coffres ne bougent pas tous pareil


func _ready():
	add_to_group("coffres")


func _process(delta):
	if not sur_terre:
		temps += delta
		$Modele.position.y = sin(temps * TAU / 3) * 0.15


func ouvrir() -> String:
	ouvert = true
	Sons.jouer("SFX_Treasure_Collected")
	$CollisionShape3D.set_deferred("disabled", true)
	var tween = create_tween()
	if sur_terre:
		tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.8).set_delay(1.0)
	else:
		tween.tween_property(self, "position:y", position.y - 2.0, 3.0).set_delay(1.0)
	tween.tween_callback(hide)
	return contenu
