extends RefCounted
## Who is at the meet. The eight founders are real members of the club; how they look follows
## their cards on 88risers.com, and what they say here is placeholder banter for them to replace.

const BLACK := Color(0.2, 0.2, 0.22)

const FOUNDERS := [
	{"id": "harry", "name": "Harry Lu", "role": "70kg Arm Wrestling Champion", "strength": 82, "portrait": "harry",
		"look": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "tint": Color(0.95, 0.95, 0.98), "cloth": "T_Peasant_2_BaseColor.jpg", "build": 0.95},
		"mind": {"open": 1.0, "grudge": 1.0, "warmth": 0.3, "chatty": 0.6},
		"life": {"pull": 0.8, "eat": 0.3, "talk": 0.8, "rest": 0.2, "quirk": 1.3, "does": "ref"}, "strap": Color(0.95, 0.95, 0.95)},
	{"id": "george", "name": "George Lu", "role": "Founder", "strength": 70, "portrait": "george",
		"look": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "tint": BLACK},
		"mind": {"open": 1.1, "grudge": 0.8, "warmth": 0.3, "chatty": 0.7},
		"life": {"pull": 0.5, "eat": 0.5, "talk": 1.0, "rest": 0.3, "quirk": 1.2, "does": "film"}, "strap": Color(0.93, 0.72, 0.28)},
	{"id": "phillip", "name": "Phillip Nguyen", "role": "80kg NSW Bronze Medalist", "strength": 78, "portrait": "phillip",
		"look": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "tint": Color(1.0, 0.22, 0.2), "build": 1.1},
		"mind": {"open": 0.8, "grudge": 1.2, "warmth": 0.1, "chatty": 0.4},
		"life": {"pull": 1.0, "eat": 0.3, "talk": 0.3, "rest": 0.4, "quirk": 1.2, "does": "drill"}, "strap": Color(0.9, 0.15, 0.15)},
	{"id": "bhavya", "name": "Bhavya Sharma", "role": "70kg Silver Medalist", "strength": 76, "portrait": "bhavya",
		"look": {"body": "Male_Peasant", "hair": "Hair_Long", "beard": true, "tint": Color(0.42, 0.42, 0.45)},
		"mind": {"open": 1.3, "grudge": 0.6, "warmth": 0.4, "chatty": 0.7},
		"life": {"pull": 0.8, "eat": 0.4, "talk": 1.0, "rest": 0.3, "quirk": 1.1, "does": "coach"}, "strap": Color(0.5, 0.3, 0.8)},
	{"id": "kelvin", "name": "Kelvin Gian", "role": "85kg+ Bushy's Amateur 2nd Place", "strength": 84, "portrait": "kelvin",
		"look": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "tint": BLACK, "build": 1.2},
		"mind": {"open": 0.9, "grudge": 1.1, "warmth": 0.1, "chatty": 0.4},
		"life": {"pull": 0.9, "eat": 1.3, "talk": 0.4, "rest": 0.6, "quirk": 0.8, "does": "seconds"}, "strap": Color(0.15, 0.6, 0.3)},
	{"id": "tommy", "name": "Tommy Cao", "role": "Founder", "strength": 68, "portrait": "",
		"look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "tint": BLACK},
		"mind": {"open": 1.1, "grudge": 0.9, "warmth": 0.3, "chatty": 0.9},
		"life": {"pull": 0.5, "eat": 0.7, "talk": 1.1, "rest": 0.2, "quirk": 1.4, "does": "prank"}, "strap": Color(1.0, 0.5, 0.1)},
	{"id": "luie", "name": "Luie Hoang", "role": "Founder", "strength": 68, "portrait": "",
		"look": {"body": "Male_Peasant", "hair": "Hair_SimpleParted", "tint": BLACK},
		"mind": {"open": 0.9, "grudge": 1.0, "warmth": 0.1, "chatty": 0.4},
		"life": {"pull": 0.5, "eat": 0.4, "talk": 0.3, "rest": 1.0, "quirk": 1.2, "does": "water"}, "strap": Color(0.2, 0.5, 0.95)},
	{"id": "erick", "name": "Erick Kang", "role": "80kg Newcastle Champion", "strength": 85, "portrait": "erick",
		"look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "tint": BLACK},
		"mind": {"open": 1.0, "grudge": 0.9, "warmth": 0.2, "chatty": 0.6},
		"life": {"pull": 1.5, "eat": 0.4, "talk": 0.5, "rest": 0.2, "quirk": 1.2, "does": "callout"}, "strap": Color(0.1, 0.1, 0.12)},
]

## Not members: people going past along the foreshore. Some stop to look.
const PASSERS := [
	{"id": "p_jog", "name": "The jogger", "role": "Out for a run", "strength": 50, "pace": 3.4, "stops": 0.25, "look": {"body": "Female_Ranger", "hair": "Hair_Buns", "tint": Color(0.5, 0.8, 1.0)}, "mind": {"warmth": 0.0},
		"chat": ["I'm on a pace here.", "Is this a club? You all just... do this?", "My watch thinks I've stopped. I have stopped."]},
	{"id": "p_dog", "name": "The dog walker", "role": "Walking Biscuit", "strength": 52, "pace": 1.3, "stops": 0.6, "dog": true, "look": {"body": "Female_Peasant", "hair": "Hair_Long", "tint": Color(0.6, 0.85, 0.6)}, "mind": {"warmth": 0.3, "open": 1.3},
		"chat": ["His name's Biscuit. He's very strong, actually.", "We come past every night. He likes the noise.", "Don't feed him chalk."]},
	{"id": "p_tour", "name": "The tourist", "role": "Looking for the ferry", "strength": 48, "pace": 1.2, "stops": 0.9, "look": {"body": "Male_Ranger", "hair": "Hair_SimpleParted", "tint": Color(1.0, 0.9, 0.5)}, "mind": {"warmth": 0.3, "open": 1.4},
		"chat": ["Is this traditional?", "Can I take a picture? I'm taking a picture.", "Which way is the ferry? Not that way?"]},
	{"id": "p_old", "name": "The old bloke", "role": "Says he used to pull", "strength": 88, "pace": 1.0, "stops": 0.8, "look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "beard": true, "tint": Color(0.75, 0.7, 0.6)}, "mind": {"warmth": 0.2},
		"chat": ["I pulled in '84. Different game then.", "No straps in my day. You held on or you didn't.", "That lad's wrist is too low."]},
	{"id": "p_office", "name": "The office worker", "role": "Still on a call", "strength": 54, "pace": 1.7, "stops": 0.3, "look": {"body": "Male_Ranger", "hair": "Hair_SimpleParted", "tint": Color(0.75, 0.8, 0.95)}, "mind": {"warmth": -0.1, "grudge": 1.3},
		"chat": ["Sorry, I'm on mute. What?", "Let's circle back on that.", "I have a stand-up at seven."]},
	{"id": "p_pt", "name": "The personal trainer", "role": "Sizing everyone up", "strength": 72, "pace": 2.0, "stops": 0.7, "look": {"body": "Female_Ranger", "hair": "Hair_BuzzedFemale", "tint": Color(1.0, 0.4, 0.7)}, "mind": {"warmth": 0.1},
		"chat": ["It's all lats. Nobody trains lats.", "I could take half of these.", "Do you do a ladies' class?"]},
	{"id": "p_cousin", "name": "Somebody's cousin", "role": "Was told there'd be food", "strength": 58, "pace": 1.4, "stops": 1.0, "look": {"body": "Female_Peasant", "hair": "Hair_Long", "tint": Color(1.0, 0.7, 0.75)}, "mind": {"warmth": 0.2, "open": 1.2},
		"chat": ["Where are the snacks? I was promised snacks.", "Which one's my cousin? They all look the same from here.", "Is it always this loud?"]},
	{"id": "p_rider", "name": "The delivery rider", "role": "Looking for unit 1408", "strength": 60, "pace": 2.2, "stops": 0.35, "look": {"body": "Male_Ranger", "hood": true, "tint": Color(0.2, 0.75, 0.6)}, "mind": {"warmth": 0.0},
		"chat": ["Did anyone here order pad thai?", "Which tower is B? They're all B.", "Five stars would be appreciated."]},
]

const ALIEN := {"id": "alien", "name": "A visitor", "role": "Not from Rhodes", "strength": 40,
	"look": {"body": "Female_Peasant", "shade": Color(0.25, 0.75, 0.35)}, "mind": {}}

## What people say as you pass, by how things stand between you.
const BARKS := {
	"close": ["There they are!", "Oi, come pull!", "Saved you a spot."],
	"mates": ["Hey, you made it.", "Good to see you.", "You pulling tonight?"],
	"known": ["Hey.", "Evening.", "How's the arm?"],
	"irritated": ["Not now.", "Oh. You.", "Give it a rest."],
	"gone": ["Stay away from me.", "Nope.", "Somebody get this one out of here."],
}

## What they say when you stop for a chat.
const CHAT := {
	"close": ["Honestly, the club's better with you in it.", "Come early next week. I'll show you the thing with the wrist.", "Whatever happens at the table, we're good."],
	"mates": ["You've got a decent side pressure. Work the hand.", "First Sunday of the month, don't forget.", "We're still looking for the 88th Riser, you know."],
	"known": ["Technique beats strength until it doesn't.", "Chalk up. It matters more than people think.", "Pull with your back, not your arm."],
	"irritated": ["What.", "I'm watching the table.", "Keep it short."],
	"gone": ["I've got nothing to say to you."],
}

const HECKLED := ["Really?", "Grow up.", "Say that at the table.", "Mate. Come on.", "Keep talking."]
const SQUARE_UP := ["Right. That's it.", "You want to go? Let's go.", "I warned you."]
const EATING := ["These are actually good.", "Who brought these?", "Mm.", "Last one's mine."]
const WON := ["Yes!", "Still got it.", "Who's next?", "Easy."]
const LOST := ["Again.", "Left arm next.", "I slipped.", "Good pull."]
const ALIEN_LINES := ["Not on meet night!", "Get off our table!", "I am not chalked for this.", "Somebody film this!"]
const AFTER_ALIENS := ["Did that just happen?", "Nobody is going to believe us.", "Same time next week, then."]

## Notes are built from two halves, so nobody can write anything they shouldn't.
const NOTE_A := ["Try", "Beware of", "Praise", "Do not trust", "Remember", "Look for", "Thank you,", "Good luck with"]
const NOTE_B := ["the toproll", "the hook", "Harry's left arm", "the snacks", "the third table", "the sky", "leg day", "chalk", "the 88th Riser", "the water at dusk", "whoever brought these", "the traffic cone"]

## Notes that were already here. Written for the game; not from real members.
const SEEDED := [
	{"spot": 0, "a": "Beware of", "b": "the third table"},
	{"spot": 1, "a": "Praise", "b": "whoever brought these"},
	{"spot": 2, "a": "Look for", "b": "the sky"},
	{"spot": 3, "a": "Try", "b": "the water at dusk"},
]

## Tonight's twist. Everyone turns up in a slightly different state each visit.
const TONIGHT := [
	{"id": "", "line": ""}, {"id": "", "line": ""}, {"id": "", "line": ""},
	{"id": "sore", "line": "Elbow's cooked tonight. I'm only watching.", "pull": 0.0, "quirk": 1.6, "talk": 1.4},
	{"id": "hungry", "line": "Skipped dinner. Don't judge me at the snack table.", "eat": 3.0},
	{"id": "fired", "line": "Feeling strong tonight. Everybody gets a pull.", "pull": 2.5},
	{"id": "tired", "line": "Long shift. I'm going to sit for a bit.", "rest": 3.0, "pull": 0.6},
	{"id": "chatty", "line": "Good day today. Good mood.", "talk": 2.5},
]

const QUIRK := {
	"ref": ["Elbows on the pad.", "Ready... GO!", "Wrists straight!", "Foul. Reset.", "Hold... hold..."],
	"rounds": ["All good here?", "Everyone warmed up?", "Chalk's by the middle table."],
	"film": ["This is going on the page.", "Do that again, I missed it.", "Look at the camera. No, pull, THEN look."],
	"spruik": ["Come have a go! First one's free!", "Arm wrestling! Every month! Free snacks!", "You look strong. You. Yes, you."],
	"drill": ["...forty-eight. Forty-nine.", "One more set.", "Tendons don't train themselves."],
	"coach": ["Higher. Wrist HIGHER.", "You're pulling with your arm. Use your back.", "Shoulder behind the hand. There."],
	"coached": ["I know, I know.", "That IS high.", "Yes, coach."],
	"seconds": ["Just one more.", "These don't count, they're small.", "I'm bulking."],
	"prank": ["Incoming!", "Chalk delivery!", "Heads up!"],
	"water": ["Nice out tonight.", "...", "You can see the bridge lights from here."],
	"callout": ["You. Me. Table.", "I haven't pulled you yet tonight.", "Come on. One pull."],
}
const STRAP_HUNT := ["Where's my strap?", "It was RIGHT here.", "I had it a minute ago."]
const STRAP_ASK := ["Anyone seen my strap?", "Have you got my strap?", "Did I lend you my strap?"]
const STRAP_NO := ["Nope.", "Not me.", "Check your bag again."]
const STRAP_GONE := ["Someone's nicked my strap.", "Fine. No strap. Fine.", "If I find out who took it..."]
const DUSTED := {
	"close": ["Ha! Right. You're getting that back.", "You absolute menace."],
	"mates": ["Pfff! Oi!", "Really? REALLY?"],
	"known": ["What was that for?", "This is a clean shirt."],
	"irritated": ["Do that again. Go on.", "Not funny."],
	"gone": ["That's it."],
}
const WEARING := {
	"cone": ["Is that a traffic cone?", "Council's going to want that back."],
	"chef_hat": ["Chef! What's on tonight?", "Snack captain on deck."],
	"antennae": ["Take those off. Too soon.", "Still got the antennae, I see."],
	"lion_mask": ["Nice mask.", "The lion walks among us."],
	"foam_finger": ["Number one, are we?"],
	"rubber_chicken": ["Why do you have a chicken."],
	"katana_88": ["Careful with that. It's cardboard."],
	"pool_noodle": ["That's a pool noodle."],
	"belt": ["That's Harry's belt, basically."],
	"ghost": ["Who invited the ghost?"],
	"strap_scarf": ["...Are those straps?", "That scarf looks familiar."],
	"clipboard": ["Sign me up twice."],
}
