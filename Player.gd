extends Node2D


const MOVE_SPEED = 500
const JUMP_FORCE = 1000
const GRAVITY = 50
const MAX_FALL_SPEED = 1000

var y_velo = 0
var facing_right = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _physics_process(delta):
	var move_dir = 0
	if Input.is_action_pressed("right"):
		move_dir += 1
	if Input.is_action_pressed("left"):
		move_dir -= 1
	var kinematic_body = get_node("KinematicBody2D")
	kinematic_body.move_and_slide(Vector2(move_dir * MOVE_SPEED, y_velo), Vector2(0, -1))
	
	var grounded = kinematic_body.is_on_floor()
	y_velo += GRAVITY
	if grounded and Input.is_action_just_pressed("jump"):
		y_velo = -JUMP_FORCE
	if grounded and y_velo >= 5:
		y_velo = 5
	if y_velo > MAX_FALL_SPEED:
		y_velo = MAX_FALL_SPEED
