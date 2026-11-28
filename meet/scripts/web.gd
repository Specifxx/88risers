extends RefCounted
## The web of talk. Things one person tells you become things you can raise with another,
## whose answer may send you on to a third, change how two of them get on, or start something.
##
## LEADS: id -> to (who you can raise it with), ask (your line), reply (theirs), then either
## plain effects or opts (ways to take it). Effects on a lead or an option:
##   v (how it lands with them), tie [a, b, change], lead (unlocks another), do (something happens).

## Which answers to a founder's own topics open a lead.
const GRANTS := {
	"(Laugh.)": "joke_bhavya",
	"Three years is real work.": "fouls_george",
	"Have you ever beaten him?": "y2019_harry",
	"Who beat you?": "dave_erick",
	"Six times? Mate.": "tally_tommy",
	"I'll get you one.": "tally_tommy",
	"Who taught you?": "thumb_tommy",
	"Can I train with you?": "sixam_phillip",
	"I'm growing one.": "oil_tommy",
	"Put me in it.": "video_kelvin",
	"(Look at the water with him.)": "water_harry",
	"So I watch the shoulder.": "shoulder_erick",
	"Sounds like you do the real work.": "realwork_harry",
	"Tell it to Phillip.": "joke_phillip",
	"Gold next year.": "gold_kelvin",
	"It's all muscle, clearly.": "muscle_bhavya",
}

const LEADS := {
	# Tommy's joke.
	"joke_bhavya": {"to": "bhavya", "ask": "\"Tommy says you didn't laugh at his side pressure joke.\"", "reply": "Because it isn't a joke. It's a sentence with arm wrestling in it.", "opts": [
		{"say": "It's a bit funny.", "reply": "...It's a four. Tell him it's a four.", "v": 0.1, "lead": "joke_four"},
		{"say": "He's properly hurt about it.", "reply": "Is he? Ugh. Fine. Tell him it was a six.", "v": 0.2, "tie": ["bhavya", "tommy", 0.1], "lead": "joke_six"},
		{"say": "You're right. It's terrible.", "reply": "Thank you. Somebody had to say it.", "v": 0.35, "lead": "joke_terrible"}]},
	"joke_six": {"to": "tommy", "ask": "\"Bhavya says the joke was a six out of ten.\"", "reply": "A SIX. From Bhavya! That's a standing ovation. I'm telling everyone.", "v": 0.5, "tie": ["bhavya", "tommy", 0.2], "do": "tell:tommy:bhavya"},
	"joke_four": {"to": "tommy", "ask": "\"Bhavya gave the joke a four.\"", "reply": "A four. Out of five?", "opts": [
		{"say": "Out of five. Sure.", "reply": "KNEW it. He loves it really.", "v": 0.4, "tie": ["bhavya", "tommy", 0.1], "lead": "joke_lie"},
		{"say": "Out of ten, mate.", "reply": "Right. Well. His beard's a four.", "v": -0.1, "tie": ["bhavya", "tommy", -0.1], "lead": "beard_four"}]},
	"joke_terrible": {"to": "tommy", "ask": "\"Bhavya and I agree the joke's terrible.\"", "reply": "You went and got a second opinion?! Unbelievable.", "v": -0.4, "tie": ["bhavya", "tommy", -0.15]},
	"joke_lie": {"to": "bhavya", "ask": "\"Tommy thinks you gave it four out of five.\"", "reply": "Why would you tell him that? Now he'll do it at every meet.", "v": -0.25, "tie": ["bhavya", "tommy", 0.05]},
	"beard_four": {"to": "bhavya", "ask": "\"Tommy says your beard's a four.\"", "reply": "He said what about the beard.", "opts": [
		{"say": "He was just sore about the joke.", "reply": "...Fine. I'll let it go. This once.", "v": 0.15},
		{"say": "A four. Out of ten.", "reply": "Hold my chalk.", "v": 0.1, "tie": ["bhavya", "tommy", -0.25], "do": "prank:bhavya:tommy"}]},
	"joke_phillip": {"to": "phillip", "ask": "\"Tommy told you his joke?\"", "reply": "He did.", "opts": [
		{"say": "And?", "reply": "...It was good. I laughed later. At home.", "v": 0.3, "lead": "phillip_laughed"},
		{"say": "You could have laughed.", "reply": "I was training.", "v": -0.15}]},
	"phillip_laughed": {"to": "tommy", "ask": "\"Phillip laughed at your joke. Later. At home.\"", "reply": "He WHAT. Phillip?! That's the best news I've had all year.", "v": 0.6, "tie": ["phillip", "tommy", 0.25], "do": "tell:tommy:phillip"},

	# The brothers.
	"fouls_george": {"to": "george", "ask": "\"Harry says he lost two finals on fouls.\"", "reply": "Fouls. His elbow came up so high it needed a passport.", "opts": [
		{"say": "(Laugh.)", "reply": "Don't tell him I said that. Actually, do.", "v": 0.35, "lead": "passport_harry"},
		{"say": "He won in the end, though.", "reply": "He did. I drove him to all three. Nobody mentions the driving.", "v": 0.2, "lead": "driving_harry"}]},
	"passport_harry": {"to": "harry", "ask": "\"George says your elbow needed a passport.\"", "reply": "He said WHAT.", "opts": [
		{"say": "He was joking.", "reply": "He's been making that joke since 2019. It's not getting better.", "v": 0.1},
		{"say": "He seemed pretty serious.", "reply": "Right. Get him over here. We're settling this at the table.", "v": 0.0, "tie": ["george", "harry", -0.2], "do": "match:harry:george"},
		{"say": "To be fair, I've seen the footage.", "reply": "You've been here five minutes.", "v": -0.35}]},
	"driving_harry": {"to": "harry", "ask": "\"George drove you to all three finals.\"", "reply": "...He did. Six hours each way to the second one.", "opts": [
		{"say": "Have you ever thanked him?", "reply": "No. I should. I'll do it now.", "v": 0.4, "tie": ["george", "harry", 0.3], "do": "tell:harry:george", "lead": "thanked_george"},
		{"say": "Some champion.", "reply": "Careful.", "v": -0.4}]},
	"thanked_george": {"to": "george", "ask": "\"Did Harry say something to you?\"", "reply": "He thanked me. For the driving. Four years late. Was that you?", "opts": [
		{"say": "Might have mentioned it.", "reply": "You're alright, you know that?", "v": 0.6},
		{"say": "No idea what you mean.", "reply": "Sure. Sure you don't.", "v": 0.35}]},
	"y2019_harry": {"to": "harry", "ask": "\"George says he beat you in 2019.\"", "reply": "My elbow slipped.", "opts": [
		{"say": "He says it did not slip.", "reply": "It SLIPPED.", "v": -0.15, "tie": ["george", "harry", -0.1]},
		{"say": "Rematch? Tonight?", "reply": "...George! Table. Now. We're doing this.", "v": 0.3, "do": "match:harry:george"},
		{"say": "I believe you.", "reply": "Thank you. Finally.", "v": 0.35}]},
	"realwork_harry": {"to": "harry", "ask": "\"George reckons he does the real work round here.\"", "reply": "He does. Don't tell him I said so.", "opts": [
		{"say": "I'm telling him.", "reply": "Don't you dare.", "v": 0.0, "lead": "harry_said_so"},
		{"say": "Your secret's safe.", "reply": "Good. He'd be unbearable.", "v": 0.3}]},
	"harry_said_so": {"to": "george", "ask": "\"Harry says you do the real work. He told me not to tell you.\"", "reply": "He said that? Out loud? I need that in writing.", "v": 0.6, "tie": ["george", "harry", 0.25]},

	# Phillip and the man from Penrith.
	"dave_erick": {"to": "erick", "ask": "\"Who's the man with hands like dinner plates?\"", "reply": "Big Dave. From Penrith. Phillip's been training for him for two years. Talks about him in his sleep, probably.", "opts": [
		{"say": "Could Phillip take him now?", "reply": "Now? Yeah. I think he could. Don't tell him I said that either.", "v": 0.2, "lead": "erick_believes"},
		{"say": "Could YOU take him?", "reply": "Obviously.", "v": 0.25, "lead": "erick_boast"}]},
	"erick_believes": {"to": "phillip", "ask": "\"Erick thinks you'd beat Big Dave now.\"", "reply": "...Erick said that.", "opts": [
		{"say": "His exact words.", "reply": "...Good.", "v": 0.5, "tie": ["erick", "phillip", 0.3]},
		{"say": "He also says you talk about Dave in your sleep.", "reply": "I'm going to have a word with Erick.", "v": -0.1, "tie": ["erick", "phillip", -0.15], "do": "tell:phillip:erick"}]},
	"erick_boast": {"to": "phillip", "ask": "\"Erick says he could beat Big Dave.\"", "reply": "Erick has never pulled Dave.", "opts": [
		{"say": "So settle it. Pull Erick.", "reply": "Fine.", "v": 0.2, "do": "match:phillip:erick"},
		{"say": "He was only talking.", "reply": "He always is.", "v": 0.1}]},
	"sixam_phillip": {"to": "phillip", "ask": "\"Erick trains at six a.m. You going?\"", "reply": "I'm there at five.", "v": 0.1, "lead": "five_erick"},
	"five_erick": {"to": "erick", "ask": "\"Phillip says he's there at five.\"", "reply": "He is not. ...Is he? Right. I'll be there at four.", "v": 0.3, "tie": ["erick", "phillip", 0.15], "lead": "four_phillip"},
	"four_phillip": {"to": "phillip", "ask": "\"Erick says he'll be there at four.\"", "reply": "...Three.", "v": 0.35, "tie": ["erick", "phillip", 0.15]},
	"gold_kelvin": {"to": "kelvin", "ask": "\"Phillip's going for gold next year.\"", "reply": "He'll get it. He doesn't eat. It's unnatural, but he'll get it.", "opts": [
		{"say": "Bring him something from the table.", "reply": "That's... actually a kind idea. I'll take him a yellow one. I don't like the yellow.", "v": 0.3, "tie": ["kelvin", "phillip", 0.2], "do": "tell:kelvin:phillip"},
		{"say": "More for you, then.", "reply": "That's how I see it.", "v": 0.2}]},

	# Kelvin and the snack table.
	"tally_tommy": {"to": "tommy", "ask": "\"Kelvin's been to the snack table six times.\"", "reply": "Seven. I'm keeping a tally on my phone.", "opts": [
		{"say": "Show me.", "reply": "Look. Timestamps. I'm a professional.", "v": 0.3, "lead": "tally_kelvin"},
		{"say": "That's a bit much, Tommy.", "reply": "It's called data.", "v": -0.1}]},
	"tally_kelvin": {"to": "kelvin", "ask": "\"Tommy's keeping a tally of your snack trips.\"", "reply": "He's WHAT.", "opts": [
		{"say": "It's at seven.", "reply": "It's a BULK.", "v": -0.2, "tie": ["kelvin", "tommy", -0.1]},
		{"say": "Want to get him back?", "reply": "With chalk. Yes. Watch this.", "v": 0.35, "tie": ["kelvin", "tommy", -0.1], "do": "prank:kelvin:tommy"},
		{"say": "I'd ignore it.", "reply": "I'm the bigger man. Literally.", "v": 0.2}]},
	"muscle_bhavya": {"to": "bhavya", "ask": "\"Kelvin says it's all muscle.\"", "reply": "It's sixty percent muscle. I've seen him train. The other forty is rice.", "opts": [
		{"say": "Rice is a strategy.", "reply": "It's working, to be fair. His side pressure is horrible.", "v": 0.2, "do": "tip"},
		{"say": "I'll tell him you said forty.", "reply": "Tell him. He knows.", "v": 0.0, "tie": ["bhavya", "kelvin", -0.05]}]},
	"video_kelvin": {"to": "kelvin", "ask": "\"George wants you to do the pin for the camera again.\"", "reply": "I've done it four times. I blinked in three.", "opts": [
		{"say": "Fifth time lucky.", "reply": "Fine. But I'm eating first.", "v": 0.1, "tie": ["george", "kelvin", 0.1], "do": "tell:kelvin:george"},
		{"say": "Tell him no.", "reply": "You tell him no. He's got the camera.", "v": 0.15}]},

	# Luie.
	"thumb_tommy": {"to": "tommy", "ask": "\"Luie's dad never let him win at thumb wars.\"", "reply": "That explains SO much. That explains everything about him.", "opts": [
		{"say": "Challenge him to one.", "reply": "Oh, I'm doing it. Thumb war. By the water. Tonight.", "v": 0.3, "lead": "thumbwar_luie"},
		{"say": "Don't tell him I told you.", "reply": "My lips are sealed. Mostly.", "v": 0.1}]},
	"thumbwar_luie": {"to": "luie", "ask": "\"Tommy wants a thumb war.\"", "reply": "...Tell him I've been waiting for someone to ask for twenty years.", "v": 0.4, "tie": ["luie", "tommy", 0.25], "do": "match:luie:tommy"},
	"water_harry": {"to": "harry", "ask": "\"Luie's by the water again.\"", "reply": "He does that before a big pull. Did you stand with him?", "opts": [
		{"say": "For a bit.", "reply": "Good. Most people talk at him. Thanks for that.", "v": 0.45, "tie": ["harry", "luie", 0.1]},
		{"say": "Bit odd, isn't he?", "reply": "He's the best listener in this club. Watch your mouth.", "v": -0.4}]},
	"shoulder_erick": {"to": "erick", "ask": "\"Luie says nobody watches the shoulder.\"", "reply": "The shoulder. THE SHOULDER. That's how he's been getting me for a year.", "opts": [
		{"say": "Don't say I told you.", "reply": "Never. But he's getting pulled. Tonight.", "v": 0.4, "tie": ["erick", "luie", -0.05], "do": "match:erick:luie", "lead": "luie_knows"},
		{"say": "Maybe you just lost.", "reply": "Nobody 'just loses' to a fake-out.", "v": -0.3}]},
	"luie_knows": {"to": "luie", "ask": "\"Erick knows about the shoulder.\"", "reply": "...You told him.", "opts": [
		{"say": "I did. Sorry.", "reply": "It's fine. I have a second one. Nobody watches the feet.", "v": 0.1, "do": "tip"},
		{"say": "No idea how he found out.", "reply": "Mm.", "v": -0.3}]},

	# The beard.
	"oil_tommy": {"to": "tommy", "ask": "\"Bhavya oils the beard.\"", "reply": "I KNEW it. I knew that shine wasn't natural.", "opts": [
		{"say": "You didn't hear it from me.", "reply": "Hear what? I know nothing. I know everything.", "v": 0.3, "lead": "oil_out"},
		{"say": "Go and ask him which brand.", "reply": "Oh, I'm asking.", "v": 0.3, "tie": ["bhavya", "tommy", -0.1], "do": "tell:tommy:bhavya", "lead": "oil_out"}]},
	"oil_out": {"to": "bhavya", "ask": "\"Tommy knows about the oil.\"", "reply": "I told you that in confidence.", "opts": [
		{"say": "I'm sorry. It slipped out.", "reply": "...It's argan. If you must know. Don't tell him THAT.", "v": -0.15},
		{"say": "It's a good beard. Own it.", "reply": "...You know what? Yes. It's argan oil and I'm not ashamed.", "v": 0.3}]},

	# Harry's job for you.
	"job_done": {"to": "harry", "ask": "\"That's three of the public I've got to the table.\"", "reply": "Three? In one night? You're hired. It's unpaid. Well done.", "v": 0.8, "do": "pay:20"},
}

## What people say about each other, by how the two of them currently get on.
const OPINION := {
	"harry": {"good": "Harry? Best thing that happened to this club. Don't tell him.", "mid": "Harry's Harry. Runs a tight meet.", "bad": "Harry thinks a whistle makes him the boss of everyone."},
	"george": {"good": "George holds this whole thing together. Nobody says it enough.", "mid": "George is alright. Always got that camera out.", "bad": "George films everything and pulls nothing."},
	"phillip": {"good": "Phillip's the hardest worker here. Quiet, but he sees everything.", "mid": "Phillip doesn't say much. Trains a lot.", "bad": "Phillip acts like talking to us costs him money."},
	"bhavya": {"good": "Bhavya's taught half of us everything we know.", "mid": "Bhavya will coach you whether you asked or not.", "bad": "Bhavya can't watch a pull without correcting it."},
	"kelvin": {"good": "Kelvin's a gentle giant. Strongest here, never mentions it.", "mid": "Kelvin's fine. Follow the crumbs and you'll find him.", "bad": "Kelvin treats the snack table like a second job."},
	"tommy": {"good": "Tommy keeps this place fun. It'd be a gym without him.", "mid": "Tommy's a clown. A decent one.", "bad": "Tommy thinks chalk in your eyes is a personality."},
	"luie": {"good": "Luie's the one I'd want in my corner. Calm.", "mid": "Luie keeps to himself. No trouble.", "bad": "Luie drifts off to the water whenever there's tables to carry."},
	"erick": {"good": "Erick wants it more than anyone. I respect that.", "mid": "Erick's intense. Good puller.", "bad": "Erick can't lose a pull without wanting three rematches."},
}
const TOLD := {
	"good": ["They said that? ...Huh. Good to know.", "Really? That's decent of them.", "Didn't think they'd noticed."],
	"bad": ["Did they now.", "Oh, is that what they think.", "Right. Noted. Thanks for telling me."],
	"worse": ["They said WHAT?", "I'm going over there.", "After everything I've done for them."],
	"soft": ["That sounds like them. Fair enough.", "Could be worse.", "Yeah, they're not wrong."],
}
