--!strict
local Hotbar = {
	DEBUG_PRINT = true
}

local UIS = game:GetService("UserInputService")

local con: RBXScriptConnection? = nil



type KeyBinding = {
	key: number | string,
	fn: () -> (),
}

export type HotbarKey = number | string | nil


local initialized = false
local keysBound: { KeyBinding | false } = {}
local digits = {
	"One",
	"Two",
	"Three",
	"Four",
	"Five",
	"Six",
	"Seven",
	"Eight",
	"Nine",
	"Zero"
}



local function matchKey(input: InputObject, key: number | string)
	key = key == 0 and 10 or key
	if typeof(key) == "number" then
		return input.KeyCode == Enum.KeyCode[digits[key]]
	elseif typeof(key) == "string" then
		return input.KeyCode == Enum.KeyCode[key]
	end
	
	return false
end

function Hotbar.BindKey(containerIndex: number, key: HotbarKey, callback: () -> ())
	if Hotbar.DEBUG_PRINT then
		if not keysBound[containerIndex] then
			warn("Hotbar key bound:", key)
		else
			warn("Hotbar key rebound:", key)
		end	
	end
	
	keysBound[containerIndex] = key ~= nil and {
		key = key,
		fn = callback
	} or false::false
end

function Hotbar.UnbindKey(containerIndex: number)
	if Hotbar.DEBUG_PRINT then
		warn("Hotbar key unbound at container index:", containerIndex)
	end
	
	keysBound[containerIndex] = false
end

function Hotbar.Init(hotbarCapacity: number)
	keysBound = table.create(hotbarCapacity, false)::{ KeyBinding | false }
	initialized = true
end

function Hotbar.Connect()
	if not initialized then error("Hotbar module not initialized") end
	if con then return end
	
	con = UIS.InputBegan:Connect(function(input: InputObject, gpe)
		if gpe then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		
		for i = 1, #keysBound do
			if not keysBound[i] then continue end
			if matchKey(input, (keysBound::{KeyBinding})[i].key) then 
				(keysBound::{KeyBinding})[i].fn() 
				break 
			end
		end
	end)
end

function Hotbar.Disconnect()
	if con and con.Connected then
		con:Disconnect()
		con = nil
	end
end


return Hotbar
