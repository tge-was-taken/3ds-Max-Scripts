gc()
clearlistener()
Dummy_Array = #()
for y = 1 to $.numverts do (
	normal = getNormal $ y
	nx = normal.x
	ny = normal.y
	nz = normal.z
	append Dummy_Array [nx,ny,nz]
)
print Dummy_Array