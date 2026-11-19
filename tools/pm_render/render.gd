extends Node
## Offline renderer for the Paper Mario 64 style stage layers.
## Usage: godot --path tools/pm_render -- spec=<file.json>
## The spec lists a camera, items (models, floor planes, standing cards,
## boxes) each tagged with a layer, and passes; every pass renders only
## its layer to a transparent PNG. See tools/build_pm_stages.py.

var spec: Dictionary
var sh: Shader
var items: Array = []   # [{cfg, mats: [ShaderMaterial]}]


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	spec = JSON.parse_string(FileAccess.get_file_as_string(args["spec"]))
	sh = load("res://n64.gdshader")
	var sz: Array = spec.get("size", [3840, 2160])
	var vp := SubViewport.new()
	vp.size = Vector2i(int(sz[0]), int(sz[1]))
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	env.environment = e
	vp.add_child(env)
	var world := Node3D.new()
	vp.add_child(world)
	for cfg: Dictionary in spec["items"]:
		var mats: Array = []
		var node := _make_item(cfg, mats)
		if node:
			world.add_child(node)
			items.append({"cfg": cfg, "mats": mats})
	var c: Dictionary = spec["camera"]
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.look_at_from_position(_v3(c["pos"]), _v3(c["at"]), Vector3.UP)
	if c.has("ortho"):
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(c["ortho"])
	else:
		cam.fov = float(c.get("fov", 40))
	cam.near = float(c.get("near", 0.01))
	cam.far = float(c.get("far", 5000))
	cam.current = true
	for p: Dictionary in spec["passes"]:
		_set_pass(String(p["name"]))
		for i in 4:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(String(p["out"]))
		print("saved ", p["out"])
	get_tree().quit()


func _set_pass(pass_name: String) -> void:
	for it: Dictionary in items:
		var cfg: Dictionary = it["cfg"]
		var layer: String = cfg.get("layer", "back")
		var split = cfg.get("zsplit", null)
		var shown := layer == pass_name or pass_name == "all"
		var zmin := -1e9
		var zmax := 1e9
		if split != null and pass_name != "all":
			# a model cut in two: everything nearer than split is "front"
			var front_layer: String = cfg.get("front_layer", "front")
			if pass_name == front_layer:
				shown = true
				zmin = float(split)
			elif pass_name == layer:
				zmax = float(split)
		for m: ShaderMaterial in it["mats"]:
			var only: String = m.get_meta("pass_only", "")
			var hidden := only != "" and only != pass_name and pass_name != "all"
			if only == "__never__":
				hidden = true
			m.set_shader_parameter("shown", 1.0 if shown and not hidden else 0.0)
			m.set_shader_parameter("zmin", zmin)
			m.set_shader_parameter("zmax", zmax)


func _make_item(cfg: Dictionary, mats: Array) -> Node3D:
	var t: String = cfg["type"]
	var n: Node3D
	match t:
		"model":
			var res: Resource = load(cfg["path"])
			if res is PackedScene:
				n = res.instantiate()
			else:
				var mi := MeshInstance3D.new()
				mi.mesh = res
				n = mi
			var meshes: Array = []
			_collect(n, meshes)
			for mi: MeshInstance3D in meshes:
				for s in mi.mesh.get_surface_count():
					var old: Material = mi.get_active_material(s)
					var tex: Texture2D = old.albedo_texture if old is BaseMaterial3D else null
					var tname := tex.resource_path.get_file() if tex else "(none)"
					if cfg.has("list"):
						print("SURF ", mi.name, " #", s, " ", tname)
					var m := _mat(tex, cfg)
					var hide: Array = cfg.get("hide_tex", [])
					if hide.has(tname):
						m.set_meta("pass_only", "__never__")
					var retex: Dictionary = cfg.get("retex", {})
					if retex.has(tname):
						var r = retex[tname]
						var rt: Texture2D = load(r) if r is String else load(r["tex"])
						m.set_shader_parameter("tex", rt)
						m.set_shader_parameter("has_tex", true)
						if r is Dictionary and r.has("uv"):
							m.set_shader_parameter("uv_scale", _v2(r["uv"]))
					var tints: Dictionary = cfg.get("tint_tex", {})
					if tints.has(tname):
						m.set_shader_parameter("tint", _col(tints[tname]))
					var novc: Array = cfg.get("novc_tex", [])
					if novc.has(tname):
						m.set_shader_parameter("use_vc", false)
					var only: Dictionary = cfg.get("pass_tex", {})
					if only.has(tname):
						m.set_meta("pass_only", only[tname])
					mi.set_surface_override_material(s, m)
					mats.append(m)
		"plane":
			# horizontal floor, centered
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = _v2(cfg["size"])
			mi.mesh = pm
			var m := _mat(load(cfg["tex"]), cfg)
			mi.material_override = m
			mats.append(m)
			n = mi
		"card":
			# upright cut-out facing the camera (+z), positioned by its bottom centre
			var tex: Texture2D = load(cfg["tex"])
			var h := float(cfg["h"])
			var uvr: Vector2 = _v2(cfg.get("uv", [1, 1]))
			var off := Vector2.ZERO
			if cfg.has("rect"):
				# sub-rectangle of an atlas texture, in 0..1 units
				var r: Array = cfg["rect"]
				off = Vector2(float(r[0]), float(r[1]))
				uvr = Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
			var w := float(cfg.get("w", h * tex.get_width() * uvr.x / (tex.get_height() * uvr.y)))
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(w, h)
			q.center_offset = Vector3(0, h * 0.5, 0)
			mi.mesh = q
			var m := _mat(tex, cfg)
			if cfg.get("flip", false):
				m.set_shader_parameter("uv_scale", uvr * Vector2(-1, 1))
				m.set_shader_parameter("uv_offset", off + Vector2(uvr.x, 0))
			else:
				m.set_shader_parameter("uv_scale", uvr)
				m.set_shader_parameter("uv_offset", off)
			mi.material_override = m
			mats.append(m)
			n = mi
		"sphere":
			var mi := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = float(cfg["r"])
			sp.height = float(cfg["r"]) * 2.0
			mi.mesh = sp
			var m := _mat(load(cfg["tex"]), cfg)
			mi.material_override = m
			mats.append(m)
			n = mi
		"box":
			var mi := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = _v3(cfg["size"])
			mi.mesh = b
			var m := _mat(load(cfg["tex"]), cfg)
			mi.material_override = m
			mats.append(m)
			n = mi
	if n == null:
		return null
	n.position = _v3(cfg.get("pos", [0, 0, 0]))
	n.rotation_degrees = Vector3(float(cfg.get("rot_x", 0)), float(cfg.get("rot", 0)), float(cfg.get("rot_z", 0)))
	var sc = cfg.get("scale", 1.0)
	n.scale = _v3(sc) if sc is Array else Vector3.ONE * float(sc)
	return n


func _mat(tex: Texture2D, cfg: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("clamp_uv", cfg["type"] == "card" and not cfg.has("rect") and not cfg.has("uv"))
	m.set_shader_parameter("has_tex", tex != null)
	m.set_shader_parameter("use_vc", not cfg.get("novc", false))
	m.set_shader_parameter("tint", _col(cfg.get("tint", [1, 1, 1, 1])))
	if cfg.has("uv") and cfg["type"] != "card":
		m.set_shader_parameter("uv_scale", _v2(cfg["uv"]))
	return m


func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _col(a) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
