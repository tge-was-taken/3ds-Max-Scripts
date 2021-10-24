
clearlistener();
gc();

/****************/
/**** Globals ****/
/****************/

global g_debug = true;
global g_curImportPath = "";
global g_curBaseOffset = 0;
global g_applyNormals = true;

/**********************/
/**** Debug stuff *****/
/*********************/

fn printD str = 
(
	if (g_debug) then print str;
)

-- IO functions

fn GetOpenFile = 
(
	clearlistener()
	local fname = getOpenFileName \ 
	caption:"Open Model" \
	types:"Twilight Princess HD Model (*.gmx)|*.gmx" \
	historyCategory:"TPHD Object Presets"
	if (fname == undefined) then
	(
		return undefined
	)
	else
	(
		g_curImportPath = fname
		local fstream = fopen fname "rb"
		return fstream
	)
)

fn FBSeek fstrm relOffset seekMode = 
(
	fseek fstrm (g_curBaseOffset + relOffset) seekMode;
)

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

fn ReadBEVector2 fstream =
(
	return [(ReadBEFloat fstream), ((ReadBEFloat fstream) * -1) + 1, 0]
)

fn ReadBEVector3 fstream =
(
	return [(ReadBEFloat fstream), (ReadBEFloat fstream), (ReadBEFloat fstream)]
)

fn ReadFString fstream len =
(
	local s = ""
	for i = 1 to len do
	(
		s += bit.intaschar (ReadByte fstream #unsigned)
	)
	return s
)

/**************************/
/**** Structs  ************/
/*************************/

struct s_GMX_Section
(
	/*****************************/
	/**** Struct field members ****/
	/*****************************/
	
	/* 0x00 char[4] */ magic,
	/* 0x04 u32 */ size,
	
	/**************************/
	/**** Context members *****/
	/**************************/
	base_off,
	fstrm,
	
	/***************************/
	/**** Static constructor ****/
	/***************************/
	fn S_Create fstream =
	(
		inst = s_GMX_Section();
		inst.I_Create(fstream);
		return inst;
	),
	
	/*****************************/
	/**** Instance constructor ****/
	/*****************************/
	fn I_Create fstream =
	(
		base_off = ftell fstream;
		fstrm = fstream;
		magic = ReadFString fstream 4
		size = ReadBELong fstream
	)
)

struct s_VERT
(
	/*****************************/
	/**** Struct field members ****/
	/*****************************/
	
	/* 0x00 s_GMX_Section */ sectHdr,
	
	/***********************/
	/**** Array members ****/
	/***********************/
	
	/* 0x00 u32 	*/ vmapIndxArr = #(),
	/* 0x04 vec3 	*/ posArr = #(),
	/* 0x10 vec3 */ nrmArr = #(),
	/* 0x1C u32 */ clrArr = #(),
	/* 0x1C vec2 */ tex0Arr = #(),
	/* 0x24 vec2*/ tex1Arr = #(),
	
	/**************************/
	/**** Context members *****/
	/**************************/
	hasVmap = false,
	hasPos = false,
	hasNrm = false,
	hasClr = false,
	hasTex0 = false,
	hasTex1 = false,
	
	/***************************/
	/**** Static constructor ****/
	/***************************/
	fn S_Create sectHeader numVert vertSize vertFlags =
	(
		inst = s_VERT();
		inst.I_Create sectHeader numVert vertSize vertFlags;
		return inst;
	),
	
	/*****************************/
	/**** Instance constructor ****/
	/*****************************/
	fn I_Create sectHeader numVert vertSize vertFlags =
	(
		sectHdr = sectHeader;
		fstrm = sectHdr.fstrm;
		fseek fstrm (sectHdr.base_off + 0x8) #seek_set;
		
		for i = 1 to numVert do
		(
			/* TODO: vertex flags are not consistent */
			
			nextVert = ftell fstrm + vertSize;
			
			if ((bit.get vertFlags 3) == true) then
			(
				hasVmap = true;
				vmapIndxArr[i] = (ReadBELong fstrm + 1); 
			)

			hasPos = true;
			posArr[i] = ReadBEVector3 fstrm;
			
			hasNrm = true;
			nrmArr[i] = ReadBEVector3 fstrm;
			
			if ((bit.get vertFlags 5) == false) then
			(
				hasClr = true;
				clrArr[i] = ReadBELong fstrm;
			)
			
			hasTex0 = true;
			tex0Arr[i] = ReadBEVector2 fstrm;
			
			if (vertSize >= 0x2C OR (hasVmap == false AND vertSize >= 0x28)) then
			(
				hasTex1 = true;
				tex1Arr[i] = ReadBEVector2 fstrm;
			)
			
			fseek fstrm nextVert #seek_set;
		)
	)
)

struct s_INDX
(
	/*****************************/
	/**** Struct field members ****/
	/*****************************/
	
	/* 0x00 s_GMX_Section */ sectHdr,
	
	/***********************/
	/**** Array members ****/
	/***********************/
	indxArr = #(),
	
	/**************************/
	/**** Context members *****/
	/**************************/
	hasIndices = false,
	
	fn S_Create sectHeader numIndx =
	(
		inst = s_INDX();
		inst.I_Create sectHeader numIndx;
		return inst;
	),
	
	fn I_Create sectHeader numIndx =
	(
		sectHdr = sectHeader;
		fstrm = sectHdr.fstrm;
		fseek fstrm (sectHdr.base_off + 0x8) #seek_set;
		
		if (numIndx > 0) then
		(
			hasIndices = true;
		)
		
		for i = 1 to numIndx by 3 do
		(
			append indxArr [((ReadBEShort fstrm) + 1), ((ReadBEShort fstrm) + 1), ((ReadBEShort fstrm) + 1)]
		)
	)
)

struct s_MESH
(
	/*****************************/
	/**** Struct field members ****/
	/*****************************/
	
	/* 0x00 s_GMX_Section */ sectHdr,
	/* 0x08 u32 */ fld08,
	/* 0x0C u16 */ vertSize,
	/* 0x0E u16 */ numVert,
	/* 0x10 u32 */ fld10,
	/* 0x14 u32 */ numIndx,
	/* 0x18 u32 */ fld18,
	/* 0x1C u16 */ vertFlags,
	/* 0x1E u16 */ fld1E,
	/* 0x20 u32 */ fld20,	
	/* 0x24 u32 */ fld24,
	
	/**************************/
	/**** Context members *****/
	/**************************/
	vertSect,
	indxSect,
	vmapSect,
	hasVertices = false,
	hasIndices = false,
	
	/***************************/
	/**** Static constructor ****/
	/***************************/
	fn S_Create sectArray &sectIdx =
	(
		inst = s_MESH();
		inst.I_Create sectArray &sectIdx;		
		return inst;
	),
	
	/**************************/
	/**** Instance methods ****/
	/*************************/
	fn I_Create sectArray &sectIdx =
	(
		sectHdr = sectArray[sectIdx];
		fstrm = sectHdr.fstrm;
		
		fseek fstrm (sectHdr.base_off + 0x8) #seek_set;
		
		fld08 = ReadBELong fstrm;
		vertSize = ReadBEShort fstrm;
		numVert = ReadBEShort fstrm;
		fld10 = ReadBELong fstrm;
		numIndx = ReadBELong fstrm;
		fld18 = ReadBELong fstrm;
		vertFlags = ReadBEShort fstrm;
		fld1E = ReadBEShort fstrm;
		fld20 = ReadBELong fstrm;
		fld24 = ReadBELong fstrm;
		
		if (numVert > 0) then
		(
			hasVertices = true;
		)
		
		if (numIndx > 0) then
		(
			hasIndices = true;
		)
		
		sectIdx += 1; -- MESH section has been parsed, increment counter
		
		if (hasVertices AND hasIndices) then
		(
		
			/*******************************/
			/**** Parse VERTEX section ****/
			/*******************************/
			
			-- Find section index
			while (sectArray[sectIdx].magic != "VERT") do
			(
				sectIdx += 1;
			)
			
			vertSect = s_VERT.S_Create sectArray[sectIdx] numVert vertSize vertFlags;
			
			sectIdx += 1; -- VERT section has been parsed, increment counter
			
			/*****************************/
			/**** Parse INDX section ****/
			/****************************/
			
			-- Find section index
			while (sectArray[sectIdx].magic != "INDX") do
			(
				sectIdx += 1;
			)
			
			indxSect = s_INDX.S_Create sectArray[sectIdx] numIndx;
			
			sectIdx += 1; -- INDX section has been parsed, increment counter
			
			/****************************/
			/**** Parse VMAP section ****/
			/****************************/
			
			-- Find section index
			while (sectArray[sectIdx].magic != "VMAP") do
			(
				sectIdx += 1;
			)
		)
	),
	
	fn I_Print =
	(
		printd("GMX2 Mesh");
		printd("Num vertices: " + numVert as string);
		printd("Num indices: " + numIndx as string);
		printd("Vertex size: " + vertSize as string);
		printd("Vertex flags:" + (bit.intashex(vertFlags)));
		printd("");
	)
)

struct s_GMX2
(
	/*****************************/
	/**** Struct field members ****/
	/*****************************/
	
	/* 0x00 s_GMX_Section */ sectHdr,
	
	/**************************/
	/**** Context members *****/
	/**************************/
	meshArray = #(),
	
	/***************************/
	/**** Static constructor ****/
	/***************************/
	fn S_Create sectArray =
	(
		inst = s_GMX2();
		inst.I_Create(sectArray);
		return inst;
	),
	
	/**************************/
	/**** Instance methods  ****/
	/**************************/
	fn I_Create sectArray = 
	(
		sectHdr = sectArray[1];
		
		for sectIdx = 2 to sectArray.count do
		(
			case (sectArray[sectIdx].magic) of
			(
				"MESH":
				(
					append meshArray (s_MESH.S_Create sectArray &sectIdx);
				)
			)
		)
	),
	
	fn I_BuildMAXScene =
	(
		for meshSect in meshArray do
		(
			if (meshSect.hasIndices == true AND meshSect.hasVertices == true) then
			(
				msh = Mesh vertices:meshSect.vertSect.posArr faces:meshSect.indxSect.indxArr;
				msh.numTVerts = meshSect.numVert;
				buildTVFaces msh;
				for j = 1 to msh.numFaces do 
				(
					setTVFace msh j meshSect.indxSect.indxArr[j];
					setFaceSmoothGroup msh j 1;
				)

				if (meshSect.vertSect.hasTex0) then
				(
					for j = 1 to meshSect.numVert do setTVert msh j meshSect.vertSect.tex0Arr[j];
				)
				
				if (meshSect.vertSect.hasNrm AND g_applyNormals) then
				(
					for j = 1 to meshSect.numVert do setNormal msh j meshSect.vertSect.nrmArr[j];
				)
			)
		)
	),
	
	fn I_Print =
	(
		printd("GMX2 Scene");
		printd("Num meshes: " + meshArray.Count as string);
		for msh in meshArray do
		(
			msh.I_Print();
		)
	)
)

/************************/
/**** Start of script ****/
/************************/

fn CheckFile fstrm = 
(
	magic = ReadFString fstrm 4;
	fseek fstrm 0 #seek_set
	
	if (magic != "GMX2") then
	(
		return false;
	)
	else
	(
		return true;
	)
)

fn ParseSectionHdrList fstrm =
(
	sect_hdr_arr = #();
	sect_hdr = s_GMX_Section();
	
	while (sect_hdr.magic != "ENDX") do
	(
		sect_hdr = s_GMX_Section.S_Create(fstrm);		
		fseek fstrm (sect_hdr.base_off + sect_hdr.size) #seek_set;
		append sect_hdr_arr sect_hdr;
	)
	
	return sect_hdr_arr;
)

fn PrintSectionHdrs sectionArr =
(
	for sect in sectionArr do
	(
		printd sect;
	)
)

fstrm = GetOpenFile();

if (fstrm != undefined AND CheckFile(fstrm) == true) then
(
	sectionHdrs = ParseSectionHdrList(fstrm);
	
	--PrintSectionHdrs(sectionHdrs);
	
	GMX2_Scene = s_GMX2.S_Create(sectionHdrs);
	GMX2_Scene.I_Print();
	GMX2_Scene.I_BuildMAXScene();
)
else
(
	messagebox "Not a proper model file.";
)

gc()