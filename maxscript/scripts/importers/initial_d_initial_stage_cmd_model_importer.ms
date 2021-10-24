
-- Initial D Special Stage model import script, made by TGE

-- set this to false if you don't want to spend ages waiting for the normals to import
importNormals = false

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

fn AlignOffset fstream relativeoffset alignment = (
	align = (alignment - (mod relativeoffset alignment as integer))
	align = fseek fstream align #seek_cur
	return align
)

fn VIFRead fstream = (
	
	struct VIFTag (
		MemAddress,
		Flag,
		DataCount,
		Command,
		ElementCount,
		ElementFormat
	)
	
	MemAddress = readbyte fstream #unsigned
	Flag = readbyte fstream #unsigned
	DataCount = readbyte fstream #unsigned
	CommandBits = readbyte fstream #unsigned
	FormatBits = (bit.and CommandBits 15)
	Command = (bit.and CommandBits 240)
	ElementCount = (bit.shift FormatBits -2) 
	ElementFormat = (bit.and FormatBits 3) 
	
	VIFTag = (VIFTag \
		MemAddress:MemAddress \
		Flag:Flag \
		DataCount:DataCount \
		Command:Command \
		ElementCount:ElementCount \
		ElementFormat:ElementFormat \
	)
	
return VIFTag
)

fn VIFParse fstream VIFTag = (
	elements = #()
	
	case (VIFTag.Flag) of ( -- I'm not entirely sure what the right settings are
		0x40:
			Sign = (#unsigned)
		0x80:
			Sign = (#signed)
		0xC0:
			Sign = (#unsigned)
	)
	
	case (VIFTag.Command) of (
		0x60: ( -- Transfer data to GIF (VIF1) & Wait for end of microprogram
				for i = 1 to (VIFTag.ElementCount + 1) do (
					case (VIFTag.ElementFormat) of (
							0x0:
								append elements (ReadFloat fstream) -- floats can't be unsigned in Max
							0x1:
								append elements (ReadShort fstream Sign)
							0x2:
								append elements (ReadByte fstream Sign)
							0x3:
								append elements (ReadShort fstream Sign) -- rgb5a1 values (16-bit)
					)
				)
				
				case (VIFTag.ElementCount) of (
					0x0: return elements[1]
					0x1: return [elements[1], elements[2], 0]
					0x2: return [elements[1], elements[2], elements[3]]
					0x3: return [elements[1], elements[2], elements[3], elements[4]]
					default: return elements
				)
				
		)
	)
)

/*
fn ParseStrips StripFlagArray = (
	
	faceArray = #()
	
	vIdx = 0
	baseIndex = 0
	fc = 0
	
	while (fc < StripFlagArray.Count) do
	(
		print ("vidx = "+vIdx as string)
		f1 = 1 + baseIndex
		f2 = 2 + baseIndex
		f3 = 0 + baseIndex
		vIdx += 2
		do (
			vIdx += 1
			f3 += 1
			fc += 1
			
			if (StripFlagArray[vIdx] == 0x3) then FaceDirection = -1
			if (StripFlagArray[vIdx] == 0x7) then FaceDirection = 1
			
			if (f1!=f2)AND(f2!=f3)AND(f3!=f1) then (
				if FaceDirection > 0 then append faceArray [f1,f2,f3]
				if FaceDirection < 0 then append faceArray [f1,f3,f2]
			)
			f1 = f2
			f2 = f3
		)
		while (StripFlagArray[vIdx+1] != 0x8000 AND (fc < StripFlagArray.Count))
		
		print "strip done"
		
		--if (faceArray.Count != 0) then baseIndex = faceArray[faceArray.Count][1] 
	)
		
	return faceArray
)
*/

-- function by sleepyzay, thanks :)
fn ReadFaces VertCount FaceType = (
	Face_array=#()
	
	if FaceType == 1 do (
		StartDirection = 1
		x=2
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
types:"Initial D Special Stage Model (*.CMD)|*.CMD" \
historyCategory:"Kinnikuman Object Presets"

f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = getFileNamePath fname

fseek f 0 #seek_end
FileEnd = ftell f
fseek f 0 #seek_set

fseek f 0x8 #seek_cur
unknown1 = readlong f
unknown2 = readlong f
fseek f 0x4 #seek_cur
nodeCount = readlong f
meshCount = readlong f
fseek f 0x4 #seek_cur
nodeDataStart = readlong f 
nodeDataStart2 = readlong f
meshDataStart = readlong f
fseek f 0x24 #seek_cur

fseek f nodeDataStart #seek_set
boneArray = #()
for i = 1 to nodeCount do
(
	nodeName = ReadFixedString f 0x10
	nodeMatrix = matrix3 \
		[(readfloat f), (readfloat f), (readfloat f), (readfloat f)] \
		[(readfloat f), (readfloat f), (readfloat f), (readfloat f)] \
		[(readfloat f), (readfloat f), (readfloat f), (readfloat f)] \
		[(readfloat f), (readfloat f), (readfloat f), (readfloat f)] 
	
	newBone = bonesys.createbone	\
		nodeMatrix.row4	\
		(nodeMatrix.row4 + 0.01 * (normalize nodeMatrix.row1)) \
		(normalize nodeMatrix.row3)
	newBone.name = nodeName
	newBone.width  = 0.01
	newBone.height = 0.01
	newBone.transform = nodeMatrix
	newBone.setBoneEnable false 0
	newBone.wirecolor = yellow
	newbone.showlinks = true
	newBone.pos.controller      = TCB_position ()
	newBone.rotation.controller = TCB_rotation ()
	
	append boneArray newBone
)

objectCounter = 0
fseek f meshDataStart #seek_set
for i = 1 to meshCount do
(
	vifDataStart = readlong f
	vifDataSize = readlong f * 0x10
	fseek f 0x8 #seek_cur
	unknown3 = readlong f
	meshColor = readlong f
	unknown4 = readlong f -- vertCount??
	unknown5 = readlong f -- faceCount??
	
	nextMeshStart = ftell f
	vifDataEnd = vifDataStart + vifDataSize
	
	fseek f vifDataStart #seek_set
	
	vertexArray = #()
	vertexAttributeArray = #()
	normalArray = #()
	colorArray = #()
	faceArray = #()
	
	verticesRead = false
	normalsRead = false
	uvsRead = false
	
	lastVertexCount = 0
	while (ftell f != (vifDataEnd)) do
	(
		VIFTag = VIFRead f
		--print ("offset: " + bit.intashex(ftell f))
		--print VIFTag
		--format "\n"
		case VIFTag.Command of
		(
			0x60: (
				case of
				(
					(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x0): ( -- 0x6C
						if (not verticesRead) then 
						(
							for d = 1 to VIFTag.DataCount do (
								VIFData = [(readfloat f), (readfloat f), (readfloat f), (readlong f)]
								
								append vertexArray [VIFData[1], VIFData[2], VIFData[3]]
								append vertexAttributeArray VIFData[4]
							)
							verticesRead = true
						)
					)
					(VIFTag.ElementCount == 0x2 AND VIFTag.ElementFormat == 0x0): ( -- 0x68
						if (not normalsRead) then
						(
							for d = 1 to VIFTag.DataCount do (
								VIFData = VIFParse f VIFTag
								
								append normalArray [VIFData[1], VIFData[2], VIFData[3]]
							)
							normalsRead = true
						)
					)
					default: (
						VIFParse f VIFTag
					)
				)
			)
			0x10: (
				case of
				(
					(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x0): ( -- 0x14
						vertexCount = vertexArray.Count - lastVertexCount
						--smFaceArray = ParseStrips vertexAttributeArray
						smFaceArray = ReadFaces vertexArray.Count 1
						
						print smFaceArray
						
						for d = 1 to smFaceArray.Count do
						(
							append faceArray [smFaceArray[d][1] + lastVertexCount, smFaceArray[d][2] + lastVertexCount, smFaceArray[d][3] + lastVertexCount]
						)
						
						objectCounter += 1
						print ("end object " + objectCounter as string + " at offset " + (bit.intashex(ftell f)))
						msh = mesh vertices:vertexArray faces:smFaceArray
						
						--lastVertexCount = vertexArray.Count
						vertexArray = #()
						vertexAttributeArray = #()
						normalArray = #()
						colorArray = #()
						faceArray = #()
						
						verticesRead = false
						normalsRead = false
						uvsRead = false
					)
					default: (
						VIFParse f VIFTag
					)
				)
			)
			default: (
				VIFParse f VIFTag
			)
		)
	)
	
	fseek f nextMeshStart #seek_set
)

gc()
fclose f
