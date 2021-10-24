
FileIn "Common.ms"
FileIn "MaxScriptExtensions\\Utils.ms"
FileIn "MaxScriptExtensions\\FileUtils.ms"
FileIn "MaxScriptExtensions\\FileStreamReader.ms"

struct AnimationReader
(
    private mReader     = undefined,
    private mBaseOffset = 0,
    
    --
    -- Function declarations
    --
    
    -- Returns array of AnimationEntry
    private fn ReadOffset = ( mReader.ReadU32() + mBaseOffset; ),
    
    private fn ReadAnimation objectCount = (),
    private fn ReadObjectAnimation flags = (),
    
    public fn ReadAnimationFile filePath =
    (
        -- Set up reader
        mReader = FileStreamReader();
        mReader.SetFile filePath true;
        
        local entries = #();
        while ( true ) do
        (
            local entry = AnimationEntry();
            entry.Id = mReader.ReadS16();
            entry.ObjectCount = mReader.ReadU16();
            
            local offset = ReadOffset();
            if ( offset != 0 ) then
            (
                mReader.PushPosition();
                mReader.SeekSet( offset );
                entry.Animation = ReadAnimation( entry.ObjectCount );
                mReader.PopPosition();
            )
            
            append entries entry;
            
            if ( entry.Id == -1 ) then
                exit;
        )
        
        entries;
    ),
    
    private fn ReadAnimation objectCount = 
    (
        local anim = Animation();
        local objAnimationOffset = mReader.ReadU32();
        anim.FrameCount = mReader.ReadU32();
        anim.Flags = mReader.ReadU16();
        anim.InterpolationAndFactor = mReader.ReadU16();
        
        if ( objAnimationOffset != 0 ) then
        (
            mReader.SeekSet( objAnimationOffset );
            for i = 1 to objectCount do
                anim.ObjectAnimations[ i ] = ReadObjectAnimation( anim.Flags );
        )
        
        anim;
    ),
    
    private fn ReadObjectAnimation flags =
    (
        local anim = ObjectAnimation();
        local mask = KeyframeFlags_Position + KeyframeFlags_Rotation + KeyframeFlags_Scale;
        if ( ( bit.and flags ( bit.not mask ) ) != 0 ) then
        (
            Format "Unknown flag combination: %\n" HexStr( flags );
            Assert( false );   
        )
        
        if ( bit.get flags KeyframeFlags_Position ) then
        (
            local positionOffset = ReadOffset();
        )
        
        if ( bit.get flags KeyframeFlags_Rotation ) then
        (
            local rotationOffset = ReadOffset();
        )
        
        if ( bit.get flags KeyframeFlags_Scale ) then
        (
            local scaleOffset = ReadOffset();
        )
        
        if ( bit.get flags KeyframeFlags_Position ) then
        (
            local positionCount = mReader.ReadU32();
        )
        
        if ( bit.get flags KeyframeFlags_Rotation ) then
        (
            local rotationCount = mReader.ReadU32();
        )
        
        if ( bit.get flags KeyframeFlags_Scale ) then
        (
            local scaleCount = mReader.ReadU32();
        )
        
        if ( bit.get flags KeyframeFlags_Position ) then
        (
            mReader.PushPosition();
            mReader.SeekSet( positionOffset );
            
            for i = 1 to positionCount do
            (
                local kf = PositionKeyframe();
                kf.Time = mReader.ReadU32();
                kf.Position = mReader.ReadVec3F32();
                anim.Positions[ i ] = kf;
            )
            
            mReader.PopPosition();
        )
        
        if ( bit.get flags KeyframeFlags_Rotation ) then
        (
            mReader.PushPosition();
            mReader.SeekSet( rotationOffset );
            
            for i = 1 to rotationCount do
            (
                local kf = RotationKeyframe();
                kf.Time = mReader.ReadU32();
                
                local rotation = mReader.ReadVec3S32();
                kf.Rotation = [ AngleToDegrees( rotation.X ),
                                 AngleToDegrees( rotation.Y ),
                                 AngleToDegrees( rotation.Z ) ];
                
                anim.Rotations[ i ] = kf;
            )
            
            mReader.PopPosition();
        )
        
        if ( bit.get flags KeyframeFlags_Scale ) then
        (
            mReader.PushPosition();
            mReader.SeekSet( scaleOffset );
            
            for i = 1 to scaleCount do
            (
                local kf = ScaleKeyframe();
                kf.Time = mReader.ReadU32();
                kf.Scale = mReader.ReadVec3F32();
                anim.Scales[ i ] = kf;
            )
            
            mReader.PopPosition();
        )
        
        anim;
    )
)