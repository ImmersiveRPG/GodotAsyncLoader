# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _is_running := false
var _to_call_out := []
var _mutex_out := Mutex.new()

func _start_loop() -> void:
	const msec_per_frame := int(1000 / 60) # FIXME: This assumes 60 FPS target
	const budget_threshold := 5  # FIXME: This should be configurable
	var consecutive_no_work_count := 0

	while _is_running:
		var budget_remaining := msec_per_frame
		var is_sleeping := false
		var call_count := 0
		while not is_sleeping:
			var before := Time.get_ticks_msec()

			_mutex_out.lock()
			var callable = _to_call_out.pop_front()
			_mutex_out.unlock()

			if callable:
				#print(callable)
				callable.call()
				call_count += 1
				consecutive_no_work_count = 0

			var after := Time.get_ticks_msec()
			var used := after - before
			budget_remaining -= used
			#print("Used:%s, budget_remaining:%s" % [used, budget_remaining])

			# Sleep if there is no work to do, or the budget is below the threshold
			if callable == null or budget_remaining < budget_threshold:
				is_sleeping = true
				consecutive_no_work_count += 1

		if call_count > 0:
			print("budget_remaining:%s, call_count:%s" % [budget_remaining, call_count])

		# Sleep, and do it longer if we had no work for X consecutive loops
		var sleep_sec := 0.05 if consecutive_no_work_count > 10 else 0.001 
		await get_tree().create_timer(sleep_sec).timeout

func start() -> void:
	_is_running = true

	self.call_deferred("_start_loop")

func stop() -> void:
	_is_running = false

func call_throttled(callable : Callable) -> void:
	_mutex_out.lock()
	_to_call_out.push_back(callable)
	_mutex_out.unlock()
