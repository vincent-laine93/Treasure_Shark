class_name Scenario

# Tous les textes du jeu (script de Treasure Shark).
# Pour changer l'histoire, il suffit de modifier ce fichier.
#
# Une réplique = ["Nom du personnage", "Texte affiché en sous-titre"]
# Plus tard, pour la voix, on ajoutera le fichier son en 3e :
#   ["Marcel", "Je m'appelle Marcel.", "res://voix/intro_1.ogg"]


# ---------- Scène 1 : l'île de la Débrouille ----------

# texte tapé à la machine sur l'écran noir
const INTRO_TEXTE := "L'inflation a tout dévoré.\nLes océans sont vides, les portefeuilles aussi.\nIl ne reste qu'un mythe pour sauver le peuple."

const INTRO := [
	["Marcel", "Je m'appelle Marcel. Avant, je pêchais le bar. Aujourd'hui, je pêche la survie."],
	["Marcel", "La crise a eu ma peau. J'ai dû vendre mes filets, mes cannes, mon sonar, et même ma dent en or."],
	["Marcel", "Tout ça... pour un misérable jerrican de sans-plomb."],
	["Marcel", "Mon réservoir est entamé, et mon compte est à sec."],
	["Marcel", "La prophétie dit que le \"Gilet Jaune Ultime\" est caché dans la baie. Trois coffres. Un seul contient la relique."],
	["Marcel", "Si j'arrive à le mettre sur la Statue de la Liberté Économique... la donne changera."],
	["Marcel", "C'est mon dernier voyage. Je dois tenter le tout pour le tout !"],
]


# ---------- Scène 2 : la chasse aux coffres et la course au carburant ----------

const DEPART_BATEAU := [
	["Marcel", "Allez, ma vieille chaloupe. Tiens le coup !"],
	["Marcel", "Faut garder un œil sur le voyant d'essence... Si la réserve tombe à sec, c'est la fin assurée au milieu des vagues."],
]

const JERRICAN := [
	["Marcel", "Un jerrican ! Ça redonne un peu de jus à la bécane !"],
]

const COFFRE_1 := [
	["Marcel", "Qu'est-ce que... Un numéro vert imprimé sur un bout de carton mouillé ? Inutile ! On continue !"],
]

const ESSENCE_BASSE := [
	["Marcel", "La manette passe au rouge ! Il me faut du carburant d'urgence avant le prochain coffre !"],
]

const COFFRE_2 := [
	["Marcel", "Une promesse électorale de 2017 à moitié rouillée ?! Bordel... Plus qu'une chance ou je finis en rade complète."],
]

const GILET := [
	["Marcel", "Le Gilet Jaune Ultime... Tissé en fils de pouvoir d'achat pur."],
	["Marcel", "Ses bandes réfléchissantes pourraient aveugler un huissier. Je l'ai !"],
]

# ce qu'on trouve dans les coffres vides
const OBJET_COFFRE_1 := "un numéro vert sur un carton mouillé"
const OBJET_COFFRE_2 := "une promesse électorale de 2017"

const GAME_OVER_PANNE := [
	["Marcel", "Plus une goutte... L'inflation a eu raison de nous."],
]
const TEXTE_GAME_OVER_PANNE := "GAME OVER - PANNE SÈCHE"


# ---------- Scène 3 : le sacrifice final ----------

const ARRIVEE_STATUE := [
	["Marcel", "Pile à sec... Mais la voilà, la Statue de la Liberté Économique !"],
]

const MARCHE_STATUE := [
	["Marcel", "Ça, c'est pour mes filets... Ça, c'est pour la TVA... les impôts et j'en passe..."],
]


# ---------- Scène 4 : épilogue ----------

const EPILOGUE := [
	["Marcel", "Et c'est ainsi que la lumière est revenue."],
	["Marcel", "Pas celle des marchés financiers ou des grands discours. Celle de la rue."],
	["Marcel", "La crise n'a pas disparu du jour au lendemain, mais la statue porte désormais nos couleurs."],
	["Marcel", "On leur a rappelé une chose essentielle :"],
	["Marcel", "la vraie valeur d'un pays, ce ne sont pas ses indices boursiers, c'est la dignité de ceux qui le font vivre."],
]
const TEXTE_FIN := "FIN"


# ---------- Les missions, dans l'ordre (affichées en haut à droite) ----------

const MISSIONS := [
	{"id": "sortir", "objectif": "Sors de la cabane"},
	{"id": "jerrican", "objectif": "Récupère ton jerrican dans le coffre de la plage"},
	{"id": "plein", "objectif": "Fais le plein du Pouvoir d'Achat"},
	{"id": "bateau", "objectif": "Monte à bord du Pouvoir d'Achat"},
	{"id": "gilet", "objectif": "Trouve le Gilet Jaune Ultime dans un des trois coffres"},
	{"id": "statue", "objectif": "Rejoins la Statue de la Liberté Économique"},
	{"id": "poser", "objectif": "Mets le gilet sur la statue"},
]
