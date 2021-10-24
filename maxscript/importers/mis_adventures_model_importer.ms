
fn GetLinearStripArray VertCount = (
	local FaceArray = #()
	
	local WindCount = 0
	local WindClockwise = false
	local a = 1
	local b = 2
	do
	(
		WindCount += 1
		local c = WindCount -- linear part
		WindClockwise = not WindClockwise -- invert current wind direction
		if (a != b) AND (b != c) AND (c != a) then -- check if triangle isn't degenerate
		(
			if (WindClockwise) then append FaceArray [a,b,c]
			else append FaceArray [a,c,b]
		)
		a = b
		b = c
	)
	while (WindCount < VertCount)
	
	return FaceArray
)

clearlistener()
fname = getOpenFileName \ 
caption:"Open Model" \
types:"Mis-Adventures Model (*.*)|*.*" \
historyCategory:"Mis-Adventures Object Presets"

f = fopen fname "rb"
fseek f 0 #seek_end
fileEnd = ftell f
fseek f 0 #seek_set

vertArray = #()
uvArray = #()
faceArray = #()
while ( (ftell f) < fileEnd ) do
(
	append vertArray [ (readfloat f), (readfloat f), (readfloat f) ]
	fseek f 0x4 #seek_cur
	append uvArray [ (readfloat f), (readfloat f), 0 ]
	fseek f 0x28 #seek_cur
)
faceArray = (GetLinearStripArray vertArray.count)

msh = mesh vertices:vertArray faces:faceArray
msh.numTVerts = vertArray.count
buildTVFaces msh
for j = 1 to uvArray.count do setTVert msh j uvArray[j]
for j = 1 to faceArray.count do setTVFace msh j faceArray[j]
fclose f


