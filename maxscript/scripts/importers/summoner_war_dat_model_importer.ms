
global importNormals = true

fn ReadFixedString bstream fixedLen =
(
   local str = ""
   for i = 1 to fixedLen do
   (
      str0 = ReadByte bstream #unsigned
      str+= bit.intAsChar str0
   )
   str
)

clearlistener()
fname = getOpenFileName \ 
caption:"Open Model" \
types:"Summoners War Model (*.dat)|*.dat" \
historyCategory:"SWM Object Presets"

st = timestamp() --get start time in milliseconds

f = fopen fname "rb"
fileName = GetFilenameFile fname
filePath = getFileNamePath fname

fseek f 0 #seek_end
fileEnd = ftell f
fseek f 0 #seek_set

headerSize = readlong f

fseek f headerSize #seek_cur

PMMSize = readlong f
PMMTag = readfixedstring f 4
unk1 = readshort f
faceCount = readshort f #unsigned / 3
vertCount = readshort f #unsigned
unk2 = readlong f
vertScale = readshort f #unsigned
fseek f 0x37 #seek_cur

vertArray = #()
for v = 1 to vertCount do
(
	vx = readlong f as float / vertScale
	vy = readlong f as float / vertScale 
	vz = readlong f as float / vertScale
	append vertArray [vx,-vz,vy]
)

normArray = #()
for v = 1 to vertCount do
(
	nx = readbyte f as float / 0x7F
	ny = readbyte f as float / 0x7F
	nz = readbyte f as float / 0x7F
	append normArray [nx,-nz,ny]
)

uvArray = #()
for v = 1 to vertCount do
(
	tu = readlong f as float / 0xFFFF
	tv = readlong f as float / 0xFFFF 
	append uvArray [tu,tv,0]
)

faceArray = #()
for fc = 1 to faceCount do
(
	f1 = readshort f #unsigned + 1
	f2 = readshort f #unsigned + 1
	f3 = readshort f #unsigned + 1
	append faceArray [f1,f2,f3]
)

/*
boneIDArray = #()
for v = 1 to vertCount do append boneIDArray (readbyte f +1)

PLMSize = readlong f
PLMStart = ftell f
PLMTag = readfixedstring f 4
unk3 = readshort f
fseek f 0x14 #seek_cur
for i = 1 to unk3 do fseek f 0x7 #seek_cur
boneCount = readbyte f #unsigned
fseek f 0x20 #seek_cur

boneArray = #()
for b = 1 to boneCount do
(
	boneFlag = readbyte f
	boneID = readbyte f
	parentID = readbyte f
	v1 = readlong f as float / 0xFFFF
	v2 = readlong f as float / 0xFFFF
	v3 = readlong f as float / 0xFFFF
	v4 = readlong f as float / 0xFFFF
	v5 = readlong f as float / 0xFFFF 
	v6 = readlong f as float / 0xFFFF 
	v7 = readlong f as float / 0xFFFF 
	v8 = readlong f as float / 0xFFFF 
	v9 = readlong f as float / 0xFFFF 
	
	
	format "v1: %\nv2: %\nv3: %\n\nv4: %\nv5: %\nv6: %\n\nv7: %\nv8: %\nv9: %\n\n" v1 v2 v3 v4 v5 v6 v7 v8 v9
	
	tfm = matrix3 1
	--tfm = quat v1 v2 v3 1 as matrix3
	tfm *= (scalematrix [v7,v8,v9])
	tfm.row4 = [v4,v5,v6]
	
	boneName = ("Bone"+(b as string))
	
	if (getNodeByName boneName) != undefined do (append boneArray (getNodeByName boneName))
	if (parentID != -1) then (tfm = tfm * boneArray[parentID+1].objecttransform)
	
	newBone = bonesys.createbone	\
					  tfm.row4	\
					  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
					  (normalize tfm.row3)
				newBone.name = boneName
				newBone.width  = 0.01
				newBone.height = 0.01
				newBone.transform = tfm
				newBone.setBoneEnable false 0
				newBone.wirecolor = yellow
				newbone.showlinks = true
				newBone.pos.controller      = TCB_position ()
				newBone.rotation.controller = TCB_rotation ()
						  
	if (parentID != -1) then newBone.parent = boneArray[(parentID+1)]
	append boneArray newBone
	
)
*/

fseek f (PLMStart + PLMSize) #seek_set
while (not (ftell f >= fileEnd)) do
(
	elementID = readlong f
	textureSize = readlong f
	pngData = #()
	pngName = (filepath + fileName + "_textures" + "\\" + fileName + "_" + elementID as string + ".png")
	makeDir (filepath + fileName + "_textures" + "\\")
	if (textureSize != 0) then
	(
		for i = 1 to textureSize do pngData[i] = (readbyte f)
		png = createfile pngName
		close png
		png = fopen pngName "wb"
		for i = 1 to textureSize do writebyte png pngData[i]
		fclose png
	)
)

msh = mesh vertices:vertArray faces:faceArray
msh.name = filename
msh.numTVerts = vertArray.count
buildTVFaces msh
for j = 1 to uvArray.count do setTVert msh j uvArray[j]
for j = 1 to faceArray.count do setTVFace msh j faceArray[j]
for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
for j = 1 to msh.numfaces do setFaceMatID msh j 1
for j = 1 to normArray.Count do setNormal msh j normArray[j]
	
msh.material = Standard()
tm = Bitmaptexture filename:(filepath + fileName + "_textures" + "\\" + fileName + "_" + 1 as string + ".png")
msh.material.diffuseMap = tm
msh.material.ShowInViewport = true
gc()
fseek f fileEnd #seek_set
fclose f