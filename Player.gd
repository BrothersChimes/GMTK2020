extends Node2D


const MOVE_SPEED = 500
const JUMP_FORCE = 1000
const GRAVITY = 50
const MAX_FALL_SPEED = 1000

var y_velo = 0
var facing_right = false
var coyote_time = 5
var game_paused = false;

var is_right = false

enum {RIGHT_PRESS, RIGHT_RELEASE}
var key_presses = []
var key_timings = []
var lag = 0.2

# Called when the node enters the scene tree for the first time.
func _ready():
	$LagLabel.text = String(lag*1000) + " ms"

func _input(event):
	if(event.is_action_pressed("pause")):
		if game_paused:
			game_paused = false
		else:
			game_paused = true


	if game_paused:
		return

	if event.is_action_pressed("right"):
		key_presses.append(RIGHT_PRESS)
		key_timings.append(lag)

	if event.is_action_released("right"):
		key_presses.append(RIGHT_RELEASE)
		key_timings.append(lag)

func _physics_process(delta):
	if game_paused:
		return
	
	for i in range(0, key_timings.size()): 
		key_timings[i] -= delta
		print("key_timings[i]")
		print(key_timings[i])

	while (key_timings.size() > 0 and key_timings[0] <= 0):
		key_timings.pop_front()
		var press = key_presses.pop_front()
		match (press):
			RIGHT_PRESS:
				is_right = true
			RIGHT_RELEASE:
				is_right = false

	var move_dir = 0
	if is_right:
		move_dir += 1
	if Input.is_action_pressed("left"):
		move_dir -= 1
	var kinematic_body = get_node("KinematicBody2D")
	kinematic_body.move_and_slide(Vector2(move_dir * MOVE_SPEED, y_velo), Vector2(0, -1))
	
	var grounded = kinematic_body.is_on_floor()
	if grounded:
		coyote_time = 20
	y_velo += GRAVITY
#	if coyote_time > 0:
#		print("coyote_time")
	if coyote_time > 0 and Input.is_action_just_pressed("jump"):
		y_velo = -JUMP_FORCE
	if grounded and y_velo >= 5:
		y_velo = 5
	if y_velo > MAX_FALL_SPEED:
		y_velo = MAX_FALL_SPEED
	coyote_time -= delta * 100
#	print(delta)

func update_lag(new_lag): 
	lag = new_lag
	$LagLabel.text = String(new_lag*1000) + " ms"
