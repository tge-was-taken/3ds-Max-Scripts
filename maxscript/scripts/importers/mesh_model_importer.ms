
fn ReadFixedString bstream fixedLen = (
    local str = ""
    for i = 1 to fixedLen do
    (
        str += bit.intAsChar (ReadByte bstream #unsigned)
    )
    str
)

-- To anyone reading this, this algorithm probably sucks but it works and I don't care to perfect it :D
fn BinaryFindString fstream str = (
	local StringBytes = #()
	for i = 1 to str.count do
	(
		append StringBytes (bit.charasint str[i])
	)
	local End = false
	
	local RealStartPos = ftell fstream
	fseek fstream 0 #seek_end
	local FileEnd = ftell fstream
	fseek fstream RealStartPos #seek_set
	
	local ReadBytes = #()
	while (not End) do
	(
		local StartPos = ftell fstream
		for i = 1 to str.count do
		(
			if (ftell fstream != FileEnd) then
			(
				ReadBytes[i] = (readbyte fstream)
				if (ReadBytes[i] == StringBytes[i]) then continue
				else exit
			)
			else End = true
		)
		if (ReadBytes.count == str.count) then 
		(
			fseek fstream RealStartPos #seek_set
			return StartPos
		)
		else StartPos += 1
		fseek fstream StartPos #seek_set
	)
	return undefined
)

fn ReadHalfFloat fstream = (
    hf=readshort fstream #unsigned
    sign = bit.get hf 16
    exponent = (bit.shift (bit.and hf (bit.hexasint "7C00")) -10) as integer - 16
    fraction = bit.and hf (bit.hexasint "03FF")
    if sign==true then sign = 1 else sign = 0
    exponentF = exponent + 127
    outputAsFloat = bit.or (bit.or (bit.shift fraction 13) \
    (bit.shift exponentF 23)) (bit.shift sign 31)
    return bit.intasfloat outputasfloat*2
)

fn ReadVector3_Int fstream = (
	return [(readshort fstream #signed as float)/32767, (readshort fstream #signed as float)/32767, (readshort fstream #signed as float)/32767]
)

fn ReadVector3_HF fstream = (
	return [(ReadHalfFloat fstream), (ReadHalfFloat fstream), (ReadHalfFloat fstream)]
)

fn ReadVector3 fstream = (
	return [(readfloat fstream), (readfloat fstream), (readfloat fstream)]
)

fn ReadVector2_HF fstream = (
	return [(ReadHalfFloat fstream), -(ReadHalfFloat fstream), 0]
)

clearlistener()

fname = GetOpenFileName caption:"Open Mesh file" types:"Mesh File(*.Mesh)|*.Mesh"
f = fopen fname "rb"   --open file in read only format
base = getFilenamePath fname
basefile = getFilenameFile fname
basefilec = basefile.count
ss = substring base 1 (base.count - (basefilec + 5)) -- returns "rof"
print "ss "+ss
h = fopen (basefile + ".Mesh" + ".header") "rb"
hsem = readfixedstring h 4
null = readlong h
-- Bounding Box
bbox = #()
for i = 1 to 6 do bbox[i] = (ReadVector3 h)
	
mtrl = readfixedstring h 4
MatCount = readlong h
MatNameArray = #()
TexNameArray = #()
format "\nMaterial Paths\n"
for m = 1 to MatCount do (
	MatPathLen = readlong h
	MatPath = ReadFixedString h MatPathLen
	print (MatPath + ".Material")
	MatPath = filterString MatPath "/"
	MatName = MatPath[MatPath.count]
	append MatNameArray MatName
	local found = false
	if (doesFileExist (base + MatName + ".Material")) then
	(
		m = fopen (base + MatName + ".Material") "rb"
		MatData = readstring m
		MatData = filterString MatData ";"
		for i = 1 to MatData.count do
		(
			TexName = findstring MatData[i] "DiffuseTexture"
			if (TexName != undefined) then
			(
				TexName = filterstring MatData[i] "/"
				TexName = TexName[TexName.count] + ".dds"
				append TexNameArray TexName
				found = true
				exit
			)
			else continue
		)
	)
	if (not found) then append TexNameArray (MatName + ".dds")
)
format "\n"

MeshCount = readlong h
for x = 1 to MeshCount do (
	
	Vert_Array = #()
	Face_Array = #()
	UV_Array = #()
	
	fseek h (BinaryFindString h "tsbs") #seek_set -- find the string in the file, lazy way!
	
	SBST = readfixedstring h 4
	MatID = readlong h + 1
	Unknown2 = readlong h -- always 1?
	format "%\nMatID = %\nUnknown2 = %\n\n" SBST MatID Unknown2
	DXVB = readfixedstring h 4 -- Direct X Vertex Buffer
	VertexCount = readshort h
	Unknown3 = readlong h 
	Unknown4 = readlong h
	format "%\nVertexCount = %\nUnknown3 = %\nUnknown4 = %\n\n" DXVB VertexCount Unknown3 Unknown4
	DXIB = readfixedstring h 4 -- Direct X Index Buffer
	Unknown5 = readlong h -- Null?
	FaceCount = readlong h
	Unknown6 = readlong h
	format "%\nUnknown5 = %\nFaceCount = %\nUnknown6 = %\n\n" DXIB Unknown5 FaceCount Unknown6
	
	format "Vertex Start = %\n" (bit.intashex(ftell f))
	for v = 1 to VertexCount do
	(
		b1 = readbyte f #unsigned + 1
		b2 = readbyte f #unsigned + 1
		b3 = readbyte f #unsigned + 1
		b4 = readbyte f #unsigned + 1
		w1 = readbyte f #unsigned
		w2 = readbyte f #unsigned
		w3 = readbyte f #unsigned
		w4 = readbyte f #unsigned
		append Vert_Array (ReadVector3_Int f)
		fseek f 0x2 #seek_cur
		append UV_Array (ReadVector2_HF f)
		fseek f 0x1C #seek_cur
	)
	
	for y = 1 to FaceCount/3 do (
		f1 = readshort f+1
		f2 = readshort f+1
		f3 = readshort f+1
		append Face_Array [f1,f2,f3]
	)
	
	msh = mesh vertices:Vert_Array faces:Face_Array
	msh.numTVerts = UV_Array.count
	msh.name = basefile + "_" + x as string	
	buildTVFaces msh
	for j = 1 to UV_array.count do setTVert msh j UV_array[j]
	for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
	for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
		
	msh.material = Standard()

	if (not MatID > TexNameArray.count) then
	(
		tm = Bitmaptexture filename:(base + "\\" + TexNameArray[MatID])
		msh.material.diffuseMap = tm
	)
	msh.material.name = (MatNameArray[MatID])
	msh.material.showInViewport = true
	msh.name = (MatNameArray[MatID])
)





print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
gc()
fclose f