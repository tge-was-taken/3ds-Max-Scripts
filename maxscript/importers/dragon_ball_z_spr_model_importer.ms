
fn ReadFixedString bstream fixedLen =
(
   local str = ""
   for i = 1 to fixedLen do
   (
      str0 = ReadByte bstream #unsigned
      str+= bit.intAsChar str0
   )
   str
)

fn floatSwap2 fstream = (
	is = bit.floatAsInt fstream
	h = bit.intashex is
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

fn ReadBufferName fstream nameTableOffset = (
	nameOff = (readBElong fstream)
	savePos = ftell f
	fseek fstream (nameTableOffset + nameOff) #seek_set
	bufferName = readstring f
	fseek f savePos #seek_set
	return bufferName
)

fn ReadBufferName2 fstream nameOff nameTableOffset = (
	savePos = ftell f
	fseek fstream (nameTableOffset + nameOff) #seek_set
	bufferName = readstring f
	fseek f savePos #seek_set
	return bufferName
)

fn ReadFaces VertCount FaceType = (
	Face_array = #()
	
	if FaceType == 1 do (
		StartDirection = -1
		x=0
		a=0
		b=1
		c=2
		
		f1 = a + 1
		f2 = b + 1  
		FaceDirection = StartDirection
		do (
			x+=1
			
			f3 = x
			FaceDirection *= -1
			if (f1!=f2)AND(f2!=f3)AND(f3!=f1) then (
				if FaceDirection > 0 then append Face_array [f1,f2,f3]
				else append Face_array [f1,f3,f2]
			)
			f1 = f2
			f2 = f3
		)
		while (x < (vertcount))
	)
	
	if FaceType == 0 do (
		
		a=0
		b=0
		c=0
		
		For x=1 to vertcount by 3 do (
			a=x
			b=x+1
			c=x+2
			append face_array [a,b,c]
		)
-- 		print face_array
	)
	return Face_Array
)

struct SPR3_Struct 
(
	SPR3Tag,
	unk1,
	sectionCount,
	bufferTableOffset,
	xmbNameOffset,
	nameTableOffset,
	bufferInfoOffset,
	bufferOffset,
	EoFOffset,
	ioramNameOffset,
	ioramSize,
	vramNameOffset,
	vramSize
)

struct bufferHeader_Struct
(
	bufferTag,
	unk1,
	bufferCount
)

struct bufferInfo_Struct
(
	bufferTag,
	bufferID,
	bufferNameOffset,
	bufferOffset,
	bufferSize
)
 
struct bufferInfoArray_Struct
(
	bufferInfo_Array
)

struct MTRLtex_Struct
(
	texTypeName,
	texName
)

struct MTRLInfo_Struct
(
	MTRLtex_Array,
	MTRLTypeName
)

clearlistener()
fname = getOpenFileName \ 
caption:"Open Model" \
types:"SPR Model (*.SPR)|*.*|*.*|*.*" \
historyCategory:"DBZSPR Object Presets"
--st = timestamp() --get start time in milliseconds

f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = getFileNamePath fname
filetype = getFilenameType fname

fseek f 0 #seek_endf
FileEnd = ftell f
fseek f 0 #seek_set
print (("File Size = ")+(bit.intashex(fileEnd) as string))

SPR3Size = 0x40

bufferHeader_Array = #()
bufferInfo_Array = #()

SPR3Header = 
(
	SPR3_Struct \
	SPR3Tag:(readfixedstring f 4) \
	unk1:(readBElong f) \
	sectionCount:(readBElong f) \
	bufferTableOffset:(readBElong f) \
	xmbNameOffset:(readBElong f) \
	nameTableOffset:(readBElong f) \
	bufferInfoOffset:(readBElong f) \
	bufferOffset:(readBElong f) \
	EoFOffset:(readBElong f) \
	ioramNameOffset:(readBElong f) \
	ioramSize:(readBElong f) \
	vramNameOffset:(readBElong f) \
	vramSize:(readBElong f) \
)

i = fopen (filePath + (ReadBufferName2 f (SPR3Header.ioramNameOffset) (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset))) "rb"

fseek f (SPR3Size + SPR3Header.bufferTableOffset) #seek_set

for x = 1 to SPR3Header.sectionCount do
(
	bufferHeader = 
	(
		bufferHeader_Struct \
		bufferTag:(readfixedstring f 4) \
		unk1:(readBElong f) \
		bufferCount:(readBElong f) \
	)
	bufferHeader_Array[x] = bufferHeader
	print bufferHeader_Array[x]
)

fseek f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset + SPR3Header.bufferInfoOffset) #seek_set
	
for x = 1 to SPR3Header.sectionCount do 
(
	bufferInfo_Array = #()
	for y = 1 to bufferHeader_Array[x].bufferCount do
	(
		bufferInfo = 
		(
			bufferInfo_Struct \
			bufferTag:(readfixedstring f 4) \
			bufferID:(readBElong f) \
			bufferNameOffset:(readBufferName f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset)) \
			bufferOffset:(readBElong f) \
			bufferSize:(readBElong f) \
		)
		fseek f 0xC #seek_cur -- padding?
		bufferInfo_Array[y] = bufferInfo
	)
	bufferInfos_Array[x] = (bufferInfoArray_Struct bufferInfo_Array:bufferInfo_Array)
)

for x = 1 to SPR3Header.sectionCount do
(
	MTRLInfo_Array = #()
	for y = 1 to bufferHeader_Array[x].bufferCount do
	(
		case bufferInfos_Array[x].bufferInfo_Array[y].bufferTag of
		(
			("VBUF"): (
				fseek f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset + SPR3Header.bufferInfoOffset + SPR3Header.bufferOffset + bufferInfos_Array[x].bufferInfo_Array[y].bufferOffset) #seek_set
				print ("vbuf info @ 0x"+((bit.intAsHex(ftell f))as string))
				unk1 = readBElong f
				unk2 = readBElong f
				vertBufferOffset = readBElong f
				vertBufferSize = readBElong f
				vertCount = readBElong f
				unk2 = readBElong f
				
				Vert_Array = #()
				Face_Array = #()
				
				fseek i vertBufferOffset #seek_set
				print ("vbuf data @ 0x"+((bit.intAsHex(ftell i))as string))
				vertStride = vertBufferSize / vertCount
				for v = 1 to vertCount do 
				(
					vx = readBEfloat i
					vy = readBEfloat i
					vz = readBEfloat i
					fseek i (vertStride - 12) #seek_cur
					append Vert_Array [vx,vy,vz]
					--print ("Last Read @ 0x"+((bit.intAsHex(ftell i))as string))
				)
				--Face_Array = ReadFaces vertCount 0
				--print Face_Array
				msh = mesh vertices:Vert_Array faces:Face_Array
			)
			/*("SHAP"): (
				fseek f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset + SPR3Header.bufferInfoOffset + SPR3Header.bufferOffset + bufferInfos_Array[x].bufferInfo_Array[y].bufferOffset) #seek_set
				print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
			)*/
			("TX2D"): (
				fseek f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset + SPR3Header.bufferInfoOffset + SPR3Header.bufferOffset + bufferInfos_Array[x].bufferInfo_Array[y].bufferOffset) #seek_set
				unk1 = readBElong f
				texOffset = readBElong f
				unk2 = readBElong f
				texSize = readBElong f
				texWidth = readBEshort f
				texHeight = readBEshort f
				unk3 = readBEshort f
				unk4 = readBEshort f
				unk5 = readBElong f
				unk6 = readBElong f
				texName = (readBufferName f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset))
				fseek f 0xC #seek_cur -- padding?
			)
			("MTRL"): (
				fseek f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset + SPR3Header.bufferInfoOffset + SPR3Header.bufferOffset + bufferInfos_Array[x].bufferInfo_Array[y].bufferOffset) #seek_set
				fseek f 0x70 #seek_cur -- Material float data
				
				MTRLtex_Array = #()
				for m = 1 to 10 do
				(
					MTRLtex = 
					(
						MTRLtex_Struct \
						texTypeName:(readBufferName f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset)) \
						texName:(readBufferName f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset)) \
					)
					MTRLtex_Array[m] = MTRLtex
				)
				
				fseek f 0x60 #seek_cur -- more material flaots (?)
				MTRLTypeName = (readBufferName f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset))
				unk1 = readBElong f
				unk2 = readBElong f
				fseek f 0x14 #seek_cur -- null
				MTRLInfo_Array[y] = (MTRLInfo_Struct MTRLtex_array:MTRLtex_array MTRLTypeName:MTRLTypeName)
			)
			default: (
				print bufferInfos_Array[x].bufferInfo_Array[y].bufferTag
				fseek f (SPR3Size + SPR3Header.bufferTableOffset + SPR3Header.nameTableOffset + SPR3Header.bufferInfoOffset + SPR3Header.bufferOffset + bufferInfos_Array[x].bufferInfo_Array[y].bufferOffset) #seek_set
				--print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
			)
		)
	)
)
print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
fclose f
fclose i







