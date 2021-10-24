fn ReadFixedString bstream fixedLen = (
    local str = ""
    for i = 1 to fixedLen do
    (
        str += bit.intAsChar (ReadByte bstream #unsigned)
    )
    str
)
clearlistener()

fname = GetOpenFileName caption:"Open BUD file" types:"BUD File(*.bud)|*.bud"
f = fopen fname "rb"   --open file in read only format
filename = GetFilenameFile fname
MeshCount = readshort f #unsigned
fseek f 0x7 #seek_cur
for m = 1 to MeshCount do (
VertCount = readlong f
-- Print ("Vertex Start @ 0x"+((bit.intAsHex(ftell f))as string))

UV_Array = #()
Vert_Array = #()
Normal_Array = #()
Face_Array = #()

for x = 1 to VertCount do (
f1 = readfloat f
f2 = readfloat f
f3 = readfloat f
f4 = readfloat f
f5 = readfloat f
f6 = readfloat f
f7 = readfloat f*-1
f8 = readfloat f*-1
append Vert_Array [f1,f2,f3]
append Normal_Array [f4,f5,f6]
append UV_Array [f7,f8,0]
)

FaceCount = readlong f
-- Print ("Face start @ 0x"+((bit.intAsHex(ftell f))as string))

for x = 1 to FaceCount/3 do (
f1 = readshort f+1
f2 = readshort f+1
f3 = readshort f+1
append Face_Array [f1,f2,f3]
)
fseek f 0x5 #seek_cur
msh = mesh vertices:Vert_array faces:Face_array
msh.numTVerts = UV_array.count
-- msh.material = meditMaterials[1]
msh.name = ((filename)+"_"+(m as string))
buildTVFaces msh
for j = 1 to UV_array.count do setTVert msh j UV_array[j]
for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
for j = 1 to Normal_array.count do setNormal msh j Normal_array[j]
max modify mode
select msh
	addmodifier msh (Edit_Normals ()) ui:off
	msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
	EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
	EN_setNormal = msh.Edit_Normals.SetNormal
	normID = #{}

	for v = 1 to Normal_array.count do(
		free normID
		EN_convertVS #{v} &normID
		for id in normID do EN_setNormal id Normal_array[v]
	)
	
maxOps.CollapseNodeTo $ 1 off
clearSelection ()
)
Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
gc()
fclose f