# Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is license under the MIT License
# https://github.com/ImmersiveRPG/AsyncLoaderExample

extends Node

const AIR_FRICTION := 10.0
const CAMERA_H_OFFSET := 2.5
const FLOOR_SLOPE_MAX_THRESHOLD := deg2rad(60)
const FLOOR_FRICTION := 60.0
const GRAVITY := -40.0
const GAME_DAY_LENGTH_IN_IRL_SECONDS := (24.0 * 60.0 * 60.0) / 30.0
const GAME_HOUR_LENGTH := GAME_DAY_LENGTH_IN_IRL_SECONDS / 24.0
const GAME_MINUTE_LENGTH := GAME_HOUR_LENGTH / 60.0
const GAME_SECOND_LENGTH := GAME_MINUTE_LENGTH / 60.0
const MOUSE_SENSITIVITY := 0.1
const MOUSE_ACCELERATION_X := 10.0
const MOUSE_ACCELERATION_Y := 10.0
const MOUSE_Y_MAX := 70.0
const MOUSE_Y_MIN := -60.0
const TILE_WIDTH := 300.0
const WORLD_TILES_WIDE := 30
const MAX_WIND_SPEED := 65.0

var _is_logging_loads := false
var _rng : RandomNumberGenerator

func _ready() -> void:
	# Setup random number generator
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

func rand_vector(min_val : float, max_val : float) -> Vector3:
	return Vector3(
		Global._rng.randf_range(min_val, max_val),
		Global._rng.randf_range(min_val, max_val),
		Global._rng.randf_range(min_val, max_val)
	)

func recursively_get_all_children_of_type(target : Node, target_type) -> Array:
	var matches := []
	var to_search := [target]
	while not to_search.empty():
		var entry = to_search.pop_front()

		for child in entry.get_children():
			to_search.append(child)

		if entry is target_type:
			matches.append(entry)

	return matches
