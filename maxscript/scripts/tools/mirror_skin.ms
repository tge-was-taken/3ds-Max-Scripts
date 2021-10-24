-- FUNCTION CACHE
maxOps_cloneNodes = maxOps.cloneNodes
maxOps_CollapseNodeTo = maxOps.CollapseNodeTo
modPanel_setCurrentObject = modPanel.setCurrentObject
skinOps_GetNumberBones = skinOps.GetNumberBones
skinOps_GetBoneIDByListID = skinOps.GetBoneIDByListID
skinOps_GetBoneName = skinOps.GetBoneName
skinOps_SelectBone = skinOps.SelectBone
skinOps_ReplaceVertexWeights = skinOps.ReplaceVertexWeights
skinOps_AddBone = skinOps.AddBone
skinOps_getVertexWeightCount = skinOps.getVertexWeightCount
skinOps_getVertexWeightBoneId = skinOps.getVertexWeightBoneId
skinOps_getVertexWeight = skinOps.getVertexWeight
--

fn cloneObj obj =
(
    maxOps_cloneNodes obj cloneType:#copy newNodes:&nnl
    nnl[1]
)

fn mirrorSkinnedObj obj =
(
    select obj
    addModifier $ (mirror ()) before:1
    maxOps_CollapseNodeTo $ 2 off
)

fn selectSkinMod obj =
(
    local skinMod = obj.modifiers[#Skin]
    modPanel_setCurrentObject skinMod
    skinMod
)

fn getBoneListId skinMod boneName =
(
    local boneCount = skinOps_GetNumberBones skinMod
    for i = 1 to boneCount do
    (
        local curBoneId = skinOps_GetBoneIDByListID skinMod i
        local curBoneName = skinOps_GetBoneName skinMod curBoneId 0
        if (stricmp curBoneName boneName == 0) then return i
    )
    
    return -1
)

fn getBoneId skinMod boneName = 
(
    local boneCount = skinOps_GetNumberBones skinMod
    for i = 1 to boneCount do
    (
        local curBoneId = skinOps_GetBoneIDByListID skinMod i
        local curBoneName = skinOps_GetBoneName skinMod curBoneId 0
        if (stricmp curBoneName boneName == 0) then return curBoneId
    )
    
    return -1
)

fn getBoneNameByBoneId skinMod boneId =
(
    local boneCount = skinOps_GetNumberBones skinMod
    for i = 1 to boneCount do
    (
        local curBoneId = skinOps_GetBoneIDByListID skinMod i
        local curBoneName = skinOps_GetBoneName skinMod curBoneId 0
        if (curBoneId == boneId) then return curBoneName
    )
    
    return undefined
)

fn removeSkinBoneContaining skinMod pattern ignoreCase =
(
    local boneCount = skinOps_GetNumberBones skinMod
    for i = 1 to boneCount do
    (
        local boneId = skinOps_GetBoneIDByListID skinMod i
        local boneName = skinOps_GetBoneName skinMod boneId 0
        if matchPattern boneName pattern:("*"+pattern+"*") ignoreCase:ignoreCase then
        (
            print ("Removing " + boneName + " " + boneId as string)
            skinOps_SelectBone skinMod boneId
            skinOps.RemoveBone skinMod
            return true
        )
    )
    
    false
)

fn removeSkinBonesContaining skinMod pattern =
(
    modPanel_setCurrentObject skinMod
    max modify mode;
    while ( removeSkinBoneContaining skinMod pattern ) do ()
)

fn copyBoneWeightsToBone skinMod boneAName boneBName =
(
    modPanel_setCurrentObject skinMod
    
    print ("copyBoneWeightsToBone(" + skinMod as string + ", " + boneAName + ", " + boneBName + ")")
    
    local boneAId = getBoneId skinMod boneAName
    local boneBId = getBoneId skinMod boneBName
    if (boneAId == -1 or boneBId == -1) then break()
    
    local vertexCount = skinOps.GetNumberVertices skinMod
    for v = 1 to vertexCount do
    (
        local vertexWeightCount = skinOps_getVertexWeightCount skinMod v
        local boneArray = #()
        local weightArray = #()
        local modified = false 
        local removedWeightCount = 0
        for w = 1 to vertexWeightCount do
        (
            local boneId = skinOps_getVertexWeightBoneId skinMod v w
            local boneWeight = skinOps_getVertexWeight skinMod v w
            if (boneWeight == 0) then
            (
                removedWeightCount = removedWeightCount + 1
                continue
            )
            
            --print ("ID: " + v as string + " B: " + getBoneNameByBoneId skinMod boneId)
            
            if boneId == boneAId then
            (         
                -- Replace bone id
                boneId = boneBId
                modified = true
                print "modified"
            )
            else if boneId == boneBId then
            (
                -- Remove weight
                --removedWeightCount = removedWeightCount + 1
                --boneId = boneAId
                --modified = true
                --continue
            )
    
            boneArray[w - removedWeightCount] = boneId
            weightArray[w - removedWeightCount] = boneWeight
        )
        
        if ( modified ) then
        (
            -- Update weights
            skinOps_ReplaceVertexWeights skinMod v boneArray weightArray
        )
    )
)

fn findNearestVertexId vertices targetVertexPos threshold =
(
    for v = 1 to vertices.count do
    (
        local vertexPos = vertices[v]
        local deltaPos = vertexPos - targetVertexPos
        
        if (( deltaPos.x <= threshold and deltaPos.x >= -threshold ) and
            ( deltaPos.y <= threshold and deltaPos.y >= -threshold ) and
            ( deltaPos.z <= threshold and deltaPos.z >= -threshold )) then
        (
            return v
        )
    )
    
    -1
)

fn findNearestVertexIds meshObj targetVertexPos threshold  =
(
    local vertexCount = meshop.getNumVerts meshObj
    local result = #()
    for v = 1 to vertexCount do
    (
        local vertexPos = meshop.getVert meshObj v
        local deltaPos = vertexPos - targetVertexPos
        
        if (( deltaPos.x <= threshold and deltaPos.x >= -threshold ) and
            ( deltaPos.y <= threshold and deltaPos.y >= -threshold ) and
            ( deltaPos.z <= threshold and deltaPos.z >= -threshold )) then
        (
            append result v
        )
    )
    
    result
)

struct modifiedSkinVertex
(
    index,
    boneArray,
    weightArray
)

fn getMeshVertices meshObj =
(
    for v = 1 to meshop.getNumVerts meshObj collect meshop.getVert meshObj v
)

fn getMirroredVertexIds vertices threshold maxThreshold =
(
    local mirroredVertexIdLookup = #()
    
    for i = 1 to vertices.count do
    (
        local vertexPos = vertices[i]
        local targetVertexPos = vertexPos * [-1, 1, 1]
        
        local curThreshold = threshold
        local mirroredVertexId = findNearestVertexId vertices targetVertexPos curThreshold
        while ((mirroredVertexId == -1 and curThreshold <= maxThreshold)) do
        (
            mirroredVertexId = findNearestVertexId vertices targetVertexPos curThreshold
            
            if ( mirroredVertexId == -1 ) then
            (
                curThreshold = curThreshold + 0.001
                --print ("getMirroredVertexIds: curThreshold: " + curThreshold as string)
            )
        )
        
        if curThreshold >= maxThreshold then
        (
            --print "getMirroredVertexIds: maxThreshold exceeded"
        )
                
        --if ( mirroredVertexId != -1 ) then
        --    print (vertexPos as string + " tgt: " + targetVertexPos as string + " act: " + (meshop.getVert meshObj mirroredVertexId) as string)
        mirroredVertexIdLookup[i] = mirroredVertexId
    )
    
    mirroredVertexIdLookup
)

fn mirrorWeights meshObj skinMod threshold maxThreshold patternA patternB ignoreCase =
(
    modPanel_setCurrentObject skinMod
    
    local vertices = getMeshVertices meshObj
    local mirroredVertexIdLookup = getMirroredVertexIds vertices threshold maxThreshold
    local processedVertexIds = #()
    
    max modify mode;
    local modifiedSkinVertices = #()
    for v = 1 to vertices.count do
    (
        local mirroredVertexId = mirroredVertexIdLookup[v]
        if (mirroredVertexId == v or mirroredVertexId == -1) then continue
        
        if mirrorVertexId == 582 then print (v + " => " + "582")
        
--         local mirrorVertexUsedBoneIds = #()
--         local mirrorVertexWeightCount = skinOps_getVertexWeightCount skinMod v
--         for w = 1 to mirrorVertexWeightCount do
--         (
--             local boneId = skinOps_getVertexWeightBoneId skinMod v w
--             append mirrorVertexUsedBoneIds boneId
--         )
        
        -- Iterate through all bone weights of the vertex
        local boneArray = #()
        local weightArray = #()

        local modified = false
        local vertexWeightCount = skinOps_getVertexWeightCount skinMod v
        for w = 1 to vertexWeightCount do
        (
            local boneId = skinOps_getVertexWeightBoneId skinMod v w
            local boneWeight = skinOps_getVertexWeight skinMod v w
            local boneName = getBoneNameByBoneId skinMod boneId
            
            if matchPattern boneName pattern:("*"+patternA+"*") ignoreCase:ignoreCase then
            (
                -- A mirrored equivalent of the bone may exist
                local mirrorBoneName = substituteString boneName patternA patternB
                local mirrorBoneId = getBoneId skinMod mirrorBoneName
                if (mirrorBoneId != -1) then
                (
                    boneId = mirrorBoneId
                    modified = true
                )
                else
                (
                    print mirrorBoneName
                )
            )
            
            --if findItem mirrorVertexUsedBoneIds boneId == 0 then
            (
                append boneArray boneId
                append weightArray boneWeight
            )
        )
        
        --if not modified then
        --    modified = findItem processedVertexIds v != 0

        
        if ( modified ) then
        (
            -- Update weights
            skinOps_ReplaceVertexWeights skinMod mirroredVertexId boneArray weightArray
            --append processedVertexIds
        )            
    )
)

-- Creates a bone mapping by finding bones that match pattern A, and then replacing the pattern by patternB
fn createBoneMapping skinMod patternA patternB ignoreCase =
(
    modPanel_setCurrentObject skinMod
    
    local boneMapping = #()
    local boneCount = skinOps_GetNumberBones skinMod
    for i = 1 to boneCount do
    (
        local boneId = skinOps_GetBoneIDByListID skinMod i
        local boneName = skinOps_GetBoneName skinMod boneId 0
        
        if matchPattern boneName pattern:("*"+patternA+"*") ignoreCase:ignoreCase then
        (
            local otherBoneName = substituteString boneName patternA patternB
            append boneMapping #(boneName, otherBoneName)
        )
    )
    
    boneMapping
)

-- Transfers the weights of bone A to bone B, removing the weights assigned to bone A in the process
fn transferBoneAWeightsToBoneB skinMod vertexCount boneAName boneBName =
(
    modPanel_setCurrentObject skinMod
    
    local boneAId = getBoneId skinMod boneAName
    local boneBId = getBoneId skinMod boneBName
    
    -- TODO error logging
    if ( boneAId == -1 or boneBId == -1 ) then return false

    for v = 1 to vertexCount do
    (
        local vertexWeightCount = skinOps_getVertexWeightCount skinMod v
        local modBoneIds = #()
        local modWeights = #()
        
        for w = 1 to vertexWeightCount do
        (
            local boneId = skinOps_getVertexWeightBoneId skinMod v w
            local boneWeight = skinOps_getVertexWeight skinMod v w
            
            if ( boneId == boneAId ) then
            (
                -- Assign weights of boneA to boneB instead
                boneId = boneBId
            )
            
            append modBoneIds boneId
            append modWeights boneWeight
        )
        
        -- Replace weights
        -- Set weights doesnt work here because it doesnt remove the original weight
        skinOps.ReplaceVertexWeights skinMod v modBoneIds modWeights
    )
)

-- Tranfers the weights of each mapped bone, removing the weights assigned to bone A in the process
fn transferBoneWeightsUsingMapping skinMod boneMapping =
(
    local vertexCount = skinOps.GetNumberVertices skinMod
    for i = 1 to boneMapping.count do
        transferBoneAWeightsToBoneB skinMod vertexCount boneMapping[i][1] boneMapping[i][2]
)

fn selectSkinWrapMod obj =
(
    local skinWrapMod = obj.modifiers[#Skin_Wrap]
    modPanel_setCurrentObject skinWrapMod
    skinWrapMod
)

fn copyBoneBWeightsToSkinModB skinModA skinModB boneMapping =
(
    modPanel_setCurrentObject skinModA
    local vertexCount = skinOps.GetNumberVertices skinModA
    for i = 1 to boneMapping.count do
    (
        local boneBName = boneMapping[i][2]
        local boneBId = getBoneId skinModA boneBName

        for v = 1 to vertexCount do
        (
            local vertexWeightCount = skinOps_getVertexWeightCount skinModA v
            local modBoneIds = #()
            local modWeights = #()
            local modified = false
            
            for w = 1 to vertexWeightCount do
            (
                local boneId = skinOps_getVertexWeightBoneId skinModA v w
                local boneWeight = skinOps_getVertexWeight skinModA v w
                
                if ( boneId == boneBId ) then
                (
                    -- Assign weights of boneA to boneB instead
                    append modBoneIds boneBId
                    append modWeights boneWeight
                    
                    --append modBoneIds boneAId
                    --append modWeights 0
                    
                    modified = true
                )
            )
            
            -- Patch onto existing weights
            if ( modified ) then
            (
                modPanel_setCurrentObject skinModB
                skinOps_ReplaceVertexWeights skinModB v modBoneIds modWeights
                modPanel_setCurrentObject skinModA
            )
        )
    )
)

struct skinData
(
    boneNames = #(),
    vertices = #()
)

struct skinVertex 
(
    index,
    indices = #(),
    weights = #()
)

fn extractSkinModData skinMod =
(
    -- Must be selected or else it wont work
    modPanel_setCurrentObject skinMod
    
    local result = skinData()
    local boneCount = skinOps_GetNumberBones skinMod
    for i = 1 to boneCount do
    (
        local boneId = skinOps_GetBoneIDByListID skinMod i
        local boneName = skinOps_GetBoneName skinMod boneId 0
        result.boneNames[boneId] = boneName
    )
    
    local vertexCount = skinOps.GetNumberVertices skinMod
    for v = 1 to vertexCount do
    (
        local vertex = skinVertex index:v
        local vertexWeightCount = skinOps_getVertexWeightCount skinMod v
        
        for w = 1 to vertexWeightCount do
        (
            local boneId = skinOps_getVertexWeightBoneId skinMod v w
            local boneWeight = skinOps_getVertexWeight skinMod v w
            
            append vertex.indices boneId
            append vertex.weights boneWeight
        )
        
        append result.vertices vertex
    )
    
    result
)

fn skinDataBoneNameToId skinData boneName =
(
    --print skinData
    --print boneName
    
    local id = -1
    for j = 1 to skinData.boneNames.count do
    (
        if ( stricmp skinData.boneNames[j] boneName == 0 ) then
        (
            id = j
            exit
        )
    )
    
    return id
)

fn convertSkinDataToSkinMod skinData obj = 
(
    max modify mode;
    local skinMod = skin();
    addModifier obj skinMod;
    skinOps.closeWeightTool skinMod
    
    -- Add used bones to the skin modifier
    for j = 1 to skinData.boneNames.count do
        skinOps_AddBone skinMod (getNodeByName skinData.boneNames[j]) 0;
    
    modPanel_setCurrentObject skinMod;
    for j = 1 to skinData.vertices.count do
       skinOps_ReplaceVertexWeights skinMod j skinData.vertices[j].indices skinData.vertices[j].weights
    
    skinMod
)

fn doMirrorWeights obj patternA patternB ignoreCase =
(
    local startTime = timestamp() --get start time in milliseconds
   
    print "Cloning object"
    local clonedObj = cloneObj obj
    
    print "Mirroring object"
    mirrorSkinnedObj clonedObj
    
    print "Creating bone map"
    local cloneSkinMod = selectSkinMod clonedObj
    local boneMapping = createBoneMapping cloneSkinMod patternA patternB ignoreCase
    
    print "-- Bone mapping --"
    print boneMapping
    
    -- Transfer bone A weights to bone B, while removing bone A weights
    print "Remapping weights"
    local cloneSkinData = extractSkinModData cloneSkinMod
    for i = 1 to boneMapping.count do
    (
        local boneAId = skinDataBoneNameToId cloneSkinData boneMapping[i][1] 
        local boneBId = skinDataBoneNameToId cloneSkinData boneMapping[i][2]
        
        -- TODO error logging
        if ( boneAId != -1 and boneBId != -1 ) then
        (
            for v = 1 to cloneSkinData.vertices.count do
            (
                for w = 1 to cloneSkinData.vertices[v].weights.count do
                (
                    if ( cloneSkinData.vertices[v].indices[w] == boneAId ) then
                    (
                        -- Assign weight assigned to bone A to bone B instead
                        cloneSkinData.vertices[v].indices[w] = boneBId
                    )
                    else if ( cloneSkinData.vertices[v].indices[w] == boneBId ) then
                    (
                        -- Remove existing weight to bone B
                        cloneSkinData.vertices[v].weights[w] = 0
                    )
                )
            )
        )
    )
    
    deleteModifier clonedObj cloneSkinMod
    print "Creating new skin modifier"
    convertSkinDataToSkinMod cloneSkinData clonedObj

    print "Skin wrapping to mirrored clone"
    -- Skin wrap to mirrored clone 
    local selObjSkinMod = selectSkinMod obj
    modPanel.addModToSelection (Skin_Wrap ()) ui:on
    local skinWrapMod = selectSkinWrapMod obj
    skinWrapMod.meshList = #(getNodeByName clonedObj.name) 
    skinWrapMod.engine = 1
    skinWrapMod.falloff = 1
    skinWrapMod.distance = 0.001
    skinWrapMod.faceLimit = 3
    skinWrapMod.threshold = 5
    skinWrapMod.weightAllVerts = on
        
    -- Convert to modifier to skin, delete it and the clone
    print "Converting skinwrap to skin"
    skinWrapMod.convertToSkin off
    deleteModifier obj skinWrapMod
    delete clonedObj
    
    print "Extracting skin data"
    -- Extract skin data from new & old skin modifier
    local selObjNewSkinMod = obj.modifiers[1]
    local newSkinData = extractSkinModData selObjNewSkinMod
    local skinData = extractSkinModData selObjSkinMod
    
    -- Merge skin data
    print "Merging skin data"
    for i = 1 to boneMapping.count do
    (
        local boneBName = boneMapping[i][2]
        local boneBId = skinDataBoneNameToId newSkinData boneBName
        
        for v = 1 to newSkinData.vertices.count do
        (
            local shouldReplaceWeights = false
            for w = 1 to newSkinData.vertices[v].weights.count do
            (
                if ( newSkinData.vertices[v].indices[w] == boneBId ) then
                (
                    -- Overwrite weight
                    shouldReplaceWeights = true
                    exit
                )
            )
            
            --shouldReplaceWeights = true
            if (shouldReplaceWeights) then
                skinData.vertices[v] = newSkinData.vertices[v]
        )
    )
    
    -- Delete skin modifiers
    deleteModifier obj selObjNewSkinMod
    local boneLimit = selObjSkinMod.bone_Limit
    deleteModifier obj selObjSkinMod
    
    -- Create new skin modifier
    print "Rebuilding skin modifier"
    local rebuiltSkinMod = convertSkinDataToSkinMod skinData obj
    rebuiltSkinMod.bone_Limit = boneLimit
    
    print ("Done! in "+((((timestamp())-startTime)*0.001)as string)+" sec")
)

rollout mainRollout "MirrorSkin by TGE" width:200 height:240
(
	button 'btnExec' "Execute" pos:[70,210] width:60 height:20 align:#left 
	editText 'edtSrcPattern' "" pos:[112,112] width:70 height:20 align:#left text:"_L"
	label 'lbl1' "Source pattern" pos:[16,112] width:80 height:20 align:#left
	editText 'edtDestPattern' "" pos:[112,144] width:70 height:20 align:#left text:"_R"
	label 'lbl2' "Dest. pattern" pos:[16,144] width:80 height:20 align:#left
	label 'lbl3' "Ignore case" pos:[16,176] width:80 height:20 align:#left
	checkbox 'cbIgnoreCase' "" pos:[116,176] width:72 height:16 checked:false align:#left
	label 'lbl4' "MirrorSkin 1.0 by TGE" pos:[17,16] width:176 height:16 align:#left
	label 'lbl5' "Mirrors the weights of bones matched by the source pattern to bones matched by the destination pattern." pos:[16,40] width:176 height:64 align:#left
	on btnExec pressed  do
    (
        local objs = for obj in selection collect obj
        for obj in objs do
            doMirrorWeights obj edtSrcPattern.text edtDestPattern.text cbIgnoreCase.checked
    )
)


fn exec =
(
    CreateDialog mainRollout
    --doMirrorWeights $ "_L_" "_R_" true
)

--turning off redraw makes Skin_Wrap.convertToSkin not work correctly
--with redraw off ( 
undo off (
exec()
)--)
