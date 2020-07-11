extends Node2D


const MOVE_SPEED = 500
const JUMP_FORCE = 1000
const GRAVITY = 50
const MAX_FALL_SPEED = 1000

var y_velo = 0
var facing_right = false
var coyote_time = 5
var kinematic_body;
var cur_lag_label;
var body_start_pos;

var is_right = false
var is_left = false
var is_jump = false

# TODO use states so that the player doesn't move whilst in another state
# enum {PAUSED, NORMAL, BANDING}.
var game_paused = false;
var is_banding = false;

enum {RIGHT_PRESS, RIGHT_RELEASE, LEFT_PRESS, LEFT_RELEASE, JUMP_PRESS, JUMP_RELEASE}
var press_dir = {
	"right": RIGHT_PRESS,
	"left": LEFT_PRESS,
	"jump": JUMP_PRESS
}

var release_dir = {
	"right": RIGHT_RELEASE,
	"left": LEFT_RELEASE,
	"jump": JUMP_RELEASE
}

var key_presses = []
var key_timings = []
var dLag = 0.0
var lag = 0.0
var next_lag = 0.0

var band_positions = []
var band_timings = []
var stored_band_time = 0.0
const MAX_BAND_TIME = 2.0

# Called when the node enters the scene tree for the first time.
func _ready():
	kinematic_body = get_node("KinematicBody2D")
	cur_lag_label = kinematic_body.get_node("CurLag")
	body_start_pos = kinematic_body.get_position()
	update_lag_and_label(0.2)
	update_next_lag(0.2)	

func _input(event):
	# TODO use states instead of boolean
	if(event.is_action_pressed("pause")):
		if game_paused:
			game_paused = false
		else:
			game_paused = true

	if(event.is_action_pressed("rubber_band")):
		is_banding = true
		return
	elif (event.is_action_released("rubber_band")):
		is_banding = false

	if game_paused:
		return

	add_key_event_to_conveyor(event)
	
	# Test purposes
	if event.is_action_pressed("lag_up"):
		update_next_lag(next_lag + 0.05)

	if event.is_action_pressed("lag_down"):
		update_next_lag(next_lag - 0.05)

	if event.is_action_pressed("reset_pos"):
		reset_body_and_clear_actions()

func reset_body_and_clear_actions():
	kinematic_body.set_position(body_start_pos)
	key_presses = []
	key_timings = []
	y_velo = 0
	is_right = false
	is_left = false
	is_jump = false
	band_positions = []
	band_timings = []
	stored_band_time = 0.0

func _physics_process(delta):
	if game_paused:
		return

	if is_banding:
		if band_positions.size() > 0: 
			var time_reversed = 0
			while time_reversed < delta and band_positions.size() > 0:
				var pos = band_positions.pop_back()
				var timing = band_timings.pop_back()
				time_reversed += timing
				kinematic_body.set_position(pos)
				stored_band_time -= delta
				print(band_positions.size())
			return
	else:
		if stored_band_time < MAX_BAND_TIME:
			band_positions.append(kinematic_body.get_position())
			band_timings.append(delta)
			stored_band_time += delta
		else: 
			band_positions.append(kinematic_body.get_position())
			band_timings.append(delta)		
			band_positions.pop_front()
			band_timings.pop_front()

	print(band_positions.size())


	adjust_lag(delta)
	rotate_key_event_conveyor(delta)

	var move_dir = 0
	if is_right:
		move_dir += 1
	if is_left:
		move_dir -= 1
	kinematic_body = get_node("KinematicBody2D")
	kinematic_body.move_and_slide(Vector2(move_dir * MOVE_SPEED, y_velo), Vector2(0, -1))
	
	var grounded = kinematic_body.is_on_floor()
	if grounded:
		coyote_time = 20
	y_velo += GRAVITY
#	if coyote_time > 0:
#		print("coyote_time")
	if coyote_time > 0 and is_jump:
		y_velo = -JUMP_FORCE
	if grounded and y_velo >= 5:
		y_velo = 5
	if y_velo > MAX_FALL_SPEED:
		y_velo = MAX_FALL_SPEED
	coyote_time -= delta * 100
#	print(delta)

func adjust_lag(delta): 
	dLag = 0
	if abs(lag - next_lag) > 0.000001:
		#lag adjustment
		if lag < next_lag:
			dLag = min((next_lag - lag), delta)
		else:
			dLag = - min((lag - next_lag), delta)
		update_lag_and_label(lag + dLag)
	else:
		update_lag_and_label(next_lag)		

func add_key_event_to_conveyor(event):
	for key_name in press_dir: 
		if event.is_action_pressed(key_name):
			key_presses.append(press_dir[key_name])
			key_timings.append(lag)
	
	for key_name in release_dir: 
		if event.is_action_released(key_name):
			key_presses.append(release_dir[key_name])
			key_timings.append(lag)

func rotate_key_event_conveyor(delta):
	for i in range(0, key_timings.size()): 
		key_timings[i] = key_timings[i] - delta + dLag

	while (key_timings.size() > 0 and key_timings[0] <= 0):
		key_timings.pop_front()
		var press = key_presses.pop_front()
		match (press):
			RIGHT_PRESS:
				is_right = true
			RIGHT_RELEASE:
				is_right = false
			LEFT_PRESS:
				is_left = true
			LEFT_RELEASE:
				is_left = false
			JUMP_PRESS:
				is_jump = true
			JUMP_RELEASE:
				is_jump = false

func update_lag_and_label(new_lag): 
	if new_lag < 0: 
		new_lag = 0
	lag = new_lag
	cur_lag_label.text = String(int(new_lag*1000)) + " ms"

func update_next_lag(new_lag): 
	if new_lag < 0: 
		new_lag = 0
	next_lag = new_lag
