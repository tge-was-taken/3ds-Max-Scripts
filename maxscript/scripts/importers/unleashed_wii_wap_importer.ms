
-- Sonic Unleashed Wii WAP parser by TGE

-- This will only work if the object names contain the original file name as it needs it to be that way
-- EG: stg011_o_a01.gno
-- Technically, as long as the string contains the area letter after the second underscore it will function correctly
-- Example: some_name_aXX will still work just fine

-- Furthermore it will collapse the modifier stack as the skin modifier really messes up transforms

clearlistener()

fn ReadBELong  fstream = (bit.swapBytes (bit.swapBytes (readlong fstream #unsigned) 1 4) 2 3)
fn ReadBEFloat fstream = (bit.intAsFloat (bit.swapBytes (bit.swapBytes (readlong fstream #unsigned) 1 4) 2 3))
	
local areaCharArray = #("A", "B", "C", "D", "E", "F", "G", "H") -- set up dictionary for area section names
	
struct AreaTFMStruct
(
	tfm,
	areaChar
)
	
file = getOpenFileName caption:"Open WAP" types:"WAP file|*.wap"
if file != undefined and doesFileExist file == true do (

	f = fopen file "rb"
	
	-- seek past some junk
	fseek f 0x8 #seek_cur
	
	-- get the area count from the file
	areaCount = ReadBElong f
	
	-- seek past some more junk
	fseek f 0x14 #seek_cur
	
	tfm_array = #()
	
	for i = 1 to areaCount do 
	(
		m11 = ReadBEFloat f; m21 = ReadBEFloat f; m31 = ReadBEFloat f; m41 = ReadBEFloat f -- x
		m12 = ReadBEFloat f; m22 = ReadBEFloat f; m32 = ReadBEFloat f; m42 = ReadBEFloat f -- y
		m13 = ReadBEFloat f; m23 = ReadBEFloat f; m33 = ReadBEFloat f; m43 = ReadBEFloat f -- z
		m14 = ReadBEFloat f; m24 = ReadBEFloat f; m34 = ReadBEFloat f; m44 = ReadBEFloat f
		tfm = matrix3 [m11,m13*-1,m12,m14] [m31*-1,(m33*-1)*-1,m32*-1,m34] [m21,m23*-1,m22,m24]  [m41,m43*-1,m42,m44] -- (flip up axis of the matrix to match max's)
		tfm_array[i] = (AreaTFMStruct tfm:tfm areaChar:areaCharArray[i])
	)
	
	-- Select all objects so we can iterate over them in the selection
	max select all
	
	for i = 1 to selection.count do 
	(
		-- if the object is not a geometry, skip it
		if (superclassof selection[i] != GeometryClass) then continue
		
		-- skin modifier will fuck everything up, so collapse the modifier stack to get rid of it
		maxOps.CollapseNodeTo selection[i] 1 true
		
		-- split string by "_" to a string array
		areaChar = filterstring selection[i].name "_"

		-- if the string array doesn't have 3 or more elements, skip this object
		if (not(areaChar.count >= 3)) then continue
		
		-- get the area character from the split string array
		areaChar = areaChar[3]
		areaChar = areaChar[1]
		
		-- get current node transform
		selectionTFM = selection[i].transform 
		
		-- iterate over the amount of areas in the wap file
		for t = 1 to areaCount do
		(
			-- check if the areaChar in the current array element is equal to our current areaChar
			if (tfm_array[t].areaChar == areaChar) then 
			(
				newTFM = selectionTFM * tfm_array[t].tfm
				selection[i].transform = newTFM
			)
		)
	)
	clearselection()
	fclose f
)