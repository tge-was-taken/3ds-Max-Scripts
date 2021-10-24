
FileIn "MaxScriptExtensions\\Utils.ms"
FileIn "MaxScriptExtensions\\FileUtils.ms"
FileIn "MaxScriptExtensions\\FileStreamReader.ms"

FileIn "ModelFormat.ms"
FileIn "ModelReader.ms"
FileIn "AnimationFormat.ms"
FileIn "AnimationReader.ms"

struct ModelLoader
(
    public ModelEntries = #(),
    public AnimationEntries = #(),
    public AnimationSpeed = 1.0f,
    
    private mVertexPositions = #(),
    private mTriangles = #(),
    private mPolygonListCache = #(),
    private mDepthLevel = 0,
    private mObjectIndex = 0,
    private mVertexIdToBoneLookup = #(),
    private mWeights = #(),
    
    -- Function declarations
    public fn LoadModelFile filePath = (),
    public fn ImportObjectById id = (),
    public fn ImportObjectByIndex index = (),
    public fn ImportAllObjects = (),
    public fn ImportMainObject = (),
    
    public fn LoadAnimationFile filePath = (),
    public fn LoadAnimationById id = (),
    public fn LoadAnimationByIndex index = (),
    
    private fn FormatDepth = #(),
    
    private fn ImportObject obj = (),
    private fn SetupObject obj = (),
    private fn SetupObjectBone obj = (),
    private fn SetupChunkModel bone model = (),
    private fn InitializeVertexCache = (),
    private fn InitializePolygonListCache = (),
    private fn ProcessPolygonList polygonList index  = (),
    
    private fn LoadAnimation anim = (),
    
    -- Function definitions
    public fn LoadModelFile filePath =
    (
        local reader = ModelReader();
        ModelEntries = reader.ReadModelFile( filePath );
    ),
    
    public fn ImportObjectById id =
    (
        for entry in ModelEntries do
        (
            if ( entry.Id == id and entry.Object != undefined ) then
            (
                ImportObject( entry.Object );
                return true;
            )
        )
        
        return false;
    ),
    
    public fn ImportObjectByIndex index =
    (
        local entry = ModelEntries[ index ];
        if ( entry.Object != undefined ) then
        (
            ImportObject( entry.Object );
            return true;
        )
        
        return false;
    ),
    
    public fn ImportAllObjects =
    (
        for entry in ModelEntries do
        (
            if ( entry.Object != undefined ) then
            (
                ImportObject( entry.Object );
                --return true;
            )
        )
        
        true;
    ),
    
    public fn ImportMainObject =
    (
        local lowestId = 0xFFFF;
        for entry in ModelEntries do
        (
            if ( entry.Id != -1 and entry.Id < lowestId ) then
                lowestId = entry.Id;
        )
        
        return ImportObjectById( lowestId );
    ),
    
    public fn LoadAnimationFile filePath = 
    (
        local reader = AnimationReader();
        AnimationEntries = reader.ReadAnimationFile( filePath );
    ),
    
    public fn ImportAnimationById id =
    (
        for entry in AnimationEntries do
        (
            if ( entry.Id == id and entry.Animation != undefined ) then
            (
                LoadAnimation( entry.Animation );
                return true;
            )
        )
        
        return false;
    ),
    
    public fn LoadAnimationByIndex index =
    (
        local entry = AnimationEntries[ index ];
        if ( entry != undefined and entry.Animation != undefined ) then
        (
            LoadAnimation( entry.Animation );
            return true;
        )
        
        return false;
    ),
    
    private fn FormatDepth =
    (
        for i = 1 to mDepthLevel do
            Format "-";
    ),
    
    private fn ImportObject obj =
    (
        InitializeVertexCache();
        mTriangles = #();
        mVertexIdToBoneLookup = #();
        mWeights = #();
        InitializePolygonListCache();
        SetupObject( obj );
    ),
    
    private fn SetupObject obj = 
    (
        mObjectIndex += 1;
        
        FormatDepth();
        Format "%\n" mObjectIndex;
        
        local curObj = obj;
        while ( curObj != undefined ) do
        (
            curObj.Bone = SetupObjectBone( curObj );
            
            if ( curObj.Model != undefined ) then
            (
                local model = curObj.Model;
                for chunk in model.VertexList do
                (
                    if ( chunk.Type != ChunkType_VertexNNF32 ) then
                        continue;
                    
                    for i = 1 to chunk.Vertices.Count do
                    (
                        local vertexId = i + chunk.IndexOffset;
                        mVertexIdToBoneLookup[ vertexId ] = mObjectIndex;
                    )
                )
            )
            
            if ( curObj.Child != undefined ) then
            (
                -- Set up child
                mDepthLevel += 1;
                SetupObject( curObj.Child );
                mDepthLevel -= 1;
            )
            
            curObj = curObj.Sibling;
        )
        
        local curObj = obj;
        while ( curObj != undefined ) do
        (
            if ( curObj.Model != undefined and not curObj.Hide ) then
            (
                SetupChunkModel curObj.Bone curObj.Model;
            )
            
            if ( curObj.Child != undefined ) then
            (
                SetupObject( curObj.Child );
            )
            
            curObj = curObj.Sibling;
        )
    ),
    
    private fn SetupObjectBone obj =
    (
        local tfm = obj.WorldTransform;
        local newBone = BoneSys.CreateBone tfm.row4 (tfm.row4 + 0.01 * (normalize tfm.row1)) (normalize tfm.row3);
        --newBone.Name = gfdNode.Name;
        newBone.Width  = 0.01;
        newBone.Height = 0.01;
        newBone.Transform = tfm;
        newBone.SetBoneEnable false 0;
        newBone.Wirecolor = yellow;
        newBone.Showlinks = true;
        newBone.Pos.Controller      = TCB_position();
        newBone.Rotation.Controller = TCB_rotation();
                          
        if ( obj.Parent != undefined ) do 
            newBone.Parent = obj.Parent.Bone;
        
        newBone;
    ),

    private fn SetupChunkModel bone model =
    (        
        --print vertexPositions
        local isCached = false;
        ProcessPolygonList model.PolygonList 1 &isCached;
        
        local vertexCount = 0;
        for chunk in model.VertexList do
        (
            if ( chunk.Type == ChunkType_Null or chunk.Type == ChunkType_End ) then
                continue;
            
            Assert( ( chunk.Type >= ChunkType_VertexSH and chunk.Type <= ChunkType_VertexN32UF ) );
            
            for i = 1 to chunk.Vertices.Count do
            (
                local vertex = chunk.Vertices[ i ];
                local vertexIndex = chunk.IndexOffset + i;
                mVertexPositions[ vertexIndex ] = vertex.Position;
                --if ( not isCached ) then mVertexPositions[ vertexIndex ] *= bone.Transform;
                vertexCount += 1;
            )
        )
        
        if ( not isCached ) then
        (
--             for i = 1 to mVertexPositions.Count do
--                 mVertexPositions[i] *= bone.Transform;
            
            local msh = mesh vertices:mVertexPositions faces:mTriangles
            meshop.deleteisoverts msh;
            msh.Parent = bone;
            msh.Transform = bone.Transform;
            --free mVertexPositions;
            free mTriangles;
            
            --mTriangles = #();
        )
        
        true;
    ),
    
    private fn InitializeVertexCache =
    (
        mVertexPositions = #();
        for i = 1 to 4096 do
            mVertexPositions[ i ] = [ 0, 0, 0 ];
    ),
    
    private fn InitializePolygonListCache =
    (
        mPolygonListCache = #();
        for i = 1 to 175 do
            mPolygonListCache[ i ] = undefined;
    ),
    
    private fn ProcessPolygonList polygonList index &isCached =
    (
        isCached = false;
        
        if ( polygonList.Count == 0 ) then
            return true;
        
        if ( index > polygonList.Count ) then
        (
            FormatDepth();
            Format "ProcessPolygonList index out of range %\n" index;
            return false;
        )
        
        for i = index to polygonList.Count do
        (
            local chunk = polygonList[ i ];
            if ( chunk.Type == ChunkType_Null or chunk.Type == ChunkType_End ) then
                continue;
            
            Assert( ( chunk.Type == ChunkType_DrawPolygonList or chunk.Type == ChunkType_CachePolygonList ) or
                    ( chunk.Type == ChunkType_TextureId or chunk.Type == ChunkType_TextureId2 ) or
                    ( chunk.Type >= ChunkType_MaterialDiffuse and chunk.Type <= ChunkType_MaterialDiffuseAmbientSpecular2 ) or
                    ( chunk.Type >= ChunkType_Strip and chunk.Type <= ChunkType_StripUVH2 ) );
              
            if ( chunk.Type == ChunkType_CachePolygonList ) then
            (
                FormatDepth();
                Format "Caching polygon list to cache index %\n" chunk.CacheIndex;
                mPolygonListCache[ chunk.CacheIndex ] = #( polygonList, i + 1 );
                isCached = true;
                return true;
            )
            else if ( chunk.Type == ChunkType_DrawPolygonList ) then
            (
                local cachedPolygonList = mPolygonListCache[ chunk.CacheIndex ];

                if ( cachedPolygonList != undefined ) then
                (
                    FormatDepth();
                    Format "Drawing polygon list from cache index %\n" chunk.CacheIndex;
                    local cachedPolygonListIsCached = false;
                    ProcessPolygonList cachedPolygonList[1] cachedPolygonList[2] &cachedPolygonListIsCached;
                )
                else
                (
                    FormatDepth();
                    Format "Referenced undefined cached polygon list! %\n" chunk.CacheIndex;
                )
            )
            else if ( chunk.Type >= ChunkType_Strip and chunk.Type <= ChunkType_StripUVH2 ) then
            (
                -- Handle strips
                for strip in chunk.Strips do
                (
                    local clockwise = strip.Clockwise;
                    local a = strip.Indices[ 1 ];
                    local b = strip.Indices[ 2 ];
                    local triangleCount = strip.Indices.Count - 2;
                    for i = 1 to triangleCount do
                    (
                        local c = strip.Indices[ 2 + i ];
                        if ( clockwise ) then
                        (
                            append mTriangles [ a.Index, b.Index, c.Index ];
                        )
                        else
                        (
                            append mTriangles [ a.Index, c.Index, b.Index ];
                        )
                        
                        clockwise = not clockwise;
                        a = b;
                        b = c;
                    )
                )
            )
        )
        
        true;
    ),
    
    private fn TraverseNode curNode &nodes =
    (
        if ( classof( curNode ) == BoneGeometry ) then
        (
            append nodes curNode;
        
            for childNode in curNode.Children do
                TraverseNode childNode &nodes;
        )
    ),
    
    private fn GetAnimationNodes =
    (
        local nodes = #()
        local animRootNode = GetNodeByName( "Bone001" )
        TraverseNode animRootNode &nodes
        return nodes
    ),
    
    private fn LoadAnimation anim =
    (
        local nodes = GetAnimationNodes();
        
        animationRange = interval 0 ( anim.FrameCount * AnimationSpeed )
        
        with animate on
        (
            for i = 1 to anim.ObjectAnimations.Count do
            (
                local objAnim = anim.ObjectAnimations[ i ];
                local node = nodes[ i ];
                
                for kf in objAnim.Positions do
                (
                    at time ( kf.Time * AnimationSpeed )
                        node.Controller.Position = kf.Position;
                )
                
                for kf in objAnim.Rotations do
                (
                    at time ( kf.Time * AnimationSpeed )
                        node.Controller.Rotation = ( eulerAngles kf.Rotation.X kf.Rotation.Y kf.Rotation.Z ) as quat;
                )
                
                for kf in objAnim.Scales do
                (
                    at time ( kf.Time * AnimationSpeed )
                        node.Controller.Scale = kf.Scale;
                )
            )
        )
    )
)

