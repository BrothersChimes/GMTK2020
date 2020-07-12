extends Node2D

enum Direction {LEFT, RIGHT}
export (Direction) var start_direction
export (float) var walk_speed = 1.0
export (float) var walk_time = 1.0
export (float) var idle_time = 1.0

var is_left = (start_direction == Direction.LEFT)
var animation

var walk_timer = 0
var idle_timer = idle_time

enum {WALK, IDLE}
var move_mode = IDLE

func _ready():
	animation = get_node("AnimatedSprite")
	animation.set_flip_h(is_left)
	animation.set_speed_scale(walk_speed)

func _process(delta):
	if move_mode == WALK:
		if(walk_timer > 0): 
			walk_timer -= delta
			var dir_multi = 1
			if is_left: 
				dir_multi = -1
			set_position(Vector2(get_position().x + dir_multi* delta*50*walk_speed, get_position().y))
		else: 
			move_mode = IDLE
			idle_timer = idle_time
			animation.set_animation("idle")

	if move_mode == IDLE: 
		if idle_timer > 0: 
			idle_timer -= delta
		else: 
			move_mode = WALK
			walk_timer = walk_time
			is_left = not is_left
			animation.set_flip_h(is_left)
			animation.set_animation("run")

