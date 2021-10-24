
struct NodeTableStruct
(
	GlobalID,
	NodePtr
)

struct NodeFlags
(
	NoTranslate = false,
	NoRotate = false,
	NoScale = false,
	NoDraw = false,
	NoDrawChild = false,
	UseZYXRotation = false
)

struct ObjectStruct
(
	Flags = NodeFlags(),
	AttachStructPtr,
	PosVec = [0,0,0],
	RotVec = [0,0,0],
	SclVec = [1,1,1],
	ChildObjectStructPtr,
	SiblingObjectStructPtr,
	-- Data attached using pointers
	AttachStruct,
	ChildObjectStruct,
	SiblingObjectStruct,
	-- Procedural members not written to the file
	LocalMatrix = matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0],
	WorldMatrix = matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0],
	Bone
)

struct AttachStruct
(
	VertStructPtr,
	MeshStructPtr,
	CenterVec,
	Radius,
	-- Data attached using pointers
	VertStruct,
	MeshStruct
)

struct MeshStruct
(
	Material,
	Tiny = #(),
	Strip = #()
)

struct LandTableStruct
(
	LandNodeCount,
	ChunkModelCount,
	Unk1,
	Unk2,
	Unk3,
	LandNodeListPtr,
	Unk4,
	TexNamePtr,
	TexListPtr,
	-- Procedural members
	LandNodeList = #(),
	TexName,
	TexList = #()
)

struct LandNodeStruct
(
	CenterVec,
	Radius,
	ObjectStructPtr,
	Padding,
	Flags,
	-- Procedural members
	ObjectStruct
)

struct Chunk 
(
	ID,
	Flags,
	Size,
	ChunkData
)

struct ChunkVertex
(
	IndexOffset,
	VertexCount,
	VertexData
)

struct VertexData
(
	Vertex = #(),
	Normal = #(),
	Flags = #(),
	Special = #(),
	Diffuse = #(),
	Specular = #(),
	VertexIndex = #()
)

struct MatData
(
	Diffuse,
	Ambient,
	Specular,
	DestAlpha,
	SrcAlpha,
	Size
)

struct TinyData
(
	DAdjust,
	ClampV,
	ClampU,
	FlipV,
	FlipU,
	-- in short data
	TexID,
	SuperSample,
	FilterMode
)

struct StripData
(
	UserFlagCount,
	Size,
	StripCount,
	UserOffset,
	Index = #(),
	UserFlag = #(),
	UV = #(),
	Normal = #(),
	Color = #()
)