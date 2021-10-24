/* Wonderful 101 WMB MaxScript Model Importer by TGE
	Credit would be nice ;)
	Please report any issues
	
	TODO:
	- Automatic texture assignment
*/

global WMB101ImportNormals = false

/* Reading functions */
fn ReadU16BE fstream = 
(
	/* Implicit return */
	bit.swapBytes (readshort fstream #unsigned) 1 2
)

fn ReadU32BE fstream = 
(
	/* Implicit return */
	bit.swapBytes (bit.swapBytes (readlong fstream #unsigned) 1 4) 2 3
)

fn ReadF32BE fstream = 
(
	/* Implicit return */
	bit.intAsFloat (bit.swapBytes (bit.swapBytes (readlong fstream #unsigned) 1 4) 2 3)
)

fn ReadF16BE Fstream = 
(
	local BH  = readByte Fstream #unsigned
	local BL  = readByte Fstream #unsigned
	local N = BH*256 + BL
	local S = floor((mod N 65536) / 32768)
	local Ef = floor((mod N 32768) / 1024)
	local M = mod N 1024
	
	local RetValue = 0
	if ((Ef==0) AND(M==0))		then RetValue = ( (-1.0)^S * 0.0 )
	if ((Ef==0)AND(M!=0))		then RetValue = ( (-1.0)^S * 2.0^-14 * (M / 2.0^10) )
	if ((Ef>0)AND(Ef<31))		then RetValue = ( (-1.0)^S * 2.0^(Ef-15) * (1 + M/2.0^10) )
	if ((Ef==31)AND(M==0))	then RetValue = ( (-1.0)^S * 1/0.0 )
	if ((Ef==31)AND(M!=0)) 	then RetValue = 0	--hack-- should be #inf   
	
	/* Implicit return */
	RetValue
)

fn ReadFixedString fstream fixedLen = (
	
	local str = ""
	for strlen = 1 to fixedLen do
	(
		str += bit.intAsChar (ReadByte fstream #unsigned)
	)
	
	/* Implicit return */
	str
)

fn addSkinBones boneObject boneCount skinMod index addBone =
(
	maxBone = boneObject
	if index != boneCount then
		addBone skinMod maxBone 0
	else
		addBone skinMod maxBone 1
)

fn addSkinWeights weightData skinMod index replaceSkinWeights =
(
   w = weightData
   bi = #() --bone index array
   wv = #() --weight value array
   
   for j = 1 to w.boneids.count do
   (
	  boneid = w.boneids[j]
	  weight = w.weights[j]
	  append bi boneid
	  append wv weight
   )   
   
   replaceSkinWeights skinMod index bi wv
)

fn addSkin msh boneCount boneArray weightArray vertCount =
(
	max modify mode
	select msh
	skinMod = skin ()
	addModifier msh skinMod
	addBone = skinOps.addBone
	replaceWeights = skinOps.ReplaceVertexWeights
	for i = 1 to boneCount do
	(  
		addSkinBones boneArray[i] boneCount skinMod i addBone
	)
	modPanel.setCurrentObject skinMod
	for i = 1 to vertCount do (
		addSkinWeights weightArray[i] skinMod i replaceWeights
	)
)

fn UnpackNormal packedNormal = 
(
	xInt = bit.and packedNormal 0x7FF
	yInt = bit.shift (bit.and packedNormal 0x3FF800) -11
	zInt = bit.shift (bit.and packedNormal 0xFFC00000) -22
		
	normal = [0,0,0]
	normal.X = xInt as float / 1023
	normal.Y = yInt as float / 1023
	normal.Z = zInt as float / 511
	
	/* Implicit return */
	normal
)

struct weight_data
(
	boneids,weights
)

rollout importRollout "Import dialog" width:205 height:172
(
	button btn1 "Import model" pos:[36,106] width:132 height:50
	checkbox flipUVChk "Flip UV" pos:[36,8] width:132 height:20 checked:true
	checkbox modelFlipChk "Flip Model" pos:[36,29] width:132 height:20 checked:true
	checkbox weightChk "Import weights" pos:[36,50] width:132 height:20 checked:true
	spinner modelSclSpn "Model Scale" pos:[36,77] width:132 height:16 range:[0,100,1] type:#float scale:0.1
	on btn1 pressed do
	(
		clearlistener()
		--enableSceneRedraw()
		if (heapSize < 20000000) then
			heapSize = 200000000 -- allow ~ 40 MB instead of just 7.5 MB. Prevents "Runtime Error: Out of scripter memory"

		fname = GetOpenFileName caption:"Open WMB/SCR" types:"WMB/SCR File(*.*)|*.*"
		if fname != undefined do(
		undo off
		(
		f = fopen fname "rb"
		filename = GetFilenameFile fname
		filepath = GetFilenamePath fname

		--disableSceneRedraw()

		type = readfixedstring f 4
		if (type == "SCR") then
		(
			scrFlag = ReadU16BE f
			wmbCount = ReadU16BE f
			offsetTableOff = ReadU32BE f
			fseek f offsetTableOff #seek_set
			wmbOffsetArray = #()
			for i = 1 to wmbCount do wmbOffsetArray[i] = (ReadU32BE f)
		)
		else if (type == "BMW") then wmbCount = 1
		else wmbCount = 0

		for wmb = 1 to wmbCount do
		(
			if (wmbOffsetArray != undefined) then 
			(
				fseek f wmbOffsetArray[wmb] #seek_set
				dataStart = ReadU32BE f
				meshName = readstring f
				fseek f (dataStart + 4) #seek_set
			) 
			else meshName = fileName
			
			wmbStart = (ftell f - 4)
			headerFlagsArray = #()
			for i = 1 to 5 do headerFlagsArray[i] = (ReadU32BE f)

			vertexStart = ReadU32BE f
			vertexColorStart = ReadU32BE f
			fseek f 0x10 #seek_cur -- padding

			headerTableArray = #()
			for i = 1 to 20 do headerTableArray[i] = (ReadU32BE f)
			-- 1 = boneCount
			-- 2 = bone parent table
			-- 3 = local bone vector3
			-- 4 = world bone vector3
			-- 5 = animTable.. thing
			-- 6 = matCount
			-- 7 = matOffsetTable offset
			-- 8 = matDataOffset
			-- 9 = meshCount
			-- 10 = meshOffsetTable offset
			-- 11 = meshDataOffset
			
			/* Hacky way to get the vertex size... searched far and wide but couldn't find any consistent flags */
			if (vertexColorStart != 0) then vertexSize = (vertexColorStart - vertexStart) / headerFlagsArray[3]
			else if (headerTableArray[2] != 0) then vertexSize = (headerTableArray[2] - vertexStart) / headerFlagsArray[3]
			else if (headerTableArray[17] != 0) then vertexSize = (headerTableArray[17] - vertexStart) / headerFlagsArray[3]
			else if (headerTableArray[7] != 0) then vertexSize = (headerTableArray[7] - vertexStart) / headerFlagsArray[3] -- hack for SCR wmbs
			vertexSize = vertexSize + (mod vertexSize 4) -- alignment might offset the count by 1 or 2, rounding the number...
			

			boneParentsArray = #()
			if headerTableArray[1] != 0 then
			(
				fseek f (wmbStart + headerTableArray[2]) #seek_set
				for i = 1 to headerTableArray[1] do boneParentsArray[i] = (ReadU16BE f)

				boneArray = #()
				fseek f (wmbStart + headerTableArray[4]) #seek_set
				for i = 1 to headerTableArray[1] do
				(
					p1 = ReadF32BE f * modelSclSpn.value
					p2 = ReadF32BE f * modelSclSpn.value
					p3 = ReadF32BE f * modelSclSpn.value
					tfm = (scalematrix [1,1,1])
					if (modelFlipChk.checked) then tfm = tfm * (transmatrix [p1,-p3,p2])
					else tfm = tfm * (transmatrix [p1,p2,p3])
					newBone = bonesys.createbone	\
								  tfm.row4	\
								  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
								  (normalize tfm.row3)
							newBone.name = ("Bone"+(i as string))
							newBone.width  = 0.01
							newBone.height = 0.01
							newBone.transform = tfm
							newBone.setBoneEnable false 0
							newBone.wirecolor = yellow
							newbone.showlinks = true
							newBone.pos.controller      = TCB_position ()
							newBone.rotation.controller = TCB_rotation ()
							If boneParentsArray[i] != 0xFF Do (
								newBone.parent = boneArray[boneParentsArray[i]+1]
							)
					append boneArray newBone
				)
			)
			
			
			if headerTableArray[17] != 0 then
			(
				fseek f (wmbStart + headerTableArray[17]) #seek_set
				Print ("Last Read @ 0x"+((bit.intAsHex(ftell f))as string))
				for i = 1 to headerTableArray[6] do
				(
					shaderName = readfixedstring f 16
					shaderType = filterstring shaderName "_"
					format "wmb: % shaderName: %\n" wmb shaderName
				)
			)

			meshOffsetArray = #()
			if headerTableArray[9] != 0 then
			(
				fseek f (wmbStart + headerTableArray[10]) #seek_set
				for i = 1 to headerTableArray[9] do meshOffsetArray[i] = (ReadU32BE f)

				for i = 1 to headerTableArray[9] do
				(
					fseek f (wmbStart + headerTableArray[11] + meshOffsetArray[i]) #seek_set
					start = ftell f
					meshID = ReadU16BE f + 1
					subMeshCount = ReadU16BE f
					unk2 = ReadU32BE f -- always 2
					meshDataOffsetTableOff = ReadU32BE f
					unk3 = ReadU32BE f -- always -2147483648
					matName = readfixedstring f 0x30
					fseek f (start + meshDataOffsetTableOff) #seek_set
						
					start = ftell f
					meshDataOffsetArray = #()
					for z = 1 to subMeshCount do meshDataOffsetArray[z] = (ReadU32BE f)
						
					for x = 1 to subMeshCount do 
					(
						fseek f (start + meshDataOffsetArray[x]) #seek_set
						smStart = ftell f
						smID = ReadU16BE f + 1
						matID = ReadU16BE f + 1
						unk7 = ReadU16BE f + 1
						shaderID = ReadU16BE f + 1
						texID = readbyte f + 1
						format "submesh: % matID: % texID: %\n" smID matID texID
						unk8 = readbyte f
						unk9 = ReadU16BE f
						vertStart = ReadU32BE f 
						vertEnd = ReadU32BE f
						primType = ReadU32BE f
						faceBufferOff = ReadU32BE f
						faceCount = ReadU32BE f
						vertStart2 = ReadU32BE f-- equal to vertStart
						fseek f 0x1C #seek_cur --padding
						usedBoneCount = ReadU32BE f
						if (usedBoneCount >= 1) then useBonePallet = true
						else useBonePallet = false
						usedBoneArray = #()
						for y = 1 to usedBoneCount do
						(
							usedBoneArray [y] = ((readbyte f #unsigned) + 1)
						)
						fseek f (smStart + faceBufferOff) #seek_set
						
						faceEnd = ftell f + (faceCount * 2)
						faceArray = #()
						
						case primType of
						(
							5: (
								StartDirection = 1
								f1 = (ReadU16BE f) + 1
								f2 = (ReadU16BE f) + 1  
								FaceDirection = StartDirection
								Do 
								(
									f3 = (ReadU16BE f)
									if (f3==0xFFFF) then 
									(
										f1 = (ReadU16BE f) + 1
										f2 = (ReadU16BE f) + 1
										FaceDirection = StartDirection 
									)
									else 
									(
										f3 += 1
										FaceDirection *= -1
										if (f1 != f2) AND (f2 != f3) AND (f3 != f1) then 
										(
											if FaceDirection > 0 then append faceArray [f3,f2,f1]
											else append faceArray [f2,f3,f1]
										)
										f1 = f2
										f2 = f3
									)
								) while (not((ftell f) >= (faceEnd)))
							)
							4: (
								for face = 1 to faceCount / 3 do
								(
									f1 = (ReadU16BE f) + 1
									f2 = (ReadU16BE f) + 1
									f3 = (ReadU16BE f) + 1
									append faceArray [f3,f2,f1]
								)
							)
							default: (
								throw ("Unsupported primitive type "+ primType as string)
							)
						)
						
						vertCount = (vertEnd - vertStart)
						
						fseek f (wmbStart + vertexStart + (vertStart * vertexSize)) #seek_set
							
						vertArray = #()
						uvArray = #()
						weightArray = #()
						nrmArray = #()
						vertColorArray = #()
							
						vertArray[vertCount] = [0,0,0]
						uvArray[vertCount] = [0,0,0]
						nrmArray[vertCount] = [0,0,0]
						vertColorArray[vertCount] = [0,0,0]
							
						if (headerTableArray[1] != 0) then
						(
							weightArray[vertCount] = 0
						)
							
						for v = 1 to vertCount do
						(
							if (vertexSize >= 0x14) then
							(
								vx = ReadF32BE f * modelSclSpn.value
								vy = ReadF32BE f * modelSclSpn.value
								vz = ReadF32BE f * modelSclSpn.value
								tu = ReadF16BE f
								if (flipUVChk.checked) then tv = (ReadF16BE f *-1) + 1
								else tv = ReadF16BE f
								nrm = UnpackNormal (ReadU32BE f)
							)
							else
							(
								throw "Invalid vertex data. This shouldn't happen"
							)
							
							if (vertexSize >= 0x18) then
							(
								tangent = UnpackNormal (ReadU32BE f)
							)
							
							if (vertexSize >= 0x1C) then
							(
								bone1 = readbyte f #unsigned
								bone2 = readbyte f #unsigned
								bone3 = readbyte f #unsigned
								bone4 = readbyte f #unsigned
							)
							else
							(
								bone1 = 0
								bone2 = 0
								bone3 = 0
								bone4 = 0
							)
							
							if (vertexSize >= 0x20) then
							(
								weight1 = readbyte f #unsigned
								weight2 = readbyte f #unsigned
								weight3 = readbyte f #unsigned
								weight4 = readbyte f #unsigned
							)
							else 
							(
								weight1 = 1
								weight2 = 0
								weight3 = 0
								weight4 = 0
							)
							if (vertexSize >= 0x24) then throw "Vertex size not supported"
							
							if (modelFlipChk.checked) then vertArray[v] = [vx,-vz,vy]
							else vertArray[v] = [vx,vy,vz]
							if (modelFlipChk.checked) then nrmArray[v] = [nrm.X, -nrm.Z, nrm.Y]
							else nrmArray[v] = nrm
							uvArray[v] = [tu,tv,0]
							
							if headerTableArray[1] != 0 then
							(
								w = (weight_data boneids:#() weights:#())
								maxweight = 0
								if(weight1 != 0) then
									maxweight = maxweight + weight1
								if(weight2 != 0) then
									maxweight = maxweight + weight2
								if(weight3 != 0) then
									maxweight = maxweight + weight3
								if(weight4 != 0) then
									maxweight = maxweight + weight4


								if(maxweight != 0) then (
									if(weight1 != 0) then (
										w1 = weight1 as float
										if (useBonePallet) then append w.boneids (usedBoneArray[(bone1+1)])
										else append w.boneids ((bone1+1))
										append w.weights (w1/255.0)
									)
									if(weight2 != 0) then (
										w2 = weight2 as float
										if (useBonePallet) then append w.boneids (usedBoneArray[(bone2+1)])
										else append w.boneids ((bone2+1))
										append w.weights (w2/255.0)
									)
									if(weight3 != 0) then (
										w3 = weight3 as float
										if (useBonePallet) then append w.boneids (usedBoneArray[(bone3+1)])
										else append w.boneids ((bone3+1))
										append w.weights (w3/255.0)
									)
									if(weight4 != 0) then (
										w4 = weight4 as float
										if (useBonePallet) then append w.boneids (usedBoneArray[(bone4+1)])
										else append w.boneids ((bone4+1))
										append w.weights (w4/255.0)
									)      
								)
								weightArray[v] = w	
							)
						)
						
						if (vertexColorStart != 0) then
						(
							fseek f (wmbStart + vertexColorStart + (vertStart * 4)) #seek_set
							
							for v = 1 to vertCount do
							(
								vertColorArray[v] = [ReadByte f #unsigned, ReadByte f #unsigned, ReadByte f #unsigned, ReadByte f #unsigned]
							)
						)
						
						msh = mesh vertices:vertArray faces:faceArray
						msh.numTVerts = vertArray.count
						msh.name = wmb as string + "_" + meshName + "_" + smID as string + "_" + matName
						msh.material = standard()
						msh.material.name = matName
						msh.backfacecull = on
						buildTVFaces msh
						
						for j = 1 to faceArray.count do setTVFace msh j faceArray[j]
						for j = 1 to uvArray.count do setTVert msh j uvArray[j]
						for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
						
						if (vertexColorStart != 0) then
						(
							setNumCPVVerts msh msh.numverts
							defaultVCFaces msh
							for j = 1 to vertColorArray.Count do SetVertColor msh j vertColorArray[j]
						)
						
						--tm = Bitmaptexture filename:((filepath+filename+"_"+(matID) as string)+".dds")
						--msh.material.DiffuseMap = tm
						msh.material.showinViewport = true
						if (not weightChk.checked) then weightArray.count = 0
						
						if (WMB101ImportNormals == true) then (
							max modify mode
							select msh
							addmodifier msh (Edit_Normals ()) ui:off
							msh.Edit_Normals.MakeExplicit selection:#{1..nrmArray.count}
							EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
							EN_setNormal = msh.Edit_Normals.SetNormal
							normID = #{}

							for v = 1 to nrmArray.count do(
								free normID
								EN_convertVS #{v} &normID
								for id in normID do EN_setNormal id nrmArray[v]
							)
						)
						--maxOps.CollapseNodeTo msh 1 true -- Collapse the Edit Normals modifier
						
						if weightArray.count != 0 then 
						(
							addSkin msh headerTableArray[1] boneArray weightArray vertCount
						)
					)
				)
			)
		)
		gc()
		fclose f
		--enableSceneRedraw()
		print "Import successful!"
		)
		)
	)
)

CreateDialog importRollout