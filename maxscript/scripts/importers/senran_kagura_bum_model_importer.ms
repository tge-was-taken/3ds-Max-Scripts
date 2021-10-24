/*
    Senran Kagura: New Link BUM model importer
    By TGE
    Version 1.0
*/

-- Globals

-- File IO
global gFileStream = undefined;
global gFileName = undefined;
global gFilePath = undefined;

-- Parser
global gYToZUp = true;

-- Functions

-- File IO
fn ioOpenFile filePath =
(
    gFileStream = fopen filePath #rb; 
    gFileName = GetFilenameFile filePath
    gFilePath = GetFilenamePath filePath
)

fn ioTell =
(
    FTell gFileStream;
)

fn ioSeekCur position =
(
    FSeek gFileStream position #seek_cur;
)

fn ioSeekSet position =
(
    FSeek gFileStream position #seek_set;
)

fn ioReadU8 =
(
    ReadByte gFileStream #unsigned;
)

fn ioReadS16 =
(
    ReadShort gFileStream #signed;
)

fn ioReadU16 =
(
    ReadShort gFileStream #unsigned;
)

fn ioReadS32 =
(
    ReadLong gFileStream #signed;
)

fn ioReadU32 =
(
    ReadLong gFileStream #unsigned;
)

function ioReadFloat =
(
    ReadFloat gFileStream;
)

function ioReadVector2 =
(
    [ ioReadFloat(), ioReadFloat() ]
)

function ioReadTexCoord =
(
    [ ioReadFloat(), 1f - ioReadFloat(), 0 ]
)

function ioReadVector3 =
(
    local value = [ ioReadFloat(), ioReadFloat(), ioReadFloat() ]
    
    if ( gYToZUp ) then
    (
        local temp = value.Y;
        value.Y = -value.Z;
        value.Z = temp;
    )
    
    value;
)

fn ioReadFixedString len =
(
    local str = "";
    
    for i = 1 to len do
    (
        local b = ioReadU8();
        if ( b != 0 ) then
            str += bit.intAsChar b;
    )
    
    str;
)

-- File format IO
struct bumChunkHeader
(
    Start,
    Magic,
    Length,
    End
)

fn bumChunkHeaderRead =
(
    local header = bumChunkHeader();
    header.Start = ioTell();
    header.Magic = ioReadFixedString( 4 );
    header.Length = ioReadU32();
    header.End = header.Start + header.Length;
    --print header;
    header;
)

fn bumNameRead header =
(
    ioReadFixedString ( header.Length - 8 );
)

fn bumNameReadChunk =
(
    local header = bumChunkHeaderRead();
    if ( header.Magic != "NAME" ) then throw "Expected NAME chunk";
    ( bumNameRead( header ) );
)

struct bumNode
(
    Name,
    Id,
    ParentIndex = -1,
    Translation,
    BoneIndices,
    InverseBindMatrices,
    DrawParams,
    MaxBone,
    Index
)

struct bumDrawParams
(
    Field00,
    GeometryIndex
)

fn bumDrawParamsRead =
(
    local drawParams = bumDrawParams();
    drawParams.Field00 = ioReadU32();
    drawParams.GeometryIndex = ioReadU32() + 1;
    drawParams;
)

fn bumNodeRead header =
(
    local node = bumNode();
    
    while ( ioTell() < header.End ) do
    (
        local subHeader = bumChunkHeaderRead();
        case ( subHeader.Magic ) of
        (
            "NAME": node.Name = bumNameRead( subHeader );
            "NSTA": node.Id = ioReadU32();
            "PARE": node.ParentIndex = ioReadS32();
            "TRNS": node.Translation = ioReadVector3();
            "BLEB":
            (
                local boneCount = ioReadU32();
                node.BoneIndices = #();
                for i = 1 to boneCount do
                    append node.BoneIndices ( ioReadU16() + 1 );
            )
            "DRWP":
            (
                node.DrawParams = bumDrawParamsRead();
            )
        )
        
        ioSeekSet( subHeader.End );
    )
    
    node;
)

struct bumMesh
(
    MaterialIndex,
    UsedBoneIndices = #(),
    Triangles = #(),
    VertexBuffer,
    MaxMesh
)

fn bumMeshRead header =
(
    local mesh = bumMesh();
    
    while ( ioTell() < header.End ) do
    (
        local subHeader = bumChunkHeaderRead();
        case ( subHeader.Magic ) of
        (
            "SMAT": mesh.MaterialIndex = ioReadU32() + 1;
            "BLES": 
            (
                local count = ioReadU32();
                for i = 1 to count do
                    append mesh.UsedBoneIndices (ioReadU32() + 1);
            )
            "DRWA":
            (
                local field08 = ioReadU16();
                local indexCount = ioReadU16();
                local triangleCount = indexCount / 3;
                for i = 1 to triangleCount do
                    append mesh.Triangles [ ioReadU16() + 1, ioReadU16() + 1, ioReadU16() + 1 ]
            )
        )
        
        ioSeekSet( subHeader.End );
    )
    
    mesh;
)

struct bumVertexBuffer
(
    Positions = #(),
    Normals = #(),
    TexCoords = #(),
    Colors = #(),
    BoneWeights = #()
)

fn bumVertexBufferRead header usedBoneCount =
(
    local vertexBuffer = bumVertexBuffer();
    local vertexFormat = ioReadU16();
    local vertexCount = ioReadU16();
    --print ( bit.intashex vertexFormat ) as string
    for i = 1 to vertexCount do
    (
        if ( bit.get vertexFormat 1 ) then append vertexBuffer.Positions (ioReadVector3());
        if ( bit.get vertexFormat 2 ) then append vertexBuffer.Normals (ioReadVector3());
        if ( bit.get vertexFormat 4 ) then append vertexBuffer.TexCoords (ioReadTexCoord());
        if ( bit.get vertexFormat 3 ) then append vertexBuffer.Colors (ioReadU32());
        if ( bit.get vertexFormat 14 ) then 
        (
            local weights = #();
            for j = 1 to usedBoneCount do
                append weights (ioReadU8() as float / 255f);
            
            ioSeekCur( (8 - usedBoneCount) );
            
            append vertexBuffer.BoneWeights weights;
        )
    )
    
    --print vertexBuffer
    
    vertexBuffer;
)

struct bumGeometry
(
    Name,
    Meshes = #()
)

fn bumGeometryRead header =
(
    local geo = bumGeometry();
    local vertexBufferIndex = 1;
    
    while ( ioTell() < header.End ) do
    (
        local subHeader = bumChunkHeaderRead();
        case ( subHeader.Magic ) of
        (
            "NAME": geo.Name = bumNameRead( subHeader );
            "MESH": append geo.Meshes ( bumMeshRead( subHeader ) );
            "ARAY": 
            (
                local bumMesh = geo.Meshes[ vertexBufferIndex ];
                bumMesh.VertexBuffer = ( bumVertexBufferRead subHeader bumMesh.UsedBoneIndices.Count );
                geo.Meshes[ vertexBufferIndex ] = bumMesh;
                vertexBufferIndex += 1;
            )
        )
        
        ioSeekSet( subHeader.End );
    )
    
    geo;
)

struct bumMaterial
(
    Name,
    Shader
)

fn bumMaterialRead header =
(
    local mat = bumMaterial();
    
    while ( ioTell() < header.End ) do
    (
        local subHeader = bumChunkHeaderRead();
        case ( subHeader.Magic ) of
        (
            "NAME": mat.Name = bumNameRead( subHeader );
        )
        
        ioSeekSet( subHeader.End );
    )
    
    mat;
)

struct bumMaterialShader
(
    MaterialName,
    ShaderName,
    Samplers = #()
)

struct bumSampler
(
    Name,
    TextureName,
    Params = #()
)

struct bumSamplerParam
(
    Name,
    Value
)

fn bumSamplerRead header =
(
    -- This one is formattedly weirdly
    local sampler = bumSampler();
    sampler.Name = bumNameReadChunk();
    sampler.TextureName = bumNameReadChunk();
--     local parameterCount = ioReadU32();
--     for i = 1 to parameterCount do
--     (
--         local param = bumSamplerParam();
--         param.Name = bumNameReadChunk();
--         param.String = bumStringReadChunk();
--     )
    
    sampler;
)

fn bumMaterialShaderRead header =
(
    local mats = bumMaterialShader();
    local field00 = ioReadU16();
    local field02 = ioReadU16();
    mats.MaterialName = bumNameReadChunk();
    mats.ShaderName = bumNameReadChunk();
    
    while ( ioTell() < header.End ) do
    (
        local subHeader = bumChunkHeaderRead();
        case ( subHeader.Magic ) of
        (
            "SAMP": append mats.Samplers ( bumSamplerRead( subHeader ) );
        )
        
        ioSeekSet( subHeader.End );
    )
    
    mats;
)

fn bumModelParse header =
(
    local nodes = #();
    local geometries = #();
    local materials = #();
    local nodeIndex = 1;
    
    while ( ioTell() < header.End ) do
    (
        local subHeader = bumChunkHeaderRead();
        case ( subHeader.Magic ) of
        (
            "NODE": 
            (
                local node = bumNodeRead( subHeader );
                
                local parentBone = undefined;
                if ( node.ParentIndex != -1 ) do
                    parentBone = nodes[node.ParentIndex + 1].MaxBone;
        
                
                local tfm = matrix3 1;
                if ( nodes.Count == 0 or node.Translation != undefined ) then
                (
                    node.Index = nodeIndex;
                    nodeIndex += 1;
                    
                    if ( node.Translation != undefined ) then
                        tfm = transmatrix node.Translation;
                )
                else
                (
                    node.Index = -1;
                )
                
                if ( parentBone != undefined ) do
                    tfm *= parentBone.transform;
                
                local newBone = bonesys.createbone \
                          tfm.row4	\
                          (tfm.row4 + 0.01 * (normalize tfm.row1)) \
                          (normalize tfm.row3);
                                  
                newBone.name = node.Name;
                newBone.width  = 0.01;
                newBone.height = 0.01;
                newBone.transform = tfm;
                newBone.setBoneEnable false 0;
                newBone.wirecolor = yellow;
                newBone.showlinks = true;
                newBone.pos.controller      = TCB_position ();
                newBone.rotation.controller = TCB_rotation ();
                newBone.Parent = parentBone;
                
                node.MaxBone = newBone; 
                append nodes node;
            )
            "PART": append geometries ( bumGeometryRead( subHeader ) );
            "MATR": append materials ( bumMaterialRead( subHeader ) ); 
            "MATS":
            (
                local materialShader = ( bumMaterialShaderRead( subHeader ) );
                for m in materials do
                (
                    if ( m.Name == materialShader.MaterialName ) then
                        m.Shader = materialShader;
                )
            )
        )
        
        ioSeekSet( subHeader.End );
    )

    for i = 1 to nodes.Count do
    (
        local bumNode = nodes[i];
        if ( bumNode.DrawParams != undefined ) then
        (
            local bumGeo = geometries[ bumNode.DrawParams.GeometryIndex ];
            for j = 1 to bumGeo.Meshes.Count do
            (
                local bumMesh = bumGeo.Meshes[j];
                if ( bumMesh.VertexBuffer == undefined ) then continue;
                
                --print bumMesh;
                
                local maxMesh = mesh vertices:bumMesh.VertexBuffer.Positions normals:bumMesh.VertexBuffer.Normals faces:bumMesh.Triangles;
                maxMesh.Name = bumGeo.Name;
                
                -- Set up texture coordinates
                if ( bumMesh.VertexBuffer.TexCoords.Count > 0 ) then
                (
                    maxMesh.NumTVerts = bumMesh.VertexBuffer.Positions.Count;
                    buildTVFaces maxMesh;
                    for i = 1 to bumMesh.Triangles.Count do setTVFace maxMesh i bumMesh.Triangles[i];
                    for i = 1 to bumMesh.VertexBuffer.TexCoords.Count do setTVert maxMesh i bumMesh.VertexBuffer.TexCoords[i];
                )
                
                -- Set up weights
                if ( bumMesh.VertexBuffer.BoneWeights.Count > 0 ) then 
                (
                    max modify mode;
                    select maxMesh;
                    skinMod = skin();
                    addModifier maxMesh skinMod;
                    
                    -- Add used bones to the skin modifier
                    for k in bumNode.BoneIndices do
                    (
                        local boneNode = undefined;
                        for n in nodes do
                        (
                            if ( n.Index == k ) then
                            (
                                boneNode = n;
                                exit;
                            )
                        )
                        
                        local maxBone = boneNode.MaxBone;
                        skinOps.addBone skinMod maxBone 0;
                    )
                    
                    modPanel.setCurrentObject skinMod;
                    for k = 1 to bumMesh.VertexBuffer.Positions.Count do
                        skinOps.ReplaceVertexWeights skinMod k bumMesh.UsedBoneIndices bumMesh.VertexBuffer.BoneWeights[k];
                )
                
                -- Set up material
                local bumMaterial = materials[ bumMesh.MaterialIndex ];
                maxMesh.Material = standard();
                maxMesh.Material.Name = bumMaterial.Name;
                
                if ( bumMaterial.Shader != undefined ) then
                (
                    for bumSampler in bumMaterial.Shader.Samplers do
                    (
                        case ( bumSampler.Name ) of
                        (
                            "DiffuseSampler": maxMesh.Material.DiffuseMap = Bitmaptexture filename:( gFilePath + bumSampler.TextureName + ".png" );
                            default:
                            (
                                format "Material '%' %: %\n" bumMaterial.Name bumSampler.Name ( bumSampler.TextureName + ".png" )
                            )
                        )
                    )
                )
                
                maxMesh.Material.ShowinViewport = true;
                maxMesh.BackFaceCull = on;
            )
        )
    )
)

fn bumModelPackParse header =
(
    local modelIndex = 0;
    
    while ( ioTell() < header.End ) do
    (
        local subHeader = bumChunkHeaderRead();
        case ( subHeader.Magic ) of
        (
            "MODL": bumModelParse( subHeader );
        )
        
        ioSeekSet( subHeader.End );
    )
)

fn bumModelImport filePath =
(
    ioOpenFile( filePath );
    local header = bumChunkHeaderRead();
    if ( header.Magic != ".BUM" ) do
        throw "Not a valid BUM model file."
    
    bumModelPackParse( header );
)

fn main =
(
    clearListener();
    
    local filePath = getOpenFileName \ 
        caption:"Open file" \
        types:"BUM model (*.bum)|*.bum" \
        historyCategory:"SenranKaguraBUM Object Presets"
    
    if ( filePath != undefined ) then
        bumModelImport( filePath );
)

main();