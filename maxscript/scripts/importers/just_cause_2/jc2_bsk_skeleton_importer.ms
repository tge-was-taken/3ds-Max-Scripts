gc()
fn GetOpenFile = 
(
	clearlistener()
	local fname = getOpenFileName \ 
	caption:"Open Model" \
	types:"Skeleton file (*.bsk)|*.bsk" \
	historyCategory:"JC2RBM Object Presets"
	if (fname == undefined) then
	(
		return undefined
	)
	else
	(
		local f = fopen fname "rb"
		return f
	)
)

fn ReadVector4 fstream =
(
	return [(ReadFloat fstream), (ReadFloat fstream), (ReadFloat fstream), (ReadFloat fstream)]
) 

fn ReadQuat fstream = 
( 
	return (quat (ReadFloat fstream) (ReadFloat fstream) (ReadFloat fstream) (ReadFloat fstream))
)

parentBoneIdArray = #() 
boneArray = #() 
startOffset = 0x28C8 

file = GetOpenFile()
FSeek file startOffset #seek_set 

boneCount = ReadLong file #unsigned 
FSeek file 0x24 #seek_cur
rootName = ReadString file
rootNameLen = rootName.count
rootNameLen -= ((rootName.count / 0x10) * 0x10)
FSeek file ((0x10 - rootNameLen) - 1) #seek_cur

for i = 1 to boneCount do 
( 
	parentBoneIdArray[i] = ReadShort file
)

FSeek file 0x158 #seek_cur  -- biped.bsk
--FSeek file 0xA0 #seek_cur -- civilian_biped.bsk
--FSeek file 0x5E #seek_cur  -- parachute.bsk

for i = 1 to boneCount do
(
	pos = ReadVector4 file 
	rot = ReadQuat file 
	scl = ReadVector4 file 
	tfm = rot as matrix3 
	tfm *= scalematrix scl 
	tfm.row4 = pos

	if (parentBoneIdArray[i] != -1) then 
	(
		tfm *= boneArray[(parentBoneIdArray[i]+1)].objecttransform
	) 

	newBone = bonesys.createbone	\
		  tfm.row4	\
		  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
		  (normalize tfm.row3)
	--newBone.name = BoneName
	newBone.width  = 0.01
	newBone.height = 0.01
	newBone.transform = tfm
	newBone.setBoneEnable false 0
	newBone.wirecolor = yellow
	newbone.showlinks = true
	newBone.pos.controller      = TCB_position ()
	newBone.rotation.controller = TCB_rotation ()
										  
	if (parentBoneIdArray[i] != -1) then 
	(
		newBone.parent = boneArray[(parentBoneIdArray[i]+1)] 
	)
	
	Append boneArray newBone 
)

for i = 1 to boneCount do
(
	FSeek file 0x10 #seek_cur
	boneName = ReadString file
	boneArray[i].name = boneName
	skip = (0x10 - boneName.count - 1)
	if (boneName.count >= 0x10) then skip += 0x10
	FSeek file skip #seek_cur
)
