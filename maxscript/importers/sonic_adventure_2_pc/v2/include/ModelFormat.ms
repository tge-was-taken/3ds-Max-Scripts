
--
-- Model
--

-- enum WeightStatusFlag
WeightStatus_Start  = Bit_0;
WeightStatus_Middle = Bit_1;
WeightStatus_End    = Bit_2;

--- enum ChunkType
ChunkType_Null                              = 00; -- 'Null' chunk, for padding
ChunkType_BlendAlpha                        = 01; -- 'Bits' chunks
ChunkType_MipmapDAdjust                     = 02;
ChunkType_SpecularExponent                  = 03;
ChunkType_CachePolygonList                  = 04;
ChunkType_DrawPolygonList                   = 05;
ChunkType_TextureId                         = 08; -- 'Tiny' chunks
ChunkType_TextureId2                        = 09;
ChunkType_MaterialDiffuse                   = 17; -- 'Material' chunks
ChunkType_MaterialAmbient                   = 18;
ChunkType_MaterialDiffuseAmbient            = 19;
ChunkType_MaterialSpecular                  = 20;
ChunkType_MaterialDiffuseSpecular           = 21;
ChunkType_MaterialAmbientSpecular           = 22;
ChunkType_MaterialDiffuseAmbientSpecular    = 23;
ChunkType_MaterialBump                      = 24;
ChunkType_MaterialDiffuse2                  = 25;
ChunkType_MaterialAmbient2                  = 26;
ChunkType_MaterialDiffuseAmbient2           = 27;
ChunkType_MaterialSpecular2                 = 28;
ChunkType_MaterialDiffuseSpecular2          = 29;
ChunkType_MaterialAmbientSpecular2          = 30;
ChunkType_MaterialDiffuseAmbientSpecular2   = 31;
ChunkType_VertexSH                          = 32; -- 'Vertex' chunks
ChunkType_VertexNSH                         = 33;
ChunkType_Vertex                            = 34;
ChunkType_VertexD8888                       = 35;
ChunkType_VertexUF32                        = 36;
ChunkType_VertexNF32                        = 37;
ChunkType_VertexD565S565                    = 38;
ChunkType_VertexD4444S565                   = 39;
ChunkType_VertexD16S16                      = 40;
ChunkType_VertexN                           = 41;
ChunkType_VertexND8888                      = 42;
ChunkType_VertexNUF32                       = 43;
ChunkType_VertexNNF32                       = 44;
ChunkType_VertexND565S565                   = 45;
ChunkType_VertexND4444S565                  = 46;
ChunkType_VertexND16S16                     = 47;
ChunkType_VertexN32                         = 48;
ChunkType_VertexN32D8888                    = 49;
ChunkType_VertexN32UF                       = 50;
ChunkType_VolumePolygon3                    = 54; -- 'Volume' chunks
ChunkType_VolumePolygon4                    = 55;
ChunkType_VolumeTristrip                    = 56;
ChunkType_Strip                             = 64; -- 'Strip' chunks
ChunkType_StripUVN                          = 65;
ChunkType_StripUVH                          = 66;
ChunkType_StripVN                           = 67;
ChunkType_StripUVNVN                        = 68;
ChunkType_StripUVHVN                        = 69;
ChunkType_StripD8                           = 70;
ChunkType_StripUVND8                        = 71;
ChunkType_StripUVHD8                        = 72;
ChunkType_Strip2                            = 73;
ChunkType_StripUVN2                         = 74;
ChunkType_StripUVH2                         = 75;
ChunkType_End                               = 255; -- End chunk, chunk list terminator

fn ChunkTypeToString value =
(
    case ( value ) of
    (
        0: "ChunkType_Null";
        1: "ChunkType_BlendAlpha";
        2: "ChunkType_MipmapDAdjust";
        3: "ChunkType_SpecularExponent";
        4: "ChunkType_CachePolygonList";
        5: "ChunkType_DrawPolygonList";
        8: "ChunkType_TextureId";
        9: "ChunkType_TextureId2";
        17: "ChunkType_MaterialDiffuse";
        18: "ChunkType_MaterialAmbient";
        19: "ChunkType_MaterialDiffuseAmbient";
        20: "ChunkType_MaterialSpecular";
        21: "ChunkType_MaterialDiffuseSpecular";
        22: "ChunkType_MaterialAmbientSpecular";
        23: "ChunkType_MaterialDiffuseAmbientSpecular";
        24: "ChunkType_MaterialBump";
        25: "ChunkType_MaterialDiffuse2";
        26: "ChunkType_MaterialAmbient2";
        27: "ChunkType_MaterialDiffuseAmbient2";
        28: "ChunkType_MaterialSpecular2";
        29: "ChunkType_MaterialDiffuseSpecular2";
        30: "ChunkType_MaterialAmbientSpecular2";
        31: "ChunkType_MaterialDiffuseAmbientSpecular2";
        32: "ChunkType_VertexSH";
        33: "ChunkType_VertexNSH";
        34: "ChunkType_Vertex";
        35: "ChunkType_VertexD8888";
        36: "ChunkType_VertexUF32";
        37: "ChunkType_VertexNF32";
        38: "ChunkType_VertexD565S565";
        39: "ChunkType_VertexD4444S565";
        40: "ChunkType_VertexD16S16";
        41: "ChunkType_VertexN";
        42: "ChunkType_VertexND8888";
        43: "ChunkType_VertexNUF32";
        44: "ChunkType_VertexNNF32";
        45: "ChunkType_VertexND565S565";
        46: "ChunkType_VertexND4444S565";
        47: "ChunkType_VertexND16S16";
        48: "ChunkType_VertexN32";
        49: "ChunkType_VertexN32D8888";
        50: "ChunkType_VertexN32UF";
        54: "ChunkType_VolumePolygon3";
        55: "ChunkType_VolumePolygon4";
        56: "ChunkType_VolumeTristrip";
        64: "ChunkType_Strip";
        65: "ChunkType_StripUVN";
        67: "ChunkType_StripUVH";
        68: "ChunkType_StripVN";
        69: "ChunkType_StripUVNVN";
        70: "ChunkType_StripUVHVN";
        71: "ChunkType_StripD8";
        72: "ChunkType_StripUVND8";
        73: "ChunkType_StripUVHD8";
        74: "ChunkType_Strip2";
        75: "ChunkType_StripUVN2";
        76: "ChunkType_StripUVH2";
        255: "ChunkType_End";
        default: value as string;
    )
)

struct ChunkObjectEntry
(
    Id     = 0,
    Object = undefined  -- ChunkObject
)

struct ChunkObject
(
    Parent              = undefined,    -- ChunkObject
    IgnoreTranslation   = false,
    IgnoreRotation      = false,
    IgnoreScale         = true,
    Hide                = false,
    IgnoreChildren      = false,
    UseZXYRotation      = false,
    Skip                = false,
    SkipShape           = false,
    Clip                = false,
    HasModifier         = false,
    Model               = undefined,    -- ChunkModel
    Translation         = [ 0, 0, 0 ],
    Rotation            = [ 0, 0, 0 ],
    Scale               = [ 1, 1, 1 ],
    Child               = undefined,    -- ChunkObject
    Sibling             = undefined,    -- ChunkObject
    
    LocalTransform      = Matrix3 1,
    WorldTransform      = Matrix3 1,
    Bone
)

struct ChunkModel
(
    VertexList  = #(),          -- Chunk[]
    PolygonList = #(),          -- Chunk[]
    Center      = [ 0, 0, 0 ],
    Radius      = 0f
)

-- Chunk definitions
struct NullChunk
(
    Type = ChunkType_Null
)

struct BlendAlphaChunk
(
    Type     = ChunkType_BlendAlpha, 
    SrcAlpha = 0,                       -- 3 bits
    DstAlpha = 0                        -- 3 bits
)

struct MipmapDAdjustChunk
(
    Type    = ChunkType_MipmapDAdjust,
    DAdjust = 0                         -- 4 bits
)

struct SpecularExponentChunk
(
    Type        = ChunkType_SpecularExponent,
    Exponent    = 0                            -- 5 bits
)

struct CachePolygonListChunk
(
    Type        = ChunkType_CachePolygonList,
    CacheIndex  = 0                            -- u8
)

struct DrawPolygonListChunk
(
    Type        = ChunkType_DrawPolygonList,
    CacheIndex  = 0                            -- u8
)

struct TextureIdChunk
(
    Type            = ChunkType_TextureId,
    MipmapDAdjust   = 0,                        -- 4 bits
    ClampUV         = 0,                        -- 2 bits
    FlipUV          = 0,                        -- 2 bits
    Id              = 0,                        -- 13 bits
    FilterMode      = 0,                        -- 2 bits
    SuperSample     = 0                         -- 1 bit
)

struct MaterialChunk
(
    Type            = ChunkType_MaterialDiffuseAmbientSpecular,    
    SrcAlpha        = 0,                            -- 3 bits
    DstAlpha        = 0,                            -- 3 bits
    Size            = 12,                           -- u16
    Diffuse         = 0xFFFFFFFF,                   -- ARGB
    Ambient         = 0xFFFFFFFF,                   -- NRGB
    Specular        = 0,                            -- ERGB
    DX              = 0,                            -- u16                    
    DY              = 0,                            -- u16
    DZ              = 0,                            -- u16
    UX              = 0,                            -- u16
    UY              = 0,                            -- u16
    UZ              = 0                             -- u16
)

struct VertexChunk
(
    Type            = ChunkType_VertexND8888,
    Size            = 0,                        -- u16
    ContinueFlag    = 0,                        -- 1 bit
    WeightStatus    = 0,                        -- 2 bits, enum WeightStatusFlag
    IndexOffset     = 0,                        -- u16
    Vertices        = #()                       -- Vertex[VertexCount]
)

struct Vertex
(
    Position    = [ 0f, 0f, 0f, 1f ],   -- Vector3, or Vector4
    Normal      = [ 0f, 0f, 0f, 0f ],   -- Vector3, or Vector4
    Diffuse     = 0xFFFFFFFF,           -- ARGB; 8888, 565 or 4444
    Specular    = 0xFFFFFFFF,           -- ARGB; 8888, 565 or 4444
    UserFlags   = 0,
    NinjaFlags  = 0
)

struct StripChunk
(
    Type                = ChunkType_StripUVND8,
    IgnoreLight         = false,
    IgnoreSpecular      = false,
    IgnoreAmbient       = false,
    UseAlpha            = true,
    IsDoubleSided       = false,
    UseFlatShading      = false,
    IsEnvironment       = false,
    UserOffset          = 0,
    Strips              = #()                       -- max. 16383 strips
)

struct Strip
(
    Clockwise           = true,
    Indices             = #()  -- VertexIndex[]
)

struct VertexIndex
(
    Index       = 0,
    UV1         = [ 0, 0 ],
    UV2         = [ 0, 0 ],
    Color       = 0xFFFFFFFF,
    Normals     = [ 0, 0, 0 ],
    UserFlags   = #()
)

struct EndChunk
(
    Type = ChunkType_End
)
