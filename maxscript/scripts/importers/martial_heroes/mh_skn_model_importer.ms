--Martial Heroes .SKN importer
--By TGE
max select all
max delete

enableSceneRedraw()
fn ReadFixedString bstream fixedLen = (
    local str = ""
    for i = 1 to fixedLen do
    (
        str += bit.intAsChar (ReadByte bstream #unsigned)
    )
    str
)
clearlistener()

fname = GetOpenFileName caption:"Open SKN file" types:"SKN File(*.skn)|*.skn"
f = fopen fname "rb"   --open file in read only format

base = getFilenamePath fname
basefile = getFilenameFile fname -- returns: "myImage.jpg"
basefile = substring basefile 3 (basefile.count - 2)
ss = substring base 1 (base.count - 5) -- returns "rof"
-- print basefile
-- print ss
DiffuseTex = (ss + "tex\4" + basefile + ".png")

-- print DiffuseTex

BNArr = #()

TextureSomething = readlong f
BoneMap = readlong f
if doesfileexist (ss + "bind\g" + (BoneMap as string) + ".bnd") then (
b = fopen (ss + "bind\g" + (BoneMap as string) + ".bnd") "rb"

unk = readlong b
NameStrCount = readlong b
SkelName = readfixedstring b NameStrCount
BoneCount = readlong b

for a = 1 to bonecount Do (
boneid = readlong b + 1
boneparent = readlong b + 1
f1 = readfloat b
f2 = readfloat b
f3 = readfloat b
f4 = readfloat b
f5 = readfloat b
f6 = readfloat b
f7 = readfloat b
tfm = (quat f4 f5 f6 (f7 * -1)) as matrix3
tfm.row4 = [f1,f2,f3]
if (boneparent != boneid) do (
tfm = tfm * BNArr[boneparent].objecttransform
 )	
newBone = bonesys.createbone	\
				  tfm.row4	\
				  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
				  (normalize tfm.row3)
			newBone.name = ((SkelName as string)+"_"+a as string)
			newBone.width  = 0.01
			newBone.height = 0.01
			newBone.transform = tfm
			newBone.setBoneEnable false 0
			newBone.wirecolor = yellow
			newbone.showlinks = true
			newBone.pos.controller      = TCB_position ()
			newBone.rotation.controller = TCB_rotation ()
 if (boneparent != 0) then
 newBone.parent = BNArr[boneparent]
append BNArr newBone
)

-- print "Bones done!"
)

NameStrCount = readlong f
MeshName = readfixedstring f NameStrCount
DataCount = readlong f

UV_Array = #()
Vert_Array = #()
Normal_Array = #()
Face_Array = #()
Weight_array = #()
W1_Array = #()
B1_Array = #()
VertID_Array = #()

struct weight_data
(
boneids,weights
)

struct Bone_Info_Struct
(
	Bone1, Bone2, Bone3, Bone4
)
struct Weight_Info_Struct
(
	Weight1, Weight2, Weight3, Weight4
)

print ("Start UV Data @ 0x"+((bit.intAsHex(ftell f))as string))

for x = 1 to DataCount do (
	f1 = readlong f+1
	tu = readfloat f
	tv = (readfloat f)*-1
	f2 = readlong f+1
	tu = readfloat f
	tv = (readfloat f)*-1
	f3 = readlong f+1
	tu = readfloat f
	tv = (readfloat f)*-1
-- 	-- print (((("f ")+f1 as string)+(" ")+f2 as string)+(" ")+f3 as string)
-- 	print ("tu "+tu as string+" tv"+tv as string)
-- 	print ("tu1 "+tu1 as string+" tv"+tv1 as string)
-- 	print ("tu2 "+tu2 as string+" tv"+tv2 as string)
	append UV_Array [tu,tv,0]
	append Face_Array [f1,f2,f3]
)

VertCount = readlong f

print ("Start Vertex Data @ 0x"+((bit.intAsHex(ftell f))as string))

for x = 1 to VertCount do (
	nx = readfloat f
	ny = readfloat f
	nz = readfloat f
	vx = readfloat f
	vy = readfloat f
	vz = readfloat f
	append Normal_Array [nx,ny,nz]
	append Vert_Array [vx,vy,vz]
)


print ("End Vertex Data @ 0x"+((bit.intAsHex(ftell f))as string))


WeightsCount = readlong f

print ("Start Weight Data @ 0x"+((bit.intAsHex(ftell f))as string))
	
Do (
WeightsCount = WeightsCount - 1
VertID = readlong f + 1
Bone1 = readlong f + 1
Bone1 = BNArr[Bone1]
Weight1 = readfloat f
Bone2 = 1
Weight2 = 0
Bone3 = 1
Weight3 = 0
Bone4 = 1
Weight4 = 0
if Weight1 < 0.999 do(
WeightsCount = WeightsCount - 1
VertID = readlong f + 1
Bone2 = readlong f + 1
Bone2 = BNArr[Bone2]
Weight2 = readfloat f
if (Weight1 + Weight2) < 0.999 do(
WeightsCount = WeightsCount - 1
VertID = readlong f + 1
Bone3 = readlong f + 1
Bone3 = BNArr[Bone3]
Weight3 = readfloat f
)
if (Weight1 + Weight2 + Weight3) < 0.999 do(
WeightsCount = WeightsCount - 1
VertID = readlong f + 1
Bone4 = readlong f + 1
Bone4 = BNArr[Bone4]
Weight4 = readfloat f
)
)
append VertID_Array VertID
append B1_array (Bone_Info_Struct Bone1:Bone1 Bone2:Bone2 Bone3:Bone3 Bone4:Bone4)
append W1_array (Weight_Info_Struct Weight1:Weight1 Weight2:Weight2 Weight3:Weight3 Weight4:Weight4)
) While WeightsCount != 0


for b = 1 to W1_array.count Do (
w = (weight_data boneids:#() weights:#())
maxweight = 0
   
if(W1_array[b].Weight1 != 0) then
   maxweight = maxweight + W1_array[b].Weight1
if(W1_array[b].Weight2 != 0) then
   maxweight = maxweight + W1_array[b].Weight2
if(W1_array[b].Weight3 != 0) then
   maxweight = maxweight + W1_array[b].Weight3
if(W1_array[b].Weight4 != 0) then
   maxweight = maxweight + W1_array[b].Weight4

if(maxweight != 0) then
   (
      if(W1_array[b].Weight1 != 0) then
      (
         w1 = W1_array[b].Weight1 as float
         append w.boneids (B1_array[b].Bone1)
         append w.weights (w1)
      )
      if(W1_array[b].Weight2 != 0) then
      (
         w2 = W1_array[b].Weight2 as float
         append w.boneids (B1_array[b].Bone2)
         append w.weights (w2)
      )
      if(W1_array[b].Weight3 != 0) then
      (
         w3 = W1_array[b].Weight3 as float
         append w.boneids (B1_array[b].Bone3)
         append w.weights (w3)
      )
      if(W1_array[b].Weight4 != 0) then
      (
         w4 = W1_array[b].Weight4 as float
         append w.boneids (B1_array[b].Bone4)
         append w.weights (w4)
      )            
   )
append Weight_array w
)


mat = standardMaterial()
mat.name = MeshName
mat.showinviewport = true
mat.twosided = false
-- tm = Bitmaptexture filename:(p + "/textures/" + TextureNames_array[PolyTextureID] + ".png")
-- tm.alphasource = 2
-- mat.diffuseMap = tm

msh = mesh vertices:Vert_array faces:Face_array
msh.numTVerts = UV_array.count
buildTVFaces msh
msh.name = MeshName
msh.material = mat
for j = 1 to UV_array.count do setTVert msh j UV_array[j]
for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
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
	
	maxOps.CollapseNodeTo $ 1 off
	clearSelection ()
	
max modify mode
select msh
skinMod = skin ()
addModifier msh skinMod
for i = 1 to BoneCount do
(  
	maxbone = BNArr[i]
	if i != BoneCount then 
		skinOps.addBone skinMod maxbone 0
	else
		skinOps.addBone skinMod maxbone 1
)
modPanel.setCurrentObject skinMod
for i = 1 to (VertexCount) do (
   w = Weight_Array[(VertID_Array[i])]
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


-- print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
gc()
fclose f
