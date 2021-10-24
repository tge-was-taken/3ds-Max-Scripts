
/*	Danganronpa: Another Episode model importer by TGE.
	Version 0.2 (WIP)
	Please give credit where is due.
*/

g_ModelScale = 100

struct FileInfo
(
	FilePath,
	FileName,
	DirectoryPath,
	Stream,
	FileSize
)

fn FileOpenWithDialog = 
(
	local fname = getOpenFileName \ 
	caption:"Open Model" \
	types:"Danganronpa: Another Episode Model (*.bnp)|*.bnp" \
	historyCategory:"DRAE Object Presets"
	
	if (fname == undefined) then
	(
		return undefined
	)
	else
	(
		local fInfo = FileInfo()
		fInfo.FilePath = fname
		fInfo.FileName = getFilenameFile fInfo.FilePath
		fInfo.DirectoryPath = GetFileNamePath fInfo.FilePath
		fInfo.Stream = fopen fname "rb"
		
		FSeek fInfo.Stream 0 #seek_end
		fInfo.FileSize = FTell fInfo.Stream
		FSeek fInfo.Stream 0 #seek_set

		return fInfo
	)
)

fn PrintNewLine =
(
	format "\n"
)

fn PrintHex str num =
(
	print (str + bit.intashex(num))
)

fn PrintNum str num =
(
	print (str + (num as string))
)

fn FStream_Align fstream alignment =
(
	local alignedPos = bit.and (ftell fstream + (alignment - 1)) (bit.not (alignment - 1))
	fseek fstream alignedPos #seek_set
)

fn ReadVec2 fstream =
(
	return [ReadFloat fstream, ReadFloat fstream, 0]
)

fn ReadVec3 fstream =
(
	return [ReadFloat fstream, ReadFloat fstream, ReadFloat fstream]
)

fn ReadVec4 fstream =
(
	return [ReadFloat fstream, ReadFloat fstream, ReadFloat fstream, ReadFloat fstream]
)

fn DecodePackedVector11_11_10 data =
(
	local x_num_bits	= 11
	local x_shift		= 0
	local x_mask		= 0x7FF
	
	local y_num_bits = 11
	local y_shift		= x_num_bits
	local y_mask		= 0x7FF
	
	local z_num_bits = 10
	local z_shift		= x_num_bits + y_num_bits
	local z_mask		= 0x3FF
	
	/*
	x_int = (data & (x_mask << x_shift)) >> x_shift
	*/
	local x_int = bit.shift (bit.and data (bit.shift x_mask x_shift)) -x_shift
	local y_int = bit.shift (bit.and data (bit.shift y_mask y_shift)) -y_shift
	local z_int = bit.shift (bit.and data (bit.shift z_mask z_shift)) -z_shift
	
	local x_float = (x_int as float) / (bit.shift x_mask -1)
	local y_float = (y_int as float) / (bit.shift y_mask -1)
	local z_float = (z_int as float) / (bit.shift z_mask -1)
		
	return [x_float, y_float, z_float]
)

fn ReadNormal fstream =
(
	return [(ReadByte fstream #signed as float) / 127f, (ReadByte fstream #signed as float) / 127f, (ReadByte fstream #signed as float) / 127f, ReadByte fstream]
)

struct BNPHeader
(
	hash,
	field04,
	field08,
	field0C,
	numMeshes,
	meshHeaderOffsets = #(),
	
	fn ReadFromFStream fstream =
	(
		local head = BNPHeader()
		head.hash 							= ReadLong fstream #unsigned
		head.field04 						= ReadLong fstream #unsigned
		head.field08 						= ReadLong fstream #unsigned
		head.field0C 						= ReadLong fstream #unsigned		
		head.numMeshes 				= ReadLong fstream #unsigned
		
		for i = 1 to head.numMeshes do
		(
			head.meshHeaderOffsets[i] = ReadLong fstream #unsigned
		)
		
		FStream_Align fstream 16
		
		return head
	)
)

struct BNPMeshHeader
(
	numVertices,
	numIndices,
	vertex1Size,
	vertex2Size,
	vertexBuffer1Offset,
	indexBufferOffset,
	vertexBuffer2Offset,
	field1C,
	
	fn ReadFromFStream fstream =
	(
		local geoHead = BNPMeshHeader()
		geoHead.numVertices 			= ReadLong fstream #unsigned
		geoHead.numIndices 			= ReadLong fstream #unsigned
		geoHead.vertex1Size 			= ReadLong fstream #unsigned
		geoHead.vertex2Size 			= ReadLong fstream #unsigned
		geoHead.vertexBuffer1Offset 	= ReadLong fstream #unsigned
		geoHead.indexBufferOffset		= ReadLong fstream #unsigned
		geoHead.vertexBuffer2Offset	= ReadLong fstream #unsigned
		geoHead.field1C 					= ReadLong fstream #unsigned
		return geoHead
	)
)

struct PSCAHeader
(
	magic,
	field04,
	field05,
	field06,
	field07,
	field08,
	field0C,
	field10,
	field14,
	field18,
	field1C,
	field20,
	field24,
	field28,
	field2C,
	field30,
	field34,
	field38,
	field3C,
	field40,
	field44,
	subMeshTableHeaderOffset,
	field4C,
	field50,
	field54,
		
	fn ReadFromFStream fstream =
	(
		local head = PSCAHeader()
		head.magic 								= ReadLong fstream #unsigned
		head.field04 								= ReadByte fstream #unsigned
		head.field05 								= ReadByte fstream #unsigned
		head.field06 								= ReadByte fstream #unsigned		
		head.field07 								= ReadByte fstream #unsigned
		head.field08								= ReadLong fstream #unsigned
		head.field0C								= ReadLong fstream #unsigned
		head.field10								= ReadLong fstream #unsigned
		head.field14								= ReadLong fstream #unsigned
		head.field18								= ReadLong fstream #unsigned
		head.field1C								= ReadLong fstream #unsigned
		head.field20								= ReadLong fstream #unsigned
		head.field24								= ReadLong fstream #unsigned
		head.field28								= ReadLong fstream #unsigned
		head.field2C								= ReadLong fstream #unsigned
		head.field30								= ReadLong fstream #unsigned
		head.field34								= ReadLong fstream #unsigned
		head.field38								= ReadLong fstream #unsigned
		head.field3C								= ReadLong fstream #unsigned
		head.field40								= ReadLong fstream #unsigned
		head.field44								= ReadLong fstream #unsigned
		head.subMeshTableHeaderOffset		= ReadLong fstream #unsigned
		head.field4C								= ReadLong fstream #unsigned
		head.field50								= ReadLong fstream #unsigned
		head.field54								= ReadLong fstream #unsigned		
		return head
	)
)

struct SubMeshTableHeader
(
	numSubmeshes,
	numSubmeshesAux,
	subMeshTableOffset,
	field0A,

	fn ReadFromFStream fstream = 
	(
		local head = SubMeshTableHeader()
		head.numSubmeshes		= ReadLong fstream #unsigned
		head.numSubmeshesAux	= ReadLong fstream #unsigned
		head.subMeshTableOffset	= ReadShort fstream #unsigned
		head.field0A					= ReadShort fstream #unsigned
		return head
	)
)

struct SubMesh
(
	field00,
	field02,
	field04,
	field06,
	field08 = #(),
	indexStart,
	vertexStart,
	numIndices,
	numVertices,
	field28,
	field2C,
	
	fn ReadFromFStream fstream = 
	(
		local sm = SubMesh()
		sm.field00		= ReadShort fstream #unsigned
		sm.field02		= ReadShort fstream #unsigned
		sm.field04		= ReadShort fstream #unsigned
		sm.field06		= ReadByte fstream #unsigned
		for i = 1 to 21 do
		(
			sm.field08[i] = ReadByte fstream #unsigned
		)
		sm.indexStart		= ReadLong fstream #unsigned
		sm.vertexStart	= ReadLong fstream #unsigned
		sm.numIndices		= ReadShort fstream #unsigned
		sm.numVertices	= ReadShort fstream #unsigned
		sm.field28 			= ReadLong fstream #unsigned
		sm.field2C 			= ReadLong fstream #unsigned
		return sm
	)
)

fn LoadBNPFile fstream = 
(
	/* Parse BNP Header */
	local header1 = BNPHeader.ReadFromFStream fstream
	
	PrintNewLine()
	Print			"BNP Header"
	PrintHex 	"Model hash: 0x" 	header1.hash
	PrintNum	"Num Meshes: "	header1.numMeshes
	
	/* Parse PSCA Header */
	local header2 = PSCAHeader.ReadFromFStream fstream
	
	/* Parse Submesh table header */
	FSeek fstream (header2.subMeshTableHeaderOffset + 0x20) #seek_set
	local smTableHeader = SubMeshTableHeader.ReadFromFStream fstream
	
	PrintNewLine()
	Print 			"Submesh Table Header"
	PrintNum	"Num Submeshes: " smTableHeader.numSubmeshes	
	PrintNum	"Num Submeshes (Aux): " smTableHeader.numSubmeshesAux
	PrintHex		"Submesh Table Offset: 0x" smTableHeader.subMeshTableOffset

	/* Parse Submesh table */
	FSeek fstream smTableHeader.subMeshTableOffset #seek_set
	local submeshes = #()
	
	for i = 1 to smTableHeader.numSubmeshes do
	(
		submeshes[i] = (SubMesh.ReadFromFStream fstream)
		
		PrintNewLine()
		Print			"Submesh"
		PrintNum	"Index: " i
		PrintNum	"Index Start: " submeshes[i].indexStart
		PrintNum	"Vertex Start: " submeshes[i].vertexStart
		PrintNum	"Num Indices: " submeshes[i].numIndices
		PrintNum	"Num Vertices: " submeshes[i].numVertices
		PrintHex		"Field00: 0x" submeshes[i].field00
		PrintHex		"Field02: 0x" submeshes[i].field02
		PrintHex		"Field04: 0x" submeshes[i].field04
		PrintNum	"Field06: " submeshes[i].field06
		Print			"Field08:" 
		Print			submeshes[i].field08
		PrintHex   	"Field28: 0x" submeshes[i].field28
		PrintHex		"Field2C: 0x" submeshes[i].field2C
	)
	
	/* Parse mesh headers */
	local meshHeaders = #()
	for i = 1 to header1.numMeshes do
	(
		FSeek fstream header1.meshHeaderOffsets[i] #seek_set
		meshHeaders[i] = BNPMeshHeader.ReadFromFStream fstream
	
		PrintNewLine()
		Print			"Mesh Header"
		PrintNum	"Index: " i
		PrintNum 	"Num Verts: " meshHeaders[i].numVertices
		PrintNum	"Vertex1 Size: "  meshHeaders[i].vertex1Size
		PrintHex		"Vertex Buffer 1 Offset: 0x"  meshHeaders[i].vertexBuffer1Offset
		PrintNum	"Vertex2 Size: "  meshHeaders[i].vertex2Size
		PrintHex		"Vertex Buffer 2 Offset: 0x"  meshHeaders[i].vertexBuffer2Offset
		PrintNum 	"Num Indices: "  meshHeaders[i].numIndices
		PrintHex		"Index Buffer Offset: 0x"  meshHeaders[i].indexBufferOffset
		
		if (meshHeaders[i].vertex1Size != 0x48) then
		(
			PrintNewLine()
			Print "Error: Unexpected vertex1Size"
			return false
		)
	)
	
	/* Load submesh data into the scene */
	for i = 1 to smTableHeader.numSubmeshes do
	(
		if ((LoadBNPSubMesh fstream submeshes[i] meshHeaders) != true) then
		(
			return false
		)
	)

	return true
)

fn LoadBNPSubMesh fstream sm meshHeaders =
(
	local meshHeader = meshHeaders[1]
	
	/* Seek to index buffer and read the indices */
	FSeek fstream (meshHeader.indexBufferOffset + (sm.indexStart * 2)) #seek_set
	
	local triIndices = #()
	for i = 1 to sm.numIndices by 3 do
	(
		append triIndices [(ReadShort fstream #unsigned) + 1, (ReadShort fstream #unsigned) + 1, (ReadShort fstream #unsigned) + 1]
	)
	
	/* Seek to the vertex buffer and read the vertex elements */
	FSeek fstream (meshHeader.vertexBuffer1Offset + (sm.vertexStart * meshHeader.vertex1Size)) #seek_set
	
	local vertPositions = #()
	local vertNormals = #()
	local vertTexCoords1 = #()
	local vertColors = #()
	local vertTexCoords2 = #()
	local vertTexCoords3 = #()
	local vertWeights = #()
	
	for i = 1 to sm.numVertices do
	(
		append vertPositions (ReadVec3 fstream)
		vertPositions[i].x *= g_ModelScale
		vertPositions[i].y *= g_ModelScale
		vertPositions[i].z *= g_ModelScale
		append vertNormals (ReadNormal fstream)
		fseek fstream 8 #seek_cur -- Skip binormal & tangent
		append vertTexCoords1 (ReadVec2 fstream)
		append vertColors ([(ReadByte fstream #unsigned as float) / 255f, (ReadByte fstream #unsigned as float) / 255f, (ReadByte fstream #unsigned as float) / 255f, (ReadByte fstream #unsigned as float) / 255f])
		append vertTexCoords2 (ReadVec2 fstream)
		append vertTexCoords3 (ReadVec2 fstream)
		append vertWeights (ReadVec4 fstream)
		fseek fstream 4 #seek_cur -- padding
	)
	
	/*
	for i = 1 to sm.numVertices do
	(
		append vertPositions (ReadVec3 fstream)
		append vertTexCoords1 (ReadVec2 fstream)
		append vertTexCoords2 (ReadVec2 fstream)
		append vertWeights (ReadVec4 fstream)
	)
	*/

	local msh = Mesh Vertices:vertPositions Faces:triIndices
	msh.numTVerts = vertTexCoords1.Count
	
	for j = 1 to vertNormals.Count do SetNormal msh j vertNormals[j]
	
	/* Uv setup */
	buildTVFaces msh
	for i = 1 to sm.numVertices do 
	(
		local texCoord = [vertTexCoords1[i].x, vertTexCoords1[i].y * -1, 0]
		setTVert msh i texCoord
	)
	
	for i = 1 to triIndices.Count do 
	(
		setTVFace msh i triIndices[i]
	)
	
	/* Color setup */
	
	setNumCPVVerts msh sm.numVertices
	-- setCVertMode msh true
	-- setShadeCVerts msh true
	defaultVCFaces msh	
	for i = 1 to sm.numVertices do 
	(
		setVertColor msh i vertColors[i]
	)
	
	return true
)

ClearListener()

g_File = FileOpenWithDialog()
if (g_File != undefined) then
(
	--g_FileStream = fopen @"D:\User\Downloads\DRAEmodels\Komaru\pl00_hair.bnp" "rb"
	if ((LoadBNPFile g_File.Stream) == true) then
	(
		PrintNewLine()
		Print "Model imported successfully."
	)
	else
	(
		PrintNewLine()
		Print "Model failed to import. Please report back to me."
	)
	
	fclose g_FileStream
)

gc()