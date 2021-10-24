-- Version 1.3

-- Definitions
struct bcmObjectBackupData
(
    Name,
    PosController,
    RotController
)

-- Globals
global g_bcmLastSelectedList = undefined;
global g_bcmObjectBackupDataList = #();

-- http://felipenogueira3d.com/posts/constraint-functions---3ds-max/
-- Position Constraint
-- bcmAddPosContraint (Affected Node) (Target Node) (Target Weight)
-- (newCon:true if fresh constrain, false if adding target to existing constrain)
fn bcmAddPosContraint obj target tarWeight:100 relative:false newCon:true =
(
    if newCon == true then
    (
        local posConstraint = Position_Constraint()
        --obj.pos.controller.available.controller = posConstraint
        obj.pos.controller = posConstraint
        local posConstraintList = posConstraint.constraints
        posConstraintList.appendtarget target tarWeight
        posConstraint.relative = relative;
    )
    else
    (
        obj.position.controller.Position_Constraint.appendtarget target tarWeight
    )
    --obj.pos.controller.setactive 3
)

-- Look-At Constraint
-- bcmAddLookConstraint (Affected Node) (Target Node) (upNode:UpNode Node) (Target Weight)
-- (newCon:true if fresh constrain, false if adding target to existing constrain)
fn bcmAddLookConstraint obj target upNode tarWeight newCon:true =
(
    if newCon == true then
    (
        local lookAtConstraint = LookAt_Constraint()
        obj.rotation.controller.available.controller = lookAtConstraint
        local lookAtConstraintList = lookAtConstraint.constraints
        lookAtConstraintList.appendtarget target tarWeight
        lookAtConstraint.upnode_world = false
        lookAtConstraint.pickUpNode = upNode
        lookAtConstraint.lookat_vector_length = 0
    )
    else
    (
        obj.rotation.controller.LookAt_Constraint.appendtarget target tarWeight
    )
    obj.rotation.controller.setactive 3
)

-- Orientation Constraint
-- bcmAddOrientConstraint (Affected Node) (Target Node) (Target Weight) (relative: keep off-set True or False)
-- (newCon:true if fresh constrain, false if adding target to existing constrain)
fn bcmAddOrientConstraint obj target tarWeight:100 relative:false newCon:true =
(
    if newCon == true then
    (
        local orientConstraint = Orientation_Constraint()
        --obj.rotation.controller.available.controller = orientConstraint
        obj.rotation.controller = orientConstraint;
        local orientConstraintList = orientConstraint.constraints
        orientConstraintList.appendtarget target tarWeight
        orientConstraint.relative = relative
    )
    else
    (
        obj.rotation.controller.Orientation_Constraint.appendtarget target tarWeight
    )
    --obj.rotation.controller.setactive 3
)

fn arrMoveItemByValue array value newIndex =
(
    local index = findItem array value;
    arrMoveItemByIndex array index newIndex;
)

fn arrMoveItemByIndex array index newIndex =
(
    if ( index != newIndex and newIndex > 0 and newIndex <= array.Count ) then
    (
        local value = array[index];
        deleteItem array index;
        insertItem value array newIndex;
    )
)

fn lbMoveSelectedItem listBox indexOffset =
(
    local items = listBox.Items;
    local index = listBox.Selection;
    local newIndex = index + indexOffset;
    arrMoveItemByIndex items index newIndex;
    listBox.Items = items;
    listBox.Selection = newIndex;
)

fn lbAddPrefixForAllItems listBox prefix =
(
    local items = #();
    for name in listBox.Items do
    (
        local newName = prefix + name;
        local node = GetNodeByName name;
        if ( node != undefined ) then
            node.Name = newName;
        
        append items newName;
    )
    
    listBox.Items = items;
)

fn lbRemoveSuffixForAllItems listBox prefix =
(
    local newItems = #();
    for name in listBox.Items do
    (
        local newName = name;
        
        if ( matchPattern name pattern:(prefix + "*") ) then
        (
            newName = substring name (prefix.Count + 1) -1;
            local node = GetNodeByName( name );
            if ( node != undefined ) then
            (
                node.Name = newName;
            )
        )
        
        append newItems newName;
    )
    
    listBox.Items = newItems;
)

fn lbAddSuffixForAllItems listBox suffix =
(
    local items = #();
    for name in listBox.Items do
    (
        local newName = name + suffix;
        local node = GetNodeByName name;
        if ( node != undefined ) then
            node.Name = newName;
        
        append items newName;
    )
    
    listBox.Items = items;
)

fn lbRemoveSuffixForAllItems listBox suffix =
(
    local newItems = #();
    for name in listBox.Items do
    (
        local newName = strRemoveSuffix name suffix;
        local node = GetNodeByName name exact:true;
        if ( node != undefined ) then
            node.Name = newName;
        
        append newItems newName;
    )
    
    listBox.Items = newItems;
)

fn lbDeleteSelectedItem listBox =
(
    local items = listBox.Items;
    local index = listBox.Selection;
    if ( index > 0 and index <= items.Count ) then
    (
        deleteItem items index;
        listBox.Items = items;
    )
)

fn strRemovePrefix str prefix =
(
    if ( prefix.Count > 0 and matchPattern str pattern:(prefix + "*") ) then
        str = substring str (prefix.Count + 1) -1;
    
    str;
)

fn strRemoveSuffix str suffix =
(
    if ( suffix.Count > 0 and matchPattern str pattern:("*" + suffix) ) then
        str = substring str 1 ( str.Count - suffix.Count );
    
    str;
)

fn strRemovePrefixSuffix str prefix suffix =
(
    str = strRemovePrefix str prefix;
    str = strRemoveSuffix str suffix;
    str;
)

fn strSwapPrefixSuffix str oldPrefix oldSuffix newPrefix newSuffix =
(
    ( newPrefix + ( strRemovePrefixSuffix str oldPrefix oldSuffix ) + newSuffix );
)

fn bcmResetObjectControllers =
(
    for backup in g_bcmObjectBackupDataList do
    (
        local obj = GetNodeByName backup.Name;
        if ( obj == undefined ) then continue;
        if ( backup.PosController != undefined ) then obj.pos.controller = backup.PosController;
        if ( backup.RotController != undefined ) then obj.rotation.controller = backup.RotController;
    )
)

fn ioSelectOpenFile category ext =
(
    local filePath = getOpenFileName \ 
        caption:("Open " + category + " file")\
        types:( category + " (*." + ext + ")|*." + ext ) \
        historyCategory:( category + " Object Presets" )
    
    filePath;
)

fn ioSelectSaveFile category ext =
(
    local filePath = getSaveFileName \ 
        caption:("Open " + category + " file")\
        types:( category + " (*." + ext + ")|*." + ext ) \
        historyCategory:( category + " Object Presets" )
    
    filePath;
)

fn lbAddSelection lb =
(
    local names = lb.Items;
    local selectedNames = for o in selection do append names o.name;
    lb.Items = names;
)

rollout bcmRollout "Bone constraint mapper 1.3 by TGE" width:640 height:504
(
	listbox 'lbSource' "" pos:[128,40] width:150 height:19 align:#left
	listbox 'lbTarget' "" pos:[368,40] width:150 height:19 align:#left
	button 'btnApply' "Apply" pos:[144,456] width:80 height:30 align:#left
	button 'btnMoveUp' "Move up" pos:[288,80] width:70 height:30 align:#left
	button 'btnMoveDown' "Move down" pos:[288,120] width:70 height:30 align:#left
	button 'btnMatchByName' "Match by name" pos:[288,160] width:70 height:40 align:#left
	button 'btnSourceAddSelection' "Add selection" pos:[136,312] width:128 height:32 align:#left
	button 'btnTargetAddSelection' "Add selection" pos:[376,312] width:128 height:32 align:#left
	label 'lbl1' "Prefix" pos:[24,40] width:63 height:16 align:#left
	label 'lbl2' "Source" pos:[176,16] width:63 height:16 align:#left
	label 'lbl3' "Target" pos:[416,16] width:63 height:16 align:#left
	label 'lbl4' "Prefix" pos:[536,40] width:63 height:16 align:#left
	button 'btnSourceAddPrefix' "+" pos:[96,56] width:15 height:15 align:#left
	button 'btnTargetAddPrefix' "+" pos:[608,56] width:15 height:15 align:#left
	button 'btnSourceClearSelection' "Clear" pos:[136,352] width:128 height:32 align:#left
	button 'btnTargetClearSelection' "Clear" pos:[376,352] width:128 height:32 align:#left
	button 'btnSourceRemovePrefix' "-" pos:[96,72] width:15 height:15 align:#left
	button 'btnTargetRemovePrefix' "-" pos:[608,72] width:15 height:15 align:#left
	button 'btnReset' "Reset" pos:[232,456] width:80 height:30 align:#left
	button 'btnDelete' "Delete" pos:[288,208] width:70 height:30 align:#left
	dropdownList 'ddlPosContraintMode' "Rotation constrain mode" pos:[320,400] width:130 height:40 items:#("None", "Relative", "Absolute") selection:2 align:#left
	dropdownList 'ddlRotConstrainMode' "Position constrain mode" pos:[184,400] width:130 height:40 items:#("None", "Relative", "Absolute") selection:2 align:#left
	label 'lbl53' "Suffix" pos:[24,104] width:63 height:16 align:#left
	button 'btnSourceAddSuffix' "+" pos:[96,120] width:15 height:15 align:#left
	button 'btnSourceRemoveSuffix' "-" pos:[96,136] width:15 height:15 align:#left
	label 'lbl74' "Suffix" pos:[536,104] width:63 height:16 align:#left
	button 'btnTargetAddSuffix' "+" pos:[608,120] width:15 height:15 align:#left
	button 'btnTargetRemoveSuffix' "-" pos:[608,136] width:15 height:15 align:#left
	edittext 'tbSourceSuffix' "" pos:[16,120] width:80 height:30 align:#left
	edittext 'tbSourcePrefix' "" pos:[16,56] width:80 height:30 align:#left
	edittext 'tbTargetPrefix' "" pos:[528,56] width:80 height:30 align:#left
	edittext 'tbTargetSuffix' "" pos:[528,120] width:80 height:30 align:#left
	button 'btnLoad' "Load" pos:[320,456] width:80 height:30 align:#left
	button 'btnSave' "Save" pos:[408,456] width:80 height:30 align:#left
    
	on lbSource selected sel do
	(
	    g_bcmLastSelectedList = lbSource;
	)
	on lbSource doubleClicked sel do
	(
	    lbTarget.Selection = lbSource.Selection;
	)
	on lbTarget selected sel do
	(
	    g_bcmLastSelectedList = lbTarget;
	)
	on lbTarget doubleClicked sel do
	(
	    lbSource.Selection = lbTarget.Selection;
	)
	on btnApply pressed do
	(
	    if ( g_bcmObjectBackupDataList.Count > 0 ) then
	    (
	        bcmResetObjectControllers();
	        g_bcmObjectBackupDataList = #();
	    )
        
	    local count = lbSource.Items.Count;
	    if ( count > lbTarget.Items.Count ) then
	        count = lbTarget.Items.Count;
	    
	    for i = 1 to count do
	    (
	        local source = GetNodeByName lbSource.Items[i];
	        local target = GetNodeByName lbTarget.Items[i];
	        if ( source == undefined or target == undefined ) then continue;
	        
	        local backup = bcmObjectBackupData();
	        backup.Name = source.Name;
	        backup.PosController = source.pos.controller;
	        backup.RotController = source.rotation.controller;
	        append g_bcmObjectBackupDataList backup;
	        
	        if ( ddlPosContraintMode.Selected != "None" ) then
	            bcmAddPosContraint source target relative:(ddlPosContraintMode.Selected == "Relative");
	        
	        if ( ddlRotConstrainMode.Selected != "None" ) then
	            bcmAddOrientConstraint source target relative:(ddlRotConstrainMode.Selected == "Relative");
	    )
	)
	on btnMoveUp pressed do
	(
        lbMoveSelectedItem g_bcmLastSelectedList -1;
	)
	on btnMoveDown pressed do
	(
        lbMoveSelectedItem g_bcmLastSelectedList 1;
	)
	on btnMatchByName pressed do
	(
	    local newSourceList = #();
	    local remainingSourceNames = #();
	    for name in lbSource.Items do
	        append remainingSourceNames name;
	    
	    for i = 1 to lbTarget.Items.Count do
	    (
	        local targetName = lbTarget.Items[i];
	        local sourceName = strSwapPrefixSuffix targetName \
	            tbTargetPrefix.Text tbTargetSuffix.Text \
	            tbSourcePrefix.Text tbSourceSuffix.Text;
	        
	        local sourceNameIndex = findItem lbSource.Items sourceName;
	        if ( sourceNameIndex == 0 ) then
	        (
	            sourceName = "";
	        )
	        else
	        (
	            local remainingSourceNameIndex = findItem remainingSourceNames sourceName;
	            if ( remainingSourceNameIndex != 0 ) then deleteItem remainingSourceNames remainingSourceNameIndex;
	        )
	        
	        newSourceList[i] = sourceName;
	    )
	    
	    for name in remainingSourceNames do
	        append newSourceList name;
	    
	    lbSource.Items = newSourceList;
	)
	on btnSourceAddSelection pressed do
	(
        lbAddSelection lbSource;
	)
	on btnTargetAddSelection pressed do
	(
	    lbAddSelection lbTarget;
	)
	on btnSourceAddPrefix pressed do
	(
	    lbAddPrefixForAllItems lbSource tbSourcePrefix.Text;
	)
	on btnTargetAddPrefix pressed do
	(
	    lbAddPrefixForAllItems lbTarget tbTargetPrefix.Text;
	)
	on btnSourceClearSelection pressed do
	(
	    lbSource.Items = #();
	)
	on btnTargetClearSelection pressed do
	(
	    lbTarget.Items = #();
	)
	on btnSourceRemovePrefix pressed do
	(
	    lbRemoveSuffixForAllItems lbSource tbSourcePrefix.Text;
	)
	on btnTargetRemovePrefix pressed do
	(
	    lbRemoveSuffixForAllItems lbTarget tbTargetPrefix.Text;
	)
	on btnReset pressed do
	(
	    bcmResetObjectControllers();
	)
	on btnDelete pressed do
	(
        lbMoveSelectedItem g_bcmLastSelectedList;
	)
	on btnSourceAddSuffix pressed do
	(
	    lbAddSuffixForAllItems lbSource tbSourceSuffix.Text;
	)
	on btnSourceRemoveSuffix pressed do
	(
	    lbRemoveSuffixForAllItems lbSource tbSourceSuffix.Text;
	)
	on btnTargetAddSuffix pressed do
	(
	    lbAddSuffixForAllItems lbTarget tbTargetSuffix.Text;
	)
	on btnTargetRemoveSuffix pressed do
	(
	    lbRemoveSuffixForAllItems lbTarget tbTargetSuffix.Text;
	)
	on btnLoad pressed do
	(
	    local filePath = ioSelectOpenFile "Bone constraint map" "bcm";
        if ( filePath != undefined ) then
        (
            local fs = openFile filePath mode:"rt" encoding:#utf16LE;
            if ( fs == undefined ) then
            (
                messageBox "Unable to open the file" title:"Error";
            )
            else
            (
                try
                (
                    local sourceNames = #();
                    local targetNames = #();
                    
                    while ( not ( eof fs ) ) do
                    (
                        local sourceName = readDelimitedString fs "\t";
                        local targetName = readDelimitedString fs "\n";
                        append sourceNames sourceName;
                        append targetNames targetName;
                    )
                    
                    lbSource.Items = sourceNames;
                    lbTarget.Items = targetNames;
                ) 
                catch
                (
                    print (getCurrentException());
                )
            
                close fs;
            )
        )
	)
	on btnSave pressed do
	(
	    local filePath = ioSelectSaveFile "Bone constraint map" "bcm";
        if ( filePath != undefined ) then
        (
            local fs = createFile filePath encoding:#utf16LE;
            if ( fs == undefined ) then
            (
                messageBox "Unable to open the file" title:"Error";
            )
            else
            (
                try
                (
                    for i = 1 to lbSource.Items.Count do
                    (
                        local sourceName = lbSource.Items[i];
                        local targetName = "";
                        if ( i <= lbTarget.Items.Count ) then
                            targetName = lbTarget.Items[i];
                        
                        format "%\t%\n" sourceName targetName to:fs;
                    )
                ) 
                catch
                (
                    print (getCurrentException());
                )
                
                flush fs;
                close fs;
            )
        )
	)
)

fn main =
(
    clearListener();
    CreateDialog bcmRollout;
)

main();
