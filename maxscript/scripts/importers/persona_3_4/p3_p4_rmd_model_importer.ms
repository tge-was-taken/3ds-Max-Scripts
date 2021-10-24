/* 
    Persona 3/4 Model Importer, version 5
    Written by TGE. Credit would be nice ;)

    To use automatic texture importing & exporting you need to have TextureExporter\RMDTextureExporter.exe in the same folder as the script!
    The program will dump the textures to the %filename%_tex\ folder in the same folder as the imported file!
    
    Changelog version 4.0:
        - Proper parsing of HAnim nodes, in order to help support the animation importer
        - User properties are set for bone nodes, containing: 
            - Name id
            - Frame index
            - HAnim node index
        - Bones are now given names based on the HAnim name id
        - Various performance improvements
        
    Changelog version 4.1
        - Implemented more compatible texture exporter
        
    Changelog version 5
        - Properly load material names
        - Script refactoring.
*/

global gUVFlip        = true -- set to false if you want the original uv map
global gImportWeights = true -- set to false if you dont want to import the weighting (speeds up importing a lot)
global gImportNormals = true -- set to false if you dont want to import the normals (speeds up importing)

struct NodeHeader
(
    Offset,
    Type,
    Size,
    Version,
    EndOffset
)

struct BoneInfo 
(
	Parent,
	Name,
	Transform
)

struct Atomic
(
	FrameIndex,
	GeometryIndex,
	Flag1,
	Flag2
)

struct WeightData
(
	boneids,weights
)

struct SkinData
(
	UsedBoneCount,
	UsedBoneIndexCount,
	Weights
)

struct GeometryData
(
	Colors,
	UvChannels,
	Triangles,
	TriangleMaterialIds,
	Vertices,
	Normals
)

struct HAnimNodeInfo
(
    NameId,
    Index,
    FrameIndex
)

global gFileStream = undefined;
global gFileName = undefined;
global gFilePath = undefined;
global gFileType = undefined;
global gFileEnd = undefined;
global gScriptDirectory = getFileNamePath (getThisScriptFilename());
global gTextureExporterPath = gScriptDirectory + "TextureExporter\\RMDTextureExporter.exe";

global gAtomics = #();
global gFrames = #();
global gFrameIndexBase = 0;
global gFrameCount = 0;
global gHAnimNodeInfoArray = #();
global gMaxBoneArray = #();
global gGeometrySkins = #();
global gGeometryDataArray = #(); 
global gGeometryCount = 0;
global gGeometryIndexBase = 0;
global gMaterialListTextureNames = #()
global gMaterialNames = #();
global gMaterialListMaterialNames = #();
global gNumMaterialTextureNamesRead = 0;
global gMaterialCount = 0;
global gVertexCount = 0;
    
    
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

fn PrintNodeHeader Chunk = 
(
	Format ("Node 0x" + (bit.intashex(Chunk.Type) as string) + " size 0x"+(bit.intashex(Chunk.Size) as string) + " @ 0x"+ (bit.intashex(Chunk.Offset) as string) + "\n")
)

fn ReadNodeHeader fstream =
(
	local node = (NodeHeader \
		Offset:(ftell fstream) \
		Type:(ReadLong fstream #unsigned) \
		Size:(ReadLong fstream #unsigned) \
		Version:(ReadLong fstream #unsigned) \
	)
    
    node.EndOffset = ( node.Offset + 0xC ) + node.Size;
    --PrintNodeHeader( node )
	
	node
)

fn ReadTextureNative header =
(
    local textureName = undefined;
    
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader gFileStream
        
        case (childNode.Type) of
        (
            0x2: 
            (
                local curTextureName = ReadFixedString gFileStream childNode.Size;
                if ( textureName == undefined ) then 
                    textureName = curTextureName;
            )
            0x1: ( -- Texture Image
                if (childNode.Size >= 80) then -- 80 is the size of the texture header
                (
                    local textureBytes = #()
                    local textureByteSize = header.Size + 0xC
                    textureBytes[textureByteSize] = 0
                    
                    FSeek gFileStream header.Offset #seek_set
                    for i = 1 to (textureByteSize) do 
                        textureBytes[i] = ReadByte gFileStream
                    
                    local textureDirectoryPath = gFilePath + gFileName + "_tex\\";
                    local pngFilePath = textureDirectoryPath + textureName + ".png";
                    local txnFilePath = textureDirectoryPath + textureName + ".txn";
                    MakeDir textureDirectoryPath;

                    if ( DoesFileExist( pngFilePath ) ) then 
                    (
                        format "PNG found! Skipping conversion of %\n" textureName
                    )
                    else
                    (
                        if ( DoesFileExist( gTextureExporterPath ) ) then
                        (
                            local texOut = fopen txnFilePath "wb"
  
                            for i = 1 to textureByteSize
                                do WriteByte texOut textureBytes[i]
                                                 
                            fclose texOut
                            ShellLaunch gTextureExporterPath ("\"" + txnFilePath + "\"")
                            sleep 0.2
                        )
                        else
                        (
                            format "RMDTextureExporter.exe not found! Skipping conversion of %\n" textureName
                        )
                    )
                    
                    FSeek gFileStream ( childNode.EndOffset ) #seek_set
                    
                )
                else
                (
                    FSeek gFileStream childNode.Size #seek_cur
                )
            )
            default: (
                FSeek gFileStream childNode.Size #seek_cur
            )
        )
    )
)

fn ReadTextureDictionary header =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader gFileStream;

        case (childNode.Type) of
        (
            0x15:
                ReadTextureNative( childNode );
            
            default: 
                FSeek gFileStream childNode.Size #seek_cur;
        )
    )
)

fn ReadFrameList header =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader gFileStream
        
        case (childNode.Type) of
        (
            (0x1): 
            (
                while (not FTell( gFileStream ) >= childNode.EndOffset) do
                (
                    gFrameCount = ReadLong gFileStream
                    for b = 1 to gFrameCount do
                    (
                        m11 = ReadFloat gFileStream; m12 = ReadFloat gFileStream; m13 = ReadFloat gFileStream
                        m21 = ReadFloat gFileStream; m22 = ReadFloat gFileStream; m23 = ReadFloat gFileStream
                        m31 = ReadFloat gFileStream; m32 = ReadFloat gFileStream; m33 = ReadFloat gFileStream
                        m41 = ReadFloat gFileStream; m42 = ReadFloat gFileStream; m43 = ReadFloat gFileStream
                        Parent = (ReadLong gFileStream) + gFrameIndexBase
                        BoneFlag = ReadLong gFileStream -- Always 3? except for levels
                        Name = ("Bone"+((b + gFrameIndexBase) as string))
                        
                        tfm = matrix3 [m11,m12,m13] [m21,m22,m23] [m31,m32,m33] [m41,m42,m43]
                        append gFrames (BoneInfo Parent:Parent Name:Name Transform:tfm)
                    )
                )
            )
            default:
                FSeek gFileStream (childNode.Size) #seek_cur
        )
        
        for i = 1 to gFrameCount do
        (
            local extensionNode = ReadNodeHeader gFileStream
            if ( extensionNode.Type != 3 ) then
            (
                FSeek gFileStream -12 #seek_cur;
                exit;
            )
            
            if (extensionNode.Size >= 0xC) then
            (
                local hAnimNode = ReadNodeHeader gFileStream
                if ( hAnimNode.Type != 0x0000011E ) then
                (
                    FSeek gFileStream -12 #seek_cur;
                    exit;
                )
                
                local hAnimVersion = ReadLong gFileStream
                local hAnimNameId = ReadLong gFileStream
                local hAnimNumNodes = ReadLong gFileStream
                
                if (hAnimNumNodes != 0) then
                (
                    local hAnimFlags = ReadLong gFileStream
                    local hAnimKeyFrameSize = ReadLong gFileStream
                    for j = 1 to hAnimNumNodes do
                    (
                        local hAnimNodeNameId = ReadLong gFileStream
                        local hAnimNodeIndex = ( ReadLong gFileStream ) + 1
                        local hAnimNodeFlags = ReadLong gFileStream
                        
                        local nodeInfo = HAnimNodeInfo()
                        nodeInfo.NameId = hAnimNodeNameId
                        nodeInfo.Index = hAnimNodeIndex
                        append gHAnimNodeInfoArray nodeInfo
                    )
                )
                
                local curNodeInfo = undefined
                for nodeInfo in gHAnimNodeInfoArray do
                (
                    if ( nodeInfo.NameId == hAnimNameId ) then
                    (
                        curNodeInfo = nodeInfo
                        exit
                    )
                )
                
                if ( curNodeInfo != undefined ) then
                    curNodeInfo.FrameIndex = i
                
                gFrames[i].Name = "_" + hAnimNameId as string
            )
            else
            (
                gFrames[i].Name = "RootNode"
            )
        )  
    )
)

fn ReadGeometryData header =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local geometryFlags = ReadShort gFileStream #unsigned;
        local uvChannelCount = ReadShort gFileStream #unsigned;
        local triangleCount = ReadLong gFileStream;
        gVertexCount = ReadLong gFileStream;
        local morphCount = ReadLong gFileStream;
        
        local hasColors = bit.get geometryFlags 4;
        local colors = #();
        local uvChannels = #();
        local triangles = #();
        local triangleMaterialIds = #();
        local vertices = #();
        local normals = #();
        
        if ( hasColors ) then
        (
            for v = 1 to gVertexCount do 
            (
                local r = ReadByte gFileStream #unsigned;
                local g = ReadByte gFileStream #unsigned;
                local b = ReadByte gFileStream #unsigned;
                local a = ReadByte gFileStream #unsigned;
                append colors [ r, g, b ];
            )
        )
        
        for x = 1 to uvChannelCount do
        (
            local uvs = #();
            for v = 1 to gVertexCount do 
            (
                local tu = ReadFloat gFileStream;
                local tv = ReadFloat gFileStream;
                
                if ( gUVFlip ) then 
                    tv *= -1;
                
                append uvs [ tu, tv, 0 ];
            )
            
            uvChannels[x] = uvs;
        )
         
        for y = 1 to triangleCount do 
        (
            local f1 = ReadShort gFileStream + 1;
            local f2 = ReadShort gFileStream + 1;
            local matId = ReadShort gFileStream + 1;
            local f3 = ReadShort gFileStream + 1;
            
             -- faces are stored backwards
            append triangles [f3, f2, f1];
            append triangleMaterialIds matId;
        )
        
        FSeek gFileStream 24 #seek_cur;
        
        for x = 1 to gVertexCount do 
        (
            local vx = ReadFloat gFileStream;
            local vy = ReadFloat gFileStream;
            local vz = ReadFloat gFileStream;
            append vertices [vx,vy,vz];
        )

        for z = 1 to gVertexCount do 
        (
            local nx = ReadFloat gFileStream;
            local ny = ReadFloat gFileStream;
            local nz = ReadFloat gFileStream;
            append normals [nx,ny,nz];
        )
        
        append gGeometryDataArray (GeometryData Colors:colors UvChannels:uvChannels Triangles:triangles TriangleMaterialIds:triangleMaterialIds Vertices:vertices Normals:normals);
        
        FSeek gFileStream (header.EndOffset) #seek_set;
        
    )
    
    gGeometryCount += 1;
)

fn ReadTextureReference header &materialTextureNames =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader gFileStream
                
        case (childNode.Type) of
        (
            (0x1): 
            ( -- Material Texture Info
                MaterialTextureInfo = ReadLong gFileStream
            )
            (0x2): 
            ( -- Material Texture Name Info
                gNumMaterialTextureNamesRead += 1
                local materialName = ReadFixedString gFileStream childNode.Size
                if ( gNumMaterialTextureNamesRead == 1 ) then 
                (
                    append materialTextureNames materialName -- only store the diffuse map
                )
            )
            default: (
                FSeek gFileStream (childNode.Size) #seek_cur
            )
        )
    )
)

fn ReadMaterialExtensionList header =
(
    local materialName = undefined;
    
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader( gFileStream );
        
        case ( childNode.Type ) of
        (
            (0x11F): ( -- User data
                local count = ReadLong gFileStream;
                for i = 1 to count do
                (
                    local nameLength = ReadLong gFileStream;
                    local name = "";
                    if ( nameLength > 0 ) then
                    (
                        name = ReadFixedString gFileStream ( nameLength - 1);
                        FSeek gFileStream 1 #seek_cur;
                    )
                    
                    local format = ReadLong gFileStream;
                    local unknown = ReadLong gFileStream;
                    local value = undefined;
                    
                    case ( format ) of
                    (
                        1: value = ReadLong gFileStream;
                        2: value = ReadFloat gFileStream;
                        3:
                        (
                            local valueLength = ReadLong gFileStream;
                            value = "";
                            if ( valueLength > 0 ) then
                            (
                                value = ReadFixedString gFileStream ( valueLength - 1);
                                FSeek gFileStream 1 #seek_cur;
                            )
                        )
                    )
                    
                    if ( name == "name" and format == 3 ) then
                    (
                        materialName = value;
                    )
                )
            )
            default: (
                FSeek gFileStream (childNode.Size) #seek_cur
            )
        )
    )
    
    append gMaterialNames materialName;
)

fn ReadMaterial header &materialTextureNames =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader gFileStream

        case (childNode.Type) of
        (            
            (0x6):
                ReadTextureReference childNode &materialTextureNames;
            
            (0x3):
                ReadMaterialExtensionList( childNode );
            
            default:
                FSeek gFileStream (childNode.Size) #seek_cur
        )
    )
    
    gMaterialCount += 1
)

fn ReadMaterialList header =
(
    local materialTextureNames = #();
    
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader gFileStream;
        gNumMaterialTextureNamesRead = 0
        
        case  (childNode.Type) of
        (
            0x7: 
                ReadMaterial childNode &materialTextureNames;
            
            default:
                FSeek gFileStream (childNode.Size) #seek_cur
        )
    )
    append gMaterialListTextureNames materialTextureNames
    append gMaterialListMaterialNames gMaterialNames
)

fn ReadSkin header =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        Weights = #()
        WeightBoneArray = #()
        BonePallet_Array = #()
        UsedBoneCount = ReadByte gFileStream #unsigned
        UsedBoneIndexCount = ReadByte gFileStream #unsigned
        flag = ReadShort gFileStream 

        for x = 1 to UsedBoneIndexCount do
        (
            unk = ReadByte gFileStream -- appears to be unused by the game
        )

        for x = 1 to gVertexCount do
        (
            bone1 = ReadByte gFileStream #unsigned
            bone2 = ReadByte gFileStream #unsigned
            bone3 = ReadByte gFileStream #unsigned
            bone4 = ReadByte gFileStream #unsigned
            append WeightBoneArray [bone1, bone2, bone3, bone4]
        )

        for x = 1 to gVertexCount do
        (
            weight1 = ReadFloat gFileStream
            weight2 = ReadFloat gFileStream
            weight3 = ReadFloat gFileStream
            weight4 = ReadFloat gFileStream
            
            w = (WeightData boneids:#() weights:#())
            maxweight = 0
            if(weight1 != 0.0) then
               maxweight = maxweight + weight1
            if(weight2 != 0.0) then
               maxweight = maxweight + weight2
            if(weight3 != 0.0) then
               maxweight = maxweight + weight3
            if(weight4 != 0.0) then
               maxweight = maxweight + weight4


            if(maxweight != 0.0) then (
                  if(weight1 != 0.0) then (
                     w1 = weight1
                     append w.boneids (WeightBoneArray[x][1] + 1)
                     append w.weights (w1)
                  )
                  if(weight2 != 0.0) then (
                     w2 = weight2
                     append w.boneids (WeightBoneArray[x][2] + 1)
                     append w.weights (w2)
                  )
                  if(weight3 != 0.0) then (
                     w3 = weight3
                     append w.boneids (WeightBoneArray[x][3] + 1)
                     append w.weights (w3)
                  )
                  if(weight4 != 0.0) then (
                     w4 = weight4
                     append w.boneids (WeightBoneArray[x][4] + 1)
                    append w.weights (w4)
                  )      
            )
            append Weights w

        )

        for x = 1 to UsedBoneCount do
        (
            FSeek gFileStream 0x40 #seek_cur -- bone matrix reference
        )
        
        unk3 = ReadLong gFileStream
        unk4 = ReadLong gFileStream
        unk5 = ReadLong gFileStream
        
        if (flag == 0x3) then
        (

            for x = 1 to UsedBoneCount do
            (
                unk6 = ReadByte gFileStream
            )

            for x = 1 to UsedBoneIndexCount do
            (
                unk7 = ReadShort gFileStream
            )

        )
        
        FSeek gFileStream (header.EndOffset) #seek_set -- to make sure it reaches the end of the chunk properly
        gGeometrySkins[gGeometryCount] = (SkinData UsedBoneCount:UsedBoneCount UsedBoneIndexCount:UsedBoneIndexCount Weights:Weights)
    )
)

fn ReadGeometryExtensionList header =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode =  ReadNodeHeader gFileStream;

        case (childNode.Type) of
        (
            0x116: 
                ReadSkin( childNode );
            
            default:
                FSeek gFileStream (childNode.Size) #seek_cur;
        )
    )
)

fn ReadGeometry header =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader gFileStream;
        
        case (childNode.Type) of
        (
            0x1: 
                ReadGeometryData( childNode );
            
            0x8: 
                ReadMaterialList( childNode );
            
            0x3: 
                ReadGeometryExtensionList( childNode );
            
            default:
                FSeek gFileStream (childNode.Size) #seek_cur
        )
    )
)

fn ReadGeometryList header =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader gFileStream
        
        case  (childNode.Type) of
        (
            0xF: 
                ReadGeometry( childNode );
            
            default:
                FSeek gFileStream (childNode.Size) #seek_cur
        )
    )
)

fn ReadAtomicList header =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader gFileStream
        
        case (childNode.Type) of
        (
            (0x1):
            (
                while (not FTell( gFileStream ) >= childNode.EndOffset) do
                (
                    local frameIndex = (ReadLong gFileStream + 1) + gFrameIndexBase  
                    local geometryIndex = (ReadLong gFileStream + 1) + gGeometryIndexBase
                    local flag1 = ReadLong gFileStream + 1 -- Always 0x6
                    local flag2 = ReadLong gFileStream + 1 -- Always 0x1
                    append gAtomics (Atomic FrameIndex:frameIndex GeometryIndex:geometryIndex Flag1:flag1 Flag2:flag2)
                )
            )
            default:
                FSeek gFileStream (childNode.Size) #seek_cur
        )
    )
)

fn ReadClump header =
(
    while (not FTell( gFileStream ) >= header.EndOffset) do
    (
        local childNode = ReadNodeHeader gFileStream;
            
        case  (childNode.Type) of
        (
            (0xE): 
                ReadFrameList( childNode );
            
            (0x1A): 
                ReadGeometryList( childNode );
            
            (0x14):
                ReadAtomicList( childNode );
            
            default:
                FSeek gFileStream (childNode.Size) #seek_cur
        )
    )
)

fn ReadFile =
(
    case (gFileType) of
    (
        (".PAC"): (
            FSeek gFileStream 0x100 #seek_cur
        )
        (".FPC"): (
            FSeek gFileStream 0x100 #seek_cur
        )
        (".P01"): (
            FSeek gFileStream 0x100 #seek_cur
        )
    )
    
    while (not FTell( gFileStream ) >= gFileEnd) do 
    (
        local node = ReadNodeHeader gFileStream
        
        case ( node.Type ) of 
        (
            0x16: 
                ReadTextureDictionary( node );
            0x10: 
                ReadClump( node );
            0xFFFFFFFFF0F000E0: 
                FSeek gFileStream (node.Size + 0x2) #seek_cur;
            default: 
                FSeek gFileStream (node.Size) #seek_cur;
        )
        
        gGeometryIndexBase += gGeometryCount;
        gFrameIndexBase += gFrameCount;
    )
)

fn BuildBones =
(
    for b = 1 to gFrames.count do
    (		
        if (getNodeByName gFrames[b].Name) != undefined do (append gMaxBoneArray (getNodeByName gFrames[b].Name))
        if ((gFrames[b].Parent != -1) AND (gFrames[b].Parent < b)) then ( gFrames[b].Transform = gFrames[b].Transform * gMaxBoneArray[gFrames[b].Parent+1].objecttransform ) 
        else if ((b > 1) AND (gFrames[b].Parent > -1)) do (print ("Bone named " + gFrames[b].Name as string + " has a parent bone that doesn't exist yet!"))
        
        newBone = bonesys.createbone	\
                          gFrames[b].Transform.row4	\
                          (gFrames[b].Transform.row4 + 0.01 * (normalize gFrames[b].Transform.row1)) \
                          (normalize gFrames[b].Transform.row3)
                    newBone.name = gFrames[b].Name
                    newBone.width  = 0.01
                    newBone.height = 0.01
                    newBone.transform = gFrames[b].Transform
                    newBone.setBoneEnable false 0
                    newBone.wirecolor = yellow
                    newbone.showlinks = true
                    newBone.pos.controller      = TCB_position ()
                    newBone.rotation.controller = TCB_rotation ()

        if (gFrames[b].Parent != -1) then newBone.parent = gMaxBoneArray[(gFrames[b].Parent+1)]
                              
        local curNodeInfo = undefined
        for nodeInfo in gHAnimNodeInfoArray do
        (
            if ( nodeInfo.FrameIndex == b ) then
            (
                curNodeInfo = nodeInfo
                exit
            )
        )
        
        if ( curNodeInfo != undefined ) then
        (
            SetUserProp newBone "NameId" ( curNodeInfo.NameId as string )
            SetUserProp newBone "Index" ( curNodeInfo.Index as string )
        )
        
        SetUserProp newBone "FrameIndex" ( b as string )
                              
        append gMaxBoneArray newBone
    )
)

fn BuildMeshes =
(
    for x = 1 to gAtomics.count do
    (
        local geometryIndex = gAtomics[x].GeometryIndex;
        local geometry = gGeometryDataArray[geometryIndex];
        
        -- Build mesh
        local msh = mesh Vertices:geometry.Vertices Faces:geometry.Triangles
        msh.numTVerts = geometry.Vertices.count
        msh.name = gFileName + "_" + ( x as string )
        buildTVFaces msh
        for a = 1 to 1 do (for j = 1 to geometry.UvChannels[a].count do SetTVert msh j geometry.UvChannels[a][j])
        for j = 1 to geometry.Triangles.count do setTVFace msh j geometry.Triangles[j]
        for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
        for j = 1 to msh.numfaces do setFaceMatID msh j geometry.TriangleMaterialIds[j]
        
        if (gImportNormals) then
        (
            -- Set up geometry.Normals
            max modify mode
            select msh
            addmodifier msh (Edit_Normals ()) ui:off
            msh.Edit_Normals.MakeExplicit selection:#{1..geometry.Normals.count}
            EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
            EN_setNormal = msh.Edit_Normals.SetNormal
            normID = #{}

            for v = 1 to geometry.Normals.count do(
                free normID
                EN_convertVS #{v} &normID
                for id in normID do EN_setNormal id geometry.Normals[v]
            )
            maxOps.CollapseNodeTo msh 1 true -- Collapse the Edit Normals modifier
        )
        
        -- Set up vertex geometry.Colors
        setNumCPVVerts msh msh.numTVerts
        defaultVCFaces msh
        for j = 1 to geometry.Colors.count do setvertcolor msh j geometry.Colors[j]
        
        -- Set up materials
        local geometryMaterialNames = gMaterialListMaterialNames[geometryIndex];
        local geometryMaterialTextureNames = gMaterialListTextureNames[geometryIndex];
        
        msh.material = multimaterial numsubs:geometryMaterialTextureNames.count
        for j = 1 to msh.material.count do 
        (
            local pngFilePath = (gFilePath + gFileName + "_tex\\" + geometryMaterialTextureNames[j] as string + ".png");
            
            tm = Bitmaptexture filename:pngFilePath
            tm.alphasource = 0
            tm.monoOutput = 1
            msh.material.materialList[j].diffuseMap = tm
            
            local materialName = geometryMaterialNames[j];
            if ( materialName == undefined ) then
            (
                materialName = geometryMaterialTextureNames[j] as string;
            )
            
            msh.material.materialList[j].name = materialName;
            msh.material.materialList[j].showInViewport = true
        )
        
        -- Set up root bone
        local rootFrame = getNodeByName gFrames[(gAtomics[x].FrameIndex)].Name
        msh.transform = rootFrame.transform
        msh.backfaceCull = true
        resetxform msh
        maxOps.CollapseNode msh off
        if ( gGeometrySkins[x] == undefined AND gImportWeights ) then
        (
            max modify mode
            select msh
            skinMod = skin ()
            addModifier msh skinMod
            skinOps.addBone skinMod rootFrame 1 
            modPanel.setCurrentObject skinMod
        )
    )
)

fn ApplyWeights =
(
    for x = 1 to gGeometryCount do
	(
        if ( gGeometrySkins[x] == undefined ) then
        (
            continue;
        )
        
        max modify mode
        msh = getNodeByName (gFileName+"_"+x as string) exact:true
        select msh
        skinMod = skin ()
        addModifier msh skinMod
        
        for i = 1 to gGeometrySkins[x].UsedBoneCount do
        ( 
            local curNodeInfo = undefined
            for nodeInfo in gHAnimNodeInfoArray do
            (
                if ( nodeInfo.Index == i ) then
                (
                    curNodeInfo = nodeInfo
                    exit
                )
            )
            
            local maxBone = GetNodeByName ( "_" + curNodeInfo.NameId as string ) exact:true
            
            if i != gGeometrySkins[x].UsedBoneCount then 
                skinOps.addBone skinMod maxbone 0
            else
                skinOps.addBone skinMod maxbone 1
        )
        
        modPanel.setCurrentObject skinMod
        
        for i = 1 to (getnumverts msh) do 
        (
           w = gGeometrySkins[x].Weights[i]
           bi = #() --bone index array
           wv = #() --weight value array
           
           for j = 1 to w.boneids.count do
           (
              boneid = w.boneids[j]
              weight = w.weights[j]
              append bi boneid
              append wv weight
           )   
           
           skinOps.ReplaceVertexWeights skinMod i bi wv
        )
	)
)

fn ImportModelFile =
(
    local startTime = Timestamp() --get start time in milliseconds
    
    GC();
    GC();
    
    ClearListener();
    DisableSceneRedraw();
    
    try (
        ReadFile();
        BuildBones();
        BuildMeshes();
        
        if (gImportWeights) then
        (
            ApplyWeights();
        )
    ) catch ( Format "Error occured! %\n" (GetCurrentException()) )

    GC();
    GC();
    FClose gFileStream
    EnableSceneRedraw()

    Format ("Done! ("+((((Timestamp())-startTime)*0.001)as string)+" Seconds)\n")
)

fn Main =
(
    ClearListener();
    
    local openFileName = getOpenFileName \ 
        caption:"Open Model" \
        types:"Persona 3/4 Model (*.*)|*.*|*.*|*.*" \
        historyCategory:"AtlusRMD Object Presets"
    
    if ( openFileName != undefined ) then
    (    
        gFileStream = fopen openFileName "rb"
        gFileName = GetFilenameFile openFileName
        gFilePath = getFileNamePath openFileName
        gFileType = getFilenameType openFileName

        FSeek gFileStream 0 #seek_end
        gFileEnd = FTell( gFileStream )
        FSeek gFileStream 0 #seek_set
        
        ImportModelFile();
    )
    
    OK;
)

Main();
