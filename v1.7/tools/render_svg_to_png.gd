extends SceneTree

## Small deterministic helper for turning project-authored SVG artwork into a PNG.
## Usage: godot --headless --path <project> --script res://tools/render_svg_to_png.gd -- <source.svg> <output.png>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Provide one SVG source path and one PNG output path.")
		quit(2)
		return
	var source_path := str(args[0])
	var output_path := str(args[1])
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		push_error("Could not load SVG: %s" % source_path)
		quit(3)
		return
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save PNG: %s" % output_path)
		quit(4)
		return
	print("Rendered %s (%dx%d)" % [output_path, image.get_width(), image.get_height()])
	quit()
