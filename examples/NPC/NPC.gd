# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends KinematicBody

const FLOOR_SLOPE_MAX_THRESHOLD := deg2rad(60)
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
	_velocity = move_and_slide_with_snap(_velocity, _snap_vector, Vector3.UP, true, 4, FLOOR_SLOPE_MAX_THRESHOLD, false)


func _on_TimerChangeDestination_timeout() -> void:
	var r := 300.0
	_destination = Vector3(
		rand_range(-r, r),
		rand_range(0.0, 0.0),
		rand_range(-r, r)
	)
