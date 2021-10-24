
/* 
Written by TGE
Last update: 10-4-2016
If there are any issues while using the script, contact me 
*/

/* Clean up */
gc()

/* Debug stuff */
global EDBDebug = true

fn PrintDebug str =
(
	if (EDBDebug) then print str
)

/* Generic math helper stuff */
fn Clamp x minVal maxVal =
(
    if (x < minVal) then
	(
        return minVal
	)
    else if (x > maxVal) then
	(
        return maxVal
	)
    else
	(
		return x
	)
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

fn ReadS16BE fstream =
(
	return Bit.SwapBytes (ReadShort fstream #signed) 1 2
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

fn ReadBytes fstream count =
(
	local arr = #()
	
	for i = 1 to count do
	(
		arr[i] = ReadByte fstream
	)
	
	return arr
)

/* GX format reading helper functions */
fn GXReadTriangles fstream numElements = 
(
	local vtxCount = ReadU16BE fstream
	
	local primsArray = #()
	local triPrims = #()
	for i = 1 to vertDescriptorArray.Count do
	(
		primsArray[i] = #()
		triPrims[i] = #()
	)
	
	for i = 1 to vtxCount do 
	(
		for j = 1 to numElements do
		(
			primsArray[j][i] = ((ReadU16BE fstream) + 1)
		)
	)
	
	for i = 1 to vtxCount by 3 do
	(
		for j = 1 to numElements do
		(
			append triPrims[j] [primsArray[j][i], primsArray[j][i + 1], primsArray[j][i + 2]]
		)
	)
	
	return triPrims	
)

fn GXReadTriangleStrip fstream numElements = 
(
	local vtxCount = ReadU16BE fstream
	
	local primsArray = #()
	local triPrims = #()
	for i = 1 to numElements do
	(
		primsArray[i] = #()
		triPrims[i] = #()
	)
	
	for i = 1 to vtxCount do 
	(
		for j = 1 to numElements do
		(
			primsArray[j][i] = ((ReadU16BE fstream) + 1)
		)
	)
	
	for i = 3 to vtxCount do
	(
		if (mod i 2) == 0 then
		(
			for j = 1 to numElements do
			(
				append triPrims[j] [primsArray[j][i], primsArray[j][i - 1], primsArray[j][i - 2]]
			)
		)
		else
		(
			for j = 1 to numElements do
			(
				append triPrims[j] [primsArray[j][i - 2], primsArray[j][i - 1], primsArray[j][i]]
			)
		)
	)
	return triPrims	
)

fn GXGetBufferElement fstream bufferOffset attribIndex stride elementIndex =
(
	fseek fstream (bufferOffset + ((elementIndex - 1) * stride)) #seek_set

	case attribIndex of
	(
		1: return (ReadVec3BE fstream)
		
		2: 
		(
			fseek fstream 12 #seek_cur
			tex0 = [Clamp (ReadS16BE fstream as float / 32767.0) -1 1, Clamp (ReadS16BE fstream as float / 32767.0) -1 1, 0]
			
			/*
			if (tex0.X < -1) do
			(
				tex0.X += 2
			)
			
			if (tex0.X > 1) do
			(
				tex0.X -= 2
			)
			
			if (tex0.Y < 0) do
			(
				tex0.Y += 2
			)
			
			if (tex0.Y > 2) do
			(
				tex0.Y -= 2
			)
			*/
			
			if (tex0.X > 1) do
			(
				tex0.X -= 2
			)
			
			return tex0
		)
		
		3: return [ReadByte fstream #unsigned, ReadByte fstream #unsigned, ReadByte fstream #unsigned, ReadByte fstream #unsigned]
		
		/* 1 << 14 */
		4: return [ReadU16FPBE fstream 1, ReadU16FPBE fstream 1, ReadU16FPBE fstream 1]
	)
)

/* EDB Entity structs */
struct PrimitiveBankHeader
(
	/* 0x00 */ Field00, -- maybe numIndices
	/* 0x02 */ Field02, -- maybe numIndexElements
	/* 0x04 */ Field04,
	/* 0x06 */ Field06,
	/* 0x08 */ PrimBankSize,
	/* 0x0C */ Field0C,
	/* 0x10 */ Field10,
	/* 0x14 */ Field14,
	/* 0x18 */ Field18,
	/* 0x1C */ Field1C,
	/********/ PrimBankOffset,
	
	fn ReadFromFStream fstream =
	(
		Field00 		= ReadU16BE fstream
		Field02 		= ReadU16BE fstream
		Field04 		= ReadU16BE fstream
		Field06 		= ReadU16BE fstream
		PrimBankSize 	= ReadU32BE fstream
		Field0C 		= ReadU32BE fstream
		Field10 		= ReadU32BE fstream
		Field14 		= ReadU32BE fstream
		Field18 		= ReadU32BE fstream
		Field1C 		= ReadU32BE fstream
		PrimBankOffset 	= ftell fstream
	)
)

struct Entity
(
	/* 0x00 */ Field00,
	/* 0x04 */ HashCode,
	/* 0x08 */ Data08,
	/* 0x50 */ Field50,
	/* 0x54 */ Field54,
	/* 0x58 */ PrimBankHeaderOffset,
	/********/ PrimBankHeader = PrimitiveBankHeader(),
	/* 0x5C */ VertexBufferOffset, 
	/* 0x60 */ NormalBufferOffset,
	/* 0x64 */ ColorBufferOffset, 
	/* 0x68 */ Field68, 
	/* 0x6C */ Field6C,
	/* 0x70 */ Field70,
	/* 0x74 */ Field74,
	/* 0x78 */ Field78,
	/* 0x7C */ Field7C, 
	/* 0x80 */ NumVertices,
	/* 0x84 */ Field84,
	/* 0x88 */ Field88, 
	/* 0x8C */ Field8C,
	/* 0x90 */ Field90,
	/* 0x94 */ Field94,
	/* 0x98 */ Field98,
	/* 0x9C */ Field9C,
	
	fn ReadFromFStream fstream =
	(
		Field00 				= ReadU32BE fstream
		HashCode 				= ReadU32BE fstream
		Data08 					= ReadBytes fstream 72
		Field50 				= ReadU32BE fstream
		Field54 				= ReadU32BE fstream
		PrimBankHeaderOffset	= ftell fstream + ReadU32BE fstream
		VertexBufferOffset 		= ftell fstream + ReadU32BE fstream
		NormalBufferOffset 		= ftell fstream + ReadU32BE fstream
		ColorBufferOffset 		= ftell fstream + ReadU32BE fstream
		Field68 				= ReadU32BE fstream
		Field6C 				= ReadU32BE fstream
		Field70 				= ReadU32BE fstream
		Field74 				= ReadU32BE fstream
		Field78 				= ReadU32BE fstream
		Field7C 				= ReadU32BE fstream
		NumVertices 			= ReadU32BE fstream
		Field84 				= ReadU32BE fstream
		Field88 				= ReadU32BE fstream
		Field8C 				= ReadU32BE fstream
		Field90 				= ReadU32BE fstream
		Field94 				= ReadU32BE fstream
		Field98 				= ReadU32BE fstream
		Field9C 				= ReadU32BE fstream
		
		PrintDebug(Field7C)
		
		if (PrimBankHeaderOffset != 0) then
		(
			-- save cur pos
			local returnPosition = ftell fstream
			
			-- seek to data
			fseek fstream PrimBankHeaderOffset #seek_set
			
			-- read
			PrimBankHeader.ReadFromFStream fstream
			
			-- seek back
			fseek fstream returnPosition #seek_set
		)
	),
	
	fn ReadPrimitives fstream =
	(
		fseek fstream PrimBankHeader.PrimBankOffset #seek_set
		
		local primArray = #()
		local primEnd = PrimBankHeader.PrimBankOffset + PrimBankHeader.PrimBankSize
		local numVertexAttribs = 4
		
		while ((ftell fstream) < primEnd) do
		(
			cmd = ReadU16BE fstream
			case (cmd) of
			(
				0x00:() -- NOP
				0x90: -- GX_TRIANGLES
				append primArray (GXReadTriangles fstream numVertexAttribs)
				0x98: -- GX_TRIANGLESTRIP
				append primArray (GXReadTriangleStrip fstream numVertexAttribs)
				default:
				(
					print("Unknown GX command: " + cmd as string)
					fseek fstream primEnd #seek_set
				)
			)
		)
		
		return primArray
	),
	
	fn ReadVertexBuffer fstream &posArray &tex0Array =
	(
		fseek fstream VertexBufferOffset #seek_set
		
		for vtxIdx = 1 to NumVertices do
		(
			posArray[vtxIdx] = ReadVec3BE fstream
			tex0Array[vtxIdx] = [ReadF16BE fstream, (ReadF16BE fstream * -1) + 1, 0]
		)
	),
	
	fn ToMaxObject fstream =
	(
		local NUM_VERT_ATTRIBUTES = 4
		
		-- Declare arrays
		local primArray = ReadPrimitives fstream
		local posArray	= #()
		local tex0Array = #()
		local clr0Array = #()
		local nrmArray	= #()
		
		-- define buffer strides
		local VERTEX_BUFFER_STRIDE	= 16
		local NORMAL_BUFFER_STRIDE	= 6
		local COLOR_BUFFER_STRIDE	= 4
		
		for i = 1 to primArray.Count do
		(
			for j = 1 to NUM_VERT_ATTRIBUTES do
			(
				case (j) of
				(
					1: -- GX_VA_POS
					for k = 1 to primArray[i][j].Count do
					(
						append posArray ((GXGetBufferElement fstream VertexBufferOffset j VERTEX_BUFFER_STRIDE primArray[i][j][k][1]))
						append posArray ((GXGetBufferElement fstream VertexBufferOffset j VERTEX_BUFFER_STRIDE primArray[i][j][k][2]))
						append posArray ((GXGetBufferElement fstream VertexBufferOffset j VERTEX_BUFFER_STRIDE primArray[i][j][k][3]))
					)
					
					2: -- GX_VA_TEX0
					for k = 1 to primArray[i][j].Count do
					(
						append tex0Array ((GXGetBufferElement fstream VertexBufferOffset j VERTEX_BUFFER_STRIDE primArray[i][j][k][1]))
						append tex0Array ((GXGetBufferElement fstream VertexBufferOffset j VERTEX_BUFFER_STRIDE primArray[i][j][k][2]))
						append tex0Array ((GXGetBufferElement fstream VertexBufferOffset j VERTEX_BUFFER_STRIDE primArray[i][j][k][3]))
					)
					
					3: -- GX_VA_CLR0
					for k = 1 to primArray[i][j].Count do
					(
						append clr0Array ((GXGetBufferElement fstream ColorBufferOffset j COLOR_BUFFER_STRIDE primArray[i][j][k][1]))
						append clr0Array ((GXGetBufferElement fstream ColorBufferOffset j COLOR_BUFFER_STRIDE primArray[i][j][k][2]))
						append clr0Array ((GXGetBufferElement fstream ColorBufferOffset j COLOR_BUFFER_STRIDE primArray[i][j][k][3]))
					)
					
					4: -- GX_VA_NRM
					for k = 1 to primArray[i][j].Count do
					(
						append nrmArray ((GXGetBufferElement fstream NormalBufferOffset j NORMAL_BUFFER_STRIDE primArray[i][j][k][1]))
						append nrmArray ((GXGetBufferElement fstream NormalBufferOffset j NORMAL_BUFFER_STRIDE primArray[i][j][k][2]))
						append nrmArray ((GXGetBufferElement fstream NormalBufferOffset j NORMAL_BUFFER_STRIDE primArray[i][j][k][3]))
					)
				)
			)
		)
		
		--print tex0Array
		--print nrmArray
		
		local faceArray = #()
		
		for i = 1 to posArray.Count by 3 do
		(
			append faceArray [i, i + 1, i + 2]
		)
		
		maxMesh = mesh vertices:posArray faces:faceArray tverts:tex0Array
		
		if (tex0Array.Count > 0) then
		(
			buildTVFaces maxMesh
			for j = 1 to faceArray.count do setTVFace maxMesh j faceArray[j]
		)
		
		--for j = 1 to nrmArray.count do setNormal maxMesh j nrmArray[j]
		for j = 1 to maxMesh.numfaces do setFaceSmoothGroup maxMesh j 1
	)
)

/* EDB table entry structs */
struct EntitiesTableEntry
(
	/* 0x00 */ ID,
	/* 0x04 */ DataOffset,
	/********/ Data = Entity(),
	/* 0x08 */ Field08,
	/* 0x0C */ Field0C,
	/* 0x10 */ HashCode,
	
	fn Clone =
	(
		local new 		= EntitiesTableEntry()
		
		new.ID 			= ID
		new.DataOffset 	= DataOffset
		new.Field08 	= Field08
		new.Field0C		= Field0C
		new.HashCode 	= HashCode
		
		return new
	),
	
	fn ReadFromFStream fstream =
	(
		ID 			= ReadU32BE fstream
		DataOffset 	= ReadU32BE fstream
		Field08 	= ReadU32BE fstream
		Field0C		= ReadU32BE fstream
		HashCode 	= ReadU32BE fstream
		
		if (DataOffset != 0) then
		(
			-- save cur pos
			local returnPosition = ftell fstream
			
			-- seek to data
			fseek fstream DataOffset #seek_set
			
			-- read
			Data.ReadFromFStream fstream
			
			-- seek back
			fseek fstream returnPosition #seek_set
		)
	)
)

/* EDBFile struct */
global EDBMagic = 0x47454F4D

struct EDBFile
(
	/* 0x04 */ HashCode,
	/* 0x08 */ Version,
	/* 0x0C */ Field0C,
	/* 0x10 */ FileTime,
	/* 0x14 */ FileSize,
	/* 0x18 */ FileRealSize,
	/* 0x1C */ Field1C,
	/* 0x20 */ Field20,
	/* 0x24 */ Field24,
	/* 0x28 */ Field28,
	/* 0x2C */ Field2C,
	/* 0x30 */ Field30,
	/* 0x34 */ FileSizeAux,
	/* 0x38 */ FileMemSize,
	/* 0x3C */ Field3C,
	/* 0x40 */ Field40,
	/* 0x44 */ Field44,
	/* 0x48 */ Field48,
	/* 0x4C */ Field4C,
	/* 0x50 */ Field50,
	
	/****************/
	/*** Sections ***/
	/****************/
	/* 0x54 */ NumSections,
	/* 0x56 */ Field56,
	/* 0x58 */ SectionsTableOffset,
	/********/ SectionsTable = #(),
	
	/***************/
	/*** Unknown ***/
	/***************/
	/* 0x5C */ Field5C,	
	/* 0x5E */ Field5E, 
	/* 0x60 */ Field60,
	
	/****************/
	/*** Entities ***/
	/****************/
	/* 0x64 */ NumEntities,
	/* 0x66 */ Field68,
	/* 0x68 */ EntitiesTableOffset,
	/********/ EntitiesTable = #(),
	
	/******************/
	/*** Animations ***/
	/******************/
	/* 0x6C */ NumAnimations,
	/* 0x6E */ Field6E,
	/* 0x70 */ AnimationsTableOffset,
	/********/ AnimationsTable = #(),
	
	/*****************/
	/*** AnimSkins ***/
	/*****************/
	/* 0x74 */ NumAnimSkins,
	/* 0x76 */ Field76,
	/* 0x78 */ AnimSkinsTableOffset,
	/********/ AnimSkinsTable = #(),
	
	/****************/
	/*** Scripts ****/
	/****************/
	/* 0x7C */ NumScripts,
	/* 0x7E */ Field7E,
	/* 0x80 */ ScriptsTableOffset,
	/********/ ScriptsTable = #(),
	
	/************/
	/*** Maps ***/
	/************/
	/* 0x84 */ NumMaps,
	/* 0x86 */ Field86,
	/* 0x88 */ MapsTableOffset,
	/********/ MapsTable = #(),
	
	/*****************/
	/*** AnimNodes ***/
	/*****************/
	/* 0x8C */ NumAnimNodes,
	/* 0x8E */ Field8E,
	/* 0x90 */ AnimNodesTableOffset,
	/********/ AnimNodesTable = #(),
	
	/****************/
	/*** AnimSets ***/
	/****************/
	/* 0x94 */ NumAnimSets,
	/* 0x96 */ Field96,
	/* 0x98 */ AnimSetsTableOffset,
	/********/ AnimSetsTable = #(),
	
	/****************/
	/*** Particles ***/
	/****************/
	/* 0x9C */ NumParticles,
	/* 0x9E */ Field9E,
	/* 0xA0 */ ParticlesTableOffset,
	/********/ ParticlesTable = #(),
	
	/****************/
	/*** Swooshs ***/
	/****************/
	/* 0xA4 */ NumSwooshs,
	/* 0xA6 */ FieldA6,
	/* 0xA8 */ SwooshsTableOffset,
	/********/ SwooshsTable = #(),
	
	/****************/
	/*** SpreadSts ***/
	/****************/
	/* 0xAC */ NumSpreadSts,
	/* 0xAE */ FieldAE,
	/* 0xB0 */ SpreadStsTableOffset,
	/********/ SpreadStsTable = #(),
	
	/****************/
	/*** Fonts ***/
	/****************/
	/* 0xB4 */ NumFonts,
	/* 0xB6 */ FieldB6,
	/* 0xB8 */ FontsTableOffset,
	/********/ FontsTable = #(),
	
	/***************/
	/*** Unknown ***/
	/***************/
	/* 0xBC */ FieldBC,	
	/* 0xBE */ FieldBE, 
	/* 0xC0 */ FieldC0,
	
	/****************/
	/*** Textures ***/
	/****************/
	/* 0xC4 */ NumTextures,
	/* 0xC6 */ FieldC6,
	/* 0xC8 */ TexturesTableOffset,
	/********/ TexturesTable = #(),
	
	/* Static */
	fn LoadFromFile pathToFile =
	(
		-- open file
		local fstream = fopen pathToFile "rb"
		
		-- create instance and read data
		local edb = EDBFile()
		edb.ReadFromFStream fstream
		
		-- close file
		fclose fstream
		
		return edb
	),
	
	fn ReadFromFStream fstream =
	(
		local magic = ReadU32BE fstream
		
		if (magic != EDBMagic) then
		(
			throw "Magic value does not match.\nInvalid EDB file."
		)
		
		/* General header stuff */
		HashCode 		= ReadU32BE fstream
		Version 		= ReadU32BE fstream
		Field0C 		= ReadU32BE fstream
		FileTime 		= ReadU32BE fstream
		FileSize 		= ReadU32BE fstream
		FileRealSize 	= ReadU32BE fstream
		Field1C 		= ReadU32BE fstream
		Field20 		= ReadU32BE fstream
		Field24 		= ReadU32BE fstream
		Field28 		= ReadU32BE fstream
		Field2C 		= ReadU32BE fstream
		Field30 		= ReadU32BE fstream
		FileSizeAux 	= ReadU32BE fstream
		FileMemSize		= ReadU32BE fstream
		Field3C	 		= ReadU32BE fstream
		Field40 		= ReadU32BE fstream
		Field44 		= ReadU32BE fstream
		Field48 		= ReadU32BE fstream
		Field4C 		= ReadU32BE fstream
		Field50 		= ReadU32BE fstream
		
		/* Sections */
		NumSections 			= ReadU16BE fstream
		Field56 				= ReadU16BE fstream
		SectionsTableOffset 	= ReadU32BE fstream + ftell fstream
		
		/* Unknown */
		Field5C					= ReadU16BE fstream
		Field5E 				= ReadU16BE fstream
		Field60 				= ReadU32BE fstream
		
		/* Entities */
		NumEntities 			= ReadU16BE fstream
		Field68 				= ReadU16BE fstream
		EntitiesTableOffset		= ReadU32BE fstream + ftell fstream
		
		if (NumEntities > 0) then
		(
			local element = EntitiesTableEntry()
			EntitiesTable = EDBFile.ReadTable EntitiesTableOffset NumEntities &element fstream
		)
		
		/* Animations */
		NumAnimations 			= ReadU16BE fstream
		Field6E 				= ReadU16BE fstream
		AnimationsTableOffset 	= ReadU32BE fstream + ftell fstream
		
		/* AnimSkins */
		NumAnimSkins 			= ReadU16BE fstream
		Field76 				= ReadU16BE fstream
		AnimSkinsTableOffset	= ReadU32BE fstream + ftell fstream
		
		/* Scripts */
		NumScripts 				= ReadU16BE fstream
		Field7E 				= ReadU16BE fstream
		ScriptsTableOffset 		= ReadU32BE fstream + ftell fstream
		
		/* Maps */
		NumMaps 				= ReadU16BE fstream
		Field86 				= ReadU16BE fstream
		MapsTableOffset 		= ReadU32BE fstream + ftell fstream
		
		/* AnimNodes */
		NumAnimNodes 			= ReadU16BE fstream
		Field8E 				= ReadU16BE fstream
		AnimNodesTableOffset	= ReadU32BE fstream + ftell fstream
		
		/* AnimSets */
		NumAnimSets				= ReadU16BE fstream
		Field96 				= ReadU16BE fstream
		AnimSetsTableOffset		= ReadU32BE fstream + ftell fstream
		
		/* Particles */
		NumParticles			= ReadU16BE fstream
		Field9E 				= ReadU16BE fstream
		ParticlesTableOffset	= ReadU32BE fstream + ftell fstream
		
		/* Swooshs */
		NumSwooshs				= ReadU16BE fstream
		FieldA6 				= ReadU16BE fstream
		SwooshsTableOffset		= ReadU32BE fstream + ftell fstream
		
		/* SpreadSts */
		NumSpreadSts			= ReadU16BE fstream
		FieldAE 				= ReadU16BE fstream
		SpreadStsTableOffset	= ReadU32BE fstream + ftell fstream
		
		/* Fonts */
		NumFonts				= ReadU16BE fstream
		FieldB6					= ReadU16BE fstream
		FontsTableOffset		= ReadU32BE fstream + ftell fstream
		
		/* Unknown */
		FieldBC					= ReadU16BE fstream
		FieldBE 				= ReadU16BE fstream
		FieldC0 				= ReadU32BE fstream + ftell fstream
		
		/* Textures */
		NumTextures				= ReadU16BE fstream
		FieldC6					= ReadU16BE fstream
		TexturesTableOffset		= ReadU32BE fstream + ftell fstream
		
		for entityEntry in EntitiesTable do
		(
			entityEntry.Data.ToMaxObject fstream
		)
	),
	
	/* Static */
	fn ReadTable offset numElements &element fstream =
	(
		-- save current position
		local returnPosition = ftell fstream
		
		-- seek to new position
		fseek fstream offset #seek_set
		
		-- read entries
		local table = #()
		
		for i = 1 to numElements do
		(
			element.ReadFromFStream fstream
			append table element
			
			element = element.Clone()
		)
		
		-- seek back
		fseek fstream returnPosition #seek_set
		
		return table
	)
)

--global filePath = @"D:\Games\Gamecube_Wii\Spyro A Heros Tail\root\Filelist\spyro\binary\_bin_gc\c43_r3b.edb"
--global filePath = @"D:\Games\Gamecube_Wii\Spyro A Heros Tail\root\Filelist\spyro\binary\_bin_gc\professo.edb"
--global filePath = @"D:\Games\Gamecube_Wii\Spyro A Heros Tail\root\Filelist\spyro\binary\_bin_gc\crow.edb"
global filePath = @"D:\Games\Nintendo Gamecube & Wii\Spyro A Heros Tail\root\Filelist\spyro\binary\_bin_gc\hunter.edb"

global edb = EDBFile.LoadFromFile filePath

-- /* Get file to open */
-- global openFileName = getOpenFileName \ 
-- caption:"Open File" \
-- types:"EDB File(*.edb)|*.edb" \
-- historyCategory:"EDBGC Object Presets"

-- /* Determines if we need to flip the mesh from y up to z up */
-- global EDBFlipUpAxis = true

-- /* Script execution start */
-- clearlistener()

-- if (openFileName != undefined) then
-- (
-- 	if (EDBDebug) then
-- 	(
-- 		AFLRes.LoadIntoMaxSceneFromFile openFileName flipUpAxis
-- 	)
-- 	else
-- 	(
-- 		try
-- 		(
-- 			AFLRes.LoadIntoMaxSceneFromFile openFileName flipUpAxis
-- 		)
-- 		catch
-- 		(
-- 			messagebox GetCurrentException()
-- 		)
-- 	)	
-- )

gc()
