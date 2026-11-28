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
	"harry": [
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
