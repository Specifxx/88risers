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
	{"id": "p_hotdog", "likes": "food", "name": "A man dressed as a hot dog", "role": "Lost a bet. Or won one.", "strength": 57, "pace": 1.5, "stops": 0.8, "prop": "bun", "look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "tint": Color(0.85, 0.3, 0.2)}, "mind": {"warmth": 0.3, "chatty": 0.9},
		"chat": ["Don't ask. It's a long story and it ends with me as a hot dog.", "I've been a hot dog since eleven this morning. You get used to it.", "No, I don't have sauce. Everyone asks about sauce."]},
	{"id": "p_stilts", "likes": "flatter", "name": "Someone on stilts", "role": "Running late for a festival", "strength": 49, "pace": 1.9, "stops": 0.5, "size": 1.55, "look": {"body": "Female_Ranger", "hair": "Hair_Long", "tint": Color(0.6, 0.2, 0.8)}, "mind": {"warmth": 0.2},
		"chat": ["I can see the whole meet from up here. The big one's hiding snacks behind the banner.", "Do NOT bump the table. I have one balance and this is it.", "Arm wrestling? At this height the leverage would be criminal."]},
	{"id": "p_statue", "likes": "honest", "name": "The human statue", "role": "Silver. Silent. On his break.", "strength": 63, "pace": 0.8, "stops": 1.0, "look": {"body": "Male_Ranger", "hair": "Hair_SimpleParted", "tint": Color(0.82, 0.84, 0.88), "shade": Color(0.75, 0.77, 0.8)}, "mind": {"warmth": 0.1, "chatty": 0.2},
		"chat": ["...", "I'm on my break. That's why I'm moving.", "Eleven hours I stood at Circular Quay today. A child put a chip in my ear."]},
	{"id": "p_clown", "likes": "honest", "name": "A clown, off duty", "role": "Does not want to talk about it", "strength": 66, "pace": 1.3, "stops": 0.6, "look": {"body": "Male_Peasant", "hair": "Hair_Buns", "tint": Color(1.0, 0.85, 0.1), "hair_tint": Color(0.9, 0.1, 0.1)}, "mind": {"warmth": -0.1, "grudge": 1.3},
		"chat": ["I've done three birthdays today. I've seen things.", "No, I won't make you a balloon animal. ...What animal?", "The shoes are regulation. Don't."]},
	{"id": "p_larp", "likes": "dare", "name": "Sir Gavin of Wentworth Point", "role": "On his way to a battle in the park", "strength": 71, "pace": 1.4, "stops": 0.8, "look": {"body": "Male_Ranger", "hood": true, "tint": Color(0.5, 0.5, 0.55)}, "mind": {"warmth": 0.2, "chatty": 0.8},
		"chat": ["Hail! Is this a tourney? I see no lists, yet men do grapple.", "I am sworn to defend the honour of Wentworth Point. Also I work in IT.", "A contest of arms! Literally! I must partake."]},
	{"id": "p_door", "likes": "honest", "name": "A bloke carrying a door", "role": "It's a long story", "strength": 75, "pace": 1.2, "stops": 0.4, "prop": "door", "look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "tint": Color(0.3, 0.45, 0.7)}, "mind": {"warmth": 0.1},
		"chat": ["Don't. Just don't ask about the door.", "It's MY door. I'm taking it with me. She can keep the frame.", "Heavier than it looks. Like most things."]},
	{"id": "p_catpram", "likes": "flatter", "name": "The woman with a cat in a pram", "role": "His name is Mr Biscuits. No relation.", "strength": 51, "pace": 1.0, "stops": 0.7, "prop": "pram", "look": {"body": "Female_Peasant", "hair": "Hair_Buns", "tint": Color(0.75, 0.6, 0.85)}, "mind": {"warmth": 0.3, "chatty": 0.8},
		"chat": ["He doesn't walk. He's never walked. He's seventeen and he's never walked anywhere.", "Mr Biscuits finds your sport undignified. I think it's lovely.", "Don't look him in the eye."]},
	{"id": "p_santa", "likes": "food", "name": "Santa, off season", "role": "It's November. He's early. Or late.", "strength": 73, "pace": 1.1, "stops": 0.9, "look": {"body": "Male_Peasant", "hair": "Hair_Long", "beard": true, "tint": Color(0.85, 0.1, 0.1), "hair_tint": Color(0.95, 0.95, 0.95), "build": 1.2}, "mind": {"warmth": 0.5, "open": 1.4},
		"chat": ["Ho ho— no. I'm off the clock. It's just Greg.", "I know which of you has been naughty. It's the one with the chalk.", "Eleven months of nothing and then one very bad night."]},
	{"id": "p_coat", "likes": "food", "name": "A very tall man in a long coat", "role": "Definitely one adult", "strength": 44, "pace": 0.9, "stops": 0.8, "size": 1.35, "look": {"body": "Male_Ranger", "hood": true, "tint": Color(0.35, 0.28, 0.2)}, "mind": {"warmth": 0.2, "chatty": 0.7},
		"chat": ["Hello, fellow adults. I am here for one adult ticket to the arm business.", "We— I. I would like some snacks. For my one stomach.", "*whispering from the middle* Stop wobbling, Josh."]},
	{"id": "p_speed", "likes": "dare", "name": "The competitive speed-walker", "role": "Hips like a metronome", "strength": 55, "pace": 3.0, "stops": 0.2, "look": {"body": "Female_Ranger", "hair": "Hair_BuzzedFemale", "tint": Color(0.1, 0.8, 0.6)}, "mind": {"warmth": -0.1, "grudge": 1.2},
		"chat": ["It's NOT running. One foot is always down. ALWAYS.", "I'm on a time. I'm always on a time.", "Olympic sport since 1908. Look it up."]},
	{"id": "p_jog", "likes": "dare", "name": "The jogger", "role": "Out for a run", "strength": 50, "pace": 3.4, "stops": 0.25, "look": {"body": "Female_Ranger", "hair": "Hair_Buns", "tint": Color(0.5, 0.8, 1.0)}, "mind": {"warmth": 0.0},
		"chat": ["I'm on a pace here.", "Is this a club? You all just... do this?", "My watch thinks I've stopped. I have stopped."]},
	{"id": "p_dog", "likes": "honest", "name": "The dog walker", "role": "Walking Biscuit", "strength": 52, "pace": 1.3, "stops": 0.6, "dog": true, "look": {"body": "Female_Peasant", "hair": "Hair_Long", "tint": Color(0.6, 0.85, 0.6)}, "mind": {"warmth": 0.3, "open": 1.3},
		"chat": ["His name's Biscuit. He's very strong, actually.", "We come past every night. He likes the noise.", "Don't feed him chalk."]},
	{"id": "p_dog2", "likes": "flatter", "name": "The man with the tiny dog", "role": "Walking Mochi", "strength": 64, "pace": 1.1, "stops": 0.7, "dog": true, "dog_name": "Mochi", "dog_color": Color(0.95, 0.93, 0.88), "dog_size": 0.6, "look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "tint": Color(0.55, 0.6, 0.85)}, "mind": {"warmth": 0.2},
		"chat": ["She's a Maltese cross. She runs the house.", "Mochi doesn't like chalk. Or cyclists. Or Tuesdays.", "I only stopped because she stopped."]},
	{"id": "p_tour", "likes": "honest", "name": "The tourist", "role": "Looking for the ferry", "strength": 48, "pace": 1.2, "stops": 0.9, "look": {"body": "Male_Ranger", "hair": "Hair_SimpleParted", "tint": Color(1.0, 0.9, 0.5)}, "mind": {"warmth": 0.3, "open": 1.4},
		"chat": ["Is this traditional?", "Can I take a picture? I'm taking a picture.", "Which way is the ferry? Not that way?"]},
	{"id": "p_old", "likes": "dare", "name": "The old bloke", "role": "Says he used to pull", "strength": 88, "pace": 1.0, "stops": 0.8, "look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "beard": true, "tint": Color(0.75, 0.7, 0.6)}, "mind": {"warmth": 0.2},
		"chat": ["I pulled in '84. Different game then.", "No straps in my day. You held on or you didn't.", "That lad's wrist is too low."]},
	{"id": "p_office", "likes": "food", "name": "The office worker", "role": "Still on a call", "strength": 54, "pace": 1.7, "stops": 0.3, "look": {"body": "Male_Ranger", "hair": "Hair_SimpleParted", "tint": Color(0.75, 0.8, 0.95)}, "mind": {"warmth": -0.1, "grudge": 1.3},
		"chat": ["Sorry, I'm on mute. What?", "Let's circle back on that.", "I have a stand-up at seven."]},
	{"id": "p_pt", "likes": "flatter", "name": "The personal trainer", "role": "Sizing everyone up", "strength": 72, "pace": 2.0, "stops": 0.7, "look": {"body": "Female_Ranger", "hair": "Hair_BuzzedFemale", "tint": Color(1.0, 0.4, 0.7)}, "mind": {"warmth": 0.1},
		"chat": ["It's all lats. Nobody trains lats.", "I could take half of these.", "Do you do a ladies' class?"]},
	{"id": "p_cousin", "likes": "food", "name": "Somebody's cousin", "role": "Was told there'd be food", "strength": 58, "pace": 1.4, "stops": 1.0, "look": {"body": "Female_Peasant", "hair": "Hair_Long", "tint": Color(1.0, 0.7, 0.75)}, "mind": {"warmth": 0.2, "open": 1.2},
		"chat": ["Where are the snacks? I was promised snacks.", "Which one's my cousin? They all look the same from here.", "Is it always this loud?"]},
	{"id": "p_rider", "likes": "flatter", "name": "The delivery rider", "role": "Looking for unit 1408", "strength": 60, "pace": 2.2, "stops": 0.35, "look": {"body": "Male_Ranger", "hood": true, "tint": Color(0.2, 0.75, 0.6)}, "mind": {"warmth": 0.0},
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
	"drill": ["...and hold. Thirty seconds.", "One more set.", "Tendons don't train themselves.", "Wrist. Fingers. Wrist."],
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

## What they bring up first on a later visit, from the strongest thing they remember about you.
const REMEMBER := {
	"scrap+": "No hard feelings about the other night. Mostly.", "scrap-": "You swung at someone here. I haven't forgotten.",
	"chalk+": "I'm still finding chalk in my ears. Good shot.", "chalk-": "You threw chalk in my face. Don't.",
	"theft-": "Keep your hands out of my bag this week.", "gift+": "You brought snacks round last time. Noted. Approved.",
	"match+": "Good pull last time. Again tonight?", "heckle-": "Got anything nicer to say this week?",
	"helped+": "You did me a good turn. I remember that.", "talk+": "Good chat last time.", "photo+": "That photo came out well.",
	"aliens+": "We don't talk about the aliens. But well done.", "insult-": "After what you said? You've got a nerve.",
}

## Each founder's own conversation. A topic can be raised once a night; every answer has a price.
## v: how it lands (-1..1). flag: remembered between visits. need: only offered once that flag is set.
## do: something that then happens in the world.
const TALK := {
	"p_hotdog": [
		{"key": "why", "ask": "\"...Why are you a hot dog?\"", "reply": "My daughter's school fete. I said I'd do anything. They took that seriously.", "opts": [
			{"say": "That's actually lovely.", "reply": "Don't make it weird. I'm a hot dog with feelings.", "v": 0.4},
			{"say": "Can a hot dog arm wrestle?", "reply": "The arms are free. The dignity went hours ago. Let's go.", "v": 0.3, "do": "keen"},
			{"say": "You'd go well with Kelvin.", "reply": "The big one? He's been looking at me. Hungrily.", "v": 0.2}]},
	],
	"p_coat": [
		{"key": "coat", "ask": "\"Are you... three kids in a coat?\"", "reply": "No. I am a businessman. I did a business today. *a small voice: 'say stocks'* Stocks.", "opts": [
			{"say": "Fair enough. Carry on, sir.", "reply": "Thank you, citizen. *giggling from the knees*", "v": 0.5},
			{"say": "Want to arm wrestle?", "reply": "*frantic whispering* ...Yes. But the top one does it. The top one's Maddy.", "v": 0.4, "do": "keen"},
			{"say": "I'm telling your parents.", "reply": "RUN, JOSH. RUN.", "v": -0.5, "kind": "heckle"}]},
	],
	"p_larp": [
		{"key": "quest", "ask": "\"What's the quest, Sir Gavin?\"", "reply": "The Orc King of Bicentennial Park has taken our esky. I ride to reclaim it. On foot.", "opts": [
			{"say": "I'll fight at your side.", "reply": "A squire! Your name shall be sung in the group chat.", "v": 0.5},
			{"say": "Prove your strength first. At the table.", "reply": "A trial by combat! I ACCEPT.", "v": 0.3, "do": "keen"},
			{"say": "That's a plastic sword.", "reply": "It is FOAM. It is tournament-legal FOAM.", "v": -0.3, "kind": "heckle"}]},
	],
	"p_santa": [
		{"key": "list", "ask": "\"Am I on the nice list?\"", "reply": "Let me check. *looks you up and down* ...What did you do to that possum?", "opts": [
			{"say": "I've been good. Mostly.", "reply": "Mostly gets you socks.", "v": 0.3},
			{"say": "What do I have to do to get on it?", "reply": "Buy a tired man a kebab.", "v": 0.2, "do": "keen"},
			{"say": "You're not the real one.", "reply": "Neither's the one at the shops, and he gets dental.", "v": -0.2}]},
	],
	"s_busker": [
		{"key": "songs", "ask": "Ask what she plays", "reply": "Anything with four chords. Which is everything. Don't tell the others.", "opts": [
			{"say": "Play something for the club.", "reply": "For the arm people? I've got one. It's called 'Hand on the Pad'. It's a waltz.", "v": 0.4, "do": "busk"},
			{"say": "Know any arm wrestling songs?", "reply": "I wrote three. Nobody asked me to. That's art.", "v": 0.3},
			{"say": "Is this your actual job?", "reply": "Is standing at a table holding hands YOUR actual job?", "v": -0.3, "kind": "heckle"}]},
		{"key": "capo", "ask": "\"You look like you've lost something.\"", "reply": "My capo. Little clamp thing. It pinged off into the seating an hour ago and I can't leave the hat unattended. Not round here.", "opts": [
			{"say": "I'll find it.", "reply": "Would you? It's silver. It'll be up the steps somewhere. I'll make it worth your while.", "v": 0.3, "do": "errand"},
			{"say": "Play without it.", "reply": "In E flat? What am I, a jazz musician?", "v": -0.1},
			{"say": "I'll watch the hat. You go.", "reply": "...No offence. But no.", "v": 0.0}]},
		{"key": "request", "ask": "Ask if she takes requests from the founders", "reply": "The funny one keeps shouting for the Wiggles. Go and ask him what he ACTUALLY wants and I'll play it. Properly.", "opts": [
			{"say": "I'll ask Tommy.", "reply": "Bring me a real answer.", "v": 0.2, "lead": "busker_request"},
			{"say": "Play the Wiggles. He means it.", "reply": "...He does, doesn't he.", "v": 0.2, "do": "busk"}]},
	],
	"s_fisher": [
		{"key": "catch", "ask": "\"Catching anything?\"", "reply": "Three bream and a jandal. The jandal fought harder.", "opts": [
			{"say": "What's the biggest you've had?", "reply": "A jewfish. Ninety-four. Long as this rail. Nobody believed me, so I stopped telling people. Until now.", "v": 0.4},
			{"say": "Can I have a go?", "reply": "Rod's right there. Don't strike early. Everyone strikes early.", "v": 0.2},
			{"say": "Fishing's just standing.", "reply": "And arm wrestling's just holding hands. We all have our lies.", "v": -0.3, "kind": "heckle"}]},
		{"key": "thermos", "ask": "\"You alright? You keep patting your pockets.\"", "reply": "My thermos. Had it thirty years. I put it down when the gulls came and now it's walked.", "opts": [
			{"say": "I'll look for it.", "reply": "Tartan. Dented. If it's by that van, tell him I want it washed.", "v": 0.4, "do": "errand"},
			{"say": "It's only a thermos.", "reply": "It's the only thing that's stayed.", "v": -0.4},
			{"say": "What's in it?", "reply": "Tea. Mostly.", "v": 0.2}]},
		{"key": "bigone", "ask": "Ask about the one under the wharf", "reply": "I call him Kevin. Had him on in '09 and again in '17. He takes the bait, looks me in the eye, and spits the hook.", "opts": [
			{"say": "What bait does Kevin like?", "reply": "Something greasy. Chips. He's got taste.", "v": 0.3, "flag": "kevin_bait"},
			{"say": "It's the same fish? Since 2009?", "reply": "I'd know that eye anywhere.", "v": 0.25},
			{"say": "Kevin isn't real.", "reply": "Neither's your technique, but I didn't say anything.", "v": -0.3}]},
	],
	"s_kebab": [
		{"key": "menu", "ask": "Ask what's good", "reply": "Everything's good. The lamb's best. The falafel's for people who've given up.", "opts": [
			{"say": "What does Kelvin order?", "reply": "Two lamb, one chicken, chips, and 'whatever's left'. Every time. He calls it 'the Sunday'.", "v": 0.35, "lead": "tally_tommy"},
			{"say": "Got anything off the menu?", "reply": "For you? The Riser. Everything, twice, in one bread. Six dollars. I shouldn't.", "v": 0.3},
			{"say": "Is the meat... meat?", "reply": "Next customer.", "v": -0.4, "kind": "heckle"}]},
		{"key": "tongs", "ask": "\"Everything okay back there?\"", "reply": "My tongs. My GOOD tongs. Something came through here, small, fast, grey, and now I'm turning chicken with a fork like an animal.", "opts": [
			{"say": "I'll find your tongs.", "reply": "Check the bins. Check the trees. It had hands. Little hands.", "v": 0.4, "do": "errand"},
			{"say": "Small, grey, with hands? That's the possum.", "reply": "The POSSUM. I KNEW it. Three weeks of this.", "v": 0.3},
			{"say": "Use the fork.", "reply": "You don't understand what tongs MEAN.", "v": -0.2}]},
		{"key": "delivery", "ask": "Ask if he delivers", "reply": "To the tables? If someone carries it. I've got a lamb here with your big friend's name on it and no way to get it to him.", "opts": [
			{"say": "I'll take it to Kelvin.", "reply": "Run. It's best in the first ninety seconds.", "v": 0.3, "lead": "kebab_kelvin"},
			{"say": "He can walk.", "reply": "He can. He won't.", "v": 0.0}]},
	],
	"p_bike": [
		{"key": "bike", "ask": "Ask about the bike", "reply": "Full carbon. Electronic shifting. It weighs less than my lunch and cost more than my car.", "opts": [
			{"say": "Can I have a go?", "reply": "Absolutely not. Nobody touches it. I don't even let my wife look at it for long.", "v": -0.1},
			{"say": "Eleven grand? For a bike?", "reply": "It's an INVESTMENT. That's what I told the bank.", "v": 0.2},
			{"say": "You know it's just a pushbike.", "reply": "It is a MACHINE. Good day.", "v": -0.4, "kind": "heckle"}]},
	],
	"p_office": [
		{"key": "boss", "ask": "\"Rough day at the office?\"", "reply": "Darren scheduled a meeting to discuss why we have too many meetings. It ran over.", "opts": [
			{"say": "What did Darren say this time?", "reply": "He said 'let's take this offline' while we were all in the same room. I think about it constantly.", "v": 0.4, "lead_local": "darren"},
			{"say": "Quit. Come and arm wrestle instead.", "reply": "...Don't tempt me. I've got a mortgage and a stand-up at seven. ...What time do you lot meet?", "v": 0.3, "do": "keen"},
			{"say": "Sounds like you're the problem.", "reply": "That's what Darren said in my review.", "v": -0.4, "kind": "heckle"}]},
		{"key": "fridge", "ask": "Ask about office politics", "reply": "Someone's been eating Priya's labelled yoghurt. There's an email chain. Forty replies. HR is involved.", "opts": [
			{"say": "Was it you?", "reply": "...It was one time. It was a Tuesday. I was low.", "v": 0.35},
			{"say": "Blame Darren.", "reply": "I already replied-all saying exactly that. I may have ended my career. It felt incredible.", "v": 0.5, "do": "keen"},
			{"say": "This is the dullest thing I've ever heard.", "reply": "You should see the email about the printer.", "v": -0.2}]},
	],
	"p_jog": [
		{"key": "run", "ask": "Ask how far she's running", "reply": "Ten k. I was on for a personal best until you lot started shouting 'GO' every thirty seconds.", "opts": [
			{"say": "Sorry. Occupational hazard.", "reply": "It's fine. Honestly it made me sprint. Might come past every month.", "v": 0.3},
			{"say": "Arm wrestling's better cardio.", "reply": "It is NOT. ...Is it? My watch would know. Let me try one.", "v": 0.2, "do": "keen"},
			{"say": "You run like you're being chased.", "reply": "I AM being chased. By my thirties.", "v": 0.25}]},
	],
	"p_dog": [
		{"key": "biscuit", "ask": "Ask about Biscuit", "reply": "He failed puppy school twice. The second time they asked us not to come back. He's very proud.", "opts": [
			{"say": "What did he do?", "reply": "Ate the certificate. Somebody else's.", "v": 0.4},
			{"say": "He looks like he could pull.", "reply": "He pulls me into the bay twice a week. Ask my shoulder.", "v": 0.3, "do": "keen"},
			{"say": "Dogs shouldn't be here.", "reply": "Biscuit, we're leaving. This person has no joy.", "v": -0.5, "kind": "heckle"}]},
	],
	"p_dog2": [
		{"key": "mochi", "ask": "Ask about Mochi", "reply": "She has four jumpers and a raincoat. I have two shirts. That's the household.", "opts": [
			{"say": "Who's in charge at home?", "reply": "She is. I just hold the lead and pay for things.", "v": 0.4},
			{"say": "Small dog, big attitude.", "reply": "She once stared down a bin lorry. It reversed.", "v": 0.35},
			{"say": "That's not a dog, that's a slipper.", "reply": "She heard that. She won't forget it. Neither will I.", "v": -0.45, "kind": "heckle"}]},
	],
	"p_tour": [
		{"key": "trip", "ask": "Ask what he's seen so far", "reply": "The bridge, the opera house, a bird that stole my sandwich, and now this. This is my favourite.", "opts": [
			{"say": "This isn't in the guidebook.", "reply": "It should be. Five stars. 'Authentic local hand combat.'", "v": 0.4},
			{"say": "Have a go. It's tradition.", "reply": "Tradition! Then I must. Hold my camera. No, you hold it. No. I'll hold it.", "v": 0.3, "do": "keen"},
			{"say": "The ferry's the other way, mate.", "reply": "Everyone says a different way. I've been to three wharves.", "v": 0.1}]},
	],
	"p_old": [
		{"key": "eighties", "ask": "Ask about pulling in the eighties", "reply": "Pubs. For jugs. No pads, no pegs, no straps. You pulled on a bar mat and if you lost you bought the round.", "opts": [
			{"say": "Were you any good?", "reply": "State finalist, '84 and '86. Lost to a wharfie called Kev both times. Kev's dead now. I still wouldn't pull him.", "v": 0.45},
			{"say": "Show these kids how it's done.", "reply": "...My doctor said nothing strenuous. My doctor isn't here.", "v": 0.4, "do": "keen"},
			{"say": "Different game now, old timer.", "reply": "Same arm, sonny. Same arm.", "v": -0.3, "kind": "heckle"}]},
	],
	"p_pt": [
		{"key": "form", "ask": "Ask what she thinks of the technique", "reply": "Honestly? Half of them are one bad pull from a shoulder reconstruction. It's fascinating.", "opts": [
			{"say": "Which half?", "reply": "The half that aren't the big quiet one. His scapula's perfect. Is he single? Don't answer that.", "v": 0.35},
			{"say": "Bet you couldn't do better.", "reply": "Excuse me? I deadlift double my bodyweight. Move.", "v": 0.1, "do": "keen"},
			{"say": "Personal trainers aren't real athletes.", "reply": "I'm going to remember your face at your first hernia.", "v": -0.5, "kind": "heckle"}]},
	],
	"p_cousin": [
		{"key": "flirt", "ask": "\"So. Come here often?\"", "reply": "To a car park full of men holding hands? First time. You'll have to do better than that.", "opts": [
			{"say": "I only came over because you're the best-looking person at an arm wrestling meet.", "reply": "That's a very low bar. I've seen who's here. ...Go on.", "v": 0.2, "then": "flirt2"},
			{"say": "I could beat everyone here. For you.", "reply": "Could you? Could you beat Kelvin? Because that I'd pay to see.", "v": 0.25, "then": "flirt2"},
			{"say": "Are you Kelvin's cousin? You've got his appetite.", "reply": "Wow. Okay. Goodnight.", "v": -0.6, "kind": "heckle"}]},
		{"key": "cousin", "ask": "Ask whose cousin she is", "reply": "Kelvin's. Well. Second cousin. Our mums play mahjong. I was told there would be food and nobody mentioned the arm thing.", "opts": [
			{"say": "The food's by the lights. Go for the red ones.", "reply": "Finally, someone useful. Kelvin just pointed and kept eating.", "v": 0.45},
			{"say": "Does Kelvin always eat like that?", "reply": "At my wedding he had three mains. He wasn't on the list for three mains.", "v": 0.35, "lead": "tally_tommy"},
			{"say": "You should pull him. Family honour.", "reply": "Oh, I've been waiting twenty years for a reason to beat Kelvin at something.", "v": 0.3, "do": "keen"}]},
	],
	"p_rider": [
		{"key": "handover", "ask": "\"Mate. Just give me the pad thai.\"", "reply": "I can't just GIVE you a customer's order. That's the one rule. That's the whole job.", "opts": [
			{"say": "Unit 1408 doesn't exist. I checked. It's a storage cupboard.", "reply": "...It did feel like a cupboard. The door had a mop sign on it. Take it. TAKE it. I'm marking it delivered.", "v": 0.3, "do": "food"},
			{"say": "I AM unit 1408.", "reply": "You're standing in a park.", "v": -0.1, "then": "handover2"},
			{"say": "Five stars and a tip if you hand it over.", "reply": "Five stars? Typed out? With a comment? ...Deal. Say I was 'friendly and prompt'.", "v": 0.4, "do": "food", "cost": 3}]},
		{"key": "order", "ask": "Ask who the pad thai is for", "reply": "'Unit 1408, Tower B.' There are four Tower Bs. I've been to three. The food's been cold since Thursday.", "opts": [
			{"say": "Just eat it.", "reply": "...It's against policy. It's also against everything I stand for. ...It's pretty good cold.", "v": 0.4},
			{"say": "Sell it to Kelvin.", "reply": "The big fella? Does he tip?", "v": 0.3, "do": "pay:5"},
			{"say": "One star.", "reply": "Mate. Don't. I've got a rating to protect.", "v": -0.4, "kind": "heckle"}]},
	],
	"g_mei": [
		{"key": "parra", "ask": "Ask about the Parramatta club", "reply": "Forty members, a sponsor, proper lighting. And nobody talks to each other. You lot have eight people and a tin and you're having more fun.", "opts": [
			{"say": "So join us.", "reply": "Don't say that near Harry. He'll have a form in my hand.", "v": 0.4},
			{"say": "Why are you really here?", "reply": "Scouting Erick. His left arm's a rumour where I'm from. Don't tell him.", "v": 0.3, "lead": "five_erick"},
			{"say": "Forty members and you came here?", "reply": "For the snacks. Obviously.", "v": 0.2}]},
	],
	"g_baz": [
		{"key": "servo", "ask": "Ask about pulling at truck stops", "reply": "Rules are simple. Winner gets the pie. Loser buys the pie. Never been the loser.", "opts": [
			{"say": "What kind of pie?", "reply": "Steak and pepper. There's no other kind. Anyone says different is a cop.", "v": 0.45},
			{"say": "Ever pulled a real puller?", "reply": "Pulled a bloke in Dubbo who turned out to be a state champ. Took me eleven seconds. Longest pie of my life.", "v": 0.3},
			{"say": "Truck stop rules don't count here.", "reply": "Mate, a hand's a hand.", "v": -0.2}]},
	],
	"g_ana": [
		{"key": "elbows", "ask": "Ask whose elbow is worst", "reply": "Patient confidentiality. ...It's Phillip's. It's held together with tape and stubbornness.", "opts": [
			{"say": "Can you fix mine before I break it?", "reply": "Warm up. Wrists, then elbows, then shoulders. Two minutes. There, I've saved you four hundred dollars.", "v": 0.4, "do": "tip"},
			{"say": "I'll tell Phillip you said that.", "reply": "He knows. He nodded once. That's the most I've ever got out of him.", "v": 0.2},
			{"say": "Physios just sell you rubber bands.", "reply": "And you'll buy six. See you in March.", "v": -0.3, "kind": "heckle"}]},
	],
	"g_kai": [
		{"key": "champ", "ask": "Ask about his plan", "reply": "Youngest ever champion. I've got a spreadsheet. Erick's on it. Harry's on it. You're not on it yet.", "opts": [
			{"say": "Put me on the spreadsheet.", "reply": "Row forty-one. Under my PE teacher.", "v": 0.4},
			{"say": "Does your mum know you're here?", "reply": "...She thinks I'm at chess. Chess is on Tuesdays. Don't tell her.", "v": 0.2},
			{"say": "You're a kid. Go home.", "reply": "That's what they said to every champion. Probably.", "v": -0.35, "kind": "heckle"}]},
	],
	"g_ron": [
		{"key": "permit", "ask": "Ask what he's observing", "reply": "Booking compliance. Noise. Chalk residue. Whether this is 'organised sport' or 'a gathering'. They're different forms.", "opts": [
			{"say": "It's a gathering with tables.", "reply": "...That's actually the cheaper form. Don't tell anyone I said so.", "v": 0.4, "lead": "fees_harry"},
			{"say": "You want a go, don't you.", "reply": "I'm on the clock. ...When I'm off the clock, hypothetically, which table?", "v": 0.35},
			{"say": "Nobody likes the council, Ron.", "reply": "I know. I've read the feedback forms.", "v": -0.3, "kind": "heckle"}]},
	],
	"harry": [
		{"key": "comp", "ask": "Ask about next month's comp", "reply": "Newcastle. Six of us are going. Come and watch. Or enter novice, if you've got the nerve.", "opts": [
			{"say": "Enter me.", "reply": "Just like that? ...Good. I like that. You're in.", "v": 0.5, "flag": "novice", "lead": "novice_erick"},
			{"say": "I'll come and watch.", "reply": "Bring a chair. It runs long.", "v": 0.15},
			{"say": "Newcastle's a dump.", "reply": "Don't let Erick hear you.", "v": -0.25, "kind": "heckle"}]},
		{"key": "ref", "ask": "Ask what he watches for as a ref", "reply": "Elbows, shoulders, and whoever's about to do something stupid. Usually Tommy.", "opts": [
			{"say": "What's the commonest foul?", "reply": "Elbow off the pad. Everyone thinks I can't see it. I can always see it.", "v": 0.25, "do": "tip"},
			{"say": "Ever given a bad call?", "reply": "Once. 2021. I still think about it.", "v": 0.2},
			{"say": "Refs are just failed pullers.", "reply": "I'm the 70kg champion.", "v": -0.5, "kind": "heckle"}]},
		{"key": "title", "ask": "Ask about the 70kg title", "reply": "Three years, that took. Lost the first two finals on fouls.", "opts": [
			{"say": "Fouls? So you cheat.", "reply": "I referee this club. Think about what you just said.", "v": -0.6, "kind": "heckle", "flag": "called_cheat"},
			{"say": "Three years is real work.", "reply": "It is. Most quit inside one. Don't be most.", "v": 0.4},
			{"say": "Show me the start.", "reply": "Hand high. Load the back. Go on the G of go. There, that's free.", "v": 0.3, "do": "tip"}]},
		{"key": "club", "ask": "Ask why he started the club", "reply": "Eight of us and one table in a garage. I wanted somewhere nobody gets laughed at for being new.", "opts": [
			{"say": "I'm new. Nobody's laughed yet.", "reply": "Good. Tell me if they do.", "v": 0.4, "flag": "harry_looks_out"},
			{"say": "Bit small-time, isn't it?", "reply": "...Enjoy your evening.", "v": -0.5, "kind": "heckle"},
			{"say": "What do you need doing tonight?", "reply": "Get three of the public to have a pull. That's how a club grows.", "v": 0.3, "flag": "harry_job"}]},
	],
	"george": [
		{"key": "tin", "ask": "Ask how the club's paid for", "reply": "Out of my pocket and a tin. The tin is mostly buttons.", "opts": [
			{"say": "Here's five for the tin.", "reply": "Actual money. In the tin. I might cry.", "v": 0.6, "cost": 5},
			{"say": "Charge membership.", "reply": "Harry won't have it. 'Nobody pays to belong.' He's right. Annoyingly.", "v": 0.2, "lead": "fees_harry"},
			{"say": "Not my problem.", "reply": "No. It's mine. Always is.", "v": -0.3}]},
		{"key": "eighty", "ask": "\"Why 88 Risers?\"", "reply": "Eight founders. And eighty more we haven't met yet. That's the whole plan.", "opts": [
			{"say": "Put me down as nine.", "reply": "Done. You're nine. Don't make me regret the paperwork.", "v": 0.5, "flag": "number_nine"},
			{"say": "Eighty's a lot.", "reply": "One a month. Seven years. I've done the maths.", "v": 0.2},
			{"say": "You'll never get there.", "reply": "Not with that attitude at the gate, no.", "v": -0.35, "kind": "heckle"}]},
		{"key": "page", "ask": "Ask about the club's page", "reply": "I run it. I need someone in tonight's video who isn't one of us eight.", "opts": [
			{"say": "Put me in it.", "reply": "Stand there. Look strong. No, stronger. Perfect.", "v": 0.4, "do": "photo"},
			{"say": "What's it pay?", "reply": "Exposure. ...Yes, I heard it as I said it.", "v": -0.15},
			{"say": "Nobody watches those.", "reply": "Four hundred people watched the last one. Three hundred were my mum.", "v": -0.35, "kind": "heckle"}]},
		{"key": "brother", "ask": "\"You and Harry are brothers?\"", "reply": "He's the champion. I'm the one who books the venue.", "opts": [
			{"say": "Sounds like you do the real work.", "reply": "Say that louder. Near him.", "v": 0.5},
			{"say": "So you're the weaker one.", "reply": "Wow. Straight for it.", "v": -0.6, "kind": "heckle", "flag": "weaker_brother"},
			{"say": "Have you ever beaten him?", "reply": "Once. 2019. He says his elbow slipped. It did not slip.", "v": 0.2}]},
	],
	"phillip": [
		{"key": "rain", "ask": "Ask what's in his headphones", "reply": "Rain sounds.", "opts": [
			{"say": "Just rain?", "reply": "Heavy rain. For heavy sets.", "v": 0.3},
			{"say": "That's serial killer behaviour.", "reply": "...", "v": -0.35, "kind": "heckle", "lead": "rain_tommy"},
			{"say": "Send me the playlist.", "reply": "It's one track. Ten hours.", "v": 0.4}]},
		{"key": "why", "ask": "Ask why he pulls", "reply": "It's the only thing where trying harder always works.", "opts": [
			{"say": "That's the best answer I've heard.", "reply": "...Thanks.", "v": 0.5},
			{"say": "Until someone's just stronger.", "reply": "Then you try for longer.", "v": 0.15},
			{"say": "Bit grim.", "reply": "It's not grim. It's simple.", "v": -0.2}]},
		{"key": "quiet", "ask": "Stand next to him and say nothing", "reply": "...", "opts": [
			{"say": "(Keep saying nothing.)", "reply": "...You're alright.", "v": 0.5, "flag": "phillip_quiet"},
			{"say": "So! Do you come here often?", "reply": "Every month. For four years. To train.", "v": -0.2, "kind": "nagged"},
			{"say": "(Count his reps out loud, wrong.)", "reply": "Twelve. That was twelve. Go away.", "v": -0.45, "kind": "heckle"}]},
		{"key": "bronze", "ask": "Ask about the NSW bronze", "reply": "Bronze.", "opts": [
			{"say": "Bronze is third.", "reply": "I know what bronze is.", "v": -0.5, "kind": "heckle", "flag": "bronze_dig"},
			{"say": "Who beat you?", "reply": "A man with hands like dinner plates. I've been training for him since.", "v": 0.3},
			{"say": "Gold next year.", "reply": "...Yes.", "v": 0.45}]},
	],
	"bhavya": [
		{"key": "silver", "ask": "Ask about the silver medal", "reply": "Lost the final to a nineteen-year-old who'd been pulling six months. Natural hand. Sickening.", "opts": [
			{"say": "You'll get him next time.", "reply": "I've watched the tape forty times. I will.", "v": 0.3},
			{"say": "So technique isn't everything.", "reply": "Technique is everything. He just had it by accident.", "v": -0.45, "kind": "heckle"},
			{"say": "What did you learn?", "reply": "That I'd stopped training my rise. Never neglect the rise.", "v": 0.3, "do": "tip"}]},
		{"key": "coach", "ask": "Ask who he'd most like to coach", "reply": "Phillip. All that work, and nobody's ever fixed his wrist. He'd be unbeatable.", "opts": [
			{"say": "Tell him.", "reply": "He doesn't take advice. He takes rain sounds.", "v": 0.1, "lead": "wrist_phillip"},
			{"say": "Coach me instead.", "reply": "You'd listen? Good. Lesson one: stop gripping like it owes you money.", "v": 0.35, "do": "tip"},
			{"say": "Maybe he doesn't want your help.", "reply": "Nobody wants help. Everyone needs it.", "v": -0.2}]},
		{"key": "form", "ask": "Ask him to look at your form", "reply": "Your wrist is low, your elbow is loose and your feet are doing nothing. Otherwise fine.", "opts": [
			{"say": "Fix one thing for me.", "reply": "Wrist. Curl it like you're hiding a coin. Feel that? That's the pull.", "v": 0.4, "do": "tip"},
			{"say": "I didn't ask for a list.", "reply": "You literally asked.", "v": -0.3},
			{"say": "You only got silver, though.", "reply": "And you got a participation medal. If that.", "v": -0.55, "kind": "heckle", "flag": "silver_dig"}]},
		{"key": "beard", "ask": "Compliment the beard", "reply": "Thank you. It's load-bearing.", "opts": [
			{"say": "Does it help the pull?", "reply": "It intimidates. That's half of it.", "v": 0.3},
			{"say": "(Reach out and tug it.)", "reply": "NO. No. We do not touch the beard.", "v": -0.6, "kind": "scrap", "flag": "beard_tug"},
			{"say": "I'm growing one.", "reply": "Good. Oil it. Don't tell Tommy I said oil.", "v": 0.35}]},
	],
	"kelvin": [
		{"key": "bushys", "ask": "Ask about Bushy's", "reply": "Second place. First was a tree surgeon. Forearms like actual trees.", "opts": [
			{"say": "Second's huge.", "reply": "It is, isn't it? Nobody says that.", "v": 0.4},
			{"say": "What did second win?", "reply": "A meat tray. Best prize of my life. Gone in a day.", "v": 0.3, "lead": "meat_tommy"},
			{"say": "So you lost.", "reply": "To a TREE SURGEON.", "v": -0.4, "kind": "heckle"}]},
		{"key": "gentle", "ask": "\"You're the biggest one here. Ever lose your temper?\"", "reply": "Once. Someone took the last red one off my plate. I don't talk about it.", "opts": [
			{"say": "Noted. Never touch the plate.", "reply": "That's all I ask.", "v": 0.35},
			{"say": "(Take a snack off his plate.)", "reply": "...Put it back. Slowly.", "v": -0.6, "kind": "scrap"},
			{"say": "What happened to them?", "reply": "We're friends now. He brings two.", "v": 0.25}]},
		{"key": "errand", "ask": "Ask if he wants anything", "reply": "One of the red ones from the snack table. I'd go, but I've been six times and people are counting.", "opts": [
			{"say": "I'll get you one.", "reply": "You're a good person. Red. Not the yellow.", "v": 0.2, "flag": "errand"},
			{"say": "Get it yourself.", "reply": "Cold. That's cold.", "v": -0.3},
			{"say": "Six times? Mate.", "reply": "I'm in a bulk. It's a programme.", "v": -0.35, "kind": "heckle"}]},
		{"key": "size", "ask": "\"How much do you weigh?\"", "reply": "Enough.", "opts": [
			{"say": "It's all muscle, clearly.", "reply": "Thank you. Finally. Someone says it.", "v": 0.5},
			{"say": "It's all snacks, clearly.", "reply": "...Say that to my hand. At the table.", "v": -0.6, "kind": "heckle", "flag": "snack_dig"},
			{"say": "What's the secret?", "reply": "Rice. So much rice. And side pressure.", "v": 0.3, "do": "tip"}]},
	],
	"tommy": [
		{"key": "van", "ask": "Ask how he became a founder", "reply": "I had a van. That's the whole story. I was the only one with a van.", "opts": [
			{"say": "Vans matter.", "reply": "THANK you. Tables don't carry themselves.", "v": 0.35},
			{"say": "Still got it?", "reply": "Sold it. Don't tell Harry. He thinks it's at the mechanic's. Since 2023.", "v": 0.2, "lead": "van_harry"},
			{"say": "So you're the driver.", "reply": "Founder. FOUNDER. It's on the banner.", "v": -0.3, "kind": "heckle"}]},
		{"key": "serious", "ask": "\"Are you ever serious?\"", "reply": "At the table. Ask anyone. I go quiet. It scares people.", "opts": [
			{"say": "I'd like to see that.", "reply": "Then pull me. But you won't like it.", "v": 0.3},
			{"say": "I don't believe you.", "reply": "Fair. Nobody does. That's how I get them.", "v": 0.15, "do": "tip"},
			{"say": "You should try it more.", "reply": "And you should try being fun.", "v": -0.3}]},
		{"key": "prank", "ask": "\"What are you up to?\"", "reply": "Harry's standing right by the chalk bucket. I'm just saying. He is RIGHT there.", "opts": [
			{"say": "Do it. I'll say it was me.", "reply": "You are my favourite person.", "v": 0.5, "do": "prank_harry", "flag": "prank_pact"},
			{"say": "Leave him alone.", "reply": "Boo. Fine. Boo.", "v": -0.15},
			{"say": "I'm telling Harry.", "reply": "Snitch! We have a snitch!", "v": -0.5, "kind": "heckle", "do": "snitch", "flag": "snitch"}]},
		{"key": "jokes", "ask": "Ask for his best joke", "reply": "Why did the arm wrestler get kicked out of the library? Too much side pressure.", "opts": [
			{"say": "(Laugh.)", "reply": "See! SEE! Bhavya said it wasn't funny.", "v": 0.45},
			{"say": "That's not a joke.", "reply": "It's a joke if you understand arm wrestling.", "v": -0.25},
			{"say": "Tell it to Phillip.", "reply": "I did. He looked at me for a full minute.", "v": 0.25}]},
	],
	"luie": [
		{"key": "little", "ask": "Ask why he says so little", "reply": "Most things don't need saying.", "opts": [
			{"say": "(Say nothing.)", "reply": "...Exactly.", "v": 0.5},
			{"say": "That needed saying, though.", "reply": "...Fair.", "v": 0.3},
			{"say": "Bit pretentious.", "reply": "Mm.", "v": -0.4, "kind": "heckle"}]},
		{"key": "others", "ask": "Ask who he'd want in his corner", "reply": "Kelvin. He'd say nothing useful and hand me food. That's all you need.", "opts": [
			{"say": "I'll tell Kelvin.", "reply": "Don't make it a thing.", "v": 0.1, "lead": "corner_kelvin"},
			{"say": "Not Harry?", "reply": "Harry would give me a plan. I don't want a plan.", "v": 0.2},
			{"say": "What about me?", "reply": "...Ask me in a year.", "v": 0.15}]},
		{"key": "water", "ask": "Ask what he's looking at", "reply": "The water. It's flat tonight. I like it flat.", "opts": [
			{"say": "(Look at the water with him.)", "reply": "...Yeah. That's it. That's all it is.", "v": 0.55, "flag": "luie_water"},
			{"say": "Shouldn't you be training?", "reply": "This is training.", "v": -0.2, "kind": "nagged"},
			{"say": "It's a river, mate. It's brown.", "reply": "It's a bay. And it's not about the colour.", "v": -0.4, "kind": "heckle"}]},
		{"key": "fake", "ask": "Ask about his fake-out", "reply": "Everyone watches the hand. Nobody watches the shoulder.", "opts": [
			{"say": "So I watch the shoulder.", "reply": "Now you're watching the shoulder. So I use the hand.", "v": 0.35, "do": "tip"},
			{"say": "That's just cheating slowly.", "reply": "It's thinking. Try it.", "v": -0.3, "kind": "heckle"},
			{"say": "Who taught you?", "reply": "My dad. Thumb wars. He never let me win one.", "v": 0.4}]},
	],
	"erick": [
		{"key": "newcastle", "ask": "Ask about the Newcastle title", "reply": "Won it left-handed. My right was strapped up. Nobody mentions that.", "opts": [
			{"say": "Left-handed? That's mad.", "reply": "RIGHT? Tell the others. They act like it's nothing.", "v": 0.5},
			{"say": "Who'd you beat?", "reply": "Fella called Gaz. He cried. I felt bad. Then I didn't.", "v": 0.2},
			{"say": "Small pond.", "reply": "Say that with your hand on the pad.", "v": -0.5, "kind": "heckle"}]},
		{"key": "lose", "ask": "\"How do you take losing?\"", "reply": "Badly. Next question.", "opts": [
			{"say": "Who was the last one?", "reply": "Luie. With that shoulder thing. I still don't know what he did.", "v": 0.15, "lead": "erick_lost_luie"},
			{"say": "That's why you're good.", "reply": "That's exactly why I'm good.", "v": 0.4},
			{"say": "Sounds exhausting to be around.", "reply": "Ask me if I care.", "v": -0.3}]},
		{"key": "bet", "ask": "\"Think you'd beat me?\"", "reply": "I know I would. Want to put a snack on it?", "opts": [
			{"say": "You're on. A snack says I pin you.", "reply": "Easiest snack of my life. Go and chalk up.", "v": 0.2, "flag": "bet"},
			{"say": "I don't gamble.", "reply": "Smart. You'd lose.", "v": 0.0},
			{"say": "Newcastle's not a real title.", "reply": "Come here and say that with your hand on the pad.", "v": -0.6, "kind": "heckle", "flag": "newcastle_dig"}]},
		{"key": "train", "ask": "Ask how he trains", "reply": "Every day. Rope, band, table. Then again.", "opts": [
			{"say": "That sounds obsessive.", "reply": "It's called wanting it.", "v": -0.2},
			{"say": "Can I train with you?", "reply": "Six a.m. Don't be late. You'll be late.", "v": 0.45, "flag": "train_with_erick"},
			{"say": "What's one thing I can steal?", "reply": "Hang from a towel. Two minutes. Your grip will thank you.", "v": 0.3, "do": "tip"}]},
	],
}

## Insults. Everyone shrugs most of them off; everyone has one that goes straight in.
const INSULTS := [
	{"key": "technique", "say": "\"Your technique's a mess.\""},
	{"key": "weak", "say": "\"You're weaker than you look.\""},
	{"key": "girl", "say": "\"Your girl was asking about me, by the way.\""},
	{"key": "loss", "say": "\"Remind me, who beat you last?\""},
]
const SORE := {"harry": "loss", "george": "weak", "phillip": "loss", "bhavya": "technique", "kelvin": "girl", "tommy": "girl", "luie": "technique", "erick": "weak"}
const SORE_REPLY := {
	"technique": ["Twelve years I've worked on this hand. Twelve.", "Say that again. Slowly."],
	"weak": ["Weak. WEAK? Get to the table.", "You don't get to say that to me."],
	"girl": ["Keep her name out of your mouth.", "What did you just say about her?"],
	"loss": ["We don't bring that up. Nobody brings that up.", "That was a slip. Everyone saw it was a slip."],
}
const SHRUG := {
	"technique": ["Says the one with the floppy wrist.", "Okay, coach."],
	"weak": ["Come and find out.", "Heard worse from my nan."],
	"girl": ["She's got better taste than that.", "Ha. No she wasn't."],
	"loss": ["Not you, anyway.", "Everybody loses. Ask around."],
}
const TOO_FAR := ["Too far.", "Oi. Not that.", "You don't say that here.", "Whoa."]

## Ways to talk a stranger into a pull. Each of them falls for one.
const PITCH := [
	{"key": "dare", "say": "\"Bet you couldn't beat me.\""},
	{"key": "flatter", "say": "\"You look like you've got an arm on you.\""},
	{"key": "honest", "say": "\"It's free, it's friendly, it takes two minutes.\""},
	{"key": "food", "say": "\"There are snacks. Here, have one.\""},
]
const PITCH_YES := {"dare": "Oh, is that right? Move.", "flatter": "...Well. I did row at school.", "honest": "Two minutes? Go on, then.", "food": "You should have opened with the snack."}
const PITCH_NO := ["Ha. No.", "I really do have to go.", "Not my thing.", "Maybe next time."]

## Things people stand around saying to each other. "any" is filled by whoever is free.
const CONVOS := [
	{"who": ["harry", "erick"], "lines": [[1, "When do I get a shot at the 70s title?"], [0, "When you make 70."], [1, "I can cut."], [0, "You can't cut a leg off, Erick."]]},
	{"who": ["harry", "george"], "lines": [[1, "Council wants the booking form in again."], [0, "We sent it."], [1, "They want it in blue ink."], [0, "...Of course they do."]]},
	{"who": ["tommy", "bhavya"], "lines": [[0, "Is it true the beard has its own protein intake?"], [1, "Don't."], [0, "Does it get a rest day?"], [1, "Tommy."]]},
	{"who": ["kelvin", "phillip"], "lines": [[0, "You eating tonight?"], [1, "After."], [0, "After what?"], [1, "Training."], [0, "It's seven o'clock at night."]]},
	{"who": ["luie", "tommy"], "lines": [[1, "What are you thinking about?"], [0, "Nothing."], [1, "You can't think about nothing."], [0, "You'd be surprised."]]},
	{"who": ["george", "kelvin"], "lines": [[0, "Do the pin again for the camera."], [1, "I've done it four times."], [0, "You blinked in three of them."]]},
	{"who": ["erick", "phillip"], "lines": [[0, "Left arms. Now."], [1, "After this set."], [0, "You said that an hour ago."], [1, "It's a long set."]]},
	{"who": ["bhavya", "luie"], "lines": [[0, "Your fake-out. How early do you sell it?"], [1, "Before I sit down."], [0, "...That's actually clever."]]},
	{"who": ["harry", "bhavya"], "lines": [[0, "We need a second ref."], [1, "I'll do it."], [0, "You'd coach both of them mid-pull."], [1, "...Yes. Probably."]]},
	{"who": ["harry", "kelvin"], "lines": [[0, "Kelvin. The snack budget."], [1, "What about it?"], [0, "It's gone. It's the eighth."], [1, "Inflation."]]},
	{"who": ["harry", "tommy"], "lines": [[0, "Was it you who chalked my car door handle?"], [1, "No."], [0, "Tommy."], [1, "Which door?"]]},
	{"who": ["harry", "luie"], "lines": [[0, "You good for the comp next month?"], [1, "Yeah."], [0, "You sure? You've been quiet."], [1, "I'm always quiet. I'm good."]]},
	{"who": ["harry", "phillip"], "lines": [[0, "You should take a week off."], [1, "No."], [0, "Your elbow's taped to your wrist."], [1, "It's supportive."]]},
	{"who": ["george", "tommy"], "lines": [[0, "I need a caption for tonight's post."], [1, "'Arms and the men.'"], [0, "No."], [1, "'Pin there, done that.'"], [0, "...Maybe."]]},
	{"who": ["george", "bhavya"], "lines": [[0, "Can you do a technique video for the page?"], [1, "How long?"], [0, "Thirty seconds."], [1, "I'd need forty minutes. Minimum."]]},
	{"who": ["george", "luie"], "lines": [[0, "You never post anything."], [1, "I liked your one about the banners."], [0, "That was in March."], [1, "It was a good post."]]},
	{"who": ["george", "erick"], "lines": [[1, "Tag me in the one where I win."], [0, "Which one? You say that every week."], [1, "All of them."]]},
	{"who": ["george", "phillip"], "lines": [[0, "Smile for one photo. One."], [1, "This is it."], [0, "That's the smile?"], [1, "That's the smile."]]},
	{"who": ["phillip", "bhavya"], "lines": [[1, "Your pronation's improved."], [0, "..."], [1, "That's a compliment."], [0, "I know. Thank you."]]},
	{"who": ["phillip", "tommy"], "lines": [[1, "Phillip. Phillip. Knock knock."], [0, "No."], [1, "You have to say who's there."], [0, "I don't."]]},
	{"who": ["phillip", "luie"], "lines": [[0, "..."], [1, "..."], [0, "Good talk."], [1, "Yeah."]]},
	{"who": ["bhavya", "kelvin"], "lines": [[0, "You're leaning back before the go."], [1, "It's working."], [0, "It's a foul."], [1, "It's working AND it's a foul."]]},
	{"who": ["bhavya", "erick"], "lines": [[1, "Rank my hook. Honestly."], [0, "Seven."], [1, "Out of?"], [0, "You don't want to know out of what."]]},
	{"who": ["kelvin", "tommy"], "lines": [[1, "If you were a snack, which one?"], [0, "The red ones."], [1, "Why?"], [0, "Because there's never any left."]]},
	{"who": ["kelvin", "luie"], "lines": [[0, "Want half of this?"], [1, "Go on."], [0, "...Smaller half."], [1, "Obviously."]]},
	{"who": ["kelvin", "erick"], "lines": [[1, "Left arms after this."], [0, "I've just eaten."], [1, "You've always just eaten."], [0, "So it's never a good time. Sad."]]},
	{"who": ["tommy", "erick"], "lines": [[0, "Erick, what's your walkout song?"], [1, "I don't have one."], [0, "I've picked one for you. It's the wiggles."], [1, "Table. Now."]]},
	{"who": ["luie", "erick"], "lines": [[1, "How do you stay that calm?"], [0, "I count the lights on the bridge."], [1, "How many?"], [0, "Thirty-one. One's out."]]},
	{"who": ["any", "any"], "lines": [[0, "Is it me or is the chalk different?"], [1, "It's the cheap stuff."], [0, "Who bought the cheap stuff?"], [1, "George. Don't start."]]},
	{"who": ["any", "any"], "lines": [[0, "My wrist is making a noise."], [1, "What kind of noise?"], [0, "Like a door."], [1, "That's fine. Doors are fine."]]},
	{"who": ["any", "any"], "lines": [[0, "The seagulls were back last month."], [1, "They know when we're here."], [0, "They can't know."], [1, "They know."]]},
	{"who": ["any", "any", "any"], "lines": [[0, "Best pull you ever saw. Go."], [1, "Harry, 2022 final."], [2, "Kelvin against the vending machine."], [0, "That wasn't a pull."], [2, "He won, though."]]},
	{"who": ["any", "any"], "lines": [[0, "Somebody's left a traffic cone up the back."], [1, "It's been there since April."], [0, "Should we move it?"], [1, "It's part of the club now."]]},
	{"who": ["any", "any", "any"], "lines": [[0, "Who's driving to Newcastle?"], [1, "Not it."], [2, "Not it."], [0, "It's always me."], [1, "You've got the good car."]]},
	{"who": ["any", "any"], "lines": [[0, "You ever think about just... not competing?"], [1, "No."], [0, "Me neither. Just checking."]]},
	{"who": ["any", "any"], "lines": [[0, "My mum asked what I do on Sundays."], [1, "What did you say?"], [0, "Church."], [1, "Basically true."]]},
	{"who": ["any", "any"], "lines": [[0, "Who's bringing the tables next month?"], [1, "Not me. My car smells of chalk."], [0, "Everyone's car smells of chalk."]]},
	{"who": ["any", "any"], "lines": [[0, "We're still short of 88."], [1, "How many now?"], [0, "Eight. And whoever that new one is."], [1, "So nine, on a good night."]]},
	{"who": ["any", "any", "any"], "lines": [[0, "Hook or toproll, if you had to pick one?"], [1, "Toproll."], [2, "Hook."], [0, "Press."], [1, "Nobody asked about press."]]},
	{"who": ["any", "any"], "lines": [[0, "Did you see the jogger stop?"], [1, "They always stop."], [0, "They never pull, though."], [1, "Somebody should ask them."]]},
]
## What they say to each other about you, when one of them has had enough of you.
const ABOUT_YOU := [[0, "The new one. What do we think?"], [1, "Don't get me started."], [0, "That bad?"], [1, "Watch your bag, is all I'm saying."]]
const ABOUT_YOU_GOOD := [[0, "The new one's alright, you know."], [1, "Yeah?"], [0, "Brought snacks round. Pulled properly."], [1, "Huh. Good."]]

## Small talk that is theirs alone.
const SMALL := {
	"harry": ["Tables go up at four. I'm here at three. Someone has to be.", "I check every pad before every meet. One loose peg and it's a hospital trip.", "People think the champion's the strongest. He's the one who turned up most.", "My wife times me. If I'm not home by eight she sends George a text.", "You see how they look at the tables when they walk in? That's why I do this."],
	"george": ["I've got four hundred hours of footage and no idea how to edit.", "The council form asks 'nature of activity'. I put 'consensual hand fighting'. They rang me.", "Harry gets the trophies. I get the group chat.", "If you see the tin, shake it. If it rattles, that's buttons.", "I only started so I could beat him. Still working on it."],
	"phillip": ["...", "Forty minutes of wrist work a day. Minimum.", "I don't warm up. I arrive warm.", "Talking uses energy.", "I counted the tiers once. There are eight."],
	"bhavya": ["Your grip starts at your feet. Nobody believes that until it works.", "I've got a notebook on every puller in NSW. Yours has one line so far.", "The beard has been to three nationals. More than most people here.", "Seventy percent of pulls are lost before 'go'. I can show you the data.", "I coach for free. People still don't listen. Explain that."],
	"kelvin": ["Red ones are barbecue. Yellow are cheese. Blue are a mistake.", "I'm not big. I'm in a bulk. Since 2019.", "People are scared to pull me. I'd never hurt anyone. I'd just win.", "My mum makes me bring a container for leftovers. There are never leftovers.", "Side pressure's just leaning with intent."],
	"tommy": ["I've got a bit about wrist straps. It's not ready. Do you want to hear it? It's not ready.", "I chalked the inside of Harry's cap once. He wore it all day.", "Everyone needs a job at the meet. Mine's morale.", "I'm quick, not strong. So I talk till they're tired.", "If Phillip ever laughs out loud I'm retiring."],
	"luie": ["The tide's going out.", "I like it here before everyone arrives.", "You can hear the ferry if you listen.", "...", "Good light tonight."],
	"erick": ["Left arms. Right now. No? Later, then.", "I sleep with a grip trainer. Not a joke.", "Everyone here's a mate until we're on the pad.", "I've pulled every one of them. I keep a ledger.", "You look like you've got a hook in you. Prove me wrong."],
}

## What kind of compliment lands with each of them, and what kind of joke.
const FLATTER := {"harry": "role", "george": "role", "phillip": "pull", "bhavya": "look", "kelvin": "pull", "tommy": "look", "luie": "pull", "erick": "pull"}
const COMPLIMENTS := [
	{"key": "pull", "say": "\"I've been watching you pull. You're the real thing.\""},
	{"key": "look", "say": "\"You're the best-looking one here, and you know it.\""},
	{"key": "role", "say": "\"This club wouldn't run without you.\""},
]
const FLATTERED := {
	"pull": ["You were watching? ...What did you see? Tell me everything.", "That means something, from someone who's actually paying attention."],
	"look": ["Finally. Someone with eyes.", "I've been saying it for years."],
	"role": ["Say that again when the others are listening.", "...Thank you. Nobody says that."],
}
const FLATTER_MEH := ["Cheers. I suppose.", "Okay. Thanks?", "What are you after?", "Nice of you."]
const HUMOUR := {"harry": "dad", "george": "roast", "phillip": "none", "bhavya": "dry", "kelvin": "dad", "tommy": "pun", "luie": "dry", "erick": "roast"}
const JOKES := [
	{"key": "pun", "say": "\"I used to arm wrestle. Then I lost my grip on reality.\""},
	{"key": "dad", "say": "\"What do you call a puller with no arms? Whatever you like, he can't pin you.\""},
	{"key": "dry", "say": "\"I chalked up once. The council sent me a bill.\""},
	{"key": "roast", "say": "\"I've seen Tommy pull. I've seen stronger handshakes at a funeral.\""},
]
const LAUGHS := ["HA. Okay. That's good.", "Ha! I'm stealing that.", "...Heh. Alright.", "That's terrible. Tell it again."]
const NO_LAUGH := ["...Right.", "Is that the whole joke?", "Keep working on it.", "Tommy does it better. And Tommy's bad."]
const HIGH_FIVE := {"yes": ["YES. Up top.", "There it is!", "Solid."], "meh": ["...Sure.", "Okay. One."], "no": ["No.", "Put your hand down.", "We're not there."]}
const DANCE := {"yes": ["Oh, we're doing this? We're doing this.", "Go on, then!", "I've got moves. Watch."], "no": ["I don't dance.", "Absolutely not.", "Not sober. Not here."]}
const WATCHING_DANCE := ["What is happening?", "Somebody film this.", "Go on!", "I can't look.", "George! Camera!"]
const LEFT_HANGING := ["Ooh. Left hanging.", "That's cold.", "Oof."]

## Visiting pullers. One turns up each real week.
const GUESTS := [
	{"id": "g_mei", "name": "Mei from Parramatta", "role": "Visiting: Parramatta Pullers", "strength": 74, "look": {"body": "Female_Ranger", "hair": "Hair_Buns", "tint": Color(0.2, 0.55, 0.5)}, "mind": {"warmth": 0.2, "open": 1.2},
		"chat": ["Your tables are lower than ours. I like it.", "We've got forty members. No snacks, though. You win on snacks.", "I came to scout Erick. Don't tell him."]},
	{"id": "g_baz", "name": "Baz the truckie", "role": "Visiting: pulls at servos", "strength": 83, "look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "beard": true, "tint": Color(0.85, 0.45, 0.15), "build": 1.15}, "mind": {"warmth": 0.1, "grudge": 1.2},
		"chat": ["I pull at truck stops. Winner gets the pie.", "Never trained a day. Just gearboxes.", "Is that bloke counting his own reps? Out loud?"]},
	{"id": "g_ana", "name": "Ana the physio", "role": "Visiting: here professionally", "strength": 62, "look": {"body": "Female_Peasant", "hair": "Hair_Long", "tint": Color(0.9, 0.9, 0.95)}, "mind": {"warmth": 0.4, "open": 1.3},
		"chat": ["I have treated every elbow in this amphitheatre.", "None of you warm up. None.", "I'm not here to pull. I'm here to say I told you so."]},
	{"id": "g_kai", "name": "Kai, sixteen", "role": "Visiting: somebody's little brother", "strength": 66, "look": {"body": "Male_Ranger", "hair": "Hair_SimpleParted", "tint": Color(0.95, 0.85, 0.2), "build": 0.9}, "mind": {"warmth": 0.3, "chatty": 0.9},
		"chat": ["I'm going to be the youngest ever champion.", "I beat my PE teacher. Twice.", "Is the chalk free? Can I have some for school?"]},
	{"id": "g_ron", "name": "Ron from the council", "role": "Visiting: 'just observing'", "strength": 57, "look": {"body": "Male_Ranger", "hair": "Hair_SimpleParted", "tint": Color(0.6, 0.65, 0.6)}, "mind": {"warmth": -0.1, "grudge": 1.3},
		"chat": ["Is this booking for sport or 'gathering'? The form matters.", "Somebody's been feeding the gulls. That's a fine.", "...Could I have a go? Off the record."]},
]
## This week's find, and roughly where it has been left.
const FINDS := [
	{"item": "sweatband", "at": Vector3(-22, 0, 3), "hint": "out past the trees on the left"},
	{"item": "boom_box", "at": Vector3(19, 2.4, -14), "hint": "up at the very top of the seating"},
	{"item": "gold_chalk", "at": Vector3(22, 0, 26), "hint": "right down by the water's edge"},
	{"item": "cape", "at": Vector3(-3, 0, 23.2), "hint": "near the lions at the gate"},
]
const RUMOURS := ["gulls", "drone", "ufo", "gulls", "drone"]

## How someone currently has you figured, and how they open a conversation when they do.
const ATTITUDES := {
	"afraid": ["afraid of what you'll do next", ["...What do you want.", "Just keep your hands where I can see them."]],
	"arm_not_bag": ["respects your arm, watches their bag", ["Good puller. Shame about the rest of you.", "I'll pull you any day. I'm not leaving my bag near you."]],
	"no_trust": ["doesn't trust you an inch", ["I counted my straps before you walked over.", "Whatever you're selling, no."]],
	"funny_pest": ["can't decide if you're funny or a pest", ["Here we go. What is it this time?", "I shouldn't laugh. I'm not going to laugh."]],
	"mouth": ["has had enough of your mouth", ["Think before you open it.", "If the next thing you say isn't an apology, save it."]],
	"wary": ["wary of you", ["Easy. I saw what you did.", "We're fine as long as you stay calm."]],
	"rates_likes": ["rates you, and likes you", ["Here's trouble. The good kind.", "You're turning into one of us, you know."]],
	"respects": ["respects you at the table", ["That hand of yours. I've been thinking about it.", "You earned that last one. Don't let it go to your head."]],
	"laugh": ["thinks you're a laugh", ["Oh good, it's you. Tonight was getting dull.", "What have you done now? Tell me everything."]],
	"amused": ["amused by you, against their judgement", ["I'm not encouraging you. ...Go on, then.", "You're a menace. Carry on."]],
	"trusts": ["would trust you with their strap", ["Watch my bag a sec? You're the only one I'd ask.", "Good, it's you. I need a second opinion on something."]],
	"owes": ["feels they owe you one", ["I haven't forgotten what you did for me.", "Need anything? I mean it."]],
	"warming": ["warming to you", ["Hey, you. Good to see you about.", "Sit down. How's your night going?"]],
	"sussing": ["still working you out", ["So. What's your story?", "You're new. I'm watching. In a friendly way."]],
	"neutral": ["has no strong feelings about you yet", ["Evening.", "Hey."]],
	"hurt": ["hurt by what you said", ["I thought we were alright, you and me.", "That stuck with me, what you said."]],
	"cold": ["being coldly polite", ["Hello.", "Can I help you with something?"]],
	"done": ["finished with you", ["No.", "Not you. Not tonight."]],
}

## What they say when they come and sit down next to you.
const BENCH := {
	"harry": ["Mind if I sit? Been on my feet since three.", "You know, I worry nobody would turn up, every month. Then they do."],
	"george": ["Budge up. I need five minutes where nobody asks me where the tape is.", "Do you think it's any good? The club? Honestly?"],
	"phillip": ["...", "It's quieter over here. I like it."],
	"bhavya": ["Sit up straight. Kidding. Mostly.", "You've got decent levers, you know. I've been watching."],
	"kelvin": ["Is this seat taken? I brought two of these. One's yours.", "I come here for the snacks. I stay for the snacks. And you lot."],
	"tommy": ["Oh good, a captive audience.", "Don't tell them, but this is the best bit of my week."],
	"luie": ["...Good spot.", "You can see the bridge from here."],
	"erick": ["Sitting? In the middle of a meet? ...Fine. Two minutes.", "What do you do, outside this? I never ask anyone."],
}

const CYCLIST := {"id": "p_bike", "likes": "dare", "name": "The cyclist", "role": "Forty k before dinner", "strength": 61, "pace": 1.6, "stops": 0.0,
	"look": {"body": "Male_Ranger", "hair": "Hair_Buzzed", "tint": Color(0.95, 0.85, 0.1)}, "mind": {"warmth": 0.0, "grudge": 1.2},
	"chat": ["Carbon frame. Eleven grand. Don't breathe on it.", "I've done forty k and I'm not even warm.", "Is that arm wrestling? I've got the legs for it. Is it legs?"]}

## The people who are always at their posts round the edge of the meet.
const STAFF := [
	{"id": "s_busker", "name": "Dee the busker", "role": "Guitar, and opinions", "strength": 55, "at": Vector3(-7.5, 0, 26.6), "yaw": PI, "anim": "Idle_Talking",
		"look": {"body": "Female_Ranger", "hair": "Hair_Long", "tint": Color(0.75, 0.4, 0.8)}, "mind": {"warmth": 0.3, "open": 1.3, "chatty": 0.8},
		"chat": ["I've played this spot four years. You lot are my best audience and my worst tippers.", "Requests are two dollars. Wonderwall is ten.", "I wrote a song about the big one who eats. He doesn't know.", "The acoustics off those steps are unreal, you know.", "I used to be in a band. We were called Elbow Grease. Yes, really."]},
	{"id": "s_fisher", "name": "Old Con the fisherman", "role": "Same spot since 1991", "strength": 70, "at": Vector3(15.0, 0, 28.3), "yaw": 0.0, "anim": "Idle",
		"look": {"body": "Male_Ranger", "hood": true, "tint": Color(0.35, 0.45, 0.3)}, "mind": {"warmth": 0.1, "grudge": 1.1, "chatty": 0.4},
		"chat": ["Bream. Mostly bream. Once a shopping trolley.", "You lot scare the fish with the shouting. They like it. Fish are nosy.", "Thirty years on this rail. I've seen that bridge get built.", "Don't eat anything out of here. I don't. I just like winning.", "There's a big one under the wharf. I've had him on twice."]},
	{"id": "s_kebab", "name": "Sami at the kebab van", "role": "The lot? Garlic? Chilli?", "strength": 74, "at": Vector3(-15.6, 0, 25.9), "yaw": 0.5, "anim": "Idle_Talking",
		"look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "beard": true, "tint": Color(0.95, 0.95, 0.95)}, "mind": {"warmth": 0.3, "open": 1.2, "chatty": 0.9},
		"chat": ["Your big friend is my best customer and my biggest problem.", "Garlic AND chilli. Anyone who says one or the other is a coward.", "I park here because of you lot. Arm wrestlers eat like they're being paid.", "My cousin says I should franchise. My cousin has never cleaned a rotisserie.", "Chicken salt is a human right."]},
]

## Second and third steps of conversations that branch more than once.
const MORE := {
	"handover2": {"reply": "...Do you live in the park?", "opts": [
		{"say": "It's a lifestyle.", "reply": "Respect. Honestly. Have the spring rolls. The pad thai stays.", "v": 0.2, "do": "food1"},
		{"say": "No. I'm lying. I'm just hungry.", "reply": "FINALLY, some honesty. Take it. Nobody's ever just said that.", "v": 0.5, "do": "food"}]},
	"flirt2": {"reply": "Alright. One question. Kelvin says the club needs 'eighty more idiots'. Are you one of the idiots?", "opts": [
		{"say": "Proudly.", "reply": "Ha. Good. I like a person who knows what they are.", "v": 0.35, "then": "flirt3"},
		{"say": "I'm more of a consultant.", "reply": "Oh no. No no no.", "v": -0.3},
		{"say": "I'd be an idiot for the right person.", "reply": "...That's either very smooth or very sad. I'm going with smooth.", "v": 0.4, "then": "flirt3"}]},
	"flirt3": {"reply": "Last one. Dinner. Where are you taking me?", "opts": [
		{"say": "The kebab van. The Riser. Everything twice.", "reply": "The VAN. With the chicken salt. You get it. You actually get it.", "v": 0.6, "do": "kiss"},
		{"say": "Somewhere with a tablecloth.", "reply": "Mm. Safe. Nice. Maybe.", "v": 0.15},
		{"say": "Kelvin's mum's. I hear she does spring rolls.", "reply": "You want to meet my AUNTIE on a first date? ...Honestly? Bold. I respect it.", "v": 0.5, "do": "kiss"}]},
}
