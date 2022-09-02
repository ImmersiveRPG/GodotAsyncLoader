# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var GROUPS := ["default"]
var CANT_SLEEP_GROUPS := []
var _post_add_sleep_msec := 10
var _thread_sleep_msec := 2
var _is_setup := false

