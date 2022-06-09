# AsyncLoaderExample


[![Loading scenes asynchronously in Godot](https://img.youtube.com/vi/GR95TXHz5kg/0.jpg)](https://www.youtube.com/watch?v=GR95TXHz5kg, "Loading scenes asynchronously in Godot")

## How to load a scene async and in chunks

1. Add SceneLoader, SceneAdder, SceneSwitcher as singleton AutoLoad to project

2. Add child scenes to a group
  * terrain
  * building
  * furniture
  * plant
  * item
  * npc
  * etc

3. Load and switch to a scene with SceneSwitcher
  ```GDScript

  # Switch to a new scene and load any children asynchronously
  SceneSwitcher.change_scene("res://src/World/World.tscn")
  ```

## How to load child scene async

```GDScript
# Instance scene asynchronously and add to current scene
var target = get_tree().get_current_scene()
var scene_file := "res://src/Animals/Puma.tscn"
var pos := Vector3(0, 1, 0)
SceneLoader.load_scene_async(target, scene_file, pos, true)
```

## How to load child scene async with callback

```GDScript
# Instance scene asynchronously and send to callback
var target = get_tree().get_current_scene()
var scene_file := "res://src/Animals/Puma.tscn"
var pos := Vector3(0, 1, 0)
SceneLoader.load_scene_async_with_cb(target, scene_file, pos, true, funcref(self, "on_animal_loaded"))

func on_animal_loaded(path : String, instance : Node, pos : Vector3, is_pos_global : bool, data : Dictionary) -> void:
	var target = get_tree().get_current_scene()
	instance.transform.origin = pos
	target.add_child(instance)
```

## How to load child scene sync

```GDScript
# Instance scene synchronously and add to target scene
var scene_file := "res://src/Animals/Puma.tscn"
var target = get_tree().get_current_scene()
var instance := SceneLoader.load_scene_sync(target, scene_file)
```
