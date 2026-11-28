extends Node
## Every sound in the game. One-shots go through a small pool; the crowd and the music loop.

const DIR := "res://assets/sfx/"
const LOOPS := ["murmur", "music", "ufo", "drone"]

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
func play(name: String, db := 0.0, pitch := 1.0, gap := 0.0) -> void:
	if Meet.muted:
		return
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
		loop("murmur", true, -9.0)
		loop("music", true, -13.0)
