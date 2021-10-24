
gc()
enableSceneRedraw()
clearlistener()

global globalStartTime = timestamp()
global globalImportedFilePath = ""
global globalBoolApplyNormals = false
global globalBoolApplySkinning = false


-- Structs

struct PakEntryInfoStruct
(
	unk1, 	-- u32
	unk2, 	-- u32
	offset, 	-- u32
	size,		-- u32
	type		-- procedural, u32
)

struct VertDescriptorStruct
(
	gxAttr 				= 0, -- byte
	stride 				= 0, -- byte
	unk 					= 0, -- 4 bytes
	vertArrayOffset 	= 0  -- u32
)


-- General helper functions

fn GetOpenFile = 
(
	clearlistener()
	local fname = getOpenFileName \ 
	caption:"Open Model" \
	types:"Package file (*.package)|*.package" \
	historyCategory:"PACKAGEWII Object Presets"
	if (fname == undefined) then
	(
		return undefined
	)
	else
	(
		globalImportedFilePath = fname
		local f = fopen fname "rb"
		return f
	)
)

-- Reading functions

fn ReadBEShort fstream = 
(
	return bit.swapBytes (ReadShort fstream #unsigned) 1 2
)

fn ReadBELong fstream = 
(
	return bit.swapBytes (bit.swapBytes (ReadLong fstream #unsigned) 1 4) 2 3
)

fn ReadBEFloat fstream = 
(
	return bit.intAsFloat (bit.swapBytes (bit.swapBytes (ReadLong fstream #unsigned) 1 4) 2 3)
)

fn ReadBEVector3 fstream =
(
	return [(ReadBEFloat fstream), (ReadBEFloat fstream), (ReadBEFloat fstream)]
)

fn ReadBEVector4 fstream =
(
	return [(ReadBEFloat fstream), (ReadBEFloat fstream), (ReadBEFloat fstream), (ReadBEFloat fstream)]
)

fn ReadBEMatrix44 fstream =
(
	return matrix3 (ReadBEVector4 fstream) (ReadBEVector4 fstream) (ReadBEVector4 fstream) (ReadBEVector4 fstream)
)

fn WriteBELong fstream val =
(
	WriteLong fstream (bit.swapBytes (bit.swapBytes val 1 4) 2 3)
)

fn WriteBEShort fstream val =
(
	WriteShort fstream (bit.swapBytes val 1 2)
)

fn GetEntryType fstream offset =
(
	local startPos = ftell fstream
	FSeek fstream offset #seek_set
	local type = ReadBELong fstream
	FSeek fstream startPos #seek_set
	return type
)

fn GetVertex fstream vtxDesc index = 
(
	fseek fstream (vtxDesc.vertArrayOffset + ((index - 1) * vtxDesc.stride)) #seek_set
	case (vtxDesc.gxAttr) of
	(
		0x09: -- GX_VA_POS
		return [(ReadBEFloat fstream), (ReadBEFloat fstream), (ReadBEFloat fstream)]
		0x0A: -- GX_VA_NRM
		return [(ReadBEFloat fstream), (ReadBEFloat fstream), (ReadBEFloat fstream)]
		
		0x0D: -- GX_VA_TEX0
		return [(ReadBEFloat fstream), ((ReadBEFloat fstream) * -1) + 1, 0]
		0x0E: -- GX_VA_TEX1
		return [(ReadBEFloat fstream), ((ReadBEFloat fstream) * -1) + 1, 0]
		0x0F: -- GX_VA_TEX2
		return [(ReadBEFloat fstream), ((ReadBEFloat fstream) * -1) + 1, 0]
		0x10: -- GX_VA_TEX3
		return [(ReadBEFloat fstream), ((ReadBEFloat fstream) * -1) + 1, 0]
		0x11: -- GX_VA_TEX4
		return [(ReadBEFloat fstream), ((ReadBEFloat fstream) * -1) + 1, 0]
		0x12: -- GX_VA_TEX5
		return [(ReadBEFloat fstream), ((ReadBEFloat fstream) * -1) + 1, 0]
		0x13: -- GX_VA_TEX6
		return [(ReadBEFloat fstream), ((ReadBEFloat fstream) * -1) + 1, 0]
		0x14: -- GX_VA_TEX7
		return [(ReadBEFloat fstream), ((ReadBEFloat fstream) * -1) + 1, 0]
		
		default:
		throw "Unknown GXAttr"
	)
)

fn ReadGXTriangleStrip fstream vertDescriptorArray = 
(
	vtxCount = ReadBEShort fstream
	
	primsArray = #()
	triPrims = #()
	for i = 1 to vertDescriptorArray.Count do
	(
		primsArray[i] = #()
		triPrims[i] = #()
	)
	
	for i = 1 to vtxCount do 
	(
		for j = 1 to vertDescriptorArray.Count do
		(
			if (vertDescriptorArray[j].gxAttr != 0) then
			(
				primsArray[j][i] = ((ReadBEShort fstream) + 1)
			)
			else
			(
				primsArray[j][i] = ((ReadByte fstream #unsigned) + 1)
			)
		)
	)
	
	for i = 3 to vtxCount do
	(
		if (mod i 2) == 0 then
		(
			for j = 1 to vertDescriptorArray.Count do
			(
				append triPrims[j] [primsArray[j][i], primsArray[j][i - 1], primsArray[j][i - 2]]
			)
		)
		else
		(
			for j = 1 to vertDescriptorArray.Count do
			(
				append triPrims[j] [primsArray[j][i - 2], primsArray[j][i - 1], primsArray[j][i]]
			)
		)
	)
	return triPrims	
)

fn ReadGXTriangles fstream vertDescriptorArray = 
(
	vtxCount = ReadBEShort fstream
	
	primsArray = #()
	triPrims = #()
	for i = 1 to vertDescriptorArray.Count do
	(
		primsArray[i] = #()
		triPrims[i] = #()
	)
	
	for i = 1 to vtxCount do 
	(
		for j = 1 to vertDescriptorArray.Count do
		(
			if (vertDescriptorArray[j].gxAttr != 0) then
			(
				primsArray[j][i] = ((ReadBEShort fstream) + 1)
			)
			else
			(
				primsArray[j][i] = ((ReadByte fstream #unsigned) + 1)
			)
		)
	)
	
	for i = 1 to vtxCount by 3 do
	(
		for j = 1 to vertDescriptorArray.Count do
		(
			append triPrims[j] [primsArray[j][i], primsArray[j][i + 1], primsArray[j][i + 2]]
		)
	)
	return triPrims	
)

fn ReadRMDL fstream offset =
(
	print("RMDL found. Start reading RMDL...")
	fseek fstream offset #seek_set
	rmdlMagic = ReadBELong fstream
	flags = ReadBELong fstream
	fseek fstream 0x18 #seek_cur
	numMeshes = ReadBELong fstream
	meshPointerTableOffset = ReadBELong fstream + offset
	
	print("RMDL flags:0x" + (bit.intashex(flags)) + " numMeshes:" + numMeshes as string)
	print("Start reading meshes...")
	for i = 1 to numMeshes do
	(
		fseek fstream (meshPointerTableOffset + ((i-1) * 4)) #seek_set
			
		meshInfoTableOffset = ReadBELong fstream + offset
		fseek fstream (meshInfoTableOffset) #seek_set
		
		primBankSize = ReadBELong fstream
		primBankOffset = ReadBELong fstream + offset
		numVertDescriptors = ReadBELong fstream
		vertDescriptorStartOffset = ReadBELong fstream + offset
		print(numVertDescriptors as string + " vertex descriptors")
		
		floatArray = #()
		for i = 1 to 16 do
		(
			floatArray[i] = ReadBEFloat fstream
		)
		--print floatArray
		
		weightInfoOffset = ReadBELong fstream + offset
		unkInfoOffset = ReadBELong fstream + offset
		unk2InfoOffset = ReadBELong fstream + offset
		
		boneMapWeightsArray = #()
		boneMapWeightIdsArray = #()
		
		print("Weight data is present. Reading bone maps...")
		if (weightInfoOffset != offset) then
		(
			fseek fstream weightInfoOffset #seek_set
			boneMapArrayOffset = ReadBELong fstream + offset
			unkFloatArrayOffset = ReadBELong fstream + offset
			numBoneMaps = ReadBELong fstream
			
			print(numBoneMaps as string + " bonemaps")
			
			fseek fstream boneMapArrayOffset #seek_set
			for i = 1 to numBoneMaps do
			(
				boneMapWeightsArray[i] = ReadBEVector4 fstream
				boneMapWeightIdsArray[i] = [(ReadByte fstream #unsigned), (ReadByte fstream #unsigned), 
														(ReadByte fstream #unsigned), (ReadByte fstream #unsigned)]
			)
		)
		
		if (unk2InfoOffset != offset) then
		(
			fseek fstream unk2InfoOffset #seek_set
			numBones = ReadBELong fstream
			unkArrayOffset = ReadBELong fstream + offset
			boneMatrixArrayOffset = ReadBELong fstream + offset
			
			fseek fstream boneMatrixArrayOffset #seek_set
			for i = 1 to numBones do
			(
				mtx = ReadBEMatrix44 fstream
				
				/*
				newBone = bonesys.createbone	\
					  mtx.row4	\
					  (mtx.row4 + 0.01 * (normalize mtx.row1)) \
					  (normalize mtx.row3)
				newBone.width  = 0.01
				newBone.height = 0.01
				newBone.transform = mtx
				newBone.setBoneEnable false 0
				newBone.wirecolor = yellow
				newbone.showlinks = true
				newBone.pos.controller      = TCB_position ()
				newBone.rotation.controller = TCB_rotation ()
				*/
			)
		)
			
		vertDescriptorArray = #()
		if (weightInfoOffset != offset) then
		(
			vtxDesc = VertDescriptorStruct()
			vtxDesc.gxAttr = 0 -- GX_VA_PNMTXIDX
			vtxDesc.stride = 1
			print vtxDesc
			append vertDescriptorArray vtxDesc
		)
		for j = 1 to numVertDescriptors do
		(
			fseek fstream (vertDescriptorStartOffset + ((j-1) * 8)) #seek_set
			vtxDesc = VertDescriptorStruct()
			vtxDesc.gxAttr = ReadByte fstream #unsigned
			vtxDesc.stride = ReadByte fstream #unsigned
			vtxDesc.unk = ReadBEShort fstream
			vtxDesc.vertArrayOffset = ReadBELong fstream + offset
			print vtxDesc
			append vertDescriptorArray vtxDesc
		)
		
		print("Start reading primitive bank...")
		primArray = #()
		fseek fstream (primBankOffset) #seek_set
		faceEnd = (primBankOffset + primBankSize)
		while ((ftell fstream) < faceEnd) do
		(
			cmd = ReadByte fstream #unsigned
			case (cmd) of
			(
				0x00:() -- NOP
				0x08: -- CP
				fseek fstream 0x05 #seek_cur
				0x20:
				fseek fstream 0x04 #seek_cur
				0x28:
				fseek fstream 0x04 #seek_cur
				0x90: -- GX_TRIANGLES
				append primArray (ReadGXTriangles fstream vertDescriptorArray)
				0x98: -- GX_TRIANGLESTRIP
				append primArray (ReadGXTriangleStrip fstream vertDescriptorArray)
				default:
				(
					print("Unknown GX command: " + cmd as string)
					fseek fstream faceEnd #seek_set
				)
			)
		)
		
		posArray = #()
		nrmArray = #()
		tex0Array = #()
		faceArray = #()
		
		print("Acquiring vertex data...")
		for i = 1 to primArray.Count do
		(
			for j = 1 to vertDescriptorArray.Count do
			(
				vtxDesc = vertDescriptorArray[j]
				
				case (vtxDesc.gxAttr) of
				(
					0x09: -- GX_VA_POS
					for k = 1 to primArray[i][j].Count do
					(
						append posArray ((GetVertex fstream vtxDesc primArray[i][j][k][1]))
						append posArray ((GetVertex fstream vtxDesc primArray[i][j][k][2]))
						append posArray ((GetVertex fstream vtxDesc primArray[i][j][k][3]))
					)
					
					0x0A: -- GX_VA_NRM
					for k = 1 to primArray[i][j].Count do
					(
						append nrmArray (GetVertex fstream vtxDesc primArray[i][j][k][1])
						append nrmArray (GetVertex fstream vtxDesc primArray[i][j][k][2])
						append nrmArray (GetVertex fstream vtxDesc primArray[i][j][k][3])
					)
					
					0x0D: -- GX_VA_TEX0
					for k = 1 to primArray[i][j].Count do
					(
						append tex0Array (GetVertex fstream vtxDesc primArray[i][j][k][1])
						append tex0Array (GetVertex fstream vtxDesc primArray[i][j][k][2])
						append tex0Array (GetVertex fstream vtxDesc primArray[i][j][k][3])
					)
				)
			)
		)
		
		for i = 1 to posArray.Count by 3 do
		(
			append faceArray [i, i+1, i+2]
		)
		
		if (posArray.Count == 0) then
		(
			return undefined
		)
		
		msh = mesh vertices:posArray faces:faceArray tverts:tex0Array
		buildTVFaces msh
		for j = 1 to faceArray.count do setTVFace msh j faceArray[j]
		for j = 1 to nrmArray.count do setNormal msh j nrmArray[j]
		for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
	)
)

fn ReadTexture fstream offset index =
(
	print("Found texture.. Reading..")
	FSeek fstream offset #seek_set
	texMagic = ReadBELong fstream
	flags = ReadBELong fstream
	imageSize = ReadBELong fstream
	FSeek fstream 0x0C #seek_cur
	width = ReadBEShort fstream
	height = ReadBEShort fstream
	imageFormat = ReadBELong fstream
	numImages = ReadBELong fstream
	FSeek fstream 0x14 #seek_cur
	imageOffset = ReadBELong fstream + offset
	imageSize = ReadBELong fstream
	imageData = #()
	FSeek fstream imageOffset #seek_set
	for i = 1 to imageSize do
	(
		imageData[i] = ReadByte fstream #unsigned
	)
	
	print("Texture " + index as string + " flags:0x" + (bit.intashex(flags)) + 
			" width:" + width as string + " height" + height as string + " format:0x" + (bit.intashex(imageFormat)))
	
	
	outName = (GetFileNamePath(globalImportedFilePath) + GetFileNameFile(globalImportedFilePath) + "_" + index as string + ".tpl")
	print("Writing to " + outName)
	createOut = createfile outName
	close createOut
	out = fopen outName "wb"
	WriteBELong out 0x0020AF30
	WriteBELong out 0x00000001
	WriteBELong out 0x0000000C
	WriteBELong out 0x00000014
	WriteBELong out 0x00000000
	WriteBEShort out height
	WriteBEShort out width
	WriteBELong out imageFormat
	WriteBELong out 0x00000060
	WriteBELong out 0x00000000
	WriteBELong out 0x00000000
	WriteBELong out 0x00000001
	WriteBELong out 0x00000001
	for i = 1 to 12 do WriteBELong out 0x00000000
	for i = 1 to imageSize do
	(
		WriteByte out imageData[i]
	)
)

pak = GetOpenFile()
if (pak != undefined AND ((ReadBELong pak) == 0x46504244)) then
(
	Print("Reading package...")
	FSeek pak 0x20 #seek_cur
	numPakEntries = ReadBELong pak
	pakEntryTableOffset = ReadBELong pak
	pakEntryTableSize = ReadBELong pak
	
	Print(numPakEntries as string + " package entries")	
	FSeek pak pakEntryTableOffset #seek_set
	FSeek pak 0x04 #seek_cur
	numSpecialEntries = ReadBELong pak
	FSeek pak (numSpecialEntries * 0x10) #seek_cur
	
	Print("Skipped " + numSpecialEntries as string + " special package entries")
	
	pakEntryInfoArray = #()
	
	Print("Reading package entries")
	for i = 1 to numPakEntries do
	(
		info = PakEntryInfoStruct()
		info.unk1 = ReadBELong pak
		info.unk2 = ReadBELong pak
		info.offset = ReadBELong pak
		info.size = ReadBELong pak
		info.type = GetEntryType pak info.offset
		pakEntryInfoArray[i] = info
		Print(info)
	)
	
	Print("Parsing package entries")
	texCounter = -1
	for entry in pakEntryInfoArray do
	(
		case (entry.type) of
		(
			0x524D444C:
			ReadRMDL pak entry.offset
			0x14FE0149:
			(
				texCounter += 1
				ReadTexture pak entry.offset texCounter
			)
		)
	)
)

gc()
