extends RefCounted
# Shared identity choices follow the generated portraits in assets/portraits.
const SKIN=["d2a079","d9a17f","cf9b79","d5a075","c99674","d5ae8f","ddb092","cda078"]
const HAIR=["62412b","392c24","483225","211c18","2a211c","b8b8ad","795239","403027"]
const BUILD=[0.94,1.06,0.98,0.96,1.18,1.04,0.90,0.94]

static func face(course: Node3D,parent: Node3D,id: int) -> void:
	var skin:=Color(SKIN[id]); var hair:=Color(HAIR[id])
	var root:=Node3D.new(); root.position=Vector3(0,0.94,-0.20); parent.add_child(root)
	var head=course.sphere(Vector3.ZERO,0.20,skin,root)
	head.scale=Vector3(0.92 if id in [1,4] else 0.80,1.16 if id in [0,7] else 1.08,0.87)
	var jaw=course.sphere(Vector3(0,-0.105,-0.035),0.13,skin,root); jaw.scale=Vector3(0.95,0.70,0.95)
	for side in [-1,1]:
		var ear=course.sphere(Vector3(side*0.17,-0.015,0),0.047,skin,root); ear.scale=Vector3(0.5,1,0.72)
		course.sphere(Vector3(side*0.055,0.024,-0.165),0.030,Color("f5eee1"),root)
		course.sphere(Vector3(side*0.055,0.023,-0.189),0.014,Color("443529"),root)
		course.sphere(Vector3(side*0.051,0.029,-0.199),0.005,Color.WHITE,root)
		var brow=course.sphere(Vector3(side*0.06,0.067,-0.171),0.036,hair,root); brow.scale=Vector3(1,0.22,0.35); brow.rotation.z=side*0.10
		var cheek=course.sphere(Vector3(side*0.094,-0.035,-0.134),0.06,skin.lightened(0.025),root); cheek.scale=Vector3(0.8,0.65,0.65)
	var nose=course.sphere(Vector3(0,-0.011,-0.191),0.041,skin,root); nose.scale=Vector3(0.68,1.25,0.9)
	var lip=course.sphere(Vector3(0,-0.09,-0.165),0.04,Color("9b6251"),root); lip.scale=Vector3(1,0.20,0.3)
	var smile=course.sphere(Vector3(0,-0.086,-0.173),0.030,Color("efe8d9"),root); smile.scale=Vector3(1,0.13,0.15)
	if id in [0,1,4]:
		for j in range(27):
			var a: float=PI*float(j)/26
			var beard=course.sphere(Vector3(cos(a)*0.12,-0.06-sin(a)*0.12,-0.08-sin(a)*0.07),0.039 if id!=1 else 0.02,hair,root)
			beard.scale=Vector3(1,1.3 if id==0 else 1,0.8)
	for j in range(22):
		var a: float=TAU*j/22.0
		if sin(a)<-0.5: continue
		var lock=course.sphere(Vector3(cos(a)*0.163,0.065,sin(a)*0.145),0.058,hair,root)
		lock.scale=Vector3(0.65,1.1,0.80)
		if id in [0,7]:
			var lower=course.sphere(Vector3(cos(a)*0.177,-0.08,sin(a)*0.152+0.035),0.065,hair,root); lower.scale=Vector3(0.66,1.65 if id==0 else 1.1,0.83)
	var cap=course.sphere(Vector3(0,0.15,0.005),0.207,Color("f2ead8"),root); cap.scale=Vector3(0.92,0.52,0.88)
	var brim=course.sphere(Vector3(0,0.12,-0.19),0.20,Color("f2ead8"),root); brim.scale=Vector3(0.85,0.055,0.85)
	var button=course.sphere(Vector3(0,0.26,0),0.017,Color("ddd4c1"),root)
	button.scale.y=0.5

static func tailoring(course: Node3D,parent: Node3D,color: Color) -> void:
	for side in [-1,1]:
		var collar=course.sphere(Vector3(side*0.075,0.66,-0.20),0.09,color.lightened(0.14),parent)
		collar.scale=Vector3(0.65,0.45,0.30); collar.rotation.z=side*0.5
	for y in [0.53,0.58,0.63]: course.sphere(Vector3(0,y,-0.265),0.013,Color("f1e7d2"),parent)
	var buckle:=BoxMesh.new(); buckle.size=Vector3(0.08,0.055,0.025)
	course.mesh_node(buckle,course.material(Color("b8b7a3"),0.3),Vector3(0,0.015,-0.27),parent)
