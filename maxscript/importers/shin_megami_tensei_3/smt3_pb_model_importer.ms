/*

Atlus .PB/.MB/.TB/.TMX importer/converter Maxscript by TGE
Revision 10

PB files are files containing both textures, models, and animations
MB files are files that contain only models
TB files are files that contain multiple textures
TMX files are files that contain a single texture

Textures will be exported to the same folder saved in RGBA DDS format
Models (including skeleton, weights, morphers) will be imported into the 3ds max scene

These following games use these formats:
Shin Megami Tensei: Nocturne
Shin Megami Tensei: Digital Devil Saga 1
Shin Megami Tensei: Digital Devil Saga 2
Shin Megami Tensei: Devil Summoner: Raidou Kuzunoha vs The Soulless Army
Shin Megami Tensei: Devil Summoner: Raidou Kuzunoha vs King Abaddon

Todo:

- Fix occasional missing meshes for type 7 whenever the objectbatchunknown isn't 0
eg: player_b.PB & player_c.PB

- Better flag handling so that models using vertex colors don't break randomly

- Figure out the numFrames field in the MT00 chunks by editing the file and loading it in the model viewer

*/
gc()
--max select all
--max delete

global importWeights = true		-- Set this to true if you want to import the skin weights
global importNormals = false		-- Normals only import correctly for static objects
global printDebugInfo = false
global g_FileName = undefined
global g_FilePath = undefined

struct Chunk (
	ChunkStart,
	ChunkID,
	ChunkSize,
	ChunkTag,
	ChunkUnk
)

struct ObjectAttrib (
	BoneID,
	BoneTFM,
	BoneObjectOffset
)

struct ObjectInfoStruct (
	ObjectBatchInfo_Array,
	ObjectBatchBoneIDs_Array
)

struct ObjectBatchInfoStruct (
	MeshTypeFlag,
	ObjectBatchSize,
	MatID,
	ObjectBatchOffset,
	BoneIDsCount,
	BoneIDsArray
)

struct ObjectBatchBoneIDsStruct (
	ObjectBatchBoneIDs_Array
)

struct MeshInfoStruct (
	FaceCount,
	VertexCount,
	Unknown1,
	Unknown2
)

struct partialBatchStruct (
	vertIDArray,
	vertArray,
	vertCount,
	weightArray
)

struct fieldTableInfoStruct (
	unknown,
	count,
	tableOffset
)

struct fieldModelInfoStruct (
	modelNameOffset,
	modelTransformOffset,
	modelDataOffset
)

struct weight_data
(
   boneids, weights
)

struct MatDataStruct
(
	ID,
	Type,
	TexID
)

struct MorphStruct
(
	Vert,
	Nrm,
	UV,
	Face,
	MatID,
	ID,
	BoneID
)

struct MTKeyInfo
(
	keyType,
	unkMorph,
	boneIndex
)

fn PrintDebug str =
(
	if (printDebugInfo == true) then print(str)
)

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
	align = (ftell fstream) + (alignment - 1)
	align = bit.and align (bit.not (alignment - 1))
	fseek fstream align #seek_set
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
		0x80:
			Sign = (#signed)
		0xC0:
			Sign = (#unsigned)
		default:
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

fn TMXtoDDS file out = (
	
	struct colorStruct
	(
		r, g, b, a
	)
	
	fseek file 0x1 #seek_cur
	paletteFormat = readbyte file
	width = readshort file
	height = readshort file
	pixelFormat = readbyte file
	mipMapCount = readbyte file
	mipMapKValue = readbyte file
	mipMapLValue = readbyte file
	textureWrapMode = readshort file
	textureID = readlong file
	clutID = readlong file
	fseek file 0x1C #seek_cur
	
	format "TMX file: %\nPalette Format: 0x%\nWidth: %\nHeight: %\nPixel Format: 0x%\n" out (bit.intashex(paletteFormat)) width height (bit.intashex(pixelFormat))
		
	colorCount = 0
		
	--if (doesFileExist out) then return -- if the file exists, don't write it again
	
	case (pixelFormat) of
	(
		(0x13): (
			colorCount = 256
		)
		(0x14): (
			colorCount = 16
		)
	)
	
	format "Color Count: %\n" colorCount
	
	paletteArray = #()
	
	for clr = 1 to colorCount do
	(
		case paletteFormat of
		(
			(0x00): (
				colorValue = readlong file #unsigned
				r = bit.and colorValue 0x000000FF
				g = bit.shift (bit.and colorValue 0x0000FF00) -8
				b = bit.shift (bit.and colorValue 0x00FF0000) -16
				a = bit.shift (bit.and colorValue 0xFF000000) -24
				a = 0xFF * (a as float / 0x80 as float) -- ps2 alpha range is 0x00 - 0x80, but we need it to be 0x00 - 0xFF instead
				append paletteArray (colorStruct r:r g:g b:b a:a)
			)
			(0x02): (
				for y = 1 to height do
				(
					for x = 1 to width do
					(
						colorShort = readshort file #unsigned
						r = (bit.shift (bit.and colorShort 0x001F) 3)
						g = (bit.shift (bit.shift (bit.and colorShort 0x03E0) -5) 3)
						b = (bit.shift (bit.shift (bit.and colorShort 0x7C00) -10) 3)
						append imageDataArray (colorStruct r:r g:g b:b a:0xFF)
					)
				)
			)
			default: (
				throw "Unknown paletteFormat"
			)
		)
	)
	
	if (colorCount == 256) then -- tile the palette
	(
		newPaletteArray = #()
		newIndex = 1
		oldIndex = 1
		for i = 1 to 8 do
		(
			for x = 1 to 8 do
			(
				newPaletteArray[newIndex] = paletteArray[oldIndex]
				newIndex += 1
				oldIndex += 1
			)
			
			oldIndex += 8
			
			for x = 1 to 8 do
			(
				newPaletteArray[newIndex] = paletteArray[oldIndex]
				newIndex += 1
				oldIndex += 1
			)
			
			oldIndex -= 16
			
			for x = 1 to 8 do
			(
				newPaletteArray[newIndex] = paletteArray[oldIndex]
				newIndex += 1
				oldIndex += 1
			)
			
			oldIndex += 8
			
			for x = 1 to 8 do
			(
				newPaletteArray[newIndex] = paletteArray[oldIndex]
				newIndex += 1
				oldIndex += 1
			)
		)
		paletteArray = newPaletteArray
	)
	
	imageDataArray = #()
	
	case pixelFormat of
	(
		(0x14): (
			for y = 1 to height do
			(
				for x = 1 to width by 2 do
				(
					colorIndex = readbyte file #unsigned
					append imageDataArray paletteArray[(bit.and colorIndex 0x0F)+1]
					append imageDataArray paletteArray[(bit.shift (bit.and colorIndex 0xF0) -4)+1]
				)
			)
		)
		(0x13): (
			for y = 1 to height do
			(
				for x = 1 to width do
				(
					colorIndex = readbyte file #unsigned
					append imageDataArray paletteArray[colorIndex+1]
				)
			)
		)
		(0x01): (
			for y =1 to height do
			(
				for x = 1 to width do 
				(
					r = readbyte file
					g = readbyte file
					b = readbyte file
					append imageDataArray (colorStruct r:r g:g b:b a:0xFF)
				)
			)
		)
		(0x02): (
			for y = 1 to height do
			(
				for x = 1 to width do
				(
					colorShort = readshort file #unsigned
					r = (bit.shift (bit.and colorShort 0x001F) 3)
					g = (bit.shift (bit.shift (bit.and colorShort 0x03E0) -5) 3)
					b = (bit.shift (bit.shift (bit.and colorShort 0x7C00) -10) 3)
					append imageDataArray (colorStruct r:r g:g b:b a:0xFF)
				)
			)
		)
		(0x00): (
			for y = 1 to height do
			(
				for x = 1 to width do
				(
					r = readbyte file
					g = readbyte file
					b = readbyte file
					a = readbyte file
					a = 0xFF * (a as float / 0x80 as float) -- ps2 alpha range is 0x00 - 0x80, but we need it to be 0x00 - 0xFF instead
					append imageDataArray (colorStruct r:r g:g b:b a:a)
				)
			)
		)
		default: (
			throw "Unknown pixelFormat"
		)
	)
	
	ddscreate = createfile out
	close ddscreate
	ddsout = fopen out "wb"
	WriteLong ddsout 0x20534444
	WriteLong ddsout 0x7C
	WriteLong ddsout 0x021007
	WriteLong ddsout height
	WriteLong ddsout width
	WriteLong ddsout (height * width * 4)
	WriteLong ddsout 0
	WriteLong ddsout 1
	for i = 1 to 11 do WriteLong ddsout 0
	WriteLong ddsout 0x20
	WriteLong ddsout 0x41
	WriteLong ddsout 0x0
	WriteLong ddsout 0x20
	WriteLong ddsout 0x00FF0000
	WriteLong ddsout 0x0000FF00
	WriteLong ddsout 0x000000FF
	WriteLong ddsout 0xFF000000
	WriteLong ddsout 0x401000
	WriteLongLong ddsout 0
	WriteLongLong ddsout 0
	for i = 1 to imageDataArray.count do
	(
		WriteByte ddsout imageDataArray[i].b
		WriteByte ddsout imageDataArray[i].g
		WriteByte ddsout imageDataArray[i].r
		WriteByte ddsout imageDataArray[i].a
	)
	fclose ddsout	
)

fn GetBoneArray =
(
	boneArray = #()
	max select all
	for o in selection do
	(
		if (ClassOf o == BoneGeometry) then
		(
			append boneArray o
		)
	)
	return boneArray
)

fn TransformNormal norm mat =
(
	n = [0,0,0]
	n.X = dot norm mat.row1
	n.Y = dot norm mat.row2
	n.Z = dot norm mat.row3
	return n
)

fn ReadMT00 chunk fstream = 
(
	unkDataOffset = ReadLong fstream + chunk.ChunkStart
	unkDataLength = ReadLong fstream
	numMorph1 = ReadShort fstream
	numMorph2 = ReadShort fstream
	numMorph3 = ReadShort fstream
	unkZero = ReadShort fstream
	
	numAnims = ReadShort fstream
	numAKeys = ReadShort fstream
	animPointerTableOffset = ReadLong fstream + chunk.ChunkStart + 0x20
	
	keyInfoArray = #()
	for i = 1 to numAKeys do
	(
		keyInfoArray[i] = MTKeyInfo()
		keyInfoArray[i].keyType = ReadShort fstream
		keyInfoArray[i].unkMorph = ReadShort fstream
		keyInfoArray[i].boneIndex = ReadLong fstream
	)
	PrintDebug("numAnims = " + numAnims as string)
	PrintDebug("numKeys = " + numAKeys as string)
	PrintDebug keyInfoArray
	
	animPointerTableArray = #()
	fseek fstream animPointerTableOffset #seek_set
	for i = 1 to numAnims do
	(
		offset = ReadLong fstream #unsigned
		if (offset != 0) then offset += (chunk.ChunkStart + 0x20)
		animPointerTableArray[i] = offset
		PrintDebug("Animation " + i as string + " offset: " + (bit.intashex(animPointerTableArray[i])))
	)
	
	firstDone = false
	for animIndex = 1 to 1 do
	(
		if (animPointerTableArray[animIndex] == 0) then continue
		fseek fstream animPointerTableArray[animIndex] #seek_set
		
		numFrames = ReadLong fstream #unsigned
		PrintDebug("Animation " + animIndex as string + " numFrames=" + numFrames as string)
		
		for keyIndex = 1 to numAKeys do
		(
			dataLength = ReadLong fstream #unsigned
			numAssignedFrames = ReadShort fstream #unsigned
			type = ReadShort fstream #unsigned
			assignedFrameIndicesArray = #()
			for j = 1 to numAssignedFrames do
			(
				assignedFrameIndicesArray[j] = ReadShort fstream #unsigned
			)
			--PrintDebug assignedFrameIndicesArray
			AlignOffset fstream 4
			
			frameDataArray = #()
			case (type) of
			(
				0x04:
				(
					for j = 1 to numAssignedFrames do
					(
						frameDataArray[j] = [ReadShort fstream, ReadShort fstream]
					)
				)
				0x08:
				(
					for j = 1 to numAssignedFrames do
					(
						frameDataArray[j] = [ReadShort fstream #signed as float, ReadShort fstream #signed as float, 
													 ReadShort fstream #signed as float, ReadShort fstream #signed as float]
					)
				)
				0x0C:
				(
					for j = 1 to numAssignedFrames do
					(
						frameDataArray[j] = [ReadFloat fstream, ReadFloat fstream, ReadFloat fstream]
					)
				)
				default:
				(
					PrintDebug("Unknown frame data type " + type as string + " at offset " + (bit.intashex(ftell fstream)))
					fseek fstream (numAssignedFrames * type) #seek_cur
				)
			)
			--PrintDebug("frame " + keyIndex as string + " type=" + type as string)
			
			
			keyInfo = keyInfoArray[keyIndex]
			bArray = GetBoneArray()
			
			if (keyInfo.keyType == 2) then
			(
				for j = 1 to numAssignedFrames do
				(
					if (assignedFrameIndicesArray[j] != -1) then
					(
						curBone = bArray[keyInfo.boneIndex]
						--curBone.transform = transmatrix frameDataArray[j]
						curBone.rotation = quat 0 0 0 0
						curBone.position = frameDataArray[j]
					)
				)
			)
			
			
		)
		
	)
)

fn ParseMaterial fstream flags &texID = 
(
	PrintDebug("Material flags:"+(bit.intashex(flags)) + " at offset 0x" + (bit.intashex(ftell fstream)))
	for i = 17 to 32 do
	(
		flg = bit.get flags i
		if (flg == true) then
		(
			case i of
			(
				17:
				(
					val = ReadLong fstream
					PrintDebug("Bit 16 set. Color value:0x" + (bit.intashex(val))) 
				)
				18:
				(
					val = ReadLong fstream
					PrintDebug("Bit 17 set. Color value:0x" + (bit.intashex(val))) 
				)
				19:
				(
					texID = ReadLong fstream #unsigned + 1
					PrintDebug("Bit 18 set. Texture ID:" + texID as string)
				)
				20:
				(
					val = #()
					for i = 1 to 5 do 
					(
						val[i] = ReadFloat fstream
					)
					PrintDebug("Bit 19 set. Float values:" + val as string)
				)
				21:
				(
					val = ReadLong fstream
					PrintDebug("Bit 20 set. Color value:0x" + (bit.intashex(val))) 
				)
				22:
				(
					val = #()
					for i = 1 to 2 do
					(
						val[i] = ReadShort fstream #unsigned
					)
					PrintDebug("Bit 21 set. Short values:" + val as string)
				)
				23:
				(
					val = #()
					for i = 1 to 5 do 
					(
						val[i] = ReadFloat fstream
					)
					PrintDebug("Bit 22 set. Float values:" + val as string)
				)
				24:
				(
					val = ReadFloat fstream -- More likely to be a color value
					PrintDebug("Bit 23 set. Float value:" + val as string)
				)
				25:
				(
					val = ReadLong fstream
					PrintDebug("Bit 25 set. Color value:0x" + (bit.intashex(val))) 
				)
				26:
				(
					val = ReadFloat fstream
					PrintDebug("Bit 25 set. Float value:" + val as string)
				)
				27:
				(
					val = #()
					for i = 1 to 2 do 
					(
						val[i] = ReadFloat fstream
					)
					PrintDebug("Bit 26 set. Float values:" + val as string)
				)
				default:
				(
					Print("Unknown material flag set in bit " + i as string + " at offset 0x" + (bit.intashex(ftell(fstream))))
				)
			)
			--PrintDebug(bit.intashex(ftell f))
		)
	)
)

fn ParseBatches fstream batchSize matID mtx &fiStart &faceArray &matIDArray &posArray &nrmArray &texArray &clrArray boneID &weightArray =
(
	batchEnd = (ftell fstream) + (batchSize)
	while ((ftell(fstream)) < batchEnd) do
	(
		VifTag = VIFRead fstream
		if (VifTag.Command == 0) then
		(
			continue
		)
		VifData = VifParse fstream VifTag
		--print(bit.intashex(ftell fstream))
		curMeshHeader = MeshInfoStruct()
		curMeshHeader.FaceCount = VifData[1]
		curMeshHeader.VertexCount = VifData[2]
		curMeshHeader.Unknown1 = VifData[3]
		curMeshHeader.Unknown2 = VifData[4]
		
		for i = 1 to 16 do
		(
			flg = bit.get curMeshHeader.Unknown2 i
			if (flg == true) then
			(
				--print(bit.intashex(ftell fstream))
				case i of
				(
					6:
					(
						--print("Faces")
						maxFi = 0
						VifTag = VifRead fstream
						for j = 1 to VifTag.DataCount do
						(
							VifData = VifParse fstream VifTag
							Faces = [VifData[1]+1, VifData[2]+1, VifData[3]+1]
							if (Faces.x > maxFi) then maxFi= Faces.x
							if (Faces.y > maxFi) then maxFi= Faces.y
							if (Faces.z > maxFi) then maxFi= Faces.z
							append faceArray [Faces[1]+fiStart, Faces[2]+fiStart, Faces[3]+fiStart]
							append matIDArray matID
						)
						fiStart += maxFi
					)
					7:
					(
						--print("Pos")
						VifTag = VifRead fstream
						
						if ((bit.get curMeshHeader.Unknown2 11) == true) then
						(
							--print("Weights")
							for j = 1 to VifTag.DataCount do
							(
								VifData = VifParse fstream VifTag
								append posArray [VifData[1], VifData[2], VifData[3], VifData[4]]
								append weightArray (weight_data boneids:#(boneID) weights:#(1.0))
							)
						)
						else
						(
							for j = 1 to VifTag.DataCount do
							(
								VifData = VifParse fstream VifTag
								append posArray ([VifData[1], VifData[2], VifData[3]] * mtx)
								append weightArray (weight_data boneids:#(boneID) weights:#(1.0))
							) 
						)
					)
					8:
					(
						--print("Nrm")
						VifTag = VifRead fstream
						for j = 1 to VifTag.DataCount do
						(
							VifData = VifParse fstream VifTag
							append nrmArray (TransformNormal VifData (inverse mtx))
						)
					)
					9:
					(
						--print("Tex0")
						VifTag = VifRead fstream
						for j = 1 to VifTag.DataCount do
						(
							VifData = VifParse fstream VifTag
							append texArray [VifData[1], (VifData[2]*-1)+1, 0]
						)
					)
					10:
					(
						--print("Clr")
						VifTag = VifRead fstream
						for j = 1 to VifTag.DataCount do
						(
							VifData = VifParse fstream VifTag
							append clrArray [VifData[1], VifData[2], VifData[3], VifData[4]]
						)
					)
				)
			)
		)
		
		done = false
		while (done != true) do
		(
			VifTag = VIFRead fstream
			if (VifTag.Command == 0x10) then done = true
		)
	)
)

fn ReadTXP0 chunk fstream =
(
	TMXOffset = #()
	TMX0Count = readlong fstream
	format "Texture Count = %\n" TMX0Count
	for x = 1 to TMX0Count do (TMXOffset[x]=(readlong fstream))
	fseek fstream (chunk.ChunkStart + TMXOffset[1]) #seek_set -- Some TXP0s have wrong sizes/offsets due to references to shared textures but the first offset is always correct
)

fn GetFacesOrColors fstream VIFTag MeshInfo &ReadIndexCount &fiStart &Face_Array MatID &MatID_Array &Color_Array =
(
	if 
	(
		(MeshInfo.Unknown2 == 0x360) OR \
		(MeshInfo.Unknown2 == 0x160) OR \
		(MeshInfo.Unknown2 == 0x3E0) OR \
		(MeshInfo.Unknown2 == 0xBE7) \
	)
	then ReadIndexCount += 1 \ -- Interleaved Colors
	else ReadIndexCount = 1
	
	if ((mod ReadIndexCount 2) == 1) then (
		maxfi = 0
		PrintDebug("Face indices, count=" + VIFTag.DataCount as string)
		for fc = 1 to VIFTag.DataCount do (
			Faces = VIFParse fstream VIFTag
			Faces = [Faces.x+1, Faces.y+1, Faces.z+1] -- indices are base 1 in 3ds Max
			if (Faces.x > maxFi) then maxFi= Faces.x
			if (Faces.y > maxFi) then maxFi= Faces.y
			if (Faces.z > maxFi) then maxFi= Faces.z
			append Face_Array [(Faces.x+fiStart), (Faces.y+fiStart), (Faces.z+fiStart)]
			append MatID_Array MatID
		)
		fiStart += maxFi -- indices start from 0 every time, so add the total of the last index to the new index
	)
	
	if ((mod ReadIndexCount 2) == 0) then (
		PrintDebug("Vertex colors, count=" + VIFTag.DataCount as string)
		for fc = 1 to VIFTag.DataCount do (
			Colors = VIFParse fstream VIFTag
			append Color_Array [Colors.x,Colors.y,Colors.z]
		)
	)
)

fn GetMeshInfo &MeshInfo VIFTag fstream =
(
	MeshInfo = VIFParse fstream VIFTag
	MeshInfo = (MeshInfoStruct \
		FaceCount:MeshInfo.x \
		VertexCount:MeshInfo.y \
		Unknown1:MeshInfo.z \
		Unknown2:MeshInfo.w \
	)
	PrintDebug("Mesh FaceCount:" + MeshInfo.FaceCount as string + " VertexCount:" + MeshInfo.VertexCount as string+ " Flag1:" + (bit.intashex(MeshInfo.Unknown1)) + " Flag2:" + (bit.intashex(MeshInfo.Unknown2)))
)

fn ReadMD00 ChunkInfo IsMap modelIndex fstream = 
(
	/*****************
	MD00 Header
	*****************/
	if (IsMap) then ChunkInfo.ChunkStart = 0
	UNIQOffset = readlong fstream
	UNIQSize = readlong fstream
	fseek fstream 0x8 #seek_cur -- Padding
	DataStart = (ftell fstream - ChunkInfo.ChunkStart)
	if (IsMap) then DataStart = 0
	Unknown1 = readlong fstream -- constant 0x10
	global OffsetKey = Unknown1 - 0x10 -- Required in order to load models ripped from memory
	if (IsMap) then OffsetKey = 0
	UNIQOffset -= OffsetKey
	MatDataOffset = readlong fstream + DataStart - OffsetKey 
	Unknown2 = readlong fstream
	NDNMOffset = readlong fstream + DataStart - OffsetKey
	BoneOffset = Unknown1  + DataStart - OffsetKey
	fseek fstream (ChunkInfo.ChunkStart + BoneOffset) #seek_set
	BoneCount = readlong fstream
	BoneOffset += 0x10
	fseek fstream 0xC #seek_cur -- Padding
	--BoneOffset = ftell fstream

	/*****************
	Materials
	*****************/
	if (MatDataOffset != DataStart) then
	(
		fseek fstream (ChunkInfo.ChunkStart + MatDataOffset) #seek_set
		MaterialCount = readlong fstream #unsigned
		MaterialData_Array = #()
		for m = 1 to MaterialCount do
		(
			MatData = MatDataStruct()
			MatData.ID = readlong fstream #unsigned + 1
			MatData.Type = readlong fstream #unsigned
			ParseMaterial fstream MatData.Type &MatData.TexID
			MaterialData_Array[m] = MatData
		)
	)

	/*****************
	NDNM Section
	*****************/
	BoneName_Array = #()
    
    local encoding = DotNetClass "System.Text.Encoding";
    local sjEncoding = encoding.GetEncoding( 932 );

	if (NDNMOffset != DataStart) then
	(
		fseek fstream (ChunkInfo.ChunkStart + NDNMOffset) #seek_set
		NDNMTag = readfixedstring fstream 4
		NDNMSize = readlong fstream
		for x = 1 to BoneCount do
		(
            local boneNameBytes = #();
            while ( true ) do
            (
                local b = ReadByte fstream;
                if ( b == 0 ) then exit;
                append boneNameBytes b;
            )
            
            BoneName = sjEncoding.GetString( boneNameBytes );
			AlignOffset fstream 4
			BoneID = readlong fstream + 1
			BoneName_Array[BoneID] = BoneName
		)
		
	)

	/*****************
	Bone Section
	*****************/
	fseek fstream (ChunkInfo.ChunkStart + BoneOffset) #seek_set

	Bone_Array = #()
	ObjectAttribute_Array = #()

	for x = 1 to BoneCount do 
	(
		Unknown1 = readlong fstream -- constant 0x01
		Unknown2 = readlong fstream
		BoneID = readlong fstream
		BoneParent = readlong fstream
		
		BoneRotX = readfloat fstream; BoneRotY = readfloat fstream; BoneRotZ = readfloat fstream; BoneRotW = readfloat fstream -- BoneRotW is always 0.0f
		BonePosX = readfloat fstream; BonePosY = readfloat fstream; BonePosZ = readfloat fstream; BonePosW = readfloat fstream
		BoneScaleX = readfloat fstream; BoneScaleY = readfloat fstream; BoneScaleZ = readfloat fstream; BoneScaleW = readfloat fstream
						
		tfm = (rotateXMatrix (radToDeg BoneRotX)) * (rotateYMatrix (radToDeg BoneRotY)) * (rotateZMatrix (radToDeg BoneRotZ))
		tfm *= (scalematrix [BoneScaleX, BoneScaleY, BoneScaleZ, BoneScaleW])
		tfm.row4 = [BonePosX, BonePosY, BonePosZ, BonePosW]
		--tfm = matrix3 [tfm[1][1],tfm[1][3]*-1,tfm[1][2],0] [tfm[3][1]*-1,(tfm[3][3]*-1)*-1,tfm[3][2]*-1,0] [tfm[2][1],tfm[2][3]*-1,tfm[2][2],0]  [tfm[4][1],tfm[4][3]*-1,tfm[4][2],1] -- (flip up axis of the matrix to match max's)
			/*
		tfm = matrix3 \
			[tfm[1][1], tfm[1][2], tfm[1][3]] \
			[tfm[3][1], tfm[3][2], tfm[3][3]] \
			[tfm[2][1], tfm[2][2], tfm[2][3]] \
			[tfm[4][1], tfm[4][2], tfm[4][3]]
			*/
		
		if (modelIndex == 0) then
		(
			if (BoneName_Array.count != 0) then (BoneName = BoneName_Array[x]) \
			else BoneName = ("Bone"+(x as string))
		)
		else
		(
			if (BoneName_Array.count != 0) then (BoneName = BoneName_Array[x]) \
			else BoneName = (modelIndex as string + "_" + "Bone"+(x as string))
		)
		
		if (getNodeByName BoneName) != undefined do (append Bone_Array (getNodeByName BoneName))
		if ((BoneParent != -1) AND (BoneParent < x)) then (tfm = tfm * Bone_Array[BoneParent+1].objecttransform)
		
		newBone = bonesys.createbone	\
						  tfm.row4	\
						  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
						  (normalize tfm.row3)
					newBone.name = BoneName
					newBone.width  = 0.01
					newBone.height = 0.01
					newBone.transform = tfm
					newBone.setBoneEnable false 0
					newBone.wirecolor = yellow
					newbone.showlinks = true
					newBone.pos.controller      = TCB_position ()
					newBone.rotation.controller = TCB_rotation ()
                              
        SetUserProp newBone "Id" (x as string)
							  
		if (BoneParent != -1) then newBone.parent = Bone_Array[(BoneParent+1)]
		append Bone_Array newBone
							  
		ObjectBoundingBoxOffset = readlong fstream + DataStart
		ObjectOffset = readlong fstream + DataStart
							  
		if (ObjectOffset != DataStart) then 
		(
			ObjectOffset -= OffsetKey
			append ObjectAttribute_Array (ObjectAttrib BoneID:x BoneTFM:tfm BoneObjectOffset:ObjectOffset)
		)
		
		fseek fstream 0x8 #seek_cur -- Padding
			
	)

	/*****************
	Parse Object Batches
	*****************/
	Face_Array = #()
	Normal_Array = #()
	UV_Array = #()
	UV2_Array = #()
	Vert_Array = #()
	Color_Array = #()
	Weight_Array = #()
	MatID_Array = #()

	fiStart = 0
	MorphData_Array = #()
	
	print ObjectAttribute_Array
	--ObjectAttribute_Array.count = 0

	for x = 1 to ObjectAttribute_Array.count do
	(
		local NormalMatrix = inverse Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform
		
		fseek fstream (ChunkInfo.ChunkStart + ObjectAttribute_Array[x].BoneObjectOffset) #seek_set
		
		MeshOffsetTableOffset = (readlong fstream + DataStart)
		
		if (MeshOffsetTableOffset == DataStart) then continue -- null pointer
		else MeshOffsetTableOffset -= OffsetKey
		
		fseek fstream (ChunkInfo.ChunkStart + MeshOffsetTableOffset) #seek_set 
		ObjectBatchCount = readshort fstream
		ObjectBatchCountUnknown = readshort fstream
		if (ObjectBatchCountUnknown != 0) then PrintDebug ("ObjectBatchCountUnknown isn't 0! @ 0x" + (bit.intashex(ftell fstream)) as string)
		
		for y = 1 to ObjectBatchCount do
		(	
			ReadVertexCount = 0
			Vector4ReadCount = 0
			ReadIndexCount = 0
			MeshInfoReadCount = 0
			
			ObjectBatchInfoOffset  = (readlong fstream + DataStart) - OffsetKey
			
			LastInfoOffset = ftell fstream -- We'll have to return to this because we still have other entries to read
			
			fseek fstream (ChunkInfo.ChunkStart + ObjectBatchInfoOffset) #seek_set
			
			MeshTypeFlag = readlong fstream #unsigned
			
			format "Mesh Type % at offset 0x%\n" MeshTypeFlag (bit.intashex(ftell fstream - 4))
				
			MeshInfo = undefined
			
			case MeshTypeFlag of
			(
				(0x1): ( -- Type 1, works well. No rigging (issues with vertex color breaking certain models)
					
					ObjectBatchSize = readshort fstream #unsigned * 0x10
					MatID = readshort fstream #unsigned + 1
					ObjectBatchOffset = readlong fstream #unsigned + DataStart - OffsetKey
					BoneIDsCount = readlong fstream #unsigned
					
					ObjectBatchBoneIDs_Array = #()
					for z = 1 to BoneIDsCount do (append ObjectBatchBoneIDs_Array (readshort fstream #unsigned + 1))
					
					fseek fstream (ChunkInfo.ChunkStart + ObjectBatchOffset) #seek_set
					StartPosition = ftell fstream
					
					/*
					while (not (ftell fstream >= StartPosition + ObjectBatchSize)) do (
						VIFTag = (VIFread fstream)
						case (VIFTag.Command) of 
						(
							0x60: (
								case of (
									(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x2): ( -- 0x6E
										GetFacesOrColors fstream VIFTag MeshInfo &ReadIndexCount &fiStart &Face_Array MatID &MatID_Array &Color_Array
									)
									(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x1): ( -- 0x6D
										GetMeshInfo &MeshInfo VIFTag fstream
									)
									(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x0): ( -- 0x64
										PrintDebug("Texture coords, count=" + VIFTag.DataCount as string)
										for d = 1 to VIFTag.DataCount do (
											UVs = VIFParse fstream VIFTag
											append UV_Array [UVs.x, (Uvs.y * -1) , 0] -- Y axis needs to be flipped to appear correctly in 3ds Max
										)
									)
									(VIFTag.ElementCount == 0x2 AND VIFTag.ElementFormat == 0x0): ( -- 0x68
										if 
										(
											(MeshInfo.Unknown2 == 0x360) OR \
											(MeshInfo.Unknown2 == 0x160) OR \
											(MeshInfo.Unknown2 == 0x3E0) OR \
											(MeshInfo.Unknown2 == 0xBE7) \
										)
										then ReadVertexCount = 1 \ -- Interleaved Colors
										else ReadVertexCount += 1
										
										if (mod ReadVertexCount 2) == 1 then
										(
											PrintDebug("Vertex positions, count=" + VIFTag.DataCount as string)
										)
										else
										(
											PrintDebug("Vertex normals, count=" + VIFTag.DataCount as string)
										)
										
										for d = 1 to VIFTag.DataCount do (
											Vertices = VIFParse fstream VIFTag
											if (mod ReadVertexCount 2) == 1 then 
											(
												append Vert_Array (Vertices * Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform) -- transform verts to world pos
												append Weight_Array (weight_data boneids:#(ObjectAttribute_Array[x].BoneID) weights:#(1.0))
											)
											if (mod ReadVertexCount 2) == 0 then 
											(
												append Normal_Array (TransformNormal Vertices (inverse Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform))
											)
										)
									)
									(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x0): ( -- 0x6C
										PrintDebug("2 Texture coords, count=" + VIFTag.DataCount as string)
										for d = 1 to VIFTag.DataCount do (
											UVs = VIFParse fstream VIFTag
											append UV_Array [UVs.x, (Uvs.y * -1) , 0] -- Y axis needs to be flipped to appear correctly in 3ds Max
											append UV2_Array [UVs.z, (UVs.w * -1), 0] -- Dunno which one is the correct one yet ;x
										)
									)
								)
							)
							default: (
								for d = 1 to VIFTag.DataCount do (
									VIFParse fstream VIFTag
								)
							)
						)
					)
					*/
					ParseBatches fstream ObjectBatchSize MatID Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform &fiStart &Face_Array &MatID_Array &Vert_Array &Normal_Array &UV_Array &Color_Array ObjectAttribute_Array[x].BoneID &Weight_Array
				)
				(0x2): ( -- Type 2, works well except for the normals. Has rigging
					
					ObjectBatchSize = readshort fstream #unsigned * 0x10
					MatID = readshort fstream #unsigned + 1
					ObjectBatchOffset = readlong fstream #unsigned + DataStart - OffsetKey
					BoneIDsCount = readlong fstream #unsigned
					
					BoneIDs_Array = #()
					for z = 1 to BoneIDsCount do (append BoneIDs_Array (readshort fstream #unsigned + 1))
					
					fseek fstream (ChunkInfo.ChunkStart + ObjectBatchOffset) #seek_set
					StartPosition = ftell fstream
					
					while (not (ftell fstream >= StartPosition + ObjectBatchSize)) do 
					(
						partialBatchVertex_Array = #()
						partialBatchNormal_Array = #()
						while (not (MeshInfoReadCount > BoneIDsCount)) do
						(
							VIFTag = (VIFread fstream)
							case (VIFTag.Command) of 
							(
								0x60: (
									case of (
										(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x2): ( -- 0x6E
											GetFacesOrColors fstream VIFTag MeshInfo &ReadIndexCount &fiStart &Face_Array MatID &MatID_Array &Color_Array
										)
										(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x1): ( -- 0x6D
											Vector4ReadCount = 0
											MeshInfoReadCount += 1
											GetMeshInfo &MeshInfo VIFTag fstream
										)
										(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x0): ( -- 0x64
											PrintDebug("Texture coords, count=" + VIFTag.DataCount as string)
											for d = 1 to VIFTag.DataCount do (
												UVs = VIFParse fstream VIFTag
												append UV_Array [UVs.x, (Uvs.y * -1)+1 , 0] -- Y axis needs to be flipped to appear correctly in 3ds Max
											)
										)
										(VIFTag.ElementCount == 0x2 AND VIFTag.ElementFormat == 0x0): ( -- 0x68
											if 
											(
												(MeshInfo.Unknown2 == 0x360) OR \
												(MeshInfo.Unknown2 == 0x160) OR \
												(MeshInfo.Unknown2 == 0x3E0) OR \
												(MeshInfo.Unknown2 == 0xBE7) \
											)
											then ReadVertexCount = 1 \ -- Interleaved Colors
											else ReadVertexCount += 1
											tmpNormal_Array = #()
											PrintDebug("Vertex normals, count=" + VIFTag.DataCount as string)
											for d = 1 to VIFTag.DataCount do (
												Vertices = VIFParse fstream VIFTag
												if (partialBatchVertex_Array[partialBatchVertex_Array.Count].weightArray[d] != 0) then
												(
													append tmpNormal_Array ((TransformNormal Vertices (inverse Bone_Array[(BoneIDs_Array[MeshInfoReadCount])].objecttransform)) * partialBatchVertex_Array[partialBatchVertex_Array.Count].weightArray[d])
												)
												else
												(
													append tmpNormal_Array [0,0,0]
												)
											)
											append partialBatchNormal_Array tmpNormal_Array
										)
										(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x0): ( -- 0x6C
											Vector4ReadCount += 1
											if (mod Vector4ReadCount 2) == 1 then
											(
												PrintDebug("Vertex positions and weight, count=" + VIFTag.DataCount as string)
												tmpVert_Array = #()
												tmpVert_Array2 = #()
												ReadVertexCount += 1
												for d = 1 to VIFTag.DataCount do
												(
													Weights = VIFParse fstream VIFTag
													if (Weights.W != 0) then
													(
														append tmpVert_Array ([Weights.x, Weights.y, Weights.z] * (Bone_Array[(BoneIDs_Array[MeshInfoReadCount])].objecttransform) * Weights.w)
													)
													else
													(
														append tmpVert_Array [0,0,0]
													)
													append tmpVert_Array2 Weights.w
												)
												append partialBatchVertex_Array (partialBatchStruct vertArray:tmpVert_Array weightArray:tmpVert_Array2)
											)
											else
											(
												PrintDebug("2 Texture coords, count=" + VIFTag.DataCount as string)
												for d = 1 to VIFTag.DataCount do (
													UVs = VIFParse fstream VIFTag
													append UV_Array [UVs.x, (Uvs.y * -1)+1 , 0] -- Y axis needs to be flipped to appear correctly in 3ds Max
													append UV2_Array [UVs.z, (UVs.w * -1)+1, 0] -- Dunno which one is the correct one yet ;x
												)
											)
										)
									)
								)
								default: (
									for d = 1 to VIFTag.DataCount do (
										VIFParse fstream VIFTag
									)
								)
							)
							if (ftell fstream >= StartPosition + ObjectBatchSize) then MeshInfoReadCount += 1
						)
						
						MeshInfoReadCount = 1
						tmpVert_Array = #()
						tmpNormal_Array = #()
						
						vertexCount = partialBatchVertex_Array[1].vertArray.count
						
						for i = 1 to vertexCount do tmpVert_Array[i] = [0,0,0]
						for i = 1 to vertexCount do tmpNormal_Array[i] = [0,0,0]
							
						for i = 1 to BoneIDsCount do
						(
							for v = 1 to vertexCount do
							(
								tmpVert_Array[v] += partialBatchVertex_Array[i].vertArray[v]
								tmpNormal_Array[v] += partialBatchNormal_Array[i][v]
							)
						)
						
						for v = 1 to vertexCount do
						(
							append Vert_Array tmpVert_Array[v]
							append Normal_Array (normalize tmpNormal_Array[v])
						)
						
						if (BoneIDsCount >= 5) then throw "More than 4 bones!"
						
						for v = 1 to vertexCount do
						(
							if (BoneIDsCount >= 1) then weight1 = partialBatchVertex_Array[1].weightArray[v]
							if (BoneIDsCount >= 2) then weight2 = partialBatchVertex_Array[2].weightArray[v]
							if (BoneIDsCount >= 3) then weight3 = partialBatchVertex_Array[3].weightArray[v]
							if (BoneIDsCount >= 4) then weight4 = partialBatchVertex_Array[4].weightArray[v]
							
							if (BoneIDsCount >= 1) then bone1 = BoneIDs_Array[1]
							if (BoneIDsCount >= 2) then bone2 = BoneIDs_Array[2]
							if (BoneIDsCount >= 3) then bone3 = BoneIDs_Array[3]
							if (BoneIDsCount >= 4) then bone4 = BoneIDs_Array[4]
							
							w = (weight_data boneids:#() weights:#())
							maxweight = 0
							if(BoneIDsCount >= 1) then
								maxweight = maxweight + weight1 as float
							if(BoneIDsCount >= 2) then
								maxweight = maxweight + weight2 as float
							if(BoneIDsCount >= 3) then
								maxweight = maxweight + weight3 as float
							if(BoneIDsCount >= 4) then
								maxweight = maxweight + weight4 as float

							if(maxweight != 0) then (
								if(BoneIDsCount >= 1) then (
									w1 = weight1 as float
									append w.boneids (bone1)
									append w.weights (w1)
								)
								if(BoneIDsCount >= 2) then (
									w2 = weight2 as float
									append w.boneids (bone2)
									append w.weights (w2)
								)
								if(BoneIDsCount >= 3) then (
									w3 = weight3 as float
									append w.boneids (bone3)
									append w.weights (w3)
								)
								if(BoneIDsCount >= 4) then (
									w4 = weight4 as float
									append w.boneids (bone4)
									append w.weights (w4)
								)      
							)
							append Weight_Array w
						)
					)
				)
				(0x8): ( -- Type 8, works well. No rigging
					
					fseek fstream 0x2 #seek_cur
					MatID = readshort fstream #unsigned + 1
					fseek fstream 0x8 #seek_cur -- null
					
					MeshInfo = (MeshInfoStruct \
						FaceCount:(readshort fstream) \
						VertexCount:(readshort fstream) \
						Unknown1:(readshort fstream) \
						Unknown2:(readshort fstream) \
					)
					
					AlignOffset fstream 16
					
					maxfi = 0
					for fc = 1 to MeshInfo.FaceCount do
					(
						f1 = (readshort fstream #unsigned) + 1
						f2 = (readshort fstream #unsigned) + 1
						f3 = (readshort fstream #unsigned) + 1
						if (f1 > maxFi) then maxFi= f1
						if (f2 > maxFi) then maxFi= f2
						if (f3 > maxFi) then maxFi= f3
						append Face_Array [(f1+fiStart), (f2+fiStart), (f3+fiStart)]
						append MatID_Array MatID
					)
					fiStart += maxFi -- indices start from 0 every time, so add the total of the last index to the new index
					
					AlignOffset fstream 16
					
					VerticesRead = 0
					
					do
					(
						VIFTag = (VIFRead fstream)
						case (VIFTag.Command) of
						(
							0x60: (
								case of
								(
									(VIFTag.ElementCount == 0x2 AND VIFTag.ElementFormat == 0x0): ( -- 0x68
										if 
										(
											(MeshInfo.Unknown2 == 0x360) OR \
											(MeshInfo.Unknown2 == 0x160) OR \
											(MeshInfo.Unknown2 == 0x3E0) OR \
											(MeshInfo.Unknown2 == 0xBE7) \
										)
										then ReadVertexCount = 1 \ -- Interleaved Colors
										else ReadVertexCount += 1
										
										LastVertexCount = VIFTag.DataCount 
										
										for d = 1 to VIFTag.DataCount do (
											Vertices = VIFParse fstream VIFTag
											if (mod ReadVertexCount 2) == 1 then 
											(
												append Vert_Array (Vertices * Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform) -- transform verts to world pos
												append Weight_Array (weight_data boneids:#(ObjectAttribute_Array[x].BoneID) weights:#(1.0))
											)
											if (mod ReadVertexCount 2) == 0 then 
											(
												append Normal_Array (TransformNormal Vertices (inverse Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform))
											)
										)
									)
									(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x0): ( -- 0x64
										for d = 1 to VIFTag.DataCount do (
											UVs = VIFParse fstream VIFTag
											append UV_Array [UVs.x, (Uvs.y * -1)+1 , 0] -- Y axis needs to be flipped to appear correctly in 3ds Max
										)
									)
								)
							)
							0x10: (
								case of 
								(
									(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x0): (
										VerticesRead += LastVertexCount
									)
									(VIFTag.ElementCount == 0x0 AND VIFTag.ElementFormat == 0x0): (
										AlignOffset fstream 16
									)
								)
							)
							default: (
								for d = 1 to VIFTag.DataCount do (
									VIFParse fstream VIFTag
								)
							)
						)
					) while (VerticesRead != MeshInfo.VertexCount)
					
				)
				(0x7): ( -- Type 7, works well except for the normals. Has rigging
					
					fseek fstream 0x2 #seek_cur
					MatID = readshort fstream #unsigned + 1
					fseek fstream 0x8 #seek_cur -- null
					
					MeshInfo = (MeshInfoStruct \
						FaceCount:(readshort fstream) \
						VertexCount:(readshort fstream) \
						Unknown1:(readshort fstream) \
						Unknown2:(readshort fstream) \
					)
					
					BoneIDsCount = readshort fstream
					
					BoneIDs_Array = #()
					for z = 1 to BoneIDsCount do (append BoneIDs_Array (readshort fstream #unsigned + 1))
					
					AlignOffset fstream 16
					
					maxfi = 0
					for fc = 1 to MeshInfo.FaceCount do
					(
						f1 = (readshort fstream #unsigned) + 1
						f2 = (readshort fstream #unsigned) + 1
						f3 = (readshort fstream #unsigned) + 1
						if (f1 > maxFi) then maxFi= f1
						if (f2 > maxFi) then maxFi= f2
						if (f3 > maxFi) then maxFi= f3
						append Face_Array [(f1+fiStart), (f2+fiStart), (f3+fiStart)]
						append MatID_Array MatID
					)
					fiStart += maxFi -- indices start from 0 every time, so add the total of the last index to the new index
					
					AlignOffset fstream 16
					
					partialBatchVertex_Array = #()
					partialBatchNormal_Array = #()
					
					ReadVertices = 0
					BoneIndex = 0
					
					while (not(ReadVertices >= MeshInfo.VertexCount)) do
					(
						VIFTag = (VIFRead fstream)
						case (VIFTag.Command) of
						(
							0x60: (
								case of
								(
									(VIFTag.ElementCount == 0x2 AND VIFTag.ElementFormat == 0x0): ( -- 0x68
										if 
										(
											(MeshInfo.Unknown2 == 0x360) OR \
											(MeshInfo.Unknown2 == 0x160) OR \
											(MeshInfo.Unknown2 == 0x3E0) OR \
											(MeshInfo.Unknown2 == 0xBE7) \
										)
										then ReadVertexCount = 1 \ -- Interleaved Colors
										else ReadVertexCount += 1
										tmpNormal_Array = #()
										for d = 1 to VIFTag.DataCount do (
											Vertices = VIFParse fstream VIFTag
											if (partialBatchVertex_Array[partialBatchVertex_Array.Count].weightArray[d] != 0) then
											(
												append tmpNormal_Array ((TransformNormal Vertices (inverse Bone_Array[BoneIDs_Array[BoneIndex]].objecttransform)) * partialBatchVertex_Array[partialBatchVertex_Array.Count].weightArray[d])
                                                --append tmpNormal_Array Vertices
											)
											else
											(
												append tmpNormal_Array [0,0,0]
											)
										)
										append partialBatchNormal_Array tmpNormal_Array
									)
									(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x0): ( -- 0x64
										for d = 1 to VIFTag.DataCount do (
											UVs = VIFParse fstream VIFTag
											append UV_Array [UVs.x, (Uvs.y * -1)+1 , 0] -- Y axis needs to be flipped to appear correctly in 3ds Max
										)
									)
									(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x0): ( -- 0x6C
										Vector4ReadCount += 1
										if (mod Vector4ReadCount 2) == 1 then
										(
											tmpVert_Array = #()
											tmpVert_Array2 = #()
											ReadVertexCount += 1
											BoneIndex += 1
											for d = 1 to VIFTag.DataCount do
											(
												Weights = VIFParse fstream VIFTag
												append tmpVert_Array ([Weights.x, Weights.y, Weights.z] * (Bone_Array[BoneIDs_Array[BoneIndex]].objecttransform)*Weights.w)
												append tmpVert_Array2 Weights.w
											)
											append partialBatchVertex_Array (partialBatchStruct vertArray:tmpVert_Array weightArray:tmpVert_Array2)
										)
										else
										(
											for d = 1 to VIFTag.DataCount do (
												UVs = VIFParse fstream VIFTag
												append UV_Array [UVs.x, (Uvs.y * -1)+1 , 0] -- Y axis needs to be flipped to appear correctly in 3ds Max
												append UV2_Array [UVs.z, (UVs.w * -1)+1, 0] -- Dunno which one is the correct one yet ;x
											)
										)
									)
								)
							)
							0x10: (
								Vector4ReadCount = 0 
								case of
								(
									(VIFTag.ElementCount == 0x0 AND VIFTag.ElementFormat == 0x0): (
										AlignOffset fstream 16
										tmpVert_Array = #()
										tmpNormal_Array = #()
										
										vertexCount = partialBatchVertex_Array[1].vertArray.count
										
										for i = 1 to vertexCount do tmpVert_Array[i] = [0,0,0]
										for i = 1 to vertexCount do tmpNormal_Array[i] = [0,0,0]
											
										for i = 1 to BoneIDsCount do
										(
											for v = 1 to vertexCount do
											(
												tmpVert_Array[v] += partialBatchVertex_Array[i].vertArray[v]
												tmpNormal_Array[v] += partialBatchNormal_Array[i][v]
											)
										)
										
										for v = 1 to vertexCount do
										(
											append Vert_Array tmpVert_Array[v]
											append Normal_Array (normalize tmpNormal_Array[v])
										)
										
										if (BoneIDsCount >= 5) then throw "More than 4 bones!"
										
										for v = 1 to vertexCount do
										(
											if (BoneIDsCount >= 1) then weight1 = partialBatchVertex_Array[1].weightArray[v]
											if (BoneIDsCount >= 2) then weight2 = partialBatchVertex_Array[2].weightArray[v]
											if (BoneIDsCount >= 3) then weight3 = partialBatchVertex_Array[3].weightArray[v]
											if (BoneIDsCount >= 4) then weight4 = partialBatchVertex_Array[4].weightArray[v]
											
											if (BoneIDsCount >= 1) then bone1 = BoneIDs_Array[1]
											if (BoneIDsCount >= 2) then bone2 = BoneIDs_Array[2]
											if (BoneIDsCount >= 3) then bone3 = BoneIDs_Array[3]
											if (BoneIDsCount >= 4) then bone4 = BoneIDs_Array[4]
											
											w = (weight_data boneids:#() weights:#())
											maxweight = 0
											if(BoneIDsCount >= 1) then
												maxweight = maxweight + weight1 as float
											if(BoneIDsCount >= 2) then
												maxweight = maxweight + weight2 as float
											if(BoneIDsCount >= 3) then
												maxweight = maxweight + weight3 as float
											if(BoneIDsCount >= 4) then
												maxweight = maxweight + weight4 as float

											if(maxweight != 0) then (
												if(BoneIDsCount >= 1) then (
													w1 = weight1 as float
													append w.boneids (bone1)
													append w.weights (w1)
												)
												if(BoneIDsCount >= 2) then (
													w2 = weight2 as float
													append w.boneids (bone2)
													append w.weights (w2)
												)
												if(BoneIDsCount >= 3) then (
													w3 = weight3 as float
													append w.boneids (bone3)
													append w.weights (w3)
												)
												if(BoneIDsCount >= 4) then (
													w4 = weight4 as float
													append w.boneids (bone4)
													append w.weights (w4)
												)      
											)
											append Weight_Array w
										)
										free partialBatchVertex_Array
										free partialBatchNormal_Array
										BoneIndex = 0
										ReadVertices += vertexCount
									)
								)
							)
							default: (
								for d = 1 to VIFTag.DataCount do (
									VIFParse fstream VIFTag
								)
							)
						)
					)
					AlignOffset fstream 16

				)
				(0x3): ( -- Type 3, morphers
					fseek fstream 0x2 #seek_cur
					MatID = readshort fstream #unsigned + 1
					SubMeshCount = readshort fstream
					SubMeshSetCount = readshort fstream
					
					SubMeshOffset_Array = #()
					for i = 1 to SubMeshCount do
					(
						SubMeshOffset_Array[i] = (readlong fstream + DataStart) - OffsetKey
					)
					
					SubMeshInfo_Array = #()
					for i = 1 to SubMeshCount do
					(
						fseek fstream (ChunkInfo.ChunkStart + SubMeshOffset_Array[i]) #seek_set
						
						Info = #()
						for s = 1 to SubMeshSetCount do
						(
							SubMeshBatchOffset = (readlong fstream + DataStart) - OffsetKey
							SubMeshBatchSize = readlong fstream * 0x10
							Info[s] = #(SubMeshBatchOffset, SubMeshBatchSize)
						)
						SubMeshInfo_Array[i] = Info
					)

					
					-- A bit of explanation here
					-- The way they did the morphs was per batch,
					-- They only put in the transformed vertices in the meshes that is not the base mesh
					-- So if I re-order the arrays in a way that each SubMeshSet forms a complete mesh
					-- I can make the morphs useable in a normal fashion
					
					MorphMesh_Array = #()
					TempFace_Array = #()
					TempUV_Array = #()
					TempMatID_Array = #()
					
					for sms = 1 to SubMeshSetCount do
					(
						TempVert_Array = #()
						TempNrm_Array = #()
						MorphFiStart = 0
						for sm = 1 to SubMeshCount do
						(
							fseek fstream (ChunkInfo.ChunkStart + SubMeshInfo_Array[sm][sms][1]) #seek_set
							
							StartPosition = ftell fstream
							while (not (ftell fstream >= StartPosition +  SubMeshInfo_Array[sm][sms][2])) do (
								VIFTag = (VIFread fstream)
								case (VIFTag.Command) of 
								(
									0x60: (
										case of (
											(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x2): ( -- 0x6E
												if 
												(
													(MeshInfo.Unknown2 == 0x360) OR \
													(MeshInfo.Unknown2 == 0x160) OR \
													(MeshInfo.Unknown2 == 0x3E0) OR \
													(MeshInfo.Unknown2 == 0xBE7) \
												)
												then ReadIndexCount += 1 \ -- Interleaved Colors
												else ReadIndexCount = 1
												
												if ((mod ReadIndexCount 2) == 1) then (
													maxfi = 0
													for fc = 1 to VIFTag.DataCount do (
														Faces = VIFParse fstream VIFTag
														Faces = [Faces.x+1, Faces.y+1, Faces.z+1] -- indices are base 1 in 3ds Max
														if (Faces.x > maxfi) then maxfi= Faces.x
														if (Faces.y > maxfi) then maxfi= Faces.y
														if (Faces.z > maxfi) then maxfi= Faces.z
														append TempFace_Array [(Faces.x+MorphFiStart), (Faces.y+MorphFiStart), (Faces.z+MorphFiStart)]
														append TempMatID_Array MatID
													)
													MorphFiStart += maxfi
												)
												
												if ((mod ReadIndexCount 2) == 0) then (
													for fc = 1 to VIFTag.DataCount do (
														Colors = VIFParse fstream VIFTag
													)
												)
											)
											(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x1): ( -- 0x6D
												for d = 1 to VIFTag.DataCount do (
													MeshInfo = VIFParse fstream VIFTag
													MeshInfo = (MeshInfoStruct \
														FaceCount:MeshInfo.x \
														VertexCount:MeshInfo.y \
														Unknown1:MeshInfo.z \
														Unknown2:MeshInfo.w \
													)
												)
											)
											(VIFTag.ElementCount == 0x1 AND VIFTag.ElementFormat == 0x0): ( -- 0x64
												for d = 1 to VIFTag.DataCount do (
													UVs = VIFParse fstream VIFTag
													append TempUV_Array [UVs.x, (Uvs.y * -1)+1 , 0] -- Y axis needs to be flipped to appear correctly in 3ds Max
												)
											)
											(VIFTag.ElementCount == 0x2 AND VIFTag.ElementFormat == 0x0): ( -- 0x68
												if 
												(
													(MeshInfo.Unknown2 == 0x360) OR \
													(MeshInfo.Unknown2 == 0x160) OR \
													(MeshInfo.Unknown2 == 0x3E0) OR \
													(MeshInfo.Unknown2 == 0xBE7) \
												)
												then ReadVertexCount = 1 \ -- Interleaved Colors
												else ReadVertexCount += 1
												
												for d = 1 to VIFTag.DataCount do (
													Vertices = VIFParse fstream VIFTag
													if (mod ReadVertexCount 2) == 1 then 
													(
														append TempVert_Array Vertices
													)
													if (mod ReadVertexCount 2) == 0 then 
													(
														append TempNrm_Array Vertices
													)
												)
											)
											(VIFTag.ElementCount == 0x3 AND VIFTag.ElementFormat == 0x0): ( -- 0x6C
												for d = 1 to VIFTag.DataCount do (
													UVs = VIFParse fstream VIFTag
													append TempUV_Array [UVs.x, (Uvs.y * -1)+1 , 0] -- Y axis needs to be flipped to appear correctly in 3ds Max
												)
											)
										)
									)
									default: (
										for d = 1 to VIFTag.DataCount do (
											VIFParse fstream VIFTag
										)
									)
								)
							)
						)
						MorphMesh_Array[sms] = #(TempVert_Array, TempNrm_Array)
					)
					
					for m = 1 to SubMeshSetCount do
					(
						NewVert_Array = #()
						NewNrm_Array = #()
						if (m != 1) then 
						(
							for v = 1 to MorphMesh_Array[1][1].count do
							(
								NewVert_Array[v] = (MorphMesh_Array[1][1][v] + MorphMesh_Array[m][1][v]) * Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform
								NewNrm_Array[v] = TransformNormal (MorphMesh_Array[1][2][v] + MorphMesh_Array[m][2][v]) (inverse Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform)
							)
						)
						else
						(
							for v = 1 to MorphMesh_Array[1][1].count do
							(
								NewVert_Array[v] = MorphMesh_Array[1][1][v] * Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform
								NewNrm_Array[v] = TransformNormal (MorphMesh_Array[1][2][v]) (inverse Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform)
							)
						)
						MorphData = MorphStruct()
						MorphData.Vert = NewVert_Array
						MorphData.Nrm = NewNrm_Array
						MorphData.UV = TempUV_Array
						MorphData.Face = TempFace_Array
						MorphData.MatID = TempMatID_Array
						MorphData.ID = m
						MorphData.BoneID = ObjectAttribute_Array[x].BoneID
						append MorphData_Array MorphData
					)
				)
				(0x5): ( -- Type 5, morphers, no vif tags
					fseek fstream 0x2 #seek_cur
					MatID = readshort fstream #unsigned + 1
					MeshCount = readshort fstream #unsigned
					fseek fstream 0x6 #seek_cur -- null
					
					MeshInfo = (MeshInfoStruct \
						FaceCount:(readshort fstream) \
						VertexCount:(readshort fstream) \
						Unknown1:(readshort fstream) \
						Unknown2:(readshort fstream) \
					)
					
					AlignOffset fstream 16
					
					TempFace_Array = #()
					TempUV_Array = #()
					TempMatID_Array = #()
					MorphMesh_Array = #()
					
					for fc = 1 to MeshInfo.FaceCount do
					(
						f1 = (readshort fstream #unsigned) + 1
						f2 = (readshort fstream #unsigned) + 1
						f3 = (readshort fstream #unsigned) + 1
						append TempFace_Array [f1, f2, f3]
						append TempMatID_Array MatID
					)
					
					AlignOffset fstream 16
					
					for m = 1 to MeshCount do
					(
						TempVert_Array = #()
						for v = 1 to MeshInfo.VertexCount do
						(
							vx = readfloat fstream
							vy = readfloat fstream
							vz = readfloat fstream
							append TempVert_Array [vx,vy,vz]
						)
						
						AlignOffset fstream 16
						
						TempNrm_Array = #()
						for v = 1 to MeshInfo.VertexCount do
						(
							nx = readfloat fstream
							ny = readfloat fstream
							nz = readfloat fstream
							append TempNrm_Array [nx,ny,nz]
						)
						
						AlignOffset fstream 16
						
						MorphMesh_Array[m] = #(TempVert_Array, TempNrm_Array)
					)
					
					for v = 1 to MeshInfo.VertexCount do 
					(
						tu = readfloat fstream
						tv = readfloat fstream * -1
						append TempUV_Array [tu, tv+1, 0]
					)
					
					for m = 1 to MeshCount do
					(
						NewVert_Array = #()
						NewNrm_Array = #()
						if (m != 1) then 
						(
							for v = 1 to MeshInfo.VertexCount do
							(
								NewVert_Array[v] = (MorphMesh_Array[1][1][v] + MorphMesh_Array[m][1][v]) * Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform
								NewNrm_Array[v] = TransformNormal (MorphMesh_Array[1][2][v] + MorphMesh_Array[m][2][v]) (inverse Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform)
							)
						)
						else
						(
							for v = 1 to MeshInfo.VertexCount do
							(
								NewVert_Array[v] = MorphMesh_Array[1][1][v] * Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform
								NewNrm_Array[v] = TransformNormal (MorphMesh_Array[1][2][v]) (inverse Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform)
							)
						)
						
						MorphData = MorphStruct()
						MorphData.Vert = NewVert_Array
						MorphData.Nrm = NewNrm_Array
						MorphData.UV = TempUV_Array
						MorphData.Face = TempFace_Array
						MorphData.MatID = TempMatID_Array
						MorphData.ID = m
						MorphData.BoneID = ObjectAttribute_Array[x].BoneID
						append MorphData_Array MorphData
						
					)
				)
				(0x4): ( -- Type 4, no vif tags
					fseek fstream 0x2 #seek_cur
					MatID = readshort fstream #unsigned + 1
					fseek fstream 0x8 #seek_cur -- null
					
					MeshInfo = (MeshInfoStruct \
						FaceCount:(readshort fstream) \
						VertexCount:(readshort fstream) \
						Unknown1:(readshort fstream) \
						Unknown2:(readshort fstream) \
					)
					
					AlignOffset fstream 16
					
					maxFi = 0
					for fc = 1 to MeshInfo.FaceCount do
					(
						f1 = (readshort fstream #unsigned) + 1
						f2 = (readshort fstream #unsigned) + 1
						f3 = (readshort fstream #unsigned) + 1
						if (f1 > maxFi) then maxFi= f1
						if (f2 > maxFi) then maxFi= f2
						if (f3 > maxFi) then maxFi= f3
						append Face_Array [(f1+fiStart), (f2+fiStart), (f3+fiStart)]
						append MatID_Array MatID
					)
					fiStart += maxFi -- indices start from 0 every time, so add the total of the last index to the new index
					
					AlignOffset fstream 16
					
					for v = 1 to MeshInfo.VertexCount do
					(
						vx = readfloat fstream
						vy = readfloat fstream
						vz = readfloat fstream
						append Vert_Array ([vx,vy,vz] * Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform) -- transform verts to world pos
						append Weight_Array (weight_data boneids:#(ObjectAttribute_Array[x].BoneID) weights:#(1.0))
					)
					
					AlignOffset fstream 16
					
					for v = 1 to MeshInfo.VertexCount do
					(
						nx = readfloat fstream
						ny = readfloat fstream
						nz = readfloat fstream
						append Normal_Array (TransformNormal [nx,ny,nz] Bone_Array[(ObjectAttribute_Array[x].BoneID)].objecttransform)
					)
					
					AlignOffset fstream 16
				)
				default: (
					format "Unknown Mesh Type: %\n at offset: %\n" MeshTypeFlag (bit.intashex(ftell fstream - 4))
				)
			)
			if (Normal_Array.count 	!= Vert_Array.count)	then for i = 1 to (Vert_Array.count - Normal_Array.count) do append Normal_Array 	[0,0,0] -- failsafe
			if (UV_Array.count 		!= Vert_Array.count) 	then for i = 1 to (Vert_Array.count - UV_Array.count) 		do append UV_Array 		[0,0,0] -- not all meshes have a uv stored
			if (UV2_Array.count 	!= Vert_Array.count) 	then for i = 1 to (Vert_Array.count - UV2_Array.count) 	do append UV2_Array 		[0,0,0] -- not all meshes have a second uv channel
			if (Color_Array.count 	!= Vert_Array.count) 	then for i = 1 to (Vert_Array.count - Color_Array.count) 	do append Color_Array 		[255,255,255] -- not all meshes have vertex colors
			
			fseek fstream LastInfoOffset #seek_set
		)
	)

	/*****************
	Morpher setup
	*****************/
	MorphCount = 0
	for i = 1 to MorphData_Array.count do
	(
		if (MorphData_Array[i].ID > MorphCount) then MorphCount = MorphData_Array[i].ID
	)

	for m = 1 to MorphCount do
	(
		MorphVert_Array = #()
		MorphFace_Array = #()
		MorphUV_Array = #()
		MorphNrm_Array = #()
		MorphMatID_Array = #()
		fiStart = 0
		for i = 1 to MorphData_Array.count do
		(
			if (MorphData_Array[i].ID == m) then
			(
				for v = 1 to MorphData_Array[i].Vert.Count do
				(
					append MorphVert_Array MorphData_Array[i].Vert[v]
					append MorphNrm_Array MorphData_Array[i].Nrm[v]
					append MorphUV_Array MorphData_Array[i].UV[v]
				)
				maxfi = 0
				for v = 1 to MorphData_Array[i].Face.Count do
				(
					append MorphFace_Array [MorphData_Array[i].Face[v][1]+fiStart, MorphData_Array[i].Face[v][2]+fiStart, MorphData_Array[i].Face[v][3]+fiStart]
					if (MorphData_Array[i].Face[v][1] > maxfi) then maxfi = MorphData_Array[i].Face[v][1]
					if (MorphData_Array[i].Face[v][2] > maxfi) then maxfi = MorphData_Array[i].Face[v][2]
					if (MorphData_Array[i].Face[v][3] > maxfi) then maxfi = MorphData_Array[i].Face[v][3]
					append MorphMatID_Array MorphData_Array[i].MatID[v]
				)
				fiStart += maxfi
			)
		)
		if (m == 1) then
		(
			msh = Mesh Vertices:MorphVert_Array Faces:MorphFace_Array
			if (m != 1) then msh.name = g_FileName + "_MorphTarget_" + (m - 1) as string
			else msh.name = g_FileName + "_Morph"
			msh.numTVerts = MorphVert_Array.count
			buildTVFaces msh
			for j = 1 to MorphUV_array.count do setTVert msh j MorphUV_array[j]
			for j = 1 to MorphFace_Array.count do setTVFace msh j MorphFace_Array[j]
			for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
			for j = 1 to msh.numfaces do setFaceMatID msh j (MorphMatID_Array[j] as integer)
			for j = 1 to MorphNrm_Array.Count do setNormal msh j MorphNrm_Array[j]
			
			if (m != 1) then hide msh
			
			if (importWeights == true) then
			(
				max modify mode
				select msh
				skinMod = skin ()
				addModifier msh skinMod
				skinOps.addBone skinMod Bone_Array[MorphData_Array[1].BoneID] 1
			)
			
			msh.material = multimaterial numsubs:MaterialCount
			for j = 1 to msh.material.count do 
			(
				if (MaterialData_Array.count >= j) then
				(
					tm = Bitmaptexture filename:(g_FilePath + "\\" + g_FileName + "_" + MaterialData_Array[j].TexID as string + ".dds")
					msh.material.materialList[j].name = (g_FileName+"_Mat"+j as string)
					msh.material.materialList[j].diffuseMap = tm
					msh.material.materialList[j].showInViewport = true
				)
				else
				(
					messagebox "Materials weren't be loaded properly! You'll have to assign some textures manually."
				)
			)
		)
	)

	if MorphData_Array.count != 0 then
	(
		BaseMesh = getNodeByName (g_FileName + "_Morph")
		max modify mode
		select BaseMesh
		MorphMod = morpher ()
		addmodifier BaseMesh MorphMod
		--for i = 1 to MorphCount - 1 do WM3_MC_BuildFromNode BaseMesh.morpher i (getNodeByName (g_FileName + "_MorphTarget_" + i as string))
	)
	
	if (Vert_Array.Count != 0) then
	(
		/*****************
		Build Mesh
		*****************/
		msh = mesh vertices:Vert_Array faces:Face_Array
		if (modelIndex == 0) then 
		(
			msh.name = g_FileName
		)
		else
		(
			msh.name = modelIndex as string + "_" + g_FileName
		)
		msh.numTVerts = Vert_Array.count
		buildTVFaces msh
		for j = 1 to UV_array.count do setTVert msh j UV_array[j]
		for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
		for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
		for j = 1 to msh.numfaces do setFaceMatID msh j (MatID_Array[j] as integer)
		for j = 1 to Normal_Array.Count do setNormal msh j Normal_Array[j]

		/*
		if ((Normal_Array.count != 0) AND (importNormals == true)) then (
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
		)
		--maxOps.CollapseNodeTo msh 1 true -- Collapse the Edit Normals modifier
		*/

		if Color_Array.count != 0 then (
			setNumCPVVerts msh msh.numTVerts
			setCVertMode msh true
			setShadeCVerts msh true
			defaultVCFaces msh
			for j = 1 to Color_Array.count do setvertcolor msh j Color_array[j]
		)

		if ((Weight_Array.count != 0) AND (importWeights == true)) then
		(
			max modify mode
			select msh
			skinMod = skin ()
			addModifier msh skinMod
			for i = 1 to Bone_Array.count do
			( 
				maxbone = Bone_Array[i]
				if i != Bone_Array.count then 
					skinOps.addBone skinMod maxbone 0
				else
					skinOps.addBone skinMod maxbone 1
			)
			modPanel.setCurrentObject skinMod
			
			for i = 1 to (getnumverts msh) do (
			   w = Weight_Array[i]
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
		)

		msh.material = multimaterial numsubs:MaterialCount
		for j = 1 to msh.material.count do 
		(
			tm = Bitmaptexture filename:(g_FilePath + "\\" + g_FileName + "_" + MaterialData_Array[j].TexID as string + ".dds")
			msh.material.materialList[j] = StandardMaterial()
			msh.material.materialList[j].name = (g_FileName+"_Mat"+j as string)
			msh.material.materialList[j].diffuseMap = tm
			/*
			tm.alphasource = 0
			tm.monoOutput = 1
			msh.material.materialList[j].opacityMap = tm
			*/
			msh.material.materialList[j].showInViewport = true
		)
	)
)


clearlistener()
fname = getOpenFileName \ 
caption:"Open Model" \
types:"Packed Model (*.PB)|*.PB|Model (*.MB)|*.MB|Texture Pack (*.TB)|*.TB|Texture (*.TMX)|*.TMX|Field Model (*.F1)|*.F1|*.*|*.*" \
historyCategory:"AtlusPB Object Presets"

if (fname != undefined) then
(
	st = timestamp() --get start time in milliseconds

	f = fopen fname "rb"
	g_FileName = GetFilenameFile fname
	g_FilePath = getFileNamePath fname

	fseek f 0 #seek_end
	FileEnd = ftell f
	fseek f 0 #seek_set
	TMXIndex = 0


	while (not ftell f >= (FileEnd)) do 
	(
		ChunkInfo = (Chunk \
			ChunkStart:(ftell f) \
			ChunkID:(readlong f) \
			ChunkSize:(readlong f) \
			ChunkTag:(readfixedstring f 4) \
			ChunkUnk:(readlong f) 
		)
		
		PrintDebug ChunkInfo
		
		case of 
		(
			(ChunkInfo.ChunkID == 0x17 or ChunkInfo.ChunkID == 0x15): (
				unknown1 = readlong f
				dataCount = readlong f
				unknownOffset = readlong f
				unknown3 = readlong f
				
				fseek f (ChunkInfo.ChunkStart + unknownOffset) #seek_set
				
				fieldTableInfo_Array = #()
				for i = 1 to dataCount do
				(
					unknown1 = readlong f
					count = readlong f
					tableOffset = readlong f
					append fieldTableInfo_Array (fieldTableInfoStruct unknown:unknown count:count tableOffset:tableOffset)
					-- 1 = model info
					-- 2 = texture info
					-- 3 = animation info
					-- 4 = light info
				)
				
				fseek f (ChunkInfo.ChunkStart + fieldTableInfo_Array[1].tableOffset) #seek_set
				
				modelInfoTable_Array = #()
				for i = 1 to fieldTableInfo_Array[1].count do
				(
					modelID = readlong f
					unknown1 = readlong f
					modelNameOffset = readlong f
					unknown2 = readlong f
					modelTransformOffset = readlong f
					modelUnknownOffset = readlong f
					unknown3 = readlong f --always 0?
					unknown4 = readlong f --always 0?
					modelDataOffset = readlong f  -- skip dummy MD00 header
					append modelInfoTable_Array (fieldModelInfoStruct modelNameOffset:modelNameOffset modelTransformOffset:modelTransformOffset modelDataOffset:modelDataOffset)
				)
				
				for i = 1 to fieldTableInfo_Array[1].count do
				(
					fseek f (ChunkInfo.ChunkStart + modelInfoTable_Array[i].modelDataOffset) #seek_set
					ReadMD00 (Chunk ChunkStart:(ftell f)) true i f
				)
				
				fseek f (FileEnd) #seek_set
			)
			(ChunkInfo.ChunkTag == "TXP0"): (
				ReadTXP0 ChunkInfo f
			) -- TXP0
			(ChunkInfo.ChunkTag == "TMX0"): (
				TMXIndex += 1
				tmxPath = (g_FilePath + "\\" + g_FileName + "_" + TMXIndex as string + ".dds")
				if ((doesFileExist tmxPath) != true) then
				(
					TMXtoDDS f tmxPath
				)
				else
				(
					TMXtoDDS f tmxPath
				)
				fseek f ((ChunkInfo.ChunkStart) +(ChunkInfo.ChunkSize)) #seek_set
				AlignOffset f 64
			) -- TMX0
			(ChunkInfo.ChunkTag == "MT00"): (
				ReadMT00 ChunkInfo f
				fseek f (FileEnd) #seek_set
			)
			(ChunkInfo.ChunkTag == "MD00"): (
				ReadMD00 ChunkInfo false 0 f
				fseek f (FileEnd) #seek_set
			)
			default: (
				fseek f ((ChunkInfo.ChunkStart) + (ChunkInfo.ChunkSize)) #seek_set
				AlignOffset f 64
			)
		)
	)
	PrintDebug ("Done! ("+((((timestamp())-st)*0.001)as string)+" Seconds)")
	fclose f
)
gc()
