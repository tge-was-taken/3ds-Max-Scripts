
global BAMS2Deg = 0.0054932478828107
global IsBigEndian = true
--global Key = 0x8C500000
global Key = 0
--global Address = 0x60E14
global Address = 0
global ResourceType = "NodeTable" -- LandTable / NodeTable / Basic

filein "General_Functions.ms"
filein "Structs.ms"

fn NJChunkEnumerator ChunkType = (
	ChunkTypeString = ""
	case ChunkType of
	(
		(00):ChunkTypeString = "Null"
		(01):ChunkTypeString = "Bits_BlendAlpha"
		(02):ChunkTypeString = "Bits_MipmapDAdjust"
		(03):ChunkTypeString = "Bits_SpecularExponent"
		(04):ChunkTypeString = "Bits_CachePolygonList"
		(05):ChunkTypeString = "Bits_DrawPolygonList"
		(08):ChunkTypeString = "Tiny_TextureID"
		(09):ChunkTypeString = "Tiny_TextureID2"
		(16):ChunkTypeString = "Material"
		(17):ChunkTypeString = "Material_Diffuse"
		(18):ChunkTypeString = "Material_Ambient"
		(19):ChunkTypeString = "Material_DiffuseAmbient"
		(20):ChunkTypeString = "Material_Specular"
		(21):ChunkTypeString = "Material_DiffuseSpecular"
		(22):ChunkTypeString = "Material_AmbientSpecular"
		(23):ChunkTypeString = "Material_DiffuseAmbientSpecular"
		(24):ChunkTypeString = "Material_Bump"
		(25):ChunkTypeString = "Material_Diffuse2"
		(26):ChunkTypeString = "Material_Ambient2"
		(27):ChunkTypeString = "Material_DiffuseAmbient2"
		(28):ChunkTypeString = "Material_Specular2"
		(29):ChunkTypeString = "Material_DiffuseSpecular2"
		(30):ChunkTypeString = "Material_AmbientSpecular2"
		(31):ChunkTypeString = "Material_DiffuseAmbientSpecular2"
		(32):ChunkTypeString = "Vertex_SH"
		(33):ChunkTypeString = "Vertex_NormalSH"
		(34):ChunkTypeString = "Vertex_Vertex"
		(35):ChunkTypeString = "Vertex_Diffuse8"
		(36):ChunkTypeString = "Vertex_UserFlags"
		(37):ChunkTypeString = "Vertex_NinjaFlags"
		(38):ChunkTypeString = "Vertex_DiffuseSpecular5"
		(39):ChunkTypeString = "Vertex_DiffuseSpecular4 "
		(40):ChunkTypeString = "Vertex_DiffuseSpecular16"
		(41):ChunkTypeString = "Vertex_Normal"
		(42):ChunkTypeString = "Vertex_NormalDiffuse8"
		(43):ChunkTypeString = "Vertex_NormalUserFlags"
		(44):ChunkTypeString = "Vertex_NormalNinjaFlags"
		(45):ChunkTypeString = "Vertex_NormalDiffuseSpecular5"
		(46):ChunkTypeString = "Vertex_NormalDiffuseSpecular4"
		(47):ChunkTypeString = "Vertex_NormalDiffuseSpecular16"
		(48):ChunkTypeString = "Vertex_NormalX"
		(49):ChunkTypeString = "Vertex_NormalXDiffuse8"
		(56):ChunkTypeString = "Volume_Polygon3"
		(57):ChunkTypeString = "Volume_Polygon4"
		(58):ChunkTypeString = "Volume_Strip"
		(64):ChunkTypeString = "Strip_Strip"
		(65):ChunkTypeString = "Strip_StripUVN"
		(66):ChunkTypeString = "Strip_StripUVH"
		(67):ChunkTypeString = "Strip_StripNormal"
		(68):ChunkTypeString = "Strip_StripUVNNormal"
		(69):ChunkTypeString = "Strip_StripUVHNormal"
		(70):ChunkTypeString = "Strip_StripColor"
		(71):ChunkTypeString = "Strip_StripUVNColor"
		(72):ChunkTypeString = "Strip_StripUVHColor"
		(73):ChunkTypeString = "Strip_Strip2"
		(74):ChunkTypeString = "Strip_StripUVN2"
		(75):ChunkTypeString = "Strip_StripUVH2"
		(255):ChunkTypeString = "End"
	)
	return ChunkTypeString
)

fn ReadNJChunk fstream ChunkHeaderSize = (
	
	if (ChunkHeaderSize == 0x4) then
	(
		ChunkHeader = ReadEndianLong fstream #unsigned
		ChunkStruct = Chunk()
		ChunkStruct.ID = bit.and ChunkHeader 0x000000FF
		ChunkStruct.Flags = bit.shift (bit.and ChunkHeader 0x0000FF00) -8
		ChunkStruct.Size = (bit.shift (bit.and ChunkHeader 0xFFFF0000) -16) * 2
	)
	else if (ChunkHeaderSize == 0x2) then
	(
		ChunkHeader = ReadEndianShort fstream #unsigned
		ChunkStruct = Chunk()
		ChunkStruct.ID = bit.and ChunkHeader 0x00FF
		ChunkStruct.Flags = bit.shift (bit.and ChunkHeader 0xFF00) -8
	)
	else throw "Invalid ChunkHeaderSize"
	
	Method = filterstring (NJChunkEnumerator ChunkStruct.ID) "_"
	
    print (bit.intashex(FTell fstream) as string)
	print (NJChunkEnumerator ChunkStruct.ID)

	case (Method[1]) of
	(
		"Vertex": (
			ChunkVertexHeader = ReadEndianLong fstream #unsigned
			ChunkVertexStruct = ChunkVertex()
			ChunkVertexStruct.IndexOffset 	= (bit.and ChunkVertexHeader 0x0000FFFF)
			ChunkVertexStruct.VertexCount	= bit.shift (bit.and ChunkVertexHeader 0xFFFF0000) -16
			ChunkVertexStruct.VertexData = VertexData()
			ChunkStruct.Size *= 2 -- Elements are of 'long' type in a vertex type
			
			case (Method[2]) of
			(
				"SH": (
					for i = 1 to ChunkVertexStruct.VertexCount do
					(
						append ChunkVertexStruct.VertexData.Vertex (ReadVector3 f)
						fseek f 0x4 #seek_cur -- Dummy float
						append ChunkVertexStruct.VertexData.VertexIndex (ChunkVertexStruct.IndexOffset + i)
					)
				)
				"Normal": (
					for i = 1 to ChunkVertexStruct.VertexCount do
					(
						append ChunkVertexStruct.VertexData.Vertex (ReadVector3 f)
						append ChunkVertexStruct.VertexData.Normal (ReadVector3 f)
						append ChunkVertexStruct.VertexData.VertexIndex (ChunkVertexStruct.IndexOffset + i)
					)
				)
				"NormalNinjaFlags": (
					for i = 1 to ChunkVertexStruct.VertexCount do
					(
						append ChunkVertexStruct.VertexData.Vertex (ReadVector3 f)
						append ChunkVertexStruct.VertexData.Normal (ReadVector3 f)
						append ChunkVertexStruct.VertexData.Flags (ReadEndianLong f #unsigned)
						append ChunkVertexStruct.VertexData.VertexIndex (ChunkVertexStruct.IndexOffset + i)
					)
				)
			)
			ChunkStruct.ChunkData = ChunkVertexStruct
		)
		"Material": (
			ChunkMatData = MatData()
			ChunkMatData.DestAlpha = bit.and ChunkStruct.Flags 7
			ChunkMatData.SrcAlpha = bit.shift (bit.and ChunkStruct.Flags 38) -3
			ChunkMatData.Size = ReadEndianShort fstream #unsigned * 2
			print ChunkMatData
			
			if (Method.count > 1) then 
			(
				case (Method[2]) of
				(
					"Diffuse": (
						ChunkMatData.Diffuse = ReadRGBA fstream
					)
					"DiffuseAmbient": (
						ChunkMatData.Diffuse = ReadRGBA fstream
						ChunkMatData.Ambient = ReadRGBA fstream
					)
					"DiffuseAmbientSpecular": (
						ChunkMatData.Diffuse = ReadRGBA fstream
						ChunkMatData.Ambient = ReadRGBA fstream
						ChunkMatData.Specular = ReadRGBA fstream
					)
					"Specular": (
						ChunkMatData.Specular = ReadRGBA fstream
					)
					"Ambient": (
						ChunkMatData.Ambient = ReadRGBA fstream
					)
					"AmbientSpecular": (
						ChunkMatData.Ambient = ReadRGBA fstream
						ChunkMatData.Specular = ReadRGBA fstream
					)
					default:(
						throw ("Material type not implemented: "+Method[2])
					)
				)
			)
			
			ChunkStruct.ChunkData = ChunkMatData
			print ChunkMatData
		)
		"Tiny": (
			ChunkTinyData = TinyData()
			ChunkTinyHeader = ReadEndianShort fstream #unsigned
			ChunkTinyData.DAdjust = bit.and ChunkStruct.Flags 0xF
			ChunkTinyData.ClampV = bit.get ChunkStruct.Flags 5
			ChunkTinyData.ClampU = bit.get ChunkStruct.Flags 6
			ChunkTinyData.FlipV = bit.get ChunkStruct.Flags 7
			ChunkTinyData.FlipU = bit.get ChunkStruct.Flags 8
			ChunkTinyData.TexID = bit.and ChunkTinyHeader 0x1FFF
			ChunkTinyData.SuperSample = bit.get ChunkTinyHeader 14
			ChunkTinyData.FilterMode = bit.shift (bit.and ChunkTinyHeader 0xC000) -14
			ChunkStruct.ChunkData = ChunkTinyData
			print ChunkTinyData
		)
		"Strip": (
			ChunkStripData = StripData()
			ChunkStripData.UserFlagCount = bit.and ChunkStruct.Flags 3
			ChunkStripData.Size = (ReadEndianShort fstream #unsigned) * 2
			ChunkStripHeader = ReadEndianShort fstream #unsigned
			ChunkStripData.StripCount = bit.and ChunkStripHeader 0x3FFF
			ChunkStripData.UserOffset = bit.shift (bit.and ChunkStripHeader 0xC000) -14
			print ChunkStripData
			
			case (Method[2]) of
			(
				"StripUVN": (
					for s = 1 to ChunkStripData.StripCount do
					(
						IndexCount = ReadEndianShort fstream #signed
						CCW = bit.get IndexCount 16
						if (CCW) then IndexCount = abs IndexCount
						
						f1 = (ReadEndianShort fstream #unsigned) + 1
						u1 = (ReadEndianShort fstream #unsigned) as float / 255
						v1 = (ReadEndianShort fstream #unsigned) as float / 255
						f2 = (ReadEndianShort fstream #unsigned) + 1
						u2 = (ReadEndianShort fstream #unsigned) as float / 255
						v2 = (ReadEndianShort fstream #unsigned) as float / 255
						-- After the first 2 indices have been read, every new index forms a triangle
						IndexCount -= 2
						for i = 1 to IndexCount do 
						(
							f3 = (ReadEndianShort fstream #unsigned) + 1
							u3 = (ReadEndianShort fstream #unsigned) as float / 255
							v3 = (ReadEndianShort fstream #unsigned) as float / 255
							for u = 1 to ChunkStripData.UserOffset do append ChunkStripData.UserFlag (ReadEndianShort fstream #unsigned)
							if (CCW) then 
							(
								append ChunkStripData.Index [f1,f3,f2]
							)
							else
							(
								append ChunkStripData.Index [f1,f2,f3]
							)
                            
                            CCW = not CCW
							f1 = f2
							u1 = u2
							v1 = v2
							f2 = f3
							u2 = u3
							v2 = v3
						)
					)
				)
				"Strip": (
					for s = 1 to ChunkStripData.StripCount do
					(
						IndexCount = ReadEndianShort fstream #signed
						CCW = bit.get IndexCount 16
						if (CCW) then IndexCount = abs IndexCount
						
						f1 = (ReadEndianShort fstream #unsigned) + 1
						f2 = (ReadEndianShort fstream #unsigned) + 1
						-- After the first 2 indices have been read, every new index forms a triangle
						IndexCount -= 2
						for i = 1 to IndexCount do 
						(
							f3 = (ReadEndianShort fstream #unsigned) + 1
							for u = 1 to ChunkStripData.UserOffset do append ChunkStripData.UserFlag (ReadEndianShort fstream #unsigned)
							if (CCW) then 
							(
								append ChunkStripData.Index [f1,f3,f2]
							)
							else
							(
								append ChunkStripData.Index [f1,f2,f3]
							)
                            CCW = not CCW
							f1 = f2
							f2 = f3
						)
					)
				)
                "StripColor": (
					for s = 1 to ChunkStripData.StripCount do
					(
                        print (bit.intashex(FTell fstream) as string)
						IndexCount = ReadEndianShort fstream #signed
						CCW = bit.get IndexCount 16
						if (CCW) then IndexCount = bit.and IndexCount 0x7FFF
						
                       
						f1 = (ReadEndianShort fstream #unsigned) + 1
						f2 = (ReadEndianShort fstream #unsigned) + 1
						-- After the first 2 indices have been read, every new index forms a triangle
						IndexCount -= 2
						for i = 1 to IndexCount do 
						(
                            --print (bit.intashex(FTell fstream) as string)
							f3 = (ReadEndianShort fstream #unsigned) + 1
                            ReadEndianLong fstream #unsigned -- argb
							for u = 1 to ChunkStripData.UserOffset do append ChunkStripData.UserFlag (ReadEndianShort fstream #unsigned)
							if (CCW) then 
							(
								append ChunkStripData.Index [f1,f3,f2]
							)
							else
							(
								append ChunkStripData.Index [f1,f2,f3]
							)
                            CCW = not CCW
							f1 = f2
							f2 = f3
						)
					)
				)
				default: (
					throw ("Strip Type: "+Method[2]+" Not implemented")
				)
			)
			ChunkStruct.ChunkData = ChunkStripData
		)
	)
	return ChunkStruct
)

fn ReadVertStruct fstream offset = (
	ReturnPos = ftell fstream
	fseek fstream offset #seek_set
	
	VertStructData = #()	
	End = false
	while (not End) do
	(
		NJChunk = (ReadNJChunk fstream 4)
		if (NJChunkEnumerator NJChunk.ID == "End") then End = true
		else if ((findstring (NJChunkEnumerator NJChunk.ID) "Vertex") != undefined) then append VertStructData NJChunk.ChunkData
		--else throw "Unexpected data for VertStruct!"
	)
	
	--print NJChunks
	
	fseek f ReturnPos #seek_set
	return VertStructData
)

fn ReadMeshStruct fstream offset = (
	ReturnPos = ftell fstream
	fseek fstream offset #seek_set
	
	MeshStructData = MeshStruct()
	End = false
	while (not End) do
	(
		NJChunk = (ReadNJChunk fstream 2)
		if (NJChunkEnumerator NJChunk.ID == "End") then End = true
		else if (findstring (NJChunkEnumerator NJChunk.ID) "Material" != undefined) then MeshStructData.Material = NJChunk.ChunkData
		else if (findstring (NJChunkEnumerator NJChunk.ID) "Tiny" != undefined) then append MeshStructData.Tiny NJChunk.ChunkData
		else if (findstring (NJChunkEnumerator NJChunk.ID) "Strip" != undefined) then append MeshStructData.Strip NJChunk.ChunkData
	)
	
	fseek f ReturnPos #seek_set
	return MeshStructData
)

fn ReadAttachStruct fstream offset = (
	ReturnPos = ftell fstream
	fseek fstream offset #seek_set
	
	NJAttach = AttachStruct()
	NJAttach.VertStructPtr = ReadPointer fstream
	NJAttach.MeshStructPtr = ReadPointer fstream
	NJAttach.CenterVec = ReadVector3 fstream
	NJAttach.Radius = ReadEndianFloat fstream
	
	if (NJAttach.VertStructPtr != 0) then
	(
		NJAttach.VertStruct = ReadVertStruct fstream NJAttach.VertStructPtr
	)
	
	if (NJAttach.MeshStructPtr != 0) then
	(
		NJAttach.MeshStruct = ReadMeshStruct fstream NJAttach.MeshStructPtr
	)
	
	fseek f ReturnPos #seek_set
	return NJAttach
)

fn ReadNodeFlags fstream = (
	Flags = ReadEndianLong fstream #unsigned
	FlagStruct = NodeFlags()
	FlagStruct.NoTranslate = bit.get Flags 1
	FlagStruct.NoRotate = bit.get Flags 2
	FlagStruct.NoScale = bit.get Flags 3
	FlagStruct.NoDraw = bit.get Flags 4
	FlagStruct.NoDrawChild = bit.get Flags 5
	FlagStruct.UseZYXRotation = bit.get Flags 6
	return FlagStruct
)

fn ReadObjectStruct fstream Offset ParentObjectStruct = (
	ReturnPos = ftell fstream
	fseek fstream offset #seek_set
	
	if (ParentObjectStruct == undefined) then -- If parent is undefined, then parent is the root of the scene
	(
		--create a scene root dummy
		ParentObjectStruct = ObjectStruct()
		ParentObjectStruct.Bone = dummy()
		ParentObjectStruct.Bone.BoxSize = [1,1,1]
		ParentObjectStruct.Bone.Name = "Scene_Root"
	)
	
	NJObject = ObjectStruct()
	NJObject.Flags = ReadNodeFlags fstream
	NJObject.AttachStructPtr = ReadPointer fstream
	NJObject.PosVec = ReadVector3 fstream
	NJObject.RotVec = ReadBAMSVector3 fstream
	NJObject.SclVec = ReadVector3 fstream
	
	--Calculate local matrix
	NJObject.LocalMatrix = Matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]
	if (not NJObject.Flags.NoTranslate) then
	(
		NJObject.LocalMatrix *= transmatrix NJObject.PosVec
	)
	
	if (not NJObject.Flags.NoRotate) then
	(
		if (not NJObject.Flags.UseZYXRotation) then NJObject.LocalMatrix *= (RotateXMatrix NJObject.RotVec.X * RotateYMatrix NJObject.RotVec.Y * RotateZMatrix NJObject.RotVec.Z)
		else NJObject.LocalMatrix *= (RotateZMatrix NJObject.RotVec.Z * RotateYMatrix NJObject.RotVec.Y * RotateXMatrix NJObject.RotVec.X)
	)
	
	if (not NJObject.Flags.NoScale) then
	(
		NJObject.LocalMatrix *= scalematrix NJObject.SclVec
	)
	
	NJObject.WorldMatrix = NJObject.LocalMatrix * ParentObjectStruct.WorldMatrix
	
	newBone = bonesys.createbone	\
		  NJObject.WorldMatrix.row4	\
		  (NJObject.WorldMatrix.row4 + 0.01 * (normalize NJObject.WorldMatrix.row1)) \
		  (normalize NJObject.WorldMatrix.row3)
	newBone.width  = 0.01
	newBone.height = 0.01
	newBone.transform = NJObject.WorldMatrix
	newBone.setBoneEnable false 0
	newBone.wirecolor = yellow
	newbone.showlinks = true
	newBone.pos.controller      = TCB_position ()
	newBone.rotation.controller = TCB_rotation ()
	newBone.parent = ParentObjectStruct.Bone
	NJObject.Bone = newBone
	
	if (NJObject.AttachStructPtr != 0) then 
	(
		NJObject.AttachStruct = ReadAttachStruct fstream NJObject.AttachStructPtr
		if (NJObject.AttachStruct.VertStruct != undefined) then 
		(
			Vert_Array = #()
			Face_Array = #()
			maxIndex = 0
			for vs in NJObject.AttachStruct.VertStruct do
			(
				index = 0
				for vtx in vs.VertexData.Vertex do
				(
					index += 1
					Vert_Array[vs.VertexData.VertexIndex[index]] = (vtx * NJObject.WorldMatrix)
				)
			)
			if (NJObject.AttachStruct.MeshStruct != undefined) then
			(
				for str in NJObject.AttachStruct.MeshStruct.Strip do
				(
					for idx in str.Index do
					(
						append Face_Array idx
						if (idx[1] > maxIndex) then maxIndex = idx[1]
						if (idx[2] > maxIndex) then maxIndex = idx[2]
						if (idx[3] > maxIndex) then maxIndex = idx[3]
					)
				)
			)
			for i = 1 to Vert_Array.count do
			(
				if (Vert_Array[i] == undefined) then Vert_Array[i] = [0,0,0]
			)
			msh = mesh vertices:Vert_Array faces:Face_Array
			setuserprop msh "NoDraw" NJObject.Flags.NoDraw
			msh.parent = NJObject.Bone
			meshop.deleteisoverts msh
		)
	)
	
	NJObject.ChildObjectStructPtr = ReadPointer fstream
	if (NJObject.ChildObjectStructPtr != 0 and not NJObject.Flags.NoDrawChild) then
	(
		NJObject.ChildObjectStruct = ReadObjectStruct fstream NJObject.ChildObjectStructPtr NJObject
	)
	
	NJObject.SiblingObjectStructPtr = ReadPointer fstream
	if (NJObject.SiblingObjectStructPtr != 0) then 
	(
		NJObject.SiblingObjectStruct = ReadObjectStruct fstream NJObject.SiblingObjectStructPtr ParentObjectStruct
	)
	
	fseek fstream ReturnPos #seek_set
	return NJObject
)

fn ReadNodeTable fstream Offset = (
	NodeTable = #()

	End = false
	RootIndex = #(0xFFFF, 0)
	while (not End) do
	(
		GlobalID = ReadEndianLong f #signed
		NodePtr = ReadPointer f
        ReadObjectStruct f NodePtr undefined
        return OK
        
		if (GlobalID != -1) then
		(
			if (GlobalID < RootIndex[1]) then 
			(
				RootIndex[1] = GlobalID
				RootIndex[2] = NodePtr 
			)
			--append NodeTable #(NodeEntry GlobalID:GlobalID NodePtr:NodePtr)
		)
		else End = true
	)

	print RootIndex
	--ReadObjectStruct f RootIndex[2] undefined
)

fn ReadLandNodeList fstream LandTable = (
	fseek f LandTable.LandNodeListPtr #seek_set
	LandNodeList = #()
	for i = 1 to LandTable.ChunkModelCount do
	(
		LandNode = LandNodeStruct()
		LandNode.CenterVec = ReadVector3 fstream
		LandNode.Radius = ReadEndianFloat fstream
		LandNode.ObjectStructPtr = ReadPointer fstream
		LandNode.Padding = ReadLongLong fstream
		LandNode.Flags = ReadEndianLong fstream #unsigned
		
		print LandNode
		
		if (LandNode.ObjectStructPtr != 0) then
		(
			--LandNode.ObjectStruct = ReadObjectStruct fstream LandNode.ObjectStructPtr undefined -- no parent
		)
		append LandNodeList LandNode
	)
	return LandNodeList
)

fn ReadLandTable fstream Offset = (
	ReturnPos = ftell fstream
	fseek f Offset #seek_set
	
	LandTable = LandTableStruct()
	LandTable.LandNodeCount = ReadEndianShort fstream #unsigned
	LandTable.ChunkModelCount = ReadEndianShort fstream #unsigned
	LandTable.Unk1 = ReadEndianLong fstream #unsigned
	LandTable.Unk2 = ReadEndianLong fstream #unsigned
	LandTable.Unk3 = ReadEndianFloat fstream
	LandTable.LandNodeListPtr = ReadPointer fstream
	LandTable.Unk4 = ReadEndianLong fstream #unsigned
	LandTable.TexNamePtr = ReadPointer fstream
	LandTable.TexListPtr = ReadPointer fstream
	
	print LandTable
	
	if (LandTable.LandNodeListPtr != 0) then
	(
		LandTable.LandNodeList = ReadLandNodeList fstream LandTable
	)
	
	if (LandTable.TexNamePtr != 0) then
	(
		fseek f LandTable.TexNamePtr #seek_set
		LandTable.TexName = (readstring fstream)
	)
	
	fseek f ReturnPos #seek_set
)

clearlistener()
fname = getOpenFileName \ 
caption:"Open Model" \
types:"Sonic Adventure 2 PC Model (*.*)|*.*|*.*|*.*" \
historyCategory:"SA2PCMDL Object Presets"

f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = getFileNamePath fname
filetype = getFilenameType fname

if (ResourceType == "NodeTable") then ReadNodeTable f Address
if (ResourceType == "LandTable") then ReadLandTable f Address

gc()
fclose f