# Copyright (c) 2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotCallThrottled

extends Node



func _process(_delta : float) -> void:
	GodotCallThrottled._main_iteration_done()
	
