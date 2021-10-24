fn ReadFixedString bstream fixedLen =
(
   local str = ""
   for i = 1 to fixedLen do
   (
      str0 = ReadByte bstream #unsigned
      if str0!=0xFF AND str0!=0xFF do str+= bit.intAsChar str0
   )
   str
)

clearlistener()
fname = getOpenFileName \ 
caption:"Open File" \
types:"Blitz3D model(*.b3d)|*.b3d" \
historyCategory:"Blitz3D_B3D Object Presets"
f = fopen fname "rb"
filename = GetFilenameFile fname
filepath = GetFilenamePath fname
fseek f 0 #seek_end
FileEnd = ftell f
fseek f 0 #seek_set

Vert_Array = #()
UV_Array = #()
UV_Array2 = #()
UV_Array3 = #()
UV_Array4 = #()
UV_Array5 = #()
UV_Array6 = #()
UV_Array7 = #()
UV_Array8 = #()
Normal_Array = #()
Face_Array = #()
Color_Array = #()
Alpha_Array = #()
TexName_Array = #()
BrushTexID_Array = #()
BrushName_Array = #()

while (not ftell f >= FileEnd) do (
	ChunkTag = readfixedstring f 4
	ChunkSize = readlong f -- Header not included!
	ChunkStart = ftell f
	case of 
	(
		(ChunkTag == "BB3D"):(
			BB3DVer = readlong f
			format "BB3D\n"
		)
		(ChunkTag == "TEXS"):(
			format " TEXS\n"
			while (not ftell f >= (ChunkStart + ChunkSize)) do (
				TextureName = readstring f
				TextureFlags = readlong f
				TextureBlend = readlong f
				TextureXTrans = readfloat f; TextureYTrans = readfloat f
				TextureXScale = readfloat f; TextureYScale = readfloat f
				TextureRotation = readfloat f -- In radians!
				append TexName_Array TextureName
				print ("Texture Name: "+TextureName as string)
			)
		)
		(ChunkTag == "BRUS"):(
			format " BRUS\n"
	-- 		fseek f ChunkSize #seek_Cur
			TEXSCount = readlong f
			while (not ftell f >= (ChunkStart + ChunkSize)) do (
				BrushName = readstring f
				BrushColor_R = readfloat f
				BrushColor_G = readfloat f
				BrushColor_B = readfloat f
				BrushColor_A = readfloat f
				BrushShine = readfloat f
				BrushBlend = readlong f
				BrushFX = readlong f
				BrushTexID = readlong f
				if BrushTexID == 0xFF then BrushTexID = 1 else BrushTexID += 1
				append BrushTexID_Array BrushTexID
				append BrushName_Array BrushName
			)
		)
		(ChunkTag == "VRTS"):(
			format " VRTS\n"
		VertFlag = readlong f
		UVSetCount = readlong f
		UVSetSize = readlong f
		while (not ftell f >= (ChunkStart + ChunkSize)) do (
			vx = readfloat f
			vy = readfloat f
			vz = readfloat f
			if (VertFlag > 0) then (
				nx = readfloat f
				ny = readfloat f
				nz = readfloat f
				append Normal_Array [nx,ny,nz]
			)
			if (VertFlag == 2) then (
				Color_R = (readfloat f * 255.999) as integer
				Color_G = (readfloat f * 255.999) as integer
				Color_B = (readfloat f * 255.999) as integer
				Color_A = (readfloat f * 255.999) as integer
				append Color_Array [Color_R,Color_G,Color_B]
				append Alpha_Array Color_A
			)
			for uvs = 1 to UVSetCount do (
				case of (
					(UVSetSize == 0):(
					append UV_Array [0,0,0]
					)
					(UVSetSize == 1):(
					fseek f 0x4 #seek_cur
					append UV_Array [0,0,0]
					)
					(UVSetSize == 2):(
					tu = readfloat f
					tv = readfloat f
					if (uvs == 1) then append UV_Array [tu,tv,0]
					if (uvs == 2) then append UV_Array2 [tu,tv,0]
					if (uvs == 3) then append UV_Array3 [tu,tv,0]
					if (uvs == 4) then append UV_Array4 [tu,tv,0]
					if (uvs == 5) then append UV_Array5 [tu,tv,0]
					if (uvs == 6) then append UV_Array6 [tu,tv,0]
					if (uvs == 7) then append UV_Array7 [tu,tv,0]
					if (uvs == 8) then append UV_Array8 [tu,tv,0]
					)
					(UVSetSize == 3):(
					tu = readfloat f
					tv = readfloat f
					tw = readfloat f
					if (uvs == 1) then append UV_Array [tu,tv,tw]
					if (uvs == 2) then append UV_Array2 [tu,tv,tw]
					if (uvs == 3) then append UV_Array3 [tu,tv,tw]
					if (uvs == 4) then append UV_Array4 [tu,tv,tw]
					if (uvs == 5) then append UV_Array5 [tu,tv,tw]
					if (uvs == 6) then append UV_Array6 [tu,tv,tw]
					if (uvs == 7) then append UV_Array7 [tu,tv,tw]
					if (uvs == 8) then append UV_Array8 [tu,tv,tw]
					)
					(UVSetSize == 4):(
					tu = readfloat f
					tv = readfloat f
					tw = readfloat f
					tx = readfloat f
					if (uvs == 1) then append UV_Array [tu,tv,tw]
					if (uvs == 2) then append UV_Array2 [tu,tv,tw]
					if (uvs == 3) then append UV_Array3 [tu,tv,tw]
					if (uvs == 4) then append UV_Array4 [tu,tv,tw]
					if (uvs == 5) then append UV_Array5 [tu,tv,tw]
					if (uvs == 6) then append UV_Array6 [tu,tv,tw]
					if (uvs == 7) then append UV_Array7 [tu,tv,tw]
					if (uvs == 8) then append UV_Array8 [tu,tv,tw]
					)
				)
			)
			append Vert_Array [vx,vy,vz]
		)
		)
		(ChunkTag == "TRIS"):(
			format " TRIS\n"
			BrushID = readlong f
			if BrushID == 0xFF then BrushID = 0 else BrushID += 1
			while (not ftell f >= (ChunkStart + ChunkSize)) do (
				f1 = readlong f+1
				f2 = readlong f+1
				f3 = readlong f+1
				append Face_Array [f1,f2,f3]
			)
			msh = mesh Vertices:Vert_Array Faces:Face_Array
			msh.name = BrushName_Array[BrushID]
			msh.numTVerts = UV_Array.count
			if Color_Array.count != 0 then (
				setNumCPVVerts msh msh.numTVerts
				setCVertMode msh true
				setShadeCVerts msh true
				defaultVCFaces msh
				UseVertAlpha == false
				for p = 1 to Color_array.count do(
					if UseVertAlpha == false then (setvertcolor msh p Color_array[p]) else (setvertcolor msh p [Alpha_array[p],Alpha_array[p],Alpha_array[p]])
				)
			)	
			buildTVFaces msh
			for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
			for j = 1 to UV_array.count do setTVert msh j UV_array[j]
			for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
			if Normal_Array.count != 0 then (
				max modify mode
				select msh
				addmodifier msh (Edit_Normals ()) ui:off
				msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
				EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
				EN_setNormal = msh.Edit_Normals.SetNormal
				normID = #{}

				for v = 1 to Normal_array.count do(
					free normID
					EN_convertVS #{v} &normID
					for id in normID do EN_setNormal id Normal_array[v]
				)
			)
			msh.material = Standard()
			tm = Bitmaptexture filename:(TexName_Array[(BrushTexID_Array[BrushID])])
			msh.material.diffuseMap = tm
			msh.material.ShowInViewport = true
			free Face_Array
			meshop.deleteIsoVerts msh
		)
		(ChunkTag == "NODE"):(
			format " NODE\n"
			NodeTFM = #()
			NodeName = readstring f
			px = readfloat f; py = readfloat f; pz = readfloat f
			sx = readfloat f; sy = readfloat f; sz = readfloat f
			rx = readfloat f; ry = readfloat f; rz = readfloat f; rw = readfloat f
			tfm = (quat rw rx ry rz) as matrix3
			tfm = tfm * scalematrix [sx,sy,sz]
			tfm = tfm * transmatrix [px,py,pz]
			append NodeTFM tfm
		)
		(ChunkTag == "MESH"):(
			format " MESH\n"
			BrushID = readlong f
		)
		default:(
			fseek f ChunkSize #seek_cur
		)
	)
)
gc()
fclose f