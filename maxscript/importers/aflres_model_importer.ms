
/* 
Written by TGE
Last update: 10-4-2016
If there are any issues while using the script, contact me 
*/


/* Clean up */
gc()

/* Debug stuff */
global AFLResDebug = false

fn PrintDebug str =
(
	if (AFLResDebug) then print str
)

/* FStream reading helper functions */
fn ReadU32BE fstream =
(
	return Bit.SwapBytes (Bit.SwapBytes (ReadLong fstream #unsigned) 1 4) 2 3
)

fn ReadU16BE fstream =
(
	return Bit.SwapBytes (ReadShort fstream #unsigned) 1 2
)

fn ReadF32BE fstream =
(
	return Bit.IntAsFloat (Bit.SwapBytes (Bit.SwapBytes (ReadLong fstream #unsigned) 1 4) 2 3)
)

fn ReadVec3BE fstream =
(
	return [ReadF32BE fstream, ReadF32BE fstream, ReadF32BE fstream]
)

fn ReadVec2BE fstream =
(
	return [ReadF32BE fstream, ReadF32BE fstream, 0]
)

/*
fn ReadVec3PackedBE fstream =
(
	return (Vec3_11_11_10.LoadFromFStream fstream).ToVector3()
)

fn ReadVec3BEBufferToArray fstream offset numElements flipUp =
(
	if (numElements == 0) then
	(
		return #()
	)
	
	local arr = #()
	arr[numElements] = [0,0,0]
	
	local retPos = ftell fstream
	
	fseek fstream offset #seek_set
	
	for i = 1 to numElements do
	(
		if (flipUp) then
		(
			local x = ReadF32BE fstream
			local y = ReadF32BE fstream
			local z = ReadF32BE fstream
			arr[i] = [x, -z, y]
		)
		else
		(
			arr[i] = [ReadF32BE fstream, ReadF32BE fstream, ReadF32BE fstream]
		)
	)
	
	fseek fstream retPos #seek_set
	
	return arr
)
*/

fn ReadVec4BEBufferToArray fstream offset numElements flipUp =
(
	if (numElements == 0) then
	(
		return #()
	)
	
	local arr = #()
	arr[numElements] = [0,0,0,0]
	
	local retPos = ftell fstream
	
	fseek fstream offset #seek_set
	
	for i = 1 to numElements do
	(
		if (flipUp) then
		(
			local x = ReadF32BE fstream
			local y = ReadF32BE fstream
			local z = ReadF32BE fstream
			local w = ReadF32BE fstream
			arr[i] = [x, -z, y, w]
		)
		else
		(
			arr[i] = [ReadF32BE fstream, ReadF32BE fstream, ReadF32BE fstream, ReadF32BE fstream]
		)
	)
	
	fseek fstream retPos #seek_set
	
	return arr
)

fn ReadVec2BEBufferToArray fstream offset numElements flipUp =
(
	if (numElements == 0) then
	(
		return #()
	)
	
	local arr = #()
	arr[numElements] = [0,0,0]
	
	local retPos = ftell fstream
	
	fseek fstream offset #seek_set
	
	for i = 1 to numElements do
	(
		if (flipUp) then
		(
			local x = ReadF32BE fstream
			local y = ReadF32BE fstream
			arr[i] = [x, -y + 1, 0]
		)
		else
		(
			arr[i] = [ReadF32BE fstream, ReadF32BE fstream, 0]
		)
	)
	
	fseek fstream retPos #seek_set
	
	return arr
)

/*
fn ReadVec3BEPackedBufferToArray fstream offset numElements flipUp =
(
	if (numElements == 0) then
	(
		return #()
	)
	
	local arr = #()
	arr[numElements] = [0,0,0]
	
	local retPos = ftell fstream
	
	fseek fstream offset #seek_set
	
	for i = 1 to numElements do
	(
		if (flipUp) then
		(
			local vec = (Vec3_11_11_10.LoadFromFStream fstream).ToVec3()
			arr[i] = [vec.x, -vec.z, vec.y]
		)
		else
		(
			arr[i] = (Vec3_11_11_10.LoadFromFStream fstream).ToVec3()
		)
	)
	
	fseek fstream retPos #seek_set
	
	return arr
)
*/

fn ReadIndexBEBufferToArray fstream offset numElements =
(
	if (numElements == 0) then
	(
		return #()
	)
	
	local arr = #()
	arr[numElements] = [0,0,0]
	
	local retPos = ftell fstream
	
	fseek fstream offset #seek_set
	
	for i = 1 to numElements do
	(
		arr[i] = [ReadU16BE fstream + 1, ReadU16BE fstream + 1, ReadU16BE fstream + 1]
	)
	
	fseek fstream retPos #seek_set
	
	return arr
)

/*
struct Vec3_11_11_10
(
	m_data,
	
	fn LoadFromFStream fstream =
	(
		local inst = Vec3_11_11_10()
		inst.m_data = ReadU32BE fstream
		return inst
	),
	
	fn ToVec3 =
	(
		local x_num_bits = 11
		--local x_mask = Vec3_11_11_10.GetMask x_num_bits
		local x_mask = 0x7FF
		local x_value = (bit.and m_data x_mask) as float / (bit.shift 1 (x_num_bits - 1))
		
		local y_num_bits = 11
		--local y_mask = bit.shift (Vec3_11_11_10.GetMask y_num_bits) x_num_bits
		local y_mask = 0x7FF
		local y_value = (bit.shift (bit.and m_data (bit.shift y_mask x_num_bits)) -x_num_bits) as float / (bit.shift 1 (y_num_bits - 1))
		
		local z_num_bits = 10
		--local z_mask = bit.shift (Vec3_11_11_10.GetMask z_num_bits) (x_num_bits + y_num_bits)
		local z_mask = 0x3FF
		local z_value = (bit.shift (bit.and m_data (bit.shift z_mask (x_num_bits + y_num_bits))) -(x_num_bits + y_num_bits)) as float / (bit.shift 1 (z_num_bits - 1))
			
		PrintDebug ("m_data = " + m_data as string)
			
		PrintDebug ("x_num_bits = " + x_num_bits as string)
		PrintDebug ("x_mask = " + x_mask as string)
		PrintDebug ("x_value = " + x_value as string)
			
		PrintDebug ("y_num_bits = " + y_num_bits as string)
		PrintDebug ("y_mask = " + y_mask as string)
		PrintDebug ("y_value = " + y_value as string)
			
		PrintDebug ("z_num_bits = " + z_num_bits as string)
		PrintDebug ("z_mask = " + z_mask as string)
		PrintDebug ("z_value = " + z_value as string)
			
		return [x_value, y_value, z_value]
	),
	
	fn GetMask num_bits =
	(
		local int_num_bits = 32
		local int_mask = 0xFFFFFFFF
		
		return (bit.shift int_mask ((int_num_bits - num_bits) * -1))
	)
)
*/

/* AFLRes structs */
struct AFLResMesh
(
	/* 0x00 */ VertexBufferOffset 		= 0,
	/* 0x04 */ NormalBufferOffset 		= 0,
	/* 0x08 */ TexCoordBufferOffset		= 0,
	/* 0x0C */ UnknownBuffer1Offset 	= 0,
	/* 0x10 */ UnknownBuffer2Offset 	= 0,
	/* 0x14 */ IndexBufferOffset 		= 0,
	/* 0x18 */ VertexBufferSize 		= 0,
	/* 0x1C */ NormalBufferSize 		= 0,
	/* 0x20 */ TexCoordBufferSize 		= 0,
	/* 0x24 */ UnknownBuffer1Size 		= 0,
	/* 0x28 */ UnknownBuffer2Size 		= 0,
	/* 0x2C */ IndexCount				= 0,
	/* 0x30 */ BoundingBoxMin			= [0, 0, 0],
	/* 0x34 */ BoundingBoxMax			= [0, 0, 0],
	
	m_fileOffset = 0,
	
	/* Static */
	fn LoadFromFStream fstream =
	(
		local inst = AFLResMesh()
		inst.m_fileOffset = ftell fstream
		
		inst.VertexBufferOffset 	= ReadU32BE fstream + inst.m_fileOffset
		inst.NormalBufferOffset 	= ReadU32BE fstream + inst.m_fileOffset
		inst.TexCoordBufferOffset 	= ReadU32BE fstream + inst.m_fileOffset 
		inst.UnknownBuffer1Offset 	= ReadU32BE fstream + inst.m_fileOffset 
		inst.UnknownBuffer2Offset 	= ReadU32BE fstream + inst.m_fileOffset 
		inst.IndexBufferOffset 		= ReadU32BE fstream + inst.m_fileOffset 
		inst.VertexBufferSize 		= ReadU32BE fstream 
		inst.NormalBufferSize 		= ReadU32BE fstream 
		inst.TexCoordBufferSize 	= ReadU32BE fstream 
		inst.UnknownBuffer1Size 	= ReadU32BE fstream 
		inst.UnknownBuffer2Size 	= ReadU32BE fstream 
		inst.IndexCount 			= ReadU32BE fstream 
		inst.BoundingBoxMin 		= ReadVec3BE fstream 
		inst.BoundingBoxMax 		= ReadVec3BE fstream 
		
		return inst
	),
	
	fn ToMaxMesh fstream flipUp =
	(
		local vertexArray 	= ReadVec4BEBufferToArray 			fstream VertexBufferOffset 		(VertexBufferSize / 16)		flipUp
	  --local normalArray 	= ReadVec3BEPackedBufferToArray 	fstream NormalBufferOffset 		(NormalBufferSize / 4)		flipUp
		local texCoordArray	= ReadVec2BEBufferToArray			fstream TexCoordBufferOffset	(TexCoordBufferSize / 8)	flipUp
		local indexArray 	= ReadIndexBEBufferToArray			fstream IndexBufferOffset		(IndexCount / 3)			
		
		/*
		PrintDebug vertexArray
		PrintDebug normalArray
		PrintDebug texCoordArray
		PrintDebug indexArray
		*/
		
		/*
		for i = 1 to vertexArray.Count do
		(
			vertexArray[i] = vertexArray[i] * [BoundingBoxMin.X, BoundingBoxMin.Y, BoundingBoxMin.Z, 0]
		)
		*/
		
		local msh = Mesh Vertices:vertexArray Faces:indexArray
		msh.numTVerts = texCoordArray.Count
		
		--for j = 1 to normalArray.Count do SetNormal msh j normalArray[j]
		
		if (texCoordArray.count > 0) then
		(
			buildTVFaces msh
			
			for j = 1 to texCoordArray.Count do setTVert msh j texCoordArray[j]
			for j = 1 to indexArray.Count do setTVFace msh j indexArray[j]
		)
		
		return msh
	)
)


struct AFLResEntry
(
	/* 0x00 */ Offset 	= 0,
	/* 0x04 */ Size1 	= 0,
	/* 0x08 */ Size2 	= 0,
	/* 0x0C */ Flags 	= 0, /* 0x0B110905,0x0B110906 */
	
	MeshData = undefined,
	
	/* Static */
	fn LoadFromFStream fstream =
	(
		local inst = AFLResEntry()
		
		inst.Offset = ReadU32BE fstream
		inst.Size1 	= ReadU32BE fstream
		inst.Size2 	= ReadU32BE fstream
		inst.Flags 	= ReadU32BE fstream
		
		-- Check if it's possibly a mesh and read it if it is
		if 	(inst.Size1 == inst.Size2) AND
			(inst.Flags == 0x0B110905) then
		(
			local retPos = ftell fstream
			
			fseek fstream inst.Offset #seek_set
			
			vertexBufferOffset = ReadU32BE fstream
			
			if (vertexBufferOffset == 0x48) then
			(
				fseek fstream inst.Offset #seek_set
			
				inst.MeshData = AFLResMesh.LoadFromFStream fstream
			)
			
			fseek fstream retPos #seek_set
		)
		
		return inst
	),
	
	fn IsModelRes = 
	(
		return MeshData != undefined
	)
)

struct AFLRes
(
	/* 0x00 */ Magic = 0x46465241,
	/* 0x04 */ UnknownField04 = 0x070000,
	/* 0x08 */ UnknownField08 = 0x04,
	/* 0x0C */ UnknownField0C = 0x022FE5E0,
	
	Entries = #(),
	
	/* Static */
	fn LoadFromFStream fstream =
	(
		local inst = AFLRes()
		
		local magic = ReadU32BE fstream
		
		if (magic != inst.Magic) then
		(
			PrintDebug magic
			throw "Error. Magic value does not match."
		)
		
		inst.UnknownField04 = ReadU32BE fstream
		inst.UnknownField08 = ReadU32BE fstream
		inst.UnknownField0C = ReadU32BE fstream
		
		local entry = AFLResEntry.LoadFromFStream fstream
		
		while (entry.flags != 0) do
		(
			append inst.Entries entry
			
			entry = AFLResEntry.LoadFromFStream fstream
		)

		return inst
	),
	
	fn GetModelEntries =
	(
		local arr = #()
		
		for entry in Entries do
		(
			if (entry.IsModelRes()) then
			(
				append arr entry
			)
		)
		
		return arr
	),
	
	/* Static */
	fn LoadIntoMaxSceneFromFile filePath flipUp =
	(
		Print "Reading model data.."
		local fstream = fopen filePath "rb"
		local res = AFLRes.LoadFromFStream fstream
		
		Print "Loading models into scene.."
		local meshEntries = res.GetModelEntries()
		
		for meshEntry in meshEntries do
		(
			maxMesh = meshEntry.MeshData.ToMaxMesh fstream flipUp
			
			PrintDebug meshEntry
			
			--exit
		)
		
		fclose fstream
		
		Print "Done."
		
		return OK
	)
)

/* Get file to open */
global openFileName = getOpenFileName \ 
caption:"Open File" \
types:"AVLRes File(*.dat)|*.dat" \
historyCategory:"AVLRES Object Presets"

/* Determines if we need to flip the mesh from y up to z up */
global flipUpAxis = true

/* Script execution start */
clearlistener()

if (openFileName != undefined) then
(
	if (AFLResDebug) then
	(
		AFLRes.LoadIntoMaxSceneFromFile openFileName flipUpAxis
	)
	else
	(
		try
		(
			AFLRes.LoadIntoMaxSceneFromFile openFileName flipUpAxis
		)
		catch
		(
			messagebox GetCurrentException()
		)
	)	
)

gc()
