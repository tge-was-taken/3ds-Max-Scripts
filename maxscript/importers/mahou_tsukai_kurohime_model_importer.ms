
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

clearlistener()
fname = getOpenFileName \ 
caption:"Open Model" \
types:"Mahou Tsukai Kurohime Model (*.*)|*.*" \
historyCategory:"MahouTsukaiKurohime Object Presets"

f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = getFileNamePath fname

fseek f 0 #seek_end
FileEnd = ftell f
fseek f 0 #seek_set
print (("File Size = ")+(bit.intashex(fileEnd) as string))

offsetTable1Array = #()
boneArray = #()
modelAttributeArray = #()
objectBoneMapArray = #()
objectOffsetArray = #()
vertArray = #()
faceArray = #()

for x = 1 to 12 do -- Offset Table
(
	offsetTable1Array[x] = (readlong f #unsigned)
	if ((x == 2) AND (offsetTable1Array[1] != 0x30 AND offsetTable1Array[2] != 0x50)) then (messagebox "This is not a model file."; throw "Not a model")
)

fseek f offsetTable1Array[1] #seek_set -- Model info
for x = 1 to 16 do
(
	modelAttributeArray[x] = (readshort f #unsigned)
)

fseek f offsetTable1Array[2] #seek_set -- Bones
boneCount = readlong f -- same as modelAttributeArray[1]
for x = 1 to boneCount do 
(
	boneParent = readlong f
	sx = readfloat f; sy = readfloat f; sz = readfloat f
	rx = readfloat f; ry = readfloat f; rz = readfloat f
	px = readfloat f; py = readfloat f; pz = readfloat f
	
	tfm = (rotateXMatrix (radToDeg rx)) * (rotateYMatrix (radToDeg ry)) * (rotateZMatrix (radToDeg rz))
	tfm *= (scalematrix [sx, sy, sz])
	tfm.row4 = [px, py, pz]
		
	boneName = ("Bone"+x as string)

	if (getNodeByName boneName) != undefined do (append boneArray (getNodeByName boneName))	
	if (boneParent != 255) then ( tfm = tfm * boneArray[boneParent+1].objecttransform ) 
	
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
						  
	if (boneParent != 255) then newBone.parent = boneArray[(boneParent+1)]
	append boneArray newBone
)

fseek f offsetTable1Array[3] #seek_set -- Bonemap
for x = 1 to modelAttributeArray[2] do -- Object count
(
	boneMapOffset = readlong f
	nextBoneMapOffset = ftell f
	
	fseek f (offsetTable1Array[3] + boneMapOffset) #seek_set
	boneMapCount = readbyte f
	
	boneMapArray = #()
	for b = 1 to boneMapCount do
	(
		boneMapArray[b] = (readbyte f)
	)
	objectBoneMapArray[x] = boneMapArray
	
	fseek f nextBoneMapOffset #seek_set
)

fseek f offsetTable1Array[4] #seek_set -- Not quite sure what this is yet, surely related to the bonemap/objects
objectCount = readlong f

vertexCount = 0 
fseek f offsetTable1Array[5] #seek_set -- Object offset table
for x = 1 to objectCount do -- Object count
(
	objectOffset = readlong f
	if (objectOffset == 0x00) then continue
	lastPos = ftell f
	
	print ("Object #"+ x as string+" offset 0x"+(bit.intAsHex(offsetTable1Array[5] + objectOffset)) as string)
		
	fseek f (offsetTable1Array[5] + objectOffset) #seek_set
	
	fseek f 0x34 #seek_cur
	unk1 = readshort f
	vifDataSize = readshort f
	fseek f 0xC #seek_cur
		
	vifDataEnd = ftell f + vifDataSize
	print ("VIF data end = "+vifDataEnd as string)
	
	vertexArray = #()
	normalArray = #()
	uvArray = #()
	
	while (not ftell f >= vifDataEnd) do
	(
		VIFTag = VIFRead f
		print VIFTag
		
		case VIFTag.Command of
		(
			0x60: (
				case of
				(
					(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x0): ( -- 0x6C
						vifPacketDataEnd = ftell f + ((VIFTag.DataCount * 4) * 4)
						
						while (not ftell f >= vifPacketDataEnd) do
						(
							arrayStart = ftell f
							arrayType = readbyte f
							arraySize = bit.shift (readshort f) -4
							
							arrayEnd = arrayStart + arraySize
							
							unk1 = readbyte f -- similar value to size???
							elementCount = readlong f
							unk2 = readlong f -- some count
							unk3 = readlong f -- some count, vertex count?
							
							format "Array at % type: % size: % unk1: % elementCount: % unk2: % unk3 %\n" (bit.intashex(arrayStart)) arrayType arraySize unk1 elementCount unk2 unk3
								
							case arrayType of
							(
								(-1): (
									-- do nothing
								)
								default:(
									fseek f arrayEnd #seek_set
								)
							)
						)
					)
				)
			)
			0x10: (
				case of
				(
					(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x3): ( -- 0x17
						fseek f 0x18 #seek_cur
						print (ftell f)
					)
				)
			)
		)
		
		--msh = mesh vertices:vertexArray faces:#()
	)
	
	fseek f lastPos #seek_set
)


fclose f







