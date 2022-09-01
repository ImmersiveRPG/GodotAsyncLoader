# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Spatial

const GROUPS := [
	#"terrain",
	#"structure",
	"furniture",
	"plant",
	"item",
	"npc",
	"etc",
]

var _prev_player_center_tile := Vector3.INF
var _tile_load_status := []
var _is_first_terrain := true

onready var _terrain = $Terrain

func _init() -> void:
	# Init a table to keep track of what terrain tiles are loaded
	for _z in range(-Global.WORLD_TILES_WIDE, Global.WORLD_TILES_WIDE):
		var row := []
		for _x in range(-Global.WORLD_TILES_WIDE, Global.WORLD_TILES_WIDE):
			row.append(0)
		_tile_load_status.append(row)

func _on_load_checker_timer_timeout() -> void:
	self.load_terrain_around_player()

func position_to_tile_xz(org : Vector3) -> Vector3:
	var half := Global.TILE_WIDTH / 2.0
	var x := round((org.x / half) / 2.0)
	var z := round((org.z / half) / 2.0)

	return Vector3(x, 0, z)

func load_terrain_around_player() -> void:
	# Load around player
	if Global._player:
		var org = Global._player.transform.origin
		var center_tile := position_to_tile_xz(org) - Global._world_offset
		if center_tile != _prev_player_center_tile:
			_prev_player_center_tile = center_tile
			load_terrain_around(center_tile)
			self._sleep_and_wake_nodes(center_tile)

	# Let the player move if the tiles under the player are loaded
	if not Global._is_ready_for_movement and _prev_player_center_tile != Vector3.INF:
		var is_player_terrain_loaded : bool = _tile_load_status[_prev_player_center_tile.z][_prev_player_center_tile.x] == 2
		if is_player_terrain_loaded:
			Global._is_ready_for_movement = true

func load_terrain_around(center_tile : Vector3) -> void:
	#print("??? org: %s" % org)
	var to_load := [
		center_tile, # Center
		center_tile + Vector3(-1.0, 0.0, 0.0), # Right
		center_tile + Vector3(1.0, 0.0, 0.0), # Left
#		center_tile + Vector3(0.0, 0.0, 1.0), # Up
#		center_tile + Vector3(0.0, 0.0, -1.0), # Down
#		center_tile + Vector3(-1.0, 0.0, 1.0), # Up Right
#		center_tile + Vector3(1.0, 0.0, 1.0), # Up Left
#		center_tile + Vector3(-1.0, 0.0, -1.0), # Down Right
#		center_tile + Vector3(1.0, 0.0, -1.0), # Down Left
#
#		center_tile + Vector3(0.0, 0.0, 2.0),
#		center_tile + Vector3(-1.0, 0.0, 2.0),
#		center_tile + Vector3(1.0, 0.0, 2.0),
#
#		center_tile + Vector3(0.0, 0.0, -2.0),
#		center_tile + Vector3(-1.0, 0.0, -2.0),
#		center_tile + Vector3(1.0, 0.0, -2.0),
#
#		center_tile + Vector3(2.0, 0.0, 1.0),
#		center_tile + Vector3(2.0, 0.0, 0.0),
#		center_tile + Vector3(2.0, 0.0, -1.0),
#
#		center_tile + Vector3(-2.0, 0.0, 1.0),
#		center_tile + Vector3(-2.0, 0.0, 0.0),
#		center_tile + Vector3(-2.0, 0.0, -1.0),
	]

	# Tell Scene loader to load terrains
	for entry in to_load:
		# Skip tiles that are outside the world
		if entry.x <= -Global.WORLD_TILES_WIDE or entry.x >= Global.WORLD_TILES_WIDE:
			continue
		if entry.z <= -Global.WORLD_TILES_WIDE or entry.z >= Global.WORLD_TILES_WIDE:
			continue

		# Skip tiles that are already loaded or started loading
		if _tile_load_status[entry.z][entry.x] > 0:
			continue

		# Instance scene asynchronously and send to callback
		var data := {
			"target" : _terrain,
			"pos" : Vector3(entry.x, 0.0, entry.z),
			"is_first" : _is_first_terrain,
		}

		# Mark that this terrain tile is starting to load
		_tile_load_status[entry.z][entry.x] = 1

		var scene_path := "res://examples/Terrain/Terrain_%+03d_%+03d.tscn" % [entry.x, entry.z]
		#print(scene_path)
		var cb := funcref(self, "_on_terrain_loaded")
		#print([cb])
		AsyncLoader.instance_with_cb(scene_path, cb, data, false)
		_is_first_terrain = false

func _on_terrain_loaded(instance : Node, data : Dictionary) -> void:
	#print([instance])
	# Add the tile
	var target = data["target"]
	var pos = data["pos"]
	target.add_child(instance)
	var offset = (Global._world_offset * Global.TILE_WIDTH)
	instance.global_transform.origin = offset + Vector3(pos.x * Global.TILE_WIDTH, pos.y, pos.z * Global.TILE_WIDTH)

	# Mark that the terrain as loaded
	_tile_load_status[pos.z][pos.x] = 2

func _sleep_and_wake_nodes(center_tile : Vector3) -> void:
	var terrain_name := "Terrain_%+03d_%+03d" % [center_tile.x, center_tile.z]
	var next_player_terrain = _terrain.get_node_or_null(terrain_name)
	#print([terrain_name, next_player_terrain])
	if next_player_terrain == null:
		return

	if Global._player_terrain:
		if not Global._sleeping_nodes.has(Global._player_terrain.name):
			Global._sleeping_nodes[Global._player_terrain.name] = []

	if next_player_terrain:
		if not Global._sleeping_nodes.has(next_player_terrain.name):
			Global._sleeping_nodes[next_player_terrain.name] = []

	# Wake up the on screen nodes
	var inverse_entries = Global._sleeping_nodes[next_player_terrain.name]
	inverse_entries.invert()
	for entry in inverse_entries:
		var node_parent = entry["node_parent"]
		var node = entry["node"]
		#print("!!! Waking: %s" % [node.name])
		node_parent.add_child(node)
		#BlockingActionThrottler.call_on_main_thread_when_idle(node_parent, "add_child", [node], false)
	Global._sleeping_nodes[next_player_terrain.name].clear()

	# Put all the off screen nodes to sleep
	var inverse_groups = GROUPS.duplicate()
	inverse_groups.invert()
	if Global._player_terrain:
		for group in inverse_groups:
			var group_nodes = Global.recursively_get_all_children_in_group(Global._player_terrain, group)
			group_nodes.invert()
			for node in group_nodes:
				#print("!!! Sleeping: %s" % [node.name])
				var node_parent = node.get_parent()
				node_parent.remove_child(node)
				#BlockingActionThrottler.call_on_main_thread_when_idle(node_parent, "remove_child", [node], false)
				Global._sleeping_nodes[Global._player_terrain.name].append({
					"node_parent" : node_parent,
					"node" : node
				})

	Global._player_terrain = next_player_terrain
	#print("!! Player(%s) is on Terrain (%s)" % [body.name, next_player_terrain.name])
