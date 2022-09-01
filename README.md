# Godot Async Loader


## Video on how plugin works

[![Loading scenes asynchronously in Godot](https://img.youtube.com/vi/PFCWlwdfK_k/0.jpg)](https://youtu.be/PFCWlwdfK_k, "Loading scenes asynchronously in Godot")

## How to install and use plugin

1. Find, download, and install the "Godot Async Loader" plugin in AssetLib

![groups](https://github.com/ImmersiveRPG/GodotAsyncLoader/blob/main/docs/asset_lib.png)

2. Enable the plugin (Project -> Project Settings -> Plugins -> Enable)

![groups](https://github.com/ImmersiveRPG/GodotAsyncLoader/blob/main/docs/plugins.png)

3. Add scenes to groups

![groups](https://github.com/ImmersiveRPG/GodotAsyncLoader/blob/main/docs/groups.png)

4. Setup plugin in main scene
```GDScript
const GROUPS := [
	"tile",
	"structure",
	"furniture",
	"plant",
	"item",
	"npc",
	"etc",
]
const SLEEP_MSEC := 100

func _ready() -> void:
	AsyncLoader.start(GROUPS, SLEEP_MSEC)
```

5. Use the plugin to change to a new scene and load it asynchronously
```GDScript
func _on_start_pressed() -> void:
	AsyncLoader.change_scene("res://examples/World/World.tscn")
```

## API

```GDScript
# The default time the thread will wait after running a callback
const DEFAULT_SLEEP_MSEC := 10

# Initializes the plugin threads and groups. Must be called before plugin can be used.
AsyncLoader.start(groups : Array, sleep_msec := DEFAULT_SLEEP_MSEC) -> void

# Instance the scene asynchronously and add it to the target
AsyncLoader.instance(target : Node, scene_path : String, pos : Vector3, is_pos_global : bool, has_priority := false) -> void

# Instance the scene asynchronously and fire the callback with it
AsyncLoader.instance_with_cb(scene_path : String, cb : FuncRef, data := {}, has_priority := false) -> void

# Instance the scene synchronously and return it
AsyncLoader.instance_sync(scene_path : String) -> Node

# Just like self.get_tree().change_scene, but it loads the scene asynchronously instead of synchronously
AsyncLoader.change_scene(scene_path : String) -> void
```

## AsyncLoader.instance

```GDScript
# Instance scene asynchronously and add to current scene
var target = get_tree().get_current_scene()
var scene_path := "res://examples/Animals/Puma.tscn"
var pos := Vector3(0, 1, 0)
AsyncLoader.instance(target, scene_path, pos, true)
```

## AsyncLoader.instance_with_cb

```GDScript
# Instance scene asynchronously and send to callback
var data := {
	"target" : self.get_tree().get_current_scene(),
	"pos" : Vector3(0, 1, 0),
}
var scene_path := "res://examples/Animals/Puma.tscn"
var cb := funcref(self, "on_animal_loaded")
AsyncLoader.instance_with_cb(scene_path, cb, data, true)

func on_animal_loaded(instance : Node, data : Dictionary) -> void:
	var target = data["target"]
	target.add_child(instance)
	instance.transform.origin = data["pos"]


```

## AsyncLoader.instance_sync

```GDScript
# Instance scene synchronously and add to target scene
var scene_path := "res://examples/Animals/Puma.tscn"
var target = get_tree().get_current_scene()
var instance := AsyncLoader.instance_sync(scene_path)
target.add_child(instance)
```
