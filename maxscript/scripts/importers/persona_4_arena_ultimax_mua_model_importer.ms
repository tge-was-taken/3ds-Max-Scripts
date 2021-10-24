fname = getOpenFileName \ 
caption:"Open Model File" \
types:"Model File(*.*)|*.*" \
historyCategory:"Object Presets"
--fname = "C:\\Users\\TGE\Downloads\\Persona.4.Arena.Ultimax.XBOX360-iMARS\\iso_contents\\Persona.4.Arena.Ultimax.XBOX360-iMARS\\data\\Char3D\\char3d_hk\\mdl\\mdl\\char3d_ta.MUA"
f = fopen fname "rb"

fn floatSwap2 f = (
	asd = bit.floatAsInt f
	h = bit.intashex asd
	while h.count < 8 do h = "0" + h
	
	s = (substring h 7 2) + (substring h 5 2) + (substring h 3 2) + (substring h 1 2)
	bit.intAsFloat (bit.hexasint s)
)	

fn readBEshort fstream = (
	short = readshort fstream #unsigned
	short = bit.swapBytes short 1 2
	return short
)

fn ReadBEHalfFloat Fstream = (
  local BH  = readByte Fstream #unsigned
  local BL  = readByte Fstream #unsigned
  local N = BH*256 + BL
  local S = floor((mod N 65536) / 32768)
  local Ef = floor((mod N 32768) / 1024)
  local M = mod N 1024
  if (Ef==0)AND(M==0) then return ( (-1.0)^S * 0.0 )
  if (Ef==0)AND(M!=0) then return ( (-1.0)^S * 2.0^-14 * (M / 2.0^10) )
  if (Ef>0)AND(Ef<31) then return ( (-1.0)^S * 2.0^(Ef-15) * (1 + M/2.0^10) )
  if (Ef==31)AND(M==0) then return ( (-1.0)^S * 1/0.0 )
  if (Ef==31)AND(M!=0) then return 0	--hack-- should be #inf   
 )--end fn ReadBEHalfFloat

fn ReadBElong fstream = (
long = readlong fstream
long = bit.swapBytes long 1 4
long = bit.swapBytes long 2 3
return long
)

fn ReadBEfloat fstream = (
return floatSwap2(readfloat fstream)
)

fn ReadFixedString bstream fixedLen = (
    local str = ""
    for i = 1 to fixedLen do
    (
        str += bit.intAsChar (ReadByte bstream #unsigned)
    )
    str
)

struct data
(
	offset, count
)

struct data1
(
	ID, unk1, parentID, unk2, unk3, unk4
)

struct data3
(
	meshID, vertCount, bufferOff, nameID
)

struct data4
(
	meshID, faceCount, bufferOff
)

struct data5
(
	unk1, ID, unk2
)

clearlistener()

sign = readFixedString f 4
if (sign != "MUA") then (fclose f)
unkA = readBELong f
dataCount = readBElong f
fseek f 0x14 #seek_cur -- Seek past padding
dataArray = #()
for i = 1 to dataCount do
(
	dataArray[i]= 
	(
		data \
		offset:(readBElong f) \
		count:(readBElong f) \
	)
	format "data:% offset:0x% count:%\n" i (bit.intAsHex(dataArray[i].offset)) dataArray[i].count
)	/*
		Data 1 = Hierarchy / Flags. Each element is 0x20 bytes in size
		Data 2 = Matrices (Bones, etc)
		Data 3 = Unknown
		struct data
		{
			float unk;
			UInt32 unk;
			UInt32 unkConst; //always 0x1
			UInt32 meshID;
			UInt32 vertCount;
			UInt32 bufferOff; //in elements, so for vertices it would be (bufferOff * 0x50)
			byte[0x9C] unk //..matrices??
			UInt32 nameID; //ID for string buffer info 
			UInt32 meshID; //again?
			UInt32 null;
		}
		Data 4 = Unknown
		struct data
		{
			UInt32 meshID;
			UInt32 faceCount;
			UInt32 bufferOff //in elements
			byte[20] null;
		}
		Data 5 = Unknown Normalized Floats
		struct data
		{
			UInt32 unkConst; //always 0x1
			UInt32 ID;
			UInt32 null;
			Matrix44 unk; (?)
			UInt32 null;
		}
		Data 6 = Unknown
		Data 7 = Unknown
		struct data
		{
			UInt32 texNameID;
			byte[12] null;
		}
		Data 8 = Unknown
		Data 9 = Unknown
		Data 10 = Unknown
		Data 11 = Unknown
		Data 12 = Unknown
		struct data
		{
			UInt32 evbNameID;
			byte[12] null;
		}
		Data 13 = Unknown
		struct data
		{
			UInt32 meshNameID;
			byte[12] null;
		}
		Data 14 = Vertex Buffer
		struct data
		{
			Vector3 vertPos;
			Vector3 vertNorm;
			Vector3 vertTangent/BiNorm (?)
			Vector2 vertUV;
			Vector2 vertUV2; //unused?
			UInt32 RGBA;
			float6 weights (?);
		}
		Data 15 = Face Index Buffer
		struct data
		{
			UInt16 vert1;
			UInt16 vert2;
			UInt16 vert3;
		}
		Data 16 = String Buffer Info
		struct data
		{
			UInt32 offset;
			UInt32 size;
			align to 16 byte boundary
		}
		Data 17 = String Buffer, count equals size
		//null terminated strings
	*/
dataArray1 = #()
fseek f dataArray[1].offset #seek_set
for i = 1 to dataArray[1].count do
(
	ID = readBElong f
	unk1 = readBElong f
	parentID = readBElong f
	unk2 = readBElong f
	unk3 = readBEshort f
	unk4 = readBEshort f
	fseek f 0xC #seek_cur
	append dataArray1 (data1 ID:ID unk1:unk1 parentID:parentID unk2:unk2 unk3:unk3 unk4:unk4)
	print dataArray1[i]
)

boneArray = #()
fseek f dataArray[2].offset #seek_set
for i = 1 to 0 do -- Bone Data
(
	ID = readBElong f
	unk_0x4 = readBElong f
	p1 = readBEfloat f; p2 = readBEfloat f; p3 = readBEfloat f
	p4 = readBEfloat f; p5 = readBEfloat f; p6 = readBEfloat f
	p7 = readBEfloat f; p8 = readBEfloat f; p9 = readBEfloat f
	p10 = readBEfloat f; p11 = readBEfloat f; p12 = readBEfloat f
	
	--tfm4 = (rotateXMatrix p4) * (rotateYMatrix p5) * (rotateZMatrix p6)
	--tfm4.row4 = [p1,p2,p3]

	ID2 = readBElong f
	parentID = readBElong f
	siblingID = readBElong f
	dSiblingID = readBElong f -- Depth-first sibling ID?
	m11 = readBEfloat f; m12 = readBEfloat f; m13 = readBEfloat f; m14 = readBEfloat f
	m21 = readBEfloat f; m22 = readBEfloat f; m23 = readBEfloat f; m24 = readBEfloat f
	m31 = readBEfloat f; m32 = readBEfloat f; m33 = readBEfloat f; m34 = readBEfloat f
	m41 = readBEfloat f; m42 = readBEfloat f; m43 = readBEfloat f; m44 = readBEfloat f
	tfm = matrix3 [m11,m12,m13,m14] [m21,m22,m23,m24] [m31,m32,m33,m34] [m41,m42,m43,m44]
	
	m11 = readBEfloat f; m12 = readBEfloat f; m13 = readBEfloat f; m14 = readBEfloat f
	m21 = readBEfloat f; m22 = readBEfloat f; m23 = readBEfloat f; m24 = readBEfloat f
	m31 = readBEfloat f; m32 = readBEfloat f; m33 = readBEfloat f; m34 = readBEfloat f
	m41 = readBEfloat f; m42 = readBEfloat f; m43 = readBEfloat f; m44 = readBEfloat f
	tfm2 = matrix3 [m11,m12,m13,m14] [m21,m22,m23,m24] [m31,m32,m33,m34] [m41,m42,m43,m44]
	
	m11 = readBEfloat f; m12 = readBEfloat f; m13 = readBEfloat f; m14 = readBEfloat f
	m21 = readBEfloat f; m22 = readBEfloat f; m23 = readBEfloat f; m24 = readBEfloat f
	m31 = readBEfloat f; m32 = readBEfloat f; m33 = readBEfloat f; m34 = readBEfloat f
	m41 = readBEfloat f; m42 = readBEfloat f; m43 = readBEfloat f; m44 = readBEfloat f
	tfm3 = matrix3 [m11,m12,m13,m14] [m21,m22,m23,m24] [m31,m32,m33,m34] [m41,m42,m43,m44]
	
	if (getNodeByName (i as string)) != undefined do (append boneArray (getNodeByName (i as string)))
	if ((parentID != -1) AND (parentID < i)) then ( tfm = tfm * boneArray[parentID+1].objecttransform ) 
	else if ((i > 1) AND (parentID > -1)) do (print ("Bone named " + (i as string) + " has a parent bone that doesn't exist yet!"))
	
	newBone = bonesys.createbone	\
					  tfm.row4	\
					  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
					  (normalize tfm.row3)
				newBone.name = (i as string)
				newBone.width  = 0.01
				newBone.height = 0.01
				newBone.transform = tfm
				newBone.setBoneEnable false 0
				newBone.wirecolor = yellow
				newbone.showlinks = true
				newBone.pos.controller      = TCB_position ()
				newBone.rotation.controller = TCB_rotation ()

	if (parentID != -1) then newBone.parent = boneArray[(parentID+1)]
	append boneArray newBone	
	fseek f 0x28 #seek_cur
	Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
)
dataArray3 = #()
fseek f dataArray[3].offset #seek_set
for i = 1 to dataArray[3].count do
(
	unk = readBEFloat f
	unk2 = readBELong f
	unkConst = readBElong f
	meshID = readBElong f
	vertCount = readBElong f
	bufferOff = readBElong f
	fseek f 0x9C #seek_cur
	nameID = readBElong f
	meshID2 = readBElong f
	fseek f 0x4 #seek_cur
	append dataArray3 (data3 meshID:meshID vertCount:vertCount bufferOff:bufferOff nameID:nameID)
	print dataArray3[i]
)

dataArray4 = #()
fseek f dataArray[4].offset #seek_set
for i = 1 to dataArray[4].count do
(
	meshID = readBElong f
	faceCount = readBElong f / 3
	bufferOff = readBElong f
	fseek f 20 #seek_cur
	append dataArray4 (data4 meshID:meshID faceCount:faceCount bufferOff:bufferOff)
	print dataArray4[i]
)

dataArray5 = #()
fseek f dataArray[5].offset #seek_set
for i = 1 to dataArray[5].count do
(
	unk1 = readBElong f
	ID = readBElong f
	unk2 = readBElong f
	fseek f 0x44 #seek_cur
	append dataArray5 (data5 unk1:unk1 ID:ID unk2:unk2)
	print dataArray5[i]
)

vertArray = #()
normArray = #()
uvArray = #()
for x = 1 to dataArray[3].count do
(
	faceArray = #()
	vertArray = #()
	normArray = #()
	uvArray = #()
	fseek f (dataArray[14].offset + (dataArray3[x].bufferOff * 0x50)) #seek_set -- Vertex Data
	for i = 1 to dataArray3[x].vertCount do
	(
		vx = readBEfloat f
		vy = readBEfloat f
		vz = readBEfloat f
		nx = readBEfloat f
		ny = readBEfloat f
		nz = readBEfloat f
		nx2 = readBEfloat f
		ny2 = readBEfloat f
		nz2 = readBEfloat f
		tu = readBEfloat f
		tv = readBEfloat f * -1
		tu2 = readBEfloat f
		tv2 = readBEfloat f
		rgba = readBElong f
		w1 = readBEfloat f
		w2 = readBEfloat f
		w3 = readBEfloat f
		w4 = readBEfloat f
		w5 = readBEfloat f
		w6 = readBEfloat f
		append vertArray [vx,vy,vz]
		append normArray [nx,ny,nz]
		append uvArray [tu,tv,0]
	)
	fseek f (dataArray[15].offset + (dataArray4[x].bufferOff * 2))#seek_set
	for i = 1 to dataArray4[x].faceCount do
	(
		f1 = readBEshort f + 1
		f2 = readBEshort f + 1
		f3 = readBEshort f + 1
		append faceArray [f1,f2,f3]
	)
	msh = mesh vertices:vertArray faces:faceArray
	msh.numTVerts = vertArray.count
	buildTVFaces msh
	for j = 1 to uvArray.count do setTVert msh j uvArray[j]
	for j = 1 to faceArray.count do setTVFace msh j faceArray[j]
	for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
	--for j = 1 to msh.numfaces do setFaceMatID msh j (MatID_Array[j] as integer)
	
	max modify mode
	select msh
	addmodifier msh (Edit_Normals ()) ui:off
	msh.Edit_Normals.MakeExplicit selection:#{1..normArray.count}
	EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
	EN_setNormal = msh.Edit_Normals.SetNormal
	normID = #{}

	for v = 1 to normArray.count do(
		free normID
		EN_convertVS #{v} &normID
		for id in normID do EN_setNormal id normArray[v]
	)
	
	maxOps.CollapseNodeTo msh 1 true -- Collapse the Edit Normals modifier
	Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
)
Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
--gc()
fclose f
