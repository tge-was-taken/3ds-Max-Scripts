fn ReadFixedString bstream fixedLen = (
    local str = ""
    for i = 1 to fixedLen do
    (
        str += bit.intAsChar (ReadByte bstream #unsigned)
    )
    str
)
clearlistener()

fname = GetOpenFileName caption:"Open BND file" types:"BND File(*.bnd)|*.bnd"
f = fopen fname "rb"   --open file in read only format

unk = readlong f
NameStrCount = readlong f
SkelName = readfixedstring f NameStrCount
BoneCount = readlong f

BNArr = #()

for a = 1 to bonecount Do (
Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
boneid = readlong f + 1
boneparent = readlong f + 1
f1 = readfloat f
f2 = readfloat f
f3 = readfloat f
f4 = readfloat f
f5 = readfloat f
f6 = readfloat f
f7 = readfloat f
tfm = (quat f4 f5 f6 (f7 * -1)) as matrix3
tfm.row4 = [f1,f2,f3]
if (boneparent != boneid) do (
tfm = tfm * BNArr[boneparent].objecttransform
 )	
newBone = bonesys.createbone	\
				  tfm.row4	\
				  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
				  (normalize tfm.row3)
			newBone.name = ((SkelName as string)+"_"+a as string)
			newBone.width  = 0.01
			newBone.height = 0.01
			newBone.transform = tfm
			newBone.setBoneEnable false 0
			newBone.wirecolor = yellow
			newbone.showlinks = true
			newBone.pos.controller      = TCB_position ()
			newBone.rotation.controller = TCB_rotation ()
 if (boneparent != 0) then
 newBone.parent = BNArr[boneparent]
append BNArr newBone
)

Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
gc()
fclose f