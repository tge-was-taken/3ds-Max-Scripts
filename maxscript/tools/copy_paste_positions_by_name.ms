
struct ObjectPosition
(
    Name,
    Position
)

global gSavedObjectPositions = #()

rollout CopyPasteDialog "CopyPasteDialog" width:79 height:77
(
	button 'CopyButton' "Copy" pos:[11,7] width:57 height:30 align:#left
	button 'PasteButton' "Paste" pos:[11,40] width:57 height:30 align:#left
    
	on CopyButton pressed  do
    (
        Free gSavedObjectPositions
        
        for o in objects do
        (
            local objPos = ObjectPosition()
            objPos.Name = o.Name
            objPos.Position = o.Pos
            
            Append gSavedObjectPositions objPos
        )
        
        Print "Successfully copied object positions"
	)
    
	on PasteButton pressed  do
    (
        for objPos in gSavedObjectPositions do
        (
            local objNode = GetNodeByName objPos.Name
            if ( objNode != undefined ) then
            (
                objNode.Pos = objPos.Position
            )
        )
        
        Print "Successfully pasted object positions"
	)
)

CreateDialog CopyPasteDialog
