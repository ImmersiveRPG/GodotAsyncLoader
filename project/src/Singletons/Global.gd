# Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is license under the MIT License
# https://github.com/ImmersiveRPG/AsyncLoaderExample

extends Node



const FLOOR_SLOPE_MAX_THRESHOLD := deg2rad(60)
const GRAVITY := -40.0

var _is_logging_loads := false
var _rng : RandomNumberGenerator

func _ready() -> void:
	# Setup random number generator
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

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
