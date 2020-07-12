extends Node2D

const MOVE_SPEED = 100
const JUMP_FORCE = 300
const GRAVITY = 10
const MAX_FALL_SPEED = 300
const COYOTE_TIME = 0.2
const MAX_X = 10000
const MAX_Y = 1500
const MIN_X = 0
const MIN_Y = 0
const LAG_LOW = 0
const LAG_MED = 0.18
const LAG_HIGH = 0.55
const START_LIVES = 3

var y_velo = 0
var facing_right = false
var coyote_time = COYOTE_TIME
var kinematic_body
var animated_sprite
var cur_lag_label
var body_start_pos
var player_pos
var collision_shape
var rewind_effect
var noclip_effect
var num_lives = START_LIVES
var lives_label
var lives_node
var life_display_arr = []

var is_right = false
var is_left = false
var is_jump = false

# TODO use states so that the player doesn't move whilst in another state
# enum {PAUSED, NORMAL, REWIND}.
var game_paused = false
var glitch_state = NORMAL

enum {NORMAL, REWIND, NOCLIP}
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

var rewind_positions = []
var rewind_timings = []
var stored_rewind_time = 0.0
const MAX_REWIND_TIME = 2.0

const MAX_NOCLIP_TIME_LOW = 1.0
const MAX_NOCLIP_TIME_MED = 3.0
const MAX_NOCLIP_TIME_HIGH = 6.0
var max_noclip_time = MAX_NOCLIP_TIME_LOW
var last_pos
var noclip_dir
var noclip_spd
var noclip_bar_sprite
var noclip_bar_sprite_original_scale
var noclip_time = 0.0
const NOCLIP_SPEED = 60
const NOCLIP_MAX_SPEED = 400


# Called when the node enters the scene tree for the first time.
func _ready():
	kinematic_body = get_node("KinematicBody2D")
	animated_sprite = kinematic_body.get_node("AnimatedSprite")
	cur_lag_label = kinematic_body.get_node("CurLag")
	body_start_pos = kinematic_body.get_position()
	update_lag_and_label(LAG_LOW)
	update_next_lag(LAG_LOW)	
	player_pos = body_start_pos
	last_pos = kinematic_body.get_position()
	collision_shape = kinematic_body.get_node("Area2D").get_node("CollisionShape2D")
	rewind_effect = kinematic_body.get_node("RewindEffect")
	noclip_effect = kinematic_body.get_node("ContinueEffect")
	rewind_effect.set_visible(false)
	noclip_effect.set_visible(false)
	lives_label = kinematic_body.get_node("LivesLabel")
	lives_node = kinematic_body.get_node("LivesNode")
	display_lives()
	noclip_bar_sprite = kinematic_body.get_node("NoclipBar").get_node("Sprite")
	noclip_bar_sprite_original_scale = noclip_bar_sprite.scale.x

func _input(event):
	# TODO use states instead of boolean
	if(event.is_action_pressed("pause")):
		if game_paused:
			game_paused = false
		else:
			game_paused = true

	if(event.is_action_pressed("rubber_band")):
		glitch_state = REWIND
		rewind_effect.set_visible(true)
		noclip_effect.set_visible(false)
		deactivate_enemy_collisions()
		reset_key_presses_and_movement()
		return
	elif (event.is_action_released("rubber_band") and glitch_state == REWIND):
		set_state_normal()

	if (event.is_action_pressed("continue_glitch")):
		glitch_state = NOCLIP
		player_pos = kinematic_body.global_position
		noclip_dir = player_pos.angle_to_point(last_pos)
		noclip_spd = player_pos.distance_to(last_pos)
		deactivate_enemy_collisions()
		noclip_effect.set_visible(true)
		rewind_effect.set_visible(false)
		return
	elif (event.is_action_released("continue_glitch") and glitch_state == NOCLIP):
		set_state_normal()

	if game_paused:
		return

	add_key_event_to_conveyor(event)
	
	# Test purposes
	if event.is_action_pressed("lag_low"):
		update_next_lag(LAG_LOW)
		max_noclip_time = MAX_NOCLIP_TIME_LOW

	if event.is_action_pressed("lag_med"):
		update_next_lag(LAG_MED)
		max_noclip_time = MAX_NOCLIP_TIME_MED

	if event.is_action_pressed("lag_high"):
		update_next_lag(LAG_HIGH)
		max_noclip_time = MAX_NOCLIP_TIME_HIGH


	if event.is_action_pressed("reset_pos"):
		reset_body_and_clear_actions()

func reset_body_and_clear_actions():
	kinematic_body.set_position(body_start_pos)
	reset_key_presses_and_movement()
	rewind_positions = []
	rewind_timings = []
	stored_rewind_time = 0.0

func set_state_normal(): 
	glitch_state = NORMAL
	rewind_effect.set_visible(false)
	noclip_effect.set_visible(false)
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

func player_loses():
	get_tree().change_scene("res://Lose.tscn")

func player_wins():
	get_tree().change_scene("res://Win.tscn")

func player_dies():
	num_lives -= 1
	if num_lives < 0:
		player_loses()
	reset_body_and_clear_actions()
	display_lives()

func display_lives():
	var offset = 0
	lives_label.text = "Lives: " + String(num_lives) + "x"
	var lifescene = preload("res://LifeDisplay.tscn")
	for life in life_display_arr:
		life.queue_free()
	life_display_arr.clear()
	for i in num_lives:
		var life_display = lifescene.instance()
		life_display_arr.push_back(life_display) 
		lives_node.call_deferred("add_child", life_display)
		life_display.position.x += offset
		offset += 25

func _process(delta):
	noclip_bar_sprite.scale.x = noclip_bar_sprite_original_scale * (noclip_time / MAX_NOCLIP_TIME_HIGH)

	# animation
	var grounded = kinematic_body.is_on_floor()
	animated_sprite.set_flip_h(not is_right)

	if glitch_state == NOCLIP:
		animated_sprite.play("crouch") 
	else:
		if glitch_state == REWIND:
			# play opposite of the direction we're going
			var cur_x = kinematic_body.get_position().x
			animated_sprite.set_flip_h(last_pos.x <= cur_x)
		if not grounded: 
			animated_sprite.play("jumping") 
		else:
			if is_right or is_left:
				animated_sprite.play("run") 
			else:
				animated_sprite.play("idle")
		
		

func _physics_process(delta):
	if game_paused:
		return

	last_pos = kinematic_body.get_position()
	
	if glitch_state == REWIND:
		if rewind_positions.size() > 0: 
			var time_reversed = 0
			while time_reversed < delta and rewind_positions.size() > 0:
				var pos = rewind_positions.pop_back()
				var timing = rewind_timings.pop_back()
				time_reversed += timing
				kinematic_body.set_position(pos)
				stored_rewind_time -= delta
			return
		else: 
			set_state_normal()
	else: 
		if stored_rewind_time < MAX_REWIND_TIME:
			rewind_positions.append(kinematic_body.get_position())
			rewind_timings.append(delta)
			stored_rewind_time += delta
		else: 
			rewind_positions.append(kinematic_body.get_position())
			rewind_timings.append(delta)		
			rewind_positions.pop_front()
			rewind_timings.pop_front()

		if glitch_state == NOCLIP: 
			if noclip_time > 0:
				var pos = kinematic_body.get_position()
				var spd = min(noclip_spd * NOCLIP_SPEED, NOCLIP_MAX_SPEED)
				pos += Vector2(1,0).rotated(noclip_dir) * spd * delta
				kinematic_body.set_position(pos)
				noclip_time -= delta
				return
			else:
				set_state_normal()

	
	if noclip_time < max_noclip_time: 
		noclip_time += delta
	if noclip_time > max_noclip_time:
		noclip_time = max_noclip_time
		
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
		player_dies()

func adjust_lag_display(delta):
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
	if new_lag == LAG_LOW:
		cur_lag_label.add_color_override("font_color", Color(0,1,0,1))
	if new_lag == LAG_MED:
		cur_lag_label.add_color_override("font_color", Color(1,1,0,1))
	if new_lag == LAG_HIGH:
		cur_lag_label.add_color_override("font_color", Color(1,0,0,1))

func update_next_lag(new_lag): 
	if new_lag < 0: 
		new_lag = 0
	next_lag = new_lag

func _on_Area2D_area_entered(_body):
	var collision_layer = _body.get_collision_layer()
	if collision_layer == 1:
		player_dies()
	elif collision_layer == 2:
		player_wins()
