

function InitList count =
(
    list = #();
    list[count - 1] = undefined;
    list;
)

global gIOStream = undefined;

function IOOpenFile path mode =
(
    gIOStream = fopen path mode;
)

function IOTell =
(
    ftell gIOStream;
)

function IOClose =
(
    fclose gIOStream;
    gIOStream = undefined;
)

function IOSeekBegin offset =
(
    FSeek gIOStream offset #seek_set; 
)

function IOSeekCurrent offset =
(
    FSeek gIOStream offset #seek_cur; 
)

function IOReadByte =
(
    ReadByte gIOStream #unsigned;
)

function IOReadBytes count =
(
    local values = InitList( count );
    for i = 1 to count do
        values[i] = IOReadByte();
    
    values
)

function IOReadInt16 =
(
    ReadShort gIOStream;
)

function IOReadUInt16 =
(
    ReadShort gIOStream #unsigned;
)

function IOReadUInt16s count =
(
    local values = InitList( count );
    for i = 1 to count do
        values[i] = IOReadUInt16();
    
    values
)

function IOReadInt32 =
(
    ReadLong gIOStream;
)

function IOReadUInt32 =
(
    ReadLong gIOStream #unsigned;
)

function IOReadFloat =
(
    ReadFloat gIOStream;
)

function IOReadVector3 =
(
    [ IOReadFloat(), IOReadFloat(), IOReadFloat() ]
)

struct MapFile
(
    Unknown1,
    Unknown2,
    Unknown3,
    BlocksSize,
    Blocks,
    Extents,
    AreasSize,
    Areas,
    Unknown6
)

struct MapUnknown3Entry
(
    Field00,
    Field01,
    Field02,
    Field03,
    Field04,
    Field05
)

struct MapBlock
(
    ModelIndex,
    XOffset,
    YOffset,
    ZOffset,
    Field05,
    Field06,
    Field07
)

struct MapExtents
(
    MinExtents,
    MaxExtents,
    Field18
)

struct MapArea
(
    PreviousIndex,
    NextIndex,
    LeftIndex,
    RightIndex,
    Field08,
    Field0C,
    Field10,
    Field14,
    Field18,
    Field1C,
    Field20,
    Field24,
    Field28,
    Field2C,
    Field30,
    Field32,
    Field34,
    Field36,
    Position,
    Field44,
    Field48,
    Field4A,
    Field4C,
    BlockCount,
    BlockStartIndex,
    Field52,
    Field54
)

function ReadMapFile path =
(
    IOOpenFile path "rb"
    
    local map = MapFile();
    map.Unknown1 = IOReadInt32();
    map.Unknown2 = IOReadUInt16s( map.Unknown1 );
    
    map.Unknown3 = InitList( map.Unknown1 );
    for i = 1 to map.Unknown1 do
    (
        local entry = MapUnknown3Entry();
        entry.Field00 = IOReadByte();
        entry.Field01 = IOReadByte();
        entry.Field02 = IOReadByte();
        entry.Field03 = IOReadByte();
        entry.Field04 = IOReadByte();
        entry.Field05 = IOReadByte();
        map.Unknown3[i] = entry;
    )
    
    map.BlocksSize = IOReadUInt32();
    local blockCount = ( map.BlocksSize / 8 );
    map.Blocks = InitList( blockCount );
    for i = 1 to blockCount do
    (
        local block = MapBlock();
        block.ModelIndex = IOReadUInt16();
        block.XOffset = IOReadByte();
        block.YOffset = IOReadByte();
        block.ZOffset = IOReadByte();
        block.Field05 = IOReadByte();
        block.Field06 = IOReadByte();
        block.Field07 = IOReadByte();
        map.Blocks[i] = block;
    )
    
    map.Extents = MapExtents();
    map.Extents.MinExtents = IOReadVector3();
    map.Extents.MaxExtents = IOReadVector3();
    map.Extents.Field18 = IOReadFloat();
    
    map.AreasSize = IOReadUInt32();
    local areaCount = ( map.AreasSize / 88 );
    map.Areas = InitList( areaCount );
    for i = 1 to areaCount do
    (
        local area = MapArea();
        area.PreviousIndex = IOReadUInt16();
        area.NextIndex = IOReadUInt16();
        area.LeftIndex = IOReadUInt16();
        area.RightIndex = IOReadUInt16();
        area.Field08 = IOReadFloat();
        area.Field0C = IOReadFloat();
        area.Field10 = IOReadFloat();
        area.Field14 = IOReadFloat();
        area.Field18 = IOReadFloat();
        area.Field1C = IOReadFloat();
        area.Field20 = IOReadFloat();
        area.Field24 = IOReadFloat();
        area.Field28 = IOReadFloat();
        area.Field2C = IOReadFloat();
        area.Field30 = IOReadInt16();
        area.Field32 = IOReadInt16();
        area.Field34 = IOReadInt16();
        area.Field36 = IOReadInt16();
        area.Position = IOReadVector3();
        area.Field44 = IOReadUInt32();
        area.Field48 = IOReadInt16();
        area.Field4A = IOReadInt16();
        area.Field4C = IOReadInt16();
        area.BlockCount = IOReadInt16();
        area.BlockStartIndex = IOReadInt16();
        area.Field52 = IOReadInt16();
        area.Field54 = IOReadInt32();
        map.Areas[i] = area;
    )
    
    map;
)

struct KeyValuePair
(
    Key,
    Value
)

function CompareKvpIntegerKey l r =
(
    case of
    (
        ( l.Key < r.Key ): -1
        ( l.Key > r.Key ): 1
        default: 0
    )
)

function FindMapBlocksInScene =
(
    local objs = #();
    
    for o in objects do
    (
        local blockId = substring o.Name 1 3 as Integer;
        if ( blockId == undefined ) then continue;
        append objs ( KeyValuePair Key:blockId Value:o )
    )
    
    qsort objs CompareKvpIntegerKey
    
    objs;
)

function Vector3YToZUp value =
(
    local newValue = value;
    newValue.Y = -value.Z;
    newValue.Z = value.Y;
    newValue;
)

function InstanceObject obj =
(
    local blockModelCopy = undefined;
    maxOps.cloneNodes obj cloneType:#instance newNodes:&blockModelCopy;
    blockModelCopy;
)

function Main =
(
    local blockModels = FindMapBlocksInScene();
    if ( blockModels.Count == 0 ) then
        throw "No block models in scene"
    
    local map = ReadMapFile( @"D:\Users\smart\Downloads\Sonic_Generations_USA_romfs\TARGET\GAME\BG\Z12_MAP\Z12MAP.BIN" );
    
    for areaIndex = 1 to map.Areas.Count do
    (
        local area = map.Areas[ areaIndex ];
        local areaDummy = Dummy name:("Area" + areaIndex as string ) pos:area.Position;
        
        for blockIndex = 1 to area.BlockCount do
        (
            local absBlockIndex = area.BlockStartIndex + blockIndex;
            local block = map.Blocks[absBlockIndex];
            
            -- Calculate absolute block position
            local blockPosition = area.Position + [ block.XOffset, block.YOffset, block.ZOffset ];
            --blockPosition = Vector3YToZUp( blockPosition );
            
            -- Clone block model
            if ( block.ModelIndex < blockModels.Count ) then
            (
                local blockModel = blockModels[ block.ModelIndex + 1 ];
                local blockModelCopy = InstanceObject blockModel.Value;
                
                -- Configure block model
                blockModelCopy.Name = "Block" + ( absBlockIndex as string );
                rotate blockModelCopy (angleaxis -90 [1,0,0])
                blockModelCopy.Pos = blockPosition;
                unhide blockModelCopy
                
--                 if ( block.Field05 == 255 ) then
--                 (
--                     -- Make mirrored copy of model
--                     local blockModelCopy2 = InstanceObject( blockModelCopy );
--                     blockModelCopy2.Name += "Mirrored";
--                     toolMode.coordsys #local
--                     rotate blockModelCopy2 (angleaxis 180 [0,1,0])
--                     move blockModelCopy2 [0,0,-40]
--                     move blockModelCopy2 [80,0,0]
--                 )
                
                blockModelCopy.Parent = areaDummy;
            )
            else
            (
                print( "Block " + absBlockIndex as string + " referenced model " + block.ModelIndex as string + " which does not exist" );
            )
        )
    )
    
    OK
)

ClearListener();
Main();