# Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is license under the MIT License
# https://github.com/ImmersiveRPG/AsyncLoaderExample

extends Control


func _on_start_pressed() -> void:
	SceneSwitcher.change_scene("res://src/World/World.tscn")
