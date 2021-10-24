-- Author: TGE
-- Usage:
-- Select meshes to merge and run the script.
--

global optionDeleteSkinData = true;

fn mergeMeshes meshes =
(
	local baseMesh = meshes[1];
	for msh in meshes do
	(
		if ( msh != baseMesh ) then
		(
			meshop.attach baseMesh msh attachMat:#IDToMat condenseMat:true;
		)
	)
	
	baseMesh;
)

fn main =
(
	local meshes = $selection as array;
	local skinDatas = #();
	for msh in meshes do
	(
		select msh;
		SkinUtils.ExtractSkinData msh;
		append skinDatas (getNodeByName ("SkinData_"+msh.Name));
	)
	
	local baseMesh = mergeMeshes meshes;
	local baseSkinData = mergeMeshes skinDatas;
	skinUtils.ImportSkinData baseMesh baseSkinData;
	if ( optionDeleteSkinData ) then delete baseSkinData;
)

with undo off
with redraw off
(
	main();
)