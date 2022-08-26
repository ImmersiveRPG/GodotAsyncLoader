# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Control

const GROUPS := [
	"terrain",
	"structure",
	"furniture",
	"plant",
	"item",
	"npc",
	"etc",
]

func _ready() -> void:
	AsyncLoader._sleep_msec = 100
	AsyncLoader.set_groups(GROUPS)

func _on_StartAsyncButton_pressed() -> void:
	AsyncLoader.change_scene("res://examples/World/World.tscn", "res://examples/Loading/Loading.tscn")

func _on_StartSyncButton_pressed() -> void:
	# Remove the old scene
	var start := OS.get_ticks_msec()
	var tree = self.get_tree()
	var old_scene = tree.current_scene
	tree.root.remove_child(old_scene)
	old_scene.queue_free()
	print("Removing old scene took %sms" % [OS.get_ticks_msec() - start])

	# Load the new scene
	start = OS.get_ticks_msec()
	var scene := ResourceLoader.load("res://examples/World/World.tscn")
	print("Loading scene took %sms" % [OS.get_ticks_msec() - start])

	# Instance the new scene
	start = OS.get_ticks_msec()
	var instance = scene.instance()
	print("Instancing scene took %sms" % [OS.get_ticks_msec() - start])

	# Add the new scene
	start = OS.get_ticks_msec()
	tree.root.add_child(instance)
	print("Adding scene took %sms" % [OS.get_ticks_msec() - start])

	tree.set_current_scene(instance)
