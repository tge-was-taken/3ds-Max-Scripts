
FileIn "include\\Loader.ms"

-- Entry point
fn Main = 
(   
    try (
    local loader = ModelLoader();
    --loader.LoadModelFile( @"D:\Games\PC\SteamLibrary\steamapps\common\Sonic Adventure 2\_\mdl files\sonicmdl.prs" );
    loader.LoadModelFile( @"D:\Users\smart\Documents\visual studio 2017\Projects\SAModelLibrary\SA2ModelConverter\bin\Debug\test.mdl" );
    loader.ImportMainObject();
    --loader.ImportObjectByIndex( 1 );
    --loader.ImportObjectById( 0 );
    --loader.LoadAnimationFile( @"D:\Games\PC\SteamLibrary\steamapps\common\Sonic Adventure 2\_\mtn files\plcommtn.prs" );
    --loader.LoadAnimationByIndex( 11 );
    ) catch ( Format (getCurrentException()) )
    
    return OK;
)

-- Start scriptz
Main();

