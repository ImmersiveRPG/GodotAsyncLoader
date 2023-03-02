# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader


extends Node3D


func _on_change_scene_pressed() -> void:
	AsyncLoader.change_scene("res://examples/World/World.tscn", "res://examples/Loading/Loading.tscn")