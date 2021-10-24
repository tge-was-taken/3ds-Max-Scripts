

function InitList count =
(
    list = #();
    list[count] = undefined;
    list;
)

global gIOStream = undefined;
global gIOFileSize = undefined;

function IOOpenFile path mode =
(
    gIOStream = fopen path mode;
    FSeek gIOStream 0 #seek_end;
    gIOFileSize = FTell gIOStream;
    FSeek gIOStream 0 #seek_set
)

function IOTell =
(
    ftell gIOStream;
)

function IOGetFileSize =
(
    gIOFileSize;
)

function IOIsEOF =
(
    FTell gIOStream >= gIOFileSize;
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

struct CollisionFile
(
    Lines = #()
)

struct CollisionLine
(
    KnotCount,
    InitialPosition,
    Knots = #()
)

struct CollisionKnot
(
    Direction,
    Position
)

function ReadCollisionFile path =
(
    IOOpenFile path "rb"
    
    local colFile = CollisionFile();
    while ( not IOIsEOF() ) do
    (
        local colLine = CollisionLine();
        colLine.KnotCount = IOReadUInt32();
        colLine.InitialPosition = IOReadVector3();
        
        colLine.Knots = InitList( colLine.KnotCount );
        for i = 1 to colLine.KnotCount do
        (
            local colPoint = CollisionKnot();
            colPoint.Direction = IOReadVector3();
            colPoint.Position = IOReadVector3();
            colLine.Knots[i] = colPoint;
        )
        
        append colFile.Lines colLine;
    )
    
    colFile;
)

function LoadCollision colFile =
(
    for lineIndex = 1 to colFile.Lines.Count do
    (
        local colLine = colFile.Lines[lineIndex];
        local lineShape = splineShape name:("Line" + lineIndex as string);
        AddNewSpline lineShape;
        AddKnot lineShape 1 #smooth #line colLine.InitialPosition;

        for pointIndex = 1 to colLine.Knots.Count do
        (
            local colPoint = colLine.Knots[pointIndex];
            AddKnot lineShape 1 #smooth #line colPoint.Position;
        )
        
        UpdateShape lineShape;
    )
)

function Vector3YToZUp value =
(
    local newValue = value;
    newValue.Y = -value.Z;
    newValue.Z = value.Y;
    newValue;
)

function Main =
(
    local colFile = ReadCollisionFile( @"D:\Users\smart\Downloads\Sonic_Generations_USA_romfs\TARGET\GAME\BG\Z11_MAP\Z11COLL.BIN" );
    LoadCollision( colFile );
    OK
)

ClearListener();
Main();