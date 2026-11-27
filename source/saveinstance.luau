local __SSI_VERSION = "[REVAMPED]"

local __modules, __loaded = {}, {}
local function require(name)
	local cached = __loaded[name]
	if cached ~= nil then return cached end
	local loader = __modules[name]
	if not loader then error("SaveInstance: missing module " .. tostring(name), 2) end
	local result = loader()
	if result == nil then result = true end
	__loaded[name] = result
	return result
end

__modules["attributes"] = function()
-- Builds Instance.AttributesSerialize from GetAttributes().
-- Format: u32 count, then per attribute (sorted by name): string name, u8 type id, value.
-- Strings are u32-length-prefixed. Spec: github.com/RobloxAPI/spec (AttributesSerialize).
local Attributes = {}

local pack = string.pack

-- Exact axis-aligned rotation matrices get a one-byte id instead of nine floats.
-- Keys are the nine rotation components packed as little-endian float32 (R00..R22).
local ROTATION_IDS = {
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x02,
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x03,
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x05,
	["\0\0\128\63\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x06,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x07,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x09,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x0a,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x0c,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x0d,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x0e,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x10,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\128"] = 0x11,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x14,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\128"] = 0x15,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x17,
	["\0\0\128\191\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\191\0\0\0\128"] = 0x18,
	["\0\0\0\0\0\0\128\63\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x19,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x1b,
	["\0\0\0\0\0\0\128\191\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x1c,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x1e,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x1f,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x20,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x22,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\191\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\128"] = 0x23,
}

local function font(value)
	local okWeight, weight = pcall(function()
		return value.Weight.Value
	end)
	local okStyle, style = pcall(function()
		return value.Style.Value
	end)
	return pack("<I2B", okWeight and weight or 400, okStyle and style or 0) .. pack("<s4s4", value.Family, "")
end

-- typeof(value) -> function returning (type id, encoded value)
local WRITERS = {
	string = function(v)
		return 0x02, pack("<s4", v)
	end,
	boolean = function(v)
		return 0x03, pack("<B", v and 1 or 0)
	end,
	number = function(v)
		return 0x06, pack("<d", v)
	end,
	UDim = function(v)
		return 0x09, pack("<fi4", v.Scale, v.Offset)
	end,
	UDim2 = function(v)
		return 0x0A, pack("<fi4fi4", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
	end,
	BrickColor = function(v)
		return 0x0E, pack("<I4", v.Number)
	end,
	Color3 = function(v)
		return 0x0F, pack("<fff", v.R, v.G, v.B)
	end,
	Vector2 = function(v)
		return 0x10, pack("<ff", v.X, v.Y)
	end,
	Vector3 = function(v)
		return 0x11, pack("<fff", v.X, v.Y, v.Z)
	end,
	CFrame = function(v)
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = v:GetComponents()
		local rotation = pack("<fffffffff", r00, r01, r02, r10, r11, r12, r20, r21, r22)
		local id = ROTATION_IDS[rotation]
		if id then
			return 0x14, pack("<fffB", x, y, z, id)
		end
		return 0x14, pack("<fffB", x, y, z, 0) .. rotation
	end,
	EnumItem = function(v)
		return 0x15, pack("<s4I4", tostring(v.EnumType), v.Value)
	end,
	NumberSequence = function(v)
		local keypoints = v.Keypoints
		local parts = { pack("<I4", #keypoints) }
		for _, keypoint in keypoints do
			table.insert(parts, pack("<fff", keypoint.Envelope, keypoint.Time, keypoint.Value))
		end
		return 0x17, table.concat(parts)
	end,
	ColorSequence = function(v)
		local keypoints = v.Keypoints
		local parts = { pack("<I4", #keypoints) }
		for _, keypoint in keypoints do
			local color = keypoint.Value
			table.insert(parts, pack("<fffff", 0, keypoint.Time, color.R, color.G, color.B))
		end
		return 0x19, table.concat(parts)
	end,
	NumberRange = function(v)
		return 0x1B, pack("<ff", v.Min, v.Max)
	end,
	Rect = function(v)
		return 0x1C, pack("<ffff", v.Min.X, v.Min.Y, v.Max.X, v.Max.Y)
	end,
	Font = function(v)
		return 0x21, font(v)
	end,
}

-- Returns the serialized blob ("" when the instance has no attributes).
function Attributes.serialize(instance)
	local attributes = instance:GetAttributes()
	if next(attributes) == nil then
		return ""
	end
	local names = {}
	for name in attributes do
		table.insert(names, name)
	end
	table.sort(names)

	local parts = { "" }
	local count = 0
	for _, name in names do
		local value = attributes[name]
		local writer = WRITERS[typeof(value)]
		if writer then
			local ok, id, encoded = pcall(writer, value)
			if ok then
				count += 1
				table.insert(parts, pack("<s4B", name, id) .. encoded)
			end
		end
	end
	parts[1] = pack("<I4", count)
	return table.concat(parts)
end

return Attributes
end

__modules["collect"] = function()
-- Decides what goes into the file: root services or model objects, ignore rules, player
-- characters, engine-injected scripts, nil instances and the extras folder.
local Schema = require("schema")
local Quirks = require("quirks")
local Env = require("env")
local Util = require("util")
local Log = require("log")

local Collect = {}

local Players = game:GetService("Players")

-- Services written for a place save, in file order. ServerStorage is written separately
-- by the serializer because it also carries the extras folder.
local PLACE_SERVICES = {
	"Workspace", "Players", "Lighting", "MaterialService", "ReplicatedFirst", "ReplicatedStorage",
	"StarterGui", "StarterPack", "StarterPlayer", "Teams", "SoundService", "Chat", "TextChatService",
	"LocalizationService", "ProximityPromptService", "VoiceChatService", "ServerScriptService",
}

-- List entries (IgnoreList, DecompileIgnore):
--   instance | "ClassName" | ClassName = true | ClassName = { "Name", ... }  -> "tree"
--   [instance] = false                                                         -> "self"
local function matcher(list)
	local instances, classes, named = {}, {}, {}
	if type(list) == "table" then
		for key, value in list do
			if type(key) == "number" then
				if typeof(value) == "Instance" then
					instances[value] = "tree"
				elseif type(value) == "string" then
					classes[value] = true
				end
			elseif typeof(key) == "Instance" then
				instances[key] = value == false and "self" or "tree"
			elseif type(key) == "string" then
				if type(value) == "table" then
					local names = {}
					for _, name in value do
						names[name] = true
					end
					named[key] = names
				elseif value then
					classes[key] = true
				end
			end
		end
	end
	return function(instance, className)
		local hit = instances[instance]
		if hit then
			return hit
		elseif classes[className] then
			return "tree"
		end
		local names = named[className]
		if names and names[instance.Name] then
			return "tree"
		end
		return nil
	end
end

function Collect.rules(options)
	local ignore = matcher(options.IgnoreList)
	local decompileIgnore = matcher(options.DecompileIgnore)
	local saveNotArchivable = options.IgnoreNotArchivable ~= false

	local characters = {}
	if options.RemovePlayerCharacters then
		for _, player in Players:GetPlayers() do
			if player.Character then
				characters[player.Character] = true
			end
		end
	end

	local starterPlayerScripts
	if options.IgnoreDefaultPlayerScripts then
		pcall(function()
			starterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
		end)
	end

	local rules = { only = nil }

	-- True when the instance and everything under it stays out of the file.
	function rules.skip(instance, className)
		if characters[instance] or ignore(instance, className) == "tree" then
			return true
		end
		if not saveNotArchivable and not instance.Archivable then
			return true
		end
		if starterPlayerScripts and instance.Parent == starterPlayerScripts
			and Quirks.defaultPlayerScripts[instance.Name] == className then
			return true
		end
		return false
	end

	function rules.children(instance)
		if ignore(instance, instance.ClassName) == "self" then
			return {}
		end
		local children = instance:GetChildren()
		local kept = table.create(#children)
		local only = rules.only
		for _, child in children do
			if not rules.skip(child, child.ClassName) and (not only or only[child]) then
				table.insert(kept, child)
			end
		end
		return kept
	end

	-- "tree", "self" or nil
	function rules.decompileIgnored(instance, className)
		return decompileIgnore(instance, className)
	end

	return rules
end

local function filteredNilInstances(own)
	local list = {}
	if not Env.getnilinstances then
		Log.warn("NilInstances: this executor has no getnilinstances()")
		return list
	end
	local ok, instances = pcall(Env.getnilinstances)
	if not ok or type(instances) ~= "table" then
		return list
	end
	for _, instance in instances do
		if typeof(instance) == "Instance" and instance ~= game and not own[instance] then
			local info = Schema.classInfo(instance.ClassName)
			if info.saveable and not info.service then
				table.insert(list, instance)
			end
		end
	end
	return list
end

-- Builds the job: roots, extras, rules, the scripts to decompile and a size estimate.
function Collect.build(options)
	local rules = Collect.rules(options)
	local job = { roots = {}, extras = {}, scripts = {}, estimate = 0, isModel = options.IsModel == true, rules = rules }

	if options.Object then
		local objects = typeof(options.Object) == "Instance" and { options.Object } or options.Object
		for _, object in objects do
			if typeof(object) == "Instance" then
				table.insert(job.roots, object)
			end
		end
		if #job.roots == 0 then
			error("Object must be an Instance or a list of Instances", 0)
		end
	elseif options.Mode == "full" then
		for _, child in game:GetChildren() do
			local className = child.ClassName
			if className ~= "ServerStorage" and Schema.classInfo(className).saveable and not rules.skip(child, className) then
				table.insert(job.roots, child)
			end
		end
	else
		for _, name in PLACE_SERVICES do
			local service = game:FindService(name)
			if service and Schema.classInfo(service.ClassName).saveable and not rules.skip(service, service.ClassName) then
				table.insert(job.roots, service)
			end
		end
	end

	if not job.isModel then
		local localPlayer = Players.LocalPlayer
		if options.IsolateLocalPlayer and localPlayer then
			table.insert(job.extras, { name = "LocalPlayer", contents = localPlayer:GetChildren(), folderize = true })
		end
		if options.IsolateLocalPlayerCharacter and localPlayer and localPlayer.Character then
			table.insert(job.extras, { name = "LocalPlayer Character", contents = { localPlayer.Character }, folderize = true })
		end
		if options.IsolatePlayers then
			table.insert(job.extras, { name = "Players", contents = Players:GetPlayers(), folderize = true })
		end
		if options.IsolateStarterPlayer then
			table.insert(job.extras, { name = "StarterPlayer", contents = game:GetService("StarterPlayer"):GetChildren(), folderize = true })
		end
		if type(options.ExtraInstances) == "table" and #options.ExtraInstances > 0 then
			table.insert(job.extras, { name = "Extra Instances", contents = options.ExtraInstances, folderize = true })
		end
		if options.NilInstances then
			table.insert(job.extras, { name = "Nil Instances", contents = filteredNilInstances(Schema.ownInstances()), folderize = false })
		end
	end

	-- One pass over everything that will be written: counts instances for the progress bar,
	-- lists the scripts to decompile, and (scripts mode) marks branches that hold scripts.
	local scriptsOnly = options.Mode == "scripts" and not options.Object
	local holdsScripts = scriptsOnly and {} or nil
	local folderizeAll = options.SaveNotCreatable
	local function walk(instance, ignoredDepth, folderize, isRoot)
		Util.step()
		local className = instance.ClassName
		-- Mirror the writer: anything it leaves out (and everything under it) is skipped here,
		-- so no time goes into decompiling scripts that never reach the file.
		local info = Schema.classInfo(className)
		if (info.service and not isRoot) or ((not info.saveable or not info.known) and not (folderize or folderizeAll)) then
			return false
		end
		job.estimate += 1
		local mark = rules.decompileIgnored(instance, className)
		local isScript = instance:IsA("LuaSourceContainer")
		if isScript and ignoredDepth == 0 and mark == nil then
			table.insert(job.scripts, instance)
		end
		local childDepth = ignoredDepth + (mark == "tree" and 1 or 0)
		local found = isScript
		for _, child in rules.children(instance) do
			if walk(child, childDepth, folderize, false) then
				found = true
			end
		end
		if found and holdsScripts then
			holdsScripts[instance] = true
		end
		return found
	end
	for _, root in job.roots do
		walk(root, 0, job.isModel, true)
	end
	for _, extra in job.extras do
		for _, instance in extra.contents do
			if typeof(instance) == "Instance" then
				walk(instance, 0, extra.folderize, false)
			end
		end
	end
	rules.only = holdsScripts
	return job
end

return Collect
end

__modules["encode"] = function()
-- XML value encoders, one per serialized value type.
-- Each returns the inner XML of a property element, or nil to leave the property out
-- (wrong value type, unsupported content). Formats follow Roblox's XML format as
-- implemented by rbx-dom (rbx_xml/src/types).
local Env = require("env")

local Encode = {}

local format, floor, find, gsub, typeof, tostring = string.format, math.floor, string.find, string.gsub, typeof, tostring
local HUGE = math.huge

local ContentSourceType
pcall(function()
	ContentSourceType = Enum.ContentSourceType
end)

-- Numbers --------------------------------------------------------------------------------
local function f32(x) -- float32 round-trips with 9 significant digits
	if x ~= x then
		return "NAN"
	elseif x == HUGE then
		return "INF"
	elseif x == -HUGE then
		return "-INF"
	elseif x == floor(x) and x > -1e9 and x < 1e9 then
		return format("%d", x)
	end
	return format("%.9g", x)
end

local function f64(x)
	if x ~= x then
		return "NAN"
	elseif x == HUGE then
		return "INF"
	elseif x == -HUGE then
		return "-INF"
	elseif x == floor(x) and x > -1e15 and x < 1e15 then
		return format("%d", x)
	end
	return format("%.17g", x)
end

local function int(x)
	if x ~= x or x == HUGE or x == -HUGE then
		return "0"
	end
	return format("%d", floor(x))
end

local function f32range(x) -- ranges and sequences reset to zero on NaN in Studio
	return x ~= x and "0" or f32(x)
end

Encode.f32, Encode.f64, Encode.int = f32, f64, int

-- Text -----------------------------------------------------------------------------------
-- Plain printable ASCII is written as-is; anything else goes into CDATA, which keeps
-- newlines, tabs and UTF-8 byte-exact. NUL cannot appear in XML at all and is dropped.
local function text(s)
	if s == "" then
		return ""
	end
	if not find(s, "[^%w%p ]") and not find(s, "[&<>]") and not find(s, "^ ") and not find(s, " $") then
		return s
	end
	if find(s, "\0", 1, true) then
		s = gsub(s, "\0", "")
	end
	if find(s, "]]>", 1, true) then
		s = gsub(s, "%]%]>", "]]]]><![CDATA[>")
	end
	return "<![CDATA[" .. s .. "]]>"
end

local function cdata(s)
	if find(s, "\0", 1, true) then
		s = gsub(s, "\0", "")
	end
	if find(s, "]]>", 1, true) then
		s = gsub(s, "%]%]>", "]]]]><![CDATA[>")
	end
	return "<![CDATA[" .. s .. "]]>"
end

local ATTRIBUTE_ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }
local function attribute(s)
	if find(s, '[&<>"]') then
		s = gsub(s, '[&<>"]', ATTRIBUTE_ESCAPES)
	end
	return s
end

Encode.text, Encode.cdata, Encode.attribute = text, cdata, attribute

-- Compound values -------------------------------------------------------------------------
local function vector3(v)
	return "<X>" .. f32(v.X) .. "</X><Y>" .. f32(v.Y) .. "</Y><Z>" .. f32(v.Z) .. "</Z>"
end

local function cframe(v)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = v:GetComponents()
	return "<X>" .. f32(x) .. "</X><Y>" .. f32(y) .. "</Y><Z>" .. f32(z)
		.. "</Z><R00>" .. f32(r00) .. "</R00><R01>" .. f32(r01) .. "</R01><R02>" .. f32(r02)
		.. "</R02><R10>" .. f32(r10) .. "</R10><R11>" .. f32(r11) .. "</R11><R12>" .. f32(r12)
		.. "</R12><R20>" .. f32(r20) .. "</R20><R21>" .. f32(r21) .. "</R21><R22>" .. f32(r22) .. "</R22>"
end

local function colorByte(channel)
	local b = floor(channel * 255 + 0.5)
	return b < 0 and 0 or b > 255 and 255 or b
end

local function uriOf(v)
	if type(v) == "string" then
		return v
	end
	if typeof(v) == "Content" and ContentSourceType then
		local sourceType = v.SourceType
		if sourceType == ContentSourceType.None then
			return ""
		elseif sourceType == ContentSourceType.Uri then
			return v.Uri or ""
		end
	end
	return nil -- Object-backed content (EditableImage, ...) cannot be stored in a file
end

local CAPABILITY_BITS = {
	Plugin = 2 ^ 0, LocalUser = 2 ^ 1, WritePlayer = 2 ^ 2, RobloxScript = 2 ^ 3, RobloxEngine = 2 ^ 4,
	NotAccessible = 2 ^ 5, RunClientScript = 2 ^ 8, RunServerScript = 2 ^ 9, AccessOutsideWrite = 2 ^ 11,
	Unassigned = 2 ^ 15, AssetRequire = 2 ^ 16, LoadString = 2 ^ 17, ScriptGlobals = 2 ^ 18,
	CreateInstances = 2 ^ 19, Basic = 2 ^ 20, Audio = 2 ^ 21, DataStore = 2 ^ 22, Network = 2 ^ 23,
	Physics = 2 ^ 24, UI = 2 ^ 25, CSG = 2 ^ 26, Chat = 2 ^ 27, Animation = 2 ^ 28, Avatar = 2 ^ 29,
	Input = 2 ^ 30, Environment = 2 ^ 31, RemoteEvent = 2 ^ 32, LegacySound = 2 ^ 33, Players = 2 ^ 34,
	CapabilityControl = 2 ^ 35, InternalTest = 2 ^ 60, PluginOrOpenCloud = 2 ^ 61, Assistant = 2 ^ 62,
}

-- Encoders --------------------------------------------------------------------------------
local E = {}

function E.bool(v)
	if type(v) == "boolean" then
		return v and "true" or "false"
	end
end

function E.int(v)
	if type(v) == "number" then
		return int(v)
	end
end
E.int64 = E.int

function E.float(v)
	if type(v) == "number" then
		return f32(v)
	end
end

function E.double(v)
	if type(v) == "number" then
		return f64(v)
	end
end

function E.string(v)
	if type(v) == "string" then
		return text(v)
	end
end

function E.ProtectedString(v)
	if type(v) == "string" then
		return cdata(v)
	end
end

function E.BinaryString(v)
	if type(v) == "string" then
		return v == "" and "" or Env.base64encode(v)
	end
end

function E.SharedString(v, ctx)
	if type(v) == "string" then
		return ctx.shared(v)
	end
end
E.NetAssetRef = E.SharedString

function E.ContentId(v)
	local uri = uriOf(v)
	if uri then
		return uri == "" and "<null></null>" or "<url>" .. text(uri) .. "</url>"
	end
end

function E.Content(v)
	local uri = uriOf(v)
	if uri then
		return uri == "" and "<null></null>" or "<uri>" .. text(uri) .. "</uri>"
	end
end

function E.token(v)
	if typeof(v) == "EnumItem" then
		return tostring(v.Value)
	elseif type(v) == "number" then
		return int(v)
	end
end

function E.Ref(v, ctx)
	if v == nil then
		return "null"
	elseif typeof(v) == "Instance" then
		return ctx.ref(v)
	end
end

function E.Vector2(v)
	if typeof(v) == "Vector2" then
		return "<X>" .. f32(v.X) .. "</X><Y>" .. f32(v.Y) .. "</Y>"
	end
end

function E.Vector2int16(v)
	if typeof(v) == "Vector2int16" then
		return "<X>" .. int(v.X) .. "</X><Y>" .. int(v.Y) .. "</Y>"
	end
end

function E.Vector3(v)
	if typeof(v) == "Vector3" then
		return vector3(v)
	end
end

function E.Vector3int16(v)
	if typeof(v) == "Vector3int16" then
		return "<X>" .. int(v.X) .. "</X><Y>" .. int(v.Y) .. "</Y><Z>" .. int(v.Z) .. "</Z>"
	end
end

function E.CFrame(v)
	if typeof(v) == "CFrame" then
		return cframe(v)
	end
end

function E.OptionalCFrame(v) -- nil means "not set": the property is left out
	if typeof(v) == "CFrame" then
		return "<CFrame>" .. cframe(v) .. "</CFrame>"
	end
end

function E.Color3(v)
	if typeof(v) == "Color3" then
		return "<R>" .. f32(v.R) .. "</R><G>" .. f32(v.G) .. "</G><B>" .. f32(v.B) .. "</B>"
	end
end

function E.Color3uint8(v)
	if typeof(v) == "Color3" then
		return format("%.0f", 4278190080 + colorByte(v.R) * 65536 + colorByte(v.G) * 256 + colorByte(v.B))
	end
end

function E.BrickColor(v)
	if typeof(v) == "BrickColor" then
		return tostring(v.Number)
	elseif type(v) == "number" then
		return int(v)
	end
end

function E.UDim(v)
	if typeof(v) == "UDim" then
		return "<S>" .. f32(v.Scale) .. "</S><O>" .. int(v.Offset) .. "</O>"
	end
end

function E.UDim2(v)
	if typeof(v) == "UDim2" then
		local x, y = v.X, v.Y
		return "<XS>" .. f32(x.Scale) .. "</XS><XO>" .. int(x.Offset) .. "</XO><YS>" .. f32(y.Scale) .. "</YS><YO>"
			.. int(y.Offset) .. "</YO>"
	end
end

function E.Rect(v)
	if typeof(v) == "Rect" then
		local min, max = v.Min, v.Max
		return "<min><X>" .. f32(min.X) .. "</X><Y>" .. f32(min.Y) .. "</Y></min><max><X>" .. f32(max.X) .. "</X><Y>"
			.. f32(max.Y) .. "</Y></max>"
	end
end

function E.NumberRange(v)
	if typeof(v) == "NumberRange" then
		return f32range(v.Min) .. " " .. f32range(v.Max)
	end
end

function E.NumberSequence(v)
	if typeof(v) == "NumberSequence" then
		local parts = {}
		for i, keypoint in v.Keypoints do
			parts[i] = f32range(keypoint.Time) .. " " .. f32range(keypoint.Value) .. " " .. f32range(keypoint.Envelope) .. " "
		end
		return table.concat(parts)
	end
end

function E.ColorSequence(v)
	if typeof(v) == "ColorSequence" then
		local parts = {}
		for i, keypoint in v.Keypoints do
			local color = keypoint.Value
			parts[i] = f32range(keypoint.Time) .. " " .. f32range(color.R) .. " " .. f32range(color.G) .. " "
				.. f32range(color.B) .. " 0 "
		end
		return table.concat(parts)
	end
end

function E.PhysicalProperties(v)
	if v == nil then
		return "<CustomPhysics>false</CustomPhysics>"
	elseif typeof(v) == "PhysicalProperties" then
		local xml = "<CustomPhysics>true</CustomPhysics><Density>" .. f32(v.Density) .. "</Density><Friction>"
			.. f32(v.Friction) .. "</Friction><Elasticity>" .. f32(v.Elasticity) .. "</Elasticity><FrictionWeight>"
			.. f32(v.FrictionWeight) .. "</FrictionWeight><ElasticityWeight>" .. f32(v.ElasticityWeight)
			.. "</ElasticityWeight>"
		local ok, absorption = pcall(function()
			return v.AcousticAbsorption
		end)
		if ok and type(absorption) == "number" then
			xml ..= "<AcousticAbsorption>" .. f32(absorption) .. "</AcousticAbsorption>"
		end
		return xml
	end
end

function E.Ray(v)
	if typeof(v) == "Ray" then
		return "<origin>" .. vector3(v.Origin) .. "</origin><direction>" .. vector3(v.Direction) .. "</direction>"
	end
end

function E.Faces(v)
	if typeof(v) == "Faces" then
		local bits = (v.Right and 1 or 0) + (v.Top and 2 or 0) + (v.Back and 4 or 0) + (v.Left and 8 or 0)
			+ (v.Bottom and 16 or 0) + (v.Front and 32 or 0)
		return "<faces>" .. bits .. "</faces>"
	end
end

function E.Axes(v)
	if typeof(v) == "Axes" then
		return "<axes>" .. ((v.X and 1 or 0) + (v.Y and 2 or 0) + (v.Z and 4 or 0)) .. "</axes>"
	end
end

function E.Font(v)
	if typeof(v) == "Font" then
		local okWeight, weight = pcall(function()
			return v.Weight.Value
		end)
		local okStyle, style = pcall(function()
			return v.Style.Name
		end)
		local family = v.Family
		return "<Family>" .. (family == "" and "<null></null>" or "<url>" .. text(family) .. "</url>")
			.. "</Family><Weight>" .. (okWeight and weight or 400) .. "</Weight><Style>"
			.. (okStyle and style or "Normal") .. "</Style>"
	end
end

function E.SecurityCapabilities(v)
	if typeof(v) == "SecurityCapabilities" then
		local total = 0
		for _, flag in string.split(tostring(v), " | ") do
			total += CAPABILITY_BITS[flag] or 0
		end
		return format("%.0f", total)
	end
end

-- XML element name per value type.
local TAGS = {
	bool = "bool", int = "int", int64 = "int64", float = "float", double = "double", string = "string",
	ProtectedString = "ProtectedString", BinaryString = "BinaryString", SharedString = "SharedString",
	NetAssetRef = "NetAssetRef", Content = "Content", ContentId = "ContentId", token = "token", Ref = "Ref",
	Vector2 = "Vector2", Vector2int16 = "Vector2int16", Vector3 = "Vector3", Vector3int16 = "Vector3int16",
	CFrame = "CoordinateFrame", OptionalCFrame = "OptionalCoordinateFrame", Color3 = "Color3",
	Color3uint8 = "Color3uint8", BrickColor = "BrickColor", UDim = "UDim", UDim2 = "UDim2", Rect = "Rect2D",
	NumberRange = "NumberRange", NumberSequence = "NumberSequence", ColorSequence = "ColorSequence",
	PhysicalProperties = "PhysicalProperties", Ray = "Ray", Faces = "Faces", Axes = "Axes", Font = "Font",
	SecurityCapabilities = "SecurityCapabilities",
}

Encode.encoders = E

function Encode.supports(valueType)
	return E[valueType] ~= nil
end

function Encode.tags(valueType, name)
	local tag = TAGS[valueType]
	return "<" .. tag .. ' name="' .. attribute(name) .. '">', "</" .. tag .. ">"
end

return Encode
end

__modules["env"] = function()
-- Executor capability detection.
-- Functions are looked up by their known names only. Nothing is downloaded and nothing is
-- fuzzy-matched; the old method finder came from a repository that no longer exists.
local Env = {}

local function first(...)
	for i = 1, select("#", ...) do
		local candidate = select(i, ...)
		if type(candidate) == "function" then
			return candidate
		end
	end
	return nil
end

local function field(container, key)
	if type(container) ~= "table" and type(container) ~= "userdata" then
		return nil
	end
	local ok, value = pcall(function()
		return container[key]
	end)
	return ok and value or nil
end

Env.gethiddenproperty = first(gethiddenproperty)
Env.sethiddenproperty = first(sethiddenproperty)
Env.getscriptbytecode = first(getscriptbytecode, get_script_bytecode)
Env.decompile = first(decompile)
Env.getnilinstances = first(getnilinstances, get_nil_instances)
Env.writefile = first(writefile)
Env.appendfile = first(appendfile)
Env.readfile = first(readfile)
Env.isfile = first(isfile)
Env.isfolder = first(isfolder)
Env.makefolder = first(makefolder)
Env.delfile = first(delfile)
Env.request = first(request, http_request, field(syn, "request"), field(http, "request"), field(fluxus, "request"))
Env.gethui = first(gethui, get_hidden_gui)
Env.protectgui = first(protectgui, field(syn, "protect_gui"))
Env.setthreadidentity = first(setthreadidentity, set_thread_identity, setidentity, field(syn, "set_thread_identity"))
Env.getthreadidentity = first(getthreadidentity, get_thread_identity, getidentity, field(syn, "get_thread_identity"))
Env.getconnections = first(getconnections, get_signal_cons)
Env.setclipboard = first(setclipboard, toclipboard, set_clipboard)

do
	local identify = first(identifyexecutor, getexecutorname, whatexecutor)
	local name = "Unknown executor"
	if identify then
		local ok, executor, version = pcall(identify)
		if ok and executor then
			name = tostring(executor) .. (version and (" " .. tostring(version)) or "")
		end
	end
	Env.executor = name
end

local EncodingService
pcall(function()
	EncodingService = game:GetService("EncodingService")
end)
Env.EncodingService = EncodingService

-- Base64 ----------------------------------------------------------------------------
-- Preference: the engine's EncodingService (native, identical on every executor), then
-- the executor's own encoder, then a pure-Luau encoder. Every candidate must reproduce a
-- known vector before it is trusted: some executors' helpers have returned odd output.
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ALPHABET_BYTES = buffer.fromstring(ALPHABET)

local function pureBase64(input)
	local length = #input
	if length == 0 then
		return ""
	end
	local source = buffer.fromstring(input)
	local out = buffer.create(math.ceil(length / 3) * 4)
	local readu8, writeu8 = buffer.readu8, buffer.writeu8
	local i, o = 0, 0
	while i + 2 < length do
		local n = readu8(source, i) * 65536 + readu8(source, i + 1) * 256 + readu8(source, i + 2)
		writeu8(out, o, readu8(ALPHABET_BYTES, n // 262144))
		writeu8(out, o + 1, readu8(ALPHABET_BYTES, (n // 4096) % 64))
		writeu8(out, o + 2, readu8(ALPHABET_BYTES, (n // 64) % 64))
		writeu8(out, o + 3, readu8(ALPHABET_BYTES, n % 64))
		i += 3
		o += 4
	end
	local rest = length - i
	if rest > 0 then
		local n = readu8(source, i) * 65536 + (rest == 2 and readu8(source, i + 1) * 256 or 0)
		writeu8(out, o, readu8(ALPHABET_BYTES, n // 262144))
		writeu8(out, o + 1, readu8(ALPHABET_BYTES, (n // 4096) % 64))
		writeu8(out, o + 2, rest == 2 and readu8(ALPHABET_BYTES, (n // 64) % 64) or 61)
		writeu8(out, o + 3, 61)
	end
	return buffer.tostring(out)
end

do
	local VECTOR_IN, VECTOR_OUT = "\0\1\2\255abc", "AAEC/2FiYw=="
	local candidates = {}
	if EncodingService then
		table.insert(candidates, {
			"EncodingService",
			function(input)
				return buffer.tostring(EncodingService:Base64Encode(buffer.fromstring(input)))
			end,
		})
	end
	local crypt = crypt
	for _, entry in
		{
			{ "crypt.base64encode", field(crypt, "base64encode") },
			{ "crypt.base64.encode", field(field(crypt, "base64"), "encode") },
			{ "base64encode", base64encode },
			{ "base64_encode", base64_encode },
			{ "base64.encode", field(base64, "encode") },
		}
	do
		if type(entry[2]) == "function" then
			table.insert(candidates, entry)
		end
	end
	table.insert(candidates, { "pure Luau", pureBase64 })

	for _, candidate in candidates do
		local ok, output = pcall(candidate[2], VECTOR_IN)
		if ok and output == VECTOR_OUT then
			Env.base64encode = candidate[2]
			Env.base64source = candidate[1]
			break
		end
	end
end

-- Hashing (cache keys for decompiled sources) ---------------------------------------
do
	local algorithm
	pcall(function()
		algorithm = Enum.HashAlgorithm.Blake3
	end)
	local native = EncodingService
		and algorithm
		and pcall(EncodingService.ComputeStringHash, EncodingService, "probe", algorithm)
		and function(input)
			return EncodingService:ComputeStringHash(input, algorithm)
		end

	-- FNV-1a over the whole string plus its length: only used if the engine hash is gone.
	local function fallback(input)
		local h1, h2 = 2166136261, 5381
		local data = buffer.fromstring(input)
		for i = 0, #input - 1 do
			local byte = buffer.readu8(data, i)
			h1 = bit32.bxor(h1, byte)
			h1 = (h1 * 16777619) % 4294967296
			h2 = (h2 * 33 + byte) % 4294967296
		end
		return string.format("%d:%08x%08x", #input, h1, h2)
	end

	Env.hash = native or fallback
	Env.hashSource = native and "EncodingService Blake3" or "FNV-1a"
end

-- SharedString keys: Roblox uses a 16-byte hash (historically MD5) encoded as base64.
-- Any unique 16-byte key loads, so a counter is the fallback.
do
	local md5
	pcall(function()
		md5 = Enum.HashAlgorithm.Md5
	end)
	if EncodingService and md5 and pcall(EncodingService.ComputeStringHash, EncodingService, "probe", md5) then
		function Env.sharedKey(bytes)
			return Env.base64encode(EncodingService:ComputeStringHash(bytes, md5))
		end
	else
		function Env.sharedKey(_, index)
			return Env.base64encode(string.pack("<I8I8", index, 0x53534934))
		end
	end
end

-- Thread identity: run our own threads at the executor's highest level so reflection,
-- hidden properties and services are readable. Returns the previous level, if known.
function Env.elevate()
	local previous
	if Env.getthreadidentity then
		local ok, level = pcall(Env.getthreadidentity)
		previous = ok and level or nil
	end
	if Env.setthreadidentity then
		pcall(Env.setthreadidentity, 8)
	end
	return previous
end

function Env.guiParent()
	if Env.gethui then
		local ok, gui = pcall(Env.gethui)
		if ok and typeof(gui) == "Instance" then
			return gui, false
		end
	end
	local ok, coreGui = pcall(game.GetService, game, "CoreGui")
	if ok and coreGui then
		return coreGui, true
	end
	local player = game:GetService("Players").LocalPlayer
	return player and player:FindFirstChildOfClass("PlayerGui"), true
end

return Env
end

__modules["log"] = function()
-- Console output, warnings, and the optional debug log file.
local Log = {}

local PREFIX = "[SaveInstance] "
local MAX_WARNINGS = 200

local debugEnabled = false
local debugLines = {}
local warnedKeys = {}
local startClock = os.clock()

Log.warnings = {}

local function join(...)
	local count = select("#", ...)
	local parts = table.create(count)
	for i = 1, count do
		parts[i] = tostring((select(i, ...)))
	end
	return table.concat(parts, " ")
end

function Log.begin(debug)
	debugEnabled = debug == true
	table.clear(debugLines)
	table.clear(warnedKeys)
	table.clear(Log.warnings)
	startClock = os.clock()
end

function Log.setDebug(enabled)
	debugEnabled = enabled == true
end

function Log.debug(...)
	if debugEnabled then
		table.insert(debugLines, string.format("[%8.2f] %s", os.clock() - startClock, join(...)))
	end
end

function Log.info(...)
	local message = join(...)
	print(PREFIX .. message)
	Log.debug(message)
end

function Log.warn(...)
	local message = join(...)
	warn(PREFIX .. message)
	Log.debug("WARN " .. message)
	if #Log.warnings < MAX_WARNINGS then
		table.insert(Log.warnings, message)
	end
end

-- Warns once per key for the whole save (for per-property or per-class problems).
function Log.warnOnce(key, ...)
	if warnedKeys[key] then
		Log.debug(...)
		return
	end
	warnedKeys[key] = true
	Log.warn(...)
end

function Log.debugText()
	return table.concat(debugLines, "\n")
end

function Log.isDebug()
	return debugEnabled
end

return Log
end

__modules["main"] = function()
-- Entry point: returns the saveinstance(options) function.

--[=[
	@class SaveInstance
	Saves the current place, or selected instances, to the executor's workspace as a
	Roblox XML file (.rbxlx for places, .rbxmx for models).

	Every option is described in the [Options reference](/docs/options).
]=]

--[=[
	@function saveinstance
	@within SaveInstance
	@param target table | Instance | { Instance } -- the options table, or what to save as a model
	@param options table? -- options, when the first argument is an instance or a list of instances
	@return table -- { ok, path, bytes, instances, scripts, decompiler, elapsed, warnings } or { ok = false, error, trace }

	```lua
	local saveinstance = loadstring(game:HttpGet(
		"https://raw.githubusercontent.com/visionarytools/tool1/refs/heads/main/source/saveinstance.luau"
	))()

	saveinstance()                          -- the whole place
	saveinstance({ Decompile = false })     -- map only
	saveinstance(workspace.SomeModel)       -- one model
	```
]=]
local Options = require("options")
local Env = require("env")
local Log = require("log")
local Util = require("util")
local Schema = require("schema")
local Scripts = require("scripts")
local Collect = require("collect")
local Serialize = require("serialize")
local Writer = require("writer")
local Streaming = require("streaming")
local UI = require("ui")
local Telemetry = require("telemetry")

local Players = game:GetService("Players")

local FOLDER = "SaveInstance420"

local function timestamp()
	return os.date("!%Y-%m-%d %H.%M.%S")
end

local function placeName()
	local name
	pcall(function()
		name = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
	end)
	return Util.fileSafe(name or game.Name)
end

local function outputPath(options, job)
	local base = options.FilePath
	if type(base) ~= "string" or base == "" then
		local subject = job.isModel and Util.fileSafe(job.roots[1] and job.roots[1].Name or "Model") or placeName()
		base = subject .. " - " .. tostring(game.PlaceId) .. " - " .. timestamp()
	end
	return base .. (job.isModel and ".rbxmx" or ".rbxlx")
end

local function neutralizeLighting()
	local Lighting = game:GetService("Lighting")
	pcall(function()
		Lighting.ClockTime = 14
		Lighting.Brightness = 2
		Lighting.ExposureCompensation = 0
		Lighting.FogStart = 0
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = true
		Lighting.Ambient = Color3.fromRGB(128, 128, 128)
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	end)
	local function soften(effect)
		if effect:IsA("PostEffect") then
			pcall(function()
				effect.Enabled = false
			end)
		elseif effect:IsA("Atmosphere") then
			pcall(function()
				effect.Density, effect.Haze, effect.Glare = 0, 0, 0
			end)
		end
	end
	for _, effect in Lighting:GetDescendants() do
		soften(effect)
	end
	if workspace.CurrentCamera then
		for _, effect in workspace.CurrentCamera:GetChildren() do
			soften(effect)
		end
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		pcall(function()
			clouds.Enabled = false
		end)
	end
end

local function startAntiIdle()
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local VirtualUser = game:GetService("VirtualUser")
	return player.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
end

-- ops: the robloxscripts.com Script Ops handle from the bundle's prelude (nil when tracking is off).
return function(version, ops)
	local genv = (getgenv and getgenv()) or _G
	Telemetry.attach(ops)

	if genv.__SaveInstance420Dev then
		-- Development only: lets tools/live.mjs tests reach individual modules.
		genv.__SaveInstance420Internals = {
			Scripts = Scripts,
			Schema = Schema,
			Encode = require("encode"),
			Env = Env,
			Options = Options,
		}
	end

	local function run(options, ui, status, cleanups)
		local started = os.clock()
		Util.setYieldBudget(options.YieldBudget)
		Schema.reset(options)

		local function report(phase, done, total, detail)
			status.phase, status.done, status.total = phase, done or 0, total or 0
			status.elapsed = os.clock() - started
			if ui then
				ui.set(phase .. (total and total > 0 and string.format(" %d / %d", done, total) or ""),
					total and total > 0 and done / total or nil,
					(detail or "") .. "  ·  " .. Util.formatDuration(status.elapsed))
			end
		end

		Log.info(string.format("Austin's Save Instance %s on %s", version, Env.executor))
		Log.info(string.format("schema: %s (snapshot %s) | base64: %s | hidden properties: %s",
			Schema.usingReflection and "ReflectionService + snapshot" or "snapshot only",
			Schema.snapshotVersion, Env.base64source or "none",
			Env.gethiddenproperty and (options.IgnoreSpecialProperties and "off (IgnoreSpecialProperties)" or "gethiddenproperty")
				or "unavailable (unions and some properties will be incomplete)"))
		if not Env.base64encode then
			error("no working base64 encoder", 0)
		end
		local decompiler = Scripts.begin(options)
		Log.info("decompiler: " .. decompiler)
		Telemetry.event("decompiler", Scripts.providerKind())

		local antiIdle = options.AntiIdle and startAntiIdle() or nil
		if antiIdle then
			table.insert(cleanups, function()
				antiIdle:Disconnect()
			end)
		end
		if options.NeutralizeLighting then
			neutralizeLighting()
		end

		if options.SetStreaming then
			report("Streaming the map in")
			local complete, summary, restore = Streaming.run(options, function(done, total, eta, note)
				report("Streaming map", done, total, note or (eta and ("about " .. Util.formatDuration(eta) .. " left")))
			end)
			table.insert(cleanups, restore)
			if complete then
				Log.info("streaming: " .. summary)
			else
				Log.warn("streaming incomplete: " .. summary)
			end
		end

		report("Collecting instances")
		local job = Collect.build(options)
		Log.info(string.format("collected ~%d instances, %d scripts in %s", job.estimate, #job.scripts,
			Util.formatDuration(os.clock() - started)))

		if options.Decompile and #job.scripts > 0 then
			local decompileStarted = os.clock()
			local prepared = Scripts.prepare(job.scripts, function(done, total, label)
				report("Decompiling scripts", done, total, label)
			end)
			if prepared then
				Log.info(string.format("decompiled %d unique scripts (%d failed) in %s", prepared.unique, prepared.failed,
					Util.formatDuration(os.clock() - decompileStarted)))
			end
		end

		if options.SafeMode and Players.LocalPlayer then
			pcall(Players.LocalPlayer.Kick, Players.LocalPlayer, "\nSaveInstance 420: saving this place, please wait...")
			pcall(function()
				game:GetService("RunService"):Set3dRenderingEnabled(false)
			end)
			table.insert(cleanups, function()
				game:GetService("RunService"):Set3dRenderingEnabled(true)
			end)
		end

		local path = outputPath(options, job)
		status.path = path
		report("Saving instances", 0, job.estimate)
		local writer = Writer.open(path, options.Callback)
		local saveStarted = os.clock()
		local ok, statsOrError = pcall(Serialize.run, job, writer, options, version, function(done, bytes)
			status.bytes = bytes
			report("Saving instances", math.min(done, job.estimate), job.estimate, Util.formatBytes(bytes))
		end)
		if not ok then
			writer.abort()
			error(statsOrError, 0)
		end
		local bytes = writer.finish()

		local stats = statsOrError
		local skipped = {}
		for className, count in stats.skippedClasses do
			table.insert(skipped, className .. " x" .. count)
		end
		if #skipped > 0 then
			table.sort(skipped)
			Log.debug("left out (not saveable): " .. table.concat(skipped, ", "))
		end

		local elapsed = os.clock() - started
		local s = Scripts.stats()
		if s.total > 0 then
			Log.info(string.format("scripts: %d decompiled, %d reused, %d failed, %d server-only, %d without source",
				s.decompiled, s.cached, s.failed, s.server, s.unavailable))
		end
		Log.info(string.format("saved %s: %d instances, %s in %s (writing took %s)", path, stats.instances,
			Util.formatBytes(bytes), Util.formatDuration(elapsed), Util.formatDuration(os.clock() - saveStarted)))
		return {
			ok = true,
			path = path,
			bytes = bytes,
			instances = stats.instances,
			sharedStrings = stats.sharedStrings,
			scripts = Scripts.stats(),
			decompiler = decompiler,
			decompilerStopped = Scripts.stoppedReason(),
			elapsed = elapsed,
			warnings = Log.warnings,
		}
	end

	local function saveinstance(...)
		local first, second = ...
		if select("#", ...) >= 2 and first == nil then
			-- saveinstance(workspace:FindFirstChild("Gone"), options) must not quietly save the
			-- whole place instead: that takes minutes, and with a paid decompiler costs requests.
			Telemetry.event("result", "nil_target")
			error("saveinstance: the instance to save is nil (it does not exist right now)", 2)
		end
		if genv.__SaveInstance420Busy then
			Telemetry.event("result", "busy")
			warn("[SaveInstance] A save is already running")
			return { ok = false, error = "a save is already running" }
		end
		genv.__SaveInstance420Busy = true
		Log.begin(false)
		local previousIdentity = Env.elevate()

		local resolved, options = pcall(Options.resolve, first, second)
		if not resolved then
			genv.__SaveInstance420Busy = nil
			error(options, 2)
		end
		Log.setDebug(options.Debug)

		-- Run statistics: fixed words only, never paths, names or option values typed by the user.
		local mode = (options.Mode == "optimized" or options.Mode == "full" or options.Mode == "scripts") and options.Mode or "other"
		Telemetry.event("save", options.Object and (options.IsModel and "model" or "object_as_place") or mode)
		for option, word in { SetStreaming = "streaming", NilInstances = "nil_instances", IsolateLocalPlayer = "isolate_player",
			IsolatePlayers = "isolate_players", SafeMode = "safe_mode", NeutralizeLighting = "neutralize_lighting",
			SaveBytecode = "save_bytecode" } do
			if options[option] == true then
				Telemetry.event("option", word)
			end
		end

		local status = { version = version, phase = "starting", done = 0, total = 0, bytes = 0, elapsed = 0 }
		genv.SaveInstance420Status = status
		local ui = options.ShowStatus and UI.open(version) or nil

		local cleanups = {}
		local ok, result = xpcall(run, function(message)
			return { message = tostring(message), trace = debug.traceback(nil, 2) }
		end, options, ui, status, cleanups)

		for _, cleanup in cleanups do
			pcall(cleanup)
		end
		Schema.cleanup()
		genv.__SaveInstance420Busy = nil
		if previousIdentity and Env.setthreadidentity then
			pcall(Env.setthreadidentity, previousIdentity)
		end

		Telemetry.event("result", ok and "ok" or "failed")
		if ok and result.decompilerStopped then
			Telemetry.event("decompiler_stopped")
		end
		if not ok then
			Telemetry.error(result.message, "save")
			Log.warn("save failed: " .. result.message)
			Log.debug(result.trace)
			result = { ok = false, error = result.message, trace = result.trace, warnings = Log.warnings }
			if ui then
				ui.finish("Save failed", result.error, false)
				ui.close(8)
			end
		elseif ui then
			ui.finish("Saved " .. result.path, string.format("%d instances  ·  %s  ·  %s", result.instances,
				Util.formatBytes(result.bytes), Util.formatDuration(result.elapsed)), true)
			ui.close(6)
		end
		status.phase = ok and "done" or "failed"
		status.result = result

		if Log.isDebug() and Env.writefile then
			pcall(function()
				if Env.isfolder and Env.makefolder and not Env.isfolder(FOLDER) then
					Env.makefolder(FOLDER)
				end
				Env.writefile(FOLDER .. "/debug " .. timestamp() .. ".log", Log.debugText())
			end)
		end
		if ok and options.ShutdownWhenDone then
			game:Shutdown()
		end
		return result
	end

	Telemetry.ready() -- loaded without errors
	return saveinstance
end
end

__modules["options"] = function()
-- Options: defaults, legacy aliases, and the call forms the original loader accepted.
local Log = require("log")

local Options = {}

-- { name, default } in display order. Names are matched case-insensitively.
local SPECS = {
	-- What to save
	{ "Mode", "optimized" }, -- "optimized" | "full" | "scripts"
	{ "Object", false }, -- Instance or { Instance } to save as a model (.rbxmx)
	{ "IsModel", "auto" },
	{ "ExtraInstances", {} },
	{ "IgnoreList", { "CoreGui", "CorePackages" } },
	{ "IgnoreProperties", {} },
	{ "IgnoreNotArchivable", true }, -- true = also save instances with Archivable = false
	{ "NilInstances", false },
	{ "RemovePlayerCharacters", true },
	{ "IsolateLocalPlayer", false },
	{ "IsolateLocalPlayerCharacter", false },
	{ "IsolatePlayers", false },
	{ "IsolateStarterPlayer", false },
	{ "SaveNotCreatable", false },

	-- Scripts
	{ "Decompile", true },
	{ "DecompileTimeout", false }, -- seconds per script; false = 10 for native decompilers, 30 for HTTP hooks
	{ "DecompileConcurrency", 16 }, -- decompiles in flight at once (native decompilers that yield)
	{ "DecompileIgnore", { "TextChatService" } },
	{ "DecompileJobless", false },
	{ "IgnoreDefaultPlayerScripts", true },
	{ "ScriptCache", true },
	{ "SaveBytecode", false },
	{ "DecompilerFallback", true }, -- use the lua.expert API when the executor has no decompile()
	{ "DecompilerApiUrl", "https://api.lua.expert/decompile" },
	{ "DecompilerApiGap", 0.12 },
	{ "DecompilerName", false },

	-- Properties
	{ "IgnoreDefaultProperties", true },
	{ "IgnoreSpecialProperties", false },
	{ "UseUGCValidationService", true },
	{ "IgnoreSharedStrings", false },
	{ "TreatUnionsAsParts", false },

	-- Output and behaviour
	{ "FilePath", false },
	{ "Callback", false },
	{ "ShowStatus", true },
	{ "ReadMe", true },
	{ "Debug", false },
	{ "SafeMode", false },
	{ "ShutdownWhenDone", false },
	{ "AntiIdle", true },
	{ "NeutralizeLighting", false },

	-- Streaming (StreamingEnabled games): request the map around the character before saving
	{ "SetStreaming", false },
	{ "StreamingAreaSize", 10000 }, -- side of the square swept around StreamingCenter, in studs
	{ "StreamingRadius", 512 }, -- grid spacing and settle radius, in studs
	{ "StreamingCenter", false }, -- Vector3; false = the character's position
	{ "StreamingSlices", 2 }, -- vertical layers per grid point
	{ "StreamingPasses", 1 },
	{ "StreamingPoints", false }, -- explicit { Vector3 } list instead of a grid
	{ "StreamingConcurrency", 4 },
	{ "StreamingTimeout", 20 }, -- seconds per request
	{ "StreamingChunkWait", 6 }, -- seconds to wait for a region to settle
	{ "StreamingSettleTime", 5 }, -- pause after the sweep for late arrivals
	{ "StreamingMaxTime", false }, -- overall limit in seconds; false = derived from the grid
	{ "YieldBudget", 8 }, -- milliseconds of work per frame
}

-- Legacy USSI / 420 names. { canonical, invert }
local ALIASES = {
	noscripts = { "Decompile", true },
	timeout = { "DecompileTimeout" },
	scriptcache = { "ScriptCache" },
	filename = { "FilePath" },
	ignoredefaultprops = { "IgnoreDefaultProperties" },
	savenoncreatable = { "SaveNotCreatable" },
	saveplayers = { "IsolatePlayers" },
	removeplayers = { "IsolatePlayers", true },
	ignorearchivable = { "IgnoreNotArchivable" },
	saveplayercharacters = { "RemovePlayerCharacters", true },
	__debug_mode = { "Debug" },
	streaming = { "SetStreaming" },
}

-- Accepted for compatibility; the rewrite no longer needs them.
local RETIRED = {
	decomptype = true,
	savecacheinterval = true,
	alternativewritefile = true,
	sharedstringoverwrite = true,
	ignorepropertiesofnotscriptsonscriptsmode = true,
	nilinstancesfixes = true,
	notcreatablefixes = true,
	anonymous = true,
}

local CANONICAL = {}
for _, spec in SPECS do
	CANONICAL[string.lower(spec[1])] = spec[1]
end

local function copy(value)
	if type(value) == "table" then
		return table.clone(value)
	end
	return value
end

local function isInstanceList(value)
	return type(value) == "table" and typeof(value[1]) == "Instance"
end

-- Accepts every call form of the original:
--   saveinstance()                  saveinstance(options)
--   saveinstance(instance)          saveinstance({ instance, ... })
--   saveinstance(instance, options) saveinstance({ instance, ... }, options)
function Options.resolve(first, second)
	local options = {}
	for _, spec in SPECS do
		options[spec[1]] = copy(spec[2])
	end

	local user, objects
	if typeof(first) == "Instance" or isInstanceList(first) then
		objects = first
		user = type(second) == "table" and second or {}
	elseif type(first) == "table" then
		user = first
	else
		user = {}
	end

	for key, value in user do
		if type(key) ~= "string" then
			continue
		end
		local lower = string.lower(key)
		local canonical = CANONICAL[lower]
		local alias = ALIASES[lower]
		if canonical then
			options[canonical] = value
		elseif alias then
			if alias[2] and type(value) == "boolean" then
				value = not value
			end
			options[alias[1]] = value
		elseif RETIRED[lower] then
			Log.debug("option", key, "is no longer needed and was ignored")
		elseif lower ~= "readme" then
			Log.warnOnce("option:" .. lower, "Unknown option '" .. key .. "' was ignored")
		end
	end

	if objects then
		options.Object = objects
	end
	if options.Object == game then
		options.Object = false
		options.Mode = "full"
	end
	if options.Object and options.IsModel == "auto" then
		options.IsModel = true
	elseif options.IsModel == "auto" then
		options.IsModel = false
	end

	options.Mode = string.lower(tostring(options.Mode))
	local timeout = tonumber(options.DecompileTimeout)
	options.DecompileTimeout = timeout and (timeout <= 0 and math.huge or timeout) or false
	return options
end

return Options
end

__modules["quirks"] = function()
-- Property and class exceptions that the API metadata alone gets wrong.
-- Every entry here exists because a save broke without it.
local Attributes = require("attributes")

local Quirks = {}

-- Never written. UniqueId/HistoryId duplicated across saves corrupt places (the classic
-- saveinstance bug); ScriptGuid is Studio-internal.
Quirks.blocked = {
	UniqueId = true,
	HistoryId = true,
	ScriptGuid = true,
}

-- Hidden serialized members with a scriptable twin that holds the same value. Reading the
-- twin is much faster than gethiddenproperty and works on every executor.
-- Keyed by the class that declares the member.
Quirks.aliases = {
	Instance = { DefinesCapabilities = "Sandboxed" },
	BasePart = { Color3uint8 = "Color", size = "Size", MaterialVariantSerialized = "MaterialVariant" },
	Part = { shape = "Shape" },
	TrussPart = { style = "Style" },
	FormFactorPart = { formFactorRaw = "FormFactor" },
	Fire = { heat_xml = "Heat", size_xml = "Size" },
	Smoke = { size_xml = "Size", opacity_xml = "Opacity", riseVelocity_xml = "RiseVelocity" },
	Sound = { xmlRead_MaxDistance_3 = "RollOffMaxDistance" },
	Humanoid = { Health_XML = "Health" },
	BallSocketConstraint = { MaxFrictionTorqueXml = "MaxFrictionTorque" },
	DoubleConstrainedValue = { value = "Value" },
	IntConstrainedValue = { value = "Value" },
	MaterialService = { Use2022MaterialsXml = "Use2022Materials" },
	WeldConstraint = { Part0Internal = "Part0", Part1Internal = "Part1" },
	MeshPart = { InitialSize = "MeshSize" },
	TriangleMeshPart = { FluidFidelityInternal = "FluidFidelity" },
	PackageLink = { PackageIdSerialize = "PackageId", VersionIdSerialize = "VersionNumber" },
	Players = { MaxPlayersInternal = "MaxPlayers", PreferredPlayersInternal = "PreferredPlayers" },
	StarterPlayer = { AvatarJointUpgrade_Serialized = "AvatarJointUpgrade" },
	Terrain = { AcquisitionMethod = "LastUsedModificationMethod" },
}

local TERRAIN_MATERIALS = { -- order fixed by the MaterialColors format
	"Grass", "Slate", "Concrete", "Brick", "Sand", "WoodPlanks", "Rock", "Glacier", "Snow", "Sandstone", "Mud",
	"Basalt", "Ground", "CrackedLava", "Asphalt", "Cobblestone", "Ice", "LeafyGrass", "Salt", "Limestone", "Pavement",
}

local function byte(channel)
	return math.clamp(math.floor(channel * 255 + 0.5), 0, 255)
end

-- Values rebuilt from public APIs. `first = true` means try this before gethiddenproperty
-- (cheaper, and it runs for every instance); otherwise it is a fallback.
Quirks.readers = {
	Instance = {
		AttributesSerialize = { first = true, read = Attributes.serialize },
		Tags = {
			first = true,
			read = function(instance)
				local tags = instance:GetTags()
				return #tags == 0 and "" or table.concat(tags, "\0")
			end,
		},
	},
	Model = {
		ScaleFactor = {
			first = true,
			read = function(model)
				return model:GetScale()
			end,
		},
		WorldPivotData = {
			read = function(model)
				return model.WorldPivot
			end,
		},
	},
	Terrain = {
		MaterialColors = {
			read = function(terrain)
				local parts = { string.rep("\0", 6) }
				for _, name in TERRAIN_MATERIALS do
					local color = terrain:GetMaterialColor(Enum.Material[name])
					table.insert(parts, string.char(byte(color.R), byte(color.G), byte(color.B)))
				end
				return table.concat(parts)
			end,
		},
	},
	Workspace = {
		CollisionGroupData = {
			read = function()
				local groups = game:GetService("PhysicsService"):GetRegisteredCollisionGroups()
				local parts = { string.pack("<BB", 1, #groups) }
				for index, group in groups do
					local mask = group.mask
					if mask >= 2147483648 then
						mask -= 4294967296 -- stored as a signed 32-bit integer
					end
					table.insert(parts, string.pack("<BBi4s1", index - 1, 4, mask, group.name))
				end
				return table.concat(parts)
			end,
		},
	},
	HumanoidDescription = {
		EmotesDataInternal = {
			read = function(description)
				local parts = {}
				for name, ids in description:GetEmotes() do
					table.insert(parts, name .. "^" .. table.concat(ids, "^") .. "^\\")
				end
				return table.concat(parts)
			end,
		},
		EquippedEmotesDataInternal = {
			read = function(description)
				local parts = {}
				for _, emote in description:GetEquippedEmotes() do
					table.insert(parts, emote.Slot .. "^" .. emote.Name .. "\\")
				end
				return table.concat(parts)
			end,
		},
	},
	LocalizationTable = {
		Contents = {
			read = function(localizationTable)
				return localizationTable:GetContents()
			end,
		},
	},
}

-- Classes that must never become <Item>s: Studio cannot create them, or they only make
-- sense at runtime. Used when ReflectionService cannot answer for a class.
Quirks.unsaveable = {
	Player = true,
	PlayerGui = true,
	PlayerScripts = true,
	PlayerMouse = true,
	Backpack = true,
	TouchTransmitter = true,
	AnimationTrack = true,
	StudioData = true,
	ScreenshotHud = true,
	TextSource = true,
	InputObject = true,
	Translator = true,
	CloudLocalizationTable = true,
}

-- Engine-injected copies of Roblox's default player scripts. Saving them (decompiled or
-- not) replaces Studio's working defaults with broken copies, so they are left out.
Quirks.defaultPlayerScripts = {
	PlayerModule = "ModuleScript",
	RbxCharacterSounds = "LocalScript",
	ChatScript = "LocalScript",
	BubbleChat = "LocalScript",
}

return Quirks
end

__modules["schema"] = function()
-- Which properties each class saves, and how to read them.
--
-- Two sources are merged per class:
--   1. ReflectionService on the running client: exact for this build, including members
--      newer than any published API dump.
--   2. The generated snapshot (schema_snapshot.luau): restores the serialized members that
--      ReflectionService hides from scripts (AttributesSerialize, Tags, union MeshData2 /
--      PhysicsData, Script.Source, Workspace streaming settings, ...), and is the whole
--      schema when reflection is unavailable.
-- A member is saved if either source says the engine serializes it.
local Snapshot = require("schema_snapshot")
local Quirks = require("quirks")
local Encode = require("encode")
local Env = require("env")
local Log = require("log")

local Schema = {}

local Reflection
do
	local ok, service = pcall(game.GetService, game, "ReflectionService")
	if ok and service then
		local probed, members = pcall(service.GetPropertiesOfClass, service, "Part")
		if probed and type(members) == "table" and #members > 0 then
			Reflection = service
		end
	end
end
Schema.usingReflection = Reflection ~= nil
Schema.snapshotVersion = Snapshot.version

local REFLECTION_TYPES = {
	Enum = "token",
	RefType = "Ref",
	CoordinateFrame = "CFrame",
	OptionalCoordinateFrame = "OptionalCFrame",
	Rect2D = "Rect",
	Vector3Int16 = "Vector3int16",
	Vector2Int16 = "Vector2int16",
}

-- Types whose nil value is meaningful (and must not be mistaken for a failed read).
local NILABLE = { Ref = true, OptionalCFrame = true, PhysicalProperties = true }

-- Snapshot access ------------------------------------------------------------------------
local parsedSnapshot = {}
local function snapshotClass(name)
	local entry = parsedSnapshot[name]
	if entry ~= nil then
		return entry or nil
	end
	local raw = Snapshot.classes[name]
	if not raw then
		parsedSnapshot[name] = false
		return nil
	end
	local super, flags, list = string.match(raw, "^([^|]*)|([^|]*)|(.*)$")
	entry = {
		super = super ~= "" and super or nil,
		notCreatable = string.find(flags, "N", 1, true) ~= nil,
		service = string.find(flags, "S", 1, true) ~= nil,
		props = {},
	}
	if list ~= "" then
		for _, item in string.split(list, ",") do
			local name, valueType, propFlags = string.match(item, "^([^:]+):([^:]+):?(.*)$")
			if name then
				table.insert(entry.props, {
					name = name,
					type = valueType,
					hidden = string.find(propFlags, "H", 1, true) ~= nil,
					preferred = string.match(propFlags, ">(.+)$"),
				})
			end
		end
	end
	parsedSnapshot[name] = entry
	return entry
end

local reflectedClasses = {}
local function reflectedClass(name)
	local entry = reflectedClasses[name]
	if entry == nil then
		entry = false
		if Reflection then
			local ok, class = pcall(Reflection.GetClass, Reflection, name)
			if ok and class then
				entry = class
			end
		end
		reflectedClasses[name] = entry
	end
	return entry or nil
end

local superclasses = {}
local function superclassOf(name)
	local super = superclasses[name]
	if super == nil then
		local snap = snapshotClass(name)
		if snap then
			super = snap.super
		else
			local class = reflectedClass(name)
			super = class and class.Superclass or nil
		end
		superclasses[name] = super or false
	end
	return super or nil
end
Schema.superclassOf = superclassOf

function Schema.isA(className, base)
	local current = className
	while current do
		if current == base then
			return true
		end
		current = superclassOf(current)
	end
	return false
end

local function quirkFor(map, className, propertyName)
	local current = className
	while current do
		local entries = map[current]
		local entry = entries and entries[propertyName]
		if entry ~= nil then
			return entry
		end
		current = superclassOf(current)
	end
	return nil
end

-- Class information ------------------------------------------------------------------------
local classInfos = {}

-- { known, saveable, creatable, service }
function Schema.classInfo(className)
	local info = classInfos[className]
	if info then
		return info
	end
	info = { name = className, known = false, saveable = false, creatable = false, service = false }
	local class = reflectedClass(className)
	local snap = snapshotClass(className)
	if class then
		local permits = class.Permits
		info.known = true
		info.saveable = class.Serialized == true
		info.creatable = type(permits) == "table" and permits.New ~= nil
		info.service = type(permits) == "table" and permits.GetService ~= nil
	elseif snap then
		info.known = true
		info.saveable = true
		info.creatable = not snap.notCreatable
		info.service = snap.service
	end
	if Quirks.unsaveable[className] then
		info.saveable = false
	end
	classInfos[className] = info
	return info
end

-- Read strategies ------------------------------------------------------------------------
local function index(instance, name)
	return instance[name]
end

local function directStrategy(name)
	return function(instance)
		return pcall(index, instance, name)
	end
end

local function hiddenStrategy(name)
	local gethiddenproperty = Env.gethiddenproperty
	return function(instance)
		local ok, value = pcall(gethiddenproperty, instance, name)
		return ok, value
	end
end

local function readerStrategy(reader)
	local read = reader.read
	return function(instance)
		return pcall(read, instance)
	end
end

local UGCValidationService
local function ugcStrategy(name)
	return function(instance)
		if not UGCValidationService then
			local ok, service = pcall(game.GetService, game, "UGCValidationService")
			if not ok or not service then
				return false
			end
			UGCValidationService = service
		end
		local ok, value = pcall(UGCValidationService.GetPropertyValue, UGCValidationService, instance, name)
		if ok and value ~= nil then -- this API returns nil for anything it cannot read
			return true, value
		end
		return false
	end
end

-- Plans --------------------------------------------------------------------------------------
local plans = {}
local settings = { hidden = true, ugc = true }
local defaultInstances = {}

function Schema.reset(options)
	table.clear(plans)
	settings.hidden = Env.gethiddenproperty ~= nil and not options.IgnoreSpecialProperties
	settings.ugc = options.UseUGCValidationService ~= false
	settings.sharedStrings = not options.IgnoreSharedStrings
end

local function buildStrategies(className, entry)
	local strategies = {}
	local alias = quirkFor(Quirks.aliases, className, entry.name)
	local reader = quirkFor(Quirks.readers, className, entry.name)
	if alias then
		table.insert(strategies, directStrategy(alias))
	end
	if reader and reader.first then
		table.insert(strategies, readerStrategy(reader))
	end
	if not entry.hidden then
		table.insert(strategies, directStrategy(entry.name))
	end
	if settings.hidden then
		table.insert(strategies, hiddenStrategy(entry.name))
	end
	if reader and not reader.first then
		table.insert(strategies, readerStrategy(reader))
	end
	if entry.preferred and entry.preferred ~= alias then
		table.insert(strategies, directStrategy(entry.preferred))
	end
	if entry.hidden then
		table.insert(strategies, directStrategy(entry.name)) -- some "hidden" members are readable at high identity
	end
	if settings.ugc then
		table.insert(strategies, ugcStrategy(entry.name))
	end
	return strategies
end

-- Returns the ordered property list for a class. Each entry:
--   name, type, open/close (XML tags), encode, strategies, nilable
function Schema.plan(className)
	local plan = plans[className]
	if plan then
		return plan
	end
	plan = {}
	local seen = {}

	local function add(name, valueType, hidden, preferred)
		if seen[name] or Quirks.blocked[name] then
			return
		end
		seen[name] = true
		if not Encode.supports(valueType) then
			Log.debug("schema: no encoder for", valueType, className .. "." .. name)
			return
		end
		if valueType == "SharedString" and not settings.sharedStrings then
			return
		end
		table.insert(plan, { name = name, type = valueType, hidden = hidden, preferred = preferred })
	end

	if Reflection then
		local ok, members = pcall(Reflection.GetPropertiesOfClass, Reflection, className)
		if ok and type(members) == "table" then
			for _, member in members do
				if member.Serialized == true and type(member.Type) == "table" then
					local engineType = member.Type.EngineType
					local permits = member.Permits
					local readable = type(permits) == "table" and permits.Read ~= nil
					if engineType then
						add(member.Name, REFLECTION_TYPES[engineType] or engineType, not readable, nil)
					end
				end
			end
		end
	end

	local current = className
	while current do
		local snap = snapshotClass(current)
		if snap then
			for _, member in snap.props do
				add(member.name, member.type, member.hidden, member.preferred)
			end
		end
		current = superclassOf(current)
	end

	for _, entry in plan do
		entry.open, entry.close = Encode.tags(entry.type, entry.name)
		entry.encode = Encode.encoders[entry.type]
		entry.nilable = NILABLE[entry.type] == true
		entry.strategies = buildStrategies(className, entry)
		entry.failures = 0
	end
	plans[className] = plan
	return plan
end

-- Reads one property, trying the strategy that worked last time first.
-- Returns ok, value.
function Schema.read(instance, entry)
	local strategies = entry.strategies
	local best = entry.best
	if best then
		local ok, value = strategies[best](instance)
		if ok and (value ~= nil or entry.nilable) then
			return true, value
		end
	end
	for i, strategy in strategies do
		if i ~= best then
			local ok, value = strategy(instance)
			if ok and (value ~= nil or entry.nilable) then
				entry.best = i
				return true, value
			end
		end
	end
	if not best then
		entry.failures += 1
		if entry.failures >= 50 then
			entry.dead = true -- never readable on this client; stop paying for the attempts
			Log.debug("schema: giving up on", entry.name, "after 50 failed reads")
		end
	end
	return false
end

-- Default values (IgnoreDefaultProperties) -------------------------------------------------
local function defaultInstance(className)
	local instance = defaultInstances[className]
	if instance == nil then
		instance = false
		if Schema.classInfo(className).creatable then
			local ok, created = pcall(Instance.new, className)
			if ok and created then
				instance = created
			end
		end
		defaultInstances[className] = instance
	end
	return instance or nil
end

function Schema.isDefault(className, entry, value)
	local hasDefault = entry.hasDefault
	if hasDefault == nil then
		hasDefault = false
		local instance = defaultInstance(className)
		if instance then
			for _, strategy in entry.strategies do
				local ok, defaultValue = strategy(instance)
				if ok and (defaultValue ~= nil or entry.nilable) then
					entry.default = defaultValue
					hasDefault = true
					break
				end
			end
		end
		entry.hasDefault = hasDefault
	end
	return hasDefault and entry.default == value
end

-- Instances created for default values, so they can be excluded from nil-instance saves.
function Schema.ownInstances()
	local set = {}
	for _, instance in defaultInstances do
		if instance then
			set[instance] = true
		end
	end
	return set
end

function Schema.cleanup()
	for className, instance in defaultInstances do
		if instance then
			pcall(instance.Destroy, instance)
		end
		defaultInstances[className] = nil
	end
	table.clear(plans)
end

return Schema
end

__modules["schema_snapshot"] = function()
-- AUTO-GENERATED by tools/gen-schema.mjs from MaximumADHD/Roblox-Client-Tracker Full-API-Dump.json.
-- Do not edit by hand; rerun the generator after a Roblox update.
-- Format per class: "Superclass|classFlags|name:type[:propFlags],..."
--   classFlags: N = NotCreatable, S = Service
--   propFlags:  H = NotScriptable (read through gethiddenproperty), >Name = preferred scriptable alias
return {
	version = "0.748.0.7481526",
	classes = {
		["Object"] = "|N|",
		["AnimationNode"] = "Object|N|",
		["AppHandle"] = "Object|N|",
		["Blob"] = "Object|N|",
		["Capture"] = "Object|N|",
		["ScreenshotCapture"] = "Capture|N|",
		["VideoCapture"] = "Capture|N|",
		["ConfigSnapshot"] = "Object|N|",
		["DataModelDiff"] = "Object|N|",
		["EditableImage"] = "Object|N|ImageData:BinaryString:H",
		["EditableMesh"] = "Object|N|MeshData:SharedString:H",
		["ExecutedRemoteCommand"] = "Object|N|",
		["FeatureMatchingSession"] = "Object|N|",
		["FeatureSearchParams"] = "Object|N|AnchorCostScale:float,AnchorIgnoresTagFilters:bool,AnchorRow:int,MaxDistance:float,MaxResults:int,NormalizationKey:int64,ReturnChannelCosts:bool,SelectionMode:token,SelectionSeed:int64,SelectionTemperature:float",
		["Instance"] = "Object|N|AttributesSerialize:BinaryString:H,Capabilities:SecurityCapabilities,DefinesCapabilities:bool:H,HistoryId:UniqueId:H,Name:string,SerializedOverrides:BinaryString:H,SourceAssetId:int64,Tags:SharedString:H,UniqueId:UniqueId",
		["AccessoryDescription"] = "Instance||AccessoryType:token,AssetId:int64,Instance:Ref,IsLayered:bool,Order:int,Position:Vector3,Puffiness:float,Rotation:Vector3,Scale:Vector3",
		["AccountService"] = "Instance|NS|",
		["Accoutrement"] = "Instance||AttachmentPoint:CFrame",
		["Accessory"] = "Accoutrement||AccessoryType:token",
		["Hat"] = "Accoutrement||",
		["AchievementService"] = "Instance|NS|",
		["ActivityHistoryEventService"] = "Instance|NS|",
		["AdPlacement"] = "Instance||ActivationInstance:Ref,AdFormat:token,PlacementId:int64",
		["AdPortal"] = "Instance||",
		["AdService"] = "Instance|NS|",
		["AdvancedDragger"] = "Instance||",
		["AnalyticsService"] = "Instance|NS|ApiKey:string",
		["AnimatedImageService"] = "Instance|NS|",
		["Animation"] = "Instance||AnimationContent:Content,AnimationId:ContentId",
		["AnimationClip"] = "Instance|N|GuidBinaryString:BinaryString:H,Loop:bool,Priority:token",
		["AnimationGraphDefinition"] = "AnimationClip||",
		["CurveAnimation"] = "AnimationClip||",
		["KeyframeSequence"] = "AnimationClip||AuthoredHipHeight:float",
		["AnimationClipProvider"] = "Instance|NS|",
		["AnimationController"] = "Instance||",
		["AnimationFromVideoCreatorService"] = "Instance|NS|",
		["AnimationFromVideoCreatorStudioService"] = "Instance|NS|",
		["AnimationNodeDefinition"] = "Instance||InputPinData:BinaryString:H,NodeId:string,NodeType:token",
		["AnimationPlayer"] = "Instance||AnimationContent:Content,AutoPlay:bool,Enabled:bool,Loop:bool,ParametersSerialize:BinaryString:H,Speed:float,Track:string",
		["AnimationRigData"] = "Instance||Generic:BinaryString:H,label:BinaryString:H,name:BinaryString:H,parent:BinaryString:H,postTransform:BinaryString:H,preTransform:BinaryString:H,transform:BinaryString:H",
		["AnimationStreamTrack"] = "Instance|N|",
		["AnimationTrack"] = "Instance|N|Priority:token",
		["AnimationValueNodeDefinition"] = "Instance||NodeId:string,NodeType:token",
		["AnimationValueOutputDefinition"] = "Instance||",
		["Animator"] = "Instance||PreferLodEnabled:bool",
		["Annotation"] = "Instance||",
		["WorkspaceAnnotation"] = "Annotation||",
		["AnnotationsService"] = "Instance|NS|",
		["AppAgeSignalsService"] = "Instance|NS|",
		["AppLifecycleObserverService"] = "Instance|NS|",
		["AppRatingPromptService"] = "Instance|NS|",
		["AppUpdateService"] = "Instance|NS|",
		["AssetCounterService"] = "Instance|NS|",
		["AssetDeliveryProxy"] = "Instance|NS|Interface:string,Port:int,StartServer:bool",
		["AssetImportService"] = "Instance|NS|",
		["AssetManagerService"] = "Instance|NS|",
		["AssetPatchSettings"] = "Instance|N|ContentId:string,OutputPath:string,PatchId:string",
		["AssetQualityService"] = "Instance|NS|",
		["AssetService"] = "Instance|NS|AllowInsertFreeAssets:bool",
		["Atmosphere"] = "Instance||Color:Color3,Decay:Color3,Density:float,Glare:float,Haze:float,Offset:float",
		["Attachment"] = "Instance||CFrame:CFrame,Visible:bool",
		["Bone"] = "Attachment||",
		["AudioAnalyzer"] = "Instance||SpectrumEnabled:bool,WindowSize:token",
		["AudioChannelMixer"] = "Instance||Layout:token",
		["AudioChannelSplitter"] = "Instance||Layout:token",
		["AudioChorus"] = "Instance||Bypass:bool,Depth:float,Mix:float,Rate:float",
		["AudioCompressor"] = "Instance||Attack:float,Bypass:bool,MakeupGain:float,Ratio:float,Release:float,Threshold:float",
		["AudioDeviceInput"] = "Instance||AccessType:token,Active:bool,Muted:bool,Player:Ref,Volume:float",
		["AudioDeviceOutput"] = "Instance||Player:Ref",
		["AudioDistortion"] = "Instance||Bypass:bool,Level:float",
		["AudioEcho"] = "Instance||Bypass:bool,DelayTime:float,DryLevel:float,Feedback:float,RampTime:float,WetLevel:float",
		["AudioEmitter"] = "Instance||AcousticSimulationEnabled:bool,AngleAttenuation:BinaryString,AudioInteractionGroup:string,DiffractionEnabled:token,DistanceAttenuation:BinaryString,DistanceAttenuationBounds:NumberRange,DistanceAttenuationMode:token,OcclusionEnabled:token,PositionInstance:Ref,PositionType:token,ReverbEnabled:token,SimulationFidelity:token:>AcousticSimulationEnabled",
		["AudioEqualizer"] = "Instance||Bypass:bool,HighGain:float,LowGain:float,MidGain:float,MidRange:NumberRange",
		["AudioFader"] = "Instance||Bypass:bool,Volume:float",
		["AudioFilter"] = "Instance||Bypass:bool,FilterType:token,Frequency:float,Gain:float,Q:float",
		["AudioFlanger"] = "Instance||Bypass:bool,Depth:float,Mix:float,Rate:float",
		["AudioFocusService"] = "Instance|NS|",
		["AudioGate"] = "Instance||Attack:float,Bypass:bool,Release:float,Threshold:NumberRange",
		["AudioLimiter"] = "Instance||Bypass:bool,MaxLevel:float,Release:float",
		["AudioListener"] = "Instance||AcousticSimulationEnabled:bool,AngleAttenuation:BinaryString,AudioInteractionGroup:string,DiffractionEnabled:token,DistanceAttenuation:BinaryString,OcclusionEnabled:token,PositionInstance:Ref,PositionType:token,ReverbEnabled:token,SimulationFidelity:token:>AcousticSimulationEnabled",
		["AudioPitchShifter"] = "Instance||Bypass:bool,Pitch:float,WindowSize:token",
		["AudioPlayer"] = "Instance||Asset:ContentId,AudioContent:Content,AutoLoad:bool,AutoPlay:bool,LoopRegion:NumberRange,Looping:bool,PlaybackRegion:NumberRange,PlaybackSpeed:double,TimePosition:double,Volume:float",
		["AudioRecorder"] = "Instance||IsRecording:bool",
		["AudioReverb"] = "Instance||Bypass:bool,DecayRatio:float,DecayTime:float,Density:float,Diffusion:float,DryLevel:float,EarlyDelayTime:float,HighCutFrequency:float,LateDelayTime:float,LowShelfFrequency:float,LowShelfGain:float,ReferenceFrequency:float,WetLevel:float",
		["AudioSearchParams"] = "Instance||Album:string,Artist:string,AudioSubType:token,MaxDuration:int,MaxPageSize:int,MinDuration:int,SearchKeyword:string,SortType:token,Tag:string,Title:string",
		["AudioSpeechToText"] = "Instance||Enabled:bool,Text:string",
		["AudioStreamReader"] = "Instance||Layout:token,WindowSize:token",
		["AudioStreamWriter"] = "Instance||Layout:token,WindowSize:token",
		["AudioTextToSpeech"] = "Instance||AutoLocalize:bool,Looping:bool,Pitch:float,PlaybackSpeed:float,Speed:float,Text:string,TimePosition:double,VoiceId:string,Volume:float",
		["AudioTremolo"] = "Instance||Bypass:bool,Depth:float,Duty:float,Frequency:float,Shape:float,Skew:float,Square:float",
		["AudioWindSynthesizer"] = "Instance||Enabled:bool,PositionInstance:Ref,PositionType:token,Profile:token,Volume:float",
		["AuroraScriptObject"] = "Instance|N|BehaviorWeak:Ref,BoundInstanceWeak:Ref,FrameId:int,LODLevel:int,PriorFrameInvoked:int",
		["AuroraScriptService"] = "Instance|NS|",
		["AuroraService"] = "Instance|NS|HashRoundingPoint:double,IgnoreRotation:bool,LockStepIdOffset:bool,RollbackOffset:int",
		["AvatarAbilityRules"] = "Instance||CharacterControllerMode:token,EnableClimbing:bool,EnableCrouching:bool,EnableFallingDown:bool,EnableGettingUp:bool,EnableHolding:bool,EnableJumping:bool,EnableReaching:bool,EnableRunning:bool,EnableSitting:bool,EnableSprinting:bool,EnableSwimming:bool,EnableTurning:bool",
		["AvatarAccessoryRules"] = "Instance||AccessoryMode:token,BackAccessoryOverride:int64,CustomAccessoryMode:token:>HairAccessoryOverride,CustomBackAccessoryEnabled:bool:>BackAccessoryOverride,CustomBackAccessoryId:int64:>BackAccessoryOverride,CustomFaceAccessoryEnabled:bool:>FaceAccessoryOverride,CustomFaceAccessoryId:int64:>FaceAccessoryOverride,CustomFrontAccessoryEnabled:bool:>FrontAccessoryOverride,CustomFrontAccessoryId:int64:>FrontAccessoryOverride,CustomHairAccessoryEnabled:bool:>HairAccessoryOverride,CustomHairAccessoryId:int64:>HairAccessoryOverride,CustomHeadAccessoryEnabled:bool:>HeadAccessoryOverride,CustomHeadAccessoryId:int64:>HeadAccessoryOverride,CustomNeckAccessoryEnabled:bool:>NeckAccessoryOverride,CustomNeckAccessoryId:int64:>NeckAccessoryOverride,CustomShoulderAccessoryEnabled:bool:>ShoulderAccessoryOverride,CustomShoulderAccessoryId:int64:>ShoulderAccessoryOverride,CustomWaistAccessoryEnabled:bool:>WaistAccessoryOverride,CustomWaistAccessoryId:int64:>WaistAccessoryOverride,EnableEmissives:bool,EnableSound:bool,EnableSpawnEffects:bool,EnableVFX:bool,FaceAccessoryOverride:int64,FrontAccessoryOverride:int64,HairAccessoryOverride:int64,HeadAccessoryOverride:int64,LimitBounds:Vector3,LimitMethod:token,NeckAccessoryOverride:int64,ShoulderAccessoryOverride:int64,WaistAccessoryOverride:int64",
		["AvatarAnimationRules"] = "Instance||AnimationClipsMode:token:>RunAnimationOverride,AnimationPacksMode:token,ClimbAnimationOverride:int64,CustomClimbAnimationEnabled:bool:>ClimbAnimationOverride,CustomClimbAnimationId:int64:>ClimbAnimationOverride,CustomFallAnimationEnabled:bool:>FallAnimationOverride,CustomFallAnimationId:int64:>FallAnimationOverride,CustomIdleAlt1AnimationEnabled:bool:>IdleAltAnimationOverride,CustomIdleAlt1AnimationId:int64:>IdleAltAnimationOverride,CustomIdleAlt2AnimationEnabled:bool,CustomIdleAlt2AnimationId:int64,CustomIdleAnimationEnabled:bool:>IdleAnimationOverride,CustomIdleAnimationId:int64:>IdleAnimationOverride,CustomJumpAnimationEnabled:bool:>JumpAnimationOverride,CustomJumpAnimationId:int64:>JumpAnimationOverride,CustomRunAnimationEnabled:bool:>RunAnimationOverride,CustomRunAnimationId:int64:>RunAnimationOverride,CustomSwimAnimationEnabled:bool:>SwimAnimationOverride,CustomSwimAnimationId:int64:>SwimAnimationOverride,CustomSwimIdleAnimationEnabled:bool:>SwimIdleAnimationOverride,CustomSwimIdleAnimationId:int64:>SwimIdleAnimationOverride,CustomWalkAnimationEnabled:bool:>WalkAnimationOverride,CustomWalkAnimationId:int64:>WalkAnimationOverride,FallAnimationOverride:int64,IdleAltAnimationOverride:int64,IdleAnimationOverride:int64,JumpAnimationOverride:int64,MoodAnimationOverride:int64,RunAnimationOverride:int64,SwimAnimationOverride:int64,SwimIdleAnimationOverride:int64,WalkAnimationOverride:int64",
		["AvatarBodyRules"] = "Instance||AppearanceMode:token:>HeadOverride,AvatarType:token,BuildMode:token,CustomBodyBundleId:int64,CustomBodyType:token,CustomBodyTypeScale:NumberRange:>CustomBuildBodyType,CustomBuildBodyType:NumberRange,CustomBuildHead:NumberRange,CustomBuildHeight:NumberRange,CustomBuildProportions:NumberRange,CustomBuildWidth:NumberRange,CustomEyebrowEnabled:bool,CustomEyebrowId:int64,CustomEyelashEnabled:bool,CustomEyelashId:int64,CustomFaceEnabled:bool,CustomFaceId:int64,CustomHeadEnabled:bool:>HeadOverride,CustomHeadId:int64:>HeadOverride,CustomHeadScale:NumberRange:>CustomBuildHead,CustomHeight:NumberRange:>CustomWorldHeight,CustomHeightScale:NumberRange:>CustomBuildHeight,CustomLeftArmEnabled:bool:>LeftArmOverride,CustomLeftArmId:int64:>LeftArmOverride,CustomLeftLegEnabled:bool:>LeftLegOverride,CustomLeftLegId:int64:>LeftLegOverride,CustomMoodEnabled:bool:>MoodAnimationOverride,CustomMoodId:int64:>MoodAnimationOverride,CustomProportionsScale:NumberRange:>CustomBuildProportions,CustomRightArmEnabled:bool:>RightArmOverride,CustomRightArmId:int64:>RightArmOverride,CustomRightLegEnabled:bool:>RightLegOverride,CustomRightLegId:int64:>RightLegOverride,CustomTorsoEnabled:bool:>TorsoOverride,CustomTorsoId:int64:>TorsoOverride,CustomWidthScale:NumberRange:>CustomBuildWidth,CustomWorldHeight:NumberRange,HeadOverride:int64,KeepPlayerHead:bool,LeftArmOverride:int64,LeftLegOverride:int64,RightArmOverride:int64,RightLegOverride:int64,ScaleMode:token,TorsoOverride:int64",
		["AvatarChatService"] = "Instance|NS|",
		["AvatarClothingRules"] = "Instance||ClassicPantsOverride:int64,ClassicShirtOverride:int64,ClassicTShirtOverride:int64,ClothingMode:token,CustomClassicPantsAccessoryEnabled:bool:>ClassicPantsOverride,CustomClassicPantsAccessoryId:int64:>ClassicPantsOverride,CustomClassicShirtsAccessoryEnabled:bool:>ClassicShirtOverride,CustomClassicShirtsAccessoryId:int64:>ClassicShirtOverride,CustomClassicTShirtsAccessoryEnabled:bool:>ClassicTShirtOverride,CustomClassicTShirtsAccessoryId:int64:>ClassicTShirtOverride,CustomClothingMode:token:>TShirtAccessoryOverride,CustomDressSkirtAccessoryEnabled:bool:>DressSkirtAccessoryOverride,CustomDressSkirtAccessoryId:int64:>DressSkirtAccessoryOverride,CustomJacketAccessoryEnabled:bool:>JacketAccessoryOverride,CustomJacketAccessoryId:int64:>JacketAccessoryOverride,CustomLeftShoesAccessoryEnabled:bool:>LeftShoeAccessoryOverride,CustomLeftShoesAccessoryId:int64:>LeftShoeAccessoryOverride,CustomPantsAccessoryEnabled:bool:>PantsAccessoryOverride,CustomPantsAccessoryId:int64:>PantsAccessoryOverride,CustomRightShoesAccessoryEnabled:bool:>RightShoeAccessoryOverride,CustomRightShoesAccessoryId:int64:>RightShoeAccessoryOverride,CustomShirtAccessoryEnabled:bool:>ShirtAccessoryOverride,CustomShirtAccessoryId:int64:>ShirtAccessoryOverride,CustomShortsAccessoryEnabled:bool:>ShortsAccessoryOverride,CustomShortsAccessoryId:int64:>ShortsAccessoryOverride,CustomSweaterAccessoryEnabled:bool:>SweaterAccessoryOverride,CustomSweaterAccessoryId:int64:>SweaterAccessoryOverride,CustomTShirtAccessoryEnabled:bool:>TShirtAccessoryOverride,CustomTShirtAccessoryId:int64:>TShirtAccessoryOverride,DressSkirtAccessoryOverride:int64,JacketAccessoryOverride:int64,LeftShoeAccessoryOverride:int64,LimitBounds:Vector3,PantsAccessoryOverride:int64,RightShoeAccessoryOverride:int64,ShirtAccessoryOverride:int64,ShortsAccessoryOverride:int64,SweaterAccessoryOverride:int64,TShirtAccessoryOverride:int64",
		["AvatarCollisionRules"] = "Instance||BodyPartsCollidableOnDeath:bool,CollisionMode:token,HitboxSize:Vector3,LegacyCollisionMode:token,SingleColliderSize:Vector3,TouchAndQueryDetectionMode:token",
		["AvatarCreationService"] = "Instance|NS|",
		["AvatarEditorService"] = "Instance|NS|",
		["AvatarEffectDescription"] = "Instance||AssetId:int64,EffectType:token",
		["AvatarImportService"] = "Instance|NS|",
		["AvatarRules"] = "Instance||AvatarType:token:>AvatarType",
		["AvatarSettings"] = "Instance|NS|RulesSchemaVersion:int",
		["BackendReplicatedStorage"] = "Instance|NS|",
		["BackendServerScriptService"] = "Instance|NS|",
		["BackendServerStorage"] = "Instance|NS|",
		["Backpack"] = "Instance||",
		["BadgeService"] = "Instance|NS|",
		["BaseCoreGuiConfiguration"] = "Instance|N|Enabled:bool",
		["CapturesViewConfiguration"] = "BaseCoreGuiConfiguration|N|Open:bool",
		["PlayerListConfiguration"] = "BaseCoreGuiConfiguration|N|Open:bool",
		["SelfViewConfiguration"] = "BaseCoreGuiConfiguration|N|Open:bool",
		["BaseImportData"] = "Instance|N|ImportName:string,ShouldImport:bool",
		["AnimationImportData"] = "BaseImportData|N|ForceNewVersion:bool,VersionedAssetId:int64",
		["FacsImportData"] = "BaseImportData|N|",
		["GroupImportData"] = "BaseImportData|N|Anchored:bool,ImportAsModelAsset:bool,InsertInWorkspace:bool",
		["JointImportData"] = "BaseImportData|N|",
		["MaterialImportData"] = "BaseImportData|N|DiffuseFilePath:string,DiffuseVersionedAssetId:int64,EmissiveFilePath:string,EmissiveVersionedAssetId:int64,MetalnessFilePath:string,MetalnessVersionedAssetId:int64,NormalFilePath:string,NormalVersionedAssetId:int64,RoughnessFilePath:string,RoughnessVersionedAssetId:int64",
		["MeshImportData"] = "BaseImportData|N|Anchored:bool,CageMeshIntersectedPreview:bool,CageNonManifoldPreview:bool,CageOverlappingVerticesPreview:bool,CageUVMisMatchedPreview:bool,DoubleSided:bool,IgnoreVertexColors:bool,IrrelevantCageModifiedPreview:bool,MeshHoleDetectedPreview:bool,OuterCageFarExtendedFromMeshPreview:bool,UseImportedPivot:bool,VersionedAssetId:int64",
		["RootImportData"] = "BaseImportData|N|AddModelToInventory:bool,Anchored:bool,AnimationIdForRestPose:float,ExistingPackageId:string,ImportAsModelAsset:bool,ImportAsPackage:bool,InsertInWorkspace:bool,InsertWithScenePosition:bool,InvertNegativeFaces:bool,KeepZeroInfluenceBones:bool,MergeMeshes:bool,PhysicalConstraintType:token,PreferredUploadId:int64,RestPose:token,RigScale:token,RigType:token,RigVisualization:bool,ScaleFactor:float,ScaleUnit:token,UseSceneOriginAsPivot:bool,UsesCages:bool,VersionedAssetId:int64,WorldForward:token,WorldUp:token",
		["BasePlayerGui"] = "Instance|N|",
		["CoreGui"] = "BasePlayerGui|NS|SelectionImageObject:Ref",
		["PlayerGui"] = "BasePlayerGui|N|ScreenOrientation:token,SelectionImageObject:Ref",
		["StarterGui"] = "BasePlayerGui|NS|ClipsDescendantsSupportsRotation:token:H,ResetPlayerGuiOnSpawn:bool,RtlTextSupport:token:H,ScreenOrientation:token,ShowDevelopmentGui:bool,StudioDefaultStyleSheet:Ref,StudioInsertWidgetLayerCollectorAutoLinkStyleSheet:Ref,VirtualCursorMode:token:H",
		["BaseRemoteEvent"] = "Instance|N|",
		["RemoteEvent"] = "BaseRemoteEvent||",
		["UnreliableRemoteEvent"] = "BaseRemoteEvent||",
		["BaseWrap"] = "Instance|N|CageMeshContent:Content,CageMeshId:ContentId,CageOrigin:CFrame,HSRAssetId:ContentId,HSRContent:Content,HSRData:SharedString:H,HSRMeshIdData:SharedString:H,ImportOrigin:CFrame,TemporaryCageMeshContent:Content:H,TemporaryCageMeshId:ContentId:H",
		["WrapDeformer"] = "BaseWrap||",
		["WrapLayer"] = "BaseWrap||AutoSkin:token,BindOffset:CFrame,Enabled:bool,NonUniformScaleContent:Content,Order:int,Puffiness:float,ReferenceMeshContent:Content,ReferenceMeshId:ContentId,ReferenceOrigin:CFrame,RotateUniformScaleContent:Content,ShrinkFactor:float,TargetShaping:float,TemporaryReferenceId:ContentId:H,TemporaryReferenceMeshContent:Content:H,UniformScaleContent:Content",
		["WrapTarget"] = "BaseWrap||Stiffness:float",
		["Beam"] = "Instance||Attachment0:Ref,Attachment1:Ref,Brightness:float,Color:ColorSequence,CurveSize0:float,CurveSize1:float,Enabled:bool,FaceCamera:bool,LightEmission:float,LightInfluence:float,Segments:int,Texture:ContentId,TextureContent:Content,TextureLength:float,TextureMode:token,TextureSpeed:float,Transparency:NumberSequence,Width0:float,Width1:float,ZOffset:float",
		["BindableEvent"] = "Instance||",
		["BindableFunction"] = "Instance||",
		["BodyMover"] = "Instance|N|",
		["BodyAngularVelocity"] = "BodyMover||AngularVelocity:Vector3,MaxTorque:Vector3,P:float",
		["BodyForce"] = "BodyMover||Force:Vector3",
		["BodyGyro"] = "BodyMover||CFrame:CFrame,D:float,MaxTorque:Vector3,P:float",
		["BodyPosition"] = "BodyMover||D:float,MaxForce:Vector3,P:float,Position:Vector3",
		["BodyThrust"] = "BodyMover||Force:Vector3,Location:Vector3",
		["BodyVelocity"] = "BodyMover||MaxForce:Vector3,P:float,Velocity:Vector3",
		["RocketPropulsion"] = "BodyMover||CartoonFactor:float,MaxSpeed:float,MaxThrust:float,MaxTorque:Vector3,Target:Ref,TargetOffset:Vector3,TargetRadius:float,ThrustD:float,ThrustP:float,TurnD:float,TurnP:float",
		["BodyPartDescription"] = "Instance||AssetId:int64,BodyPart:token,Color:Color3,HeadShape:string,Instance:Ref",
		["BranchService"] = "Instance|NS|",
		["Breakpoint"] = "Instance||",
		["BrowserService"] = "Instance|NS|",
		["BugReporterService"] = "Instance|NS|",
		["CacheableContentProvider"] = "Instance|NS|",
		["HSRDataContentProvider"] = "CacheableContentProvider|NS|",
		["MeshContentProvider"] = "CacheableContentProvider|NS|",
		["SlimContentProvider"] = "CacheableContentProvider|NS|",
		["SolidModelContentProvider"] = "CacheableContentProvider|NS|",
		["WrapContentProvider"] = "CacheableContentProvider|NS|",
		["CallingService"] = "Instance|NS|",
		["CalloutService"] = "Instance|NS|",
		["CaptureService"] = "Instance|NS|",
		["ChangeHistoryService"] = "Instance|NS|",
		["ChangeHistoryStreamingService"] = "Instance|NS|",
		["CharacterAppearance"] = "Instance|N|",
		["BodyColors"] = "CharacterAppearance||HeadColor3:Color3,LeftArmColor3:Color3,LeftLegColor3:Color3,RightArmColor3:Color3,RightLegColor3:Color3,TorsoColor3:Color3",
		["CharacterMesh"] = "CharacterAppearance||BaseTextureContent:Content,BaseTextureId:int64,BodyPart:token,MeshContent:Content,OverlayTextureContent:Content",
		["Clothing"] = "CharacterAppearance|N|Color3:Color3",
		["Pants"] = "Clothing||PantsTemplate:ContentId,PantsTemplateContent:Content",
		["Shirt"] = "Clothing||ShirtTemplate:ContentId,ShirtTemplateContent:Content",
		["ShirtGraphic"] = "CharacterAppearance||Color3:Color3,Graphic:ContentId,TextureContent:Content",
		["Skin"] = "CharacterAppearance||SkinColor:BrickColor",
		["Chat"] = "Instance|NS|BubbleChatEnabled:bool,IsAutoMigrated:bool,LoadDefaultChat:bool",
		["ClickDetector"] = "Instance||CursorIcon:ContentId,CursorIconContent:Content,MaxActivationDistance:float",
		["DragDetector"] = "ClickDetector||ActivatedCursorIcon:ContentId,ActivatedCursorIconContent:Content,ApplyAtCenterOfMass:bool,DragFrame:CFrame,DragStyle:token,Enabled:bool,GamepadModeSwitchKeyCode:token,KeyboardModeSwitchKeyCode:token,MaxDragAngle:float,MaxDragTranslation:Vector3,MaxForce:float,MaxTorque:float,MinDragAngle:float,MinDragTranslation:Vector3,Orientation:Vector3,PermissionPolicy:token,ReferenceInstance:Ref,ResponseStyle:token,Responsiveness:float,RunLocally:bool,TrackballRadialPullFactor:float,TrackballRollFactor:float,VRSwitchKeyCode:token",
		["ClientStorageService"] = "Instance|NS|",
		["CloudCRUDService"] = "Instance|NS|",
		["CloudClientService"] = "Instance|NS|RobloxRealityFilterEnabled:bool",
		["CloudExecutionService"] = "Instance|NS|",
		["Clouds"] = "Instance||Color:Color3,Cover:float,Density:float,Enabled:bool",
		["ClusterPacketCache"] = "Instance|NS|",
		["Collaborator"] = "Instance|N|",
		["CollaboratorsService"] = "Instance|NS|",
		["CollectionService"] = "Instance|NS|",
		["CommerceService"] = "Instance|NS|",
		["CompositeValueCurve"] = "Instance||CurveType:token",
		["ConfigService"] = "Instance|NS|",
		["Configuration"] = "Instance||",
		["ConfigureServerService"] = "Instance|NS|",
		["ConnectivityService"] = "Instance|NS|",
		["Constraint"] = "Instance|N|Attachment0:Ref,Attachment1:Ref,Color:BrickColor,Enabled:bool,Visible:bool",
		["AlignOrientation"] = "Constraint||AlignType:token,CFrame:CFrame,MaxAngularVelocity:float,MaxTorque:float,Mode:token,PrimaryAxisOnly:bool,ReactionTorqueEnabled:bool,Responsiveness:float,RigidityEnabled:bool",
		["AlignPosition"] = "Constraint||ApplyAtCenterOfMass:bool,ForceLimitMode:token,ForceRelativeTo:token,MaxAxesForce:Vector3,MaxForce:float,MaxVelocity:float,Mode:token,Position:Vector3,ReactionForceEnabled:bool,Responsiveness:float,RigidityEnabled:bool",
		["AngularVelocity"] = "Constraint||AngularVelocity:Vector3,MaxTorque:float,ReactionTorqueEnabled:bool,RelativeTo:token",
		["AnimationConstraint"] = "Constraint||AngularDamping:float,AngularStrength:float,IsKinematic:bool,LinearDamping:float,LinearStrength:float,MaxForce:float,MaxTorque:float,Transform:CFrame",
		["BallSocketConstraint"] = "Constraint||LimitsEnabled:bool,MaxFrictionTorqueXml:float:H,Radius:float,Restitution:float,TwistLimitsEnabled:bool,TwistLowerAngle:float,TwistUpperAngle:float,UpperAngle:float",
		["HingeConstraint"] = "Constraint||ActuatorType:token,AngularResponsiveness:float,AngularSpeed:float,AngularVelocity:float,LimitsEnabled:bool,LowerAngle:float,MotorMaxAcceleration:float,MotorMaxTorque:float,Radius:float,Restitution:float,ServoMaxTorque:float,SoftlockServoUponReachingTarget:bool,TargetAngle:float,UpperAngle:float",
		["LineForce"] = "Constraint||ApplyAtCenterOfMass:bool,InverseSquareLaw:bool,Magnitude:float,MaxForce:float,ReactionForceEnabled:bool",
		["LinearVelocity"] = "Constraint||ForceLimitMode:token,ForceLimitsEnabled:bool,LineDirection:Vector3,LineVelocity:float,MaxAxesForce:Vector3,MaxForce:float,MaxPlanarAxesForce:Vector2,PlaneVelocity:Vector2,PrimaryTangentAxis:Vector3,ReactionForceEnabled:bool,RelativeTo:token,SecondaryTangentAxis:Vector3,VectorVelocity:Vector3,VelocityConstraintMode:token",
		["PlaneConstraint"] = "Constraint||",
		["Plane"] = "PlaneConstraint||",
		["RigidConstraint"] = "Constraint||",
		["RodConstraint"] = "Constraint||Length:float,LimitAngle0:float,LimitAngle1:float,LimitsEnabled:bool,Thickness:float",
		["RopeConstraint"] = "Constraint||Length:float,Restitution:float,Thickness:float,WinchEnabled:bool,WinchForce:float,WinchResponsiveness:float,WinchSpeed:float,WinchTarget:float",
		["SlidingBallConstraint"] = "Constraint|N|ActuatorType:token,LimitsEnabled:bool,LinearResponsiveness:float,LowerLimit:float,MotorMaxAcceleration:float,MotorMaxForce:float,Restitution:float,ServoMaxForce:float,Size:float,SoftlockServoUponReachingTarget:bool,Speed:float,TargetPosition:float,UpperLimit:float,Velocity:float",
		["CylindricalConstraint"] = "SlidingBallConstraint||AngularActuatorType:token,AngularLimitsEnabled:bool,AngularResponsiveness:float,AngularRestitution:float,AngularSpeed:float,AngularVelocity:float,InclinationAngle:float,LowerAngle:float,MotorMaxAngularAcceleration:float,MotorMaxTorque:float,RotationAxisVisible:bool,ServoMaxTorque:float,SoftlockAngularServoUponReachingTarget:bool,TargetAngle:float,UpperAngle:float",
		["PrismaticConstraint"] = "SlidingBallConstraint||",
		["SpringConstraint"] = "Constraint||Coils:float,Damping:float,FreeLength:float,LimitsEnabled:bool,MaxForce:float,MaxLength:float,MinLength:float,Radius:float,Stiffness:float,Thickness:float",
		["Torque"] = "Constraint||RelativeTo:token,Torque:Vector3",
		["TorsionSpringConstraint"] = "Constraint||Coils:float,Damping:float,LimitEnabled:bool:>LimitsEnabled,LimitsEnabled:bool,MaxAngle:float,MaxTorque:float,Radius:float,Restitution:float,Stiffness:float",
		["UniversalConstraint"] = "Constraint||LimitsEnabled:bool,MaxAngle:float,Radius:float,Restitution:float",
		["VectorForce"] = "Constraint||ApplyAtCenterOfMass:bool,Force:Vector3,RelativeTo:token",
		["ContentProvider"] = "Instance|NS|",
		["ContextActionService"] = "Instance|NS|",
		["ControlState"] = "Instance||Owner:Ref,StateSchema:BinaryString:H",
		["Controller"] = "Instance|N|",
		["HumanoidController"] = "Controller||",
		["SkateboardController"] = "Controller||",
		["VehicleController"] = "Controller||",
		["ControllerBase"] = "Instance|N|BalanceRigidityEnabled:bool,MoveSpeedFactor:float",
		["AirController"] = "ControllerBase||BalanceMaxTorque:float,BalanceSpeed:float,MaintainAngularMomentum:bool,MaintainLinearMomentum:bool,MoveMaxForce:float,TurnMaxTorque:float,TurnSpeedFactor:float",
		["ClimbController"] = "ControllerBase||AccelerationTime:float,BalanceMaxTorque:float,BalanceSpeed:float,MoveMaxForce:float",
		["GroundController"] = "ControllerBase||AccelerationLean:float,AccelerationTime:float,BalanceMaxTorque:float,BalanceSpeed:float,DecelerationTime:float,Friction:float,FrictionWeight:float,GroundOffset:float,StandForce:float,StandSpeed:float,TurnSpeedFactor:float",
		["SwimController"] = "ControllerBase||AccelerationTime:float,PitchMaxTorque:float,PitchSpeedFactor:float,RollMaxTorque:float,RollSpeedFactor:float",
		["ControllerManager"] = "Instance||ActiveController:Ref,BaseMoveSpeed:float,BaseTurnSpeed:float,ClimbSensor:Ref,FacingDirection:Vector3,GroundSensor:Ref,MovingDirection:Vector3,RootPart:Ref,UpDirection:Vector3",
		["ControllerService"] = "Instance|NS|",
		["CookiesService"] = "Instance|NS|",
		["CoreGuiConfiguration"] = "Instance|NS|CapturesViewConfiguration:Ref,PlayerListConfiguration:Ref,SelfViewConfiguration:Ref",
		["CorePackages"] = "Instance|NS|",
		["CoreScriptDebuggingManagerHelper"] = "Instance|NS|",
		["CoreScriptSyncService"] = "Instance|NS|",
		["CreationDBService"] = "Instance|NS|",
		["CreatorStoreService"] = "Instance|NS|",
		["CrossDMScriptChangeListener"] = "Instance|NS|",
		["CustomEvent"] = "Instance||PersistedCurrentValue:float:H",
		["CustomEventReceiver"] = "Instance||Source:Ref",
		["CustomLog"] = "Instance||",
		["DataModelMesh"] = "Instance|N|Offset:Vector3,Scale:Vector3,VertexColor:Vector3",
		["BevelMesh"] = "DataModelMesh|N|Bevel:float:H,Bevel Roundness:float:H,Bulge:float:H",
		["BlockMesh"] = "BevelMesh||",
		["CylinderMesh"] = "BevelMesh||",
		["FileMesh"] = "DataModelMesh||MeshContent:Content,MeshId:ContentId,TextureContent:Content,TextureId:ContentId",
		["SpecialMesh"] = "FileMesh||MeshType:token",
		["DataModelSession"] = "Instance|N|",
		["DataStoreGetOptions"] = "Instance||UseCache:bool",
		["DataStoreIncrementOptions"] = "Instance||",
		["DataStoreInfo"] = "Instance|N|",
		["DataStoreKey"] = "Instance|N|",
		["DataStoreKeyInfo"] = "Instance|N|",
		["DataStoreObjectVersionInfo"] = "Instance|N|",
		["DataStoreOptions"] = "Instance||AllScopes:bool",
		["DataStoreService"] = "Instance|NS|AutomaticRetry:bool,LegacyNamingScheme:bool",
		["DataStoreSetOptions"] = "Instance||",
		["Debris"] = "Instance|NS|MaxItems:int",
		["DebugSettings"] = "Instance|NS|IsScriptStackTracingEnabled:bool,ReportSoundWarnings:bool,TickCountPreciseOverride:token",
		["DebuggablePluginWatcher"] = "Instance|NS|",
		["DebuggerBreakpoint"] = "Instance|N|Condition:string,ContinueExecution:bool,IsEnabled:bool,LogExpression:string,isContextDependentBreakpoint:bool,line:int:H",
		["DebuggerConnection"] = "Instance|N|",
		["LocalDebuggerConnection"] = "DebuggerConnection|N|",
		["DebuggerConnectionManager"] = "Instance|NS|Timeout:double",
		["DebuggerLuaResponse"] = "Instance|N|",
		["DebuggerManager"] = "Instance|NS|",
		["DebuggerUIService"] = "Instance|NS|",
		["DebuggerVariable"] = "Instance|N|",
		["DebuggerWatch"] = "Instance||Expression:string",
		["DeferredAssetManagerService"] = "Instance|NS|JoiningPlaceId:int64,JoiningUniverseId:int64,PregameLoadingScreenOnly:bool",
		["DesignFoundationsService"] = "Instance|NS|",
		["DeviceDisplayService"] = "Instance|NS|",
		["DeviceIdService"] = "Instance|NS|",
		["Dialog"] = "Instance||BehaviorType:token,ConversationDistance:float,GoodbyeChoiceActive:bool,GoodbyeDialog:string,InitialPrompt:string,Purpose:token,Tone:token,TriggerDistance:float,TriggerOffset:Vector3",
		["DialogChoice"] = "Instance||GoodbyeChoiceActive:bool,GoodbyeDialog:string,ResponseDialog:string,UserDialog:string",
		["DigitsRigDescription"] = "Instance||Index1:Ref,Index1TposeAdjustment:CFrame,Index2:Ref,Index2TposeAdjustment:CFrame,Index3:Ref,Index3TposeAdjustment:CFrame,IndexRange:Vector3,IndexSize:float,Middle1:Ref,Middle1TposeAdjustment:CFrame,Middle2:Ref,Middle2TposeAdjustment:CFrame,Middle3:Ref,Middle3TposeAdjustment:CFrame,MiddleRange:Vector3,MiddleSize:float,Pinky1:Ref,Pinky1TposeAdjustment:CFrame,Pinky2:Ref,Pinky2TposeAdjustment:CFrame,Pinky3:Ref,Pinky3TposeAdjustment:CFrame,PinkyRange:Vector3,PinkySize:float,Ring1:Ref,Ring1TposeAdjustment:CFrame,Ring2:Ref,Ring2TposeAdjustment:CFrame,Ring3:Ref,Ring3TposeAdjustment:CFrame,RingRange:Vector3,RingSize:float,Side:token,Thumb1:Ref,Thumb1TposeAdjustment:CFrame,Thumb2:Ref,Thumb2TposeAdjustment:CFrame,Thumb3:Ref,Thumb3TposeAdjustment:CFrame,ThumbRange:Vector3,ThumbSize:float",
		["DisplayWakeLock"] = "Instance|N|",
		["DraftsService"] = "Instance|NS|",
		["Dragger"] = "Instance||",
		["DraggerService"] = "Instance|NS|",
		["EditableService"] = "Instance|NS|",
		["EditorSourceService"] = "Instance|NS|",
		["EncodingService"] = "Instance|NS|",
		["EulerRotationCurve"] = "Instance||RotationOrder:token",
		["EventIngestService"] = "Instance|NS|",
		["ExampleV2Service"] = "Instance|NS|",
		["ExperienceAuthService"] = "Instance|NS|",
		["ExperienceInviteOptions"] = "Instance||InviteMessageId:string,InviteUser:int64,LaunchData:string,PromptMessage:string",
		["ExperienceNotificationService"] = "Instance|NS|",
		["ExperienceService"] = "Instance|NS|",
		["ExperienceStateCaptureService"] = "Instance|NS|",
		["ExperienceStateRecordingService"] = "Instance|NS|",
		["ExplorerFilter"] = "Instance||",
		["ExplorerFilterAutocompleter"] = "Instance|N|",
		["ExplorerServiceVisibilityService"] = "Instance|NS|",
		["Explosion"] = "Instance||BlastPressure:float,BlastRadius:float,DestroyJointRadiusPercent:float,ExplosionType:token,Position:Vector3,TimeScale:float,Visible:bool",
		["ExternalIdentityService"] = "Instance|NS|",
		["FaceAnimatorService"] = "Instance|NS|",
		["FaceControls"] = "Instance||InternalOverrideFACSData:BinaryString:H",
		["FaceInstance"] = "Instance|N|Face:token",
		["Decal"] = "FaceInstance||AutoLocalize:bool,Color3:Color3,EmissiveMaskContent:Content,EmissiveStrength:float,EmissiveTint:Color3,MetalnessMap:ContentId,MetalnessMapContent:Content,NormalMap:ContentId,NormalMapContent:Content,ResampleMode:token,Rotation:float,RoughnessMap:ContentId,RoughnessMapContent:Content,Texture:ContentId,TextureContent:Content,TexturePack:ContentId,TexturePackContent:Content,TexturePackMetadata:string:H,Transparency:float,UVOffset:Vector2,UVScale:Vector2,ZIndex:int",
		["Texture"] = "Decal||OffsetStudsU:float,OffsetStudsV:float,StudsPerTileU:float,StudsPerTileV:float",
		["FacialAgeEstimationService"] = "Instance|NS|",
		["FacialAnimationRecordingService"] = "Instance|NS|",
		["FacialAnimationStreamingServiceStats"] = "Instance|N|",
		["FacialAnimationStreamingServiceV2"] = "Instance|NS|ServiceState:int",
		["FacialAnimationStreamingSubsessionStats"] = "Instance|N|",
		["Feature"] = "Instance|N|FaceId:token,InOut:token,LeftRight:token,TopBottom:token",
		["Hole"] = "Feature||",
		["MotorFeature"] = "Feature||",
		["FeatureMatchingService"] = "Instance|NS|",
		["FeatureMatchingTable"] = "Instance||Data:SharedString:H",
		["FeatureRestrictionManager"] = "Instance|NS|",
		["File"] = "Instance|N|",
		["FileManagerService"] = "Instance|NS|",
		["FilePickerService"] = "Instance|NS|",
		["FileSyncReplicationService"] = "Instance|NS|",
		["Fire"] = "Instance||Color:Color3,Enabled:bool,SecondaryColor:Color3,TimeScale:float,heat_xml:float:H,size_xml:float:H",
		["FlagStandService"] = "Instance|NS|",
		["FloatCurve"] = "Instance||ValuesAndTimes:BinaryString:H",
		["FlyweightService"] = "Instance|S|",
		["CSGDictionaryService"] = "FlyweightService|S|",
		["NonReplicatedCSGDictionaryService"] = "FlyweightService|S|",
		["Folder"] = "Instance||ExplorerIconContent:Content,IconTint:Color3",
		["GeneratedFolder"] = "Folder||",
		["FollowRotationBoneBehavior"] = "Instance||CounterRotate:bool,Driver:Ref,Weight:float",
		["FollowTwistBoneBehavior"] = "Instance||Axis:token,AxisMode:token,CounterRotate:bool,Driver:Ref,EndBone:Ref,StartBone:Ref,Weight:float",
		["ForceField"] = "Instance||Visible:bool",
		["FriendService"] = "Instance|NS|",
		["FriendsCallingInstance"] = "Instance|N|",
		["FriendsCallingParticipant"] = "Instance|N|",
		["FriendsCallingService"] = "Instance|NS|",
		["FunctionalTest"] = "Instance||Description:string,HasMigratedSettingsToTestService:bool:H",
		["GameDownloaderService"] = "Instance|NS|",
		["GamePassService"] = "Instance|NS|",
		["GameSettings"] = "Instance|NS|VideoCaptureEnabled:bool",
		["GamepadService"] = "Instance|NS|GamepadCursorEnabled:bool",
		["GenerationService"] = "Instance|NS|",
		["GenericChallengeService"] = "Instance|NS|",
		["Geometry"] = "Instance|NS|",
		["GeometryService"] = "Instance|NS|",
		["GetTextBoundsParams"] = "Instance||Font:Font,RichText:bool,Size:float,Text:string,Width:float",
		["GlobalDataStore"] = "Instance|N|",
		["DataStore"] = "GlobalDataStore|N|",
		["OrderedDataStore"] = "GlobalDataStore|N|",
		["GongService"] = "Instance|NS|",
		["GroupService"] = "Instance|NS|",
		["GuiBase"] = "Instance|N|",
		["GuiBase2d"] = "GuiBase|N|AutoLocalize:bool,RootLocalizationTable:Ref,SelectionBehaviorDown:token,SelectionBehaviorLeft:token,SelectionBehaviorRight:token,SelectionBehaviorUp:token,SelectionGroup:bool",
		["GuiObject"] = "GuiBase2d|N|Active:bool,AnchorPoint:Vector2,AutomaticSize:token,BackgroundColor3:Color3,BackgroundTransparency:float,BorderColor3:Color3,BorderMode:token,BorderSizePixel:int,ClipsDescendants:bool,Draggable:bool,Interactable:bool,LayoutOrder:int,NextSelectionDown:Ref,NextSelectionLeft:Ref,NextSelectionRight:Ref,NextSelectionUp:Ref,Position:UDim2,Rotation:float,Selectable:bool,SelectionImageObject:Ref,SelectionOrder:int,Sink:token:H,Size:UDim2,SizeConstraint:token,Visible:bool,ZIndex:int",
		["CanvasGroup"] = "GuiObject||GroupColor3:Color3,GroupTransparency:float",
		["Frame"] = "GuiObject||Style:token",
		["GuiButton"] = "GuiObject|N|AutoButtonColor:bool,HoverHapticEffect:Ref,Modal:bool,PressHapticEffect:Ref,Selected:bool,Style:token",
		["ImageButton"] = "GuiButton||HoverImage:ContentId,HoverImageContent:Content,Image:ContentId,ImageColor3:Color3,ImageContent:Content,ImageRectOffset:Vector2,ImageRectSize:Vector2,ImageTransparency:float,PressedImage:ContentId,PressedImageContent:Content,ResampleMode:token,ScaleType:token,SliceCenter:Rect,SliceScale:float,TileSize:UDim2",
		["TextButton"] = "GuiButton||FontFace:Font,LineHeight:float,LocalizationMatchIdentifier:string,LocalizationMatchedSourceText:string,MaxVisibleGraphemes:int,OpenTypeFeatures:string,RichText:bool,Text:string,TextColor3:Color3,TextDirection:token,TextScaled:bool,TextSize:float,TextStrokeColor3:Color3,TextStrokeTransparency:float,TextTransparency:float,TextTruncate:token,TextWrapped:bool,TextXAlignment:token,TextYAlignment:token",
		["GuiLabel"] = "GuiObject|N|",
		["ImageLabel"] = "GuiLabel||Image:ContentId,ImageColor3:Color3,ImageContent:Content,ImageRectOffset:Vector2,ImageRectSize:Vector2,ImageTransparency:float,ResampleMode:token,ScaleType:token,SliceCenter:Rect,SliceScale:float,TileSize:UDim2",
		["TextLabel"] = "GuiLabel||FontFace:Font,LineHeight:float,LocalizationMatchIdentifier:string,LocalizationMatchedSourceText:string,MaxVisibleGraphemes:int,OpenTypeFeatures:string,RichText:bool,Text:string,TextColor3:Color3,TextDirection:token,TextScaled:bool,TextSize:float,TextStrokeColor3:Color3,TextStrokeTransparency:float,TextTransparency:float,TextTruncate:token,TextWrapped:bool,TextXAlignment:token,TextYAlignment:token",
		["InputActionLabel"] = "GuiObject||FontFace:Font,ImageColor3:Color3,ImageTransparency:float,InputAction:Ref,TextColor3:Color3,TextSize:float,TextTransparency:float,TextWrapped:bool,TextXAlignment:token,TextYAlignment:token",
		["RelativeGui"] = "GuiObject||",
		["ScrollingFrame"] = "GuiObject||AutomaticCanvasSize:token,BottomImage:ContentId,BottomImageContent:Content,CanvasPosition:Vector2,CanvasSize:UDim2,ElasticBehavior:token,HorizontalScrollBarInset:token,MidImage:ContentId,MidImageContent:Content,ScrollBarImageColor3:Color3,ScrollBarImageTransparency:float,ScrollBarThickness:int,ScrollingDirection:token,ScrollingEnabled:bool,TopImage:ContentId,TopImageContent:Content,VerticalScrollBarInset:token,VerticalScrollBarPosition:token",
		["TextBox"] = "GuiObject||ClearTextOnFocus:bool,FontFace:Font,LineHeight:float,LocalizationMatchIdentifier:string,LocalizationMatchedSourceText:string,MaxVisibleGraphemes:int,MultiLine:bool,OpenTypeFeatures:string,PlaceholderColor3:Color3,PlaceholderText:string,RichText:bool,ShowNativeInput:bool,Text:string,TextColor3:Color3,TextDirection:token,TextEditable:bool,TextScaled:bool,TextSize:float,TextStrokeColor3:Color3,TextStrokeTransparency:float,TextTransparency:float,TextTruncate:token,TextWrapped:bool,TextXAlignment:token,TextYAlignment:token",
		["TextChannelWindow"] = "GuiObject||FontFace:Font,Target:Ref,UseDefaultFont:bool",
		["VideoDisplay"] = "GuiObject||ResampleMode:token,ScaleType:token,TileSize:UDim2,VideoColor3:Color3,VideoRectOffset:Vector2,VideoRectSize:Vector2,VideoTransparency:float",
		["VideoFrame"] = "GuiObject||InternalVideoUsage:token,Looped:bool,MaximumResolution:token,Playing:bool,RollOffMaxDistance:float,RollOffMinDistance:float,RollOffMode:token,TimePosition:double,Video:ContentId,VideoContent:Content,Volume:float",
		["ViewportFrame"] = "GuiObject||Ambient:Color3,CameraCFrame:CFrame:H,CameraFieldOfView:float:H,ImageColor3:Color3,ImageTransparency:float,LightColor:Color3,LightDirection:Vector3",
		["LayerCollector"] = "GuiBase2d|N|Enabled:bool,InputSinkEnabled:token,ResetOnSpawn:bool,ZIndexBehavior:token",
		["BillboardGui"] = "LayerCollector||Active:bool,Adornee:Ref,AlwaysOnTop:bool,Brightness:float,ClipsDescendants:bool,DistanceLowerLimit:float,DistanceUpperLimit:float,ExtentsOffset:Vector3,ExtentsOffsetWorldSpace:Vector3,LightInfluence:float,MaxDistance:float,PlayerToHideFrom:Ref,Size:UDim2,SizeOffset:Vector2,StudsOffset:Vector3,StudsOffsetWorldSpace:Vector3",
		["PluginGui"] = "LayerCollector|N|Title:string",
		["DockWidgetPluginGui"] = "PluginGui|N|",
		["QWidgetPluginGui"] = "PluginGui|N|",
		["ScreenGui"] = "LayerCollector||ClipToDeviceSafeArea:bool,DisplayOrder:int,SafeAreaCompatibility:token,ScreenInsets:token",
		["GuiMain"] = "ScreenGui||",
		["SurfaceGuiBase"] = "LayerCollector|N|Active:bool,Adornee:Ref,Face:token",
		["AdGui"] = "SurfaceGuiBase||AdShape:token,EnableVideoAds:bool,FallbackImage:ContentId,FallbackImageContent:Content",
		["SurfaceGui"] = "SurfaceGuiBase||AlwaysOnTop:bool,Brightness:float,CanvasSize:Vector2,ClipsDescendants:bool,LightInfluence:float,MaxDistance:float,PixelsPerStud:float,SizingMode:token,ToolPunchThroughDistance:float,ZOffset:float",
		["GuiBase3d"] = "GuiBase|N|Color3:Color3,Transparency:float,Visible:bool",
		["FloorWire"] = "GuiBase3d||CycleOffset:float,From:Ref,StudsBetweenTextures:float,Texture:ContentId,TextureSize:Vector2,To:Ref,Velocity:float,WireRadius:float",
		["InstanceAdornment"] = "GuiBase3d|N|Adornee:Ref",
		["SelectionBox"] = "InstanceAdornment||LineThickness:float,StudioSelectionBox:bool,SurfaceColor3:Color3,SurfaceTransparency:float",
		["PVAdornment"] = "GuiBase3d|N|Adornee:Ref",
		["HandleAdornment"] = "PVAdornment|N|AdornCullingMode:token,AlwaysOnTop:bool,CFrame:CFrame,SizeRelativeOffset:Vector3,ZIndex:int",
		["BoxHandleAdornment"] = "HandleAdornment||DoubleSided:bool,Shading:token,Size:Vector3",
		["ConeHandleAdornment"] = "HandleAdornment||DoubleSided:bool,Height:float,Hollow:bool,Radius:float,Shading:token",
		["CylinderHandleAdornment"] = "HandleAdornment||Angle:float,DoubleSided:bool,Height:float,InnerRadius:float,Radius:float,Shading:token",
		["ImageHandleAdornment"] = "HandleAdornment||DoubleSided:bool,Image:ContentId,ImageContent:Content,Size:Vector2",
		["LineHandleAdornment"] = "HandleAdornment||Length:float,Thickness:float",
		["PyramidHandleAdornment"] = "HandleAdornment||DoubleSided:bool,Height:float,Shading:token,Sides:int,Size:float",
		["SphereHandleAdornment"] = "HandleAdornment||DoubleSided:bool,Radius:float,Shading:token",
		["WireframeHandleAdornment"] = "HandleAdornment||Scale:Vector3,Thickness:float",
		["ParabolaAdornment"] = "PVAdornment||",
		["SelectionSphere"] = "PVAdornment||SurfaceColor3:Color3,SurfaceTransparency:float",
		["PartAdornment"] = "GuiBase3d|N|Adornee:Ref",
		["HandlesBase"] = "PartAdornment|N|",
		["ArcHandles"] = "HandlesBase||Axes:Axes",
		["Handles"] = "HandlesBase||Faces:Faces,Style:token",
		["SurfaceSelection"] = "PartAdornment||TargetSurface:token",
		["SelectionLasso"] = "GuiBase3d|N|Humanoid:Ref",
		["SelectionPartLasso"] = "SelectionLasso||Part:Ref",
		["SelectionPointLasso"] = "SelectionLasso||Point:Vector3",
		["Path2D"] = "GuiBase||Closed:bool,Color3:Color3,PropertiesSerialize:BinaryString:H,Thickness:float,Transparency:float,Visible:bool,ZIndex:int",
		["GuiService"] = "Instance|NS|AutoSelectGuiEnabled:bool,DisplayScalingMode:token,GuiNavigationEnabled:bool,SelectedObject:Ref",
		["GuidRegistryService"] = "Instance|NS|",
		["HapticEffect"] = "Instance||Looped:bool,Position:Vector3,Radius:float,Type:token,WaveformData:BinaryString:H",
		["HapticService"] = "Instance|NS|",
		["HarmonyService"] = "Instance|NS|",
		["HeapProfilerService"] = "Instance|NS|",
		["HeatmapQueryService"] = "Instance|NS|",
		["HeatmapService"] = "Instance|NS|",
		["HeightmapImporterService"] = "Instance|S|",
		["HiddenPlayerService"] = "Instance|NS|",
		["HiddenSurfaceRemovalAsset"] = "Instance||HSRData:BinaryString:H,HSRMeshIdData:BinaryString:H",
		["Highlight"] = "Instance||Adornee:Ref,DepthMode:token,Enabled:bool,FillColor:Color3,FillTransparency:float,OutlineColor:Color3,OutlineTransparency:float",
		["Hopper"] = "Instance|NS|",
		["HttpRbxApiService"] = "Instance|NS|",
		["HttpRequest"] = "Instance|N|",
		["HttpService"] = "Instance|NS|HttpEnabled:bool",
		["Humanoid"] = "Instance||AutoJumpEnabled:bool,AutoRotate:bool,AutomaticScalingEnabled:bool,BreakJointsOnDeath:bool,CollisionType:token,DisplayDistanceType:token,DisplayName:string,EvaluateStateMachine:bool,HealthDisplayDistance:float,HealthDisplayType:token,Health_XML:float:H,HipHeight:float,InternalBodyScale:Vector3:H,InternalHeadScale:float:H,JumpHeight:float,JumpPower:float,MaxHealth:float,MaxSlopeAngle:float,NameDisplayDistance:float,NameOcclusion:token,RequiresNeck:bool,RigType:token,UseJumpPower:bool,WalkSpeed:float",
		["HumanoidDescription"] = "Instance||BodyTypeScale:float,ClimbAnimation:int64,DepthScale:float,EmotesDataInternal:string:H,EquippedEmotesDataInternal:string:H,Face:int64,FallAnimation:int64,GraphicTShirt:int64,HeadScale:float,HeightScale:float,IdleAnimation:int64,JumpAnimation:int64,MoodAnimation:int64,Pants:int64,ProportionScale:float,RunAnimation:int64,Shirt:int64,StaticFacialAnimation:bool,SwimAnimation:int64,UseAvatarSettings:bool,WalkAnimation:int64,WidthScale:float",
		["HumanoidRigDescription"] = "Instance||Chest:Ref,ChestRangeMax:Vector3,ChestRangeMin:Vector3,ChestSize:float,ChestTposeAdjustment:CFrame,HeadBase:Ref,HeadBaseRangeMax:Vector3,HeadBaseRangeMin:Vector3,HeadBaseSize:float,HeadBaseTposeAdjustment:CFrame,LeftAnkle:Ref,LeftAnkleRangeMax:Vector3,LeftAnkleRangeMin:Vector3,LeftAnkleSize:float,LeftAnkleTposeAdjustment:CFrame,LeftClavicle:Ref,LeftClavicleRangeMax:Vector3,LeftClavicleRangeMin:Vector3,LeftClavicleSize:float,LeftClavicleTposeAdjustment:CFrame,LeftElbow:Ref,LeftElbowRangeMax:Vector3,LeftElbowRangeMin:Vector3,LeftElbowSize:float,LeftElbowTposeAdjustment:CFrame,LeftHip:Ref,LeftHipRangeMax:Vector3,LeftHipRangeMin:Vector3,LeftHipSize:float,LeftHipTposeAdjustment:CFrame,LeftKnee:Ref,LeftKneeRangeMax:Vector3,LeftKneeRangeMin:Vector3,LeftKneeSize:float,LeftKneeTposeAdjustment:CFrame,LeftShoulder:Ref,LeftShoulderRangeMax:Vector3,LeftShoulderRangeMin:Vector3,LeftShoulderSize:float,LeftShoulderTposeAdjustment:CFrame,LeftToeBase:Ref,LeftToeBaseRangeMax:Vector3,LeftToeBaseRangeMin:Vector3,LeftToeBaseSize:float,LeftToeBaseTposeAdjustment:CFrame,LeftWrist:Ref,LeftWristRangeMax:Vector3,LeftWristRangeMin:Vector3,LeftWristSize:float,LeftWristTposeAdjustment:CFrame,Neck:Ref,NeckRangeMax:Vector3,NeckRangeMin:Vector3,NeckSize:float,NeckTposeAdjustment:CFrame,OriginOffset:CFrame,RightAnkle:Ref,RightAnkleRangeMax:Vector3,RightAnkleRangeMin:Vector3,RightAnkleSize:float,RightAnkleTposeAdjustment:CFrame,RightClavicle:Ref,RightClavicleRangeMax:Vector3,RightClavicleRangeMin:Vector3,RightClavicleSize:float,RightClavicleTposeAdjustment:CFrame,RightElbow:Ref,RightElbowRangeMax:Vector3,RightElbowRangeMin:Vector3,RightElbowSize:float,RightElbowTposeAdjustment:CFrame,RightHip:Ref,RightHipRangeMax:Vector3,RightHipRangeMin:Vector3,RightHipSize:float,RightHipTposeAdjustment:CFrame,RightKnee:Ref,RightKneeRangeMax:Vector3,RightKneeRangeMin:Vector3,RightKneeSize:float,RightKneeTposeAdjustment:CFrame,RightShoulder:Ref,RightShoulderRangeMax:Vector3,RightShoulderRangeMin:Vector3,RightShoulderSize:float,RightShoulderTposeAdjustment:CFrame,RightToeBase:Ref,RightToeBaseRangeMax:Vector3,RightToeBaseRangeMin:Vector3,RightToeBaseSize:float,RightToeBaseTposeAdjustment:CFrame,RightWrist:Ref,RightWristRangeMax:Vector3,RightWristRangeMin:Vector3,RightWristSize:float,RightWristTposeAdjustment:CFrame,Root:Ref,RootRangeMax:Vector3,RootRangeMin:Vector3,RootSize:float,RootTposeAdjustment:CFrame,Spine:Ref,SpineRangeMax:Vector3,SpineRangeMin:Vector3,SpineSize:float,SpineTposeAdjustment:CFrame,Waist:Ref,WaistRangeMax:Vector3,WaistRangeMin:Vector3,WaistSize:float,WaistTposeAdjustment:CFrame",
		["IKControl"] = "Instance||ChainRoot:Ref,Enabled:bool,EndEffector:Ref,EndEffectorOffset:CFrame,Offset:CFrame,Pole:Ref,Priority:int,SmoothTime:float,Target:Ref,Type:token,Weight:float",
		["ILegacyStudioBridge"] = "Instance|NS|",
		["LegacyStudioBridge"] = "ILegacyStudioBridge|NS|",
		["IXPService"] = "Instance|NS|",
		["ImageScreenCaptureService"] = "Instance|NS|",
		["ImportSession"] = "Instance|N|",
		["AssetImportSession"] = "ImportSession|N|",
		["IncrementalPatchBuilder"] = "Instance|NS|AddPathsToBundle:bool,BuildDebouncePeriod:double,HighCompression:bool,SerializePatch:bool,UseFileLevelCompressionInsteadOfChunk:bool,ZstdCompression:bool",
		["InputAction"] = "Instance||DisplayName:string,Enabled:bool,Type:token",
		["InputBinding"] = "Instance||Backward:token,ClampMagnitudeToOne:bool,Deadzone:NumberRange,DisplayImage:Content,DisplayName:string,Down:token,Forward:token,KeyCode:token,Left:token,PointerIndex:int,PressedThreshold:float,PrimaryModifier:token,ReleasedThreshold:float,ResponseCurve:float,Right:token,Scale:float,SecondaryModifier:token,Type:token,UIButton:Ref,UIModifier:Ref,Up:token,Vector2Scale:Vector2,Vector3Scale:Vector3",
		["InputContext"] = "Instance||Enabled:bool,Priority:int,Sink:bool",
		["InputObject"] = "Instance|N|",
		["InputReplayService"] = "Instance|NS|",
		["InsertService"] = "Instance|NS|AllowInsertFreeModels:bool",
		["InstanceExtensionsService"] = "Instance|NS|",
		["InstanceFileSyncService"] = "Instance|NS|",
		["InstanceRegistryService"] = "Instance|NS|",
		["IntegrityService"] = "Instance|NS|",
		["IntentService"] = "Instance|NS|",
		["InternalMessagingService"] = "Instance|NS|",
		["InternalMessagingServiceVerifier"] = "Instance|NS|",
		["InternalSyncItem"] = "Instance||AutoSync:bool,Enabled:bool,Path:string",
		["InternalSyncService"] = "Instance|NS|",
		["JointInstance"] = "Instance|N|C0:CFrame,C1:CFrame,Enabled:bool,Part0:Ref,Part1:Ref",
		["DynamicRotate"] = "JointInstance|N|BaseAngle:float",
		["RotateP"] = "DynamicRotate||",
		["RotateV"] = "DynamicRotate||",
		["Glue"] = "JointInstance||F0:Vector3,F1:Vector3,F2:Vector3,F3:Vector3",
		["ManualSurfaceJointInstance"] = "JointInstance|N|",
		["ManualGlue"] = "ManualSurfaceJointInstance||",
		["ManualWeld"] = "ManualSurfaceJointInstance||",
		["Motor"] = "JointInstance||DesiredAngle:float,MaxVelocity:float",
		["Motor6D"] = "Motor||",
		["Rotate"] = "JointInstance||",
		["Snap"] = "JointInstance||",
		["VelocityMotor"] = "JointInstance||CurrentAngle:float,DesiredAngle:float,Hole:Ref,MaxVelocity:float",
		["Weld"] = "JointInstance||",
		["JointsService"] = "Instance|NS|",
		["KeyboardService"] = "Instance|NS|",
		["Keyframe"] = "Instance||Time:float",
		["KeyframeMarker"] = "Instance||Value:string",
		["KeyframeSequenceProvider"] = "Instance|NS|",
		["LanguageService"] = "Instance|NS|",
		["Light"] = "Instance|N|Brightness:float,Color:Color3,Enabled:bool,Shadows:bool",
		["PointLight"] = "Light||Range:float",
		["SpotLight"] = "Light||Angle:float,Face:token,Range:float",
		["SurfaceLight"] = "Light||Angle:float,Face:token,Range:float",
		["Lighting"] = "Instance|NS|Ambient:Color3,Brightness:float,ColorShift_Bottom:Color3,ColorShift_Top:Color3,EnvironmentDiffuseScale:float,EnvironmentSpecularScale:float,ExposureCompensation:float,ExtendLightRangeTo120:token:H,FogColor:Color3,FogEnd:float,FogStart:float,GeographicLatitude:float,GlobalShadows:bool,LightAttenuationMode:token,LightingStyle:token,OutdoorAmbient:Color3,Outlines:bool,PrioritizeLightingQuality:bool,ShadowSoftness:float,Technology:token:>LightingStyle,TimeOfDay:string",
		["LinkingService"] = "Instance|NS|",
		["LiveScriptingService"] = "Instance|NS|",
		["LiveSyncService"] = "Instance|NS|",
		["LocalStorageService"] = "Instance|NS|",
		["AppStorageService"] = "LocalStorageService|NS|",
		["UserStorageService"] = "LocalStorageService|NS|",
		["LocalizationService"] = "Instance|NS|",
		["LocalizationTable"] = "Instance||Contents:string:H,SourceLocaleId:string",
		["CloudLocalizationTable"] = "LocalizationTable|N|",
		["LodDataEntity"] = "Instance|N|",
		["LodDataService"] = "Instance|NS|",
		["LogReporterService"] = "Instance|NS|",
		["LogService"] = "Instance|NS|",
		["LoginService"] = "Instance|NS|",
		["LuaSettings"] = "Instance|NS|",
		["LuaSourceContainer"] = "Instance|N|ScriptGuid:string:H",
		["AuroraScript"] = "LuaSourceContainer||AuroraScriptBindingsSerialize:BinaryString:H,EnableCulling:bool,EnableLOD:bool,LODCriticality:int,Priority:int,Source:ProtectedString",
		["BaseScript"] = "LuaSourceContainer|N|Disabled:bool,LinkedSource:ContentId,RunContext:token",
		["CoreScript"] = "BaseScript|N|",
		["Script"] = "BaseScript||Source:ProtectedString",
		["LocalScript"] = "Script||",
		["ModuleScript"] = "LuaSourceContainer||LinkedSource:ContentId,Source:ProtectedString",
		["LuaWebService"] = "Instance|NS|",
		["LuauExpressionService"] = "Instance|NS|",
		["LuauScriptAnalyzerService"] = "Instance|NS|",
		["MLModelDeliveryService"] = "Instance|NS|",
		["MLService"] = "Instance|NS|",
		["MakeupDescription"] = "Instance||AssetId:int64,Instance:Ref,MakeupType:token,Order:int",
		["MarkerCurve"] = "Instance||ValuesAndTimes:BinaryString:H",
		["MarketplaceService"] = "Instance|NS|",
		["MatchmakingService"] = "Instance|NS|",
		["MaterialGenerationService"] = "Instance|NS|",
		["MaterialService"] = "Instance|NS|AsphaltName:string:H,BasaltName:string:H,BrickName:string:H,CardboardName:string:H,CarpetName:string:H,CeramicTilesName:string:H,ClayRoofTilesName:string:H,CobblestoneName:string:H,ConcreteName:string:H,CorrodedMetalName:string:H,CrackedLavaName:string:H,DiamondPlateName:string:H,FabricName:string:H,FoilName:string:H,GlacierName:string:H,GraniteName:string:H,GrassName:string:H,GroundName:string:H,IceName:string:H,LeafyGrassName:string:H,LeatherName:string:H,LimestoneName:string:H,MarbleName:string:H,MetalName:string:H,MudName:string:H,PavementName:string:H,PebbleName:string:H,PlasterName:string:H,PlasticName:string:H,RockName:string:H,RoofShinglesName:string:H,RubberName:string:H,SaltName:string:H,SandName:string:H,SandstoneName:string:H,SlateName:string:H,SmoothPlasticName:string:H,SnowName:string:H,Use2022MaterialsXml:bool:H,WoodName:string:H,WoodPlanksName:string:H",
		["MaterialVariant"] = "Instance||AlphaMode:token,BaseMaterial:token,ColorMap:ContentId,ColorMapContent:Content,CustomPhysicalProperties:PhysicalProperties,EmissiveMaskContent:Content,EmissiveStrength:float,EmissiveTint:Color3,MaterialPattern:token,MetalnessMap:ContentId,MetalnessMapContent:Content,NormalMap:ContentId,NormalMapContent:Content,RoughnessMap:ContentId,RoughnessMapContent:Content,StudsPerTile:float,TexturePack:ContentId:H,TexturePackContent:Content:H",
		["MemStorageConnection"] = "Instance|N|",
		["MemStorageService"] = "Instance|NS|",
		["MemoryStoreDistributedCounter"] = "Instance|N|",
		["MemoryStoreHashMap"] = "Instance|N|",
		["MemoryStoreQueue"] = "Instance|N|",
		["MemoryStoreService"] = "Instance|S|",
		["MemoryStoreSortedMap"] = "Instance|N|",
		["Message"] = "Instance||Text:string",
		["Hint"] = "Message||",
		["MessageBusConnection"] = "Instance|N|",
		["MessageBusService"] = "Instance|NS|",
		["MessagingService"] = "Instance|NS|",
		["MetaBreakpoint"] = "Instance|N|Condition:string,ContinueExecution:bool,Enabled:bool,Line:int,LogMessage:string,RemoveOnHit:bool,Script:string",
		["MetaBreakpointContext"] = "Instance|N|ContextDataInternal:string:H",
		["MetaBreakpointManager"] = "Instance|NS|",
		["MicroProfilerService"] = "Instance|NS|ContextLabel:string",
		["ModelInfoService"] = "Instance|NS|",
		["ModerationService"] = "Instance|NS|",
		["MomentsService"] = "Instance|NS|",
		["Mouse"] = "Instance|N|Icon:ContentId,IconContent:Content,TargetFilter:Ref",
		["PlayerMouse"] = "Mouse|N|",
		["PluginMouse"] = "Mouse|N|",
		["MouseService"] = "Instance|NS|",
		["MultipleDocumentInterfaceInstance"] = "Instance|N|",
		["NetworkMarker"] = "Instance|N|",
		["NetworkPeer"] = "Instance|N|",
		["NetworkClient"] = "NetworkPeer|NS|",
		["NetworkServer"] = "NetworkPeer|NS|",
		["NetworkReplicator"] = "Instance|N|",
		["ClientReplicator"] = "NetworkReplicator|N|",
		["ServerReplicator"] = "NetworkReplicator|N|",
		["NetworkSettings"] = "Instance|NS|HttpProxyEnabled:bool,HttpProxyURL:string,InboundNetworkJitterMs:float,InboundNetworkLossPercent:float,InboundNetworkMinDelayMs:float,IncomingReplicationLag:double,OutboundNetworkJitterMs:float,OutboundNetworkLossPercent:float,OutboundNetworkMinDelayMs:float,PrintJoinSizeBreakdown:bool,PrintPhysicsErrors:bool,PrintStreamInstanceQuota:bool,RandomizeJoinInstanceOrder:bool,RenderStreamedRegions:bool,ShowActiveAnimationAsset:bool",
		["NoCollisionConstraint"] = "Instance||Enabled:bool,Part0:Ref,Part1:Ref",
		["Noise"] = "Instance||NoiseType:token,Seed:int",
		["NotificationService"] = "Instance|NS|",
		["OmniRecommendationsService"] = "Instance|NS|",
		["OpenCloudApiV1"] = "Instance|N|",
		["OpenCloudService"] = "Instance|NS|",
		["OperationGraph"] = "Instance||",
		["PVInstance"] = "Instance|N|",
		["BasePart"] = "PVInstance|N|Anchored:bool,AudioCanCollide:bool,BackParamA:float,BackParamB:float,BackSurface:token,BackSurfaceInput:token,BottomParamA:float,BottomParamB:float,BottomSurface:token,BottomSurfaceInput:token,CFrame:CFrame,CanCollide:bool,CanQuery:bool,CanTouch:bool,CastShadow:bool,CollisionGroup:string,CollisionGroupId:int:>CollisionGroup,Color3uint8:Color3uint8:H,CustomPhysicalProperties:PhysicalProperties,EnableFluidForces:bool,FrontParamA:float,FrontParamB:float,FrontSurface:token,FrontSurfaceInput:token,LeftParamA:float,LeftParamB:float,LeftSurface:token,LeftSurfaceInput:token,Locked:bool,Massless:bool,Material:token,MaterialVariantSerialized:string:H,PivotOffset:CFrame,Reflectance:float,RightParamA:float,RightParamB:float,RightSurface:token,RightSurfaceInput:token,RootPriority:int,RotVelocity:Vector3:>AssemblyAngularVelocity,TopParamA:float,TopParamB:float,TopSurface:token,TopSurfaceInput:token,Transparency:float,Velocity:Vector3:>AssemblyLinearVelocity,size:Vector3:H",
		["CornerWedgePart"] = "BasePart||",
		["FormFactorPart"] = "BasePart|N|formFactorRaw:token:H",
		["Part"] = "FormFactorPart||shape:token:H",
		["FlagStand"] = "Part||TeamColor:BrickColor",
		["Platform"] = "Part|N|",
		["Seat"] = "Part||Disabled:bool",
		["SkateboardPlatform"] = "Part||Steer:int,StickyWheels:bool,Throttle:int",
		["SpawnLocation"] = "Part||AllowTeamChangeOnTouch:bool,Duration:int,Enabled:bool,Neutral:bool,TeamColor:BrickColor",
		["WedgePart"] = "FormFactorPart||",
		["Terrain"] = "BasePart|N|AcquisitionMethod:token:H,Decoration:bool,GrassLength:float,MaterialColors:BinaryString:H,Materials:SharedString:H,PhysicsGrid:BinaryString:H,SmoothGrid:BinaryString:H,SmoothVoxelsUpgraded:bool,WaterColor:Color3,WaterReflectance:float,WaterTransparency:float,WaterWaveSize:float,WaterWaveSpeed:float",
		["TriangleMeshPart"] = "BasePart|N|AeroMeshData:SharedString:H,FluidFidelityInternal:token:H,InertiaMigrated:bool:H,PhysicalConfigData:SharedString:H,UnscaledCofm:Vector3,UnscaledVolInertiaDiags:Vector3,UnscaledVolInertiaOffDiags:Vector3,UnscaledVolume:float",
		["MeshPart"] = "TriangleMeshPart||DoubleSided:bool,HasJointOffset:bool,HasSkinnedMesh:bool,InitialSize:Vector3:H,JointOffset:Vector3,MeshContent:Content,MeshId:ContentId,PhysicsData:BinaryString:H,RenderFidelity:token,TextureContent:Content,TextureID:ContentId,VertexCount:int:H",
		["PartOperation"] = "TriangleMeshPart||AssetId:ContentId:H,ChildData:BinaryString:H,ChildData2:SharedString:H,ComponentIndex:int:H,Content:Content:H,FormFactor:token:H,InitialSize:Vector3:H,MeshData:BinaryString:H,MeshData2:SharedString:H,OffCentered:bool:H,PhysicsData:BinaryString:H,RenderFidelity:token,SmoothingAngle:float,SolidMeshHolder:NetAssetRef:H,TriangleCount:int,UsePartColor:bool",
		["IntersectOperation"] = "PartOperation||",
		["NegateOperation"] = "PartOperation||PreviousOperation:token:H",
		["UnionOperation"] = "PartOperation||",
		["TrussPart"] = "BasePart||style:token:H",
		["VehicleSeat"] = "BasePart||Disabled:bool,HeadsUpDisplay:bool,MaxSpeed:float,Steer:int,SteerFloat:float,Throttle:int,ThrottleFloat:float,Torque:float,TurnSpeed:float",
		["Camera"] = "PVInstance||CFrame:CFrame,CameraSubject:Ref,CameraType:token,FieldOfView:float,FieldOfViewMode:token,Focus:CFrame,HeadLocked:bool,HeadScale:float,OrthographicMode:token,OrthographicSize:float,ProjectionType:token,VRTiltAndRollEnabled:bool,ViewStretch:float",
		["ViewportCamera"] = "Camera||",
		["Model"] = "PVInstance||ExplorerIconContent:Content,LevelOfDetail:token,ModelMeshCFrame:CFrame:H,ModelMeshData:SharedString:H,ModelMeshSize:Vector3:H,ModelStreamingMode:token,NeedsPivotMigration:bool:H,PrimaryPart:Ref,ScaleFactor:float:H,SlimHash:SharedString:H,WorldPivotData:OptionalCFrame:H",
		["Actor"] = "Model||",
		["BackpackItem"] = "Model|N|TextureContent:Content,TextureId:ContentId",
		["HopperBin"] = "BackpackItem||Active:bool,BinType:token",
		["Tool"] = "BackpackItem||CanBeDropped:bool,Enabled:bool,Grip:CFrame,ManualActivationOnly:bool,RequiresHandle:bool,ToolTip:string",
		["Flag"] = "Tool||TeamColor:BrickColor",
		["ProceduralModel"] = "Model||Dirty:bool:H,Generator:Ref,Size:Vector3",
		["Status"] = "Model|N|",
		["WorldRoot"] = "Model|N|AutoSimulate:bool,CollisionGroupData:BinaryString:H,GravityDirection:Vector3,SimulationRate:float,Wind:float,WindDirection:Vector3",
		["Workspace"] = "WorldRoot|NS|AirDensity:float,AirTurbulenceIntensity:float,AllowThirdPartySales:bool,AuthorityMode:token,AvatarUnificationMode:token:H,ClientAnimatorThrottling:token,CurrentCamera:Ref,DistributedGameTime:double,EnableSLIMAvatars:token:H,ExpandedTerrain:token:H,ExplicitAutoJoints:bool:H,FallHeightEnabled:bool,FallenPartsDestroyHeight:float,FluidForces:token:H,GlobalWind:Vector3,Gravity:float,IKControlConstraintSupport:token:H,ImprovedPhysicsReplication:token:H,InputSinkEnabled:token,LayeredClothingCacheOptimizations:token:H,LuauTypeCheckMode:token,MapTVRemoteToGamepadKeycodes:token:H,MeshPartHeadsAndAccessories:token:H,MeshStreamingAndImprovedLods:token:H,ModelStreamingBehavior:token:H,NextGenerationPhysicsSolver:token,NextGenerationReplication:token:H,ParticlesUseDynamicWind:token:H,PathfindingUseImprovedSearch:token:H,PhysicsSteppingMethod:token:H,PlayerCharacterDestroyBehavior:token:H,PlayerScriptsUseInputActionSystem:token,PredictiveStreamingMode:token,RejectCharacterDeletions:token:H,RenderingCacheOptimizations:token:H,ReplicateInstanceDestroySetting:token:H,ReplicationFrequency:token,ReplicationThroughput:token,Retargeting:token,SandboxedInstanceMode:token:H,SignalBehavior2:token:H,StreamOutBehavior:token,StreamingAdaptiveRadius:bool,StreamingEnabled:bool,StreamingIntegrityMode:token,StreamingMinRadius:int,StreamingTargetRadius:int,TerrainWeldsFixed:bool:H,TouchEventsUseCollisionGroups:token:H,TouchesUseCollisionGroups:bool:H,UseFixedSimulation:token:H,UseNewLuauTypeSolver:token:H,ValidateEnabledProximityPrompt:token:H",
		["WorldModel"] = "WorldRoot||UseWorkspaceCollisionGroups:bool",
		["PackageLink"] = "Instance|N|AutoUpdate:bool,DefaultName:string,ModifiedState:int,PackageContentSerialize:Content:H,PackageIdSerialize:ContentId:H,SerializedDefaultAttributes:BinaryString,VersionIdSerialize:int64:H",
		["PackageService"] = "Instance|NS|",
		["PackageUIService"] = "Instance|NS|",
		["Packages"] = "Instance|NS|IsDehydrated:bool,OverridesRecalculated:bool,ShellPackagesCount:int,SkippedInstancesCount:int",
		["Pages"] = "Instance|N|",
		["AudioPages"] = "Pages|N|",
		["BanHistoryPages"] = "Pages|N|",
		["CapturesPages"] = "Pages|N|",
		["CatalogPages"] = "Pages|N|",
		["DataStoreKeyPages"] = "Pages|N|",
		["DataStoreListingPages"] = "Pages|N|",
		["DataStorePages"] = "Pages|N|",
		["DataStoreVersionPages"] = "Pages|N|",
		["FriendPages"] = "Pages|N|",
		["InventoryPages"] = "Pages|N|",
		["MemoryStoreHashMapPages"] = "Pages|N|",
		["OutfitPages"] = "Pages|N|",
		["RecommendationPages"] = "Pages|N|",
		["StandardPages"] = "Pages|N|",
		["PartOperationAsset"] = "Instance||ChildData:BinaryString:H,MeshData:BinaryString:H",
		["ParticleEmitter"] = "Instance||Acceleration:Vector3,Brightness:float,Color:ColorSequence,Drag:float,EmissionDirection:token,Enabled:bool,FlipbookBlendFrames:bool,FlipbookFramerate:NumberRange,FlipbookIncompatible:string,FlipbookLayout:token,FlipbookMode:token,FlipbookSizeX:int,FlipbookSizeY:int,FlipbookStartRandom:bool,Lifetime:NumberRange,LightEmission:float,LightInfluence:float,LockedToPart:bool,Orientation:token,Rate:float,RotSpeed:NumberRange,Rotation:NumberRange,Shape:token,ShapeInOut:token,ShapePartial:float,ShapeStyle:token,Size:NumberSequence,Speed:NumberRange,SpreadAngle:Vector2,Squash:NumberSequence,Texture:ContentId,TextureContent:Content,TimeScale:float,Transparency:NumberSequence,VelocityInheritance:float,WindAffectsDrag:bool,ZOffset:float",
		["ParticleEmitter2D"] = "Instance||Acceleration:Vector2,Blend:float,Brightness:float,Color:ColorSequence,Drag:float,EmissionAngle:float,EmissionMode:token,EmissionOffset:Vector2,EmissionSpread:Vector2,Enabled:bool,FlipbookBlendFrames:bool,FlipbookFramerate:NumberRange,FlipbookLayout:token,FlipbookMode:token,FlipbookSizeX:int,FlipbookSizeY:int,FlipbookStartRandom:bool,Lifetime:NumberRange,LightInfluence:float,LockedToParent:bool,Rate:float,RotSpeed:NumberRange,Rotation:NumberRange,Size:NumberSequence,Speed:NumberRange,SpreadAngle:float,Squash:NumberSequence,TextureContent:Content,TimeScale:float,Transparency:NumberSequence,ZIndex:int",
		["PartyEmulatorService"] = "Instance|NS|",
		["PatchBundlerFileWatch"] = "Instance|NS|",
		["PatchMapping"] = "Instance|N|FlattenTree:bool,PatchId:string,TargetPath:string",
		["Path"] = "Instance|N|",
		["Path3D"] = "Instance||",
		["PathfindingLink"] = "Instance||Attachment0:Ref,Attachment1:Ref,IsBidirectional:bool,Label:string",
		["PathfindingModifier"] = "Instance||Label:string,PassThrough:bool",
		["PathfindingService"] = "Instance|NS|",
		["PausedState"] = "Instance|N|",
		["PausedStateBreakpoint"] = "PausedState|N|",
		["PausedStateException"] = "PausedState|N|",
		["PerformanceControlService"] = "Instance|NS|",
		["PermissionsService"] = "Instance|NS|",
		["PhysicsService"] = "Instance|NS|",
		["PhysicsSettings"] = "Instance|NS|AllowSleep:bool,AreAnchorsShown:bool,AreAssembliesShown:bool,AreAssemblyCentersOfMassShown:bool,AreAwakePartsHighlighted:bool,AreBodyTypesShown:bool,AreCollisionCostsShown:bool,AreConstraintForcesShownForSelectedOrHoveredInstances:bool,AreConstraintTorquesShownForSelectedOrHoveredInstances:bool,AreContactForcesShownForSelectedOrHoveredAssemblies:bool,AreContactIslandsShown:bool,AreContactPointsShown:bool,AreGravityForcesShownForSelectedOrHoveredAssemblies:bool,AreJointCoordinatesShown:bool,AreMagnitudesShownForDrawnForcesAndTorques:bool,AreMechanismsShown:bool,AreModelCoordsShown:bool,AreNonAnchorsShown:bool,AreOwnersShown:bool,ArePartCoordsShown:bool,AreRegionsShown:bool,AreSolverIslandsShown:bool,AreTerrainReplicationRegionsShown:bool,AreTimestepsShown:bool,AreUnalignedPartsShown:bool,AreWorldCoordsShown:bool,CollisionGeomDrawOriginalParts:bool,CollisionGeomMatchPartTransparency:bool,CollisionGeomOverlayTransparency:float,CollisionGeomShowCollidableParts:bool,CollisionGeomShowCollisionGroup:string,CollisionGeomShowQueryableParts:bool,CollisionGeomShowTouchableParts:bool,DisableCSGv2:bool,DisableCSGv3ForPlugins:bool,DrawConstraintsNetForce:bool,DrawContactsNetForce:bool,DrawShapecast:bool,DrawTotalNetForce:bool,EnableForceVisualizationSmoothing:bool,FluidForceDrawScale:float,ForceCSGv2:bool,ForceDrawScale:float,ForceVisualizationSmoothingSteps:int,IsInterpolationThrottleShown:bool,IsReceiveAgeShown:bool,IsTreeShown:bool,PhysicsEnvironmentalThrottle:token,ShowDecompositionGeometry:bool,ShowFluidForcesForSelectedOrHoveredMechanisms:bool,ShowInstanceNamesForDrawnForcesAndTorques:bool,SolverConvergenceMetricType:token,SolverConvergenceVisualizationMode:token,ThrottleAdjustTime:double,TorqueDrawScale:float,UseCSGv2:bool",
		["PinShortcutService"] = "Instance|NS|",
		["PlaceAssetIdsService"] = "Instance|NS|",
		["PlaceSettings"] = "Instance|NS|",
		["PlaceStatsService"] = "Instance|NS|",
		["PlacesService"] = "Instance|NS|",
		["PlatformCloudStorageService"] = "Instance|NS|",
		["PlatformFriendsService"] = "Instance|NS|",
		["PlatformLibraries"] = "Instance|NS|",
		["Player"] = "Instance||AutoJumpEnabled:bool,CameraMaxZoomDistance:float,CameraMinZoomDistance:float,CameraMode:token,Character:Ref,CharacterAppearance:string:>CharacterAppearanceId,CharacterAppearanceId:int64,DevCameraOcclusionMode:token,DevComputerCameraMode:token,DevComputerMovementMode:token,DevEnableMouseLock:bool,DevTouchCameraMode:token,DevTouchMovementMode:token,HealthDisplayDistance:float,InputLatency:int,NameDisplayDistance:float,Neutral:bool,RawJoinData:BinaryString:H,ReplicationFocus:Ref,RespawnLocation:Ref,Team:Ref,TeamColor:BrickColor,TeleportedIn:bool",
		["PlayerData"] = "Instance|N|",
		["PlayerDataService"] = "Instance|NS|",
		["PlayerEmulatorService"] = "Instance|NS|CustomPoliciesEnabled:bool,EmulatedCountryCode:string,EmulatedGameLocale:string,PlayerEmulationEnabled:bool,PseudolocalizationEnabled:bool,SerializedEmulatedPolicyInfo:BinaryString,TextElongationFactor:int",
		["PlayerHydrationService"] = "Instance|NS|",
		["PlayerScripts"] = "Instance|N|",
		["PlayerViewService"] = "Instance|NS|",
		["Players"] = "Instance|NS|BanningEnabled:bool,CharacterAutoLoads:bool,MaxPlayersInternal:int,PreferredPlayersInternal:int,RespawnTime:float,UseStrafingAnimations:bool",
		["Plugin"] = "Instance|N|DisableUIDragDetectorDrags:bool,IsDebuggable:bool",
		["PluginAction"] = "Instance||",
		["PluginCapabilities"] = "Instance||Manifest:string",
		["PluginConnectionService"] = "Instance|NS|",
		["PluginDebugService"] = "Instance|NS|",
		["PluginDragEvent"] = "Instance|N|",
		["PluginGuiService"] = "Instance|NS|",
		["PluginManagementService"] = "Instance|NS|",
		["PluginManager"] = "Instance|N|",
		["PluginManagerInterface"] = "Instance|N|",
		["PluginMenu"] = "Instance|N|Visible:bool",
		["PluginPolicyService"] = "Instance|NS|",
		["PluginToolbar"] = "Instance|N|",
		["PluginToolbarButton"] = "Instance|N|",
		["PointsService"] = "Instance|NS|",
		["PolicyService"] = "Instance|NS|IsLuobuServer:token,LuobuWhitelisted:token",
		["PopLatencyService"] = "Instance|NS|",
		["PoseBase"] = "Instance|N|EasingDirection:token,EasingStyle:token,Weight:float",
		["NumberPose"] = "PoseBase||Value:double",
		["Pose"] = "PoseBase||CFrame:CFrame",
		["PostEffect"] = "Instance|N|Enabled:bool",
		["BloomEffect"] = "PostEffect||Intensity:float,Size:float,Threshold:float",
		["BlurEffect"] = "PostEffect||Size:float",
		["ColorCorrectionEffect"] = "PostEffect||Brightness:float,ColorLutContent:Content,ColorLutIntensity:float,Contrast:float,Saturation:float,TintColor:Color3",
		["ColorGradingEffect"] = "PostEffect||TonemapperPreset:token",
		["DepthOfFieldEffect"] = "PostEffect||FarIntensity:float,FocusDistance:float,InFocusRadius:float,NearIntensity:float",
		["SunRaysEffect"] = "PostEffect||Intensity:float,Spread:float",
		["Preloaded"] = "Instance|NS|",
		["ProceduralBehaviorSchedulerService"] = "Instance|NS|",
		["ProcessInstancePhysicsService"] = "Instance|NS|",
		["ProjectService"] = "Instance|NS|ContentMap:NetAssetRef:H",
		["ProximityPrompt"] = "Instance||ActionText:string,AutoLocalize:bool,ClickablePrompt:bool,Enabled:bool,Exclusivity:token,GamepadKeyCode:token,HoldDuration:float,KeyboardKeyCode:token,MaxActivationDistance:float,MaxIndicatorDistance:float,ObjectText:string,RequiresLineOfSight:bool,RootLocalizationTable:Ref,Style:token,UIOffset:Vector2",
		["ProximityPromptService"] = "Instance|S|Enabled:bool,MaxIndicatorsVisible:int,MaxPromptsVisible:int",
		["PublishService"] = "Instance|NS|",
		["QueueService"] = "Instance|NS|",
		["RTAnimationTracker"] = "Instance||",
		["RbxAnalyticsService"] = "Instance|NS|",
		["RealtimeMedia"] = "Instance||ForwardInput:bool",
		["RecommendationService"] = "Instance|NS|",
		["ReflectionMetadata"] = "Instance||",
		["ReflectionMetadataCallbacks"] = "Instance||",
		["ReflectionMetadataClasses"] = "Instance||",
		["ReflectionMetadataEnums"] = "Instance||",
		["ReflectionMetadataEvents"] = "Instance||",
		["ReflectionMetadataFunctions"] = "Instance||",
		["ReflectionMetadataItem"] = "Instance|N|Browsable:bool,ClassCategory:string,ClientOnly:bool,Constraint:string,Deprecated:bool,EditingDisabled:bool,EditorType:string,FFlag:string,IsBackend:bool,PropertyOrder:int,ScriptContext:string,ServerOnly:bool,SliderScaling:string,UIMaximum:double,UIMinimum:double,UINumTicks:double",
		["ReflectionMetadataClass"] = "ReflectionMetadataItem||ExplorerImageIndex:int,ExplorerOrder:int,Insertable:bool,PreferredParent:string,ServiceVisibility:token",
		["ReflectionMetadataEnum"] = "ReflectionMetadataItem||",
		["ReflectionMetadataEnumItem"] = "ReflectionMetadataItem||",
		["ReflectionMetadataMember"] = "ReflectionMetadataItem||",
		["ReflectionMetadataProperties"] = "Instance||",
		["ReflectionMetadataYieldFunctions"] = "Instance||",
		["ReflectionService"] = "Instance|NS|",
		["RemoteCommandService"] = "Instance|NS|",
		["RemoteCursorService"] = "Instance|NS|",
		["RemoteDebuggerServer"] = "Instance|NS|",
		["RemoteFunction"] = "Instance||",
		["RenderSettings"] = "Instance|NS|AutoFRMLevel:int,EagerBulkExecution:bool,EditQualityLevel:token,Enable VR Mode:bool,ExportMergeByMaterial:bool,FrameRateManager:token,GraphicsMode:token,MeshCacheSize:int,MeshPartDetailLevel:token,QualityLevel:token,ReloadAssets:bool,RenderCSGTrianglesDebug:bool,ShowBoundingBoxes:bool,ViewMode:token",
		["RenderingTest"] = "Instance||CFrame:CFrame,ComparisonDiffThreshold:int,ComparisonMethod:token,ComparisonPsnrThreshold:float,Description:string,FieldOfView:float,PerfTest:bool,QualityAuto:bool,QualityLevel:int,RenderingTestFrameCount:int,ShouldSkip:bool,Ticket:string,Timeout:int",
		["ReplicatedFirst"] = "Instance|NS|",
		["ReplicatedStorage"] = "Instance|NS|",
		["RequestOrchestratorService"] = "Instance|NS|",
		["RibbonNotificationService"] = "Instance|NS|",
		["RobloxPluginGuiService"] = "Instance|NS|",
		["RobloxReplicatedStorage"] = "Instance|NS|",
		["RobloxSerializableInstance"] = "Instance|N|Data:BinaryString",
		["RobloxServerStorage"] = "Instance|NS|",
		["RolloutValidation"] = "Instance|N|AdditionalFluffOne:int:H,AdditionalFluffThree:float:H,AdditionalFluffTwo:bool:H,CreationVersion:int:H,FirstBinaryExpectedValue:string:H,FirstBinaryString:BinaryString:H,FirstSharedExpectedValue:string:H,FirstSharedString:SharedString:H,GenerationStrategy:int:H,SecondBinaryExpectedValue:string:H,SecondBinaryString:BinaryString:H,SecondSharedExpectedValue:string:H,SecondSharedString:SharedString:H,ThirdBinaryExpectedValue:string:H,ThirdBinaryString:BinaryString:H,ThirdSharedExpectedValue:string:H,ThirdSharedString:SharedString:H",
		["RolloutValidationService"] = "Instance|NS|",
		["RomarkRbxAnalyticsService"] = "Instance|NS|",
		["RomarkService"] = "Instance|NS|",
		["RotationCurve"] = "Instance||ValuesAndTimes:BinaryString:H",
		["RtMessagingService"] = "Instance|NS|",
		["RunService"] = "Instance|NS|",
		["RuntimeContentService"] = "Instance|NS|",
		["RuntimeScriptService"] = "Instance|NS|",
		["SafetyService"] = "Instance|NS|IsCaptureModeForReport:bool",
		["SceneAnalysisService"] = "Instance|NS|",
		["ScreenshotHud"] = "Instance|N|CameraButtonIcon:ContentId,CameraButtonIconContent:Content,CameraButtonPosition:UDim2,CloseButtonPosition:UDim2,CloseWhenScreenshotTaken:bool,ExperienceNameOverlayEnabled:bool,HideCoreGuiForCaptures:bool,HidePlayerGuiForCaptures:bool,OverlayFont:token,UsernameOverlayEnabled:bool,Visible:bool",
		["ScriptBuilder"] = "Instance|N|",
		["SyncScriptBuilder"] = "ScriptBuilder|N|CompileTarget:token,CoverageInfo:bool,DebugInfo:bool,PackAsSource:bool,RawBytecode:bool:>CompileTarget",
		["ScriptChangeService"] = "Instance|NS|",
		["ScriptCloneWatcher"] = "Instance|NS|",
		["ScriptCloneWatcherHelper"] = "Instance|NS|",
		["ScriptCommitService"] = "Instance|NS|",
		["ScriptContext"] = "Instance|NS|",
		["ScriptDebugger"] = "Instance|N|CoreScriptIdentifier:string:H,ScriptGuid:string:H",
		["ScriptDebuggerService"] = "Instance|NS|",
		["ScriptDocument"] = "Instance|N|",
		["ScriptEditorService"] = "Instance|NS|",
		["ScriptProfilerService"] = "Instance|NS|",
		["ScriptRegistrationService"] = "Instance|NS|",
		["ScriptRuntime"] = "Instance|N|",
		["ScriptScannerService"] = "Instance|NS|",
		["ScriptService"] = "Instance|NS|",
		["Selection"] = "Instance|NS|",
		["SelectionHighlightManager"] = "Instance|NS|",
		["SensorBase"] = "Instance|N|UpdateType:token",
		["AtmosphereSensor"] = "SensorBase||",
		["BuoyancySensor"] = "SensorBase||FullySubmerged:bool,TouchingSurface:bool",
		["ControllerSensor"] = "SensorBase|N|",
		["ControllerPartSensor"] = "ControllerSensor||HitFrame:CFrame,HitNormal:Vector3,LadderSearchHeight:float,LadderSearchOffset:float,SearchDistance:float,SensedMaterial:token,SensedPart:Ref,SensorMode:token",
		["FluidForceSensor"] = "SensorBase||",
		["PhysicsActivitySensor"] = "SensorBase||",
		["SerializationService"] = "Instance|NS|",
		["ServerScriptService"] = "Instance|NS|LoadStringEnabled:bool:H",
		["ServerStorage"] = "Instance|NS|",
		["ServiceProvider"] = "Instance|N|",
		["DataModel"] = "ServiceProvider|N|",
		["GenericSettings"] = "ServiceProvider|N|",
		["GlobalSettings"] = "GenericSettings|N|",
		["UserSettings"] = "GenericSettings|N|",
		["ServiceVisibilityService"] = "Instance|NS|HiddenServices:BinaryString,VisibleServices:BinaryString",
		["SessionCheckService"] = "Instance|NS|",
		["SessionService"] = "Instance|NS|",
		["SessionStorage"] = "Instance|NS|",
		["SharedTableRegistry"] = "Instance|NS|",
		["Sky"] = "Instance||CelestialBodiesShown:bool,MoonAngularSize:float,MoonTextureContent:Content,MoonTextureId:ContentId,SkyboxBackContent:Content,SkyboxBk:ContentId,SkyboxDn:ContentId,SkyboxDownContent:Content,SkyboxFrontContent:Content,SkyboxFt:ContentId,SkyboxLeftContent:Content,SkyboxLf:ContentId,SkyboxOrientation:Vector3,SkyboxRightContent:Content,SkyboxRt:ContentId,SkyboxUp:ContentId,SkyboxUpContent:Content,StarCount:int,SunAngularSize:float,SunTextureContent:Content,SunTextureId:ContentId",
		["SlimAnimationDataEntity"] = "Instance|N|",
		["SlimAnimationReplicationService"] = "Instance|NS|",
		["SlimDebugSettings"] = "Instance|NS|",
		["SlimReplicationService"] = "Instance|NS|",
		["SlimService"] = "Instance|NS|",
		["Smoke"] = "Instance||Color:Color3,Enabled:bool,TimeScale:float,opacity_xml:float:H,riseVelocity_xml:float:H,size_xml:float:H",
		["SmoothVoxelsUpgraderService"] = "Instance|NS|",
		["SocialService"] = "Instance|NS|",
		["Sound"] = "Instance||AcousticSimulationEnabled:bool,AudioContent:Content,LoopRegion:NumberRange,Looped:bool,PlayOnRemove:bool,PlaybackRegion:NumberRange,PlaybackRegionsEnabled:bool,PlaybackSpeed:float,Playing:bool,RollOffMaxDistance:float,RollOffMinDistance:float,RollOffMode:token,SoundGroup:Ref,SoundId:ContentId,TimePosition:double,Volume:float",
		["SoundEffect"] = "Instance|N|Enabled:bool,Priority:int",
		["ChorusSoundEffect"] = "SoundEffect||Depth:float,Mix:float,Rate:float",
		["CompressorSoundEffect"] = "SoundEffect||Attack:float,GainMakeup:float,Ratio:float,Release:float,SideChain:Ref,Threshold:float",
		["CustomSoundEffect"] = "SoundEffect|N|",
		["AssetSoundEffect"] = "CustomSoundEffect|N|",
		["ChannelSelectorSoundEffect"] = "CustomSoundEffect|N|Channel:int",
		["DistortionSoundEffect"] = "SoundEffect||Level:float",
		["EchoSoundEffect"] = "SoundEffect||Delay:float,DryLevel:float,Feedback:float,WetLevel:float",
		["EqualizerSoundEffect"] = "SoundEffect||HighGain:float,LowGain:float,MidGain:float",
		["FlangeSoundEffect"] = "SoundEffect||Depth:float,Mix:float,Rate:float",
		["PitchShiftSoundEffect"] = "SoundEffect||Octave:float",
		["ReverbSoundEffect"] = "SoundEffect||DecayTime:float,Density:float,Diffusion:float,DryLevel:float,WetLevel:float",
		["TremoloSoundEffect"] = "SoundEffect||Depth:float,Duty:float,Frequency:float",
		["SoundGroup"] = "Instance||Volume:float",
		["SoundService"] = "Instance|NS|AcousticSimulationEnabled:bool,AmbientReverb:token,AudioApiByDefault:token,CharacterSoundsUseNewApi:token,DefaultListenerLocation:token,DiffractionEnabled:bool,DistanceFactor:float,DopplerScale:float,IsNewExpForAudioApiByDefault:bool,ListenerCFrame:CFrame,ListenerObject:Ref,ListenerType:token,OcclusionEnabled:bool,RespectFilteringEnabled:bool,ReverbEnabled:bool,RolloffScale:float,VolumetricAudio:token:H",
		["SoundShimService"] = "Instance|NS|",
		["Sparkles"] = "Instance||Enabled:bool,SparkleColor:Color3,TimeScale:float",
		["SpawnerService"] = "Instance|NS|",
		["StackFrame"] = "Instance|N|",
		["StandalonePluginScripts"] = "Instance||",
		["StandardQueue"] = "Instance|N|",
		["StartPageService"] = "Instance|NS|",
		["StarterGear"] = "Instance||",
		["StarterPack"] = "Instance|NS|",
		["StarterPlayer"] = "Instance|NS|AllowCustomAnimations:bool,AutoJumpEnabled:bool,AvatarJointUpgrade_SerializedRollout:token:H,CameraMaxZoomDistance:float,CameraMinZoomDistance:float,CameraMode:token,CharacterBreakJointsOnDeath:bool,CharacterJumpHeight:float,CharacterJumpPower:float,CharacterMaxSlopeAngle:float,CharacterUseJumpPower:bool,CharacterWalkSpeed:float,ClassicDeath:bool,CreateDefaultPlayerModule:bool,DevCameraOcclusionMode:token,DevComputerCameraMovementMode:token,DevComputerMovementMode:token,DevTouchCameraMovementMode:token,DevTouchMovementMode:token,EnableDynamicHeads:token:H,EnableMouseLockOption:bool,GameSettingsAvatar:token,GameSettingsR15Collision:token,HealthDisplayDistance:float,LoadCharacterAppearance:bool,LoadCharacterLayeredClothing:token:H,LuaCharacterController:token,NameDisplayDistance:float,PlaceAvatarRules:Ref,PlayerModuleStatus:int,UseImprovedCharacterEvents:token:H,UserEmotesEnabled:bool",
		["StarterPlayerScripts"] = "Instance|N|",
		["StarterCharacterScripts"] = "StarterPlayerScripts|N|",
		["StartupMessageService"] = "Instance|NS|",
		["StateMachineDefinition"] = "Instance||NodeId:string",
		["StateMachineTransitionDefinition"] = "Instance||From:Ref,Priority:int,To:Ref,TransitionId:string",
		["Stats"] = "Instance|NS|",
		["StatsItem"] = "Instance|N|",
		["RunningAverageItemDouble"] = "StatsItem|N|",
		["RunningAverageItemInt"] = "StatsItem|N|",
		["RunningAverageTimeIntervalItem"] = "StatsItem|N|",
		["TotalCountTimeIntervalItem"] = "StatsItem|N|",
		["StopWatchReporter"] = "Instance|NS|",
		["Studio"] = "Instance|NS|ActionOnAutoResumeSync:token,ActionOnStopSync:token,Active Color:Color3,Active Hover Over Color:Color3,Always Save Script Changes:bool,Animate Hover Over:bool,Animation Skeleton Scale:float,Animation Skeleton Transparency:float,AutoPlayAnimatedImages:bool,AutoResumeSyncOnPlaceOpen:bool,AutoUpdateEnabled:bool,Auto Clean Empty Line:bool,Auto Closing Brackets:bool,Auto Closing Quotes:bool,Auto Delete Closing Brackets and Quotes:bool,Auto Indent Rule:token,Auto-Recovery Enabled:bool,Auto-Recovery Interval (Minutes):int,AutocompleteAcceptanceBehavior:token,Automatically trigger AI Code Completion:bool,Basic Objects Display Mode:token,CameraAltLeftMouseToRotate:bool,CameraFocusFillPercent:float,CameraKeyMoveSmoothing:bool,CameraMouseMultiplier:float,CameraNavigationModel:token,CameraNavigationModelLocked:bool,CameraRotateCursorLock:token,CameraRotateShiftFactor:float,CameraShiftFactor:float,CameraTweenFocus:bool,CameraZoomToMousePosition:bool,Camera Mouse Wheel Speed:float,Camera Orbit Speed:float,Camera Pan Speed:float,Camera Shift Speed:float,Camera Speed:float,Camera Speed Adjust Binding:token,Camera Zoom to Mouse Position:bool,Clear Output On Start:bool,CommandBarEnterExec:bool,CommandBarHistoryLen:int,CommandBarLocalState:bool,DefaultScriptSyncFileType:token,DeprecatedObjectsShown:bool,DisplayLanguage:string,DraggerActiveColor:Color3,DraggerLengthFactor:float,DraggerMajorGridIncrement:int,DraggerMaxSoftSnaps:int,DraggerPassiveColor:Color3,DraggerScaleFactor:float,DraggerShowAxisTicks:bool,DraggerShowDraggedPoint:bool,DraggerShowHoverRuler:bool,DraggerShowMeasurement:bool,DraggerShowNegativeAxes:bool,DraggerShowPlanes:bool,DraggerShowTargetSnap:bool,DraggerShowTrackball:bool,DraggerShowWhileDragging:bool,DraggerSoftSnapMarginFactor:float,DraggerSummonMarginFactor:float,DraggerTiltRotateDuration:float,EnableCodeAssist:bool,EnableFindOnType:bool,EnableIndentationRulers:bool,EnableOnTypeAutocomplete:bool,EnableOvertypeMode:bool,EnableSelectionTooltips:bool,EnableStudioStreaming:bool,Enable Autocomplete:bool,Enable Autocomplete Doc View:bool,Enable Client/Server MDI:bool,Enable CoreScript Debugger:bool,Enable Flag Editor:bool,Enable Http Sandboxing:bool,Enable Internal Beta Features:bool,Enable Internal Features:bool,Enable Script Analysis:bool,Enable Scrollbar Markers:bool,Enable Signature Help:bool,Enable Signature Help Doc View:bool,Enable Temporary Tabs:bool,Enable Temporary Tabs In Explorer:bool,Enable Type Hover:bool,ExternalEditorMode:token,Format On Paste:bool,Format On Type:bool,Highlight Current Line:bool,Highlight Occurances:bool,Hover Animate Speed:token,Hover Box Thickness:float,Hover Line Thickness:int,Hover Over Color:Color3,Indent Using Spaces:bool,LargeFileLineCountThreshold:int,LargeFileThreshold:int,Line Thickness:float,LoadAllBuiltinPluginsInRunModes:bool,LoadInternalPlugins:bool,LoadUserPluginsInRunModes:bool,LuaDebuggerEnabled:bool,Main Volume:float,MaxFindReplaceAllResults:int,Maximum Output Lines:int,Only Play Audio from Window in Focus:bool,Output Layout Mode:token,PermissionLevelShown:token,Physical Draggers Select Scope By Default:bool,Pivot Snap To Geometry Color:Color3,PluginDebuggingEnabled:bool,PreferredTextSize:token,ReloadBuiltinPluginsOnChange:bool,ReloadLocalPluginsOnChange:bool,Respect Studio shortcuts when game has focus:bool,Rulers:string,RuntimeUndoBehavior:token,ScriptEditorShouldShowPluginMethods:bool,ScriptTimeoutLength:int,Script Editor Color Preset:token,Scroll Past Last Line:bool,Select Color:Color3,Select/Hover Color:Color3,Selection Box Thickness:float,Selection Line Thickness:int,Set Pivot of Imported Parts:bool,ShowCorePackagesInExplorer:bool,Show Animation Skeleton:bool,Show Animation Skeleton Attachments:bool,Show Animation Skeleton Axes:bool,Show Animation Skeleton Rotations:bool,Show Animation Skeleton Text:bool,Show Core GUI in Explorer while Playing:bool,Show Diagnostics Bar:bool,Show FileSyncService:bool,Show Hidden Objects in Explorer:bool,Show Hover Over:bool,Show Light Guides:bool,Show Navigation Labels:bool,Show Navigation Mesh:bool,Show Pathfinding Links:bool,Show Plugin GUI Service in Explorer:bool,Show Singly Selected Attachment Parent Frame:bool,Show Whitespace:bool,Show plus button on hover in Explorer:bool,Skip Closing Brackets and Quotes:bool,Tab Width:int,Text Wrapping:bool,UseDefaultExternalEditor:bool,Use Bounding Box Move Handles:bool,VAxisColor:Color3,XAxisColor:Color3,YAxisColor:Color3,ZAxisColor:Color3",
		["StudioAssetService"] = "Instance|NS|",
		["StudioAttachment"] = "Instance||AutoHideParent:bool,IsArrowVisible:bool,Offset:Vector2,SourceAnchorPoint:Vector2,TargetAnchorPoint:Vector2",
		["StudioCallout"] = "Instance||",
		["StudioCameraService"] = "Instance|NS|FocusDistance:float,GraspDistance:float,LoggingEnabled:bool",
		["StudioCaptureService"] = "Instance|NS|",
		["StudioData"] = "Instance|NS|EnableScriptCollabByDefaultOnLoad:bool",
		["StudioDeviceEmulatorService"] = "Instance|NS|",
		["StudioDeviceSimulatorService"] = "Instance|NS|",
		["StudioObjectBase"] = "Instance|N|",
		["StudioWidget"] = "StudioObjectBase|N|",
		["StudioPublishService"] = "Instance|NS|PublishLocked:bool",
		["StudioScreenshotCapture"] = "Instance|N|",
		["StudioScriptDebugEventListener"] = "Instance|NS|",
		["StudioSdkService"] = "Instance|NS|",
		["StudioService"] = "Instance|NS|Secrets:string",
		["StudioTestService"] = "Instance|NS|EditModeActive:bool",
		["StudioTheme"] = "Instance|N|",
		["StudioUserService"] = "Instance|NS|",
		["StudioWidgetsService"] = "Instance|NS|",
		["StyleBase"] = "Instance|N|",
		["StyleRule"] = "StyleBase||Priority:int,PropertiesSerialize:BinaryString:H,PropertyTransitionsSerialize:BinaryString:H,Selector:string",
		["StyleSheet"] = "StyleBase||",
		["StyleDerive"] = "Instance||Priority:int,StyleSheet:Ref",
		["StyleLink"] = "Instance||StyleSheet:Ref",
		["StyleQuery"] = "Instance||ConditionsSerialize:BinaryString:H",
		["StylingService"] = "Instance|NS|",
		["SurfaceAppearance"] = "Instance||AlphaMode:token,Color:Color3,ColorMap:ContentId,ColorMapContent:Content,EmissiveMaskContent:Content,EmissiveStrength:float,EmissiveTint:Color3,MetalnessMap:ContentId,MetalnessMapContent:Content,NormalMap:ContentId,NormalMapContent:Content,ResampleMode:token,RoughnessMap:ContentId,RoughnessMapContent:Content,SurfaceSlot:int,TexturePack:ContentId,TexturePackContent:Content",
		["SystemThemeService"] = "Instance|NS|",
		["TaskScheduler"] = "Instance|NS|ThreadPoolConfig:token",
		["Team"] = "Instance||AutoAssignable:bool,TeamColor:BrickColor",
		["TeamCreateData"] = "Instance|NS|",
		["TeamCreatePublishService"] = "Instance|NS|",
		["TeamCreateService"] = "Instance|NS|",
		["Teams"] = "Instance|NS|",
		["TelemetryService"] = "Instance|NS|",
		["TeleportAsyncResult"] = "Instance|N|",
		["TeleportOptions"] = "Instance||ForcePublicServer:bool,ReservedServerAccessCode:string:>ReservedServerId,ReservedServerId:string,ServerInstanceId:string,ShouldReserveServer:bool:>ReservedServerId,VipServerId:string",
		["TeleportService"] = "Instance|NS|",
		["TemporaryCageMeshProvider"] = "Instance|NS|",
		["TemporaryScriptService"] = "Instance|NS|",
		["TerrainDetail"] = "Instance||ColorMap:ContentId,ColorMapContent:Content,EmissiveMaskContent:Content,EmissiveStrength:float,EmissiveTint:Color3,Face:token,MaterialPattern:token,MetalnessMap:ContentId,MetalnessMapContent:Content,NormalMap:ContentId,NormalMapContent:Content,RoughnessMap:ContentId,RoughnessMapContent:Content,StudsPerTile:float,TexturePack:ContentId:H,TexturePackContent:Content:H",
		["TerrainRegion"] = "Instance||ExtentsMax:Vector3int16:H,ExtentsMin:Vector3int16:H,SmoothGrid:BinaryString:H",
		["TestCoordinatorService"] = "Instance|NS|",
		["TestService"] = "Instance|S|AutoRuns:bool,Description:string,ExecuteWithStudioRun:bool,IsPhysicsEnvironmentalThrottled:bool,IsSleepAllowed:bool,NumberOfPlayers:int,SimulateSecondsLag:double,ThrottlePhysicsToRealtime:bool,Timeout:double",
		["TextBoxService"] = "Instance|NS|",
		["TextChannel"] = "Instance||AddPlayersOnJoin:bool",
		["TextChatCommand"] = "Instance||AutocompleteVisible:bool,Enabled:bool,PrimaryAlias:string,SecondaryAlias:string",
		["TextChatConfigurations"] = "Instance|N|",
		["BubbleChatConfiguration"] = "TextChatConfigurations|N|AdorneeName:string,BackgroundColor3:Color3,BackgroundTransparency:double,BubbleDuration:float,BubblesSpacing:float,Enabled:bool,Font:token,FontFace:Font,LocalPlayerStudsOffset:Vector3,MaxBubbles:float,MaxDistance:float,MinimizeDistance:float,TailVisible:bool,TextColor3:Color3,TextSize:int64,VerticalStudsOffset:float",
		["ChannelTabsConfiguration"] = "TextChatConfigurations|N|BackgroundColor3:Color3,BackgroundTransparency:double,Enabled:bool,FontFace:Font,HoverBackgroundColor3:Color3,SelectedTabTextColor3:Color3,TextColor3:Color3,TextSize:int64,TextStrokeColor3:Color3,TextStrokeTransparency:double",
		["ChatInputBarConfiguration"] = "TextChatConfigurations|N|AutocompleteEnabled:bool,BackgroundColor3:Color3,BackgroundTransparency:double,Enabled:bool,FontFace:Font,KeyboardKeyCode:token,PlaceholderColor3:Color3,TargetTextChannel:Ref,TextColor3:Color3,TextSize:int64,TextStrokeColor3:Color3,TextStrokeTransparency:double",
		["ChatWindowConfiguration"] = "TextChatConfigurations|N|BackgroundColor3:Color3,BackgroundTransparency:double,Enabled:bool,FontFace:Font,HeightScale:float,HorizontalAlignment:token,TextChannelDisplayMode:token,TextColor3:Color3,TextSize:int64,TextStrokeColor3:Color3,TextStrokeTransparency:double,VerticalAlignment:token,WidthScale:float",
		["TextChatMessage"] = "Instance|N|BubbleChatMessageProperties:Ref,ChatWindowMessageProperties:Ref,TextChannel:Ref,TextSource:Ref",
		["TextChatMessageProperties"] = "Instance||",
		["BubbleChatMessageProperties"] = "TextChatMessageProperties||",
		["ChatWindowMessageProperties"] = "TextChatMessageProperties|N|",
		["TextChatService"] = "Instance|NS|ChatTranslationFTUXShown:bool,ChatTranslationToggleEnabled:bool,ChatVersion:token,CreateDefaultCommands:bool,CreateDefaultTextChannels:bool,HasSeenDeprecationDialog:bool,IsLegacyChatDisabled:bool,PlatformIntegratedChat:token",
		["TextDocument"] = "Instance||TextContent:Content",
		["TextFilterResult"] = "Instance|N|",
		["TextFilterTranslatedResult"] = "Instance|N|",
		["TextGenerator"] = "Instance||Seed:int,SystemPrompt:string,Temperature:float,TopP:float",
		["TextService"] = "Instance|NS|",
		["TextSource"] = "Instance|N|CanSend:bool",
		["TextureGenerationPartGroup"] = "Instance|N|",
		["TextureGenerationService"] = "Instance|NS|",
		["TextureGenerationUnwrappingRequest"] = "Instance|N|",
		["ThirdPartyUserService"] = "Instance|NS|",
		["ThreadState"] = "Instance|N|",
		["TimerService"] = "Instance|NS|",
		["ToastNotificationService"] = "Instance|NS|",
		["TouchInputService"] = "Instance|NS|",
		["TouchTransmitter"] = "Instance|N|",
		["TraceRouteService"] = "Instance|NS|",
		["TracerService"] = "Instance|NS|",
		["TrackerLodController"] = "Instance|N|AudioMode:token,VideoExtrapolationMode:token,VideoLodMode:token,VideoMode:token",
		["TrackerStreamAnimation"] = "Instance||",
		["Trail"] = "Instance||Attachment0:Ref,Attachment1:Ref,Brightness:float,Color:ColorSequence,Enabled:bool,FaceCamera:bool,Lifetime:float,LightEmission:float,LightInfluence:float,MaxLength:float,MinLength:float,Texture:ContentId,TextureContent:Content,TextureLength:float,TextureMode:token,Transparency:NumberSequence,WidthScale:NumberSequence",
		["Translator"] = "Instance|N|",
		["TutorialService"] = "Instance|NS|",
		["TweenBase"] = "Instance|N|",
		["Tween"] = "TweenBase||",
		["TweenService"] = "Instance|NS|",
		["UGCAvatarService"] = "Instance|NS|",
		["UGCValidationService"] = "Instance|NS|",
		["UIBase"] = "Instance|N|",
		["UIComponent"] = "UIBase|N|",
		["UIBlur"] = "UIComponent||Color:Color3,Enabled:bool,Strength:token,Transparency:float",
		["UIConstraint"] = "UIComponent|N|",
		["UIAspectRatioConstraint"] = "UIConstraint||AspectRatio:float,AspectType:token,DominantAxis:token",
		["UISizeConstraint"] = "UIConstraint||MaxSize:Vector2,MinSize:Vector2",
		["UITextSizeConstraint"] = "UIConstraint||MaxTextSize:int,MinTextSize:int",
		["UICorner"] = "UIComponent||BottomLeftRadius:UDim,BottomRightRadius:UDim,TopLeftRadius:UDim,TopRightRadius:UDim",
		["UIDragDetector"] = "UIComponent||ActivatedCursorIcon:ContentId,ActivatedCursorIconContent:Content,BoundingBehavior:token,BoundingUI:Ref,CursorIcon:ContentId,CursorIconContent:Content,DragAxis:Vector2,DragRelativity:token,DragRotation:float,DragSpace:token,DragStyle:token,DragUDim2:UDim2,Enabled:bool,MaxDragAngle:float,MaxDragTranslation:UDim2,MinDragAngle:float,MinDragTranslation:UDim2,ReferenceUIInstance:Ref,ResponseStyle:token,Selectable:bool,SelectionModeDragSpeed:UDim2,SelectionModeRotateSpeed:float,UIDragSpeedAxisMapping:token",
		["UIFlexItem"] = "UIComponent||FlexMode:token,GrowRatio:float,ItemLineAlignment:token,ShrinkRatio:float",
		["UIGradient"] = "UIComponent||Color:ColorSequence,Enabled:bool,Offset:Vector2,Rotation:float,Scale:float,TileMode:token,Transparency:NumberSequence,Type:token",
		["UILayout"] = "UIComponent|N|",
		["UIGridStyleLayout"] = "UILayout|N|FillDirection:token,HorizontalAlignment:token,SortOrder:token,VerticalAlignment:token",
		["UIGridLayout"] = "UIGridStyleLayout||CellPadding:UDim2,CellSize:UDim2,FillDirectionMaxCells:int,StartCorner:token",
		["UIListLayout"] = "UIGridStyleLayout||HorizontalFlex:token,ItemLineAlignment:token,Padding:UDim,VerticalFlex:token,Wraps:bool",
		["UIPageLayout"] = "UIGridStyleLayout||Animated:bool,Circular:bool,EasingDirection:token,EasingStyle:token,GamepadInputEnabled:bool,Padding:UDim,ScrollWheelInputEnabled:bool,TouchInputEnabled:bool,TweenTime:float",
		["UITableLayout"] = "UIGridStyleLayout||FillEmptySpaceColumns:bool,FillEmptySpaceRows:bool,MajorAxis:token,Padding:UDim2",
		["UIPadding"] = "UIComponent||PaddingBottom:UDim,PaddingLeft:UDim,PaddingRight:UDim,PaddingTop:UDim",
		["UIScale"] = "UIComponent||Scale:float",
		["UIShadow"] = "UIComponent||BlurRadius:UDim,Color:Color3,Enabled:bool,Inset:bool,Mode:token,Offset:UDim2,ShowBehindParent:bool,Spread:UDim2,Transparency:float,ZIndex:int",
		["UIStroke"] = "UIComponent||ApplyStrokeMode:token,BorderOffset:UDim,BorderStrokePosition:token,Color:Color3,Enabled:bool,LineJoinMode:token,StrokeSizingMode:token,Thickness:float,Transparency:float,ZIndex:int",
		["UIDragDetectorService"] = "Instance|NS|",
		["UniqueIdLookupService"] = "Instance|NS|",
		["UnvalidatedAssetService"] = "Instance|NS|CachedData:string:H",
		["UserGameSettings"] = "Instance|NS|AllTutorialsDisabled:bool,BadgeVisible:bool,CameraMode:token,CameraYInverted:bool,ChatTranslationEnabled:bool,ChatTranslationFTUXShown:bool,ChatTranslationLocale:string,ChatTranslationToggleEnabled:bool,ChatVisible:bool,CompletedTutorials:string:H,ComputerCameraMovementChanged:bool:H,ComputerCameraMovementMode:token,ComputerMovementChanged:bool:H,ComputerMovementMode:token,ControlMode:token,DefaultCameraID:string,FramerateCap:int,Fullscreen:bool,GamepadCameraSensitivity:float,GraphicsOptimizationMode:token,GraphicsQualityLevel:int,HapticStrength:float,HasEverUsedVR:bool,MasterVolume:float,MasterVolumeStudio:float,MaxQualityEnabled:bool,MicroProfilerWebServerEnabled:bool,MouseSensitivity:float,MouseSensitivityFirstPerson:Vector2,MouseSensitivityThirdPerson:Vector2,OnScreenProfilerEnabled:bool,PartyVoiceVolume:float,PeoplePageLayout:token,PerformanceStatsVisible:bool,PlayerHeight:float,PlayerListVisible:bool,PlayerNamesEnabled:bool,PreferredTextSize:token,PreferredTransparency:float,QualityResetLevel:int,RCCProfilerRecordFrameRate:int,RCCProfilerRecordTimeFrame:int,ReadAloud:bool,ReducedMotion:bool,SavedQualityLevel:token,StartMaximized:bool:H,StartScreenPosition:Vector2:H,StartScreenSize:Vector2:H,TouchCameraMovementChanged:bool:H,TouchCameraMovementMode:token,TouchMovementChanged:bool:H,TouchMovementMode:token,UIScaleMultiplierHundredths:int,UiNavigationKeyBindEnabled:bool,UsedCoreGuiIsVisibleToggle:bool,UsedCustomGuiIsVisibleToggle:bool,UsedHideHudShortcut:bool,VRComfortSetting:token,VREnabled:bool,VRRotationIntensity:int,VRSafetyBubbleMode:token,VRSmoothRotationEnabled:bool,VRSmoothRotationEnabledCustomOption:bool,VRThirdPersonFollowCamEnabled:bool,VRThirdPersonFollowCamEnabledCustomOption:bool,VignetteEnabled:bool,VignetteEnabledCustomOption:bool,VoiceChatVolume:float,gaID:string:H",
		["UserInputService"] = "Instance|NS|LegacyInputEventsEnabled:bool,MouseBehavior:token,MouseIcon:ContentId,MouseIconContent:Content,MouseIconEnabled:bool",
		["UserService"] = "Instance|NS|",
		["VRService"] = "Instance|NS|AutomaticScaling:token,AvatarGestures:bool,ControllerModels:token,FadeOutViewOnCollision:bool,LaserPointer:token",
		["VRStatusService"] = "Instance|NS|",
		["ValueBase"] = "Instance|N|",
		["BinaryStringValue"] = "ValueBase||Value:BinaryString:H",
		["BoolValue"] = "ValueBase||Value:bool",
		["BrickColorValue"] = "ValueBase||Value:BrickColor",
		["CFrameValue"] = "ValueBase||Value:CFrame",
		["Color3Value"] = "ValueBase||Value:Color3",
		["DoubleConstrainedValue"] = "ValueBase||MaxValue:double,MinValue:double,value:double:H",
		["IntConstrainedValue"] = "ValueBase||MaxValue:int64,MinValue:int64,value:int64:H",
		["IntValue"] = "ValueBase||Value:int64",
		["NumberValue"] = "ValueBase||Value:double",
		["ObjectValue"] = "ValueBase||Value:Ref",
		["RayValue"] = "ValueBase||Value:Ray",
		["StringValue"] = "ValueBase||Value:string",
		["Vector3Value"] = "ValueBase||Value:Vector3",
		["ValueCurve"] = "Instance||ValuesAndTimes:BinaryString:H",
		["Vector3Curve"] = "Instance||",
		["VersionControlService"] = "Instance|NS|",
		["VideoCaptureService"] = "Instance|NS|",
		["VideoDeviceInput"] = "Instance||Active:bool,CameraId:string,CaptureQuality:token",
		["VideoPlayer"] = "Instance||InternalVideoUsage:token,Looping:bool,MaximumResolution:token,PlaybackSpeed:float,TimePosition:double,VideoContent:Content,Volume:float",
		["VideoScreenCaptureService"] = "Instance|NS|",
		["VideoService"] = "Instance|NS|",
		["VirtualInputManager"] = "Instance|S|",
		["VirtualUser"] = "Instance|NS|",
		["VisibilityCheckDispatcher"] = "Instance|NS|",
		["Visit"] = "Instance|NS|",
		["VisualizationMode"] = "Instance||Enabled:bool,Title:string,ToolTip:string",
		["VisualizationModeCategory"] = "Instance||Enabled:bool,Title:string",
		["VisualizationModeService"] = "Instance|NS|",
		["VoiceChatInternal"] = "Instance|NS|",
		["VoiceChatService"] = "Instance|NS|DefaultDistanceAttenuation:token,EnableDefaultVoice:bool,EnableVoiceVolumeControls:token,UseAudioApi:token",
		["WebSocketClient"] = "Instance|N|",
		["WebSocketService"] = "Instance|NS|",
		["WebViewService"] = "Instance|NS|",
		["WeldConstraint"] = "Instance||CFrame0:CFrame:H,Part0Internal:Ref:H,Part1Internal:Ref:H,State:int:H",
		["WindowProtocolService"] = "Instance|NS|",
		["Wire"] = "Instance||SourceInstance:Ref,SourceName:string,TargetInstance:Ref,TargetName:string",
		["WrapTextureTransfer"] = "Instance||ReferenceCageMeshContent:Content,UVMaxBound:Vector2,UVMinBound:Vector2",
		["Logger"] = "Object|N|",
		["LuauExpression"] = "Object|N|",
		["MLSession"] = "Object|N|",
		["OutputLink"] = "Object|N|",
		["ParticipantHandle"] = "Object|N|",
		["PickedFile"] = "Object|N|",
		["PluginConnection"] = "Object|N|",
		["SceneSnapshot"] = "Object|N|",
		["StudioActionOverride"] = "Object|N|Enabled:bool",
		["TerrainIterateOperation"] = "Object|N|",
		["TerrainModifyOperation"] = "Object|N|",
		["TerrainReadOperation"] = "Object|N|",
		["TerrainWriteOperation"] = "Object|N|",
		["TestCase"] = "Object|N|",
		["TestExecutionContext"] = "Object|N|",
		["TestFailure"] = "Object|N|",
		["TestResult"] = "Object|N|",
		["TestRunResult"] = "Object|N|",
		["TestSuite"] = "Object|N|",
		["VideoSampler"] = "Object|N|",
		["VirtualInput"] = "Object|N|",
		["VoxelBuffer"] = "Object|N|",
		["WebStreamClient"] = "Object|N|",
	},
}
end

__modules["scripts"] = function()
-- Script sources: bytecode -> decompiler, cached by bytecode hash for the whole session
-- (scripts that share bytecode, and re-saves, cost one decompile).
--
-- `decompile()` is whatever is installed when the save starts: the executor's native
-- decompiler, or a loader's hook such as Oracle (an HTTP API). Hooks can return their
-- error text as if it were source, so every result is checked before it is saved or cached.
local Env = require("env")
local Log = require("log")
local Util = require("util")

local Scripts = {}

local HttpService = game:GetService("HttpService")

local genv = (getgenv and getgenv()) or _G
local CACHE = genv.__SaveInstance420Sources
if type(CACHE) ~= "table" then
	CACHE = {}
	genv.__SaveInstance420Sources = CACHE
end

local state

-- Provider identification ------------------------------------------------------------------
local KNOWN_PROVIDERS = { -- substring of a URL or name inside the hook -> label, kind (for run stats)
	{ "oracle.mshq.dev", "Oracle", "oracle" },
	{ "oracle", "Oracle", "oracle" },
	{ "lua.expert", "lua.expert", "lua_expert" },
	{ "konstant", "Konstant", "konstant" },
	{ "medal", "Medal", "medal" },
}

local function currentDecompile()
	local installed = genv.decompile
	if type(installed) == "function" then
		return installed
	end
	return Env.decompile
end

local function isNative(f)
	if type(iscclosure) == "function" then
		local ok, result = pcall(iscclosure, f)
		if ok then
			return result == true
		end
	end
	return false
end

-- Strings a hook holds (constants and upvalues), lowercased, for provider detection.
local function hookStrings(f)
	local strings = {}
	local debugLib = debug
	for _, getter in { debugLib.getconstants, debugLib.getupvalues, getconstants, getupvalues } do
		if type(getter) == "function" then
			local ok, values = pcall(getter, f)
			if ok and type(values) == "table" then
				for _, value in values do
					if type(value) == "string" then
						table.insert(strings, string.lower(value))
					end
				end
			end
		end
	end
	return strings
end

-- Returns the label for the installed decompile(), whether it is a native C function, and a
-- fixed kind word for run statistics (a user-chosen name is never sent).
local function identify(f, options)
	local native = isNative(f)
	local namedKind = native and "native" or "named_hook"
	if type(options.DecompilerName) == "string" and options.DecompilerName ~= "" then
		return options.DecompilerName, native, namedKind
	end
	-- Registration convention kept from 1.x:
	-- getgenv().__SaveInstanceDecompiler = { Name = "Oracle", Function = getgenv().decompile }
	local registered = genv.__SaveInstanceDecompiler
	if type(registered) == "table" and registered.Function == f and type(registered.Name) == "string" then
		return registered.Name, native, namedKind
	end
	if native then
		return (string.match(Env.executor, "^(%S+)") or "executor") .. " decompile()", true, "native"
	end
	for _, text in hookStrings(f) do
		for _, provider in KNOWN_PROVIDERS do
			if string.find(text, provider[1], 1, true) then
				return provider[2], false, provider[3]
			end
		end
	end
	return "decompile() hook", false, "hook"
end

-- Result checking --------------------------------------------------------------------------
local KEY_TEXT = { "key has expired", "expired key", "not redeemed", "invalid key", "invalid api key", "unauthorized", "unauthorised" }
local QUOTA_TEXT = { "quota", "out of credits", "out of requests", "insufficient credits", "insufficient balance", "no credits left", "no requests left" }
local RATE_TEXT = { "rate limit", "rate-limit", "ratelimit", "too many requests", "too many concurrent", "slow down" }
local STUBS = { -- placeholder "sources" providers return instead of failing
	"-- decompilation failed",
	"-- update the decompiling script",
	"-- something went wrong when decompiling",
	"-- your executor does not have a decompiler",
	"-- failed to decompile",
	"-- decompiler error",
}

local function containsAny(text, list)
	for _, needle in list do
		if string.find(text, needle, 1, true) then
			return true
		end
	end
	return false
end

local function scrub(text) -- providers sometimes echo the request URL, key included
	text = string.gsub(tostring(text), "([?&]key=)[^&%s\"']+", "%1***")
	text = string.gsub(text, "[%c]", " ")
	return string.sub(text, 1, 160)
end

-- nil when `source` looks like decompiled code; otherwise kind, message where kind is
-- "fatal" (stop decompiling: key or quota), "rate" (back off and retry) or "failed".
local function classify(source)
	if type(source) ~= "string" or string.match(source, "^%s*$") then
		return "failed", "decompiler returned nothing"
	end
	local head = string.lower(string.sub(source, 1, 300))
	for _, stub in STUBS do
		if string.sub(head, 1, #stub) == stub then
			return containsAny(head, RATE_TEXT) and "rate" or "failed", scrub(string.match(source, "^[^\n]*"))
		end
	end
	if string.find(head, "^%s*<!doctype") or string.find(head, "^%s*<html") then
		return (containsAny(head, RATE_TEXT) or string.find(head, "1015", 1, true)) and "rate" or "failed",
			"the provider returned a web page instead of source"
	end
	-- Error bodies are one short line of prose or a small JSON object; code is not.
	if #source <= 300 and not string.find(source, "\n", 1, true)
		and not string.find(head, "^%s*return[%s%(]") and not string.find(head, "^%s*local%s") then
		if containsAny(head, KEY_TEXT) or containsAny(head, QUOTA_TEXT) then
			return "fatal", scrub(source)
		elseif containsAny(head, RATE_TEXT) then
			return "rate", scrub(source)
		elseif string.find(head, "^%s*{") and (string.find(head, "error", 1, true) or string.find(head, "message", 1, true)) then
			return "failed", scrub(source)
		end
	end
	return nil
end
Scripts.classify = classify

-- Calling the provider --------------------------------------------------------------------
-- Runs f in its own thread and waits up to `timeout` seconds. A thread that overruns is
-- abandoned, never cancelled: task.cancel on a thread inside a native decompiler crashes
-- Volt. A late result is simply ignored.
local function callWithTimeout(timeout, f, ...)
	local box = { done = false }
	task.spawn(function(...)
		box.result = table.pack(pcall(f, ...))
		box.done = true
	end, ...)
	if not box.done then
		local deadline = os.clock() + timeout
		while not box.done do
			if os.clock() > deadline then
				return false, string.format("timed out after %gs", timeout)
			end
			task.wait()
		end
	end
	return table.unpack(box.result, 1, box.result.n)
end

-- lua.expert free API. Requests are spaced by DecompilerApiGap seconds (it rejects bursts)
-- and `request` is called directly: some executors' request misbehaves in spawned threads.
local nextRequestAt = 0
local function apiDecompile(_, bytecode)
	local wait = nextRequestAt - os.clock()
	if wait > 0 then
		task.wait(wait)
	end
	nextRequestAt = os.clock() + state.options.DecompilerApiGap
	local response = Env.request({
		Url = state.options.DecompilerApiUrl,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode({ script = Env.base64encode(bytecode) }),
	})
	if type(response) == "table" and type(response.Body) == "string" then
		if response.StatusCode == 200 or response.StatusCode == 429 then
			return response.Body -- a 429 body is classified as a rate limit
		end
	end
	error(string.format("HTTP %s", tostring(type(response) == "table" and response.StatusCode or "no response")), 0)
end

function Scripts.begin(options)
	state = {
		options = options,
		results = {},
		byHash = {}, -- [bytecode hash] = { source, by, fresh } | { failure }
		keys = {}, -- [script] = bytecode hash, filled by prepare()
		stats = { total = 0, decompiled = 0, cached = 0, failed = 0, server = 0, unavailable = 0 },
	}
	local hook = currentDecompile()
	state.kind = "none"
	if not options.Decompile then
		state.label, state.kind = "off (Decompile = false)", "off"
	elseif hook then
		local label, native, kind = identify(hook, options)
		state.kind = kind
		state.backend = function(script)
			return hook(script)
		end
		state.spawn, state.native, state.label = true, native, label
		state.concurrency = math.clamp(math.floor(tonumber(options.DecompileConcurrency) or 16), 1, 64)
		-- Remote hooks wait on HTTP; give them as long as their own request timeout.
		state.timeout = tonumber(options.DecompileTimeout) or (native and 10 or 30)
	elseif options.DecompilerFallback and Env.request and Env.getscriptbytecode then
		state.backend, state.spawn, state.concurrency, state.label = apiDecompile, false, 1, "lua.expert API"
		state.kind = "lua_expert_api"
		state.timeout = tonumber(options.DecompileTimeout) or 30
	else
		state.label = "unavailable on this executor"
	end
	return state.label
end

function Scripts.stats()
	return state.stats
end

function Scripts.stoppedReason()
	return state and state.stopped
end

-- A fixed word naming the decompiler kind, for run statistics.
function Scripts.providerKind()
	return state and state.kind or "none"
end

-- "client" scripts carry bytecode on this client; "server" ones never do.
function Scripts.kind(script)
	if script:IsA("ModuleScript") or script:IsA("LocalScript") then
		return "client"
	elseif script:IsA("Script") then
		local ok, context = pcall(function()
			return script.RunContext
		end)
		return (ok and context == Enum.RunContext.Client) and "client" or "server"
	end
	return "client"
end

-- Calls the provider once. Returns kind, sourceOrMessage where kind is "ok", "fatal",
-- "rate" or "failed".
local function attempt(script, bytecode, timeout)
	local ok, source
	if state.spawn then
		ok, source = callWithTimeout(timeout, state.backend, script, bytecode)
	else
		ok, source = pcall(state.backend, script, bytecode)
	end
	if not ok then
		return "failed", scrub(source)
	end
	local kind, message = classify(source)
	if kind then
		return kind, message
	end
	return "ok", source
end

local function cachedEntry(key)
	local entry = state.byHash[key]
	if entry then
		return entry
	end
	if state.options.ScriptCache then
		entry = CACHE[key]
		if entry and classify(entry.source) then
			CACHE[key] = nil -- written by an older build that cached error text
			return nil
		end
	end
	return entry
end

local function remember(key, source)
	local entry = { source = source, by = state.label, fresh = true }
	state.byHash[key] = entry
	if state.options.ScriptCache then
		CACHE[key] = { source = source, by = state.label }
	end
end

local function stop(message)
	if not state.stopped then
		state.stopped = message
		Log.warn(string.format("%s stopped answering: %s. The remaining scripts are saved without source.", state.label, message))
	end
end

local function resolve(script)
	local result = state.results[script]
	if result then
		return result
	end
	local options = state.options
	local stats = state.stats
	stats.total += 1

	if Scripts.kind(script) == "server" then
		stats.server += 1
		result = { note = "server script: its source is never sent to the client" }
	elseif not state.backend and not options.DecompileJobless then
		stats.unavailable += 1
		result = { note = "not decompiled: decompiler " .. state.label }
	else
		local ok, bytecode = false, nil
		if Env.getscriptbytecode then
			ok, bytecode = pcall(Env.getscriptbytecode, script)
		end
		if not ok or type(bytecode) ~= "string" or bytecode == "" then
			stats.unavailable += 1
			result = { note = "no bytecode on this client" }
		else
			local key = state.keys[script] or Env.hash(bytecode)
			local known = cachedEntry(key)
			if known and known.failure then
				stats.failed += 1
				result = { note = "decompile failed: " .. known.failure }
			elseif known then
				if known.fresh then
					known.fresh = nil -- the first script with this bytecode counts as the decompile
					stats.decompiled += 1
					result = { source = known.source, note = "decompiled with " .. known.by }
				else
					stats.cached += 1
					result = { source = known.source, note = "decompiled with " .. known.by .. " (cached)" }
				end
			elseif options.DecompileJobless then
				stats.unavailable += 1
				result = { note = "not in the decompile cache (DecompileJobless)" }
			elseif state.stopped then
				stats.failed += 1
				result = { note = "not decompiled: " .. state.label .. " stopped (" .. state.stopped .. ")" }
			else
				local kind, value = attempt(script, bytecode, state.timeout)
				if kind == "ok" then
					remember(key, value)
					state.byHash[key].fresh = nil
					stats.decompiled += 1
					result = { source = value, note = "decompiled with " .. state.label }
				else
					if kind == "fatal" then
						stop(value)
					end
					stats.failed += 1
					result = { note = "decompile failed: " .. value }
				end
			end
			if options.SaveBytecode then
				result.bytecode = bytecode
			end
		end
	end
	state.results[script] = result
	return result
end

-- Decompiles everything in `list` before the save, so writing never stalls and progress
-- can be shown. Each distinct bytecode is decompiled once.
-- onProgress(done, total, label)
function Scripts.prepare(list, onProgress)
	local options = state.options
	if not state.backend or options.DecompileJobless then
		return
	end

	-- 1. Bytecode + hash for every client script (cheap), keeping one job per bytecode.
	local jobs, queued = {}, {}
	for i, script in list do
		if Scripts.kind(script) == "client" then
			local ok, bytecode = pcall(Env.getscriptbytecode, script)
			if ok and type(bytecode) == "string" and bytecode ~= "" then
				local key = Env.hash(bytecode)
				state.keys[script] = key
				if not queued[key] and not cachedEntry(key) then
					queued[key] = true
					table.insert(jobs, { key = key, script = script, bytecode = bytecode })
				end
			end
		end
		if i % 250 == 0 then
			onProgress(0, #list, "reading bytecode")
			Util.yield()
		end
	end

	-- 2. Worker pool. `limit` is how many may be in flight: it halves on a rate limit and
	-- creeps back up after a run of successes. A key or quota error stops everything.
	local total, done = #jobs, 0
	local queue, head, requeued = jobs, 1, {}
	local limit, inflight, cooldownUntil, backoff, streak = state.concurrency, 0, 0, 2, 0
	local timeout = state.timeout

	local function finish(job, kind, value)
		if kind == "ok" then
			remember(job.key, value)
		else
			state.byHash[job.key] = { failure = value }
			Log.debug("decompile failed:", Util.path(job.script), value)
		end
		done += 1
	end

	local function nextJob()
		local job = queue[head]
		if job then
			head += 1
			return job
		end
		return table.remove(requeued, 1)
	end

	local function handle(job)
		local kind, value = attempt(job.script, job.bytecode, timeout)
		if kind == "rate" then
			job.rateRetries = (job.rateRetries or 0) + 1
			streak = 0
			if job.rateRetries <= 6 then
				limit = math.max(1, limit // 2)
				cooldownUntil = math.max(cooldownUntil, os.clock() + backoff)
				Log.debug(string.format("rate limited (%s); %d in flight, waiting %gs", value, limit, backoff))
				backoff = math.min(backoff * 2, 30)
				table.insert(requeued, job)
				return
			end
		elseif kind == "fatal" then
			stop(value)
		elseif kind == "ok" then
			backoff = 2
			streak += 1
			if streak >= 40 and limit < state.concurrency then
				limit += 1
				streak = 0
			end
		end
		finish(job, kind, value)
	end

	local active = 0
	local function worker()
		while not state.stopped do
			while not state.stopped and (inflight >= limit or os.clock() < cooldownUntil) do
				task.wait(0.05)
			end
			if state.stopped then
				break
			end
			local job = nextJob()
			if not job then
				break
			end
			inflight += 1
			pcall(handle, job)
			inflight -= 1
			Util.step() -- a synchronous native decompiler must not hold the frame
		end
		active -= 1
	end

	if state.concurrency <= 1 then
		active = 1
		worker() -- API backends: one request at a time, on this thread
	else
		for _ = 1, math.min(state.concurrency, total) do
			active += 1
			task.spawn(worker)
		end
	end
	while active > 0 do
		onProgress(done, total, limit < state.concurrency and string.format("%s, slowed to %d at a time", state.label, limit) or state.label)
		task.wait()
	end

	-- 3. With many jobs queued inside a provider, a slow script can miss its deadline
	-- without being stuck. Give each plain failure one more try on its own, with more time.
	if not state.stopped and state.spawn and state.concurrency > 1 then
		local retry = {}
		for _, job in jobs do
			local entry = state.byHash[job.key]
			if entry and entry.failure then
				table.insert(retry, job)
			end
		end
		for i, job in retry do
			if state.stopped then
				break
			end
			onProgress(i, #retry, "retrying slow scripts")
			local kind, value = attempt(job.script, job.bytecode, timeout * 3)
			if kind == "ok" then
				remember(job.key, value)
			else
				if kind == "fatal" then
					stop(value)
				end
				state.byHash[job.key] = { failure = value }
			end
			Util.step()
		end
	end
	onProgress(total, total, state.label)

	local failed = 0
	for _, job in jobs do
		local entry = state.byHash[job.key]
		if not entry or entry.failure then
			failed += 1
		end
	end
	return { unique = total, failed = failed, stopped = state.stopped }
end

-- Final Source text for a script.
function Scripts.source(script, ignored)
	if ignored then
		return "-- Skipped by IgnoreList\n"
	end
	local result = resolve(script)
	local source = "-- SaveInstance 420 Edition: " .. result.note .. "\n"
	if result.source then
		source ..= result.source
	end
	if result.bytecode then
		source ..= "\n\n--[==[ bytecode (base64)\n" .. Env.base64encode(result.bytecode) .. "\n]==]\n"
	end
	return source
end

return Scripts
end

__modules["serialize"] = function()
-- Writes the XML document (Roblox XML format, version 4).
local Schema = require("schema")
local Scripts = require("scripts")
local Encode = require("encode")
local Env = require("env")
local Util = require("util")

local Serialize = {}

local function readme(version)
	return table.concat({
		"--[[",
		"\tSaved with SaveInstance 420 Edition " .. version,
		"\tPlace " .. tostring(game.PlaceId) .. ", saved " .. os.date("!%Y-%m-%d %H:%M UTC") .. " with " .. Env.executor,
		"",
		"\tWhat a client can save:",
		"\t- Server scripts never reach the client, so they contain only a note, and",
		"\t  ServerScriptService / ServerStorage start empty.",
		"\t- LocalScripts and ModuleScripts are decompiled; decompiled code can need fixes.",
		"\t- Only content streamed in to this client is saved.",
		"\t- MeshParts that use private assets can show as grey boxes in Studio.",
		"",
		"\tTips:",
		"\t- Save the place as .rbxl from Studio right away (smaller, faster to open).",
		"\t- Camera stuck: workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed, or delete the Camera.",
		"\t- Character will not spawn: move the scripts out of StarterPlayer, then run",
		"\t  game:GetService(\"Players\").CharacterAutoLoads = true in the command bar.",
		"]]",
		"return nil",
		"",
	}, "\n")
end

-- job: { roots, extras, rules, isModel }; onProgress(instancesWritten, bytes)
function Serialize.run(job, writer, options, version, onProgress)
	local push = writer.push
	local rules = job.rules
	local text, cdata = Encode.text, Encode.cdata
	local read, isDefault, plan = Schema.read, Schema.isDefault, Schema.plan
	local skipDefaults = options.IgnoreDefaultProperties ~= false
	local saveNotCreatable = options.SaveNotCreatable
	local unionsAsParts = options.TreatUnionsAsParts

	local ignoredProperties = {}
	for key, value in options.IgnoreProperties do
		if type(key) == "number" and type(value) == "string" then
			ignoredProperties[value] = true
		elseif type(key) == "string" and value then
			ignoredProperties[key] = true
		end
	end

	-- Referents and shared strings --------------------------------------------------------
	local referents, referentCount = {}, 0
	local sharedKeys, sharedList = {}, {}
	local ctx = {}

	function ctx.ref(instance)
		local referent = referents[instance]
		if not referent then
			referentCount += 1
			referent = "RBX" .. referentCount
			referents[instance] = referent
		end
		return referent
	end

	local function newReferent()
		referentCount += 1
		return "RBX" .. referentCount
	end

	function ctx.shared(bytes)
		local key = sharedKeys[bytes]
		if not key then
			key = Env.sharedKey(bytes, #sharedList + 1)
			sharedKeys[bytes] = key
			table.insert(sharedList, { key, bytes })
		end
		return key
	end

	local stats = { instances = 0, skippedClasses = {} }
	local scriptClass = {}
	local function isScriptClass(className)
		local result = scriptClass[className]
		if result == nil then
			result = Schema.isA(className, "LuaSourceContainer")
			scriptClass[className] = result
		end
		return result
	end

	-- Instances --------------------------------------------------------------------------
	local function writeProperties(instance, className, isScript, decompileIgnored)
		local entries = plan(className)
		for i = 1, #entries do
			local entry = entries[i]
			local name = entry.name
			if entry.dead or ignoredProperties[name] then
				continue
			end
			if isScript and name == "Source" then
				push(entry.open .. cdata(Scripts.source(instance, decompileIgnored)) .. entry.close)
				continue
			end
			local ok, value = read(instance, entry)
			if not ok or (skipDefaults and isDefault(className, entry, value)) then
				continue
			end
			local xml = entry.encode(value, ctx)
			if xml ~= nil then
				push(entry.open .. xml .. entry.close)
			end
		end
	end

	local function folderItem(instance, name)
		push('<Item class="Folder" referent="' .. ctx.ref(instance) .. '"><Properties><string name="Name">' .. text(name)
			.. "</string></Properties>")
	end

	local function writeInstance(instance, folderize, ignoredDepth, isRoot)
		Util.step()
		local className = instance.ClassName
		local info = Schema.classInfo(className)
		if info.service and not isRoot then
			return -- services only exist at the top of a place
		end
		local mark = rules.decompileIgnored(instance, className)
		local decompileIgnored = ignoredDepth > 0 or mark ~= nil

		if job.isModel and info.service then
			folderItem(instance, instance.Name) -- a service cannot be inserted as a model
		elseif not info.saveable or not info.known then
			if not (folderize or saveNotCreatable) then
				stats.skippedClasses[className] = (stats.skippedClasses[className] or 0) + 1
				return
			end
			folderItem(instance, "[" .. className .. "] " .. instance.Name)
		else
			local itemClass = className
			if unionsAsParts and Schema.isA(className, "PartOperation") then
				itemClass = "Part"
			end
			push('<Item class="' .. itemClass .. '" referent="' .. ctx.ref(instance) .. '"><Properties>')
			writeProperties(instance, itemClass, isScriptClass(itemClass), decompileIgnored)
			push("</Properties>")
		end

		stats.instances += 1
		if stats.instances % 250 == 0 then
			onProgress(stats.instances, writer.size())
		end
		local childDepth = ignoredDepth + (mark == "tree" and 1 or 0)
		for _, child in rules.children(instance) do
			writeInstance(child, folderize, childDepth, false)
		end
		push("</Item>")
	end

	-- Document ---------------------------------------------------------------------------
	push('<roblox version="4">')
	if not job.isModel then
		push('<Meta name="ExplicitAutoJoints">true</Meta>')
	end

	for _, root in job.roots do
		writeInstance(root, false, 0, true)
	end

	if not job.isModel then
		-- ServerStorage never replicates, so it is always written here. Its contents neither
		-- run nor render in Studio, which makes it the safe home for the extras folder.
		push('<Item class="ServerStorage" referent="' .. newReferent()
			.. '"><Properties><string name="Name">ServerStorage</string></Properties>')
		if options.ReadMe or #job.extras > 0 then
			push('<Item class="Folder" referent="' .. newReferent()
				.. '"><Properties><string name="Name">SaveInstance420</string></Properties>')
			if options.ReadMe then
				push('<Item class="ModuleScript" referent="' .. newReferent()
					.. '"><Properties><string name="Name">README</string><ProtectedString name="Source">'
					.. cdata(readme(version)) .. "</ProtectedString></Properties></Item>")
			end
			for _, extra in job.extras do
				push('<Item class="Folder" referent="' .. newReferent() .. '"><Properties><string name="Name">'
					.. text(extra.name) .. "</string></Properties>")
				for _, instance in extra.contents do
					if typeof(instance) == "Instance" then
						writeInstance(instance, extra.folderize, 0, false)
					end
				end
				push("</Item>")
			end
			push("</Item>")
		end
		push("</Item>")
	end

	if #sharedList > 0 then
		push("<SharedStrings>")
		for _, item in sharedList do
			push('<SharedString md5="' .. item[1] .. '">' .. Env.base64encode(item[2]) .. "</SharedString>")
			Util.step()
		end
		push("</SharedStrings>")
	end
	push("</roblox>")

	onProgress(stats.instances, writer.size())
	stats.referents = referentCount
	stats.sharedStrings = #sharedList
	return stats
end

return Serialize
end

__modules["streaming"] = function()
-- Streams in map content before saving (StreamingEnabled games).
-- The client only holds what has streamed to it, so the sweep asks the server for every
-- point of a grid around the character, waits for each region to settle, and keeps
-- streamed content resident until the save finishes. Completeness is never guaranteed:
-- the server decides what to send.
local Env = require("env")
local Log = require("log")
local Util = require("util")

local Streaming = {}

local Players = game:GetService("Players")

local function number(value, fallback, low, high)
	local n = tonumber(value)
	if not n or n ~= n or math.abs(n) == math.huge then
		n = fallback
	end
	return math.clamp(n, low, high)
end

local function validPoint(p)
	return typeof(p) == "Vector3" and p.X == p.X and p.Y == p.Y and p.Z == p.Z
		and math.abs(p.X) ~= math.huge and math.abs(p.Y) ~= math.huge and math.abs(p.Z) ~= math.huge
end

-- Grid of request points (serpentine rows so consecutive requests stay close).
function Streaming.plan(options, player)
	if type(options.StreamingPoints) == "table" then
		local points = {}
		for i, point in options.StreamingPoints do
			if not validPoint(point) then
				return nil, "StreamingPoints entry " .. i .. " is not a valid Vector3"
			end
			points[i] = point
		end
		if #points == 0 then
			return nil, "StreamingPoints is empty"
		end
		return { points = points, spacing = number(options.StreamingRadius, 512, 64, 4096) }
	end
	local spacing = number(options.StreamingRadius, 512, 64, 4096)
	local area = number(options.StreamingAreaSize, 10000, 0, 100000)
	local slices = math.floor(number(options.StreamingSlices, 2, 1, 8))
	local passes = math.floor(number(options.StreamingPasses, 1, 1, 3))
	local center = options.StreamingCenter
	if not validPoint(center) then
		center = Vector3.new(0, 50, 0)
		local character = player and player.Character
		if character then
			local ok, pivot = pcall(character.GetPivot, character)
			if ok then
				center = pivot.Position
			end
		end
	end
	local divisions = math.max(1, math.ceil(area / spacing))
	local width = area == 0 and 1 or divisions + 1
	local total = width * width * slices * passes
	if total > 10000 then
		return nil, "the sweep would need more than 10000 requests; lower StreamingAreaSize or raise StreamingRadius"
	end
	local points = table.create(total)
	for _ = 1, passes do
		for xi = 0, width - 1 do
			for zi = 0, width - 1 do
				local z = xi % 2 == 0 and zi or (width - 1 - zi)
				for yi = 0, slices - 1 do
					table.insert(points, center + Vector3.new(
						area == 0 and 0 or -area / 2 + xi * area / divisions,
						(yi - (slices - 1) / 2) * spacing * 0.8,
						area == 0 and 0 or -area / 2 + z * area / divisions
					))
				end
			end
		end
	end
	return { points = points, spacing = spacing, center = center }
end

-- Counts anchored parts near a point until the count stops changing.
local function waitForRegion(point, radius, maxWait)
	local function count()
		local ok, parts = pcall(workspace.GetPartBoundsInRadius, workspace, point, radius)
		if not ok or not parts then
			return nil
		end
		local anchored = 0
		for _, part in parts do
			if part.Anchored then
				anchored += 1
			end
		end
		return anchored
	end
	local started = os.clock()
	local last, stableSince = count(), os.clock()
	if last == nil then
		return false
	end
	while os.clock() - started < maxWait do
		task.wait(0.5)
		local now = count()
		if now == nil then
			return false
		elseif now ~= last then
			last, stableSince = now, os.clock()
		end
		if os.clock() - started >= 1.5 and os.clock() - stableSince >= 1 then
			return true
		end
	end
	return false
end

-- Runs the sweep. Returns ok, summary, restore() (call restore after the save).
function Streaming.run(options, onProgress)
	local noop = function() end
	if not workspace.StreamingEnabled then
		return true, "StreamingEnabled is off; the whole map is already on the client", noop
	end
	local player = Players.LocalPlayer
	if not player then
		return false, "no LocalPlayer", noop
	end
	if options.SafeMode then
		return false, "streaming needs a connected client; turn SafeMode off", noop
	end
	local plan, reason = Streaming.plan(options, player)
	if not plan then
		return false, reason, noop
	end

	local points, spacing = plan.points, plan.spacing
	local total = #points
	local concurrency = math.floor(number(options.StreamingConcurrency, 4, 1, 8))
	local timeout = number(options.StreamingTimeout, 20, 1, 60)
	local chunkWait = number(options.StreamingChunkWait, 6, 1, 30)
	local maxTime = number(options.StreamingMaxTime, math.ceil(total / concurrency) * (math.min(timeout, 8) + chunkWait) * 1.25, 10, 3600)
	local started = os.clock()
	local deadline = started + maxTime

	-- Keep streamed content resident: Opportunistic stream-out evicts regions behind the sweep.
	local restore = noop
	if Env.gethiddenproperty and Env.sethiddenproperty then
		local ok, previous = pcall(Env.gethiddenproperty, workspace, "StreamOutBehavior")
		if ok and typeof(previous) == "EnumItem" and pcall(Env.sethiddenproperty, workspace, "StreamOutBehavior", Enum.StreamOutBehavior.LowMemory) then
			restore = function()
				pcall(Env.sethiddenproperty, workspace, "StreamOutBehavior", previous)
			end
		end
	end

	Log.info(string.format("streaming: %d requests around %s, %d at a time, up to %s", total,
		tostring(plan.center or "custom points"), concurrency, Util.formatDuration(maxTime)))

	local nextIndex, done, failed, unsettled, active = 0, 0, 0, 0, 0
	local function request(point)
		-- RequestStreamAroundAsync can hang past its own timeout on empty regions, so it runs
		-- on a side thread that is abandoned when the deadline passes.
		local box = { done = false }
		task.spawn(function()
			box.ok, box.err = pcall(player.RequestStreamAroundAsync, player, point, timeout)
			box.done = true
		end)
		local limit = os.clock() + timeout
		while not box.done and os.clock() < limit and os.clock() < deadline do
			task.wait(0.1)
		end
		return box.done and box.ok
	end
	local function worker()
		pcall(function()
			while os.clock() < deadline do
				nextIndex += 1
				local point = points[nextIndex]
				if not point then
					return
				end
				if not request(point) then
					failed += 1
				elseif not waitForRegion(point, spacing, math.min(chunkWait, math.max(0, deadline - os.clock()))) then
					unsettled += 1
				end
				done += 1
			end
		end)
		active -= 1
	end
	for _ = 1, math.min(concurrency, total) do
		active += 1
		task.spawn(worker)
	end
	while active > 0 and os.clock() < deadline do
		local elapsed = os.clock() - started
		onProgress(done, total, done > 0 and (total - done) * elapsed / done or nil)
		task.wait(0.25)
	end

	local settle = number(options.StreamingSettleTime, 5, 0, 60)
	if settle > 0 then
		onProgress(done, total, nil, "letting late regions arrive")
		task.wait(settle)
	end

	local complete = done == total and failed == 0 and unsettled == 0
	local summary = string.format("%d/%d regions requested, %d failed, %d still loading, %s", done, total, failed,
		unsettled, Util.formatDuration(os.clock() - started))
	if done < total then
		summary ..= " (time limit reached; raise StreamingMaxTime for a fuller save)"
	end
	return complete, summary, restore
end

return Streaming
end

__modules["telemetry"] = function()
-- Run statistics for robloxscripts.com (Script Ops). What is sent and how to turn it off is
-- described at the top of the built saveinstance.luau (from src/prelude/telemetry.luau) and in
-- docs/privacy.md. Only counts are reported from here: no place content and no player names.
local Telemetry = {}

local ops

function Telemetry.attach(handle)
	ops = handle
end

local function call(method, ...)
	if ops ~= nil then
		pcall(function(...)
			ops[method](...)
		end, ...)
	end
end

-- Loaded successfully (ok = false with a short reason when it did not).
function Telemetry.ready(ok, reason)
	call("ready", ok, reason)
end

-- Counts one use of a feature. name: lowercase letters, digits and _; value: a short word.
function Telemetry.event(name, value)
	call("event", name, value)
end

function Telemetry.error(err, where)
	call("error", err, where)
end

return Telemetry
end

__modules["ui"] = function()
-- On-screen status panel. Lives in gethui()/CoreGui so it is never part of a save.
local Env = require("env")

local UI = {}

local LINKS = { "[VS] Visionary Studios" }
local ACCENT = Color3.fromRGB(150, 220, 120)

local function label(parent, y, height, size, font, color)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(16, y)
	text.Size = UDim2.new(1, -32, 0, height)
	text.Font = font
	text.TextSize = size
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Text = ""
	text.Parent = parent
	return text
end

function UI.open(version)
	local ok, parts = pcall(function()
		local parent, unprotected = Env.guiParent()
		local gui = Instance.new("ScreenGui")
		gui.Name = game:GetService("HttpService"):GenerateGUID(false)
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 1000000
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		if unprotected and Env.protectgui then
			pcall(Env.protectgui, gui)
		end

		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -48)
		panel.Size = UDim2.fromOffset(460, 100)
		panel.BackgroundColor3 = Color3.fromRGB(17, 19, 24)
		panel.BackgroundTransparency = 0.06
		panel.BorderSizePixel = 0
		panel.Parent = gui
		Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
		local stroke = Instance.new("UIStroke")
		stroke.Color = ACCENT
		stroke.Transparency = 0.65
		stroke.Parent = panel

		local title = label(panel, 10, 18, 15, Enum.Font.GothamBold, ACCENT)
		title.Text = "Austin's Save Instance " .. version
		local link = label(panel, 10, 18, 12, Enum.Font.Gotham, Color3.fromRGB(120, 125, 135))
		link.TextXAlignment = Enum.TextXAlignment.Right
		link.Text = LINKS[1]
		local phase = label(panel, 34, 18, 14, Enum.Font.GothamMedium, Color3.fromRGB(236, 237, 242))
		phase.Text = "Starting..."

		local track = Instance.new("Frame")
		track.Position = UDim2.fromOffset(16, 60)
		track.Size = UDim2.new(1, -32, 0, 6)
		track.BackgroundColor3 = Color3.fromRGB(44, 48, 58)
		track.BorderSizePixel = 0
		track.Parent = panel
		Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = ACCENT
		fill.BorderSizePixel = 0
		fill.Parent = track
		Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

		local detail = label(panel, 72, 16, 12, Enum.Font.Gotham, Color3.fromRGB(165, 170, 180))
		gui.Parent = parent
		return { gui = gui, phase = phase, fill = fill, detail = detail, link = link, title = title }
	end)
	if not ok then
		return nil
	end

	local ui = {}
	local lastUpdate = 0
	local linkIndex = 1
	local lastLink = os.clock()

	-- fraction: 0..1 or nil for an indeterminate phase
	function ui.set(phaseText, fraction, detailText, force)
		local now = os.clock()
		if not force and now - lastUpdate < 0.1 then
			return
		end
		lastUpdate = now
		pcall(function()
			parts.phase.Text = phaseText
			if fraction then
				parts.fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			end
			parts.detail.Text = detailText or ""
			if now - lastLink > 4 then
				lastLink = now
				linkIndex = linkIndex % #LINKS + 1
				parts.link.Text = LINKS[linkIndex]
			end
		end)
	end

	function ui.finish(phaseText, detailText, success)
		pcall(function()
			parts.phase.Text = phaseText
			parts.detail.Text = detailText or ""
			parts.fill.Size = UDim2.fromScale(1, 1)
			parts.fill.BackgroundColor3 = success and ACCENT or Color3.fromRGB(230, 95, 95)
		end)
	end

	function ui.close(delay)
		task.delay(delay or 0, function()
			pcall(parts.gui.Destroy, parts.gui)
		end)
	end

	return ui
end

return UI
end

__modules["util"] = function()
-- Small shared helpers: cooperative yielding and formatting.
local Util = {}

local budget = 0.008
local lastYield = os.clock()

-- How much work (in milliseconds) runs per frame before yielding.
function Util.setYieldBudget(ms)
	budget = math.clamp(tonumber(ms) or 8, 1, 100) / 1000
end

-- Call from every long loop. Yields one frame once this frame's budget is spent, so the
-- client keeps rendering and big games never white-screen during a save.
function Util.step()
	if os.clock() - lastYield >= budget then
		task.wait()
		lastYield = os.clock()
		return true
	end
	return false
end

function Util.yield()
	task.wait()
	lastYield = os.clock()
end

function Util.formatBytes(n)
	if n >= 1073741824 then
		return string.format("%.2f GB", n / 1073741824)
	elseif n >= 1048576 then
		return string.format("%.1f MB", n / 1048576)
	elseif n >= 1024 then
		return string.format("%.1f KB", n / 1024)
	end
	return string.format("%d B", n)
end

function Util.formatDuration(seconds)
	if seconds < 60 then
		return string.format("%.1fs", seconds)
	end
	return string.format("%dm %02ds", math.floor(seconds / 60), math.floor(seconds % 60))
end

function Util.path(instance)
	local ok, name = pcall(instance.GetFullName, instance)
	return ok and name or tostring(instance)
end

-- Makes a name safe to use as a Windows file name.
function Util.fileSafe(name)
	name = string.gsub(tostring(name), '[%c<>:"/\\|%?%*]', "")
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "[%s%.]+$", "")
	if #name > 120 then
		local cut = utf8.offset(name, 121)
		name = string.sub(name, 1, (cut or 121) - 1)
	end
	return name ~= "" and name or "Place"
end

return Util
end

__modules["writer"] = function()
-- Buffered output. Streams to disk with appendfile so memory stays flat on huge games,
-- builds the file in memory when appendfile is missing, or hands chunks to a callback.
local Env = require("env")

local Writer = {}

local FLUSH_BYTES = 4 * 1024 * 1024

function Writer.open(path, callback)
	local parts, count, pending, written = {}, 0, 0, 0
	local mode, memory

	if type(callback) == "function" then
		mode = "callback"
	elseif Env.writefile and Env.appendfile then
		mode = "stream"
		Env.writefile(path, "")
	elseif Env.writefile then
		mode = "memory"
		memory = {}
	else
		error("this executor has no writefile()", 0)
	end

	local function flush()
		if count == 0 then
			return
		end
		local chunk = table.concat(parts, "", 1, count)
		table.clear(parts)
		count, pending = 0, 0
		written += #chunk
		if mode == "stream" then
			Env.appendfile(path, chunk)
		elseif mode == "memory" then
			table.insert(memory, chunk)
		else
			callback(chunk)
		end
	end

	local writer = { mode = mode, path = path }

	function writer.push(s)
		count += 1
		parts[count] = s
		pending += #s
		if pending >= FLUSH_BYTES then
			flush()
		end
	end

	function writer.size()
		return written + pending
	end

	function writer.finish()
		flush()
		if mode == "memory" then
			Env.writefile(path, table.concat(memory))
			memory = nil
		end
		return written
	end

	function writer.abort()
		table.clear(parts)
		count, pending = 0, 0
		memory = nil
		if mode == "stream" and Env.delfile then
			pcall(Env.delfile, path)
		end
	end

	return writer
end

return Writer
end

local __ok, __saveinstance = pcall(function()
	return require("main")(__SSI_VERSION, ops)
end)
if not __ok then
	pcall(function()
		ops.ready(false, "load_error")
		ops.error(__saveinstance, "load")
	end)
	error(__saveinstance, 0)
end
return __saveinstance
