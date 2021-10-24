
gc()
enableSceneRedraw()
clearlistener()

global globalStartTime = timestamp()
global globalImportedFilePath = ""
global globalBoolApplyNormals = false
global globalBoolApplySkinning = false

-- Structs --

struct RenderBlockModelStruct
(
	magic 		= "RBMDL", -- const string "RBMDL"
	verMajor 	= 1,			-- const uint 1
	verMinor		= 13,			-- const uint 13
	verRev		= 0,			-- const uint 0
	bbMin		= [0,0,0], 	-- point3
	bbMax		= [0,0,0],	-- point3
	numBlocks	= 0,			-- uint
	blockArray	= #()		-- array of RenderBlockStruct
)

struct RenderBlockStruct
(
	type				= 0, 					-- uint
	data				= undefined,		-- struct corresponding to type
	footerMagic	= 0x89ABCDEF 	-- const uint 0x89ABCDEF
)

struct MaterialStruct
(
	diffuseMapName			= "dummy_dif.dds",	-- uint length + string
	normalMapName			= "dummy_nrm.dds",	-- uint length + string
	propMapName				= "dummy_mpm.dds",	-- uint length + string
	defDiffuseMapName		= "",	-- uint length + string
	defNormalMapName		= "",	-- uint length + string
	defPropMapName			= "",	-- uint length + string
	normalMapExtraName	= "",	-- uint length + string
	shadowMapName			= "",	-- uint length + string
	unknown 					= 3	-- const uint 3
)

struct SkinnedGeneralStruct
(
	version				= 3, 						-- byte
	flags					= 0x100000, 			-- uint
	unk1 					= [10,1,1], 			-- point3
	unk2					= [1,1,1],				-- point3
	materialData 		= MaterialStruct(), 	-- MaterialStruct
	vertexArray1		= #(),					-- array of vertex struct depending on the flags
	vertexArray2		= #(),					-- array of vertex struct depending on the flags
	skinBatchArray	= #(),					-- array of SkinBatchStruct
	faceArray			= #()					-- array of ushort face indices
)

struct SkinnedGeneralVertex0SmallStruct
(
	position			= [0,0,0], 		-- point3
	boneWeights	= [0,0,0,0], 	-- byte point4
	boneIds 			= [0,0,0,0]		-- byte point4
)

struct SkinnedGeneralVertex0BigStruct
(
	position			= [0,0,0], 		-- point3
	boneWeights	= [0,0,0,0], 	-- byte point4
	boneIds			= [0,0,0,0], 	-- byte point4
	unk2				= [0,0,0,0], 	-- byte point4
	unk3				= [0,0,0,0] 	-- byte point4
)

struct SkinnedGeneralVertex1Struct
(
	normal		= [0,0,0,0],		-- packed point4
	tangent		= [0,0,0,0],		-- packed point4
	binormal		= [0,0,0,0],		-- packed point4
	texCoord	= [0,0,0]			-- point2
)

struct SkinnedGeneralSkinBatchStruct
(
	faceCount		= 0,		-- uint
	faceIndex		= 0,		-- uint
	boneCount		= 0,		-- uint
	boneIdxArray	= #()	-- array of short bone indices
)

struct ProceduralMesh
(
	positionArray		= #(),
	normalArray		= #(),
	tangentArray		= #(),
	binormalArray		= #(),
	texCoordArray		= #(),
	boneIndexArray	= #(),
	boneWeightArray	= #(),
	faceArray			= #(),
	skinMod
)

--*** General helper functions ***--

fn GetOpenFile = 
(
	clearlistener()
	local fname = getOpenFileName \ 
	caption:"Open Model" \
	types:"Render Block Model (*.rbm)|*.rbm" \
	historyCategory:"JC2RBM Object Presets"
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

fn GetSaveFile = 
(
	local fname = getSaveFileName \ 
	caption:"Save Model" \
	types:"Render Block Model (*.rbm)|*.rbm" \
	historyCategory:"JC2RBM Object Presets"
	if (fname == undefined) then
	(
		return undefined
	)
	else
	(
		local f = fopen fname "wb"
		return f
	)
)

fn GetFloatFromByte fstream =
(
	local val = (((ReadByte fstream #unsigned) as float) / 0x80)
	val -= 1
	return val
)

fn GetByteFromFloat fVal =
(
	val = fval + 1
	val = (val * 0x80) as integer
	return val
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

fn GetSceneMeshArray =
(
	meshArray = #()
	for msh in objects do
	(
		if superclassof msh == GeometryClass and ClassOf msh == Editable_mesh then
		(
			append meshArray msh
		)
	)
	return meshArray
)

fn GetMeshSkinMod msh =
(
	for m in msh.modifiers do
	(
		if (m.name == "Skin") then
		(
			return m
		)
	)
	return undefined
)

fn ExpandVector3 p3 lastElement =
(
	return [p3[1], p3[2], p3[3], lastElement]
)

-- Allocate an array with numElements elements of type element
fn AllocateArray element numElements =
(
	local arr = #()
	arr[numElements] = element
	for i = 1 to numElements do
	(
		arr[i] = element
	)
	return arr
)

fn SplitSkinnedGeneralVertex0Struct vStructArray &vtxArray &boneIdsArray &boneWeightsArray =
(
	vtxArray = #()
	boneIdsArray = #()
	boneWeightsArray = #()
	for vStruct in vStructArray do
	(
		append vtxArray vStruct.position
		append boneIdsArray vStruct.boneIds
		append boneWeightsArray vStruct.boneWeights
	)
)

fn SplitSkinnedGeneralVertex1Struct vStructArray &normalArray &texCoordArray =
(
	normalArray = #()
	texCoordArray = #()
	for vStruct in vStructArray do
	(
		append normalArray vStruct.normal
		append texCoordArray vStruct.texCoord
	)
)

--*** Reading functions ***--

fn ReadFString fstream len =
(
	local s = ""
	for i = 1 to len do
	(
		s += bit.intaschar (ReadByte fstream #unsigned)
	)
	return s
)

fn ReadPrefixString fstream =
(
	local len = ReadLong fstream #unsigned
	return (ReadFString fstream len)
)

fn ReadULong fstream =
(
	return (ReadLong fstream #unsigned)
)

fn ReadUByte fstream =
(
	return (ReadByte fstream #unsigned)
)

fn ReadUShort fstream =
(
	return (ReadShort fstream #unsigned)
)

fn ReadVector2 fstream = 
(
	return [(ReadFloat fstream), ((ReadFloat fstream) * -1) + 1, 0]
)

fn ReadVector3 fstream = 
(
	return [(ReadFloat fstream), (ReadFloat fstream), (ReadFloat fstream)]
)

fn ReadVector4Byte fstream =
(
	return [(ReadUByte fstream), (ReadUByte fstream), (ReadUByte fstream), (ReadUByte fstream)]
)

fn ReadVector4Packed fstream =
(
	return [(GetFloatFromByte fstream), (GetFloatFromByte fstream), (GetFloatFromByte fstream), (GetFloatFromByte fstream)]
)


--*** Structure reading functions ***--

fn ReadFaces fstream =
(
	local fArray = #()
	local count = (ReadULong fstream) / 3
	fArray[count] = 0
	
	for i = 1 to count do
	(
		fArray[i] = [(ReadUShort fstream) + 1, (ReadUShort fstream) + 1, (ReadUShort fstream) + 1]
	)
	return fArray
)

fn ReadSkinnedGeneralSkinBatch fstream =
(
	local sbArray = #()
	local sbCount = ReadULong fstream
	sbArray[sbCount] = 0
	
	for i = 1 to sbCount do
	(
		sbArray[i] = SkinnedGeneralSkinBatchStruct()
		sbArray[i].faceCount = ReadULong fstream
		sbArray[i].faceIndex = ReadULong fstream
		sbArray[i].boneCount = ReadULong fstream
		sbArray[i].boneIdxArray = #()
		for j = 1 to sbArray[i].boneCount do
		(
			sbArray[i].boneIdxArray[j] = ReadShort fstream
		)
	)
	return sbArray
)

fn ReadSkinnedGeneralVertex1 fstream =
(
	local vArray = #()
	local count = ReadULong fstream
	vArray[count] = 0
	
	for i = 1 to count do
	(
		vArray[i] = SkinnedGeneralVertex1Struct()
		vArray[i].normal = ReadVector4Packed fstream
		vArray[i].tangent = ReadVector4Packed fstream
		vArray[i].binormal = ReadVector4Packed fstream
		vArray[i].texCoord = ReadVector2 fstream
	)
	return vArray
)

fn ReadSkinnedGeneralVertex0Big fstream =
(
	local vArray = #()
	local count = ReadULong fstream
	vArray[count] = 0
	
	for i = 1 to count do
	(
		vArray[i] = SkinnedGeneralVertex0BigStruct()
		vArray[i].position = ReadVector3 fstream
		vArray[i].boneWeights = ReadVector4Byte fstream
		vArray[i].boneIds = ReadVector4Byte fstream
		vArray[i].unk2 = ReadVector4Byte fstream
		vArray[i].unk3 = ReadVector4Byte fstream
		
		--print ("vArray[i].unk2 = " + vArray[i].unk2 as string)
		--print ("vArray[i].unk3 = " + vArray[i].unk3 as string)
	)
	
	return vArray
)

fn ReadSkinnedGeneralVertex0Small fstream =
(
	local vArray = #()
	local count = ReadULong fstream
	vArray[count] = 0
	
	for i = 1 to count do
	(
		vArray[i] = SkinnedGeneralVertex0SmallStruct()
		vArray[i].position = ReadVector3 fstream
		vArray[i].boneWeights = ReadVector4Byte fstream
		vArray[i].boneIds = ReadVector4Byte fstream
	)
	
	return vArray
)

fn ReadMaterial fstream =
(
	m = MaterialStruct()
	m.diffuseMapName = ReadPrefixString fstream
	m.normalMapName = ReadPrefixString fstream
	m.propMapName = ReadPrefixString fstream
	m.defDiffuseMapName = ReadPrefixString fstream
	m.defNormalMapName = ReadPrefixString fstream
	m.defPropMapName = ReadPrefixString fstream
	m.normalMapExtraName = ReadPrefixString fstream
	m.shadowMapName = ReadPrefixString fstream
	m.unknown = ReadULong fstream
	return m
)

fn ReadSkinnedGeneral fstream = 
(
	local s = SkinnedGeneralStruct()
	s.version = ReadUByte fstream
	s.flags = ReadULong fstream
	s.unk1 = ReadVector3 fstream
	s.unk2 = ReadVector3 fstream
	s.materialData = ReadMaterial fstream
	if ((s.version >= 3) AND ((bit.and s.flags 0x80000) == 0x80000)) then
	(
		s.vertexArray1 = ReadSkinnedGeneralVertex0Big fstream
	)
	else
	(
		s.vertexArray1 = ReadSkinnedGeneralVertex0Small fstream
	)
	s.vertexArray2 = ReadSkinnedGeneralVertex1 fstream
	s.skinBatchArray = ReadSkinnedGeneralSkinBatch fstream
	s.faceArray = ReadFaces fstream
	return s
)

fn ReadRenderBlock fstream =
(
	local b = RenderBlockStruct()
	b.type = ReadULong fstream
	
	case (b.type) of
	(
		0x5E657F20:
		(
			b.data = ReadSkinnedGeneral fstream
		)
	)
	b.footerMagic = ReadULong fstream
	
	return b
)

fn ReadRenderBlockModel fstream = 
(
	local h = RenderBlockModelStruct()
	h.magic = ReadPrefixString fstream
	h.verMajor = ReadULong fstream
	h.verMinor = ReadULong fstream
	h.verRev = ReadULong fstream
	h.bbMin = ReadVector3 fstream
	h.bbMax = ReadVector3 fstream
	h.numBlocks = ReadULong fstream
	--h.numBlocks = 1
	for i = 1 to h.numBlocks do
	(
		h.blockArray[i] = ReadRenderBlock fstream
	)
	return h
)

--*** Writing functions ***--

fn WritePrefixString fstream stringValue =
(
	WriteLong fstream stringValue.count
	
	for i = 1 to stringValue.count do
	(
		WriteByte fstream (bit.CharAsInt stringValue[i])
	)
)

fn WriteVector2 fstream vec =
(
	WriteFloat fstream vec.X
	WriteFloat fstream ((vec.Y * -1) - 1)
)

fn WriteVector3 fstream vec =
(
	WriteFloat fstream vec.X
	WriteFloat fstream vec.Y
	WriteFloat fstream vec.Z
)

fn WriteVector4Byte fstream vec =
(
	WriteByte fstream vec.X; WriteByte fstream vec.Y; WriteByte fstream vec.Z; WriteByte fstream vec.W
)

fn WriteVector4Packed fstream vec =
(
	WriteByte fstream (GetByteFromFloat vec.X)
	WriteByte fstream (GetByteFromFloat vec.Y)
	WriteByte fstream (GetByteFromFloat vec.Z)
	WriteByte fstream (GetByteFromFloat vec.W)
)

--*** Structure writing functions ***--

fn WriteMaterial fstream mat =
(
	WritePrefixString 	fstream mat.diffuseMapName
	WritePrefixString 	fstream mat.normalMapName
	WritePrefixString 	fstream mat.propMapName
	WritePrefixString 	fstream mat.defDiffuseMapName
	WritePrefixString 	fstream mat.defNormalMapName
	WritePrefixString 	fstream mat.defPropMapName
	WritePrefixString 	fstream mat.normalMapExtraName
	WritePrefixString 	fstream mat.shadowMapName
	WriteLong 			fstream mat.unknown
)

fn WriteSkinnedGeneralVertex0Big fstream vArray =
(
	WriteLong fstream vArray.Count
	for v in vArray do
	(
		WriteVector3 		fstream v.position
		WriteVector4Byte	fstream v.boneWeights
		WriteVector4Byte	fstream v.boneIds
		--WriteVector4Byte	fstream v.unk2
		--WriteVector4Byte	fstream v.unk3
		WriteVector4Byte	fstream [0,0,0,0]
		WriteVector4Byte	fstream [0,0,0,0]
	)
)

fn WriteSkinnedGeneralVertex0Small fstream vArray =
(
	WriteLong fstream vArray.Count
	for v in vArray do
	(
		WriteVector3 		fstream v.position
		WriteVector4Byte	fstream v.boneWeights
		WriteVector4Byte	fstream v.boneIds
	)
)

fn WriteSkinnedGeneralVertex1 fstream vArray =
(
	WriteLong fstream vArray.Count
	for v in vArray do
	(
		WriteVector4Packed fstream v.normal
		WriteVector4Packed fstream v.tangent
		WriteVector4Packed fstream v.binormal
		WriteVector2			fstream v.texCoord
	)
)

fn WriteSkinnedGeneralSkinBatch fstream sbArray =
(
	WriteLong fstream sbArray.Count
	for sb in sbArray do
	(
		WriteLong fstream sb.faceCount
		WriteLong fstream sb.faceIndex
		WriteLong fstream sb.boneIdxArray.Count
		for idx in sb.boneIdxArray do
		(
			WriteShort fstream idx
		)
	)
)

fn WriteFaces fstream fArray =
(
	WriteLong fstream (fArray.Count * 3)
	for face in fArray do
	(
		WriteShort fstream (face[1] - 1)
		WriteShort fstream (face[2] - 1)
		WriteShort fstream (face[3] - 1)
	)
)

fn WriteSkinnedGeneral fstream skn =
(
	WriteByte 								fstream skn.version
	WriteLong 								fstream skn.flags
	WriteVector3							fstream skn.unk1
	WriteVector3							fstream skn.unk2
	WriteMaterial							fstream skn.materialData
	
	if ((skn.version >= 3) AND ((bit.and skn.flags 0x80000) == 0x80000)) then
	(
		WriteSkinnedGeneralVertex0Big		fstream skn.vertexArray1
	)
	else
	(
		WriteSkinnedGeneralVertex0Small	fstream skn.vertexArray1
	)
	
	WriteSkinnedGeneralVertex1		fstream skn.vertexArray2
	WriteSkinnedGeneralSkinBatch	fstream skn.skinBatchArray
	WriteFaces								fstream skn.faceArray
)

fn WriteRenderBlock fstream rb =
(
	WriteLong fstream rb.type
	
	case (rb.type) of
	(
		0x5E657F20:
		(
			WriteSkinnedGeneral fstream rb.data
		)
	)
	
	--WriteLong fstream rb.footerMagic -- Why won't it write this correctly??
	WriteByte fstream 0xEF
	WriteByte fstream 0xCD
	WriteByte fstream 0xAB
	WriteByte fstream 0x89
)

fn WriteRenderBlockModel fstream rbm =
(
	WritePrefixString 	fstream rbm.magic
	WriteLong 			fstream rbm.verMajor
	WriteLong 			fstream rbm.verMinor
	WriteLong 			fstream rbm.verRev
	WriteVector3		fstream rbm.bbMin
	WriteVector3		fstream rbm.bbMax
	WriteLong			fstream rbm.numBlocks
	
	for rb in rbm.blockArray do
	(
		WriteRenderBlock fstream rb
	)
)

--*** Mesh building functions ***--

fn BuildMeshFromArrays posArray faceArray texCoordArray nrmArray =
(
	newMesh = mesh vertices:posArray faces:faceArray
	--newMesh.name = filename
	newMesh.numTVerts = posArray.count
	buildTVFaces newMesh
	for j = 1 to texCoordArray.count do setTVert newMesh j texCoordArray[j]
	for j = 1 to faceArray.count do setTVFace newMesh j faceArray[j]
	for j = 1 to newMesh.numfaces do setFaceSmoothGroup newMesh j 1
	
	if (globalBoolApplyNormals == true) then 
	(
		/*
		max modify mode
		select newMesh
		addmodifier newMesh (Edit_Normals ()) ui:off
		newMesh.Edit_Normals.MakeExplicit selection:#{1..nrmArray.count}
		normID = #{}

		for v = 1 to nrmArray.count do(
			free normID
			newMesh.Edit_Normals.ConvertVertexSelection #{v} &normID
			for id in normID do newMesh.Edit_Normals.SetNormal id nrmArray[v]
		)
		--maxOps.CollapseNode newMesh true
		*/
		for j = 1 to nrmArray.Count do setNormal newMesh j nrmArray[j]
	)
	return newMesh
)

fn BuildMaterials mat &newMesh =
(
	newMesh.material = standard()
	newMesh.material.showInViewport = true
	
	-- Ambient map
	newMesh.material.adTextureLock = off
	newMesh.material.ambient = [0,0,0]
	newMesh.material.ambientMap = RGB_Tint red:[255,255,255] green:[0,0,0] blue:[0,0,0]
	newMesh.material.ambientMap.map1 = Bitmaptexture filename:((getFilenamePath globalImportedFilePath) + mat.propMapName)	
	
	-- Diffuse map
	newMesh.material.diffuseMap = Bitmaptexture filename:((getFilenamePath globalImportedFilePath) + mat.diffuseMapName)
	
	-- Normal map
	newMesh.material.bumpMapAmount = 100
	newMesh.material.bumpMap = Normal_Bump()
	newMesh.material.bumpMap.normal_map = Bitmaptexture filename:((getFilenamePath globalImportedFilePath) + mat.normalMapName)
	
	-- Specular level
	newMesh.material.specularLevelMap = RGB_Tint red:[0,0,0] green:[255,255,255]	blue:[0,0,0]
	newMesh.material.specularLevelMap.map1 = Bitmaptexture filename:((getFilenamePath globalImportedFilePath) + mat.propMapName)	
	
	-- Specular exponent
	newMesh.material.glossinessMap	= RGB_Tint red:[0,0,0] green:[0,0,0] blue:[255,255,255] 	
	newMesh.material.glossinessMap.map1 = Bitmaptexture filename:((getFilenamePath globalImportedFilePath) + mat.propMapName)
)

fn BuildSkinnedGeneralMesh skGen =
(
	posArray; boneIdsArray; boneWeightsArray; nrmArray; uvArray
	SplitSkinnedGeneralVertex0Struct skGen.vertexArray1 &posArray &boneIdsArray &boneWeightsArray
	SplitSkinnedGeneralVertex1Struct skGen.vertexArray2 &nrmArray &uvArray
	newMesh = BuildMeshFromArrays posArray skGen.faceArray uvArray nrmArray
	BuildMaterials skGen.materialData &newMesh
	
	newMesh.name += (" flags:" + (bit.intashex(skGen.flags)))
	
	if (globalBoolApplySkinning == true) then
	(
		boneArray = GetBoneArray()
		max modify mode
		select newMesh
		skinMod = skin ()
		addModifier newMesh skinMod
		for i = 1 to boneArray.count do
		( 
			maxbone = boneArray[i]
			if i != boneArray.count then 
				skinOps.addBone skinMod maxbone 0
			else
				skinOps.addBone skinMod maxbone 1
		)
		modPanel.setCurrentObject skinMod
		
		for i = 1 to posArray.Count do 
		(
		   bi = #() --bone index array
		   wv = #() --weight value array
		   
		   for j = 1 to 4 do
		   (
			   bID = (boneIdsArray[i][j]+1)
				--boneid = skGen.skinBatchArray[1].boneIdxArray[bID] + 1
				boneid = boneIdsArray[i][j]+1
				weight = (boneWeightsArray[i][j] as float) / 0xFF
				append bi boneid
				append wv weight
		   )   
		   skinOps.ReplaceVertexWeights skinMod i bi wv
		)
	)
	
)

fn BuildRenderBlockModelMeshes rbm = 
(
	disableSceneRedraw()
	for rb in rbm.blockArray do
	(
		case (rb.type) of
		(
			0x5E657F20:
			(
				BuildSkinnedGeneralMesh rb.data
			)
		)
	)
	enableSceneRedraw()
)

--*** Structure creation functions ***--

fn CreateMaterial mshMat =
(
	mat = MaterialStruct()
	
	if (mshMat.diffuseMap != undefined) then
	(
		mat.diffuseMapName =	(GetFileNameFile mshMat.diffuseMap.fileName) + ".dds"
	)
	
	if (mshMat.bumpMap != undefined AND mshMat.bumpMap.normal_map != undefined) then
	(
		mat.normalMapName = 	(GetFileNameFile mshMat.bumpMap.normal_map.fileName) + ".dds"
	)
	
	if (mshMat.specularLevelMap != undefined AND mshMat.specularLevelMap.map1 != undefined) then
	(
		mat.propMapName 	= 	(GetFileNameFile mshMat.specularLevelMap.map1.fileName) + ".dds"
	)
	
	return mat
)

fn GetVertexSkinningInfo msh vtxID =
(
	struct VertexSkinningInfoStruct
	(
		numUsedWeights	= 0,
		boneIDArray		= #(),
		weightArray		= #()
	)
	
	skinMod = (GetMeshSkinMod msh)
	
	vtxInfo = VertexSkinningInfoStruct()
	vtxInfo.numUsedWeights = skinOps.GetVertexWeightCount skinMod vtxID
	
	for i = 1 to vtxInfo.numUsedWeights do
	(
		vtxInfo.boneIDArray[i] = skinOps.GetVertexWeightBoneID skinMod vtxID i
		vtxInfo.weightArray[i] = skinOps.GetVertexWeight skinMod vtxID i
	)
	
	--print vtxInfo
	
	return vtxInfo
)

fn CreateSkinnedGeneralVertex0Small pMesh =
(
	local vtxArray = #()
	
	for i = 1 to pMesh.positionArray.Count do
	(
		vtxArray[i] = SkinnedGeneralVertex0SmallStruct()
		vtxArray[i].position = pMesh.positionArray[i]
		vtxArray[i].boneWeights = pMesh.boneWeightArray[i]
		vtxArray[i].boneIds = pMesh.boneIndexArray[i]
	)
	return vtxArray
)

fn CalculateTangentBinormal &pMesh =
(	
	tan1 = AllocateArray [0,0,0] pMesh.positionArray.Count
	tan2 = AllocateArray [0,0,0] pMesh.positionArray.Count
	
	for i = 1 to pMesh.faceArray.Count do
	(
		tri = pMesh.faceArray[i]
		
		v1 = pMesh.positionArray[tri[1]]
		v2 = pMesh.positionArray[tri[2]]
		v3 = pMesh.positionArray[tri[3]]
		
		w1 = pMesh.texCoordArray[tri[1]]
		w2 = pMesh.texCoordArray[tri[2]]
		w3 = pMesh.texCoordArray[tri[3]]
		
		x1 = v2.x - v1.x
		x2 = v3.x - v1.x
		y1 = v2.y - v1.y
		y2 = v3.y - v1.y
		z1 = v2.z - v1.z
		z2 = v3.z - v1.z
		
		s1 = w2.x - w1.x
		s2 = w3.x - w1.x
		t1 = w2.y - w1.y
		t2 = w3.y - w1.y
		
		r = 1.0 / (s1 * t2 - s2 * t1)
		sdir = [(t2 * x1 - t1 * x2) * r, (t2 * y1 - t1 * y2) * r, (t2 * z1 - t1 * z2) * r];
		tdir = [(s1 * x2 - s2 * x1) * r, (s1 * y2 - s2 * y1) * r, (s1 * z2 - s2 * z1) * r];
		
		tan1[tri[1]] += sdir
		tan1[tri[2]] += sdir
		tan1[tri[3]] += sdir
		
		tan2[tri[1]] += tdir
		tan2[tri[2]] += tdir
		tan2[tri[3]] += tdir
	)
	
	for i = 1 to pMesh.positionArray.Count do
	(
		n = pMesh.normalArray[i]
		n = [n[1], n[2], n[3]]
		t = tan1[i]
		pMesh.tangentArray[i] = normalize ((t - n) * (dot n t))
		sign = (dot (cross n t) (tan2[i])) < 0.0
		if (sign == true) then 
		(
			pMesh.tangentArray[i] = [pMesh.tangentArray[i].x, pMesh.tangentArray[i].y, pMesh.tangentArray[i].z, -1.0]
		)
		else
		(
			pMesh.tangentArray[i] = [pMesh.tangentArray[i].x, pMesh.tangentArray[i].y, pMesh.tangentArray[i].z, 1.0]
		)
		t = pMesh.tangentArray[i]
		b = (cross n t) * t.w
		pMesh.binormalArray[i] = [b.x, b.y, b.z, 0]
	)
)

fn CreateSkinnedGeneralVertex1 pMesh =
(
	local vtxArray = #()
	for i = 1 to pMesh.positionArray.Count do
	(
		vtxArray[i] = SkinnedGeneralVertex1Struct()
		vtxArray[i].normal = pMesh.normalArray[i]
		vtxArray[i].texCoord = pMesh.texCoordArray[i]
		vtxArray[i].tangent = pMesh.tangentArray[i]
		vtxArray[i].binormal = pMesh.binormalArray[i]
	)
	return vtxArray
)

fn CreateSkinBatch pMesh =
(
	local sknBatchArray = #()
	
	local sknBatch = SkinnedGeneralSkinBatchStruct()
	sknBatch.faceCount = pMesh.faceArray.Count * 3
	
	sknBatch.boneCount = skinOps.GetNumberBones pMesh.skinMod
	for i = 1 to sknBatch.boneCount do
	(
		sknBatch.boneIdxArray[i] = 0
	)
	
	sknBatchArray[1] = sknBatch
	return sknBatchArray
)

/*
fn CreateFaces pMesh =
(
	local faceArray = #()
	
	for i = 1 to msh.numFaces do
	(
		faceArray[i] = (GetFace msh i)
	)
	
	return faceArray
)
*/

fn GenerateProceduralMeshSkinned msh =
(
	pMesh = ProceduralMesh()
	numFaces = msh.numFaces
	skinMod = (GetMeshSkinMod msh)
	
	vIdx = 1
	for fIdx = 1 to numFaces do
	(
		curFace = getFace msh fIdx
		curTVFace = getTVFace msh fidx
		
		for i = 1 to 3 do
		(
			append pMesh.positionArray (getVert msh curFace[i])
			append pMesh.normalArray (ExpandVector3 (getNormal msh curFace[i]) 0)			
			append pMesh.texCoordArray (getTVert msh curTVFace[i])
			
			numUsedWeights = skinOps.GetVertexWeightCount skinMod curFace[i]
			
			bI = [0,0,0,0]
			bW = [0,0,0,0]
			
			for j = 1 to numUsedWeights do
			(
				bI[j] = ((skinOps.GetVertexWeightBoneID skinMod curFace[i] j) - 1) as integer
				bW[j] = ((skinOps.GetVertexWeightBoneID skinMod curFace[i] j) * 0xFF) as integer
			)
			
			append pMesh.boneIndexArray bI
			append pMesh.boneWeightArray bW
		)
	)
	pMesh.skinMod = skinMod
	
	fIdx = 1
	for i = 1 to pMesh.positionArray.Count / 3 do
	(
		pMesh.faceArray[i] = [fIdx, fIdx+1, fIdx+2]
		fIdx += 3
	)
	
	pMesh.tangentArray = AllocateArray [0,0,0,0] pMesh.positionArray.Count 
	pMesh.binormalArray = AllocateArray [0,0,0,0] pMesh.positionArray.Count 
	
	--CalculateTangentBinormal &pMesh
	
	/*
	
	triIdx = 0
	for vtxIdx = 1 to numVerts by 3 do
	(
		triIdx += 1
		
		tri = [0,0,0]
		
		for triVtxOffset = 1 to 3 do
		(
			curPos = getVert 
		)
	)
	
	*/
	
	return pMesh
)

fn CreateSkinnedGeneral msh =
(
	local skn = SkinnedGeneralStruct()
	skn.materialData = CreateMaterial msh.material
	
	local skinMod = (GetMeshSkinMod msh)
	select msh
	skinMod.bone_Limit = 4
	skinOps.RemoveZeroWeights skinMod
	
	-- Create a procedural mesh with optimized vertex buffers
	pMesh = GenerateProceduralMeshSkinned msh
	
	skn.vertexArray1 = CreateSkinnedGeneralVertex0Small pMesh
	skn.vertexArray2 = CreateSkinnedGeneralVertex1 pMesh
	skn.skinBatchArray = CreateSkinBatch pMesh
	skn.faceArray = pMesh.faceArray
	
	return skn
)

fn CreateRenderBlock msh =
(
	rb = RenderBlockStruct()
	rb.type = 0x5E657F20
	rb.data = CreateSkinnedGeneral msh
	return rb
)

fn CreateBoundingBox meshes &bbMin &bbMax =
(
	bbMin = [0,0,0]
	bbMax = [0,0,0]
	
	-- Loop over all meshes
	for msh in meshes do
	(
		-- Loop over all the vertices of the current mesh
		for v = 1 to msh.numVerts do
		(
			vtx = getVert msh v
			
			if (vtx.X > bbMax.X) then bbMax.X = vtx.X
			if (vtx.Y > bbMax.Y) then bbMax.Y = vtx.Y
			if (vtx.Z > bbMax.Z) then bbMax.Z = vtx.Z
			
			if (vtx.X < bbMin.X) then bbMin.X = vtx.X
			if (vtx.Y < bbMin.Y) then bbMin.Y = vtx.Y
			if (vtx.Z < bbMin.Z) then bbMin.Z = vtx.Z
		)
	)
)

fn CreateRenderBlockModel =
(
	meshes = GetSceneMeshArray()
	rbm = RenderBlockModelStruct()
	rbm.numBlocks = meshes.Count
	CreateBoundingBox meshes &rbm.bbMin &rbm.bbMax
	
	for i = 1 to rbm.numBlocks do
	(
		rbm.blockArray[i] = CreateRenderBlock meshes[i]
	)
	return rbm
)

fn SetStartTime =
(
	globalStartTime = timeStamp()
)

fn GetEndTime =
(
	curTime = timeStamp()
	return ((curTime - globalStartTime) * 0.001)
)

-- Rollout stuff

rollout JC2ModelIORollout "Just Cause 2 Model Import and Export" width:283 height:180
(
	button btn1 "Import" pos:[166,32] width:88 height:37
	button btn3 "Export" pos:[166,73] width:88 height:37
	label lbl1 "Just Cause 2 Model Import and Export. Created by TGE" pos:[89,131] width:190 height:34	
	checkbutton ckb1 "Import Weights" pos:[10,13] width:87 height:29
	checkbutton ckb3 "Import Normals" pos:[10,47] width:87 height:29

	on btn1 pressed do
	(
		inFile = GetOpenFile()
		if (inFile != undefined) then
		(
			Print ("Importing start..")	
			Print ("Reading model...")
			SetStartTime()
			importedRbm = ReadRenderBlockModel inFile
			impTime = GetEndTime()
			Print ("Reading model done in " + impTime as string + " seconds.")			
			Print ("Building meshes...")
			SetStartTime()
			BuildRenderBlockModelMeshes importedRbm
			buildTime = GetEndTime()
			Print ("Building meshes done in " + buildTime as string + " seconds.")
			fclose inFile
			Print ("Import done in " + (impTime + buildTime) as string + " seconds.")			
		)

	)

	on btn3 pressed do
	(
		outFile = GetSaveFile()		
		if (outFile != undefined) then
		(
			st = timestamp() --get start time in milliseconds
			newRbm = CreateRenderBlockModel()
			WriteRenderBlockModel outFile newRbm
			fclose outFile
			Print ("Exporting done! ("+((((timestamp())-st)*0.001)as string)+" Seconds)")
		)
	)
	
	on ckb1 changed state do
	(
		globalBoolApplySkinning = not globalBoolApplySkinning
	)

	on ckb3 changed state do
	(
		globalBoolApplyNormals = not globalBoolApplyNormals
	)

)

createdialog JC2ModelIORollout
