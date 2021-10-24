--import functions--
clearlistener()
fname = getOpenFileName \ 
caption:"Open File" \
types:"43 Model(*.43)|*.43|*.*|*.*" \
historyCategory:"Unity43 Object Presets"

fn ReadFixedString bstream fixedLen =
(
   local str = ""
   for i = 1 to fixedLen do
   (
      str0 = ReadByte bstream #unsigned
      if str0!=0xFD AND str0!=0xFC do str+= bit.intAsChar str0
   )
   str
)

if fname != undefined do (	
f = fopen fname "rb"
filename = GetFilenameFile fname

fseek f 0x5E8 #seek_set --Face Index Offset
FaceCount = readlong f
print ("FaceCount is "+FaceCount as string)
FaceArr = #()
for x = 1 to FaceCount/6 do ( --wtf
	f1 = readshort f + 1
	f2 = readshort f + 1
	f3 = readshort f + 1
	append FaceArr [f1,f2,f3]	
)
fseek f 0xDA14 #seek_set --Vertex Offset
VertCount = readlong f
VertArr = #()
TVertArr = #()
NormArr = #()
for x = 1 to VertCount/8 do (
	p1 = readfloat f
	p2 = readfloat f
	p3 = readfloat f
-- 	p4 = (readshort f)
-- 	p5 = (readshort f)
-- 	p6 = (readshort f)
-- 	p7 = (readshort f)
-- 	p8 = (readshort f)
	append VertArr [p1,p2,p3]
)

msh = mesh vertices:VertArr faces:FaceArr
-- msh.numTVerts = UV_array.count
msh.name = filename	
-- setNumCPVVerts msh msh.numTVerts
-- setCVertMode msh false
-- setShadeCVerts msh false
-- defaultVCFaces msh
-- buildTVFaces msh
-- convertTo msh PolyMeshObject
-- for j = 1 to UV_array.count do setTVert msh j UV_array[j]
-- for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
-- for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1


)

--end of file functions
Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
gc()
fclose f