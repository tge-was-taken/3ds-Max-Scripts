
fn floatSwap2 _fstream = (
	_i = bit.floatAsInt _fstream
	_h = bit.intashex _i
	while _h.count < 8 do _h = "0" + _h
	
	_s = (substring _h 7 2) + (substring _h 5 2) + (substring _h 3 2) + (substring _h 1 2)
	bit.intAsFloat (bit.hexasint _s)
)	

fn readBEshort _fstream = (
	_short = readshort _fstream #unsigned
	_short = bit.swapBytes _short 1 2
	return _short
)

fn ReadBElong _fstream = (
_long = readlong _fstream
_long = bit.swapBytes _long 1 4
_long = bit.swapBytes _long 2 3
return _long
)

fn ReadBEfloat fstream = (
return floatSwap2(readfloat fstream)
)

fn ReadBEVector3 fstream = (
	return [(ReadBEFloat fstream), (ReadBEFloat fstream), (ReadBEFloat fstream)]
)

fn ReadBEVector2 fstream = (
	return [(ReadBEFloat fstream), (ReadBEFloat fstream), 0]
)

fname = GetOpenFileName caption:"Open Maverick Hunter X model" types:"Maverick Hunter X Model File(*.1_4)|*.1_4"

f = fopen fname "rb"

vertexPositionBufferOffset = readBELong f
vertexNormalBufferOffset = readBELong f
unknownBuffer1Offset = readBELong f
vertexUVBufferOffset = readBELong f
unknownBuffer2Offset = readBELong f
indexBufferOffset = readBELong f
vertexCount = readBEShort f
uvCount = readBEShort f
unknownBuffer2Count = readBEShort f
faceCount = readBEShort f

fseek f vertexPositionBufferOffset #seek_set
vertexArray = #()
vertexArray[vertexCount] = [0,0,0]

for i = 1 to vertexCount do
(
	vertexArray[i] = ReadBEVector3 f
)

fseek f vertexNormalBufferOffset #seek_set
normalArray = #()
normalArray[vertexCount] = [0,0,0]

for i = 1 to vertexCount do
(
	normalArray[i] = ReadBEVector3 f
)

fseek f vertexUVBufferOffset #seek_set
uvArray = #()
uvArray[uvCount] = [0,0,0]

for i = 1 to uvCount do
(
	uvArray[i] = ReadBEVector2 f
)

fseek f indexBufferOffset #seek_set
faceArray = #()
faceArray[faceCount] = [0,0,0]

uvFaceArray = #()
uvFaceArray[faceCount] = [0,0,0]

for i = 1 to faceCount do
(
	v1 = ReadBEShort f + 1
	u1 = ReadBEShort f + 1
	v2 = ReadBEShort f + 1
	u2 = ReadBEShort f + 1
	v3 = ReadBEShort f + 1
	u3 = ReadBEShort f + 1
	faceArray[i] = [v1, v2, v3]
	uvFaceArray[i] = [u1, u2, u3]
)

-- Max doesn't support seperate uv indices so we need to use a workaround
rawVertexCount = faceCount * 3

rawVertexArray = #()
rawVertexArray[rawVertexCount] = [0,0,0]

rawNormalArray = #()
rawNormalArray[rawVertexCount] = [0,0,0]

rawUVArray = #()
rawUVArray[rawVertexCount] = [0,0,0]

rawIndex = 1

for i = 1 to faceCount do
(
	rawVertexArray[rawIndex] = vertexArray[faceArray[i][1]]
	rawVertexArray[rawIndex + 1] = vertexArray[faceArray[i][2]]
	rawVertexArray[rawIndex + 2] = vertexArray[faceArray[i][3]]
	
	rawNormalArray[rawIndex] =  normalArray[faceArray[i][1]]
	rawNormalArray[rawIndex + 1] =  normalArray[faceArray[i][2]]
	rawNormalArray[rawIndex + 2] =  normalArray[faceArray[i][3]]
	
	rawUVArray[rawIndex] =  uvArray[uvFaceArray[i][1]]
	rawUVArray[rawIndex + 1] =  uvArray[uvFaceArray[i][2]]
	rawUVArray[rawIndex + 2] =  uvArray[uvFaceArray[i][3]]
	
	rawIndex += 3
)

free vertexArray; free normalArray; free uvArray; free faceArray; free uvFaceArray

-- Piece of modified code taken from Parax's CMDL maxscript, ty Parax.

newVertexArray = #()
newNormalArray = #() -- Used to check for duplicate vertices, not used on the actual mesh
newUVArray = #()
newFaceArray = #()

for v = 1 to faceCount do (
	-- Iterate through each face
	face = #()
	
	for dv = 1 to 3 do (
		-- We need to use this slightly confusing format so we can parse vertices three at a time, which is necessary because Max wants faces in point3 format.
		index = 0
		curv = ((v - 1) * 3) + dv -- This is kind of confusing but it's basically just getting the current vertex number. It needs to account for the fact that array indices in the file start at 0, but array indices in Max start at 1
		
		vert = rawVertexArray[curv]
		nrm = rawNormalArray[curv]
		uv = rawUVArray[curv]
		
		-- Check for duplicates before appending anything. If the vertex is a duplicate we want to reuse it instead of making a new one.
		-- This is a pretty slow check, and I wouldn't be surprised if it could be sped up a fair bit.
		for v2 = 1 to newVertexArray.count do (
			if (vert == newVertexArray[v2]) and (nrm == newNormalArray[v2]) and (uv == newUVArray[v2]) then (
				index = v2
				exit
			)
		)
		
		-- If the vertex is  duplicate, reuse the original vertex's index.
		if index != 0 then append face index
			
		-- If it's not, then we'll create a new vertex.
		if index == 0 then (
			append newVertexArray vert
			append newNormalArray nrm
			append newUVArray uv
			append face newVertexArray.count
		)
	)
	append newFaceArray [face[1], face[2], face[3]]
)

msh = mesh vertices:newVertexArray faces:newFaceArray
msh.numTVerts = newUVArray.count
buildTVFaces msh
for j = 1 to newFaceArray.count do setTVFace msh j newFaceArray[j]
for j = 1 to newUVArray.count do setTVert msh j newUVArray[j]
for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1

free newVertexArray; free newNormalArray; free newUVArray; free newFaceArray

fclose f