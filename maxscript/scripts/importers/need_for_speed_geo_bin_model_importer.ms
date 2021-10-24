fn ReadFixedString bstream fixedLen =
(
   local str = ""
   for i = 1 to fixedLen do
   (
      str0 = ReadByte bstream #unsigned
      if str0!=0xFF AND str0!=0xFF do str+= bit.intAsChar str0
   )
   str
)

fn AlignOffset fstream relativeoffset alignment = (
	align = (alignment - (mod relativeoffset alignment as integer))
	align = fseek fstream align #seek_cur
	return align
)

fn FileEnd fstream = (
	fseek fstream 0 #seek_end
	fileEnd = ftell fstream
	fseek fstream 0 #seek_set
	return fileEnd
)

clearlistener()
fname = getOpenFileName \ 
caption:"Open File" \
types:"Geometry File (*.bin*)|*.bin*" \
historyCategory:"NFSGEO Object Presets"
f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = GetFilenamePath fname
fileEnd = fileEnd f

while (ftell f != fileEnd) do (
	ChunkID = readlong f
	ChunkSize = readlong f
	ChunkStart = ftell f
	format "Chunk ID: 0x%\n" (bit.intashex (ChunkID))
	case ChunkID of (
		0x00000000:(
			format "Padding\n"
			fseek f ChunkSize #seek_cur
		)
		0x80134000:(
			format "File start\n"
			fseek f 0x8 #seek_cur
		)
		0x80134001:( -- Needs filling in
			format "Unknown Data\n"
			fseek f ChunkSize #seek_cur
		)
		0x80134010:(
			format "Object Start @ 0x%\n" ChunkStart
		)
		0x00134011:( -- Needs filling in
			format "Object Info @ 0x%\n" ChunkStart
			fseek f ChunkSize #seek_cur
		)
		0x00134012:( -- Needs filling in
			format "Object Info @ 0x%\n" ChunkStart
			fseek f ChunkSize #seek_cur
		)
		0x00134012:( -- Needs filling in
			format "Unknown data @ 0x%\n" ChunkStart
			fseek f ChunkSize #seek_cur
		)
		0x80134100:(
			format "Start of something @ 0x%\n" ChunkStart
		)
		0x00134900:(
			format "Unknown data @ 0x%\n" ChunkStart
			fseek f ChunkSize #seek_cur
		)
		0x00134B01:(
			format "Vertex Chunk @ 0x%\n" ChunkStart
			AlignOffset f ChunkStart 0x100
			Vert_Array = #()
			UV_Array = #()
			Color_Array = #()
			Face_Array = #()
-- 			while (ftell f != (ChunkStart + ChunkSize)) do (
-- 				vx = readfloat f
-- 				vy = readfloat f
-- 				vz = readfloat f
-- 				cr = readbyte f
-- 				cg = readbyte f
-- 				cb = readbyte f
-- 				ca = readbyte f
-- 				tu = readfloat f
-- 				tv = readfloat f
-- 				append Vert_Array [vx,vy,vz]
-- 				append UV_Array [tu,tv,0]
-- 				append Color_Array [cr,cg,cb]
-- 				msh = mesh Vertices:Vert_Array Faces:Face_Array
-- 			)
			while (ftell f != (ChunkStart + ChunkSize)) do (
				vx = readfloat f
				vy = readfloat f
				vz = readfloat f
				nx = readfloat f
				ny = readfloat f
				nz = readfloat f
				cr = readbyte f
				cg = readbyte f
				cb = readbyte f
				ca = readbyte f
				tu = readfloat f
				tv = readfloat f
				append Vert_Array [vx,vy,vz]
				append UV_Array [tu,tv,0]
				append Color_Array [cr,cg,cb]
				msh = mesh Vertices:Vert_Array Faces:Face_Array
			)
		)
		default:(
			fseek f ChunkSize #seek_cur
		)
	)
	Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
)
gc()
fclose f