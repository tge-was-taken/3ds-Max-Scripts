
-- Script by TGE

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
		0x80:
			Sign = (#signed)
		0xC0:
			Sign = (#unsigned)
		default:
			Sign = (#signed)
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
		0x70: ( -- Transfer data to GIF (VIF1) & Wait for end of microprogram
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

fn AlignOffset fstream alignment = (
	align = (alignment - (mod (ftell fstream) alignment))
	if (align != alignment) then fseek fstream align #seek_cur
)

fn GetLinearStripArray VertCount = (
	local FaceArray = #()
	
	local WindCount = 0
	local WindClockwise = true
	local a = 1
	local b = 2
	local c = WindCount
	do
	(
		WindCount += 1
		c = WindCount -- linear part
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

fname = GetOpenFileName caption:"Open NSTL/SNO model" types:"NSTL/SNO Model File(*.*)|*.*"
f = fopen fname "rb"
fseek f 0 #seek_end
FileEnd = ftell f
fseek f 0 #seek_set
clearlistener()

headerRead = false
verticesRead = false
normalsRead = false
uvsRead = false

headerArray = #()
faceArray = #()
vertexArray = #()
normalArray = #()
uvArray = #()

index = 1
while ( not (ftell f) >= FileEnd ) do
(	
	VIFTag = VIFRead f
	case VIFTag.Command of
	(
		0x60: (
			case of
			(
				(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x0): ( -- 0x6C
					if (not headerRead and VIFTag.MemAddress == 0) then
					(
						print("batch " + index as string + " header at " + (bit.intashex(ftell f)))
						for d = 1 to VIFTag.DataCount do (
							VIFData = [(readlong f), (readlong f), (readlong f), (readlong f)]
							append headerArray VIFData
						)
						headerRead = true
					)
					else
					(
						print (bit.intashex(ftell f)) + " error: header was already read and another 0x6C batch was added"
						for d = 1 to VIFTag.DataCount do VIFParse f VIFTag
					)
				)
			)
		)
		0x70: (
			case of
			(
				(VIFTag.ElementCount == 0x2 AND VIFTag.ElementFormat == 0x0): ( -- 0x78
					if (not verticesRead and headerRead) then
					(
						for d = 1 to VIFTag.DataCount do (
							VIFData = VIFParse f VIFTag
							append vertexArray VIFData
						)
						verticesRead = true
					)
					else if (not normalsRead and headerRead) then 
					(
						for d = 1 to VIFTag.DataCount do (
							VIFData = VIFParse f VIFTag
							append normalArray VIFData
						)
						normalsRead = true
					)
					else
					(
						print (bit.intashex(ftell f)) + " error: vertices and normals were already read and another 0x78 batch was added"
						for d = 1 to VIFTag.DataCount do VIFParse f VIFTag
					)
				)
				(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x0): ( -- 0x74
					if (not uvsRead and headerRead) then
					(
						for d = 1 to VIFTag.DataCount do (
							VIFData = VIFParse f VIFTag
							append uvArray VIFData
						)
						uvsRead = true
					)
				)
				(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x1): ( -- 0x75
					if (not uvsRead and headerRead) then
					(
						for d = 1 to VIFTag.DataCount do (
							VIFData = VIFParse f VIFTag
							append uvArray [VIFData[1] / 0xFFF, VIFData[2] / 0xFFF, 0]
						)
						uvsRead = true
					)
				)
			)
		)
		0x10: (
			if (headerRead) then
			(
				if (vertexArray.Count > 0) then
				(
					faceArray = GetLinearStripArray vertexArray.Count
					msh = mesh vertices:vertexArray faces:faceArray
					msh.name = "batch_" + index as string
					msh.numTVerts = vertexArray.count
					buildTVFaces msh
					for j = 1 to uvArray.count do setTVert msh j uvArray[j]
					for j = 1 to faceArray.count do setTVFace msh j faceArray[j]
					for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
				)
				
				headerRead = false
				verticesRead = false
				normalsRead = false
				uvsRead = false
				
				free headerArray
				free faceArray
				free vertexArray
				free normalArray
				free uvArray
				
				index += 1
				AlignOffset f 16
			)
		)
	)
	AlignOffset f 4
)
fclose f
gc()
