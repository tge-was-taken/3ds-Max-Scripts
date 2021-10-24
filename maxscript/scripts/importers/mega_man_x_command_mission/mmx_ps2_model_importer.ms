
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

fn AlignOffset fstream alignment = (
	align = (alignment - (mod (ftell fstream) alignment as integer))
	if (align != alignment) then fseek fstream align #seek_cur
)

fn GetTriStrips TriStripFlagArray = (
	lastPosition = 1
	while (lastPosition != TriStripFlagArray.Count) do
	(
		print lastPosition
		if (TriStripFlagArray[lastPosition] == 0x8000) then
		(
			faceArray = #()
			x = 0
			f1 = 1
			f2 = 2
			clockWise = true
			lastPosition += 1
			do (
				x += 1
				clockWise = not clockWise
				f3 = x
				if (f1 != f2) AND (f2 != f3) AND (f3 != f1) then 
				(
					if (clockWise) then append faceArray [f1,f2,f3]
					else append faceArray [f1,f3,f2]
				)
				f1 = f2
				f2 = f3
			)
			while (TriStripFlagArray[lastPosition + x] != 0x8000)
			print faceArray
			lastPosition += x
		)
		else lastPosition += 1
		if (lastPosition > 1000) then lastPosition = TriStripFlagArray.Count
	)
)

fn ReadFaces VertCount FaceType = (
	Face_array=#()
	
	if FaceType == 1 do (
		StartDirection = 1
		x=0
		a=0
		b=1
		c=2
		
		f1 = a + 1
		f2 = b + 1  
		FaceDirection = StartDirection
		do (
			x+=1
			
			f3 = x
			FaceDirection *= -1
			if (f1!=f2)AND(f2!=f3)AND(f3!=f1) then (
				if FaceDirection > 0 then append Face_array [f1,f2,f3]
				else append Face_array [f1,f3,f2]
			)
			f1 = f2
			f2 = f3
		)
		while (x < (vertcount))
	)
	
	if FaceType == 0 do (
		
		a=0
		b=0
		c=0
		
		For x=1 to vertcount by 3 do (
			a=x
			b=x+1
			c=x+2
			append face_array [a,b,c]
		)
	)
	
	return Face_array
)

clearlistener()
fname = getOpenFileName \ 
caption:"Open Model" \
types:"Mega Man X Command Mission PS2 Model (*.dat)|*.dat" \
historyCategory:"MegaManXCommandMissionPS2 Object Presets"

f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = getFileNamePath fname

meshCount = readlong f
fseek f 0x4 #seek_cur
fileSize = readlong f -- not including header
fseek f 0x4 #seek_cur

for i = 1 to meshCount do
(
	meshName = ReadFixedString f 0xC
	meshOffset = readlong f
	fseek f 0x10 #seek_cur
	nextMeshOffset = ftell f
	
	fseek f meshOffset #seek_set
	vertexCount = readlong f
	
	print vertexCount
	
	vertexArray = #()
	triStripFlagArray = #()
	normalArray = #()
	uvArray = #()
	
	AlignOffset f 16
	for v = 1 to vertexCount do
	(
		vertexArray[v] = [(readshort f as float), (readshort f as float), (readshort f as float)]
		triStripFlagArray[v] = (readshort f #unsigned)
	)
	
	AlignOffset f 16
	for v = 1 to vertexCount do
	(
		uvArray[v] = [(readshort f as float) / 0xFFF, (readshort f as float) / 0xFFF, 1.0f]
	)
	
	AlignOffset f 16
	for v = 1 to vertexCount do
	(
		normalArray[v] = [(readshort f as float) / 0xFFF, (readshort f as float) / 0xFFF, (readshort f as float) / 0xFFF]
	)
	
	faceArray = ReadFaces vertexCount 1
	
	GetTriStrips triStripFlagArray
	
	msh = mesh vertices:vertexArray faces:faceArray
	
	fseek f nextMeshOffset #seek_set
)

/*
boneArrayOffset = readlong f
animationIndexInfoArray = readlong f
indexArrayOffset = readlong f
unknown1ArrayOffset = readlong f
boneCount = readshort f
animationCount = readshort f
unknown2ArrayOffset = readlong f
unknown3ArrayOffset = readlong f

fseek f boneArrayOffset #seek_set
boneArray = #()
for i = 1 to boneCount do
(
	parentBoneIndex = readshort f #signed
	rotX = readshort f as float / 0xFFFF
	rotY = readshort f as float / 0xFFFF
	rotZ = readshort f as float / 0xFFFF
	posX = readfloat f
	posY = readfloat f
	posZ = readfloat f
	
	tfm = (rotateXMatrix (radToDeg rotX)) * (rotateYMatrix (radToDeg rotY)) * (rotateZMatrix (radToDeg rotZ))
	tfm.row4 = [posX, posY, posZ]
		
	boneName = ("Bone"+i as string)

	if (getNodeByName boneName) != undefined do (append boneArray (getNodeByName boneName))	
	if (parentBoneIndex != -1) then ( tfm = tfm * boneArray[(parentBoneIndex+1)].objecttransform ) 
	
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
						  
	if (parentBoneIndex != -1) then newBone.parent = boneArray[(parentBoneIndex+1)]
	append boneArray newBone
)
*/



