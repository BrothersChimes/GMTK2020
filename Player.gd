extends Node2D

const MOVE_SPEED = 100
const JUMP_FORCE = 200
const GRAVITY = 10
const MAX_FALL_SPEED = 300
const COYOTE_TIME = 0.2
const MAX_X = 5000
const MAX_Y = 5000
const MIN_X = 0
const MIN_Y = 0
const LAG_LOW = 0
const LAG_MED = 0.18
const LAG_HIGH = 0.55

var y_velo = 0
var facing_right = false
var coyote_time = COYOTE_TIME
var kinematic_body;
var cur_lag_label;
var body_start_pos;
var player_pos;
var collision_shape;
var rewind_effect;
var continue_effect;

var is_right = false
var is_left = false
var is_jump = false

# TODO use states so that the player doesn't move whilst in another state
# enum {PAUSED, NORMAL, BANDING}.
var game_paused = false;
var glitch_state = NORMAL

enum {NORMAL, BANDING, CONTINUE_GLITCHING}
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

var lag_display_diff = 0
var lag_display_countdown = 0
var key_presses = []
var key_timings = []
var dLag = 0.0
var lag = 0.0
var next_lag = 0.0

# const MAX_GLITCH_TIME = 2.0


var band_positions = []
var band_timings = []
var stored_band_time = 0.0
const MAX_BAND_TIME = 2.0

var last_pos;
var glitch_dir;
var glitch_spd;
const CONTINUE_SPEED = 60
const CONTINUE_MAX_SPEED = 500


# Called when the node enters the scene tree for the first time.
func _ready():
	kinematic_body = get_node("KinematicBody2D")
	cur_lag_label = kinematic_body.get_node("CurLag")
	body_start_pos = kinematic_body.get_position()
	update_lag_and_label(LAG_LOW)
	update_next_lag(LAG_LOW)	
	player_pos = body_start_pos
	last_pos = kinematic_body.get_position()
	collision_shape = kinematic_body.get_node("Area2D").get_node("CollisionShape2D")
	rewind_effect = kinematic_body.get_node("RewindEffect")
	continue_effect = kinematic_body.get_node("ContinueEffect")
	rewind_effect.set_visible(false)
	continue_effect.set_visible(false)

func _input(event):
	# TODO use states instead of boolean
	if(event.is_action_pressed("pause")):
		if game_paused:
			game_paused = false
		else:
			game_paused = true

	if(event.is_action_pressed("rubber_band")):
		glitch_state = BANDING
		rewind_effect.set_visible(true)
		continue_effect.set_visible(false)
		deactivate_enemy_collisions()
		reset_key_presses_and_movement()
		return
	elif (event.is_action_released("rubber_band") and glitch_state == BANDING):
		set_state_normal()

	if (event.is_action_pressed("continue_glitch")):
		glitch_state = CONTINUE_GLITCHING
		player_pos = kinematic_body.global_position
		glitch_dir = player_pos.angle_to_point(last_pos)
		glitch_spd = player_pos.distance_to(last_pos)
		deactivate_enemy_collisions()
		continue_effect.set_visible(true)
		rewind_effect.set_visible(false)
		return
	elif (event.is_action_released("continue_glitch") and glitch_state == CONTINUE_GLITCHING):
		set_state_normal()

	if game_paused:
		return

	add_key_event_to_conveyor(event)
	
	# Test purposes
	if event.is_action_pressed("lag_low"):
		update_next_lag(LAG_LOW)

	if event.is_action_pressed("lag_med"):
		update_next_lag(LAG_MED)

	if event.is_action_pressed("lag_high"):
		update_next_lag(LAG_HIGH)


	if event.is_action_pressed("reset_pos"):
		reset_body_and_clear_actions()

func reset_body_and_clear_actions():
	kinematic_body.set_position(body_start_pos)
	reset_key_presses_and_movement()
	band_positions = []
	band_timings = []
	stored_band_time = 0.0

func set_state_normal(): 
	glitch_state = NORMAL
	rewind_effect.set_visible(false)
	continue_effect.set_visible(false)
	reactivate_enemy_collisions()
	
func deactivate_enemy_collisions():
	collision_shape.set_deferred("disabled", true)

func reactivate_enemy_collisions():
	collision_shape.set_deferred("disabled", false)

func reset_key_presses_and_movement():
	key_presses = []
	key_timings = []
	y_velo = 0
	is_right = false
	is_left = false
	is_jump = false

func _physics_process(delta):
	if game_paused:
		return

	last_pos = kinematic_body.get_position()
	if glitch_state == BANDING:
		if band_positions.size() > 0: 
			var time_reversed = 0
			while time_reversed < delta and band_positions.size() > 0:
				var pos = band_positions.pop_back()
				var timing = band_timings.pop_back()
				time_reversed += timing
				kinematic_body.set_position(pos)
				stored_band_time -= delta
			return
		else: 
			set_state_normal()
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

		if glitch_state == CONTINUE_GLITCHING: 
			var pos = kinematic_body.get_position()
			var spd = min(glitch_spd * CONTINUE_SPEED, CONTINUE_MAX_SPEED)
			pos += Vector2(1,0).rotated(glitch_dir) * spd * delta
			kinematic_body.set_position(pos)
			continue_effect.get_node("Sprite").get_texture().get_noise().set_seed(randi()%10+1)
			return

	adjust_lag_display(delta)	
	adjust_lag(delta)
	rotate_key_event_conveyor(delta)

	var move_dir = 0
	if is_right:
		move_dir += 1
	if is_left:
		move_dir -= 1
	kinematic_body.move_and_slide(Vector2(move_dir * MOVE_SPEED, y_velo), Vector2(0, -1))
	
	var grounded = kinematic_body.is_on_floor()
	if grounded:
		coyote_time = COYOTE_TIME + lag
	y_velo += GRAVITY
	if coyote_time > 0 and is_jump:
		y_velo = -JUMP_FORCE
	if grounded and y_velo >= 5:
		y_velo = 5
	if y_velo > MAX_FALL_SPEED:
		y_velo = MAX_FALL_SPEED
	coyote_time -= delta
	player_pos = kinematic_body.global_position
	if player_pos.x < MIN_X or player_pos.x > MAX_X or player_pos.y < MIN_Y or player_pos.y > MAX_Y:
		reset_body_and_clear_actions()

func adjust_lag_display(delta):
	print(lag_display_diff)
	lag_display_countdown -= delta
	if lag_display_countdown > 0:
		return
	lag_display_countdown = randi() % 6 + 1
	lag_display_diff = randi() % 10
	if randi() % 2 == 1:
		lag_display_diff *= -1

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
	var offset = max(20, int(new_lag*1000))
	cur_lag_label.text = String(lag_display_diff + offset) + " ms"

func update_next_lag(new_lag): 
	if new_lag < 0: 
		new_lag = 0
	next_lag = new_lag

func _on_Area2D_area_entered(_body):
	reset_body_and_clear_actions()
