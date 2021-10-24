
clearlistener()

fn readShortFloat f =
(
	short = (readshort f) as float / 4096
	return short as float
)

file = getOpenFileName caption:"Open ICO" types:"PS2 ICO file|*.ico"

if file != undefined and doesFileExist file == true do 
(
	f = fopen file "rb"
	
	ID = readlong f
	shapeCount = readlong f
	textureType = readlong f
	unusedFloat = readfloat f
	vertCount = readlong f
	
	format "Shape Count = %\n Texture Type = %\n Vertex Count = %\n" shapeCount textureType vertCount
	
	vtxArray = #()
	shpArray = #()
	nrmArray = #()
	tuvArray = #()
	clrArray = #()
	faceArray = #()
	
	triStart = 0
	
	for v = 1 to vertCount/3 do
	(
		for tri = 1 to 3 do
		(
			for shp = 1 to shapeCount do
			(
				vtxArray[shp] = [(readShortFloat f), (readShortFloat f), (readShortFloat f)]
				vtxFlag = readshort f
			)
			append shpArray vtxArray[1]
			
			append nrmArray [(readShortFloat f), (readShortFloat f), (readShortFloat f)]
			nrmFlag = readshort f
			
			append tuvArray [(readShortFloat f), (readShortFloat f), 0] 
			append clrArray [(readbyte f #unsigned), (readbyte f #unsigned), (readbyte f #unsigned), (readbyte f #unsigned)]
		)
		faceArray[v] = [1+triStart,2+triStart,3+triStart]
		triStart += 3
	)
	msh = mesh vertices:shpArray faces:faceArray
	msh.numTVerts = shpArray.count
	buildTVFaces msh
	for j = 1 to tuvArray.count do setTVert msh j tuvArray[j]
	for j = 1 to faceArray.count do setTVFace msh j faceArray[j]
	for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
		
	setNumCPVVerts msh msh.numTVerts
	setCVertMode msh true
	setShadeCVerts msh true
	defaultVCFaces msh
	for j = 1 to clrArray.count do setvertcolor msh j clrArray[j]
	
	max modify mode
	select msh
	addmodifier msh (Edit_Normals ()) ui:off
	msh.Edit_Normals.MakeExplicit selection:#{1..nrmArray.count}
	EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
	EN_setNormal = msh.Edit_Normals.SetNormal
	normID = #{}

	for v = 1 to nrmArray.count do(
		free normID
		EN_convertVS #{v} &normID
		for id in normID do EN_setNormal id nrmArray[v]
	)
	maxOps.CollapseNodeTo msh 1 true -- Collapse the Edit Normals modifier
	
)