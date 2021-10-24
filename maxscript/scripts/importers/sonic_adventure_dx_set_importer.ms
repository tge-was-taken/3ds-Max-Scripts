--Hey a script no one's going to get use out of!
-- A Møøse once bit my sister.

struct ObjectEntry
(
	Type,
	ClipLevel,
	RotationVec,
	PositionVec,
	Prop1,
	Prop2,
	Prop3
)

clearlistener()
fname = getOpenFileName \ 
caption:"Open SET file" \
types:"SET file (*.bin)|*.bin" \
historyCategory:"SET Object Presets"

f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = getFileNamePath fname
fseek f 0 #seek_end
FileEnd = ftell f
fseek f 0 #seek_set

Global isBigEndian

test = readlong f
if (test != ((FileEnd / 0x20) - 1)) then isBigEndian = true
else isBigEndian = false
fseek f 0 #seek_set

fn floatSwap2 f = (
	i = bit.floatAsInt f
	h = bit.intashex i
	while h.count < 8 do h = "0" + h
	
	s = (substring h 7 2) + (substring h 5 2) + (substring h 3 2) + (substring h 1 2)
	bit.intAsFloat (bit.hexasint s)
)

fn ReadEndianShort fstream = (
	short = readshort fstream #unsigned
	if (isBigEndian) then short = bit.swapBytes short 1 2
	return short
)

fn ReadEndianBAMS fstream = (
	if (isBigEndian) then return (ReadEndianShort fstream as float /65536)*360
	else return (ReadEndianShort fstream as float /65536)*360
)

fn ReadEndianLong fstream = (
	long = readlong fstream #unsigned
	if (isBigEndian) then
	(
		long = bit.swapBytes long 1 4
		long = bit.swapBytes long 2 3
	)
	return long
)

fn ReadEndianFloat fstream = (
	floatValue = readfloat fstream
	if (isBigEndian) then floatValue = floatSwap2(floatValue)
	return floatValue
)

ObjectCount = ReadEndianLong f
fseek f 0x1C #seek_cur
for i = 1 to ObjectCount do
(
	Object = ObjectEntry()
	TypeBits = ReadEndianShort f
	Object.Type = bit.and TypeBits 0x0FFF
	Object.ClipLevel = bit.shift (bit.and TypeBits 0xF000) -12
	Object.RotationVec = [(ReadEndianBAMS f), (ReadEndianBAMS f), (ReadEndianBAMS f)]
	Object.PositionVec = [(ReadEndianFloat f), (ReadEndianFloat f), (ReadEndianFloat f)]
	Object.Prop1 = (ReadEndianFloat f)
	Object.Prop2 = (ReadEndianFloat f)
	Object.Prop3 = (ReadEndianFloat f)
	--format "%\n" Object
	
	ObjectTFM = (rotateXMatrix Object.RotationVec.X) * (rotateYMatrix Object.RotationVec.Y) * (rotateZMatrix Object.RotationVec.Z)
	ObjectTFM.row4 = [Object.PositionVec.x, Object.PositionVec.y, Object.PositionVec.z]
	-- OMG MATRIX MATH INCOMING
	ObjectTFM = matrix3 	[ObjectTFM[1][1] , -ObjectTFM[1][3],  ObjectTFM[1][2]] \ -- X
									[-ObjectTFM[3][1],  ObjectTFM[3][3], -ObjectTFM[3][2]] \ -- -Z
									[ObjectTFM[2][1] , -ObjectTFM[2][3],  ObjectTFM[2][2]] \ -- Y
									[ObjectTFM[4][1] , -ObjectTFM[4][3],  ObjectTFM[4][2]] -- Z
	
	ObjectDummy = dummy transform:ObjectTFM \
									name:("Type: " + Object.Type as string + " - " + "Prop1: " + Object.Prop1 as string + " - " + "Prop2: " + Object.Prop2 as string + " - " + " Prop3: " + Object.Prop3 as string)
)