
/* Structs */

struct stChunk
(
	u32Type, u32Size
)

struct stBuffer
(
	u32Count, arrData = #()
)

struct stTexture
(
	u16Width, u16Height, u32Format, u32Unk1, arrUnk2, u32Size, arrData 
)

struct stBufferFlags
(
	pos = false,
	nrm = false,
	uv0 = false,
	uv1 = false,
	uv2 = false
)

/* Reading functions */

fn ReadBEShort fstream = (
	short = readshort fstream #unsigned
	short = bit.swapBytes short 1 2
	return short
)

fn ReadBELong fstream = (
	long = readlong fstream
	long = bit.swapBytes long 1 4
	long = bit.swapBytes long 2 3
	return long
)

fn ReadBEFloat fstream = (
	return bit.intAsFloat (ReadBELong fstream)
)

fn ReadBEVector3 fstream = (
	return [(ReadBEFloat fstream), (ReadBEFloat fstream), (ReadBEFloat fstream)]
)

fn ReadBEVector2 fstream = (
	return [(ReadBEFloat fstream), (ReadBEFloat fstream), 0] -- Max doesn't have a point2 type, so we add another empty element to the point3.
)

fn ReadChunkHeader fstream = (
	return (stChunk u32Type:(ReadBELong fstream) u32Size:(ReadBELong fstream))
)

fn Align32 fstream = (
	align = (mod (ftell f) 32)
	if (align != 0) then fseek f (32 - align) #seek_cur
)

fn ReadBuffer fstream type bufferFlags = (
	buffer = stBuffer()
	buffer.u32Count = ReadBELong fstream
	Align32 fstream
	case type of
	(
		0x10:
		for i = 1 to buffer.u32Count do buffer.arrData[i] = ReadBEVector3 fstream -- Position
		0x11:
		for i = 1 to buffer.u32Count do buffer.arrData[i] = ReadBEVector3 fstream -- Normal
		0x18:
		for i = 1 to buffer.u32Count do buffer.arrData[i] = ReadBEVector2 fstream -- UV0
		0x19:
		for i = 1 to buffer.u32Count do buffer.arrData[i] = ReadBEVector2 fstream -- UV1
		0x1A:
		for i = 1 to buffer.u32Count do buffer.arrData[i] = ReadBEVector2 fstream -- UV2
		0x50: 
		for i = 1 to buffer.u32Count do buffer.arrData[i] = ReadFaces fstream bufferFlags
	)
	Align32 fstream
	return buffer
)

fn ReadFaces fstream bufferFlags =
(
	fseek fstream 0x20 #seek_cur
	size = ReadBEShort fstream
	faceEnd = (ftell fstream) + size
	Align32 fstream
	
	primitives = #()
	while ((ftell fstream) < faceEnd) do
	(
		cmd = readbyte f #unsigned
		print (bit.intashex(cmd))
		case cmd of
		(
			0x98: -- Triangle strip
			append primitives (ReadTriangleStrip fstream bufferFlags)
			0xA0: -- Triangle fan
			append primitives (ReadTriangleFan fstream bufferFlags)
		)
	)
	print(bit.intashex(ftell f))
	Align32 fstream
	return primitives
)

fn ReadTriangleStrip fstream bufferFlags = 
(
	curPos = #()
	curNrm = #()
	curUV0 = #()
	primPos = #()
	primNrm = #()
	primUV0 = #()
	vtxCount = ReadBEShort fstream
	for i = 1 to vtxCount do 
	(
		fseek fstream 2 #seek_cur
		if (bufferFlags.pos == true) then append curPos (ReadBEShort fstream + 1)
		if (bufferFlags.nrm == true) then append curNrm (ReadBEShort fstream + 1)
		if (bufferFlags.uv0 == true) then append curUV0 (ReadBEShort fstream + 1)
		if (bufferFlags.uv1 == true) then fseek fstream 2 #seek_cur
		if (bufferFlags.uv2 == true) then fseek fstream 2 #seek_cur
	)
	for i = 3 to vtxCount do
	(
		if (mod i 2) == 0 then
		(
			append primPos [curPos[i], curPos[i - 1], curPos[i - 2]]
			append primNrm [curNrm[i], curNrm[i - 1], curNrm[i - 2]]
			append primUV0 [curUV0[i], curUV0[i - 1], curUV0[i - 2]]
		)
		else
		(
			append primPos [curPos[i - 2], curPos[i - 1], curPos[i]]
			append primNrm [curPos[i - 2], curPos[i - 1], curPos[i]]
			append primUV0 [curUV0[i - 2], curUV0[i - 1], curUV0[i]]
		)
	)
	return primPos
)

fn ReadTriangleFan fstream bufferFlags = 
(
	curPos = #()
	curNrm = #()
	curUV0 = #()
	primPos = #()
	primNrm = #()
	primUV0 = #()
	vtxCount = ReadBEShort fstream
	
	fseek fstream 1 #seek_cur
	if (bufferFlags.pos == true) then centerPos = (ReadBEShort fstream + 1)
	if (bufferFlags.nrm == true) then centerNrm = (ReadBEShort fstream + 1)
	if (bufferFlags.uv0 == true) then centerUV0 = (ReadBEShort fstream + 1)
	
	for i = 2 to vtxCount do 
	(
		fseek fstream 1 #seek_cur
		if (bufferFlags.pos == true) then append curPos (ReadBEShort fstream + 1)
		if (bufferFlags.nrm == true) then append curNrm (ReadBEShort fstream + 1)
		if (bufferFlags.uv0 == true) then append curUV0 (ReadBEShort fstream + 1)
	)
	
	for i = 2 to vtxCount-1 do
	(
		append primPos [centerPos, curPos[i - 1], curPos[i]]
		append primNrm [centerNrm, curNrm[i - 1], curNrm[i]]
		append primUV0 [centerUV0, curUV0[i - 1], curUV0[i]]
	)
	
	return primPos
)

clearListener()

/* Reading file */

fname = GetOpenFileName caption:"Open Pikmin model" types:"Pikmin Model File(*.mod)|*.mod"
f = fopen fname "rb"
if (doesFileExist fname) do
(
	fileEnd = (fseek f 0 #seek_end; ftell f)
	fseek f 0 #seek_set
	
	bufferFlags = stBufferFlags()
	
	while (ftell f < fileEnd) do
	(
		chunk = ReadChunkHeader f
		print chunk
		print (bit.intashex(ftell f))
		case chunk.u32Type of
		(
			0x10:
			(
				posBuffer = ReadBuffer f chunk.u32Type bufferFlags
				bufferFlags.pos = true
			)
			0x11:
			(
				nrmBuffer = ReadBuffer f chunk.u32Type bufferFlags
				bufferFlags.nrm = true
			)
			0x18:
			(
				uv0Buffer = ReadBuffer f chunk.u32Type bufferFlags
				bufferFlags.uv0 = true
			)
			0x19:
			(
				uv1Buffer = ReadBuffer f chunk.u32Type bufferFlags
				bufferFlags.uv1 = true
			)
			0x1A:
			(
				uv2Buffer = ReadBuffer f chunk.u32Type bufferFlags
				bufferFlags.uv2 = true
			)
			0x50:
			(
				faceBuffer = ReadBuffer f chunk.u32Type bufferFlags
			)
			0xFFFF:
			fseek f fileEnd #seek_set
			default:
			fseek f chunk.u32Size #seek_cur
		)
	)
	
	for smIdx = 1 to faceBuffer.u32Count do
	(
		for primIdx = 1 to faceBuffer.arrData[smIdx].Count do
		(
			msh = mesh vertices:posBuffer.arrData faces:faceBuffer.arrData[smIdx][primIdx]
			meshop.deleteIsoVerts msh
		)
	)
)

fclose f
gc()