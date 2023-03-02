# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends CharacterBody3D

const FLOOR_SLOPE_MAX_THRESHOLD := deg_to_rad(60)
const HP_MAX := 100.0
const JUMP_IMPULSE := 20.0
const ROTATION_SPEED := 6.0
const ACCELERATION := 70.0
const MAX_VELOCITY := 60.0

var _velocity := Vector3.ZERO
var _snap_vector := Vector3.ZERO
var _destination := Vector3.INF

func _ready() -> void:
	_on_TimerChangeDestination_timeout()

func _physics_process(delta : float) -> void:
	# Get the input vector based on the destination
	var input_vector := Vector3.ZERO
	if _destination != Vector3.INF:
		input_vector = (_destination - self.global_transform.origin).normalized()

	var is_moving := input_vector != Vector3.ZERO

	self.rotation.y = lerp_angle(self.rotation.y, atan2(-input_vector.x, -input_vector.z), ROTATION_SPEED * delta)

	# Velocity
	var max_velocity := MAX_VELOCITY

	# Acceleration
	if is_moving:
		_velocity = input_vector * max_velocity * ACCELERATION * delta
	else:
		_velocity.x = 0.0
		_velocity.z = 0.0

	# Gravity
	_velocity.y = clamp(_velocity.y + Global.GRAVITY * delta, Global.GRAVITY, JUMP_IMPULSE)

	# Snap to floor plane if close enough
	_snap_vector = -get_floor_normal() if is_on_floor() else Vector3.DOWN

	# Actually move
	set_velocity(_velocity)
	# TODOConverter40 looks that snap in Godot 4.0 is float, not vector like in Godot 3 - previous value `_snap_vector`
	set_up_direction(Vector3.UP)
	set_floor_stop_on_slope_enabled(true)
	set_max_slides(4)
	set_floor_max_angle(FLOOR_SLOPE_MAX_THRESHOLD)
	# TODOConverter40 infinite_inertia were removed in Godot 4.0 - previous value `false`
	move_and_slide()
	_velocity = velocity


func _on_TimerChangeDestination_timeout() -> void:
	var r := 300.0
	_destination = Vector3(
		randf_range(-r, r),
		randf_range(0.0, 0.0),
		randf_range(-r, r)
	)
