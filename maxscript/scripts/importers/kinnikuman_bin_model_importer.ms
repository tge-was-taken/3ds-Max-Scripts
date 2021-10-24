
-- Kinnikuman model import script, made by TGE

-- set this to false if you don't want to spend ages waiting for the normals to import
importNormals = false

fn AlignOffset fstream relativeoffset alignment = (
	align = (alignment - (mod relativeoffset alignment as integer))
	if (align != alignment) then fseek fstream align #seek_cur
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
	local elements = #()
	
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

fn GetLinearStripArray VertCount = (
	local FaceArray = #()
	
	local WindCount = 0
	local WindClockwise = true
	local a = 1
	local b = 2
	do
	(
		WindCount += 1
		local c = WindCount -- linear part
		WindClockwise = not WindClockwise -- invert current wind direction
		if (a != b) AND (b != c) AND (c != a) then -- check if triangle isn't degenerate
		(
			if (WindClockwise) then append FaceArray [a,b,c]
			else append FaceArray [a,c,b]
		)
		a = b
		b = c
	)
	while (WindCount < VertCount)
	
	return FaceArray
)

clearlistener()
fname = getOpenFileName \ 
caption:"Open Model" \
types:"Kinnikuman Model (*.bin)|*.bin" \
historyCategory:"Kinnikuman Object Presets"

f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = getFileNamePath fname

fseek f 0x8 #seek_cur
objectCount = readlong f

fseek f 0x6C #seek_set
objectArrayOffset = readlong f

fseek f objectArrayOffset #seek_set

boneArray = #()

/*
faceArray = #()
vertexArray = #()
normalArray = #()
uvArray = #()
lastVertexCount = 0
*/

for i = 1 to objectCount do
(
	objectStart = ftell f
	
	objectSize = readlong f
	parent = readshort f
	unk2 = readshort f
	unk3 = readshort f
	index = readshort f
	unk4 = readlong f
	sx = readfloat f; sy = readfloat f; sz = readfloat f; dmy = readfloat f
	rx = readfloat f; ry = readfloat f; rz = readfloat f; dmy = readfloat f
	px = readfloat f; py = readfloat f; pz = readfloat f; dmy = readfloat f
	
	print("index = "+index as string)
	print("parent = "+parent as string)
	print("unk2 = "+unk2 as string)
	print("unk3 = "+unk3 as string)
	print("unk4 = "+unk4 as string)
	print("\n")
	
	/*
	--tfm = (rotateXMatrix (radToDeg rx)) * (rotateYMatrix (radToDeg ry)) * (rotateZMatrix (radToDeg rz))
	--tfm *= (scalematrix [sx, sy, sz])
	tfm = matrix3 1
	tfm.row4 = [px, py, pz]
	
	boneName = ("Bone"+i as string)
		
	if ((parent+1) != i) do (
	tfm = tfm * boneArray[parent+1].objecttransform
	 )	
	
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
						  
	if ((parent+1) != i) then newBone.parent = boneArray[parent+1]
	append boneArray newBone
	*/
	
	if (objectSize > 0x40) then
	(
		fseek f 0x20 #seek_cur
		vifDataSize = readshort f * 0x10 + 0x8
		unk4 = readshort f
		unk5 = readlong f
		
		vifDataStart = ftell f
		
		headerArray = #()
		
		faceArray = #()
		vertexArray = #()
		normalArray = #()
		uvArray = #()
		lastVertexCount = 0

		while (ftell f != (vifDataStart + vifDataSize)) do
		(
			VIFTag = VIFRead f
			case VIFTag.Command of
			(
				0x60: (
					case of
					(
						(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x0): ( -- 0x6C
							if (headerArray.Count == 0) then
							(
								for d = 1 to VIFTag.DataCount do (
									VIFData = [(readlong f), (readlong f), (readlong f), (readlong f)]
									append headerArray VIFData
								)
							)
							else 
							(
								loopCycle = 0
								
								for d = 1 to VIFTag.DataCount do (
									VIFData = VIFParse f VIFTag
									
									loopCycle += 1
									if (loopCycle > 3) then loopCycle = 1
									
									case loopCycle of
									(
										1: (
											--print ("loopCycle 1 element 4: " + VIFData[4] as string)
											append vertexArray [VIFData[1], VIFData[2], VIFData[3]]
										)
										2: (
											append normalArray [VIFData[1], VIFData[2], VIFData[3]]
										)
										3: (
											append uvArray [VIFData[1], VIFData[2], VIFData[3]]
										)
									)
								)
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
						(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x3): ( -- 0x17
							packetVertexCount = vertexArray.Count - lastVertexCount
							packetFaceArray = GetLinearStripArray packetVertexCount 
							
							for d = 1 to packetFaceArray.Count do
							(
								append faceArray [packetFaceArray[d][1] + lastVertexCount, packetFaceArray[d][2] + lastVertexCount, packetFaceArray[d][3] + lastVertexCount]
							)
							
							lastVertexCount = vertexArray.Count
							headerArray = #() 
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
		
		msh = mesh vertices:vertexArray faces:faceArray
		msh.numTVerts = vertexArray.count
		buildTVFaces msh
		for j = 1 to uvArray.count do setTVert msh j uvArray[j]
		for j = 1 to faceArray.count do setTVFace msh j faceArray[j]
		for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
			
		if ((normalArray.count != 0) AND (importNormals == true)) then (
			max modify mode
			select msh
			addmodifier msh (Edit_Normals ()) ui:off
			msh.Edit_Normals.MakeExplicit selection:#{1..normalArray.count}
			EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
			EN_setNormal = msh.Edit_Normals.SetNormal
			normID = #{}

			for v = 1 to normalArray.count do(
				free normID
				EN_convertVS #{v} &normID
				for id in normID do EN_setNormal id normalArray[v]
			)
		)
		maxOps.CollapseNodeTo msh 1 true -- Collapse the Edit Normals modifier
	)
	
	fseek f (objectStart + objectSize) #seek_set
)

/*
msh = mesh vertices:vertexArray faces:faceArray
msh.numTVerts = vertexArray.count
buildTVFaces msh
for j = 1 to uvArray.count do setTVert msh j uvArray[j]
for j = 1 to faceArray.count do setTVFace msh j faceArray[j]
for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
	
if ((normalArray.count != 0) AND (importNormals == true)) then (
	max modify mode
	select msh
	addmodifier msh (Edit_Normals ()) ui:off
	msh.Edit_Normals.MakeExplicit selection:#{1..normalArray.count}
	EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
	EN_setNormal = msh.Edit_Normals.SetNormal
	normID = #{}

	for v = 1 to normalArray.count do(
		free normID
		EN_convertVS #{v} &normID
		for id in normID do EN_setNormal id normalArray[v]
	)
)
maxOps.CollapseNodeTo msh 1 true -- Collapse the Edit Normals modifier
*/

