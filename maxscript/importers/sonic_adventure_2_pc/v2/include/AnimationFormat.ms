
-- enum<u16> KeyframeFlags
-- {
    KeyframeFlags_Position    = 1;
    KeyframeFlags_Rotation    = 2;
    KeyframeFlags_Scale       = 4;
    KeyframeFlags_Vector      = 8;
    KeyframeFlags_Vertex      = 16;
    KeyframeFlags_Normal      = 32;
    KeyframeFlags_Target      = 64;
    KeyframeFlags_Roll        = 128;
    KeyframeFlags_Rotation2   = 256;
    KeyframeFlags_Color       = 512;
    KeyframeFlags_Intensity   = 1024;
    KeyframeFlags_Spot        = 2048;
    KeyframeFlags_Point       = 4096;
    KeyframeFlags_Quaternion  = 8192;

    KeyframeFlags_Linear      = 0x0000;
    KeyframeFlags_Spline      = 0x0040;
    KeyframeFlags_User        = 0x0080;
-- };

struct AnimationEntry
(
    Id          = 0,
    ObjectCount = 0,
    Animation   = undefined -- Animation
)

struct Animation
(
    ObjectAnimations        = #(),  -- ObjectAnimation[]
    FrameCount              = 0,    -- enum KeyframeFlags
    Flags                   = 0,
    InterpolationAndFactor  = 0
)

struct PositionKeyframe 
(
    Time     = 0,
    Position = [ 0, 0, 0 ]
)

struct RotationKeyframe 
(
    Time     = 0,
    Rotation = [ 0, 0, 0 ] -- Euler angles (degrees)
)

struct ScaleKeyframe 
(
    Time     = 0,
    Scale    = [ 0, 0, 0 ]
)

struct ObjectAnimation
(
    Positions   = #(), -- PositionKeyframe[], can be empty
    Rotations   = #(), -- RotationKeyframe[], can be empty
    Scales      = #(), -- ScaleKeyframe[], can be empty
    
    fn HasPosition = ( Positions.Count != 0; ),
    fn HasRotation = ( Rotations.Count != 0; ),
    fn HasScale    = ( Scales.Count != 0; )
)