
struct ObjectTransform
(
    Name,
    Transform
)

global gSavedObjectTransforms = #()

rollout CopyPasteDialog "CopyPasteDialog" width:79 height:77
(
	button 'CopyButton' "Copy" pos:[11,7] width:57 height:30 align:#left
	button 'PasteButton' "Paste" pos:[11,40] width:57 height:30 align:#left
    
	on CopyButton pressed  do
    (
        Free gSavedObjectTransforms
        
        for o in objects do
        (
            local objPos = ObjectTransform()
            objPos.Name = o.Name
            objPos.Transform = o.Transform
            
            Append gSavedObjectTransforms objPos
        )
        
        Print "Successfully copied object transforms"
	)
    
	on PasteButton pressed  do
    (
        for objPos in gSavedObjectTransforms do
        (
            local objNode = GetNodeByName objPos.Name
            if ( objNode != undefined ) then
            (
                objNode.Transform = objPos.Transform
            )
        )
        
        Print "Successfully pasted object transforms"
	)
)

CreateDialog CopyPasteDialog
