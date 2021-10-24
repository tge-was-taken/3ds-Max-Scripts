if (heapSize < 200000) then
        heapSize = 2000000 -- allow ~ 40 MB instead of just 7.5 MB. Prevents "Runtime Error: Out of scripter memory"

fn floatSwap2 f = (
	i = bit.floatAsInt f
	h = bit.intashex i
	while h.count < 8 do h = "0" + h
	
	s = (substring h 7 2) + (substring h 5 2) + (substring h 3 2) + (substring h 1 2)
	bit.intAsFloat (bit.hexasint s)
)	

fn readBEshort fstream = (
	short = readshort fstream #unsigned
	short = bit.swapBytes short 1 2
	return short
)

fn readBEshortS fstream = (
	short = readshort fstream #signed
	short = bit.swapBytes short 1 2
	return short
)

fn readBElong fstream = (bit.swapBytes (bit.swapBytes (readlong fstream #unsigned) 1 4) 2 3)

fn ReadBEfloat fstream = (
return floatSwap2(readfloat fstream)
)

fn ReadFixedString bstream fixedLen = (
    local str = ""
    for i = 1 to fixedLen do
    (
        str += bit.intAsChar (ReadByte bstream #unsigned)
    )
    str
)

rollout MadWorldMDBImport "MadWorld MDB model importer" width:250 height:225
(
	button btnImport "Import Model" pos:[12,8] width:225 height:40
	label lblDisclaimer1 "This script was written by TGE.\nMost models should import but in case they fail to import correctly, contact me over at the VG Resource and I'll see what I can do to sort it out. \nHave fun~!" pos:[12,50] width:230 height:80
	label lblDisclaimer2 "Notes: Be sure to place wiimgt.exe in your 3ds Max root directory, otherwise the textures will not import!\n" pos:[12,150] width:230 height:80
	
on btnImport pressed do (

clearlistener()
fname = getOpenFileName \ 
caption:"Open File" \
types:"Model Binary(*.mdb)|*.mdb" \
historyCategory:"MadWorldMDB Object Presets"

-- Implement .DAT stuff here--

if fname != undefined do (
f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = GetFilenamepath fname
maxRootDir = getdir #maxroot
fseek f 0x0 #seek_end
FileEnd = ftell f
fseek f 0x0 #seek_set

FileIdentifier = readfixedstring f 2
if FileIdentifier != "JK" then throw "Not a proper MDB file!"
VertFlagUnk = readBEshort f
VertexCount = readBElong f
VertexOffset = readBElong f
NormalsCount = readBElong f
NormalsOffset = readBElong f
UVCount = readBElong f
UVOffset = readBElong f
Unknown = readBElong f
Unknown = readBElong f	
BoneWeightCount = readBElong f
BoneWeightOffset = readBElong f
BoneCount = readBElong f
BoneParentsOffset = readBElong f
BoneLocalOffset = readBElong f
BoneWorldOffset = readBElong f
TextureCount = readBElong f
TextureChunkOffset = readBElong f
FaceCount = readBElong f
FaceIndexStartOffset = readBElong f
FaceFlagUnk = readBEShort f
FaceUVSizeFlag = readBEShort f
Unknown = readBElong f
IndexChunk1Offset = readBELong f
IndexChunk2Offset = readBElong f
BoneIDsOffset = readBElong f
IndexChunk4Offset = readBElong f
SubMeshCount = ReadBEShort f
UnknownConstant = readBEShort f
Unknown = ReadBElong f
Unknown = readBElong f
Unknown = readBElong f
UnkFlag = readBElong f
UnkFlag = readBElong f
FaceStride = readBElong f 

Vert_Array = #()
Normal_Array = #()
NormalIndex_Array = #()
Face_Array = #()
UV_Array = #()
UV_Array2 = #()
UVIndex_Array = #()
Bone_Array = #()
BoneInfo_Array = #()
Mat_Array = #()
MatID_Array = #()
Dummy_Array = #()
BoneParent_Array = #()
Weight_Array = #()
WeightID_Array = #()

struct BoneDataStruct (
	BoneID, BoneParent
)

struct MatData (
	MatName, TexID
)

struct weight_data
(
	boneids,weights
)

fseek f VertexOffset #seek_set
VertexStride = ((NormalsOffset - VertexOffset)/VertexCount)

case of (
	(VertexStride > 7 AND VertexStride < 15):(
	for x = 1 to VertexCount do ( -- Based off GNO script by ItsEasyActually, doesn't work correctly??
		vx = (ReadBEShortS f as float) /8192
		If vx > 7 Do (
			vx = vx - 8
		)
		If vx < -1 Do (
			vx= vx + 8
		)
		vy = (ReadBEShortS f as float) /8192
		If vy > 7 Do (
			vy = vy - 8
		)
		If vy < -1 Do (
			vy = vy + 8
		)
		vz = (ReadBEShortS f as float) /8192
		If vz > 7 Do (
			vz = vz - 8
		)
		If vz < -1 Do (
			vz = vz + 8
		)
		WeightID = readBEshort f +1
		WeightID_Array[x]=WeightID
		append Vert_Array [(vx*10),(-vz*10),(vy*10)]
	)
	)
	(VertexStride > 15):(
	for x = 1 to VertexCount do (
		vx = readBEfloat f
		vy = readBEfloat f
		vz = readBEfloat f
		WeightID = readBEshort f +1
		fseek f 0x2 #seek_cur
		WeightID_Array[x]=WeightID
		append Vert_Array [(vx*10),(-vz*10),(vy*10)]
	)
	)
	default:throw "Failed!"
)

fseek f UVOffset #seek_set

for x = 1 to UVCount do (
	tu = ((readBEshort f as float)/16384)
	tv= (((readBEshort f as float) * -1)/16384)
	append UV_Array [tu,tv,0]
)
uvmsh = mesh Vertices:UV_Array Faces:Face_Array
uvmsh.name = "uvmsh"
bbMax = uvmsh.max
if bbMax.x < 0.935 then (
	for x = 1 to UVCount do (
		uv = transmatrix UV_Array[x]
		tfm = (matrix3 [2,0,0] [0,2,0] [0,0,2] [0,0,0])
		uv2 = (uv * tfm)
		append UV_Array2 uv2.row4
	)
)
delete (getnodebyname "uvmsh" exact:true)
	
fseek f BoneParentsOffset #seek_set
for x = 1 to BoneCount do (
	BoneParent = readbyte f + 1
	BoneParent_Array[x]=BoneParent
)

fseek f BoneIDsOffset #seek_set
for x = 1 to BoneCount do (
	BoneID = readbyte f + 1
	BoneParent = BoneParent_Array[x]
	append BoneInfo_Array (BoneDataStruct BoneID:BoneID BoneParent:BoneParent)
)

fseek f BoneWeightOffset #seek_set
for x = 1 to BoneWeightCount do (
	Bone1 = readbyte f #unsigned
	Weight1 = readbyte f #unsigned
	Bone2 = readbyte f #unsigned
	Weight2 = readbyte f #unsigned
	Bone3 = readbyte f #unsigned
	Weight3 = readbyte f #unsigned
	Bone4 = readbyte f #unsigned
	Weight4 = readbyte f #unsigned
	
	w = (weight_data boneids:#() weights:#())
	maxweight = 0
	if(weight1 != 255) then
	   maxweight = maxweight + weight1
	if(weight2 != 255) then
	   maxweight = maxweight + weight2
	if(weight3 != 255) then
	   maxweight = maxweight + weight3
	if(weight4 != 255) then
	   maxweight = maxweight + weight4


	if(maxweight != 0) then (
		  if(weight1 != 255) then (
			 w1 = weight1 as float
			 append w.boneids (bone1 + 1)
			 append w.weights (w1/100.0)
		  )
		  if(weight2 != 255) then (
			 w2 = weight2 as float
			 append w.boneids (bone2 + 1)
			 append w.weights (w2/100.0)
		  )
		  if(weight3 != 255) then (
			 w3 = weight3 as float
			 append w.boneids (bone3 + 1)
			 append w.weights (w3/100.0)
		  )
		  if(weight4 != 255) then (
			 w4 = weight4 as float
			 append w.boneids (bone4 + 1)
			append w.weights (w4/100.0)
		  )      
	   )
	append Weight_Array w	
)

fseek f BoneWorldOffset #seek_set
for x = 1 to BoneCount do (
	BoneID = BoneInfo_Array[x].BoneID
	BoneParent = BoneInfo_Array[x].BoneParent
	px = readBEfloat f
	py = readBEfloat f
	pz = readBEfloat f
	tfm = (matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0])
	tfm.row4 = [px,-pz,py]*10
	newBone = bonesys.createbone	\
				  tfm.row4	\
				  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
				  (normalize tfm.row3)
			newBone.name = ("Bone"+(x as string))
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
	append Bone_Array newBone
)


fseek f FaceIndexStartOffset #seek_set
ObjectID = 0
LastIndex = 0
for o = 1 to SubMeshCount do (
ObjectID += 1
start = ftell f
NextSM = readBElong f
TexID = readbyte f
TexID2 = readbyte f
if TexID == 0xFF then TexID = 0
FaceFlag1 = readBEshort f
FaceFlag2 = readBEshort f
FaceFlag3 = readBEshort f
FaceFlag4 = readBEshort f
FaceFlag5 = readBEshort f
FaceFlag6 = readBEshort f
FaceFlag7 = readBEshort f
FaceBufferSize = readBElong f
FaceFlag8 = readBElong f
fseek f 0x4 #seek_cur
MaterialName = readstring f
	
if NextSM != 0 then
FaceStart = ((NextSM - FaceBufferSize) + start) - 0x1
if NextSM == 0 then
FaceStart = (FileEnd - FaceBufferSize) - 0x1

fseek f FaceStart #seek_set
FaceType = readBEshort f
case of (
	((FaceType2==0x48)):(
	FaceCount = readBElong f
	)
	default:(
	FaceCount = readBEshort f
	)
)
append Mat_Array (MatData MatName:MaterialName TexID:TexID)
case of (
	((FaceStride == 0xC)OR(FaceStride == 0xA000F)):(
	for x = 1 to FaceCount / 3 do (
	f1 = (ReadBEshort f) + 1
	f2 = (ReadBEshort f) + 1
	f3 = (ReadBEshort f) + 1
	f4 = (ReadBEshort f) + 1
	f5 = (ReadBEshort f) + 1
	f6 = (ReadBEshort f) + 1
	f7 = (ReadBEshort f) + 1
	f8 = (ReadBEshort f) + 1
	f9 = (ReadBEshort f) + 1
	fa = (ReadBEshort f) + 1
	fb = (ReadBEshort f) + 1
	fc = (ReadBEShort f) + 1
	MatID_Array[(x+LastIndex)]=ObjectID
	append Face_Array [f9,f5,f1]
	append NormalIndex_Array [fa,f6,f2]
	append Dummy_Array [fb,f7,f3]
	append UVIndex_Array [fc,f8,f4]
	)
	)
	((FaceStride == 0x1C)OR(FaceStride == 0xA010D)OR(FaceStride == 0x10C)OR((FaceStride == 0x100)AND(FaceFlag7 == 0x2))):(
	for x = 1 to FaceCount / 3 do (
	fc = (Readbyte f) + 1
	f1 = (ReadBEshort f) + 1
	f2 = (ReadBEshort f) + 1
	f3 = (ReadBEshort f) + 1
	f4 = (ReadBEshort f) + 1
	fc = (Readbyte f) + 1
	f5 = (ReadBEshort f) + 1
	f6 = (ReadBEshort f) + 1
	f7 = (ReadBEshort f) + 1
	f8 = (ReadBEshort f) + 1
	fc = (Readbyte f) + 1
	f9 = (ReadBEshort f) + 1
	fa = (ReadBEshort f) + 1
	fb = (ReadBEshort f) + 1
	fd = (ReadBEShort f) + 1
	MatID_Array[(x+LastIndex)]=ObjectID
	append Face_Array [f9,f5,f1]
	append NormalIndex_Array [fa,f5,f2]
	append Dummy_Array [fb,f7,f3]
	append UVIndex_Array [fd,f8,f4]
	)
	)
	(FaceStride == 0x0):(
	for x = 1 to FaceCount / 3 do (
	f1 = (ReadBEshort f) + 1
	n1 = (ReadBEshort f) + 1
	x1 = (ReadBEshort f) + 1
	f2 = (ReadBEshort f) + 1
	n2 = (ReadBEshort f) + 1
	x2 = (ReadBEshort f) + 1   
	f3 = (ReadBEshort f) + 1
	n3 = (ReadBEshort f) + 1
	x3 = (ReadBEshort f) + 1
	MatID_Array[(x+LastIndex)]=ObjectID
	append Face_Array [f3,f2,f1]
	append NormalIndex_Array [n3,n2,n1]
	append UVIndex_Array [x3,x2,x1]
	)
	)
	(FaceStride == 0x100):(
	for x = 1 to FaceCount / 3 do (
	fb = readbyte f + 1
	f1 = (ReadBEshort f) + 1
	n1 = (ReadBEshort f) + 1
	x1 = (ReadBEshort f) + 1
	fb = readbyte f + 1
	f2 = (ReadBEshort f) + 1
	n2 = (ReadBEshort f) + 1
	x2 = (ReadBEshort f) + 1  
	fb = readbyte f + 1		
	f3 = (ReadBEshort f) + 1
	n3 = (ReadBEshort f) + 1
	x3 = (ReadBEshort f) + 1
	MatID_Array[(x+LastIndex)]=ObjectID
	append Face_Array [f3,f2,f1]
	append NormalIndex_Array [n3,n2,n1]
	append UVIndex_Array [x3,x2,x1]
	)
	)
	default:(throw ("Unknown FaceStride "+FaceStride as string))
)
LastIndex += FaceCount/3
if NextSM != 0 then (
fseek f (start+NextSM) #seek_set
)
else exit
)
msh = mesh vertices:Vert_Array faces:Face_Array
msh.numTVerts = UV_Array.count
msh.name = FileName
msh.backfacecull = on
buildTVFaces msh
msh.material = multimaterial numsubs:ObjectID
if UV_Array2.count != 0 then for j = 1 to UV_array.count do setTVert msh j UV_array2[j]
if UV_Array2.count == 0 then for j = 1 to UV_array.count do setTVert msh j UV_array[j]
for j = 1 to UVIndex_array.count do setTVFace msh j UVIndex_array[j]
for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
for j = 1 to msh.numfaces do setFaceMatID msh j (MatID_Array[j] as integer)
texCnv = "cp"+" '"+(filepath as string)+(filename as string)+".tpl"+"' '"+(filepath as string)+(filename as string)+".png'"
texCnv_AB = "cp"+" '"+(filepath as string)+(filename as string)+"_AB"+".tpl"+"' '"+(filepath as string)+(filename as string)+"_AB"+".png'"
ShellLaunch (maxRootDir+"wimgt.exe") texCnv
ShellLaunch (maxRootDir+"wimgt.exe") texCnv_AB
sleep 0.25 -- fixes textures not appearing bug
for j = 1 to msh.material.count do (
if doesFileExist (filepath +(filename +".mm"+(Mat_Array[j].TexID as string)+".png")) then (
if Mat_Array[j].TexID != 0 then  ( tm = Bitmaptexture filename:(filepath +(filename +".mm"+(Mat_Array[j].TexID as string)+".png"))) 
else ( tm = Bitmaptexture filename:(filepath+filename+".png"))) 
else ( tm = Bitmaptexture filename:(filepath+filename+".png"))
tm.alphasource = 0
tm.monoOutput = 1
msh.material.materialList[j].name = Mat_Array[j].MatName
msh.material.materialList[j].diffuseMap = tm
msh.material.materialList[j].opacityMap = tm
msh.material.materialList[j].opacityMapEnable = false
msh.material.materialList[j].showInViewport = true
filename = GetFilenameFile fname
filepath = GetFilenamepath fname
)

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
for i = 1 to (VertexCount) do (
   w = Weight_Array[(WeightID_Array[i])]
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



	
--end of file functions
gc()
fclose f
)
)
)

CreateDialog MadWorldMDBImport
