
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
		0x02:
			Sign = (#unsigned)
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

fn ParseTriStrip TriStripArray FaceArray = (
	
	local elementIndex = 0 -- This variable will be incremented by one each iteration of the loop
	local elementsPerRow = 4
	local rowIndex = 2 -- We start at row 2 in the loop because the first row is used for other data
	local indexCount = 0
	local somethingCount = TriStripArray[1][1] 
	local somethingCount2 = TriStripArray[1][2] 
	local clockwise = true
	
	--print("face array:")
	--print TriStripArray
	local first = true
	while (indexCount < somethingCount) do
	(
		clockwise = not clockwise
		elementIndex += 1
		indexCount += 1
		if (elementIndex > 4) then 
		(
			elementIndex = 1
			rowIndex += 1
		)
		if (first) then
		(
			f1 = TriStripArray[2][1]
			f2 = TriStripArray[2][2]
			elementIndex += 2
			indexCount += 2
			first = false
		)
		else if (bit.and TriStripArray[rowIndex][elementIndex] 0x8000 == 0x8000) then
		(
			f1 = bit.and TriStripArray[rowIndex][elementIndex] 0x7FFF
			elementIndex += 1
			if (elementIndex > 4) then 
			(
				elementIndex = 1
				rowIndex += 1
			)
			f2 = bit.and TriStripArray[rowIndex][elementIndex] 0x7FFF
			elementIndex += 1
			indexCount += 2
			if (elementIndex > 4) then 
			(
				elementIndex = 1
				rowIndex += 1
			)
		)
		f3 = bit.and TriStripArray[rowIndex][elementIndex] 0x7FFF
		if (f1 != f2) AND (f2 != f3) AND (f3 != f1) then
		(
			if (clockwise) then append FaceArray [f1 + 1, f2 + 1, f3 + 1]
			else append FaceArray [f1 + 1, f3 + 1, f2 + 1]
		)
		f1 = f2
		f2 = f3
		if (indexCount > 1000) then exit
	)
	
	local first = true
	indexCount = 0
	while (indexCount < somethingCount2) do
	(
		clockwise = not clockwise
		elementIndex += 1
		indexCount += 1
		if (elementIndex > 4) then 
		(
			elementIndex = 1
			rowIndex += 1
		)
		if (first) then
		(
			f1 = TriStripArray[2][1]
			f2 = TriStripArray[2][2]
			elementIndex += 2
			indexCount += 2
			first = false
			if (elementIndex > 4) then 
			(
				elementIndex = 1
				rowIndex += 1
			)
		)
		if (indexCount < somethingCount2 AND rowIndex <= TriStripArray.Count) then
		(
			if (bit.and TriStripArray[rowIndex][elementIndex] 0x8000 == 0x8000) then
			(
				f1 = bit.and TriStripArray[rowIndex][elementIndex] 0x7FFF
				elementIndex += 1
				if (elementIndex > 4) then 
				(
					elementIndex = 1
					rowIndex += 1
				)
				if (indexCount < somethingCount2 AND rowIndex <= TriStripArray.Count) then
				(
					f2 = bit.and TriStripArray[rowIndex][elementIndex] 0x7FFF
					elementIndex += 1
					indexCount += 2
					if (elementIndex > 4) then 
					(
						elementIndex = 1
						rowIndex += 1
					)
				)
			)
		)
		if (elementIndex > 4) then 
		(
			elementIndex = 1
			rowIndex += 1
		)
		if (indexCount < somethingCount2 AND rowIndex <= TriStripArray.Count) then
		(
			f3 = bit.and TriStripArray[rowIndex][elementIndex] 0x7FFF
			if (f1 != f2) AND (f2 != f3) AND (f3 != f1) then
			(
				if (clockwise) then append FaceArray [f1 + 1, f2 + 1, f3 + 1]
				else append FaceArray [f1 + 1, f3 + 1, f2 + 1]
			)
			f1 = f2
			f2 = f3
		)
		if (indexCount > 1000) then exit
	)

	
	/*
	triCount = 0
	while (triCount < somethingCount2) do
	(
		for i = 1 to 3 do
		(
			elementIndex += 1
			triCount += 1
			if (elementIndex > 4) then
			(
				elementIndex = 1
				rowIndex += 1
			)
			if (i == 1) then f1 = bit.and TriStripArray[rowIndex][elementIndex] 0x7FFF
			if (i == 2) then f2 = bit.and TriStripArray[rowIndex][elementIndex] 0x7FFF
			if (i == 3) then f3 = bit.and TriStripArray[rowIndex][elementIndex] 0x7FFF
		)
		append FaceArray [f1, f2, f3]
	)
	*/
)

fn AlignOffset fstream alignment = (
	align = (alignment - (mod (ftell fstream) alignment))
	if (align != alignment) then fseek fstream align #seek_cur
)

fname = GetOpenFileName caption:"Open PGG model" types:"PGG Model File(*.PGG)|*.PGG"
f = fopen fname "rb"
fseek f 0 #seek_end
FileEnd = ftell f
fseek f 0 #seek_set
clearlistener()

fseek f 0x58 #seek_set
vifDataStart = readlong f + 0x60
fseek f vifDataStart #seek_set

index = 1
while ( (ftell f) != FileEnd ) do
(
	vifDataSize = readshort f * 0x10
	vifUnk1 = readbyte f
	vifUnk2 = readbyte f
	AlignOffset f 16
	vifDataStart = ftell f
	
	headerRead = false
	facesRead = false
	verticesRead = false
	normalsRead = false
	uvsRead = false
	
	headerArray = #()
	triStripArray = #()
	faceArray = #()
	vertexArray = #()
	normalArray = #()
	uvArray = #()
	
	while ( (ftell f) != (vifDataStart + vifDataSize) ) do
	(
		VIFTag = VIFRead f
		case VIFTag.Command of
		(
			0x60: (
				case of
				(
					(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x0): ( -- 0x6C
						if (not headerRead) then
						(
							for d = 1 to VIFTag.DataCount do (
								VIFData = [(readlong f), (readlong f), (readfloat f), (readfloat f)]
								append headerArray VIFData
								print("batch " + index as string + " faceCount = " + VIFData[1] as string + " vertexCount = " + VIFData[2] as string)
							)
							headerRead = true
						)
						else
						(
							print (bit.intashex(ftell f)) + " error: header was already read and another 0x6C batch was added"
							for d = 1 to VIFTag.DataCount do VIFParse f VIFTag
						)
					)
					(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x1): ( -- 0x6D
						print("face buffer of batch " + index as string + " at offset " + (bit.intashex(ftell f)))
						if (not facesRead) then
						(
							for d = 1 to VIFTag.DataCount do (
								VIFData = VIFParse f VIFTag
								append triStripArray VIFData
							)
							ParseTriStrip triStripArray faceArray
							facesRead = true
						)
						else
						(
							print (bit.intashex(ftell f)) + " error: face indices aren't parsed yet and another 0x6D batch was added"
							for d = 1 to VIFTag.DataCount do VIFParse f VIFTag
						)
					)
					(VIFTag.ElementCount == 0x2 AND VIFTag.ElementFormat == 0x1): ( -- 0x69
						if (not verticesRead) then
						(
							for d = 1 to VIFTag.DataCount do (
								VIFData = VIFParse f VIFTag
								append vertexArray [VIFData[1] / 0xFFF, VIFData[2] / 0xFFF, VIFData[3] / 0xFFF]
							)
							verticesRead = true
						)
						else
						(
							print (bit.intashex(ftell f)) + " error: vertices aren't parsed yet and another 0x69 batch was added"
							for d = 1 to VIFTag.DataCount do VIFParse f VIFTag
						)
					)
					(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x1): ( -- 0x65
						if (not uvsRead) then
						(
							for d = 1 to VIFTag.DataCount do (
								VIFData = VIFParse f VIFTag
								append uvArray [VIFData[1] / 0xFFF, (VIFData[2] / 0xFFF) * -1, 0]
							)
							uvsRead = true
						)
						else
						(
							print (bit.intashex(ftell f)) + " error: uvs aren't parsed yet and another 0x65 batch was added"
							for d = 1 to VIFTag.DataCount do VIFParse f VIFTag
						)
					)
					(VIFTag.ElementCount == 0x2 AND VIFTag.ElementFormat == 0x2): ( -- 0x6A
						if (not normalsRead) then
						(
							for d = 1 to VIFTag.DataCount do (
								VIFData = VIFParse f VIFTag
								append normalArray [VIFData[1] / 0xFFF, VIFData[2] / 0xFFF, VIFData[3] / 0xFFF]
							)
							normalsRead = true
						)
						else
						(
							print (bit.intashex(ftell f)) + " error: normals aren't parsed yet and another 0x6A batch was added"
							for d = 1 to VIFTag.DataCount do VIFParse f VIFTag
						)
					)
					(VIFTag.ElementCount == 0x0 AND VIFTag.ElementFormat == 0x2): ( -- 0x62
						for d = 1 to VIFTag.DataCount do
						(
							VIFParse f VIFTag -- Not sure what this data is
						)
					)
				)
			)
			0x10: (
				
				try (
				msh = mesh vertices:vertexArray faces:faceArray
				msh.name = "batch_" + index as string
				)
				catch (
					msh = mesh vertices:vertexArray faces:#()
					msh.name = "batch_" + index as string
				)
				
				
				headerRead = false
				facesRead = false
				verticesRead = false
				normalsRead = false
				uvsRead = false
				
				free headerArray
				free faceArray
				free vertexArray
				free normalArray
				free uvArray
				
				index += 1
			)
		)
		AlignOffset f 4
	)
	
	fseek f (vifDataStart + vifDataSize) #seek_set
)
gc()
