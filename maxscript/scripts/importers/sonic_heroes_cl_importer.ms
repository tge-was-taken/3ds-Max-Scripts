

fn floatSwap2 f = (
	i = bit.floatAsInt f
	h = bit.intashex i
	while h.count < 8 do h = "0" + h
	
	s = (substring h 7 2) + (substring h 5 2) + (substring h 3 2) + (substring h 1 2)
	bit.intAsFloat (bit.hexasint s)
)	

fn readBEshort fstream = (
	short = readshort fstream #unsigned
	short = bit.swapBytes short 1 2
	return short
)

fn ReadBElong fstream = (
long = readlong fstream
long = bit.swapBytes long 1 4
long = bit.swapBytes long 2 3
return long
)

fn ReadBEfloat fstream = (
return floatSwap2(readfloat fstream)
)
clearlistener()

fname = GetOpenFileName caption:"Open Sonic Heroes Collision file" types:"cl File(*.cl)|*.cl"
f = fopen fname "rb"   --open file in read only format
filename = GetFilenameFile fname
clSize = readBElong f
face_offset = readBElong f
unk_offset = readBElong f
vert_offset = readBElong f
fseek f 0 #seek_end
file_end = ftell f

Vert_Array = #()
Face_Array = #()

fseek f face_offset #seek_set
try (
while ftell!= unk_offset do (
f2 = (ReadBEShort f) + 1
faceFlags = ReadBEShort f
f1 = (ReadBEShort f) + 1
f3 = (ReadBEShort f) + 1
append Face_Array (point3 f1 f2 f3)
print (((("f ")+f1 as string)+(" ")+f2 as string)+(" ")+f3 as string)
)
)catch

fseek f vert_offset #seek_set
Print ("Vertex Start @ 0x"+((bit.intAsHex(ftell f))as string))

try (
while ftell != file_end do (
vx = readBEfloat f
vy = readBEfloat f
vz = readBEfloat f
append Vert_Array [vx,vy,vz]
)
)catch (print "End of File reached!")

msh = mesh vertices:Vert_array faces:Face_array
msh.name = filename
Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
gc()
fclose f