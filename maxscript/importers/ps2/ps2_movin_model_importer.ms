
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

fn AlignOffset fstream alignment = (
	align = (alignment - (mod (ftell fstream) alignment))
	if (align != alignment) then fseek fstream align #seek_cur
)

fname = GetOpenFileName caption:"Open model" types:"Model File(*.*)|*.*"
f = fopen fname "rb"
fseek f 0 #seek_end
FileEnd = ftell f
fseek f 0 #seek_set
clearlistener()

--fseek f 0xB4C708 #seek_set

index = 1
headerRead = false
verticesRead = false
uvsRead = false

headerArray = #()
faceArray = #()
vertexArray = #()
uvArray = #()
while ( (ftell f) != FileEnd ) do
(
	VIFTag = VIFRead f
	--print VIFTag
	case VIFTag.Command of
	(
		0x60: (
			case of
			(
				(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x2): ( -- 0x6E
					if (not headerRead) then
					(
						for d = 1 to VIFTag.DataCount do (
							VIFData = VIFParse f VIFTag
							append headerArray VIFData
						)
						headerRead = true
					)
					else
					(
						--print (bit.intashex(ftell f)) + " error: header was already read and another 0x6C batch was added"
						for d = 1 to VIFTag.DataCount do VIFParse f VIFTag
					)
				)
				(VIFTag.ElementCount == 0x2 AND VIFTag.ElementFormat == 0x1): ( -- 0x69
					if (not verticesRead and headerRead) then
					(
						for d = 1 to VIFTag.DataCount do (
							VIFData = VIFParse f VIFTag
							append vertexArray [VIFData[1] / 0xFFF, VIFData[2] / 0xFFF, VIFData[3] / 0xFFF]
						)
						verticesRead = true
					)
					else
					(
						--print (bit.intashex(ftell f)) + " error: vertices aren't parsed yet and another 0x69 batch was added"
						for d = 1 to VIFTag.DataCount do VIFParse f VIFTag
					)
				)
				(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x1): ( -- 0x65
					if (not uvsRead and headerRead and verticesRead) then
					(
						for d = 1 to VIFTag.DataCount do (
							VIFData = VIFParse f VIFTag
							append uvArray [VIFData[1] / 0xFFF, (VIFData[2] / 0xFFF) * -1, 0]
						)
						uvsRead = true
					)
					else
					(
						--print (bit.intashex(ftell f)) + " error: uvs aren't parsed yet and another 0x65 batch was added"
						for d = 1 to VIFTag.DataCount do VIFParse f VIFTag
					)
				)
				(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x3): (
					fseek f (VIFTag.DataCount * 2) #seek_cur
				)
				default: (
					VIFParse f VIFTag
				)
			)
		)
		0x10: (
			if (headerRead and verticesRead) then
			(
				faceArray = GetLinearStripArray vertexArray.count
				msh = mesh vertices:vertexArray faces:faceArray
				msh.name = "batch_" + index as string

				headerRead = false
				verticesRead = false
				uvsRead = false
				
				free headerArray
				free faceArray
				free vertexArray
				free uvArray
				
				index += 1
				
				--fseek f FileEnd #seek_set
			)
		)
		default: (
			--VIFParse f VIFTag
		)
	)
	if ((ftell f) + 4 > FileEnd) then fseek f FileEnd #seek_set
	AlignOffset f 4
)
gc()
