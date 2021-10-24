/*
Kamen Rider *.pemt motion pack loader version 1.0
Changelog:
10/2/2019: Initial release.
*/

-- Globals
global g_ioContext = undefined;

global g_krMotionDlgLoader = undefined;
global g_krMotionDlgIndexMap = undefined;
global g_krMotionDlgSelectedIndex = 1;

-- Functions

-- Cache commonly used interface functions
global _bit_SwapBytes = bit.SwapBytes;
global _bit_And = bit.And;
global _bit_IntAsFloat = bit.IntAsFloat;
global _bit_Get = bit.Get;
global _bit_IntAsChar = bit.intAsChar;

-- Utility
fn utilSwap16 value =
(
    _bit_SwapBytes value 1 2
)

fn utilSwap32 value =
(
    _bit_SwapBytes ( _bit_SwapBytes value 1 4 ) 2 3
)

fn utilSwapFloat value =
(
    _bit_IntAsFloat ( _bit_SwapBytes ( _bit_SwapBytes value 1 4 ) 2 3 )
)

fn utilAllBitsSet value mask =
(
    ( _bit_And value mask ) == mask;
)

fn utilInitList count  =
(
    local list = #();
	
	if ( count > 0 ) then
		list[count] = undefined;
	
    list;
)

fn utilVector3YToZUp value =
(
    local temp = value.Y;
    value.Y = -value.Z;
    value.Z = temp;   
    value;
)

-- File IO
ioEndian_Little = 0
ioEndian_Big = 1

struct ioContext
(
    Stream,
    FileName,
    FilePath,
    Endianness,
    Swap,
    BasePositions,
	BasePositionIndex,
	BasePosition,
    SavedPositions,
	SavedPositionIndex
)

fn ioOpenFile filePath =
(
    g_ioContext = ioContext();
    g_ioContext.Stream = fopen filePath #rb;
    g_ioContext.FileName = GetFilenameFile filePath;
    g_ioContext.FilePath = GetFilenamePath filePath;
    g_ioContext.Endianness = ioEndian_Little;
    g_ioContext.Swap = false;
	g_ioContext.BasePositions = #( 0 );
    g_ioContext.BasePositionIndex = 1;
	g_ioContext.BasePosition = 0;
	g_ioContext.SavedPositions = #();
    g_ioContext.SavedPositionIndex = 0;
)

fn ioSelectOpenFile category ext =
(
    local filePath = getOpenFileName \ 
        caption:("Open " + category + " file")\
        types:( category + " (*." + ext + ")|*." + ext ) \
        historyCategory:( category + " Object Presets" )
    
    filePath;
)

fn ioGetFileName =
(
    g_ioContext.FileName;
)

fn ioGetFilePath =
(
    g_ioContext.FilePath;
)

fn ioSetEndianness endian =
(
    g_ioContext.Endianness = endian;
    g_ioContext.Swap = g_ioContext.Endianness == ioEndian_Big;
)

fn ioTell =
(
    FTell g_ioContext.Stream;
)

fn ioPushBase =
(
	g_ioContext.BasePositionIndex += 1;
	g_ioContext.BasePosition = g_ioContext.BasePositions[ g_ioContext.BasePositionIndex ] = ioTell();
)

fn ioPush =
(
	--print( "ioPush (0x" + ( bit.intashex(ioTell()) as string ) + ")" );
	g_ioContext.SavedPositionIndex += 1;
    g_ioContext.SavedPositions[ g_ioContext.SavedPositionIndex ] = ioTell();
)

fn ioPopBase =
(
	g_ioContext.BasePositionIndex -= 1;
	g_ioContext.BasePosition = g_ioContext.BasePositions[ g_ioContext.BasePositionIndex ];
)

fn ioSeekSetAbs position = ()

fn ioPop =
(
	--print( "ioPop (0x" + ( bit.intashex(ioTell()) as string ) + ")" );
	local savedPosition = g_ioContext.SavedPositions[ g_ioContext.SavedPositionIndex ];
	g_ioContext.SavedPositionIndex -= 1;
    ioSeekSetAbs( savedPosition );
)

fn ioSeekCur position =
(
    FSeek g_ioContext.Stream position #seek_cur;
)

fn ioSeekSetAbs position =
(
    FSeek g_ioContext.Stream position #seek_set;
)

fn ioSeekSet position =
(
    FSeek g_ioContext.Stream ( g_ioContext.BasePosition + position ) #seek_set;
)

fn ioReadU8 =
(
    ReadByte g_ioContext.Stream #unsigned;
)

fn ioReadS16 =
(
    local value = ReadShort g_ioContext.Stream #signed;
    if ( g_ioContext.Swap ) then value = utilSwap16( value );
    value;
)

fn ioReadU16 =
(
    local value = ReadShort g_ioContext.Stream #unsigned;
    if ( g_ioContext.Swap ) then value = utilSwap16( value );
    value;
)

fn ioReadS32 =
(
    local value = ReadLong g_ioContext.Stream #signed;
    if ( g_ioContext.Swap ) then value = utilSwap32( value );
    value;
)

fn ioReadU32 =
(
    local value = ReadLong g_ioContext.Stream #unsigned;
    if ( g_ioContext.Swap ) then value = utilSwap32( value );
    value;
)

fn ioReadF32 =
(
    local value;
    if ( g_ioContext.Swap ) then value = _bit_IntAsFloat( ioReadU32() );
    else value = ReadFloat g_ioContext.Stream;
    value;
)

fn ioReadVector2 =
(
    [ ioReadF32(), ioReadF32() ];
)

fn ioReadVector3 =
(
    [ ioReadF32(), ioReadF32(), ioReadF32() ];
)

fn ioReadVector4 =
(
    [ ioReadF32(), ioReadF32(), ioReadF32(), ioReadF32() ];
)

fn ioReadQuaternion =
(
    quat (ioReadF32()) (ioReadF32()) (ioReadF32()) (ioReadF32());
)

-- KR type definitions
struct krMotionPack
(
	Field00,
	Motions
)

struct krMotion
(
	Tracks,
	DeltaTime,
	Duration
)

struct krMotionTrack
(
	Flags,
	NodeIndex,
	KeyCount,
	Duration,
	Field0C,
	KeyTimes,
	KeyValues,
	Field18,
	Field1C
)

struct krMotionLoader
(
	MotionPack,
	Nodes
)

struct krMotionNode
(
	Id,
	BasePosition,
	BaseScale,
	BaseRotation,
	RefPosition,
	RefScale,
	RefRotation,
	MaxNode
)

struct krMotionMap
(
	DisplayIndex,
	RealIndex
)

krMotionFlags_ComponentMask = 0xF;
krMotionFlags_ComponentTranslation = 1;
krMotionFlags_ComponentScale = 2;
krMotionFlags_ComponentRotation = 8;

fn krMotionTrackListRead count =
(
	--print "krMotionTrackListRead"
	local list = utilInitList( count );
	
	for i = 1 to count do
	(
		local mt = krMotionTrack();
		mt.Flags = ioReadU32();
		mt.NodeIndex = ioReadU16();
		--print mt.NodeIndex;
		mt.KeyCount = ioReadU16();
		mt.Duration = ioReadF32();
		mt.Field0C = ioReadU32();
		local keyTimeListOffset = ioReadU32();
		local keyValueListOffset = ioReadU32();
		mt.Field18 = ioReadU32();
		mt.Field1C = ioReadU32();
		
		-- Decompose flags
		local flags = mt.Flags;
		local componentFlags = _bit_and flags krMotionFlags_ComponentMask;  
		local hasTranslation = componentFlags == krMotionFlags_ComponentTranslation;
		local hasScale = componentFlags == krMotionFlags_ComponentScale;
		local hasRotation = componentFlags == krMotionFlags_ComponentRotation;
		
		local keyCount = mt.KeyCount;				
		mt.KeyTimes = utilInitList( keyCount );
		mt.KeyValues = utilInitList( keyCount );
		local keyTimes = mt.KeyTimes;
		local keyValues = mt.KeyValues;
		
		if ( keyCount > 0 ) then
		(
			ioPush();
			
			if ( keyTimeListOffset > 0 ) then
			(
				ioSeekSet( keyTimeListOffset );

				for j = 1 to keyCount do
					keyTimes[j] = ioReadF32();
			)
			
			if ( keyValueListOffset > 0 ) then
			(
				ioSeekSet( keyValueListOffset );
				
				if ( hasTranslation ) then
				(
					for j = 1 to keyCount do
					(
						keyValues[j] = ioReadVector3();
						--if ( ioReadU32() != 0 ) then throw "Padding is not 0";
						ioSeekCur( 4 ); -- padding
					)
				)
				else if ( hasScale ) then
				(
					for j = 1 to keyCount do
					(
						keyValues[j] = ioReadVector3();
						--if ( ioReadU32() != 0 ) then throw "Padding is not 0";
						ioSeekCur( 4 ); -- padding
					)
				)
				else if ( hasRotation ) then
				(
					for j = 1 to keyCount do
					(
						keyValues[j] = ioReadQuaternion();
					)
				)
			)
			
			ioPop();
		)
		
		list[i] = mt;
	)
	
	list;
)

fn krMotionRead =
(
	ioPushBase();
	
	local m = krMotion();
	local trackCount = ioReadU32();
	local trackListOffset = ioReadU32();
	m.DeltaTime = ioReadF32();
	m.Duration = ioReadF32();
	
	if ( trackCount != 0 and trackListOffset != 0 ) then
	(
		ioPush();
		ioSeekSet( trackListOffset );
		m.Tracks = krMotionTrackListRead( trackCount );
		ioPop();
	)
	
	ioPopBase();
	m;
)

fn krMotionListRead count =
(
	local list = utilInitList( count );
	
	for i = 1 to count do
	(
		local motionOffset = ioReadU32();
		
		if ( motionOffset != 0 ) then
		(
			ioPush();
			ioSeekSet( motionOffset );
			list[i] = krMotionRead();
			ioPop();
		)
		else
		(
			list[i] = undefined;
		)
	)
	
	list;
)

fn krMotionPackRead =
(
	ioPushBase();

	local mp = krMotionPack();
	mp.Field00 = ioReadU32();
	local motionCount = ioReadU32();
	local motionListOffset = ioReadU32();
	ioSeekCur( 4 ); -- file size
	
	if ( motionCount > 0 and motionListOffset != 0 ) then
	(
		ioSeekSet( motionListOffset );
		mp.Motions = krMotionListRead( motionCount );
	)
	
	ioPopBase();
	mp;
)

fn krMotionPackLoad filePath =
(	
	ioOpenFile( filePath );
	ioSetEndianness( ioEndian_Big );
	krMotionPackRead();
)

-- Motion load helpers
fn krMotionLoaderTraverseNode curNode &nodes =
(
	local krNode = krMotionNode();
	krNode.MaxNode = curNode;
	krNode.Id = (getUserProp krNode.MaxNode "id") as integer;
	krNode.BasePosition = krNode.RefPosition = krNode.MaxNode.Controller.Position;
	krNode.BaseScale = krNode.RefScale = krNode.MaxNode.Controller.Scale;
	krNode.BaseRotation = krNode.RefRotation = krNode.MaxNode.Controller.Rotation;
	append nodes krNode
	
	for childNode in curNode.Children do
	(
		krMotionLoaderTraverseNode childNode &nodes
	)
)

fn krMotionLoaderGetNodes =
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
	
	if ( animRootNode == undefined ) then
		throw "There are no animateable nodes in the scene!";
	
	-- Traverse nodes
	local nodes = #()
	krMotionLoaderTraverseNode animRootNode &nodes
	
	return nodes
)

fn krMotionLoaderGetNodeById list id =
(
	result = undefined;
	
	for n in list do
	(
		if ( n.Id == id ) then
		(
			result = n;
			exit;
		)
	)
	
	result;
)

fn krMotionLoaderNodeCompareFunc x y =
(
	xId = (getUserProp x "id") as integer
	yId = (getUserProp y "id") as integer 
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
)

fn krMotionLoaderGetCachedNodes loader =
(
	local nodes = loader.Nodes;
	if ( nodes.Count > 0 ) then
	(
		if ( isDeleted nodes[1].MaxNode ) then
		(
			-- Node instance doesn't exist anymore, presumably
			-- because of a scene reload
			nodes = krMotionLoaderGetNodes();
		)
	)
	
	nodes;
)

fn krMotionLoaderReset loader = 
(
	local nodes = krMotionLoaderGetCachedNodes( loader );
	for krNode in nodes do
	(
		deleteKeys krNode.MaxNode.Controller #allkeys;
		krNode.MaxNode.Controller.Position = krNode.BasePosition;
		krNode.MaxNode.Controller.Scale = krNode.BaseScale;
		krNode.MaxNode.Controller.Rotation = krNode.BaseRotation;
	)
)	

fn krMotionLoaderLoadMotionByIndex loader index =
(
	krMotionLoaderReset( loader );
	
	if ( index < 1 or index > loader.MotionPack.Motions.Count ) then
		return false;
	
	local motion = loader.MotionPack.Motions[ index ];
	if ( motion == undefined ) then
		return false;
	
	local nodes = krMotionLoaderGetCachedNodes( loader );
	local fps = 60f;
	if ( motion.DeltaTime != 0 ) then
		fps = 1f / motion.DeltaTime;
	
	AnimationRange = interval 0 (motion.Duration * fps);
	
	with animate on
	(		
		for track in motion.Tracks do
		(
			local nodeId = track.NodeIndex;
			if ( nodeId == 0xFFFF ) then
			(
				continue;
			)
			
			local krNode = krMotionLoaderGetNodeById nodes nodeId;
			if ( krNode == undefined ) then
			(
				print ("Missing node for id " + nodeId as string)
				continue;
			)
			
			local maxNode = krNode.MaxNode;
			
			-- Decompose flags
			local flags = track.Flags;
			local componentFlags = _bit_and flags krMotionFlags_ComponentMask;  
			local hasTranslation = componentFlags == krMotionFlags_ComponentTranslation;
			local hasScale = componentFlags == krMotionFlags_ComponentScale;
			local hasRotation = componentFlags == krMotionFlags_ComponentRotation;
			
			local keyCount = track.KeyCount;
			for i = 1 to keyCount do
			(
				at time ( track.KeyTimes[i] * fps)
				(
					local keyValue = track.KeyValues[i];
					if ( hasTranslation ) then
					(
						maxNode.Controller.Position = krNode.RefPosition + keyValue;
					)
					else if ( hasScale ) then
					(
						maxNode.Controller.Scale = keyValue;
					)
					else if ( hasRotation ) then
					(
						maxNode.Controller.Rotation = krNode.RefRotation * ( inverse keyValue );
					)
					else
					(
						print( "Unknown key frame type: " + (bit.intashex(flags) as string) )
					)
				)
			)
		)
	)
	
	true;
)

fn krMotionLoaderLoadPack loader motionPack =
(
	loader.MotionPack = motionPack;
	loader.Nodes = krMotionLoaderGetNodes();
)

fn krMotionLoaderSetRefPose loader =
(
	local nodes = krMotionLoaderGetCachedNodes( loader );
	for n in nodes do
	(
		n.RefPosition = n.MaxNode.Controller.Position;
		n.RefScale = n.MaxNode.Controller.Scale;
		n.RefRotation = n.MaxNode.Controller.Rotation;
	)
)

fn krMotionLoaderResetRefPose loader =
(
	local nodes = krMotionLoaderGetCachedNodes( loader );
	for n in nodes do
	(
		n.RefPosition = n.BasePosition;
		n.RefScale = n.BaseScale;
		n.RefRotation = n.BaseRotation;
	)
)

rollout krMotionSelectDialog "Kamen Rider Motion Loader" width:200 height:264
(
	dropdownList 'ddlIndex' "       Select motion index" pos:[16,16] width:176 height:40 align:#left
	button 'BTNOK' "OK" pos:[24,160] width:70 height:25 align:#left
	button 'btnReset' "Reset" pos:[104,160] width:70 height:26 align:#left
	spinner 'spnIndex' "Index" pos:[112,64] width:50 height:16 range:[0,999,0] type:#integer scale:1 align:#left
	button 'btnSetRefPose' "Set reference pose" pos:[24,96] width:152 height:25 align:#left
	button 'btnResetRefPose' "Reset reference pose" pos:[24,128] width:152 height:25 align:#left
	label 'lbl1' "Created by TGE (2019)                 To be used in conjunction with the edited version of RTB's EMD MaxScript" pos:[16,200] width:168 height:56 align:#left
	
	fn Initialize = 
	(
		g_krMotionDlgIndexMap = #();
		
		for i = 1 to g_krMotionDlgLoader.MotionPack.Motions.Count do
		(
			if ( g_krMotionDlgLoader.MotionPack.Motions[i] == undefined ) then
				continue;
			
			ddlIndex.Items = append ddlIndex.Items ( ( i - 1 ) as string );
			append g_krMotionDlgIndexMap ( krMotionMap DisplayIndex:ddlIndex.Items.Count RealIndex:i );
		)
	)	
	
	on ddlIndex selected sel do
	(
		local displayIndex = ddlIndex.Selection;
		local realIndex = 0;
		for i = 1 to g_krMotionDlgIndexMap.Count do
		(
			if ( g_krMotionDlgIndexMap[i].DisplayIndex == displayIndex ) then
			(
				realIndex = g_krMotionDlgIndexMap[i].RealIndex;
				exit;
			)
		)
		
		g_krMotionDlgSelectedIndex = realIndex;
		spnIndex.Value = realIndex - 1;
	)
	on BTNOK pressed do
	(
		krMotionLoaderLoadMotionByIndex g_krMotionDlgLoader g_krMotionDlgSelectedIndex;
	)
	on btnReset pressed do
	(
		krMotionLoaderReset( g_krMotionDlgLoader );
	)
	on spnIndex changed val do
	(
		local index = val + 1;
		g_krMotionDlgSelectedIndex = index;
		
		local displayIndex = undefined;
		for i = 1 to g_krMotionDlgIndexMap.Count do
		(
			if ( g_krMotionDlgIndexMap[i].RealIndex == index ) then
			(
				displayIndex = g_krMotionDlgIndexMap[i].DisplayIndex;
				exit;
			)
		)
		
		if ( displayIndex != undefined ) then
			ddlIndex.Selection = displayIndex;
	)
	on btnSetRefPose pressed do
	(
		krMotionLoaderSetRefPose g_krMotionDlgLoader;
	)
	on btnResetRefPose pressed do
	(
		krMotionLoaderResetRefPose g_krMotionDlgLoader;
	)
)

fn main =
(
	clearListener();
	
	-- local filePath = @"D:\Emulators\RPCS3\dev_hdd0\game\BLJS10263\PS3_GAME\USRDIR\nativePS\nativePS\nativePS\data\chr\KRW\KRW00\motion\0000.pemt";
	local filePath = ioSelectOpenFile "Kamen Rider Motion Pack" "pemt";
	if ( filePath != undefined ) then
	(
		-- Load motion pack
		local motionPack = krMotionPackLoad( filePath );

		-- Create loader
		local motionLoader = krMotionLoader();
		krMotionLoaderLoadPack motionLoader motionPack;
		
		-- Show dialog
		g_krMotionDlgLoader = motionLoader;
		CreateDialog krMotionSelectDialog;
		krMotionSelectDialog.Initialize();
	)
	
	OK
)

main();
