extends Node2D

signal activate_checkpoint(position)

var is_active = false
var torch

func _ready():
	torch = get_node("AnimatedSprite")
	torch.set_visible(false)

func _on_Area2D_area_entered(_body): 
	torch.set_visible(true)
	is_active = true
	emit_signal("activate_checkpoint", get_position())

func _on_activate_checkpoint(_position):
	torch.set_visible(false)
