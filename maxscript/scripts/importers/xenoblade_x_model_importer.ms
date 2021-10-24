
gc()

fn GetOpenFile = 
(
	clearlistener()
	local fname = getOpenFileName \ 
	caption:"Open Model" \
	types:"Model (*.camdo)|*.camdo" \
	historyCategory:"XENBLADECHRX Object Presets"
	if (fname == undefined) then
	(
		return undefined
	)
	else
	(
		--globalImportedFilePath = fname
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

fn ReadBEVector2 fstream =
(
	return [(ReadBEFloat fstream), ((ReadBEFloat fstream) * -1) + 1, 0]
)

fn ReadBEVector3 fstream =
(
	return [(ReadBEFloat fstream), (ReadBEFloat fstream), (ReadBEFloat fstream)]
)

struct VertBufDescriptorStruct
(
	/* u32 */ vertBufOffset,
	/* u32 */ numVertices,
	/* u32 */ vertStride,
	/* u32 */ unkIndicesArrayOffset,
	/* u32 */ numUnkIndices,
	/* u32 */ unk0x14
)

struct FaceBufDescriptorStruct
(
	/* u32 */ faceBufOffset,
	/* u32 */ numFaces,
	/* u32 */ unk0x08
)

file = GetOpenFile()

if (file != undefined) then
(
	fseek file 0x14 #seek_cur
	bufferDescriptorOffset = ReadBELong file
	
	fseek file bufferDescriptorOffset #seek_set
	
	vertBufDescriptorArrayOffset = ReadBELong file
	numVertexBuffers = ReadBELong file
	faceBufDescriptorArrayOffset = ReadBELong file
	numFaceBuffers = ReadBELong file
	
	fseek file (bufferDescriptorOffset + vertBufDescriptorArrayOffset) #seek_set
	vertDescriptorArray = #()
	for i = 1 to numVertexBuffers do
	(
		vtxDesc = VertBufDescriptorStruct()
		vtxDesc.vertBufOffset = ReadBELong file
		vtxDesc.numVertices = ReadBELong file
		vtxDesc.vertStride = ReadBELong file
		vtxDesc.unkIndicesArrayOffset = ReadBELong file
		vtxDesc.numUnkIndices = ReadBELong file
		vtxDesc.unk0x14 = ReadBELong file
		vertDescriptorArray[i] = vtxDesc
	)
	
	fseek file (bufferDescriptorOffset + faceBufDescriptorArrayOffset) #seek_set
	faceDescriptorArray = #()
	for i = 1 to numFaceBuffers do
	(
		faceDesc = FaceBufDescriptorStruct()
		faceDesc.faceBufOffset = ReadBELong file
		faceDesc.numFaces = ReadBELong file
		faceDesc.unk0x08 = ReadBELong file
		faceDescriptorArray[i] = faceDesc
	)
	
	posArray = #()
	uvArray = #()
	for i = 1 to numVertexBuffers do
	(	
		if (vertDescriptorArray[i].vertStride == 0x10) then continue -- Weight data
		for j = 1 to vertDescriptorArray[i].numVertices do
		(
			fseek file (bufferDescriptorOffset + vertDescriptorArray[i].vertBufOffset + ((j - 1) * vertDescriptorArray[i].vertStride)) #seek_set
			append posArray (ReadBEVector3 file)
			fseek file 0x04 #seek_cur
			append uvArray (ReadBEVector2 file)
		)
	)
	
	faceArray = #()
	for i = 1 to numFaceBuffers do
	(
		fseek file (bufferDescriptorOffset + faceDescriptorArray[i].faceBufOffset) #seek_set
		for j = 1 to faceDescriptorArray[i].numFaces/3 do
		(
			append faceArray [(ReadBEShort file) + 1, (ReadBEShort file) + 1, (ReadBEShort file) + 1]
		)
	)
	
	msh = mesh vertices:posArray faces:faceArray tverts:uvArray
	buildTVFaces msh
	for j = 1 to faceArray.count do setTVFace msh j faceArray[j]
)

gc()