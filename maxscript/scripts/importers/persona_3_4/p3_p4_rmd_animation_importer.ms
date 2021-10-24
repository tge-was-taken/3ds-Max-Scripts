/*
    Persona 3/4 Animation importer, version 1.1
    Written by TGE. Please give credit where is due.
    
    Changelog:
        1.0:
            Reads animations found in given files, and gives you a list of them to select and load represented by a GUI dialog.
            Supports reading animations from any RenderWare binary file, and .PAC files
            
        1.1:
            Reset button now properly resets the skeleton to its initial default pose.
            Note that this uses the pose the model is in when you first load an animation!
*/

ClearListener()

FileIn @"include\MaxScriptExtensions\FileStreamReader.ms"
FileIn @"include\MaxScriptExtensions\FileUtils.ms"

struct RwAnimationHeader
(
	public Version,
	public KeyFrameType,
	public FrameCount,
	public Flags,
	public Duration
)

struct RwKeyFrame
(
    public Time,
    public Rotation,
    public Translation,
    public PreviousFrameOffset,
    public PreviousFrame,
    public Node
)

struct RwCompressedKeyFrame
(
	public Time,
	public RotationX,
	public RotationY,
	public RotationZ,
	public RotationW,
	public TranslationX,
	public TranslationY,
	public TranslationZ,
	public PreviousFrameOffset
)

struct RwCompressedKeyFrameCustomData
(
	public Offset,
	public Scalar
)

struct RwAnimation
(
    public Header,
    public KeyFrames = #()
)

struct KeyValuePair
(
    public Key,
    public Value
)

global gLoader = undefined
struct RwAnimationLoader
(
	public Animations = #(),
    public FPS = 30,
    private mAnimationNodes = undefined,
    private mDefaultPose = undefined,
    
    -- Forward declarations
    public fn Create = (),
    public fn ReadAnimationsFromFile filePath = (),
    public fn ClearAnimations = (),
    public fn LoadAnimation animationIndex = (),
    public fn SelectAnimation = (),
    private fn DecompressFloat compressed = (),
    private fn GetAnimationNodes = (),
    private fn GetAnimationNodesImpl = (),
    private fn TraverseNode curNode &nodes = (),
    private fn SaveDefaultPose = (),
	
    -- Public
    public fn Create = 
    (
        gLoader = RwAnimationLoader()
        gLoader
    ),
    
	public fn ReadAnimationsFromFile filePath =
	(
        -- Read file
        local reader = FileStreamReader()
		reader.SetFile filePath false
        
        local fileType = GetFilenameType filePath
        if ( fileType == ".PAC" ) then
        (
            reader.SeekCur( 0x100 )
        )
        
        while ( ( reader.GetPosition() + 12 ) < reader.GetFileStreamLength() ) do
        (
            -- Keep looping over file until we're out of possible animations to read
            local chunkId = reader.ReadU32()
            local chunkSize = reader.ReadU32()
            local chunkVersion = reader.ReadU32()
            if ( chunkId != 0x1B ) then
            (
                -- Skip
                if ( ( reader.GetPosition() + chunkSize ) >= reader.GetFileStreamLength() ) then
                (
                    exit
                )
                
                reader.SeekCur( chunkSize )
                continue
            )
            
            -- Read animation
            local animation = RwAnimation()
            
            -- Read animation header
            animation.Header = RwAnimationHeader()
            animation.Header.Version = reader.ReadU32()
            animation.Header.KeyFrameType = reader.ReadU32()
            animation.Header.FrameCount = reader.ReadU32()
            animation.Header.Flags = reader.ReadU32()
            animation.Header.Duration = reader.ReadF32()
		
            -- Read keyframes
            local frameOffsets = #()
            for i = 1 to animation.Header.FrameCount do
            (
                local kf = RwKeyFrame()
                if ( animation.Header.KeyFrameType == 1 ) then
                (
                    append frameOffsets ((i - 1) * 36)
                    
                    kf.Time = reader.ReadF32()
                    kf.Rotation = reader.ReadQuatF32()
                    kf.Translation = reader.ReadVec3F32()
                    kf.PreviousFrameOffset = reader.ReadU32()
                )
                else
                (
                    append frameOffsets ((i - 1) * 24)
                    
                    local ckf = RwCompressedKeyFrame()
                    ckf.Time = reader.ReadF32()
                    ckf.RotationX = reader.ReadU16()
                    ckf.RotationY = reader.ReadU16()
                    ckf.RotationZ = reader.ReadU16()
                    ckf.RotationW = reader.ReadU16()
                    ckf.TranslationX = reader.ReadU16()
                    ckf.TranslationY = reader.ReadU16()
                    ckf.TranslationZ = reader.ReadU16()
                    ckf.PreviousFrameOffset = reader.ReadU32()
                    
                    kf.Time = ckf.Time
                    kf.Rotation = quat (DecompressFloat(ckf.RotationX)) (DecompressFloat(ckf.RotationY)) (DecompressFloat(ckf.RotationZ)) (DecompressFloat(ckf.RotationW))
                    kf.Translation = [ DecompressFloat(ckf.TranslationX), DecompressFloat(ckf.TranslationY),DecompressFloat(ckf.TranslationZ) ]
                    kf.PreviousFrameOffset = ckf.PreviousFrameOffset
                )
                
                if (kf.Time != 0.0f) then
                (
                    local prevFrameIdx = finditem frameOffsets kf.PreviousFrameOffset
                    
                    if (prevFrameIdx != -1) then
                    (
                        kf.PreviousFrame = animation.KeyFrames[prevFrameIdx]
                    )
                    else 
                    (
                        print( "kf.PreviousFrame = undefined!! i = " + i as string + " kf.PreviousFrameOffset = " + kf.PreviousFrameOffset as string )
                        kf.PreviousFrame = undefined
                    )
                )
                else
                (
                    kf.PreviousFrame = undefined
                )
                
                animation.KeyFrames[i] = kf
            )
            
            if ( animation.Header.KeyFrameType == 2 ) then
            (
                local customData = RwCompressedKeyFrameCustomData()
                customData.Offset = reader.ReadVec3F32()
                customData.Scalar = reader.ReadVec3F32()
                
                for keyFrame in animation.KeyFrames do
                (
                    keyFrame.Translation *= customData.Scalar
                    keyFrame.Translation += customData.Offset
                )
            )
            
            append Animations animation
        )
        
        reader.Close()
	),
    
    public fn LoadAnimation animationIndex =
	(
        ClearAnimations()
        
        local animation = Animations[ animationIndex ]
		
		-- set up max animation
		animationRange = interval 0 (animation.Header.Duration * FPS)
		
		-- enter animation scope
		with animate on
		(
			local boneIdx = 1
			for keyIdx = 1 to animation.Header.FrameCount do
			(
				local keyFrame = animation.KeyFrames[keyIdx]
				
				at time (keyFrame.Time * FPS)
				(
					if (keyFrame.Time == 0.0f) then
					(
						keyFrame.Node = (GetAnimationNodes())[ keyIdx ]
					)
					else if (keyFrame.Node == undefined) then
					(
						keyFrame.Node = keyFrame.PreviousFrame.Node
					)
					
                    if ( keyFrame.Node == undefined ) then
                    (
                        print( "keyFrame.Node == undefined!! keyIdx = " + keyIdx as string ) 
                    )
                    else
                    (
                        keyFrame.Node.Controller.Rotation = inverse keyFrame.Rotation
                        keyFrame.Node.Controller.Position = keyFrame.Translation
                    )
				)
			)
		)
	),
    
    public fn SelectAnimation =
    (
        rollout AnimationSelectionDialog "Select an animation to load" width:198 height:123
        (
        	dropdownList 'animationDropdown' "       Select an animation to load" pos:[9,7] width:176 height:40 align:#left
        	button 'OkButton' "OK" pos:[65,90] width:68 height:25 align:#left
        	spinner 'FpsSpinner' "FPS" pos:[10,58] width:56 height:16 range:[30,120,0] align:#left
        	button 'ResetButton' "Reset" pos:[118,54] width:62 height:26 align:#left
            
            fn Initialize = 
            (
                for i = 1 to gLoader.Animations.Count do
                (
                    animationDropdown.Items = append animationDropdown.Items ( i as string )
                )
            )
            
            on FpsSpinner changed value do
            (
                gLoader.FPS = value
            )
            
        	on OkButton pressed do
        	(
        	    if ( animationDropdown.Selection != 0 ) then
        	        gLoader.LoadAnimation( animationDropdown.Selection )
        	)
            
            on ResetButton pressed do
            (
                gLoader.ClearAnimations()
            )
        )
        
        
        CreateDialog AnimationSelectionDialog
        AnimationSelectionDialog.Initialize()
    ),
        
    public fn ClearAnimations =
    (
        if ( mDefaultPose == undefined ) then
        (
            SaveDefaultPose()
        )
        else
        (
            local nodes = GetAnimationNodes()
            for node in nodes do
            (
                DeleteKeys node.Controller #allkeys
            )
            
            for i = 1 to nodes.Count do
            (
                nodes[i].Controller.Position = mDefaultPose[i][1]
                nodes[i].Controller.Rotation = mDefaultPose[i][2]
            )
        )
    ),
    
    -- Private
    private fn DecompressFloat compressed =
    (
        local floatInt = bit.shift (bit.and compressed 0x8000) 16
        if ((bit.and compressed 0x7fff) != 0) then
        (
            floatInt = bit.or floatInt ((bit.shift (bit.and compressed 0x7800) 12) + 0x38000000)
            floatInt = bit.or floatInt (bit.shift (bit.and compressed 0x07ff) 12)
        )

        bit.intasfloat floatInt
    ),
    
    private fn GetAnimationNodes =
    (
        if ( mAnimationNodes == undefined ) then
            mAnimationNodes = GetAnimationNodesImpl()
        
        return mAnimationNodes
    ),
    
    private fn GetAnimationNodesImpl =
    (
        local nodes = #()
        
        for o in objects do
        (
            local indexProp = GetUserProp o "Index"
            if ( indexProp != undefined ) then
            (
                local index = indexProp as integer
                nodes[ index ] = o
            )
        )
        
        if ( nodes.Count == 0 ) then
        (
            -- Fallback
            local animRootNode = GetNodeByName "_5002"
            if ( animRootNode == undefined ) then
                animRootNode = GetNodeByName "Bone2"
            
            -- Traverse nodes
            TraverseNode animRootNode &nodes
        )
        
        return nodes
    ),
    
    private fn TraverseNode curNode &nodes =
    (
        append nodes curNode
        for childNode in curNode.Children do
            TraverseNode childNode &nodes
    ),
    
    private fn SaveDefaultPose = 
    (
        mDefaultPose = #()
        
        for node in GetAnimationNodes() do
        (
            append mDefaultPose #( node.Controller.Position, node.Controller.Rotation )
        )
    )
)


(
    local filePath = FileUtils.RunOpenFileDialog "Open file containing animations" "Persona 3/4 animation files (*.*)|*.*" "RMD Animation Object Presets"
    local animationLoader = RwAnimationLoader.Create()
    animationLoader.ReadAnimationsFromFile( filePath )
    animationLoader.SelectAnimation()
)

