
FileIn "Common.ms"
FileIn "MaxScriptExtensions\\Utils.ms"
FileIn "MaxScriptExtensions\\FileUtils.ms"
FileIn "MaxScriptExtensions\\FileStreamReader.ms"

struct ModelReader
(    
    private mReader     = undefined,
    private mBaseOffset = 0,
    
    --
    -- Function declarations
    --
    
    -- Returns array of ChunkObjectEntry
    public fn ReadModelFile filePath = (),
    
    private fn ReadOffset = (),
    
    private fn ReadChunkObject parent = (),
    private fn ReadChunkModel = (),
    private fn ReadChunkList size = (),
    
    -- Chunk reading functions
    private fn ReadNullChunk flags type = (),
    private fn ReadBlendAlphaChunk flags type = (),
    private fn ReadMipmapDAdjustChunk flags type = (),
    private fn ReadSpecularExponentChunk flags type = (),
    private fn ReadCachePolygonListChunk flags type = (),
    private fn ReadDrawPolygonListChunk flags type = (),
    private fn ReadTextureIdChunk flags type = (),
    private fn ReadMaterialChunk flags type = (),
    private fn ReadVertexChunk flags type = (),
    private fn ReadStripChunk flags type = (),
    private fn ReadEndChunk flags type = (),
    
    --
    -- Function definitions
    --
    
    public fn ReadModelFile filePath =
    (
        -- Set up reader
        mReader = FileStreamReader();
        mReader.SetFile filePath true;
        
        local entries = #();
        while ( true ) do
        (
            local entry = ChunkObjectEntry();
            entry.Id = mReader.ReadS32();
            
            local offset = ReadOffset();
            if ( offset != 0 ) then
            (
                mReader.PushPosition();
                mReader.SeekSet( offset );
                entry.Object = ReadChunkObject( undefined );
                mReader.PopPosition();
            )
            
            append entries entry;
            
            if ( entry.Id == -1 ) then
                exit;
        )
        
        entries;
    ),
    
    private fn ReadOffset = 
    (
        mReader.ReadU32() + mBaseOffset;
    ),
    
    private fn ReadChunkObject parent = 
    (
        local obj = ChunkObject();
        obj.Parent = parent;
        
        -- Extract flags
        local flags = mReader.ReadU32();
        obj.IgnoreTranslation   = bit.get flags 1
        obj.IgnoreRotation      = bit.get flags 2
        obj.IgnoreScale         = bit.get flags 3
        obj.Hide                = bit.get flags 4
        obj.IgnoreChildren      = bit.get flags 5
        obj.UseZXYRotation      = bit.get flags 6
        obj.Skip                = bit.get flags 7
        obj.SkipShape           = bit.get flags 8
        obj.Clip                = bit.get flags 9
        obj.HasModifier         = bit.get flags 10
        
        local modelOffset = ReadOffset();        
        obj.Translation = mReader.ReadVec3F32();
        
        -- Decode BAMS rotation to euler angles (degrees)
        local rotation = mReader.ReadVec3S32();
        obj.Rotation = [ AngleToDegrees( rotation.X ),
                         AngleToDegrees( rotation.Y ),
                         AngleToDegrees( rotation.Z ) ];
        
        obj.Scale = mReader.ReadVec3F32();
        
        -- Calculate local transform
        if ( not obj.IgnoreTranslation ) then
            obj.LocalTransform *= TransMatrix obj.Translation;
        
        if ( not obj.IgnoreRotation ) then
        (
            if ( not obj.UseZXYRotation ) then 
                obj.LocalTransform *= ( RotateXMatrix obj.Rotation.X * RotateYMatrix obj.Rotation.Y * RotateZMatrix obj.Rotation.Z );
            else 
                obj.LocalTransform *= ( RotateZMatrix obj.Rotation.Z * RotateYMatrix obj.Rotation.Y * RotateXMatrix obj.Rotation.X );
        )
        
        if ( not obj.IgnoreScale ) then
            obj.LocalTransform *= ScaleMatrix obj.Scale;
        
        -- Calculate world transform
        if ( parent != undefined ) then
        (
            obj.WorldTransform = obj.LocalTransform * parent.WorldTransform;
        )
        else
        (
            obj.WorldTransform = obj.LocalTransform;
        )
        
        local childOffset = ReadOffset();
        local siblingOffset = ReadOffset();
        
        if ( modelOffset != 0 ) then
        (
            mReader.SeekSet( modelOffset );
            obj.Model = ReadChunkModel();
        )
        
        if ( childOffset != 0 ) then
        (
            mReader.SeekSet( childOffset );
            obj.Child = ReadChunkObject( obj );
        )
        
        if ( siblingOffset != 0 ) then
        (
            mReader.SeekSet( siblingOffset );
            obj.Sibling = ReadChunkObject( parent );
        )      
        
        obj;
    ),
    
    private fn ReadChunkModel =
    (
        local model = ChunkModel();
        local vertexListOffset = ReadOffset();
        local polygonListOffset = ReadOffset();
        model.Center = mReader.ReadVec3F32();
        model.Radius = mReader.ReadF32();
        
        if ( vertexListOffset != 0 ) then
        (
            --Print( "Reading vertex list" );
            mReader.PushPosition();
            mReader.SeekSet( vertexListOffset );
            model.VertexList = ReadChunkList( 4 );
            mReader.PopPosition();
        )
        
        if ( polygonListOffset != 0 ) then
        (
            --Print( "Reading polygon list" );
            mReader.PushPosition();
            mReader.SeekSet( polygonListOffset );
            model.PolygonList = ReadChunkList( 2 );
            mReader.PopPosition();
        )
        
        model;
    ),
    
    private fn ReadChunkList size =
    (
        local chunks = #();
        
        while ( true ) do
        (
            local chunkHeader = 0;
            local chunkSize = 0;
            
            if ( size == 4 ) then
            (
                chunkSize = mReader.ReadU16();
            )
            
            local flags = mReader.ReadU8();
            local type = mReader.ReadU8();
            
            --Format "Reading chunk type % at %\n" (ChunkTypeToString(type)) (HexStr(mReader.GetPosition()))
            
            -- Create chunk
            local chunk = undefined;
            
            if ( type == ChunkType_Null ) then
            (
                chunk = ReadNullChunk flags type;
            )
            else if ( type == ChunkType_BlendAlpha ) then
            (
                chunk = ReadBlendAlphaChunk flags type;
            )
            else if ( type == ChunkType_MipmapDAdjust ) then
            (
                chunk = ReadMipmapDAdjustChunk flags type;
            )
            else if ( type == ChunkType_CachePolygonList ) then
            (
                chunk = ReadCachePolygonListChunk flags type;
            )
            else if ( type == ChunkType_DrawPolygonList ) then
            (
                chunk = ReadDrawPolygonListChunk flags type;
            )
            else if ( type == ChunkType_TextureId or type == ChunkType_TextureId2 ) then
            (
                chunk = ReadTextureIdChunk flags type;
            )
            else if ( type >= ChunkType_MaterialDiffuse and type <= ChunkType_MaterialDiffuseAmbientSpecular2 ) then
            (
                chunk = ReadMaterialChunk flags type;
            )
            else if ( type >= ChunkType_VertexSH and type <= ChunkType_VertexN32UF ) then
            (
                chunk = ReadVertexChunk flags type;
            )
            else if ( type >= ChunkType_Strip and type <= ChunkType_StripUVH2 ) then
            (
                chunk = ReadStripChunk flags type;
            )
            else if ( type == ChunkType_End ) then
            (
                chunk = ReadEndChunk flags type;
            )
            
            append chunks chunk;
            
            if ( type == ChunkType_End ) then
            (
                exit;
            )
        )
        
        chunks;
    ),
    
    private fn ReadNullChunk flags type = 
    (
        NullChunk();
    ),
    
    private fn ReadBlendAlphaChunk flags type =
    (
        BlendAlphaChunk(); -- Todo
    ),
    
    private fn ReadMipmapDAdjustChunk flags type =
    (
        MipmapDAdjustChunk(); -- Todo
    ),
    
    private fn ReadSpecularExponentChunk flags type =
    (
        SpecularExponentChunk(); -- Todo
    ),
    
    private fn ReadCachePolygonListChunk flags type =
    (
        local chunk = CachePolygonListChunk();
        chunk.CacheIndex = flags + 1;
        chunk;
    ),
    
    private fn ReadDrawPolygonListChunk flags type =
    (
        local chunk = DrawPolygonListChunk();
        chunk.CacheIndex = flags + 1;
        chunk;
    ),
    
    private fn ReadTextureIdChunk flags type =
    (
        -- Todo
        local chunk = TextureIdChunk(); 
        chunk.Type = type;
        local packed = mReader.ReadU16();
        chunk;
    ),
    
    private fn ReadMaterialChunk flags type =
    (
        -- Todo: decode flags
        local chunk = MaterialChunk();
        chunk.Type = type;
        local size = mReader.ReadU16() * 2;
        local endOffset = mReader.GetPosition() + size;
        
        if ( size >= 4 and (
             type == ChunkType_MaterialDiffuse                   or type == ChunkType_MaterialDiffuse2                  or
             type == ChunkType_MaterialDiffuseAmbient            or type == ChunkType_MaterialDiffuseAmbient2           or
             type == ChunkType_MaterialDiffuseSpecular           or type == ChunkType_MaterialDiffuseSpecular2          or
             type == ChunkType_MaterialDiffuseAmbientSpecular    or type == ChunkType_MaterialDiffuseAmbientSpecular2 ) ) then
        (
            chunk.Diffuse = mReader.ReadU32();
        )
        
        size -= 4;
        
        if ( size >= 4 and (
             type == ChunkType_MaterialAmbient                   or type == ChunkType_MaterialAmbient2                 or
             type == ChunkType_MaterialDiffuseAmbient            or type == ChunkType_MaterialDiffuseAmbient2          or
             type == ChunkType_MaterialAmbientSpecular           or type == ChunkType_MaterialAmbientSpecular2         or
             type == ChunkType_MaterialDiffuseAmbientSpecular    or type == ChunkType_MaterialDiffuseAmbientSpecular ) ) then
        (
            chunk.Ambient = mReader.ReadU32();
        )
        
         size -= 4;
        
        if ( size >= 4 and (
             type == ChunkType_MaterialSpecular                  or type == ChunkType_MaterialSpecular2                or
             type == ChunkType_MaterialDiffuseSpecular           or type == ChunkType_MaterialDiffuseSpecular2         or
             type == ChunkType_MaterialAmbientSpecular           or type == ChunkType_MaterialAmbientSpecular2         or
             type == ChunkType_MaterialDiffuseAmbientSpecular    or type == ChunkType_MaterialDiffuseAmbientSpecular ) ) then
        (
            chunk.Specular = mReader.ReadU32();
        )
        
        if ( type == ChunkType_MaterialBump ) then
        (
            chunk.DX = mReader.ReadU16();
            chunk.DY = mReader.ReadU16();
            chunk.DZ = mReader.ReadU16();
            chunk.UX = mReader.ReadU16();
            chunk.UY = mReader.ReadU16();
            chunk.UZ = mReader.ReadU16();
        )
        
        mReader.SeekSet( endOffset );
        
        chunk;
    ),
    
    private fn ReadVertexChunk flags type =
    (
        local chunk = VertexChunk();
        chunk.Type = type;
        
        local vertexCount = mReader.ReadU16();
        chunk.IndexOffset = mReader.ReadU16();
        
        for i = 1 to vertexCount do
        (
            local vtx = Vertex();
            vtx.Position = mReader.ReadVec3F32();
            
            if ( type == ChunkType_VertexSH ) then
            (
                vtx.Position.Z = mReader.ReadF32();
            )
            else if ( type == ChunkType_VertexNSH ) then
            (
                vtx.Position.Z = mReader.ReadF32();
                vtx.Normal = mReader.ReadVec4F32();
            )
            else if ( type == ChunkType_VertexD8888 ) then
            (
                vtx.Diffuse = mReader.ReadU32();
            )
            else if ( type == ChunkType_VertexUF32 ) then
            (
                vtx.UserFlags = mReader.ReadU32();
            )
            else if ( type == ChunkType_VertexNF32 ) then
            (
                vtx.NinjaFlags = mReader.ReadU32();
            )
            else if ( type == ChunkType_VertexD565S565 ) then
            (
                vtx.Diffuse = mReader.ReadU16();
                vtx.Specular = mReader.ReadU16();
            )
            else if ( type == ChunkType_VertexD4444S565 ) then
            (
                vtx.Diffuse = mReader.ReadU16();
                vtx.Specular = mReader.ReadU16();
            )
            else if ( type == ChunkType_VertexD16S16 ) then
            (
                vtx.Diffuse = mReader.ReadU16();
                vtx.Specular = mReader.ReadU16();
            )
            else if ( type == ChunkType_VertexN ) then
            (
                vtx.Normal = mReader.ReadVec3F32();
            )
            else if ( type == ChunkType_VertexND8888 ) then
            (
                vtx.Normal = mReader.ReadVec3F32();
                vtx.Diffuse = mReader.ReadU32();
            )
            else if ( type == ChunkType_VertexNUF32 ) then
            (
                vtx.Normal = mReader.ReadVec3F32();
                vtx.UserFlags = mReader.ReadU32();
            )
            else if ( type == ChunkType_VertexNNF32 ) then
            (
                vtx.Normal = mReader.ReadVec3F32();
                vtx.NinjaFlags = mReader.ReadU32();
            )
            else if ( type == ChunkType_VertexND565S565 ) then
            (
                vtx.Normal = mReader.ReadVec3F32();
                vtx.Diffuse = mReader.ReadU16();
                vtx.Specular = mReader.ReadU16();
            )
            else if ( type == ChunkType_VertexND4444S565 ) then
            (
                vtx.Normal = mReader.ReadVec3F32();
                vtx.Diffuse = mReader.ReadU16();
                vtx.Specular = mReader.ReadU16();
            )
            else if ( type == ChunkType_VertexND16S16 ) then
            (
                vtx.Normal = mReader.ReadVec3F32();
                vtx.Diffuse = mReader.ReadU16();
                vtx.Specular = mReader.ReadU16();
            )
            else if ( type == ChunkType_VertexN32 ) then
            (
                -- Todo: decode 2:10:10:10 normal
                local normal = mReader.ReadU32();
            )
            else if ( type == ChunkType_VertexN32D8888 ) then
            (
                -- Todo: decode 2:10:10:10 normal
                local normal = mReader.ReadU32();
                vtx.Diffuse = mReader.ReadU32();
            )
            else if ( type == ChunkType_VertexN32UF ) then
            (
                -- Todo: decode 2:10:10:10 normal
                local normal = mReader.ReadU32();
                vtx.UserFlags = mReader.ReadU32();
            )
        
            append chunk.Vertices vtx;
        )
        
        chunk;
    ),
    
    private fn ReadStripChunk flags type =
    (
        local chunk = StripChunk();
        chunk.Type = type;
        
        local size = mReader.ReadU16();
        
        local stripFlags = mReader.ReadU16();
        local stripCount = bit.and stripFlags 0x3FFF;
        chunk.UserOffset = bit.shift ( bit.and stripFlags 0xC000 ) -14;
        
        for i = 1 to stripCount do
        (
            local curStrip = Strip();
            
            local indexCount = mReader.ReadS16();
            
            -- Strip initial winding order
            local clockwise = true;
            if ( indexCount < 0 ) then
            (
                clockwise = false;
                indexCount = -indexCount;
            )
            
            curStrip.Clockwise = clockwise;
            for j = 1 to indexCount do
            (
                local index = VertexIndex();
                index.Index = mReader.ReadU16() + 1;
                
                if ( type == ChunkType_StripUVN      or type == ChunkType_StripUVH   or 
                     type == ChunkType_StripUVNVN    or type == ChunkType_StripUVHVN or 
                     type == ChunkType_StripUVNVN    or type == ChunkType_StripUVHVN or 
                     type == ChunkType_StripUVN2     or type == ChunkType_StripUVH2 ) then
                (
                    index.UV1 = [ mReader.ReadU16() as float / 255f, mReader.ReadU16() as float / 255f ];
                )
                
                if ( type == ChunkType_StripUVN2 or type == ChunkType_StripUVH2 ) then
                (
                    index.UV2 = [ mReader.ReadU16() as float / 255f, mReader.ReadU16() as float / 255f ];
                )
                
                if ( type == ChunkType_StripD8 ) then
                (
                    index.Color = mReader.ReadU32();
                )
                
                if ( type == ChunkType_StripVN or type == ChunkType_StripUVNVN or type == ChunkType_StripUVHVN ) then
                (
                    index.Normals = mReader.ReadVec3U16();
                )
                
                if ( j > 2 ) then
                (
                    for k = 1 to chunk.UserOffset do
                    (
                        append index.UserFlags mReader.ReadU16();
                    )
                )
                
                append curStrip.Indices index;
            )
            
            append chunk.Strips curStrip;
        )
        
        chunk;
    ),
    
    private fn ReadEndChunk flags type =
    (
        EndChunk();
    )
)