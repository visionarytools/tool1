local SynSaveInstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/visionarytools/tool2/refs/heads/main/source.lua", true), "saveinstance")()

local Options = {
    SafeMode = false,
    SetStreaming = false,
    DecompilePrepass = true,
    NeutralizeLighting = true,
    mode = "full"
}

SynSaveInstance(Options)
