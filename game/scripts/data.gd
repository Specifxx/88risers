extends RefCounted
## Authored content for the slice: the founders, the people of Tallow Ford, and the Pinned.

const TOPIC_JOIN := "Becoming a Riser"

## How each person looks. The six founders with cards on 88risers.com follow those cards:
## hair, beard, build and what they wear. Tommy and Luie have no card yet.
const BLACK := Color(0.2, 0.2, 0.22)
const LOOKS := {
	"harry": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "tint": Color(0.95, 0.95, 0.98), "cloth": "T_Peasant_2_BaseColor.jpg", "build": 0.95, "portrait": "harry"},
	"george": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "tint": BLACK, "portrait": "george"},
	"phillip": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "tint": Color(1.0, 0.22, 0.2), "build": 1.1, "portrait": "phillip"},
	"bhavya": {"body": "Male_Peasant", "hair": "Hair_Long", "beard": true, "tint": Color(0.42, 0.42, 0.45), "portrait": "bhavya"},
	"kelvin": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "tint": BLACK, "build": 1.2, "portrait": "kelvin"},
	"tommy": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "tint": BLACK},
	"luie": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "tint": BLACK},
	"erick": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "tint": BLACK, "portrait": "erick"},
	"mara": {"body": "Female_Peasant", "hair": "Hair_Long", "tint": Color(0.68, 0.84, 1.0)},
	"ned": {"body": "Male_Peasant", "hair": "Hair_Buzzed"},
	"ivo": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "beard": true, "tint": Color(1.0, 0.6, 0.5)},
	"pell": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "beard": true, "cloth": "T_Peasant_2_BaseColor.jpg", "tint": Color(0.8, 0.75, 0.95)},
	"hesper": {"body": "Female_Peasant", "hair": "Hair_Buns", "cloth": "T_Peasant_2_BaseColor.jpg", "hair_tint": Color(0.8, 0.8, 0.8)},
	"wren": {"body": "Female_Ranger", "hair": "Hair_Long", "hair_tint": Color(0.45, 0.25, 0.12)},
}

## Temperament, the fixed part of each mind: how readily good and bad experiences change
## them, where they start with a stranger, and how much they talk.
const MINDS := {
	"harry": {"open": 1.0, "grudge": 1.0, "warmth": 0.2, "chatty": 0.5},
	"george": {"open": 1.0, "grudge": 0.8, "warmth": 0.2, "chatty": 0.7},
	"phillip": {"open": 0.7, "grudge": 1.3, "warmth": 0.0, "chatty": 0.3},
	"bhavya": {"open": 1.3, "grudge": 0.6, "warmth": 0.4, "chatty": 0.6},
	"kelvin": {"open": 0.8, "grudge": 1.2, "warmth": 0.0, "chatty": 0.3},
	"tommy": {"open": 1.1, "grudge": 0.9, "warmth": 0.3, "chatty": 0.9},
	"luie": {"open": 0.8, "grudge": 1.0, "warmth": 0.0, "chatty": 0.3},
	"erick": {"open": 1.0, "grudge": 0.9, "warmth": 0.2, "chatty": 0.6},
	"mara": {"open": 0.9, "grudge": 1.1, "warmth": 0.0, "chatty": 0.4},
	"ned": {"open": 1.4, "grudge": 0.5, "warmth": 0.4, "chatty": 0.9},
	"ivo": {"open": 0.35, "grudge": 1.6, "warmth": -0.4, "chatty": 0.6},
	"pell": {"open": 0.7, "grudge": 1.5, "warmth": -0.1, "chatty": 0.8},
	"hesper": {"open": 0.9, "grudge": 0.8, "warmth": 0.1, "chatty": 1.0},
	"wren": {"open": 1.25, "grudge": 1.1, "warmth": -0.1, "chatty": 0.4},
}

## Where people drift to when they are not at their post.
const SPOTS := {
	"rhodes": [Vector3(22.6, 0, -22.4), Vector3(25.4, 0, -22.0), Vector3(21.5, 0, 12.5), Vector3(18.5, 0, 15.5), Vector3(2, 0, 2.5), Vector3(-3, 0, 3), Vector3(12, 0, -10.5), Vector3(31, 0, 1.5), Vector3(-16, 0, 6)],
	"tallow": [Vector3(231.6, 0, 23.4), Vector3(228.3, 0, 21.2), Vector3(212, 0, 8.5), Vector3(236, 0, 7.5), Vector3(207, 0, 17.5), Vector3(226, 0, 31)],
}

## Things people say aloud as you pass, by how they feel about you.
const BARKS := {
	"trusting": ["Pilgrim! Good to see you.", "Walk safe out there.", "If you need anything, ask."],
	"friendly": ["Morning, pilgrim.", "Still in one piece, I see.", "Back again?"],
	"reserved": ["Pilgrim.", "...", "Hm."],
	"used to you": ["You again.", "Pilgrim.", "Still here, then."],
	"wary": ["I'm watching you.", "Keep walking.", "Mind yourself."],
	"hostile": ["Stay away from me.", "We know what you did.", "Get out."],
	"afraid": ["Please. Don't.", "I didn't see anything. I swear it.", "Stay back. Please stay back."],
}

## Shouted in the moment by someone who sees it happen.
const SHOUTS := {
	"violence": ["You struck %s!", "Leave %s alone!", "Murder! Somebody!", "Get the Wall! Get the Wall!"],
	"theft": ["Thief!", "I saw that!", "That isn't yours!"],
}

## How the same answer comes out, depending on how they feel about you.
const TONES := {
	"afraid": "They will not meet your eye, and answer quickly, to have it over with.\n\n\"%s\"",
	"wary": "They look you over before answering.\n\n\"%s\" They say no more than that.",
	"trusting": "\"%s\"\n\nThey say it easily, the way people talk to their own.",
}

## Things people will not discuss with someone they do not trust.
const PERSONAL := ["Your father", "The stone lion", "The last pilgrims", "The pyre", "Wukhan", "The Lion"]

## What they pass on to each other, and what you overhear.
const GOSSIP := {
	"raised": "They say the road's quieter. The pilgrim raised one for good.",
	"raised_kin": "Oswin's gone from the jetty. Risen, Mara says.",
	"theft": "Pell's strongbox was emptied. The pilgrim was seen at it.",
	"violence": "%s is dead. It was the pilgrim.",
	"gift": "The pilgrim's been handing out chalk.",
	"trained": "Ned's been out past the fence with the pilgrim. Standing his ground, too.",
	"helped": "The pilgrim did right by one of ours.",
}

const FOUNDERS := [
	{
		"id": "harry", "name": "Harry Lu", "role": "Head Riser", "pos": Vector3(0, 0, -2), "color": Color(0.8, 0.6, 0.18),
		"greet": "You made it inside the Ring. Good. There's work, and not enough of us to do it.",
		"topics": {
			"The Pilgrimage": "Eighty-eight Risers once held the whole world. We are eight. Above the Register it says: \"If he fails, gather the 88.\" So we gather.\n\nStart with Tallow Ford. Go out the east gate and keep to the road. Bring me three who are willing and able, and I'll know this can be done.",
			"The rite": "Put the Pinned down first. Then throw chalk, so you can see who it was. Then the strap, to hold the spirit against the dark. Then talk to it. It won't rise until it's ready to go, and the strap won't hold for ever. When it's ready, say the words.\n\nIf you only kill it, it will be back.",
			"Wukhan": "He protects the Ring. He has done nothing else since before my grandfather's time. With 88 of us, they say, he can be mended.",
			"The Lion": "In the heavens, watching. So we're taught.",
		},
	},
	{
		"id": "george", "name": "George Lu", "role": "Keeper of the Register", "pos": Vector3(-3.5, 0, -7.5), "color": Color(0.55, 0.2, 0.2),
		"greet": "Every Riser there is has a line on that board. Most of it is empty.",
		"topics": {
			"The Register": "",
			"The first 88": "They did the rite by hand for the whole world. Then they built Wukhan to do it for them, and stopped. The line above the Register is the only thing they left us.",
			"Tallow Ford": "Out the east gate and stay on the road. It bends north round a stand of pines, then swings south again. You'll see the roofs before you see the river. Don't leave the road if you can help it.",
		},
	},
	{
		"id": "phillip", "name": "Phillip Nguyen", "role": "Captain of the wall", "pos": Vector3(6, 0, -27), "color": Color(0.25, 0.38, 0.28),
		"greet": "If you're going outside, you'd better be able to hit something.",
		"topics": {
			"Fighting the Pinned": "A plain strike costs you nothing. A heavy one hits twice as hard and takes your wind. Guard when you're spent: you take half and get your breath back. And there's no shame in running. They stop at the Ring.",
		},
	},
	{
		"id": "bhavya", "name": "Bhavya Sharma", "role": "Healer", "pos": Vector3(-12, 0, 14), "color": Color(0.85, 0.85, 0.8),
		"greet": "Sit down. Let me look at you.",
		"topics": {
			"The dying": "Anyone can throw chalk and tie a strap. That's what keeps a person from sinking until one of us can get there. The villages never have enough of either.",
		},
	},
	{
		"id": "kelvin", "name": "Kelvin Gian", "role": "Warden of the gate", "pos": Vector3(37, 0, 5), "color": Color(0.3, 0.3, 0.36),
		"greet": "Gate's open. It's always open. They just can't use it.",
		"topics": {
			"Outside": "They can't cross the Ring. You can. Once you're past me, everything dead out there will come for you. If it goes badly, run for the gate. They stop at the line.",
		},
	},
	{
		"id": "tommy", "name": "Tommy Cao", "role": "Trader", "pos": Vector3(14, 0, -12), "color": Color(0.2, 0.42, 0.5),
		"greet": "Chalk, straps, bread. Everything a pilgrim runs out of.",
		"topics": {
			"Tallow Ford": "They'll trade with you before they'll trust you. Pell keeps the shop there. Don't touch what's his.",
		},
	},
	{
		"id": "luie", "name": "Luie Hoang", "role": "Undertaker", "pos": Vector3(-15, 0, -13), "color": Color(0.16, 0.16, 0.18),
		"greet": "Mind where you step. He takes up most of the village.",
		"topics": {
			"Dangerous dead": "The longer they've been down, the harder they pull on the strap. If one's too strong for you, walk away. It will still be there tomorrow.",
			"Wukhan": "People say he can be mended. Go and listen to him some time. He only ever says the one thing.",
		},
	},
	{
		"id": "erick", "name": "Erick Kang", "role": "Has been furthest out", "pos": Vector3(22, 0, 12), "color": Color(0.45, 0.33, 0.2),
		"greet": "You're the new pilgrim. They haven't sent one of those in a long time.",
		"topics": {
			"The last Pilgrimage": "134 years ago. Five went out. The villages still remember them, and not kindly. Old Hesper at Tallow Ford will tell you about it, if she likes you.",
			"Recruits": "Every village has a few who'd be willing and a few who'd be able. Hardly ever the same people. You'll have to work on one or the other, and some you'll never get.",
		},
	},
]

const VILLAGERS := [
	{
		"id": "mara", "name": "Mara Quill", "role": "Ferrywoman", "pos": Vector3(244, 0, 30), "color": Color(0.2, 0.35, 0.5),
		"willing": 20, "willing_cap": 40, "capable": 75, "disp": 40,
		"greet": "If you want the far bank, the river's too low for the ferry. Walk it.",
		"topics": {
			"The ford": "I pole the ferry when the river's up. My father did it before me.",
			"Your father": "Oswin. The river took him two winters back, at the old jetty south of the village. Nobody was with him. He's still down there, walking the planks like he's waiting on a fare. I can't go near him.",
		},
		"no_willing": "And leave him pinned down there? No. Don't ask me again.",
		"no_capable": "", "yes": "You did for him what none of us could. If that's the work, I'll do it.",
	},
	{
		"id": "ned", "name": "Ned Harrow", "role": "Farmhand", "pos": Vector3(222, 0, 34), "color": Color(0.5, 0.42, 0.22),
		"willing": 80, "willing_cap": 100, "capable": 25, "disp": 50,
		"greet": "You came up the road? On your own? And you're still walking?",
		"topics": {
			"The road": "I've not been past the last fence since I was small. You hear them at night.",
		},
		"no_willing": "", "no_capable": "I'd go tomorrow. I've wanted out of this mud all my life. But I've never stood in front of one of them and not run.",
		"yes": "I can do this. I didn't think so last week. Put my name down.",
	},
	{
		"id": "ivo", "name": "Ivo Brand", "role": "Pyre-keeper", "pos": Vector3(214, 0, 8), "color": Color(0.5, 0.18, 0.12),
		"willing": 0, "willing_cap": 10, "capable": 65, "disp": 15,
		"greet": "Rhodes. I wondered when you'd remember we were here.",
		"topics": {
			"Rhodes": "You sat behind your wall for 134 years, and now you want our dead. Why should anyone here trust that?",
			"The pyre": "We burn ours. Nothing sinks that's ash. It works when we're quick. We aren't always quick.",
		},
		"no_willing": "No. And you can stop asking the young ones, too.",
		"no_capable": "", "yes": "",
	},
	{
		"id": "pell", "name": "Pell", "role": "Shopkeeper", "pos": Vector3(236, 0, 9), "color": Color(0.35, 0.3, 0.42),
		"willing": 30, "willing_cap": 45, "capable": 30, "disp": 35,
		"greet": "Buying? Good. Looking? Look from there.",
		"topics": {
			"Prices": "A strap costs twelve here because it costs blood to bring it up that road. Take it up with the dead.",
		},
		"no_willing": "I've a shop. Who runs it when I'm off chasing the dead? No.",
		"no_capable": "", "yes": "",
	},
	{
		"id": "hesper", "name": "Old Hesper", "role": "Elder", "pos": Vector3(226, 0, 22), "color": Color(0.55, 0.52, 0.48),
		"willing": 60, "willing_cap": 60, "capable": 5, "disp": 30,
		"greet": "A pilgrim. I was told there'd be no more of you.",
		"topics": {
			"The last pilgrims": "My grandmother saw them. Five, and one of them carried the words. They went east full of kindness and came back west full of anger. Something out there told them your machine was the cause of all this. They went home to have it out with him. None of them came out of the Ring again.",
			"The stone lion": "Traders from the far east talk of an old carving of a lion with its shoulders broken, and people round it who never stay dead. I never believed a word.",
		},
		"no_willing": "", "no_capable": "Child, I can't get up that hill without a stick. Ask someone with knees.",
		"yes": "",
	},
	{
		"id": "wren", "name": "Wren Calloway", "role": "Hunter", "pos": Vector3(240, 0, 20), "color": Color(0.24, 0.36, 0.2),
		"willing": 65, "willing_cap": 100, "capable": 70, "disp": 20,
		"greet": "You're from the Ring. Then you'll know why the road's the way it is.",
		"topics": {
			"The road": "I've put down the same ones a dozen times. They're up again by morning. Raise a few properly, so they stay gone, and I'll believe Rhodes is good for something.",
		},
		"no_willing": "", "no_capable": "",
		"no_trust": "I don't know you yet. Show me the road can be made safe.",
		"yes": "That road's quieter than I've ever known it. All right. I'm in.",
	},
]

## The Pinned. grip = how many true things it must hear before it will go.
## strain = turns it takes off the strap.
const SPIRITS := {
	"carter": {
		"shape": "A Pinned", "name": "Tobin Marsh, a carter", "hp": 14, "atk": 3, "grip": 2, "strain": 0,
		"seen": "The chalk settles on a broad man with a whip coiled at his belt. He keeps looking back down the road, counting something that isn't there.",
		"say": [
			["Your load reached the ford. Someone carried it the rest of the way.", "\"All of it? ... All of it.\" His shoulders drop.", true],
			["Nobody blames you for being late.", "\"I was never late. Not once before.\" He almost smiles.", true],
			["The road is safe now.", "\"The road was never the trouble.\" He pulls at the strap.", false],
			["Rhodes commands you to rise.", "He does not seem to hear you.", false],
		],
	},
	"guard": {
		"shape": "A Pinned", "name": "Edda Vane, of the Wall", "hp": 20, "atk": 4, "grip": 2, "strain": 1,
		"seen": "A soldier in a Wall House coat, one hand still raised as if to knock. She is facing the Ring.",
		"say": [
			["The gate is open. I walked out of it this morning.", "\"Open.\" Her raised hand comes down.", true],
			["You held the line. You're relieved.", "She straightens, and salutes nobody.", true],
			["Wukhan protects the Ring.", "\"It did not protect me.\" The strap creaks.", false],
			["You should have run faster.", "She turns her back on you.", false],
		],
	},
	"child": {
		"shape": "A small Pinned", "name": "Pip, a child", "hp": 10, "atk": 2, "grip": 2, "strain": 0,
		"seen": "It is a child, barefoot, standing exactly where somebody once told them to wait.",
		"say": [
			["She looked for you. She never stopped looking.", "\"She came back?\" The small face lifts.", true],
			["You don't have to wait here any more.", "\"I'm allowed to go?\"", true],
			["Be brave.", "\"I have been.\" The child sits down in the road.", false],
			["Where is your mother?", "The child only points up the road, and waits.", false],
		],
	},
	"porter": {
		"shape": "A tall Pinned", "name": "A porter of the last Pilgrimage", "hp": 28, "atk": 5, "grip": 3, "strain": 2, "leaves": "old_sword",
		"seen": "An old, old shape under a pack frame that rotted away long ago. It is still bent as if carrying it. It has been here 134 years.",
		"say": [
			["They got home. All five reached the Ring.", "\"Then it was carried.\" The bent back eases a little.", true],
			["It has been 134 years. You can put the pack down.", "\"So long?\" Something slides from its shoulders.", true],
			["I'm carrying it now.", "It looks at you for a long time, and nods.", true],
			["They died for nothing.", "The strap goes taut as wire.", false],
			["What did the dragon tell you?", "\"The machine. The machine. The machine.\" It will say nothing else.", false],
		],
	},
	"farmer": {
		"shape": "A Pinned", "name": "Hale Harrow, a farmer", "hp": 16, "atk": 3, "grip": 2, "strain": 0,
		"seen": "A farmer with a scythe-handle and no blade, cutting at wheat that was harvested years ago.",
		"say": [
			["The field was brought in. Your people ate that winter.", "He lowers the handle. \"All in?\"", true],
			["Ned's grown. He's stronger than he thinks.", "\"The boy?\" A dry laugh. \"Good.\"", true],
			["The harvest is lost.", "He goes back to cutting, faster.", false],
			["This land belongs to the dead now.", "\"It's mine.\" He will not look at you.", false],
		],
	},
	"oswin": {
		"shape": "A Pinned on the jetty", "name": "Oswin Quill, ferryman", "hp": 20, "atk": 4, "grip": 3, "strain": 1,
		"seen": "An old man with a ferry pole, wet through. He is watching the far bank for someone who needs to cross.",
		"say": [
			["Mara sent me.", "\"Mara.\" He turns from the river for the first time.", true],
			["She poles the ferry now. Nobody has been left on the bank.", "\"She was always better at it than me.\"", true],
			["There are no more fares tonight, Oswin. You can tie up.", "He lays the pole down along the planks, carefully.", true],
			["The river took you.", "\"I know what the river did.\" He turns back to the water.", false],
			["Come with me to Rhodes.", "\"I don't leave my crossing.\"", false],
		],
	},
}

## A spirit for someone the player killed.
static func victim_spirit(who: String) -> Dictionary:
	return {
		"shape": "A Pinned", "name": who, "hp": 18, "atk": 5, "grip": 2, "strain": 1,
		"seen": "The chalk settles and it is %s. They know exactly who you are." % who,
		"say": [
			["I did this to you. I'm sorry.", "They watch you. The pull on the strap slackens.", true],
			["I won't ask you to forgive me.", "\"Good.\" But something in them lets go.", true],
			["You gave me no choice.", "\"There was a choice.\" The strap groans.", false],
			["It was nothing personal.", "They lunge against the strap.", false],
		],
	}

const ROAD_PINNED := [
	["carter", Vector3(78, 0, -6)],
	["child", Vector3(112, 0, -22)],
	["guard", Vector3(58, 0, 14)],
	["farmer", Vector3(176, 0, 16)],
	["porter", Vector3(146, 0, -34)],
	["oswin", Vector3(262, 0, 64)],
]
