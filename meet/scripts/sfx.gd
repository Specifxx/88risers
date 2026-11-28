extends Node
## Every sound in the game. One-shots go through a small pool; the crowd and the music loop.

const DIR := "res://assets/sfx/"
const LOOPS := ["murmur", "music", "music2", "music3", "music4", "ufo", "drone"]
const TRACKS := ["music", "music2", "music3"]
const TRACK_NAMES := ["the usual koto loop", "something with a beat", "a slow groove"]
var track := 0

var _pool: Array = []
var _next := 0
var _loops := {}
var _cache := {}
var _last := {}

func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var s: AudioStreamWAV = load(DIR + name + ".wav")
		if name in LOOPS:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		_cache[name] = s
	return _cache[name]

## gap: do not repeat this sound more often than this many seconds.
## What the louder or stranger sounds are, in words, shown on screen while they play.
const CAPTIONS := {"ufo": "a hum from the ship", "drone": "a drone's motor, overhead", "horn": "the ferry's horn", "pipes": "bagpipes", "rumble": "a deep rumble",
	"crash": "a crash", "gull": "seagulls", "whistle": "Harry's whistle", "sting": "somebody has had enough of you", "zap": "a zap", "bark": "a dog",
	"music4": "phonk, from nowhere", "ooh": "the crowd reacting"}

func caption(name: String, seconds := 2.5) -> void:
	if CAPTIONS.has(name) and Meet.hud != null:
		Meet.hud.sound_caption(CAPTIONS[name], seconds)

func play(name: String, db := 0.0, pitch := 1.0, gap := 0.0) -> void:
	if Meet.muted:
		return
	if db > -11.0:
		caption(name)
	var now := Time.get_ticks_msec() / 1000.0
	if gap > 0.0 and now - float(_last.get(name, -99.0)) < gap:
		return
	_last[name] = now
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _stream(name)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

func loop(name: String, on: bool, db := -8.0) -> void:
	if on and not Meet.muted:
		caption(name, 6.0)
		if not _loops.has(name):
			var p := AudioStreamPlayer.new()
			add_child(p)
			p.stream = _stream(name)
			_loops[name] = p
		_loops[name].volume_db = db
		if not _loops[name].playing:
			_loops[name].play()
	elif _loops.has(name):
		_loops[name].stop()

func set_muted(m: bool) -> void:
	Meet.muted = m
	if m:
		for k in _loops:
			_loops[k].stop()
	else:
		loop(TRACKS[track], true, -12.0)

## Change what is playing. Returns the name of the new track.
func next_track() -> String:
	loop(TRACKS[track], false)
	track = (track + 1) % TRACKS.size()
	loop(TRACKS[track], true, -10.0)
	return TRACK_NAMES[track]

## Cut to another track for a while, then back to whatever was on.
func interlude(name: String, seconds: float) -> void:
	if Meet.muted:
		return
	loop(TRACKS[track], false)
	loop(name, true, -9.0)
	get_tree().create_timer(seconds).timeout.connect(func():
		loop(name, false)
		if not Meet.muted:
			loop(TRACKS[track], true, -12.0))
