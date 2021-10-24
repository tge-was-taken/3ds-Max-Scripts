/*
    Yakuza series *.GMD model importer
    By TGE
    Version 1.0
*/

-- Globals
global gIoContext = undefined;

-- Functions

-- Cache commonly used interface functions
global _bit_SwapBytes = bit.SwapBytes;
global _bit_And = bit.And;
global _bit_IntAsFloat = bit.IntAsFloat;
global _bit_Get = bit.Get;
global _bit_IntAsChar = bit.intAsChar;
global _bonesys_createbone = bonesys.createbone;
global _skinOps_AddBone = skinOps.AddBone;
global _modPanel_SetCurrentObject = modPanel.SetCurrentObject;
global _skinOps_ReplaceVertexWeights = skinOps.ReplaceVertexWeights;
global _skinOps_SetVertexWeights = skinOps.SetVertexWeights;

-- Utility
fn utilSwap16 value =
(
    _bit_SwapBytes value 1 2
)

fn utilSwap32 value =
(
    _bit_SwapBytes ( _bit_SwapBytes value 1 4 ) 2 3
)

fn utilSwapFloat value =
(
    _bit_IntAsFloat ( _bit_SwapBytes ( _bit_SwapBytes value 1 4 ) 2 3 )
)

fn utilAllBitsSet value mask =
(
    ( _bit_And value mask ) == mask;
)

fn utilInitArray count  =
(
    local array = #();
    array[count] = undefined;
    array;
)

fn utilSetUIRedraw arg =
(
	if arg == 1 then 
    (
        cui.CommandPanelOpen = true; 
        enableSceneRedraw(); 
    )
    else 
    (
        disableSceneRedraw();
    )	
    
	local WM_SETREDRAW=0xB;
	local commandHWND = (windows.getChildHWND #max "Command Panel");
	windows.sendmessage (commandHWND[1]) WM_SETREDRAW arg 0;
)

-- File IO
ioEndian_Little = 0
ioEndian_Big = 1

struct ioContext
(
    Stream,
    FileName,
    FilePath,
    Endianness,
    Swap,
    BasePosition,
    SavedPosition
)

fn ioOpenFile filePath =
(
    gIoContext = ioContext();
    gIoContext.Stream = fopen filePath #rb;
    gIoContext.FileName = GetFilenameFile filePath;
    gIoContext.FilePath = GetFilenamePath filePath;
    gIoContext.Endianness = ioEndian_Little;
    gIoContext.Swap = false;
    gIoContext.BasePosition = 0;
    gIoContext.SavedPosition = 0;
)

fn ioSelectOpenFileWithHandler category ext handler =
(
    local filePath = getOpenFileName \ 
        caption:("Open " + category + " file")\
        types:( category + " (*." + ext + ")|*." + ext ) \
        historyCategory:( category + " Object Presets" )
    
    if ( filePath != undefined ) then
        handler( filePath );
)

fn ioGetFileName =
(
    gIoContext.FileName;
)

fn ioGetFilePath =
(
    gIoContext.FilePath;
)

fn ioSetEndianness endian =
(
    gIoContext.Endianness = endian;
    gIoContext.Swap = gIoContext.Endianness == ioEndian_Big;
)

fn ioTell =
(
    FTell gIoContext.Stream;
)

fn ioPushBase =
(
    gIoContext.BasePosition = ioTell();
)

fn ioPush pos =
(
    gIoContext.SavedPosition = ioTell();
    ioSeekSet( pos );
)

fn ioPop =
(
    ioSeekSet( gIoContext.SavedPosition );
)

fn ioSeekCur position =
(
    FSeek gIoContext.Stream position #seek_cur;
)

fn ioSeekSetAbs position =
(
    FSeek gIoContext.Stream position #seek_set;
)

fn ioSeekSet position =
(
    FSeek gIoContext.Stream ( gIoContext.BasePosition + position ) #seek_set;
)

fn ioReadU8 =
(
    ReadByte gIoContext.Stream #unsigned;
)

fn ioReadU8Array count =
(
    local array = #();
    array[count] = undefined;
    for i = 1 to count do array[i] = (ioReadU8());
    array;
)

fn ioReadS16 =
(
    local value = ReadShort gIoContext.Stream #signed;
    if ( gIoContext.Swap ) then value = utilSwap16( value );
    value;
)

fn ioReadS16Array count =
(
    local array = #();
    array[count] = undefined;
    for i = 1 to count do array[i] = (ioReadS16());
    array;
)

fn ioReadU16 =
(
    local value = ReadShort gIoContext.Stream #unsigned;
    if ( gIoContext.Swap ) then value = utilSwap16( value );
    value;
)

fn ioReadU16Array count =
(
    local array = #();
    array[count] = undefined;
    for i = 1 to count do array[i] = (ioReadU16());
    array;
)

fn ioReadS32 =
(
    local value = ReadLong gIoContext.Stream #signed;
    if ( gIoContext.Swap ) then value = utilSwap32( value );
    value;
)

fn ioReadU32 =
(
    local value = ReadLong gIoContext.Stream #unsigned;
    if ( gIoContext.Swap ) then value = utilSwap32( value );
    value;
)

fn ioReadF16 =
(
    local N = ioReadU16();
    local S = Floor((Mod N 65536) / 32768);
    local Ef = Floor((Mod N 32768) / 1024);
    local M = Mod N 1024;
    local result = 0;
    
    if (Ef == 0) AND (M == 0) 
        then result = ( (-1.0)^S * 0.0 );
    
    else if (Ef == 0) AND (M != 0) 
        then result = ( (-1.0)^S * 2.0^-14 * (M / 2.0^10) );
    
    else if (Ef > 0) AND (Ef < 31) 
        then result = ( (-1.0)^S * 2.0^(Ef-15) * (1 + M/2.0^10) );
    
    else if (Ef == 31) AND (M == 0) 
        then result = ( (-1.0)^S * 1/0.0 );
    
    result;
)

fn ioReadF32 =
(
    local value;
    if ( gIoContext.Swap ) then value = _bit_IntAsFloat( ioReadU32() );
    else value = ReadFloat gIoContext.Stream;
    value;
)

fn ioReadVector2 =
(
    [ ioReadF32(), ioReadF32() ];
)

fn ioReadTexCoord =
(
    [ ioReadF32(), 1f - ioReadF32(), 0 ];
)

fn ioReadTexCoordF16 =
(
    [ ioReadF16(), 1f - ioReadF16(), 0 ];
)

fn ioReadVector3 =
(
    [ ioReadF32(), ioReadF32(), ioReadF32() ];
)

fn ioReadVector4 =
(
    [ ioReadF32(), ioReadF32(), ioReadF32(), ioReadF32() ];
)

fn ioReadQuaternion =
(
    quat (ioReadF32()) (ioReadF32()) (ioReadF32()) (ioReadF32());
)

fn ioReadMatrix4x3 =
(
    matrix3 (ioReadF32()) (ioReadF32()) (ioReadF32()) (ioReadF32()) \
            (ioReadF32()) (ioReadF32()) (ioReadF32()) (ioReadF32()) \
            (ioReadF32()) (ioReadF32()) (ioReadF32()) (ioReadF32());
)

fn ioReadMatrix4x4 =
(
    matrix3 (ioReadF32()) (ioReadF32()) (ioReadF32()) (ioReadF32()) \
            (ioReadF32()) (ioReadF32()) (ioReadF32()) (ioReadF32()) \
            (ioReadF32()) (ioReadF32()) (ioReadF32()) (ioReadF32()) \
            (ioReadF32()) (ioReadF32()) (ioReadF32()) (ioReadF32());
)

fn ioReadFixedString len =
(
    local str = "";
    
    for i = 1 to len do
    (
        local b = ioReadU8();
        if ( b != 0 ) then
            str += _bit_IntAsChar b;
    )
    
    str;
)

fn gmdStringRead =
(
    ioSeekCur( 2 );
    ioReadFixedString( 30 );
)

fn gmdStringListRead offset count =
(
    ioSeekSet( offset );
    local array = #();
    array[count] = undefined;
    for i = 1 to count do array[i] = (gmdStringRead());
    array;
)

struct gmdNode
(
    Name,
    ParentIndex = -1,
    LocalTransform,
    MaxBone
)

fn gmdNodeListParse offset count nameList =
(
    ioSeekSet( offset );
    
    local nodes = #();
    nodes[count] = undefined;
    for i = 1 to count do
        nodes[i] = (gmdNode())
    
    for i = 1 to count do
    (
        local node = nodes[i];
        ioSeekCur( 4 );
        local childIndex = ioReadU32();
        local siblingIndex = ioReadU32();
        ioSeekCur( 8 );
        local field14 = ioReadU32();
        local nameIndex = ioReadS32();
        ioSeekCur( 4 );
        local position = ioReadVector3();
        ioSeekCur( 4 );
        local rotation = ioReadQuaternion();
        local scale = ioReadVector3();
        ioSeekCur( 52 );   

--         if ( ( field14 == 1 or field14 == 3 ) and siblingIndex >= 0 ) then
--             nodes[siblingIndex + 1].ParentIndex = node.ParentIndex;
--         
--         if ( field14 == 1 or field14 == 0 ) then
--             nodes[childIndex + 1].ParentIndex = i;   

        if ( siblingIndex != -1 ) then
            nodes[siblingIndex + 1].ParentIndex = node.ParentIndex;
        
        if ( childIndex != -1 ) then
            nodes[childIndex + 1].ParentIndex = i;            
        
        local name;
        if ( nameIndex != -1 ) then
            name = nameList[ nameIndex + 1 ];
        else
            name = "node_" + i;
        
        node.Name = name;
        
        local tfm = (Inverse rotation) as matrix3;
        tfm *= ScaleMatrix scale;
        tfm.row4 = position;
        node.LocalTransform = tfm;
    )
    
    for node in nodes do
    (
        local parentBone = undefined;
        if ( node.ParentIndex != -1 ) do
            parentBone = nodes[node.ParentIndex].MaxBone;
        
        local tfm = node.LocalTransform;
        if ( parentBone != undefined ) do
            tfm *= parentBone.Transform;
        
        local newBone = _bonesys_createbone \
                  tfm.row4	\
                  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
                  (normalize tfm.row3);
                          
        newBone.name = node.Name;
        newBone.width  = 0.001;
        newBone.height = 0.001;
        newBone.transform = tfm;
        newBone.setBoneEnable false 0;
        newBone.wirecolor = yellow;
        newBone.showlinks = true;
        newBone.pos.controller      = TCB_position ();
        newBone.rotation.controller = TCB_rotation ();
        newBone.Parent = parentBone;
        
        node.MaxBone = newBone; 
    )
    
    nodes;
)

struct gmdMeshLod
(
    IndexCount,
    IndexStartIndex
)

struct gmdMesh
(
    MaterialIndex,
    VertexBufferIndex,
    VertexCount,
    Lods = utilInitArray( 3 ),
    UsedBoneCount,
    BoneMapStartOffset,
    NodeIndex,
    GeometryIndex,
    VertexStartIndex
)

fn gmdMeshListRead offset count =
(
    ioSeekSet( offset );
    local list = #();
    list[count] = undefined;
    
    for i = 1 to count do
    (
        local m = gmdMesh();
        
        ioSeekCur( 4 );
        m.MaterialIndex = ioReadU32();
        m.VertexBufferIndex = ioReadU32();
        m.VertexCount = ioReadU32();
        
        for j = 1 to 3 do
        (
            local mLod = gmdMeshLod();
            mLod.IndexCount = ioReadU32();
            mLod.IndexStartIndex = ioReadU32();
            m.Lods[j] = mLod;
        )
        
        m.UsedBoneCount = ioReadU32();
        m.BoneMapStartOffset = ioReadU32();
        m.NodeIndex = ioReadU32();
        m.GeometryIndex = ioReadU32();
        ioSeekCur( 4 );
        m.VertexStartIndex = ioReadU32();
        
        list[i] = m;
    )
    
    list;
)

struct gmdVertexBuffer
(
    Format,
    Offset,
    Stride
)

fn gmdVertexBufferListRead offset count =
(
    ioSeekSet( offset );
    local list = #();
    list[count] = undefined;
    
    for i = 1 to count do
    (
        local vertexBuffer = gmdVertexBuffer();
        ioSeekCur( 12 );
        vertexBuffer.Format = ioReadU32();
        vertexBuffer.Offset = ioReadU32();
        ioSeekCur( 4 );
        vertexBuffer.Stride = ioReadU32();
        ioSeekCur( 4 );
        list[i] = vertexBuffer;
    )
    
    list;
)

fn gmdTriangleListParse offset indexCount baseIndex =
(
    ioSeekSet( offset );
    
    baseIndex -= 1;
    
    local triangleCount = indexCount / 3;
    local triangles = utilInitArray( triangleCount );
    for i = 1 to triangleCount do
        triangles[i] = [ioReadU16() - baseIndex, ioReadU16() - baseIndex, ioReadU16() - baseIndex]
    
    triangles;
)

fn gmdTriangleStripParse offset indexCount baseIndex = 
(
    ioSeekSet( offset );
    
    local triangles = #();
    
    local startDirection = -1;
    local f1 = ioReadU16();
    local f2 = ioReadU16();
    indexCount -= 2;
    local direction = startDirection;
    
    baseIndex -= 1;
    
    do 
    (
        local f3 = ioReadU16();
        indexCount -= 1;
        
        if ( f3 == 0xFFFF ) then 
        (
            f1 = ioReadU16();
            f2 = ioReadU16();
            indexCount -= 2;
            direction = startDirection;
        )
        else 
        (
            direction *= -1
            
            if ( f1 != f2 ) and ( f2 != f3 ) and ( f3 != f1 ) then 
            (
                if direction == 1 then append triangles [f1 - baseIndex, f2 - baseIndex, f3 - baseIndex]
                else append triangles [f1 - baseIndex, f3 - baseIndex, f2 - baseIndex]
            )
            
            f1 = f2
            f2 = f3
        )
    ) while ( indexCount > 0 )

    triangles;
)

fn gmdNormalVectorRead =
(
    [ ( ( ioReadU8() as float ) - 128f ) / 128f, ( ( ioReadU8() as float ) - 128f ) / 128f,
      ( ( ioReadU8() as float ) - 128f ) / 128f, ( ( ioReadU8() as float ) - 128f ) / 128f ];
)

struct gmdMaterial
(
    ShaderName,
    DiffuseName,
    ReflectionName,
    MtMapName,
    SpecularMapName,
    RsMapName,
    TnMapName,
    RtMapName,
    TsMapName
)

fn gmdMaterialListRead offset count materialNames shaderNames =
(
    ioSeekSet( offset );
    local list = #();
    list[count] = undefined;
    
    for i = 1 to count do
    (
        local mat = gmdMaterial();
        
        ioSeekCur( 0x0A );
        local shaderNameIndex = ioReadS16();
        if ( shaderNameIndex != -1 ) then mat.ShaderName = shaderNames[ shaderNameIndex + 1 ];
        
        ioSeekCur( 0x16 );
        local diffuseNameIndex = ioReadS16();
        if ( diffuseNameIndex != -1 ) then mat.DiffuseName = materialNames[ diffuseNameIndex + 1 ];
        
        ioSeekCur( 2 );
        local reflectionNameIndex = ioReadS16();
        if ( reflectionNameIndex != -1 ) then mat.ReflectionName = materialNames[ reflectionNameIndex + 1 ];
        
        ioSeekCur( 2 );
        local mtNameIndex = ioReadS16();
        if ( mtNameIndex != -1 ) then mat.MtMapName = materialNames[ mtNameIndex + 1 ];
        
        ioSeekCur( 2 );
        local specularNameIndex = ioReadS16();
        if ( specularNameIndex != -1 ) then mat.SpecularMapName = materialNames[ specularNameIndex + 1 ];
        
        ioSeekCur( 2 );
        local rsNameIndex = ioReadS16();
        if ( rsNameIndex != -1 ) then mat.RsMapName = materialNames[ rsNameIndex + 1 ];
        
        ioSeekCur( 2 );
        local tnNameIndex = ioReadS16();
        if ( tnNameIndex != -1 ) then mat.TnMapName = materialNames[ tnNameIndex + 1 ];
        
        ioSeekCur( 2 );
        local rtNameIndex = ioReadS16();
        if ( rtNameIndex != -1 ) then mat.RtMapName = materialNames[ rtNameIndex + 1 ];
        
        ioSeekCur( 2 );
        local tsNameIndex = ioReadS16();
        if ( tsNameIndex != -1 ) then mat.TsMapName = materialNames[ tsNameIndex + 1 ];
        
        ioSeekCur( 0x40 );
        list[i] = mat;
    )
    
    print list;
    list;
)

struct gmdModelImportConfig
(
    ApplyWeights
)

fn gmdModelParse config =
(
    local version = ioReadU8();
    local endianness = ioReadU8();
    ioSetEndianness( endianness );
    ioSeekSet( 0x30 );
    local nodeListOffset = ioReadU32();
    local nodeCount = ioReadU32();
    local geometryListOffset = ioReadU32();
    local geometryCount = ioReadU32();
    local meshListOffset = ioReadU32();
    local meshCount = ioReadU32();
    local materialListOffset = ioReadU32();
    local materialCount = ioReadU32();
    ioSeekSet( 0x60 );
    local vertexBufferListOffset = ioReadU32();
    local vertexBufferCount = ioReadU32();
    local vertexBufferPoolOffset = ioReadU32();
    ioSeekSet( 0x70 );
    local materialNameListOffset = ioReadU32();
    local materialNameCount = ioReadU32();
    local shaderNameListOffset = ioReadU32();
    local shaderNameCount = ioReadU32();
    local nodeNameListOffset = ioReadU32();
    local nodeNameCount = ioReadU32();
    local indexBufferOffset = ioReadU32();
    ioSeekSet( 0x98 );
    local boneMapBufferOffset = ioReadU32();
    ioSeekSet( 0xFC );
    local flags = ioReadU32();
    
    -- Parse nodes
    local nodeNames = gmdStringListRead nodeNameListOffset nodeNameCount;
    local nodes = gmdNodeListParse nodeListOffset nodeCount nodeNames;
    
    -- Readvertex buffers
    local vertexBuffers = gmdVertexBufferListRead vertexBufferListOffset vertexBufferCount;
    
    -- Read materials
    local materialNames = gmdStringListRead materialNameListOffset materialNameCount;
    local shaderNames = gmdStringListRead shaderNameListOffset shaderNameCount;
    local materials = gmdMaterialListRead materialListOffset materialCount materialNames shaderNames;
    
    -- Parse meshes
    local meshes = gmdMeshListRead meshListOffset meshCount;
    
    for m in meshes do
    (
        --local m = meshes[meshIndex];
        local vertexBuffer = vertexBuffers[ m.VertexBufferIndex + 1 ];
        local usedBoneCount = m.UsedBoneCount;
        local usedBoneNodeIndices = undefined;
        if ( usedBoneCount > 0 ) then
        (
            ioSeekSet( boneMapBufferOffset + m.BoneMapStartOffset );

            if ( _bit_Get flags 8 ) then 
            (
                ioSeekCur( 2 );
                usedBoneNodeIndices = ioReadU16Array( usedBoneCount );
            )
            else
            (
                ioSeekCur( 1 );
                usedBoneNodeIndices = ioReadU8Array( usedBoneCount);
            )
        )
        
        -- Read vertices
        local vertexCount = m.VertexCount;
        local positions = utilInitArray( vertexCount );
        local boneWeights = utilInitArray( vertexCount );
        local boneIndices = utilInitArray( vertexCount );
        local normals = utilInitArray( vertexCount );
        local texCoords = utilInitArray( vertexCount );
        local texCoords2 = utilInitArray( vertexCount );
        
        --ioSeekSet( vertexBufferPoolOffset + vertexBuffer.Offset + ( vertexBuffer.Stride * m.VertexStartIndex ) );
        local vertexOffset = vertexBufferPoolOffset + vertexBuffer.Offset + ( vertexBuffer.Stride * m.VertexStartIndex );
        
        -- extract format flags
        local hasWeights = utilAllBitsSet vertexBuffer.Format 0x3C0;
        local hasTangents = utilAllBitsSet vertexBuffer.Format 0x7000;
        local hasBinormals = utilAllBitsSet vertexBuffer.Format 0xE00000;
        local hasBitangents = utilAllBitsSet vertexBuffer.Format 0x7000000;
        local hasTexCoord1 = _bit_Get vertexBuffer.Format 29;
        local hasTexCoord2 = _bit_Get vertexBuffer.Format 30;
        
        for i = 1 to vertexCount do
        (
            ioSeekSet( vertexOffset );
            
            positions[i] = (ioReadVector3());

            if ( hasWeights ) then
            (
                local vertexBoneWeights = #();
                local vertexBoneIndices = #();
                local w1 = ioReadU8();
                local w2 = ioReadU8();
                local w3 = ioReadU8();
                local w4 = ioReadU8();
                local b1 = ioReadU8();
                local b2 = ioReadU8();
                local b3 = ioReadU8();
                local b4 = ioReadU8();
                
                if ( w1 != 0 ) then
                (
                    append vertexBoneWeights ( ( w1 as float ) / 255f );
                    append vertexBoneIndices ( b1 + 1 );
                )
                
                if ( w2 != 0 ) then
                (
                    append vertexBoneWeights ( ( w2 as float ) / 255f );
                    append vertexBoneIndices ( b2 + 1 );
                )

                if ( w3 != 0 ) then
                (
                    append vertexBoneWeights ( ( w3 as float ) / 255f );
                    append vertexBoneIndices ( b3 + 1 );
                )
                
                if ( w4 != 0 ) then
                (
                    append vertexBoneWeights ( ( w4 as float ) / 255f );
                    append vertexBoneIndices ( b4 + 1 );
                )
                
                boneWeights[i] = vertexBoneWeights;
                boneIndices[i] = vertexBoneIndices;
            )
            
            normals[i] = (gmdNormalVectorRead());
                
            if ( hasTangents ) then 
                ioSeekCur( 4 );
                
            if ( hasBinormals ) then 
                ioSeekCur( 4 );
                
            if ( hasBitangents ) then 
                ioSeekCur( 4 );
                
            if ( hasTexCoord1 ) then
                texCoords[i] = (ioReadTexCoordF16());
                    
            if ( hasTexCoord2 ) then
                texCoords2[i] = (ioReadTexCoordF16());
                
            vertexOffset += vertexBuffer.Stride;
        )
        
        -- Read indices
        --for i = 1 to m.Lods.Count do
        for i = 1 to 1 do
        (
            local mLod = m.Lods[i];
            local indicesStartOffset = indexBufferOffset + ( mLod.IndexStartIndex * 2 );
            
            local triangles;
            if ( i == 1 ) then 
                triangles = gmdTriangleListParse indicesStartOffset mLod.IndexCount m.VertexStartIndex;
            else               
                triangles = gmdTriangleStripParse indicesStartOffset mLod.IndexCount m.VertexStartIndex;
            
            local maxMesh = mesh vertices:positions normals:normals faces:triangles;
            maxMesh.Name = nodes[ m.NodeIndex ].Name;
            
            -- Set up texture coordinates
            maxMesh.NumTVerts = vertexCount;
            buildTVFaces maxMesh;
            for j = 1 to triangles.Count do setTVFace maxMesh j triangles[j];
            for j = 1 to texCoords.Count do setTVert maxMesh j texCoords[j];
                
            -- Set up weights
            if ( config.ApplyWeights and usedBoneCount > 0 ) then 
            (                
                resumeEditing();
                max modify mode;
                
                select maxMesh;
                skinMod = skin();
                addModifier maxMesh skinMod;
                
                -- Add used bones to the skin modifier
                for j in usedBoneNodeIndices do
                (
                    local maxBone = nodes[j + 1].MaxBone;
                    _skinOps_AddBone skinMod maxBone 0;
                )
                
                _modPanel_SetCurrentObject skinMod;
                for j = 1 to vertexCount do
                   _skinOps_ReplaceVertexWeights skinMod j boneIndices[j] boneWeights[j];
            )
            
            -- Set up material
            local mat = materials[ m.MaterialIndex + 1 ];
            maxMesh.Material = standard();
            maxMesh.Material.Name = "material_" + m.MaterialIndex as string;
            
            if ( mat.DiffuseName != undefined ) then
                maxMesh.Material.DiffuseMap = Bitmaptexture filename:( ioGetFilePath() + mat.DiffuseName + ".dds" );
            
            --if ( mat.ReflectionName != undefined ) then
            --    maxMesh.Material.RelectionMap = Bitmaptexture filename:( ioGetFilePath() + mat.ReflectionName + ".dds" );
            
            if ( mat.TnMapName != undefined ) then
            (
                maxMesh.Material.BumpMap = Normal_Bump();
                maxMesh.Material.BumpMap.Normal_Map = Bitmaptexture filename:( ioGetFilePath() + mat.TnMapName + ".dds" );
            )
            
            if ( mat.ShaderName != undefined ) then
                maxMesh.Material.Name += "@" + mat.ShaderName;
            
            maxMesh.Material.ShowinViewport = true; 
            maxMesh.BackFaceCull = on;
        )
    )
)

fn gmdModelImport filePath config =
(
    ioOpenFile( filePath );
    local magic = ioReadFixedString( 4 );
    if ( magic != "GSGM" ) do
        throw "Not a valid Yakuza GMD model file.";
    
    gmdModelParse( config );
)

fn main =
(
    gc();
    gc();
    
    local config = gmdModelImportConfig ApplyWeights:true;
    
    clearListener();
    local startTime = timestamp();
    
    --ioSelectOpenFileWithHandler "Yakuza GMD model" "gmd" gmdModelImport
    with redraw off
    undo off
    (
        suspendEditing();
        max create mode;
        
        --try (
            gmdModelImport @"D:\Games\PC\SteamLibrary\steamapps\common\Yakuza 0\media\data\chara\w64\adv\c_cm_kiryu_d_no_daimon\mesh\c_cm_kiryu_d_no_daimon_ps4.gmd" config;
            --gmdModelImport @"D:\Games\PC\SteamLibrary\steamapps\common\Yakuza 0\media\data\chara\w64\adv\c_ck_dummy\mesh_unpack\c_ck_dummy.gmd" config;
        --) catch ( print (getCurrentException()) )
        
        resumeEditing();
    )
    
    local endTime = timestamp();
    print ( "Done! (" + ( ( endTime - startTime ) as string ) + " ms)" );
    
    gc();
    gc();
    
    OK;
)

main();