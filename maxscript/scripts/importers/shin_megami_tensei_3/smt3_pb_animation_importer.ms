
ClearListener()

FileIn "include\\MaxScriptExtensions\\FileStreamReader.ms"
FileIn "include\\MaxScriptExtensions\\FileUtils.ms"
FileIn "include\\MaxScriptExtensions\\Utils.ms"

MOTION_FIXED_POINT_7 = 128.0f
MOTION_FIXED_POINT_12 = 4096.0f -- 12 bits
MOTION_CONTROLLER_TYPE_TRANSLATION = 0
MOTION_CONTROLLER_TYPE_SCALE = 2
MOTION_CONTROLLER_TYPE_ROTATION = 3
global gEnablePrint = false -- really slow, for debugging

struct MotionFileHeader
(
    FileType,
    IsCompressed,
    UserId,
    FileSize,
    MagicCode,
    RealSize,
    DataSize,
    AddressInfoSize,
    Group,
    PlayGroup,
    FirstMotion,
    Flags
)

struct MotionDataHeader
(
    MotionCount,
    ControllerCount,
    MotionTableOffset
)

struct MotionController
(
    Type,
    Unknown1,
    NodeIndex,
    Unknown2
)

struct Motion
(
    FrameCount,
    KeyframeData = #()
)

struct MotionControllerKeyframeData
(
    DataSize,
    KeyframeCount,
    KeyframeSize,
    KeyframeFrameTimes = #(),
    KeyframeValues = #()
)

struct MotionFile
(
    FileHeader = MotionFileHeader(),
    DataHeader = MotionDataHeader(),
    Controllers = #(),
    Motions = #()
)

struct MotionFileLoader
(
    private mReader,
    private mBaseOffset,
    private mIndentLevel = 0,
    private mFileHeader,
    private mDataHeader,
    private mControllers = #(),
    private mMotions = #(),
    
    --
    -- Function forward declarations 
    --
    public fn IsValidMotionFile filePath = #(),
    public fn ReadMotionFile filePath = #(),
    public fn ApplyMotion index = #(),
    public fn ApplyAllMotions = #(),
    private fn ApplyMotionInternal index timeBase = #(),
    private fn IncreaseIndent = #(),
    private fn DecreaseIndent = #(),
    private fn IndentString str = #(),
    private fn ReadMotionFileHeader = #(),
    private fn ReadMotionDataHeader = #(),
    private fn ReadController = #(),
    private fn ReadMotion = #(),
    private fn ReadMotionControllerKeyframeData = #(),
    private fn GetAnimationNodes = #(),
    private fn TraverseNode = #(),
    private fn NodeCompareFunc x y = #(),
    private fn ClearAnimations = #(),
    
    --
    -- Function definitions
    --
    
    -- Static
    public fn IsValidMotionFile filePath =
    (
        local reader = FileStreamReader()
        reader.SetFile filePath false
        
        local result = false
        if ( reader.GetFileStreamLength() >= 0x20 ) then
        (
            reader.SeekSet( 0x08 )
            local magic = reader.ReadFixedLengthString( 4 )
            
            if ( magic == "MT00" or magic == "PIB0" ) then
                result = true
        )
        
        reader.Close()
        
        result
    ),
    
    -- Public methods
    public fn ReadMotionFile filePath =
    (
        -- Init reader
        mReader = FileStreamReader()
        mReader.SetFile filePath false
        
        -- Read header
        mFileHeader = ReadMotionFileHeader()
        mBaseOffset = mReader.GetPosition()
        
        if ( mFileHeader.DataSize > 0 ) then
        (
            mDataHeader = ReadMotionDataHeader()
            
            -- Read controllers
            if ( gEnablePrint ) then
            (
                Format( IndentString( "Controllers @ %\n" ) ) (HexStr(mReader.GetPosition()))
                Format( IndentString( "{\n" ) )
                IncreaseIndent()
            )
            
            for i = 1 to mDataHeader.ControllerCount do
            (
                local controller = ReadController()
                mControllers[i] = controller
            )
            
            if ( gEnablePrint ) then
            (
                DecreaseIndent()
                Format( IndentString( "}\n\n" ) )
                
                -- Read motion entries
                Format( IndentString( "Motions @ %\n" ) ) (HexStr(mReader.GetPosition()))
                Format( IndentString( "{\n" ) )
                IncreaseIndent()
            )
            z
            for i = 1 to mDataHeader.MotionCount do
            (
                mReader.SeekSet( mDataHeader.MotionTableOffset + ( ( i - 1 ) * 4 ) )
                local motionOffset = mReader.ReadU32()
                local motion = undefined
                
                if ( motionOffset != 0 ) then
                (
                    mReader.SeekSet( motionOffset + mBaseOffset )
                    motion = ReadMotion()
                )
                
                if ( motion == undefined and gEnablePrint ) then
                    Format( IndentString( "null,\n" ) )
                
                mMotions[i] = motion
            )
            
            if ( gEnablePrint ) then
            (
                DecreaseIndent()
                Format( IndentString( "}\n\n" ) )
            )
        )
    ),
    
    public fn ApplyMotion index =
    (
        ClearAnimations()
        
        local nodes = GetAnimationNodes()
        local motion = mMotions[ index ]
        if ( motion == undefined ) then
        (
            return false
        )
        
        AnimationRange = interval 0 motion.FrameCount

        ApplyMotionInternal nodes motion 0
    ),
    
    public fn ApplyAllMotions =
    (
        ClearAnimations()
        
        local nodes = GetAnimationNodes()
        local timeBase = 0
        
        -- Calculate range
        local totalFrameCount = 0
        for motion in mMotions do
        (
            if ( motion != undefined ) then
                totalFrameCount += motion.FrameCount
        )
        
        -- Apply default pose
        local defaultMotion = mMotions[ 1 ]
        if ( defaultMotion != undefined ) then
        (
            ApplyMotionInternal nodes defaultMotion 0
        )
        
        -- Get default values for controllers
        local defaultPositions = #()
        local defaultScales = #()
        local defaultRotations = #()
        
        with animate on
        (
            at time ( 0 )
            (
                for n in nodes do
                (
                    append defaultPositions n.Controller.Position
                    append defaultScales n.Controller.Scale
                    append defaultRotations n.Controller.Rotation
                ) 
            )
        )
        
        AnimationRange = interval 0 totalFrameCount
        
        for i = 1 to mMotions.Count do
        (
            -- Put default key values at beginning to prevent interpolation between animations
            
            if ( timeBase != totalFrameCount ) then
            (
                with animate on
                (
                    at time ( timeBase + 1 )
                    (
                        for i = 1 to nodes.Count do
                        (
                            local n = nodes[ i ]
                            n.Controller.Position = defaultPositions[ i ]
                            n.Controller.Scale = defaultScales[ i ]
                            n.Controller.Rotation = defaultRotations[ i ]
                        )
                    )
                )
            )
            
            local motion = mMotions[ i ]
            if ( motion == undefined ) then
            (
                continue
            )
            
            ApplyMotionInternal nodes motion timeBase
            timeBase += motion.FrameCount
            
            -- Put keys at end to prevent interpolation between animations
            
            with animate on
            (
                at time ( timeBase - 1 )
                (
                    for n in nodes do
                    (
                        n.Controller.Position = n.Controller.Position
                        n.Controller.Scale = n.Controller.Scale
                        n.Controller.Rotation = n.Controller.Rotation
                    )
                )
            )
            
            
        )
    ),
    
    private fn ApplyMotionInternal nodes motion timeBase = 
    (
        with animate on
        (         
            for i = 1 to mControllers.Count do
            (
                local controller = mControllers[i]
                local controllerNode = nodes[ controller.NodeIndex + 1 ]
                local keyframeData = motion.KeyframeData[i]
                
                for j = 1 to keyframeData.KeyframeCount do
                (
                    local keyframeFrameIndex = keyframeData.KeyframeFrameTimes[ j ]
                    local keyframeValue = keyframeData.KeyframeValues[ j ]
                    if ( keyframeValue == undefined ) then
                        continue
                    
                    at time ( timeBase + keyframeFrameIndex )
                    (
                        case ( controller.Type ) of
                        (
                            MOTION_CONTROLLER_TYPE_TRANSLATION:
                            (
                                controllerNode.Controller.Position = keyframeValue
                            )
                            
                            MOTION_CONTROLLER_TYPE_SCALE:
                            (
                                controllerNode.Controller.Scale = keyframeValue
                            )
                            
                            MOTION_CONTROLLER_TYPE_ROTATION:
                            (
                                controllerNode.Controller.Rotation = keyframeValue
                            )
                        )
                    )
                )
            )
        )
    ),
    
    -- Logging helpers
    private fn IncreaseIndent = 
    (
        mIndentLevel = mIndentLevel + 1
    ),
    
    private fn DecreaseIndent =
    (
        mIndentLevel = mIndentLevel - 1
    ),
    
    private fn IndentString str =
    (
        for i = 1 to mIndentLevel do
            str = "    " + str
        
        str
    ),
    
    private fn AlignOffset reader alignment = 
    (
        local align = reader.GetPosition() + (alignment - 1)
        align = bit.and align (bit.not (alignment - 1))
        reader.SeekSet( align );
    ),
    
    -- Read methods
    private fn ReadMotionFileHeader =
    (
        if ( gEnablePrint ) then
        (
            Format( IndentString( "MotionFileHeader @ %\n" ) ) (HexStr(mReader.GetPosition()))
            Format( IndentString( "{\n" ) )
            IncreaseIndent()
        )
        
        local header = MotionFileHeader();
        while ( true ) do
        (
            header.FileType = mReader.ReadU8()
            header.IsCompressed = mReader.ReadU8() == 1
            header.UserId = mReader.ReadU16()
            header.FileSize = mReader.ReadU32()
            header.MagicCode = mReader.ReadU32()
            header.RealSize = mReader.ReadU32()
            
            if ( header.MagicCode == 0x3030544D ) then
            (
                exit;
            )
            else
            (
                mReader.SeekCur( header.FileSize - 16 );
                AlignOffset mReader 64;
            )
        )
        
        header.DataSize = mReader.ReadU32()
        header.AddressInfoSize = mReader.ReadU32()
        header.Group = mReader.ReadU16()
        header.PlayGroup = mReader.ReadU16()
        header.FirstMotion = mReader.ReadU16()
        header.Flags = mReader.ReadU16()
        
        if ( gEnablePrint ) then
        (
            Format( IndentString( "FileType        %\n" ) ) header.FileType
            Format( IndentString( "IsCompressed    %\n" ) ) header.IsCompressed
            Format( IndentString( "UserId          %\n" ) ) header.UserId
            Format( IndentString( "FileSize        %\n" ) ) ( HexStr( header.FileSize ) )
            Format( IndentString( "MagicCode       %\n" ) ) ( HexStr( header.MagicCode ) )
            Format( IndentString( "RealSize        %\n" ) ) ( HexStr( header.RealSize ) )
            Format( IndentString( "DataSize        %\n" ) ) ( HexStr( header.DataSize ) )
            Format( IndentString( "AddressInfoSize %\n" ) ) ( HexStr( header.AddressInfoSize ) )
            Format( IndentString( "Group           %\n" ) ) header.Group
            Format( IndentString( "PlayGroup       %\n" ) ) header.PlayGroup
            Format( IndentString( "FirstMotion     %\n" ) ) header.FirstMotion
            Format( IndentString( "Flags           %\n" ) ) header.Flags
            DecreaseIndent()
            Format( IndentString( "}\n\n" ) )
        )
        
        header
    ),
    
    private fn ReadMotionDataHeader = 
    (
        if ( gEnablePrint ) then
        (
            Format( IndentString( "MotionDataHeader @ %\n" ) ) (HexStr(mReader.GetPosition()))
            Format( IndentString( "{\n" ) )
            IncreaseIndent()
        )
        
        header = MotionDataHeader()
        header.MotionCount = mReader.ReadU16()
        header.ControllerCount = mReader.ReadU16()
        header.MotionTableOffset = mReader.ReadU32()
        if ( header.MotionTableOffset != 0 ) then
            header.MotionTableOffset += mBaseOffset
        
        if ( gEnablePrint ) then
        (
            Format( IndentString( "MotionCount       %\n" ) ) header.MotionCount
            Format( IndentString( "ControllerCount     %\n" ) ) header.ControllerCount
            Format( IndentString( "MotionTableOffset %\n" ) ) ( HexStr( header.MotionTableOffset ) )
            DecreaseIndent()
            Format( IndentString( "}\n\n" ) )
        )
        
        header
    ),
    
    private fn ReadController =
    (
        if ( gEnablePrint ) then
        (
            Format( IndentString( "Controller @ %\n" ) ) (HexStr(mReader.GetPosition()))
            Format( IndentString( "{\n" ) )
            IncreaseIndent()
        )
        
        local controller = MotionController()
        controller.Type = mReader.ReadU16()
        controller.Unknown1 = mReader.ReadU16()
        controller.NodeIndex = mReader.ReadU16()
        controller.Unknown2 = mReader.ReadU16()
        
        if ( controller.Type != MOTION_CONTROLLER_TYPE_TRANSLATION and 
             controller.Type != MOTION_CONTROLLER_TYPE_SCALE and
             controller.Type != MOTION_CONTROLLER_TYPE_ROTATION )
        then
        (
            Print( "Warning: Unknown controller type: " + ( controller.Type as string ) )
        )
        
        if ( controller.Unknown1 != 0 ) then
        (
            Print( "Warning: controller.Unknown1 = " + ( controller.Unknown1 as string ) )
        )
        
        if ( controller.Unknown2 != 0 ) then
        (
            Print( "Warning: controller.Unknown2 = " + ( controller.Unknown2 as string ) )
        )
        
        if ( gEnablePrint ) then
        (
            Format( IndentString( "Type      %\n" ) ) controller.Type
            Format( IndentString( "Unknown1  %\n" ) ) controller.Unknown1
            Format( IndentString( "NodeIndex %\n" ) ) controller.NodeIndex
            Format( IndentString( "Unknown2  %\n" ) ) controller.Unknown2
            DecreaseIndent()
            Format( IndentString( "},\n" ) )
        )
        
        controller
    ),
    
    private fn ReadMotion = 
    (
        local m = Motion()
        m.FrameCount = mReader.ReadU32()
        
        if ( gEnablePrint ) then
        (
            Format( IndentString( "Motion % @\n" ) ) (HexStr(mReader.GetPosition()))
            Format( IndentString( "{\n" ) )
            IncreaseIndent()
            Format( IndentString( "FrameCount %\n" ) ) m.FrameCount
        )
        
        for i = 1 to mControllers.Count do
        (
            local keyframeData = ReadMotionControllerKeyframeData( mControllers[i] )
            m.KeyframeData[ i ] = keyframeData
        )
        
        if ( gEnablePrint ) then
        (
            DecreaseIndent()
            Format( IndentString( "},\n" ) )
        )
        
        m
    ),

    private fn ReadMotionControllerKeyframeData controller = 
    (
        local keyframeData = MotionControllerKeyframeData()
        keyframeData.DataSize = mReader.ReadU32()
        keyframeData.KeyframeCount = mReader.ReadU16()
        keyframeData.KeyframeSize = mReader.ReadU16()
        
        if ( gEnablePrint ) then
        (
            Format( IndentString( "MotionControllerKeyframeData @ %\n" ) ) (HexStr(mReader.GetPosition()))
            Format( IndentString( "{\n" ) )
            IncreaseIndent()
            Format( IndentString( "ControllerType      %\n" ) ) controller.Type
            Format( IndentString( "DataSize      %\n" ) ) keyframeData.DataSize
            Format( IndentString( "KeyframeCount %\n" ) ) keyframeData.KeyframeCount
            Format( IndentString( "KeyframeSize  %\n" ) ) keyframeData.KeyframeSize
            Format( IndentString( "KeyframeFrameTimes @ %\n" ) ) (HexStr(mReader.GetPosition()))
            Format( IndentString( "{\n" ) )
            IncreaseIndent()
        )
        
        keyframeData.KeyframeFrameTimes = mReader.ReadU16Array( keyframeData.KeyframeCount )
        mReader.AlignPosition( 4 )
        
        if ( gEnablePrint ) then
        (
            for i in keyframeData.KeyframeFrameTimes do
                Format( IndentString( "%,\n" ) ) i
                
            DecreaseIndent()
            Format( IndentString( "}\n" ) )            
            Format( IndentString( "KeyframeValues @ %\n" ) ) (HexStr(mReader.GetPosition()))
            Format( IndentString( "{\n" ) )
            IncreaseIndent()
        )
            
        for i = 1 to keyframeData.KeyframeCount do 
        (
            case ( controller.Type ) of
            (
                MOTION_CONTROLLER_TYPE_TRANSLATION:
                (
                    case ( keyframeData.KeyframeSize ) of
                    (
                        4:
                        (
                            --keyframeData.KeyframeValues[i] = [ ( mReader.ReadS8() as float ) / MOTION_FIXED_POINT_7, ( mReader.ReadS8() as float ) / MOTION_FIXED_POINT_7, ( mReader.ReadS8() as float ) / MOTION_FIXED_POINT_7, ( mReader.ReadS8() as float ) / MOTION_FIXED_POINT_7 ]
                            -- always something along the lines of 0x80808080?
                            print ( "Warning: MOTION_CONTROLLER_TYPE_TRANSLATION KeyframeSize = 4 Data = " + ( HexStr(mReader.ReadU32()) ) )
                        )
                        
                        8:
                        (
                            -- U32 morph shape id
                            -- F32 blend amount?
                            print ( "Warning: MOTION_CONTROLLER_TYPE_TRANSLATION KeyframeSize = 8 Data = " + ( HexStr(mReader.ReadU32()) ) + " " +  ( HexStr(mReader.ReadU32()) ) )
                        )
                        
                        12:
                        (
                            keyframeData.KeyframeValues[i] = [ mReader.ReadF32(), mReader.ReadF32(), mReader.ReadF32() ]
                        )
                        
                        default:
                        (
                            throw ( "Unhandled case: MOTION_CONTROLLER_TYPE_TRANSLATION KeyframeSize = " + ( keyframeData.KeyframeSize as string ) )
                        )
                    )
                )
                
                MOTION_CONTROLLER_TYPE_SCALE:
                (
                    case ( keyframeData.KeyframeSize ) of
                    (
                        4:
                        (
                            print ( "Warning: MOTION_CONTROLLER_TYPE_SCALE KeyframeSize = 4 Data = " + ( HexStr(mReader.ReadU32()) ) )
                        )
                        
                        8:
                        (
                            print ( "Warning: MOTION_CONTROLLER_TYPE_SCALE KeyframeSize = 8 Data = " + ( HexStr(mReader.ReadU32()) ) + " " +  ( HexStr(mReader.ReadU32()) ) )
                        )
                        
                        12:
                        (
                            keyframeData.KeyframeValues[i] = [ mReader.ReadF32(), mReader.ReadF32(), mReader.ReadF32() ]
                        )
                        
                        20:
                        (
                            print ( "Warning: MOTION_CONTROLLER_TYPE_SCALE KeyframeSize = 20 Data = " + ( HexStr(mReader.ReadU32()) ) + " " +  ( HexStr(mReader.ReadU32()) ) + " " +  ( HexStr(mReader.ReadU32()) ) + " " +  ( HexStr(mReader.ReadU32()) ) + " " +  ( HexStr(mReader.ReadU32()) ) )
                        )
                        
                        default:
                        (
                            throw ( "Unhandled case: MOTION_CONTROLLER_TYPE_SCALE KeyframeSize = " + ( keyframeData.KeyframeSize as string ) )
                        )
                    )
                )
                
                MOTION_CONTROLLER_TYPE_ROTATION:
                (
                    case ( keyframeData.KeyframeSize ) of
                    (
                        4:
                        (
                            print ( "Warning: MOTION_CONTROLLER_TYPE_ROTATION KeyframeSize = 4 Data = " + ( HexStr(mReader.ReadU32()) ) )
                        )
                        
                        8:
                        (
                            keyframeData.KeyframeValues[i] = quat ( ( mReader.ReadS16() as float ) / MOTION_FIXED_POINT_12 ) ( ( mReader.ReadS16() as float ) / MOTION_FIXED_POINT_12 )  ( ( mReader.ReadS16() as float ) / MOTION_FIXED_POINT_12 ) ( ( mReader.ReadS16() as float ) / MOTION_FIXED_POINT_12 )
                        )
                        
                        12:
                        (
                            print ( "Warning: MOTION_CONTROLLER_TYPE_ROTATION KeyframeSize = 12 Data = " + ( HexStr(mReader.ReadU32()) ) + " " +  ( HexStr(mReader.ReadU32()) ) + " " +  ( HexStr(mReader.ReadU32()) ) )
                        )
                        
                        default:
                        (
                            throw ( "Unhandled case: MOTION_CONTROLLER_TYPE_ROTATION KeyframeSize = " + ( keyframeData.KeyframeSize as string ) )
                        )
                    )
                )
                
                default:
                (
                    mReader.SeekCur( keyframeData.KeyframeSize )
                )
            )
        )
        
        if ( gEnablePrint ) then
        (
            for i in keyframeData.KeyframeValues do
                Format( IndentString( "%,\n" ) ) i 
                
            DecreaseIndent()
            Format( IndentString( "}\n" ) )
            DecreaseIndent()
            Format( IndentString( "},\n" ) )
        )
        
        keyframeData
    ),
    
    -- Motion load helpers
    private fn GetAnimationNodes =
    (
        local animRootNode = undefined
        
        -- Find root node
        for o in objects do
        (
            if (ClassOf o == BoneGeometry and not o.IsHidden) then
            (
                animRootNode = o
                exit
            )
        )
        
        -- Traverse nodes
        local nodes = #()
        TraverseNode animRootNode &nodes
        
        -- Sort nodes by id
        qsort nodes NodeCompareFunc
        
        return nodes
    ),
    
    private fn NodeCompareFunc x y =
    (
        xId = (getUserProp x "Id") as integer
        yId = (getUserProp y "Id") as integer 
        if ( xId == undefined or yId == undefined ) then
            throw "Nodes don't have ID user properties! Please use an updated version of the MaxScript"
        
        local result = 0
        
        if ( xId < yId ) then
        (
            result = -1
        )
        else if ( xId > yId ) then
        (
            result = 1
        )
        
        result
    ),
    
    private fn TraverseNode curNode &nodes =
    (
        append nodes curNode
        for childNode in curNode.Children do
        (
            TraverseNode childNode &nodes
        )
    ),
    
    private fn ClearAnimations = 
    (
        for obj in objects do
        (
            DeleteKeys obj.controller #allkeys
        )
    )
)

global loader = MotionFileLoader()
global filePath = FileUtils.RunOpenFileDialog "Open file containing animations" "SMT animation files (*.PB)|*.PB" "AtlusMT Object Presets"
if ( loader.IsValidMotionFile( filePath ) ) then
(
    loader.ReadMotionFile( filePath )
    loader.ApplyAllMotions()
)

