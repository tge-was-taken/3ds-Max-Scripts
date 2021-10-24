
fn ReadFixedString bstream fixedLen = (
    local str = ""
    for i = 1 to fixedLen do
    (
        str += bit.intAsChar (ReadByte bstream #unsigned)
    )
    str
)

fn readHalfFloat fstream = (
    hf=readshort fstream #unsigned
    sign = bit.get hf 16
    exponent = (bit.shift (bit.and hf (bit.hexasint "7C00")) -10) as integer - 16
    fraction = bit.and hf (bit.hexasint "03FF")
    if sign==true then sign = 1 else sign = 0
    exponentF = exponent + 127
    outputAsFloat = bit.or (bit.or (bit.shift fraction 13) \
    (bit.shift exponentF 23)) (bit.shift sign 31)
    return bit.intasfloat outputasfloat*2
)

clearlistener()
fname = getOpenFileName \ 
caption:"Open File" \
types:"WMB model(*.wmb)|*.wmb" \
historyCategory:"PlatinumWMB Object Presets"
f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = GetFilenamePath fname

Bone_Array = #()
SubMeshInfo_Array = #()
TexID_Array = #()
Material_Array = #()
BoneMap_Array = #()
BoneID_Array = #()

struct SMInfo (
	SMVertCount, SMFaceCount
)

struct weight_data
(
	boneids,weights
)

struct BoneMapData (
	BoneMapOffset, BoneMapCount
)

WMBType = readfixedstring f 4
case WMBType of (
"WMB3":( -- Legend of Korra
Unknown1 = readshort f
Unknown2 = readshort f
Unknown3 = readlong f
Unknown4 = readshort f
Unknown5 = readshort f
Unknown6 = readlong f
fseek f 0x18 #seek_cur -- Presumably the Bounding Box
DataInfoOff = readlong f
DataInfoCount = readlong f
SubMeshInfoOff = readlong f
SubMeshCount = readlong f #unsigned
TextureInfoOff = readlong f
BoneOff = readlong f
BoneCount = readlong f
UnkOff = readlong f
UnkCount = readlong f
BoneMapTableOff = readlong f
BoneMapTableCount = readlong f
ShaderDataOff = readlong f
ShaderDataCount = readlong f
MatFloatsOff = readlong f
MatFloatsCount = readlong f
MaterialInfoOff = readlong f
MaterialCount = readlong f

if DataInfoOff == 0x00 then throw (messagebox "Empty Model!")

fseek f TextureInfoOff #seek_set
TexInfoTableOff = readlong f
TexInfoTableCount = readlong f
fseek f TexInfoTableOff #seek_set
for t = 1 to TexInfoTableCount do (
	SubMeshID = readlong f +1
	Unk = readlong f 
	Unk = readshort f +1
	TexID = readshort f #unsigned + 1
	if TexID == 0 then TexID = 1
	Unk = readlong f
	TexID_Array[SubMeshID]=TexID
-- 	print ("TexID: "+TexID_Array[SubMeshID] as string)
)

fseek f MatFloatsOff #seek_set
for mf = 1 to MatFloatsCount do ( -- Probably something else!
	MatFloat = readfloat f
)

fseek f MaterialInfoOff #seek_set
Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
for m = 1 to MaterialCount do (
	MatNameOff = readlong f
	MatFloatA = readlong f
	MatFloatB = readfloat f
	MatFloatC = readfloat f
	MatFloatD = readfloat f
	MatFloatE = readfloat f
	MatFloatF = readfloat f
	MatAssignOff = readlong f
	MatAssignCount = readlong f
	fseek f 0x10 #seek_cur -- null
	UnkOff = readlong f -- sometimes null
	UnkCount = readlong f -- sometimes null
	fseek f 0x8 #seek_cur -- null
	UnkOff = readlong f
	UnkCount = readlong f
	MatEntryEnd = ftell f
	
	fseek f MatNameOff #seek_set
	MatName = readstring f
	
	fseek f MatAssignOff #seek_set
	for ma = 1 to MatAssignCount do (
		MatAssignID = readshort f +1 -- References the submesh ID to assign materials
		Material_Array[MatAssignID]=MatName
	)
	
	fseek f MatEntryEnd #seek_set
)
print Material_Array

fseek f DataInfoOff #seek_set
VertOff = readlong f
Vert2Off = readlong f
fseek f 0x8 #seek_cur
VertStride = readlong f
Vert2Stride = readlong f
fseek f 0x8 #seek_cur
VertCount = readlong f
FaceOff = readlong f
FaceCount = readlong f
fseek f 0x4 #seek_cur

fseek f BoneOff #seek_set
for b = 1 to BoneCount do (
	Unk = readshort f
	BoneID = readshort f +1
	BoneParent = readshort f +1
	Unk = readshort f
	lx = readfloat f; ly = readfloat f; lz = readfloat f  -- Local positions
	px = readfloat f; py = readfloat f; pz = readfloat f
	tfm = (scalematrix [1,1,1])
	tfm = tfm * (transmatrix [px,-pz,py])
	tfm = tfm * (matrix3 [10,0,0] [0,10,0] [0,0,10] [0,0,0])
	newBone = bonesys.createbone	\
				  tfm.row4	\
				  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
				  (normalize tfm.row3)
			newBone.name = ("Bone"+(b as string))
			newBone.width  = 0.01
			newBone.height = 0.01
			newBone.transform = tfm
			newBone.setBoneEnable false 0
			newBone.wirecolor = yellow
			newbone.showlinks = true
			newBone.pos.controller      = TCB_position ()
			newBone.rotation.controller = TCB_rotation ()
			If BoneParent != 0 Do (
				newBone.parent = Bone_Array[BoneParent]
			)
	append BoneID_Array b
	append Bone_Array newBone
)

fseek f (SubMeshInfoOff+0xC) #seek_set
for sm = 1 to SubMeshCount do (
	SMVertCount = readlong f #unsigned
	SMFaceCount = readlong f #unsigned/3
	UnkCount1 = readlong f
	UnkCount2 = readlong f
	UnkCount3 = readlong f
	append SubMeshInfo_Array (SMInfo SMVertCount:SMVertCount SMFaceCount:SMFaceCount)
)

if BoneMapTableOff != 0 then (
fseek f BoneMapTableOff #seek_set
for bmt = 1 to BoneMapTableCount do (
	BoneMapOff = readlong f
	BoneMapCount = readlong f
	BoneMap_Array[bmt]=(BoneMapData BoneMapOffset:BoneMapOff BoneMapCount:BoneMapCount)
)
)

SMVertOff = VertOff
SMVert2Off = Vert2Off
SMFaceOff = FaceOff
SMBoneMapOff = BoneMapTableOff
for sm = 1 to SubMeshCount do (

Vert_Array = #()
UV_Array = #()
Normal_Array = #()
Face_Array = #()
Weight_Array = #()
Color_Array = #()
BonePallet_Array = #()	

UseBonePallet = false	
if (TexID_Array[sm] != undefined) AND (BoneMapTableOff != 0) then (
	UseBonePallet = true
	fseek f BoneMap_Array[(TexID_Array[sm])].BoneMapOffset #seek_set
	for bm = 1 to BoneMap_Array[(TexID_Array[sm])].BoneMapCount do (
		UsedBoneID = readbyte f #unsigned + 1
		append BonePallet_Array UsedBoneID
	)
)

-- print ("Used Bones: "+BonePallet_Array as string)

fseek f SMVertOff #seek_set
case of (
(VertStride == 0x14):(
	for v = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
		vx = readfloat f*10
		vy = readfloat f*10
		vz = readfloat f*10
		tu = readhalffloat f
		tv = readhalffloat f*-1
		cr = readbyte f #unsigned -- Colors seem to be related to shading
		cg = readbyte f #unsigned
		cb = readbyte f #unsigned
		ca = readbyte f #unsigned
		append Vert_Array [vx,-vz,vy]
		append UV_Array [tu,tv,0]
		append Color_Array [cr,cg,cb]
	)
)
(VertStride == 0x18):(
	for v = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
		vx = readfloat f*10
		vy = readfloat f*10
		vz = readfloat f*10
		tu = readhalffloat f
		tv = readhalffloat f*-1
		fseek f 0x8 #seek_cur
		append Vert_Array [vx,-vz,vy]
		append UV_Array [tu,tv,0]
	)
)
(VertStride == 0x1C):(
	for v = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
		vx = readfloat f*10
		vy = readfloat f*10
		vz = readfloat f*10
		tu = readhalffloat f
		tv = readhalffloat f*-1
		fseek f 0xC #seek_cur
		append Vert_Array [vx,-vz,vy]
		append UV_Array [tu,tv,0]
	)
)
default:throw "Unknown VertStride!\n Import Failed!"
)
SMVertOff = ftell f

fseek f SMVert2Off #seek_set
case of (
(Vert2Stride == 0x8):(
	for v = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
		nx = readhalffloat f
		ny = readhalffloat f
		nz = readhalffloat f
		null = readshort f
		Bone1 = 1
		Bone2 = 0
		Bone3 = 0
		Bone4 = 0
		Weight1 = 255
		Weight2 = 0
		Weight3 = 0
		Weight4 = 0
		
		w = (weight_data boneids:#() weights:#())
		maxweight = 0
		if(weight1 != 0) then
			maxweight = maxweight + weight1
		if(weight2 != 0) then
			maxweight = maxweight + weight2
		if(weight3 != 0) then
			maxweight = maxweight + weight3
		if(weight4 != 0) then
			maxweight = maxweight + weight4


		if(maxweight != 0) then (
			if(weight1 != 0) then (
				w1 = weight1 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone1)])
				else append w.boneids (bone1)
				append w.weights (w1/255.0)
			)
			if(weight2 != 0) then (
				w2 = weight2 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone2)])
				else append w.boneids (bone2)
				append w.weights (w2/255.0)
			)
			if(weight3 != 0) then (
				w3 = weight3 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone3)])
				else append w.boneids (bone3)
				append w.weights (w3/255.0)
			)
			if(weight4 != 0) then (
				w4 = weight4 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone4)])
				else append w.boneids (bone4)
				append w.weights (w4/255.0)
			)      
		)
		append Weight_Array w		
		append Normal_Array [nx,-nz,ny]
	)
)
(Vert2Stride == 0x10):(
	for v = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
		nx = readhalffloat f
		ny = readhalffloat f
		nz = readhalffloat f
		null = readshort f
		Bone1 = readbyte f #unsigned
		Bone2 = readbyte f #unsigned
		Bone3 = readbyte f #unsigned
		Bone4 = readbyte f #unsigned
		Weight1 = readbyte f #unsigned
		Weight2 = readbyte f #unsigned
		Weight3 = readbyte f #unsigned
		Weight4 = readbyte f #unsigned
-- 		format "Bone1: % Bone2: % Bone3: % Bone4: %" Bone1 Bone2 Bone3 Bone4
		
		w = (weight_data boneids:#() weights:#())
		maxweight = 0
		if(weight1 != 0) then
			maxweight = maxweight + weight1
		if(weight2 != 0) then
			maxweight = maxweight + weight2
		if(weight3 != 0) then
			maxweight = maxweight + weight3
		if(weight4 != 0) then
			maxweight = maxweight + weight4


		if(maxweight != 0) then (
			if(weight1 != 0) then (
				w1 = weight1 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone1+1)])
				else append w.boneids (bone1+1)
				append w.weights (w1/255.0)
			)
			if(weight2 != 0) then (
				w2 = weight2 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone2+1)])
				else append w.boneids (bone2+1)
				append w.weights (w2/255.0)
			)
			if(weight3 != 0) then (
				w3 = weight3 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone3+1)])
				else append w.boneids (bone3+1)
				append w.weights (w3/255.0)
			)
			if(weight4 != 0) then (
				w4 = weight4 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone4+1)])
				else append w.boneids (bone4+1)
				append w.weights (w4/255.0)
			)      
		)
		append Weight_Array w		
		append Normal_Array [nx,-nz,ny]
	)
)
(Vert2Stride == 0x14):(
	for v = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
		nx = readhalffloat f
		ny = readhalffloat f
		nz = readhalffloat f
		null = readshort f
		Bone1 = readbyte f #unsigned
		Bone2 = readbyte f #unsigned
		Bone3 = readbyte f #unsigned
		Bone4 = readbyte f #unsigned
		Weight1 = readbyte f #unsigned
		Weight2 = readbyte f #unsigned
		Weight3 = readbyte f #unsigned
		Weight4 = readbyte f #unsigned
		fseek f 0x4 #seek_cur
-- 		format "Bone1: % Bone2: % Bone3: % Bone4: %" Bone1 Bone2 Bone3 Bone4
		
		w = (weight_data boneids:#() weights:#())
		maxweight = 0
		if(weight1 != 0) then
			maxweight = maxweight + weight1
		if(weight2 != 0) then
			maxweight = maxweight + weight2
		if(weight3 != 0) then
			maxweight = maxweight + weight3
		if(weight4 != 0) then
			maxweight = maxweight + weight4


		if(maxweight != 0) then (
			if(weight1 != 0) then (
				w1 = weight1 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone1+1)])
				else append w.boneids (bone1+1)
				append w.weights (w1/255.0)
			)
			if(weight2 != 0) then (
				w2 = weight2 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone2+1)])
				else append w.boneids (bone2+1)
				append w.weights (w2/255.0)
			)
			if(weight3 != 0) then (
				w3 = weight3 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone3+1)])
				else append w.boneids (bone3+1)
				append w.weights (w3/255.0)
			)
			if(weight4 != 0) then (
				w4 = weight4 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone4+1)])
				else append w.boneids (bone4+1)
				append w.weights (w4/255.0)
			)      
		)
		append Weight_Array w		
		append Normal_Array [nx,-nz,ny]
	)
)
default:throw "Unknown Vert2Stride!\n Import Failed!"
)
SMVert2Off = ftell f

fseek f SMFaceOff #seek_set
for x = 1 to (SubMeshInfo_Array[sm].SMFaceCount) do (
	f1 = readshort f #unsigned+1
	f2 = readshort f #unsigned+1
	f3 = readshort f #unsigned+1
	append Face_Array [f3,f2,f1]
)
SMFaceOff = ftell f
msh = mesh vertices:Vert_Array faces:Face_Array
msh.numTVerts = UV_Array.count
if Material_Array[sm] != undefined then msh.name = (Material_Array[sm]+"_"+sm as string) else msh.name = ("NoMaterial_"+SM as string)
msh.backfacecull = on
buildTVFaces msh
for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
for j = 1 to UV_array.count do setTVert msh j UV_array[j]
for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
msh.material = standard()
texsm = sm - 1
if texsm == 0 then texsm = 1
if Material_Array[sm] != undefined then msh.material.name = Material_Array[sm] else msh.material.name = ("NoMaterial_"+SM as string)
tm = Bitmaptexture filename:(filepath+filename+"_"+((TexID_Array[texsm]) as string)+".dds")
msh.material.DiffuseMap = tm
msh.material.showinViewport = true

-- Weight_Array.count = 0
-- Normal_Array.count = 0

if Normal_Array.count != 0 then (
max modify mode
select msh
addmodifier msh (Edit_Normals ()) ui:off
msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
EN_setNormal = msh.Edit_Normals.SetNormal
normID = #{}

for v = 1 to Normal_array.count do(
	free normID
	EN_convertVS #{v} &normID
	for id in normID do EN_setNormal id Normal_array[v]
)
)

if Weight_Array.count != 0 then (
max modify mode
select msh
skinMod = skin ()
addModifier msh skinMod
for i = 1 to BoneCount do
(  
	maxbone = Bone_Array[i]
	if i != BoneCount then 
		skinOps.addBone skinMod maxbone 0
	else
		skinOps.addBone skinMod maxbone 1
)
modPanel.setCurrentObject skinMod
for i = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
   w = Weight_Array[i]
   bi = #() --bone index array
   wv = #() --weight value array
   
   for j = 1 to w.boneids.count do
   (
      boneid = w.boneids[j]
      weight = w.weights[j]
      append bi boneid
      append wv weight
   )   
   
   skinOps.ReplaceVertexWeights skinMod i bi wv
   
)
)
)

Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
fclose f
gc()
)
"WMB4":( -- Metal Gear Rising: Revengeance
Unknown1 = readlong f
VertFlag = readbyte f
UnkFlag = readbyte f
Unknown3 = readshort f
Unknown4 = readlong f
fseek f 0x18 #seek_cur -- Presumably the Bounding Box
DataInfoOff = readlong f
DataInfoCount = readlong f
SubMeshInfoOff = readlong f
SubMeshCount = readlong f #unsigned
TextureInfoOff = readlong f
BoneOff = readlong f
BoneCount = readlong f
UnkOff = readlong f -- Related to Animation Mapping
UnkCount = readlong f
BoneMapTableOff = readlong f
BoneMapTableCount = readlong f
ShaderDataOff = readlong f
ShaderDataCount = readlong f
MatFloatsOff = readlong f
MatFloatsCount = readlong f
MaterialInfoOff = readlong f
MaterialCount = readlong f

case of (
(VertFlag == 0x37):(
	VertStride = 32
)
(VertFlag == 0x7):(
	VertStride = 24
)
)

fseek f DataInfoOff #seek_set
VertOff = readlong f
Vert2Off = readlong f
fseek f 0x8 #seek_cur
VertCount = readlong f
FaceOff = readlong f
FaceCount = readlong f
fseek f 0x4 #seek_cur

fseek f TextureInfoOff #seek_set
TexInfoTableOff = readlong f
TexInfoTableCount = readlong f
fseek f TexInfoTableOff #seek_set
for t = 1 to TexInfoTableCount do (
	SubMeshID = readlong f +1
	Unk = readlong f 
	Unk = readshort f +1
	TexID = readshort f #unsigned + 1
	if TexID == 0 then TexID = 1
	Unk = readlong f
	TexID_Array[SubMeshID]=TexID
	print ("TexID: "+TexID_Array[SubMeshID] as string)
)

fseek f MatFloatsOff #seek_set
for mf = 1 to MatFloatsCount do ( -- Probably something else!
	MatFloat = readfloat f
)

fseek f MaterialInfoOff #seek_set
Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
for m = 1 to MaterialCount do (
	MatNameOff = readlong f
	MatFloatA = readfloat f
	MatFloatB = readfloat f
	MatFloatC = readfloat f
	MatFloatD = readfloat f
	MatFloatE = readfloat f
	MatFloatF = readfloat f
	MatAssignOff = readlong f
	MatAssignCount = readlong f
	fseek f 0x10 #seek_cur -- null
	UnkOff = readlong f -- sometimes null
	UnkCount = readlong f -- sometimes null
	UnkOff = readlong f
	UnkCount = readlong f
	MatEntryEnd = ftell f
	
	fseek f MatNameOff #seek_set
	MatName = readstring f
	
	fseek f MatAssignOff #seek_set
	for ma = 1 to MatAssignCount do (
		MatAssignID = readshort f +1 -- References the submesh ID to assign materials
		Material_Array[MatAssignID]=MatName
	)
	
	fseek f MatEntryEnd #seek_set
)
print Material_Array

fseek f BoneOff #seek_set
for b = 1 to BoneCount do (
	Unk = readshort f
	BoneID = readshort f +1
	BoneParent = readshort f +1
	Unk2 = readshort f
	rx = readfloat f; ry = readfloat f; rz = readfloat f
	px = readfloat f; py = readfloat f; pz = readfloat f
	tfm = (rotateXMatrix rx) * (rotateYMatrix -rz) * (rotateZMatrix ry)
	tfm = tfm * (scalematrix [1,1,1])
	tfm = tfm * (transmatrix [px*10,-pz*10,py*10])
	newBone = bonesys.createbone	\
				  tfm.row4	\
				  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
				  (normalize tfm.row3)
			newBone.name = ("Bone"+(b as string)+"_"+Unk as string)
			newBone.width  = 0.01
			newBone.height = 0.01
			newBone.transform = tfm
			newBone.setBoneEnable false 0
			newBone.wirecolor = yellow
			newbone.showlinks = true
			newBone.pos.controller      = TCB_position ()
			newBone.rotation.controller = TCB_rotation ()
			If BoneParent != 0 Do (
				newBone.parent = Bone_Array[BoneParent]
			)
	append BoneID_Array BoneID
	append Bone_Array newBone
)

fseek f (SubMeshInfoOff+0xC) #seek_set
for sm = 1 to SubMeshCount do (
	SMVertCount = readlong f #unsigned
	SMFaceCount = readlong f #unsigned/3
	UnkCount1 = readlong f
	UnkCount2 = readlong f
	UnkCount3 = readlong f
	append SubMeshInfo_Array (SMInfo SMVertCount:SMVertCount SMFaceCount:SMFaceCount)
)
print SubMeshInfo_Array

if BoneMapTableOff != 0 then (
fseek f BoneMapTableOff #seek_set
for bmt = 1 to BoneMapTableCount do (
	BoneMapOff = readlong f
	BoneMapCount = readlong f
	BoneMap_Array[bmt]=(BoneMapData BoneMapOffset:BoneMapOff BoneMapCount:BoneMapCount)
)
)

SMVertOff = VertOff
SMVert2Off = Vert2Off
SMFaceOff = FaceOff
SMBoneMapOff = BoneMapTableOff
for sm = 1 to SubMeshCount do (

Vert_Array = #()
UV_Array = #()
UV_Array2 = #()
Normal_Array = #()
Face_Array = #()
Weight_Array = #()
Color_Array = #()
Alpha_Array = #()
BonePallet_Array = #()	

UseBonePallet = false	
if (TexID_Array[sm] != undefined) AND (BoneMapTableOff != 0) then (
	UseBonePallet = true
	fseek f BoneMap_Array[(TexID_Array[sm])].BoneMapOffset #seek_set
	for bm = 1 to BoneMap_Array[(TexID_Array[sm])].BoneMapCount do (
		UsedBoneID = readbyte f #unsigned + 1 
		append BonePallet_Array UsedBoneID
	)
)

print ("Used Bones: "+BonePallet_Array as string)
fseek f SMVertOff #seek_set
case of (
(VertStride == 32):(
	for v = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
		vx = readfloat f*10
		vy = readfloat f*10
		vz = readfloat f*10
		tu = readhalffloat f
		tv = readhalffloat f*-1
		unk1 = readbyte f
		unk2 = readbyte f
		unk3 = readbyte f
		unk4 = readbyte f
		unk5 = readbyte f
		unk6 = readbyte f
		unk7 = readbyte f
		unk8 = readbyte f
		bone1 = readbyte f #unsigned
		bone2 = readbyte f #unsigned
		bone3 = readbyte f #unsigned
		bone4 = readbyte f #unsigned
		weight1 = readbyte f #unsigned
		weight2 = readbyte f #unsigned
		weight3 = readbyte f #unsigned
		weight4 = readbyte f #unsigned
		append Vert_Array [vx,-vz,vy]
-- 		append Normal_Array [nx,-nz,ny]
		append UV_Array [tu,tv,0]
		
		w = (weight_data boneids:#() weights:#())
		maxweight = 0
		if(weight1 != 0) then
			maxweight = maxweight + weight1
		if(weight2 != 0) then
			maxweight = maxweight + weight2
		if(weight3 != 0) then
			maxweight = maxweight + weight3
		if(weight4 != 0) then
			maxweight = maxweight + weight4


		if(maxweight != 0) then (
			if(weight1 != 0) then (
				w1 = weight1 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone1+1)])
				else append w.boneids (bone1+1)
				append w.weights (w1/255.0)
			)
			if(weight2 != 0) then (
				w2 = weight2 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone2+1)])
				else append w.boneids (bone2+1)
				append w.weights (w2/255.0)
			)
			if(weight3 != 0) then (
				w3 = weight3 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone3+1)])
				else append w.boneids (bone3+1)
				append w.weights (w3/255.0)
			)
			if(weight4 != 0) then (
				w4 = weight4 as float
				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone4+1)])
				else append w.boneids (bone4+1)
				append w.weights (w4/255.0)
			)      
		)
		append Weight_Array w	
	)
)
(VertStride == 24):(
	for v = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
		vx = readfloat f*10
		vy = readfloat f*10
		vz = readfloat f*10
		tu = readhalffloat f
		tv = readhalffloat f*-1
		fseek f 0x8 #seek_cur
		append Vert_Array [vx,-vz,vy]
-- 		append Normal_Array [nx,-nz,ny]
		append UV_Array [tu,tv,0]
		
-- 		w = (weight_data boneids:#() weights:#())
-- 		maxweight = 0
-- 		if(weight1 != 0) then
-- 			maxweight = maxweight + weight1
-- 		if(weight2 != 0) then
-- 			maxweight = maxweight + weight2
-- 		if(weight3 != 0) then
-- 			maxweight = maxweight + weight3
-- 		if(weight4 != 0) then
-- 			maxweight = maxweight + weight4


-- 		if(maxweight != 0) then (
-- 			if(weight1 != 0) then (
-- 				w1 = weight1 as float
-- 				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone1+1)])
-- 				else append w.boneids (bone1+1)
-- 				append w.weights (w1/255.0)
-- 			)
-- 			if(weight2 != 0) then (
-- 				w2 = weight2 as float
-- 				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone2+1)])
-- 				else append w.boneids (bone2+1)
-- 				append w.weights (w2/255.0)
-- 			)
-- 			if(weight3 != 0) then (
-- 				w3 = weight3 as float
-- 				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone3+1)])
-- 				else append w.boneids (bone3+1)
-- 				append w.weights (w3/255.0)
-- 			)
-- 			if(weight4 != 0) then (
-- 				w4 = weight4 as float
-- 				if UseBonePallet == true then append w.boneids (BonePallet_Array[(bone4+1)])
-- 				else append w.boneids (bone4+1)
-- 				append w.weights (w4/255.0)
-- 			)      
-- 		)
-- 		append Weight_Array w	
	)
)
default:throw "Unknown VertStride!"
)
SMVertOff = ftell f

if SMVert2Off != 0 then (
fseek f SMVert2Off #seek_set
case of (
(VertStride == 32):(
	for v = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
		cr = readbyte f
		cg = readbyte f
		cb = readbyte f
		ca = readbyte f
		tu2 = readhalffloat f
		tv2 = readhalffloat f*-1
		append UV_Array2 [tu2,tv2,0]
		append Color_Array [cr,cg,cb]
		append Alpha_Array ca
	)
)
default:throw "Unknown Vert2Stride!"
)
SMVert2Off = ftell f
)

fseek f SMFaceOff #seek_set
for x = 1 to (SubMeshInfo_Array[sm].SMFaceCount) do (
	f1 = readshort f #unsigned+1
	f2 = readshort f #unsigned+1
	f3 = readshort f #unsigned+1
	append Face_Array [f3,f2,f1]
)
SMFaceOff = ftell f
msh = mesh vertices:Vert_Array faces:Face_Array
msh.numTVerts = UV_Array.count
if Material_Array[sm] != undefined then msh.name = (Material_Array[sm]+"_"+sm as string) else msh.name = ("NoMaterial_"+SM as string)
msh.backfacecull = on
if Color_Array.count != 0 then (
setNumCPVVerts msh msh.numTVerts
setCVertMode msh true
setShadeCVerts msh true
defaultVCFaces msh
for j = 1 to Color_array.count do setvertcolor msh j Color_array[j]
)
buildTVFaces msh
for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
for j = 1 to UV_array.count do setTVert msh j UV_array[j]
for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
msh.material = standard()
if Material_Array[sm] != undefined then msh.material.name = Material_Array[sm] else msh.material.name = ("NoMaterial_"+SM as string)
tm = Bitmaptexture filename:(filepath+filename+"_"+(TexID_Array[sm] as string)+".dds")
msh.material.DiffuseMap = tm
msh.material.showinViewport = true

-- Weight_Array.count = 0
-- Normal_Array.count = 0

if Normal_Array.count != 0 then (
max modify mode
select msh
addmodifier msh (Edit_Normals ()) ui:off
msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
EN_setNormal = msh.Edit_Normals.SetNormal
normID = #{}

for v = 1 to Normal_array.count do(
	free normID
	EN_convertVS #{v} &normID
	for id in normID do EN_setNormal id Normal_array[v]
)
)

if Weight_Array.count != 0 then (
max modify mode
select msh
skinMod = skin ()
addModifier msh skinMod
for i = 1 to BoneCount do
(  
	maxbone = Bone_Array[i]
	if i != BoneCount then 
		skinOps.addBone skinMod maxbone 0
	else
		skinOps.addBone skinMod maxbone 1
)
modPanel.setCurrentObject skinMod
for i = 1 to (SubMeshInfo_Array[sm].SMVertCount) do (
   w = Weight_Array[i]
   bi = #() --bone index array
   wv = #() --weight value array
   
   for j = 1 to w.boneids.count do
   (
      boneid = w.boneids[j]
      weight = w.weights[j]
      append bi boneid
      append wv weight
   )   
   
   skinOps.ReplaceVertexWeights skinMod i bi wv
   
)
)
)

Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
fclose f
gc()
)
)
