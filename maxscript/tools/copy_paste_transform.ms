
global savedTransform;

rollout TransformCopyPasteDialog "TransformCopyPasteDialog" width:162 height:102
(
	button 'CopyButton' "Copy" pos:[32,8] width:96 height:38 align:#left
	button 'PasteButton' "Paste" pos:[31,53] width:96 height:38 align:#left
    
	on CopyButton pressed  do
    (
        savedTransform = $.Pos
	)
    
	on PasteButton pressed  do
    (
        undo on
        (
            $.Pos = savedTransform
        )
	)
)

CreateDialog TransformCopyPasteDialog
