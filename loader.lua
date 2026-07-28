local SynSaveInstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/visionarytools/tool1/refs/heads/main/source/source.lua", true), "saveinstance")()

local Options = {
    SafeMode = false,
    SetStreaming = false,
    DecompilePrepass = true,
    NeutralizeLighting = true,
    mode = "full"
}

SynSaveInstance(Options)
