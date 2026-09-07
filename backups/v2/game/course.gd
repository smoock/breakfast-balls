extends Node3D

const Data = preload("res://game/data.gd")
var hole_index: int = 0
var length_m: float = 400.0
var bend: float = 0.0
var rise: float = 0.0
var pin: Vector3
var tee: Vector3
var ponds: Array = []
var bunkers: Array = []
var trees: Array = []
var rng := RandomNumberGenerator.new()
var terrain_mesh: MeshInstance3D

func center_x(z: float) -> float:
	return bend * sin(clampf(-z / length_m, 0.0, 1.0) * PI * 0.82)

func height_at(x: float, z: float) -> float:
	var t: float = clampf(-z / length_m, 0.0, 1.0)
	var base: float = rise * smoothstep(0.0, 1.0, t)
	var green_z: float = -length_m
	var dist: float = Vector2(x - center_x(green_z), z - green_z).length()
	var hills: float = sin(z * 0.026 + hole_index) * 2.1 + sin(x * 0.041 + z * 0.018) * 1.4
	var slope: float = (x - center_x(green_z)) * 0.026 + (z - green_z) * 0.018
	return base + lerpf(slope, hills, smoothstep(24.0, 46.0, dist))

func ground_point(x: float, z: float, offset: float = 0.0) -> Vector3:
	return Vector3(x, height_at(x, z) + offset, z)

func in_ellipse(p: Vector3, e: Vector4) -> bool:
	return pow((p.x - e.x) / e.z, 2.0) + pow((p.z - e.y) / e.w, 2.0) < 1.0

func lie_at(p: Vector3) -> String:
	if absf(p.x) > 155.0 or p.z > 45.0 or p.z < -length_m - 65.0: return "OUT OF BOUNDS"
	for e in ponds:
		if in_ellipse(p, e): return "WATER"
	for e in bunkers:
		if in_ellipse(p, e): return "BUNKER"
	if Vector2(p.x - pin.x, p.z - pin.z).length() < 16.0: return "GREEN"
	if Vector2(p.x, p.z).length() < 9.0: return "TEE"
	if p.z < -15.0 and p.z > -length_m and absf(p.x - center_x(p.z)) < fairway_width(p.z): return "FAIRWAY"
	return "ROUGH"

func fairway_width(z: float) -> float:
	return 22.0 + 5.5 * sin(-z * 0.029) + (3.0 if Data.HOLES[hole_index][1] == 5 else 0.0)

func material(color: Color, roughness: float = 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func mesh_node(mesh: Mesh, mat: Material, pos: Vector3, parent: Node = self) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

func cylinder(pos: Vector3, radius: float, h: float, color: Color, top: float = -1.0, parent: Node = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = h
	mesh.radial_segments = 16
	return mesh_node(mesh, material(color), pos, parent)

func sphere(pos: Vector3, radius: float, color: Color, parent: Node = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 20
	mesh.rings = 12
	return mesh_node(mesh, material(color), pos, parent)

func build(index: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	hole_index = index
	rng.seed = 87021 + index * 341
	var spec: Array = Data.HOLES[index]
	length_m = spec[2] * 0.9144
	bend = spec[3]
	rise = spec[4]
	tee = ground_point(0, 0, 0.15)
	pin = ground_point(center_x(-length_m), -length_m, 0.1)
	ponds.clear()
	bunkers.clear()
	trees.clear()
	if spec[5] == 1:
		ponds.append(Vector4(center_x(-length_m * 0.55) + 52, -length_m * 0.55, 27, 44))
	if spec[5] == 2:
		ponds.append(Vector4(pin.x - 29, pin.z + 5, 25, 40))
	if spec[5] == 3:
		ponds.append(Vector4(pin.x, pin.z + 29, 47, 10))
	bunkers.append(Vector4(pin.x - 20, pin.z + 9, 8.5, 13))
	bunkers.append(Vector4(pin.x + 19, pin.z - 5, 9, 12))
	if spec[1] > 3:
		bunkers.append(Vector4(center_x(-210) + 22, -210, 10, 17))
	var backdrop:=PlaneMesh.new(); backdrop.size=Vector2(4000,4000)
	mesh_node(backdrop,material(Color("547449")),Vector3(0,-24,-length_m*0.5))
	_build_ground()
	for e in ponds: _patch(e, Color("4b9390"), 0.15)
	for e in bunkers:
		_patch(Vector4(e.x,e.y,e.z+1.8,e.w+1.8), Color("b3b27c"), 0.11)
		_patch(e, Color("eedbab"), 0.15)
	_patch(Vector4(pin.x,pin.z,19.0,19.0), Color("537e43"), 0.12)
	_patch(Vector4(pin.x,pin.z,16.0,16.0), Color("739650"), 0.16)
	# Subtle green mowing stripes; their geometry follows the playable slope.
	for j in range(-6,7):
		var x: float = pin.x + j * 2.2
		var half: float = sqrt(maxf(0.0, 15.0*15.0 - pow(x-pin.x,2)))
		_strip(x, pin.z-half, pin.z+half, 1.1, Color("799c55"))
	_patch(Vector4(0,0,8,5), Color("86ac5d"), 0.18)
	for side in [-1,1]:
		sphere(ground_point(side*5,0,0.20),0.18,Color("f4de97"))
	# A pin you can see from the fairway.
	cylinder(pin + Vector3(0,2.2,0),0.055,4.4,Color("fff0be"))
	var flagmesh := BoxMesh.new()
	flagmesh.size = Vector3(1.6,0.88,0.035)
	mesh_node(flagmesh,material(Color("e3b951")),pin+Vector3(0.78,3.85,0))
	cylinder(pin+Vector3(0,0.08,0),0.24,0.045,Color("153e2e"))
	# Dense-looking groves, batched into MultiMeshes for modest draw-call cost.
	_build_trees()
	_build_flowers()
	_build_clubhouse()
	_build_landscape()
	_build_details()

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float = 5.0
	for zi in range(int((length_m+160)/step)):
		var z: float = 65.0 - zi*step
		for xi in range(70):
			var x: float = -175.0 + xi*step
			for offset in [Vector2(0,0),Vector2(step,0),Vector2(0,-step),Vector2(step,0),Vector2(step,-step),Vector2(0,-step)]:
				var p := ground_point(x+offset.x,z+offset.y)
				var fair: bool = p.z < -10 and p.z > -length_m and absf(p.x-center_x(p.z)) < fairway_width(p.z)
				var col := Color("315b36")
				if fair: col = Color("659647") if int((-p.z+p.x*0.35)/10.0)%2 == 0 else Color("59863d")
				else: col = col.lightened(0.035*sin(p.z*0.08+p.x*0.12))
				st.set_color(col)
				st.add_vertex(p)
	st.generate_normals()
	var m := ShaderMaterial.new()
	m.shader=preload("res://game/turf.gdshader")
	terrain_mesh = mesh_node(st.commit(),m,Vector3.ZERO)

func _patch(e: Vector4, color: Color, offset: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(64):
		var a: float = TAU*i/64.0
		var b: float = TAU*(i+1)/64.0
		for p in [Vector2(e.x,e.y),Vector2(e.x+cos(b)*e.z,e.y+sin(b)*e.w),Vector2(e.x+cos(a)*e.z,e.y+sin(a)*e.w)]:
			st.add_vertex(ground_point(p.x,p.y,offset))
	st.generate_normals()
	var mat: Material=material(color)
	if color.g>color.r:
		var turf:=ShaderMaterial.new(); turf.shader=preload("res://game/turf.gdshader")
		turf.set_shader_parameter("use_vertex_color",false); turf.set_shader_parameter("turf_color",color.darkened(0.12)); mat=turf
	mesh_node(st.commit(),mat,Vector3.ZERO)

func _strip(x: float,z1: float,z2: float,width: float,col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector2(x,z1),Vector2(x,z2),Vector2(x+width,z1),Vector2(x+width,z1),Vector2(x,z2),Vector2(x+width,z2)]:
		st.add_vertex(ground_point(p.x,p.y,0.18))
	st.generate_normals()
	var turf:=ShaderMaterial.new(); turf.shader=preload("res://game/turf.gdshader")
	turf.set_shader_parameter("use_vertex_color",false); turf.set_shader_parameter("turf_color",col.darkened(0.12))
	mesh_node(st.commit(),turf,Vector3.ZERO)

func _instances(mesh: Mesh, transforms: Array, color: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material(color)
	add_child(node)

func _build_trees() -> void:
	var trunks: Array = []
	var foliage: Array = [[],[],[],[]]
	var branches: Array = []
	for i in range(350):
		var z: float = rng.randf_range(-length_m-65,48)
		var x: float = center_x(z) + (1 if i%2 else -1)*rng.randf_range(39,155)
		var p := ground_point(x,z)
		if lie_at(p) == "WATER" or Vector2(x-pin.x,z-pin.z).length()<32: continue
		var h: float = rng.randf_range(14,27)
		trees.append(Vector3(x,p.y+h*0.5,z))
		trunks.append(Transform3D(Basis().scaled(Vector3(0.7,h,0.7)),p+Vector3(0,h*0.5,0)))
		# Branching pines and broadleaf crowns replace the old two-cone trees.
		var pine: bool=i%3!=0
		for j in range(18):
			var a: float=j*2.399+rng.randf_range(-0.3,0.3)
			var tier: float=float(j)/18.0
			var reach: float=(1.0-tier*0.65)*h*(0.23 if pine else 0.30)
			var tip: Vector3=p+Vector3(cos(a)*reach,h*(0.48+tier*0.50),sin(a)*reach)
			var start: Vector3=p+Vector3(0,h*(0.45+tier*0.48),0)
			var axis: Vector3=(tip-start).normalized()
			var basis:=Basis(Vector3.UP.cross(axis).normalized(),axis,Vector3.ZERO)
			basis.z=basis.x.cross(basis.y).normalized()
			branches.append(Transform3D(basis.scaled_local(Vector3(0.18,tip.distance_to(start),0.18)),(tip+start)*0.5))
			var size: float=rng.randf_range(1.7,2.8)*(1.0-tier*0.45)
			foliage[(i+j)%4].append(Transform3D(Basis().rotated(Vector3.UP,a).scaled(Vector3(size*1.65,size*(0.65 if pine else 1.25),size)),tip))
	var trunk := CylinderMesh.new()
	trunk.height=1; trunk.top_radius=0.28; trunk.bottom_radius=0.5; trunk.radial_segments=8
	var crown := SphereMesh.new()
	crown.radius=1; crown.height=2; crown.radial_segments=8; crown.rings=4
	_instances(trunk,trunks,Color("665745"))
	_instances(trunk,branches,Color("665745"))
	for i in range(4): _instances(crown,foliage[i],[Color("204e3b"),Color("315f3c"),Color("477342"),Color("557d46")][i])

func _build_landscape() -> void:
	# Distant overlapping ridgelines frame the hole without changing playable ground.
	for layer in range(3):
		var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var radius: float=650+layer*260
		for i in range(96):
			var a: float=TAU*i/96.0; var b: float=TAU*(i+1)/96.0
			var ha: float=60+35*sin(a*5+layer)+28*sin(a*9+layer*2)
			var hb: float=60+35*sin(b*5+layer)+28*sin(b*9+layer*2)
			var p:=Vector3(cos(a)*radius,ha,-length_m*0.5+sin(a)*radius)
			var q:=Vector3(cos(b)*radius,hb,-length_m*0.5+sin(b)*radius)
			for v in [Vector3(p.x,-26,p.z),p,q,Vector3(p.x,-26,p.z),q,Vector3(q.x,-26,q.z)]: st.add_vertex(v)
		st.generate_normals()
		mesh_node(st.commit(),material([Color("538d80"),Color("79a69b"),Color("a4c3b4")][layer]),Vector3.ZERO)
	# Soft, cream cloud banks borrow the illustrated reference's silhouettes.
	var cloud:=SphereMesh.new(); cloud.radius=1; cloud.height=2; cloud.radial_segments=16; cloud.rings=8
	var clouds: Array=[]
	for i in range(48):
		var a: float=rng.randf_range(0,TAU)
		clouds.append(Transform3D(Basis().scaled(Vector3(rng.randf_range(40,95),rng.randf_range(12,24),35)),Vector3(cos(a)*850,rng.randf_range(180,235),sin(a)*850-length_m*0.5)))
	_instances(cloud,clouds,Color("fff5d7"))

func _build_details() -> void:
	var shrubs: Array=[]
	var grasses: Array=[]
	for i in range(2600):
		var z: float=rng.randf_range(-length_m-40,30)
		var x: float=center_x(z)+(1 if i%2 else -1)*rng.randf_range(29,65)
		var p:=ground_point(x,z)
		if lie_at(p)!="ROUGH" or p.distance_to(pin)<21: continue
		if i%15==0 and absf(x-center_x(z))>45:
			for j in range(4):
				shrubs.append(Transform3D(Basis().scaled(Vector3(0.9,0.6,0.8)),p+Vector3(cos(j*2.4)*0.8,0.45,sin(j*2.4)*0.8)))
		else:
			grasses.append(Transform3D(Basis().rotated(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(0.18,rng.randf_range(0.15,0.5),0.18)),p))
	var shrub:=SphereMesh.new(); shrub.radius=1; shrub.height=2; shrub.radial_segments=10; shrub.rings=5
	_instances(shrub,shrubs,Color("3f6842"))
	var blade:=CylinderMesh.new(); blade.top_radius=0; blade.bottom_radius=0.5; blade.height=1; blade.radial_segments=3
	_instances(blade,grasses,Color("859655"))
	# Course furniture: a tee sign, ball washer, and a bench.
	var sign:=BoxMesh.new(); sign.size=Vector3(1.4,0.9,0.12)
	mesh_node(sign,material(Color("173d33")),ground_point(-8,2,1.25))
	cylinder(ground_point(-8,2,0.6),0.06,1.2,Color("d3b582"))
	var label:=Label3D.new(); label.text="%02d  /  PAR %d"%[hole_index+1,Data.HOLES[hole_index][1]]; label.font_size=48; label.pixel_size=0.0035; label.position=ground_point(-8,2.08,1.25); label.modulate=Color("f5dfaa"); add_child(label)
	cylinder(ground_point(8,3,0.6),0.06,1.2,Color("344d43"))
	sphere(ground_point(8,3,1.3),0.22,Color("dfc47f"))
	for y in [0.5,1.0]:
		var plank:=BoxMesh.new(); plank.size=Vector3(2.5,0.15,0.5)
		mesh_node(plank,material(Color("a18a60")),ground_point(-11,5,y))
	for x in [-12,-10]: cylinder(ground_point(x,5,0.25),0.07,0.5,Color("354f43"))

func _build_flowers() -> void:
	var groups: Array = [[],[],[]]
	var leaves: Array=[]
	for i in range(190):
		# Natural azalea beds behind and beside the green, leaving its approach clear.
		var a: float = rng.randf_range(PI*0.92,TAU*1.04)
		var r: float = rng.randf_range(28,43)
		var p := ground_point(pin.x+cos(a)*r,pin.z+sin(a)*r,0.6)
		if lie_at(p)=="WATER": continue
		leaves.append(Transform3D(Basis().scaled(Vector3(1.1,0.7,1.1)),p))
		for j in range(12):
			var a2: float=rng.randf_range(0,TAU)
			var blossom: Vector3=p+Vector3(cos(a2)*rng.randf_range(0.3,0.95),rng.randf_range(0.1,0.65),sin(a2)*rng.randf_range(0.3,0.95))
			groups[i%3].append(Transform3D(Basis().scaled(Vector3(0.17,0.12,0.17)),blossom))
	var flower := SphereMesh.new()
	flower.radius=1; flower.height=2; flower.radial_segments=6; flower.rings=3
	_instances(flower,leaves,Color("365b3c"))
	for i in range(3): _instances(flower,groups[i],[Color("e38d9b"),Color("f2b5ad"),Color("ebe2c6")][i])

func _build_clubhouse() -> void:
	var p := ground_point(-80,14)
	var box := BoxMesh.new(); box.size=Vector3(27,6,12)
	mesh_node(box,material(Color("efe2c6")),p+Vector3(0,3,0))
	var roof := BoxMesh.new(); roof.size=Vector3(30,1.2,15)
	mesh_node(roof,material(Color("284638")),p+Vector3(0,6.4,0))
	for i in range(7): cylinder(p+Vector3(-12+i*4,3,7),0.25,6,Color("fff2d5"))
