
global gIOContext;
global gIOActiveContexts;
global gIONextFileId;

struct ioContext
(
    mId,
    mStream = undefined
)

function ioInit =
(
    gIOContext = undefined;
    gIOActiveContexts = #();
    gIONextFileId = 0;
)

function ioShutdown =
(
    gIOContext = undefined;
    
    for ctx in gIOActiveContexts do
    (
        if ( ctx != undefined ) then
        (
            fclose ctx.mStream;
        )
    )
    
    gIONextFileId = 0;
    OK;
)

function ioOpenFile path mode =
(
    local ctx = ioContext();
    ctx.mId = gIONextFileId;
    ctx.mStream = fopen path mode;
    gIOContext = ctx;    
    gIONextFileId += 1;
    return gIOContext.mId;
)

function ioSetFile id =
(
    gIOContext = gIOActiveContexts[ id ];
)

function ioTell =
(
    ftell gIOContext.mStream;
)

function ioClose =
(
    fclose gIOContext.mStream;
    gIOContext = undefined;
)

function ioSeekBegin offset =
(
    FSeek gIoContext.mStream offset #seek_set; 
)

function ioSeekCurrent offset =
(
    FSeek gIoContext.mStream offset #seek_cur; 
)

function ioReadByte =
(
    ReadByte gIOContext.mStream #unsigned;
)

function ioReadInt16 =
(
    ReadShort gIOContext.mStream;
)

function ioReadUInt16 =
(
    ReadShort gIOContext.mStream #unsigned;
)

function ioReadInt32 =
(
    ReadLong gIOContext.mStream;
)

function ioReadUInt32 =
(
    ReadLong gIOContext.mStream #unsigned;
)

function ioReadFloat =
(
    ReadFloat gIOContext.mStream;
)

function ioReadHalfFloat = 
(
    local hf= ioReadUInt16();
    local sign = bit.get hf 16;
    local exponent = (bit.shift (bit.and hf 0x7C00) -10) as integer - 16;
    local fraction = bit.and hf 0x03FF;
    if sign then sign = 1 else sign = 0;
    local exponentF = exponent + 127;
    local outputAsFloat =  bit.or (bit.or (bit.shift fraction 13) \
                          (bit.shift exponentF 23)) (bit.shift sign 31);
    bit.intasfloat outputasfloat * 2;
)

function ioReadVector3 =
(
    [ ioReadFloat(), ioReadFloat(), ioReadFloat() ]
)

function ioReadVector2Half = 
(
    [ ioReadHalfFloat(), ioReadHalfFloat() ];
)

function ioReadTexCoordsHalf = 
(
    [ ioReadHalfFloat(), ( ioReadHalfFloat() * -1 ) + 1, 0 ];
)

function ioReadCString =
(
    ReadString gIOContext.mStream;
)

function ioReadCStringOffset =
(
    local stream = gIOContext.mStream;
    local offset = ReadLong stream;
    local str;
    
    if ( offset != 0 ) then
    (
        local pos = FTell stream;
        FSeek stream offset #seek_set;
        str = ReadString stream;
        FSeek stream pos #seek_set;
    )
    
    str;
)

WMB4_PRIMITIVE_TYPE_TRIANGLE_LIST = 0;
WMB4_PRIMITIVE_TYPE_TRIANGLE_STRIP = 1;

struct wmb4BufferGroup
(
    VertexBufferOffsets = #(),
    VertexCount,
    IndexBufferOffset,
    IndexCount
)

struct wmb4VertexInfo
(
    Stride,
    HasWeights,
    HasColors,
    HasTexCoord2
)

struct wmb4SubMesh
(
    BufferGroupIndex,
    VertexBufferStartIndex,
    IndexBufferStartIndex,
    VertexCount,
    IndexCount,
    
    BufferGroup
)

struct wmb4Mesh
(
    SubMeshIndex,
    GroupIndex,
    MaterialIndex,
    BonePaletteIndex,
    
    SubMesh,
    MeshGroup,
    Mat,
    BonePalette
)

struct wmb4Material
(
    DiffuseMapIndex,
    NormalMapIndex,
    
    DiffuseMapUID,
    NormalMapUID
)

struct wmb4MeshGroup
(
    Name,
    MeshIds
)

function wmb4ReadMeshGroups count =
(
    local meshGroups = #();
    
    for k = 1 to count do
    (
        local meshGroup = wmb4MeshGroup();
        meshGroup.Name = ioReadCStringOffset();
        ioSeekCurrent( 24 ); -- extents
        
        meshGroup.MeshIds = #();
        for i = 1 to 5 do
        (
            meshGroup.MeshIds[i] = #();
            
            local offset = ioReadInt32();
            local indexCount = ioReadInt32();
            
            if ( indexCount > 0 ) then
            (
                local nextPos = ioTell();
                
                ioSeekBegin( offset );
                for j = 1 to indexCount do meshGroup.MeshIds[i][j] = ioReadInt16() + 1;
                
                ioSeekBegin( nextPos );
            )
        )
        
        meshGroups[k] = meshGroup;
    )
    
    meshGroups;
)

function wmb4ParseNodes nodeCount =
(
    local maxBones = #();
    for i = 1 to nodeCount do
    (
        local uid = ioReadInt16();
        local flag = ioReadInt16();
        local parentIndex = ioReadInt16();
        ioSeekCurrent( 14 );
        local worldPosition = ioReadVector3();
        
        local parentBone = undefined;
        if parentIndex != -1 do
            parentBone = maxBones[parentIndex + 1];
        
        local tfm = transmatrix worldPosition;
        newBone = bonesys.createbone \
                  tfm.row4	\
                  (tfm.row4 + 0.01 * (normalize tfm.row1)) \
                  (normalize tfm.row3);
                          
        newBone.name = uid as string;
        newBone.width  = 0.01;
        newBone.height = 0.01;
        newBone.transform = tfm;
        newBone.setBoneEnable false 0;
        newBone.wirecolor = yellow;
        newBone.showlinks = true;
        newBone.pos.controller      = TCB_position ();
        newBone.rotation.controller = TCB_rotation ();
        newBone.Parent = parentBone;
        
        maxBones[i] = newBone;
    )
    
    maxBones;
)

function wmb4BufferGroupRead = 
(
    local bufferGroup = wmb4BufferGroup();
    
    bufferGroup.VertexBufferOffsets = #();
    for i = 1 to 4 do bufferGroup.VertexBufferOffsets[i] = ioReadInt32();
    bufferGroup.VertexCount = ioReadInt32();
    
    bufferGroup.IndexBufferOffset = ioReadInt32();
    bufferGroup.IndexCount = ioReadInt32();
    
    bufferGroup;
)

function wmb4SubMeshRead =
(
    local subMesh = wmb4SubMesh();
    subMesh.BufferGroupIndex = ioReadInt32() + 1;
    subMesh.VertexBufferStartIndex = ioReadInt32() + 1;
    subMesh.IndexBufferStartIndex = ioReadInt32() + 1;
    subMesh.VertexCount = ioReadInt32();
    subMesh.IndexCount = ioReadInt32();
    subMesh;
)

function wmb4MeshRead =
(
    local msh = wmb4Mesh();
    msh.SubMeshIndex = ioReadInt32() + 1;
    msh.GroupIndex = ioReadInt32() + 1;
    msh.MaterialIndex = ioReadInt16() + 1;
    msh.BonePaletteIndex = ioReadInt16() + 1;
    ioSeekCurrent( 4 );
    msh;
)

function wmb4MeshParse msh vertexInfo primitiveType maxBones =
(
    local subMesh = msh.SubMesh;
    local bufferGroup = subMesh.BufferGroup;
    local vertexCount = subMesh.VertexCount;
    
    local positions = #();
    positions[ vertexCount ] = undefined;
    
    local texCoords = #();
    texCoords[ vertexCount ] = undefined;
    
    local boneIndices;
    local boneWeights;
    
    if ( vertexInfo.HasWeights ) then
    (
        boneIndices = #();
        boneIndices[ vertexCount ] = undefined;
        boneWeights = #();
        boneWeights[ vertexCount ] = undefined;
    )
    
    local vertexBufferOffset = bufferGroup.VertexBufferOffsets[ 1 ];
    local effectiveVertexBufferOffset = vertexBufferOffset + ( vertexInfo.Stride * ( subMesh.VertexBufferStartIndex - 1 ) );
    
    ioSeekBegin( effectiveVertexBufferOffset );
    for j = 1 to vertexCount do
    (
        positions[ j ] = ioReadVector3();
        texCoords[ j ] = ioReadTexCoordsHalf();
        ioSeekCurrent( 8 );
        
        if ( vertexInfo.HasWeights ) then
        (
            local vertexBoneIndices = #();
            for k = 1 to 4 do vertexBoneIndices[k] = ioReadByte() + 1;
            
            local vertexBoneWeights = #();
            for k = 1 to 4 do vertexBoneWeights[k] = ( ioReadByte() as float ) / 255.0f
            
            local vertexBoneIndicesClean = #();
            local vertexBoneWeightsClean = #();
            
            -- Remove unused bones
            for k = 1 to 4 do
            (
                if ( vertexBoneWeights[k] != 0 ) then
                (
                    append vertexBoneIndicesClean vertexBoneIndices[k];
                    append vertexBoneWeightsClean vertexBoneWeights[k];
                )
            )
            
            boneIndices[ j ] = vertexBoneIndicesClean;
            boneWeights[ j ] = vertexBoneWeightsClean;
        )
        else
        (
            if ( vertexInfo.HasColors ) then
                ioSeekCurrent( 4 );
            
            if ( vertexInfo.HasTexCoord2 ) then
                ioSeekCurrent( 4 );
        )
    )
    
    local indexBufferOffset = bufferGroup.IndexBufferOffset;
    local effectiveIndexBufferOffset = indexBufferOffset + ( ( subMesh.IndexBufferStartIndex - 1 ) * 2 );
    
    ioSeekBegin( effectiveIndexBufferOffset );
    local triangles = #();
    
    if ( primitiveType == WMB4_PRIMITIVE_TYPE_TRIANGLE_LIST ) then
    (
        local triangleCount = subMesh.IndexCount / 3;
        triangles[ triangleCount ] = undefined;
        
        for i = 1 to triangleCount do
        (
            local c = ioReadInt16() + 1;
            local b = ioReadInt16() + 1;
            local a = ioReadInt16() + 1;
            triangles[i] = [ a, b, c ];
        )
    )
    else
    (
        throw "Unimplemented";
    )
    
    local maxMesh = mesh vertices:positions faces:triangles;
    
    -- Set up texture coordinates
    maxMesh.NumTVerts = vertexCount;
    buildTVFaces maxMesh;
    for i = 1 to triangles.Count do setTVFace maxMesh i triangles[i];
    for i = 1 to texCoords.Count do setTVert maxMesh i texCoords[i];
        
    -- Set up weights
    if ( vertexInfo.HasWeights ) then 
    (
        max modify mode;
        select maxMesh;
        skinMod = skin();
        addModifier maxMesh skinMod;
        
        -- Add used bones to the skin modifier
        local boneToNodeIndices = msh.BonePalette;
        for i in boneToNodeIndices do
        (
            local maxBone = maxBones[i];
            skinOps.addBone skinMod maxBone 0;
        )
        
        modPanel.setCurrentObject skinMod;
        for i = 1 to vertexCount do 
           skinOps.ReplaceVertexWeights skinMod i boneIndices[i] boneWeights[i];
    )
    
    -- Set up material
    maxMesh.Material = standard();
    maxMesh.Material.Name = msh.MaterialIndex as string;
    maxMesh.Material.DiffuseMap = Bitmaptexture filename:( bit.intashex( msh.Mat.DiffuseMapUID ) as string + ".dds" );
    
    if ( msh.Mat.NormalMapUID != undefined ) then
    (
        maxMesh.Material.BumpMap = Normal_Bump();
        maxMesh.Material.BumpMap.Normal_Map = Bitmaptexture filename:( bit.intashex( msh.Mat.NormalMapUID ) as string + ".dds" );
    )
    
    maxMesh.Material.ShowinViewport = true;
    maxMesh.BackFaceCull = on;
    
    maxMesh;
)

function wmb4VertexInfoCreate flags =
(
    local vertexInfo = wmb4VertexInfo();
    vertexInfo.HasWeights = bit.get flags 5;
    vertexInfo.HasColors = bit.get flags 17;
    vertexInfo.HasTexCoord2 = bit.get flags 10;
    vertexInfo.Stride = 24;
    
    if ( vertexInfo.HasWeights ) then
    (
        vertexInfo.Stride += 8;
    )
    else
    (
        if ( vertexInfo.HasColors ) then vertexInfo.Stride += 4;
        if ( vertexInfo.HasTexCoord2 ) then vertexInfo.Stride += 4;
    )
    
    vertexInfo;
)

function wmb4MaterialRead =
(
    local mat = wmb4Material();
    
    ioSeekCurrent( 4 );
    local shaderIntParameterListOffset = ioReadInt32();
    ioSeekCurrent( 4 );
    local shaderFloatParameterListOffset = ioReadInt32();
    ioSeekCurrent( 8 );
    
    local endPosition = ioTell();
    
    local shaderIntParameterListSize = shaderFloatParameterListOffset - shaderIntParameterListOffset;
    ioSeekBegin( shaderIntParameterListOffset );
    
    if ( shaderIntParameterListSize >= 8 ) then
    (
        ioSeekCurrent( 4 );
        mat.DiffuseMapIndex = ioReadInt32() + 1;
    )
    
    if ( shaderIntParameterListSize >= 32 ) then
    (
        ioSeekCurrent( 20 );
        mat.NormalMapIndex = ioReadInt32() + 1;
    )
    
    ioSeekBegin( endPosition );
    mat;
)

function wmb4BonePaletteListRead count =
(
    local bonePalettes = #();
    bonePalettes[count] = undefined;
    
    for i = 1 to count do
    (
        local offset = ioReadInt32();
        local indexCount = ioReadInt32();
        if ( indexCount == 0 ) then continue;
        
        bonePalettes[i] = #();
        bonePalettes[i][indexCount] = undefined;
        
        local nextPos = ioTell();
        
        ioSeekBegin( offset );
        for j = 1 to indexCount do bonePalettes[i][j] = ioReadByte() + 1;
        
        ioSeekBegin( nextPos );
    )
    
    bonePalettes;
)

struct wmb4LoaderOptions
(
    ApplyNormals = true,
    ApplyWeights = true
)

function wmb4Load path =
(
    ioInit();
    ioOpenFile path "rb";
    
    local magic = ioReadInt32();
    ioSeekCurrent( 4 );
    local flags = ioReadInt32();
    local primitiveType = ioReadInt16();
    ioSeekCurrent( 26 );
    local bufferGroupListOffset = ioReadInt32();
    local bufferGroupCount = ioReadInt32();
    local subMeshListOffset = ioReadInt32();
    local subMeshCount = ioReadInt32();
    local meshLODListOffset = ioReadInt32();
    local nodeListOffset = ioReadInt32();
    local nodeCount = ioReadInt32();
    ioSeekCurrent( 8 );
    local bonePaletteListOffset = ioReadInt32();
    local bonePaletteCount = ioReadInt32();
    local materialListOffset = ioReadInt32();
    local materialCount = ioReadInt32();
    local textureListOffset = ioReadInt32();
    local textureCount = ioReadInt32();
    local meshGroupListOffset = ioReadInt32();
    local meshGroupCount = ioReadInt32();
    
    -- Read nodes & convert em to max bones
    ioSeekBegin( nodeListOffset );
    local maxBones = wmb4ParseNodes( nodeCount );
    
    -- Read buffer groups
    ioSeekBegin( bufferGroupListOffset );
    local bufferGroups = #();
    for i = 1 to bufferGroupCount do
        bufferGroups[i] = wmb4BufferGroupRead();
    
    -- Read sub mesh definitions
    ioSeekBegin( subMeshListOffset );
    local subMeshes = #();
    for i = 1 to subMeshCount do
    (
        local subMesh = wmb4SubMeshRead();
        subMesh.BufferGroup = bufferGroups[ subMesh.BufferGroupIndex ];
        subMeshes[ i ] = subMesh;
    )
    
    -- Read bone palettes
    local bonePalettes;
    if ( bonePaletteCount > 0 ) then
    (
        ioSeekBegin( bonePaletteListOffset );
        bonePalettes = wmb4BonePaletteListRead( bonePaletteCount );
    )
    
    -- Read texture references
    ioSeekBegin( textureListOffset );
    local textures = #();
    for i = 1 to textureCount do
    (
        ioSeekCurrent( 4 ); -- flag
        textures[i] = ioReadUInt32();
    )
    
    -- Read materials
    ioSeekBegin( materialListOffset );
    local materials = #();
    for i = 1 to materialCount do
    (
        local mat = wmb4MaterialRead();
        
        if ( mat.DiffuseMapIndex != undefined ) then mat.DiffuseMapUID = textures[ mat.DiffuseMapIndex ];
        if ( mat.NormalMapIndex != undefined ) then mat.NormalMapUID = textures[ mat.NormalMapIndex ];
        
        materials[i] = mat;
    )
    
    -- Read groups
    ioSeekbegin( meshGroupListOffset );
    local meshGroups = wmb4ReadMeshGroups( meshGroupCount );
    
    -- Calculate vertex buffer doodaloo
    local vertexInfo = wmb4VertexInfoCreate( flags );
    
    -- Read mesh definition & create max meshes
    ioSeekBegin( meshLODListOffset );
    for i = 1 to 4 do
    (
        local meshListOffset = ioReadInt32();
        local meshCount = ioReadInt32();
        if ( meshCount == 0 ) then continue;

        local meshLODNextOffset = ioTell();
            
        ioSeekBegin( meshListOffset );
        for j = 1 to meshCount do
        (
            local msh = wmb4MeshRead();
            local meshNextOffset = ioTell();
                
            -- Resolve index references
            msh.SubMesh = subMeshes[ msh.SubMeshIndex ];
            msh.MeshGroup = meshGroups[ msh.GroupIndex ];
            msh.Mat = materials[ msh.MaterialIndex ];
            
            if ( msh.BonePaletteIndex != 0 ) then
                msh.BonePalette = bonePalettes[ msh.BonePaletteIndex ];

            -- Convert wmb4 mesh into max mesh
            local maxMesh = wmb4MeshParse msh vertexInfo primitiveType maxBones;
            
            -- Tag the mesh with important stuff
            maxMesh.Name = "Mesh" + ( j - 1 ) as string + "@GRP(" + msh.MeshGroup.Name;
            
            local matchedIndices = #();
            for k = 1 to 5 do
            (
                local meshIndices = msh.MeshGroup.MeshIds[ k ];
                for meshIndex in meshIndices do
                (
                    if ( meshIndex != j ) then continue;
                    append matchedIndices k;
                    exit;
                )
            )
            
            for matchedIndex in matchedIndices do
            (
                maxMesh.Name += ",";
                maxMesh.Name += ( matchedIndex - 1 ) as string
            )
            
            maxMesh.Name += ")";
            
            if ( i > 1 ) then
            (
                maxMesh.Name += "@LOD(" + ( i - 1 ) as string + ")";
            )
            
            ioSeekBegin( meshNextOffset );
        )
        
        if ( i != 4 ) then
            ioSeekBegin( meshLODNextOffset );
    )

    ioShutdown();
)

function main = 
(
    clearListener();
    global gStartTime = timestamp();
    
    --wmb4Load( @"D:\Games\PC\METAL GEAR RISING REVENGEANCE\Temp\pl1010\pl1010.wmb" );
    --wmb4Load( @"D:\Games\PC\METAL GEAR RISING REVENGEANCE\Dump\dat\pl1010\pl1010.wmb" );
    wmb4Load( @"D:\Games\PC\METAL GEAR RISING REVENGEANCE\Dump\dat\pl1012\pl1012.wmb" );
    --wmb4Load( @"D:\Games\PC\METAL GEAR RISING REVENGEANCE\Dump\wmb\dummy.wmb" );
    --wmb4Load( @"D:\Games\PC\METAL GEAR RISING REVENGEANCE\Dump\wmb\wp10e0.wmb" );
    
    global gEndTime = timestamp();
    print ( "Done! (" + ( ( gEndTime - gStartTime ) as string ) + " ms)" );
    
    OK;
)

main();