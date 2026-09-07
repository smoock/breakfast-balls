extends Node3D

const Data = preload("res://game/data.gd")
const Layouts=preload("res://game/layouts.gd")
var green_radii:=Vector2(16,16)

func profile(values: Array,t: float) -> float:
	var at: float=clampf(t,0,1)*4
	var i: int=mini(3,int(at))
	return lerpf(values[i],values[i+1],smoothstep(0,1,at-i))
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
	return profile(Layouts.HOLES[hole_index].x,-z/length_m)

func base_height_at(x: float, z: float) -> float:
	var t: float = clampf(-z / length_m, 0.0, 1.0)
	var base: float = rise * smoothstep(0.0, 1.0, t)
	var green_z: float = -length_m
	var dist: float = Vector2(x - center_x(green_z), z - green_z).length()
	var hills: float = sin(z * 0.026 + hole_index) * 2.1 + sin(x * 0.041 + z * 0.018) * 1.4
	var slope: float = (x - center_x(green_z)) * 0.026 + (z - green_z) * 0.018
	return base + lerpf(slope, hills, smoothstep(24.0, 46.0, dist))

func height_at(x: float, z: float) -> float:
	var height: float=base_height_at(x,z)
	# Bunkers are true terrain bowls. The broad flat floor and steeper outer third
	# produce a visible face/lip while keeping ball physics on the same surface.
	for e in bunkers:
		var q: float=sqrt(pow((x-e.x)/e.z,2.0)+pow((z-e.y)/e.w,2.0))
		if q<1.0:
			var bowl: float=1.0-smoothstep(0.48,1.0,q)
			height-=1.15*bowl
	return height

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
	if in_ellipse(p,Vector4(pin.x,pin.z,green_radii.x,green_radii.y)): return "GREEN"
	if in_ellipse(p,Vector4(0,0,8,5)): return "TEE"
	if p.z < -15.0 and p.z > -length_m:
		var edge: float=absf(p.x-center_x(p.z))-fairway_width(p.z)
		if edge<0: return "FAIRWAY"
		if edge<7: return "FIRST CUT"
	return "SECOND CUT"

func fairway_width(z: float) -> float:
	return profile(Layouts.HOLES[hole_index].w,-z/length_m)

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

func body_prism(pos: Vector3, height: float, bottom: Vector2, top: Vector2, color: Color, parent: Node = self) -> MeshInstance3D:
	# A softly tapered human/clothing silhouette; unlike a scaled sphere it has shoulders,
	# a waist, planar sides and readable front/back surfaces.
	var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0: float=-height*0.5; var y1: float=height*0.5
	var b=[Vector3(-bottom.x,y0,-bottom.y),Vector3(bottom.x,y0,-bottom.y),Vector3(bottom.x,y0,bottom.y),Vector3(-bottom.x,y0,bottom.y)]
	var t=[Vector3(-top.x,y1,-top.y),Vector3(top.x,y1,-top.y),Vector3(top.x,y1,top.y),Vector3(-top.x,y1,top.y)]
	for face in [[b[0],b[1],t[1],b[0],t[1],t[0]],[b[1],b[2],t[2],b[1],t[2],t[1]],[b[2],b[3],t[3],b[2],t[3],t[2]],[b[3],b[0],t[0],b[3],t[0],t[3]],[b[0],b[3],b[2],b[0],b[2],b[1]],[t[0],t[1],t[2],t[0],t[2],t[3]]]:
		for v in face: st.add_vertex(v)
	st.generate_normals()
	return mesh_node(st.commit(),material(color),pos,parent)

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
	# Clear the previous hole's hazards before sampling this hole's tee and pin.
	# Bunkers now affect height_at(), so stale ellipses would otherwise dent them.
	ponds.clear()
	bunkers.clear()
	trees.clear()
	tee = ground_point(0, 0, 0.15)
	pin = ground_point(center_x(-length_m), -length_m, 0.1)
	var layout: Dictionary=Layouts.HOLES[index]
	green_radii=Vector2(layout.g[0],layout.g[1])
	for e in layout.s: bunkers.append(Vector4(pin.x+e[0],pin.z+e[1],e[2],e[3]))
	for e in layout.f:
		var z: float=-length_m*e[0]
		bunkers.append(Vector4(center_x(z)+e[1],z,e[2],e[3]))
	for e in layout.get("water",[]): ponds.append(Vector4(pin.x+e[0],pin.z+e[1],e[2],e[3]))
	if layout.get("creek",false):
		for i in range(20):
			var z: float=-length_m*(0.28+i*0.032)
			ponds.append(Vector4(center_x(z)-fairway_width(z)-6,z,4.5,12))
	var backdrop:=PlaneMesh.new(); backdrop.size=Vector2(4000,4000)
	mesh_node(backdrop,material(Color("547449")),Vector3(0,-24,-length_m*0.5))
	_build_ground()
	for e in ponds:
		# A dark damp shelf separates water from turf and hides the procedural seam.
		_patch(Vector4(e.x,e.y,e.z+1.35,e.w+1.35),Color("365f3b"),0.075)
	_build_water_surface()
	_patch(Vector4(pin.x,pin.z,green_radii.x+3,green_radii.y+3), Color("537e43"), 0.12)
	_patch(Vector4(pin.x,pin.z,green_radii.x,green_radii.y), Color("739650"), 0.16)
	# Subtle green mowing stripes; their geometry follows the playable slope.
	for j in range(-6,7):
		var x: float = pin.x + j * green_radii.x/7.0
		var half: float = green_radii.y*0.94*sqrt(maxf(0.0,1.0-pow((x-pin.x)/green_radii.x,2)))
		_strip(x, pin.z-half, pin.z+half, 1.1, Color("799c55"))
	# Draw bunkers after the green and its mowing stripes so sand cuts cleanly
	# through the putting surface instead of inheriting painted turf ribbons.
	for e in bunkers:
		_patch(Vector4(e.x,e.y,e.z+2.2,e.w+2.2), Color("537646"), 0.10)
		_patch(Vector4(e.x,e.y,e.z+1.15,e.w+1.15), Color("8b7652"), 0.12)
		_patch(e, Color("eedbab"), 0.16)
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
	m.set_shader_parameter("hole_length",length_m)
	m.set_shader_parameter("hole_bend",bend)
	m.set_shader_parameter("par_five",Data.HOLES[hole_index][1]==5)
	m.set_shader_parameter("route_x",PackedFloat32Array(Layouts.HOLES[hole_index].x))
	m.set_shader_parameter("route_width",PackedFloat32Array(Layouts.HOLES[hole_index].w))
	terrain_mesh = mesh_node(st.commit(),m,Vector3.ZERO)

func _patch(e: Vector4, color: Color, offset: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var is_hazard: bool=color==Color("4b9390") or color==Color("eedbab")
	var rings: int=9 if is_hazard else 1
	var sectors: int=96 if is_hazard else 64
	for ring in range(rings):
		var r0: float=float(ring)/rings; var r1: float=float(ring+1)/rings
		for i in range(sectors):
			var a: float=TAU*i/sectors; var b: float=TAU*(i+1)/sectors
			var points=[Vector3(e.x+cos(a)*e.z*r0,0,e.y+sin(a)*e.w*r0),Vector3(e.x+cos(b)*e.z*r0,0,e.y+sin(b)*e.w*r0),Vector3(e.x+cos(a)*e.z*r1,0,e.y+sin(a)*e.w*r1),Vector3(e.x+cos(b)*e.z*r1,0,e.y+sin(b)*e.w*r1)]
			for k in [0,1,2,2,1,3]:
				var p: Vector3=points[k]
				if color==Color("4b9390"):
					# All overlapping ellipses use the identical surface function, preventing
					# intersecting planes and bright triangular seams in compound ponds.
					p.y=height_at(p.x,p.z)+offset
				elif color==Color("eedbab"):
					# Sand follows the same bowl used by collision and ball physics.
					p.y=height_at(p.x,p.z)+offset
				else: p.y=height_at(p.x,p.z)+offset
				st.add_vertex(p)
	st.generate_normals()
	var mat: Material=material(color)
	if color.g>color.r:
		var turf:=ShaderMaterial.new(); turf.shader=preload("res://game/turf.gdshader")
		turf.set_shader_parameter("use_vertex_color",false); turf.set_shader_parameter("turf_color",color.darkened(0.12)); mat=turf
		turf.set_shader_parameter("cut_kind",0 if e.x==0 and e.y==0 else 4)
	if is_hazard:
		var hazard_mat:=ShaderMaterial.new(); hazard_mat.shader=preload("res://game/hazard.gdshader")
		hazard_mat.set_shader_parameter("water",color==Color("4b9390"))
		hazard_mat.set_shader_parameter("ellipse",e)
		mat=hazard_mat
	mesh_node(st.commit(),mat,Vector3.ZERO)

func _build_water_surface() -> void:
	if ponds.is_empty(): return
	var min_x: float=INF; var max_x: float=-INF; var min_z: float=INF; var max_z: float=-INF
	for e in ponds:
		min_x=minf(min_x,e.x-e.z); max_x=maxf(max_x,e.x+e.z)
		min_z=minf(min_z,e.y-e.w); max_z=maxf(max_z,e.y+e.w)
	var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step: float=1.5
	var nx: int=int(ceil((max_x-min_x)/step)); var nz: int=int(ceil((max_z-min_z)/step))
	for iz in range(nz):
		var z: float=min_z+iz*step
		for ix in range(nx):
			var x: float=min_x+ix*step
			var center:=Vector3(x+step*0.5,0,z+step*0.5)
			var wet: bool=false
			for e in ponds:
				if in_ellipse(center,e): wet=true; break
			if not wet: continue
			for p in [Vector2(x,z),Vector2(x+step,z),Vector2(x,z+step),Vector2(x,z+step),Vector2(x+step,z),Vector2(x+step,z+step)]:
				st.add_vertex(ground_point(p.x,p.y,0.12))
	st.generate_normals()
	var water_mat:=ShaderMaterial.new(); water_mat.shader=preload("res://game/hazard.gdshader")
	water_mat.set_shader_parameter("water",true)
	# Shore color comes from the damp-bank geometry; a large ellipse keeps this
	# single union surface in the shader's deep-water range.
	water_mat.set_shader_parameter("ellipse",Vector4((min_x+max_x)*0.5,(min_z+max_z)*0.5,maxf(1.0,max_x-min_x)*8.0,maxf(1.0,max_z-min_z)*8.0))
	mesh_node(st.commit(),water_mat,Vector3.ZERO)

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

func _instances_authored(mesh: Mesh, transforms: Array) -> void:
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=mesh
	mm.instance_count=transforms.size()
	for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
	var node:=MultiMeshInstance3D.new()
	node.multimesh=mm
	add_child(node)

func _mesh_from_scene(path: String) -> Mesh:
	var root: Node
	if ResourceLoader.exists(path):
		var packed: PackedScene=load(path)
		if packed==null: return null
		root=packed.instantiate()
	else:
		# Development and portable builds can read the Blender-exported GLB directly;
		# this also keeps the test scene independent of editor import timing.
		var document:=GLTFDocument.new(); var state:=GLTFState.new()
		if document.append_from_file(ProjectSettings.globalize_path(path),state)!=OK: return null
		root=document.generate_scene(state)
		if root==null: return null
	var nodes:=root.find_children("*","MeshInstance3D",true,false)
	if nodes.is_empty():
		root.free(); return null
	var result: Mesh=nodes[0].mesh.duplicate()
	root.free()
	return result

func _build_authored_trees() -> bool:
	var pine_mesh:=_mesh_from_scene("res://game/assets/models/tree_pine_a.glb")
	var broad_mesh:=_mesh_from_scene("res://game/assets/models/tree_broadleaf_a.glb")
	if pine_mesh==null or broad_mesh==null: return false
	var pines: Array=[]; var broadleaf: Array=[]
	for i in range(200):
		var z: float=rng.randf_range(-length_m-65,48)
		var x: float=center_x(z)+(1 if i%2 else -1)*rng.randf_range(39,155)
		var p:=ground_point(x,z)
		if lie_at(p)=="WATER" or Vector2(x-pin.x,z-pin.z).length()<32: continue
		var h: float=rng.randf_range(14,27)
		trees.append(Vector3(x,p.y+h*0.5,z))
		var s: float=h/16.0
		var basis:=Basis().rotated(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(s*rng.randf_range(0.86,1.08),s,s*rng.randf_range(0.86,1.08)))
		var transform:=Transform3D(basis,p+Vector3(0,h*0.46,0))
		if i%3!=0: pines.append(transform)
		else: broadleaf.append(transform)
	_instances_authored(pine_mesh,pines)
	_instances_authored(broad_mesh,broadleaf)
	return true

func _build_trees() -> void:
	if _build_authored_trees(): return
	var trunks: Array = []
	var pine_foliage: Array = [[],[],[],[]]
	var broad_foliage: Array = [[],[],[],[]]
	var branches: Array = []
	for i in range(200):
		var z: float = rng.randf_range(-length_m-65,48)
		var x: float = center_x(z) + (1 if i%2 else -1)*rng.randf_range(39,155)
		var p := ground_point(x,z)
		if lie_at(p) == "WATER" or Vector2(x-pin.x,z-pin.z).length()<32: continue
		var h: float = rng.randf_range(14,27)
		trees.append(Vector3(x,p.y+h*0.5,z))
		trunks.append(Transform3D(Basis().scaled(Vector3(0.7,h,0.7)),p+Vector3(0,h*0.5,0)))
		# Branching pines and broadleaf crowns replace the old two-cone trees.
		var pine: bool=i%3!=0
		for j in range(6):
			var a: float=j*2.399+rng.randf_range(-0.3,0.3)
			var tier: float=float(j)/6.0
			var reach: float=(1.0-tier*0.65)*h*(0.23 if pine else 0.30)
			var tip: Vector3=p+Vector3(cos(a)*reach,h*(0.48+tier*0.50),sin(a)*reach)
			var start: Vector3=p+Vector3(0,h*(0.45+tier*0.48),0)
			var axis: Vector3=(tip-start).normalized()
			var basis:=Basis(Vector3.UP.cross(axis).normalized(),axis,Vector3.ZERO)
			basis.z=basis.x.cross(basis.y).normalized()
			branches.append(Transform3D(basis.scaled_local(Vector3(0.18,tip.distance_to(start),0.18)),(tip+start)*0.5))
			var size: float=rng.randf_range(2.25,3.45)*(1.0-tier*0.45)
			if pine:
				# Directional needle sprays create air gaps and a recognizable pine silhouette.
				pine_foliage[(i+j)%4].append(Transform3D(Basis().rotated(Vector3.UP,a).scaled(Vector3(size*1.30,size*0.82,size*0.72)),tip))
			else:
				# Broadleaf crowns stay faceted and irregular, with branches visible between masses.
				broad_foliage[(i+j)%4].append(Transform3D(Basis().rotated(Vector3.UP,a).rotated(Vector3.RIGHT,rng.randf_range(-0.22,0.22)).scaled(Vector3(size*1.50,size*1.05,size*1.18)),tip))
	var trunk := CylinderMesh.new()
	trunk.height=1; trunk.top_radius=0.28; trunk.bottom_radius=0.5; trunk.radial_segments=8
	var crown := SphereMesh.new()
	crown.radius=1; crown.height=2; crown.radial_segments=8; crown.rings=4
	var needles := CylinderMesh.new()
	needles.height=2; needles.bottom_radius=1; needles.top_radius=0.08; needles.radial_segments=7; needles.rings=1
	_instances(trunk,trunks,Color("665745"))
	_instances(trunk,branches,Color("665745"))
	for i in range(4):
		var leaf_color: Color=[Color("173f30"),Color("295a37"),Color("42723e"),Color("5a8247")][i]
		_instances(needles,pine_foliage[i],leaf_color)
		_instances(crown,broad_foliage[i],leaf_color)

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
		if lie_at(p)!="SECOND CUT" or p.distance_to(pin)<21: continue
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
