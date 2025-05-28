--!strict
local Hotbar = {
	DEBUG_PRINT = true
}

local UIS = game:GetService("UserInputService")

local IMContainer = require(script.Parent.IMContainer)
local IMUserType = require(script.Parent.IMUserType)
local IMInput = require(script.Parent.IMInput)



type KeyBinding = {
    key: number | string,
	fn: () -> (),
}


local initialized = false
local scrollIndex = -1
local con1: RBXScriptConnection? = nil
local con2: RBXScriptConnection? = nil
local con3: RBXScriptConnection? = nil
local keysBound: { KeyBinding | false } = {}
local digits: { Enum.KeyCode } = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
	Enum.KeyCode.Zero,
}

local MOUSE_ENABLED = IMInput.GetInputType() == IMInput.INPUT_MOUSE


local function matchKey(input: InputObject, key: number | string)
	key = key == 0 and 10 or key
	if typeof(key) == "number" then
		return input.KeyCode == digits[key]
	elseif typeof(key) == "string" then
		return input.KeyCode == (Enum.KeyCode::any)[key]
	end
	
	return false
end

function Hotbar.BindKey(containerIndex: number, key: IMContainer.HotbarKey, callback: () -> ())
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
    if not keysBound[containerIndex] then return end
    
	if Hotbar.DEBUG_PRINT then
		warn("Hotbar key unbound at container index:", containerIndex)
	end
	
	keysBound[containerIndex] = false
end

function Hotbar.Init(hotbarCapacity: number)
	keysBound = table.create(hotbarCapacity, false)::{ KeyBinding | false }
	initialized = true
end

function Hotbar.ConnectKeybinds()
	if not initialized then error("Hotbar module not initialized") end
	if con1 then return end
	
	con1 = UIS.InputBegan:Connect(function(input: InputObject, gpe)
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


local function scrollHotbar(
    data: { IMUserType.USER_ITEM_TYPE | false }, 
    container: IMContainer._Container, 
    scrollDir: number, 
    callback: (item: IMUserType.USER_ITEM_TYPE?, slotIndex: number) -> ()
)
    scrollIndex = (scrollIndex - scrollDir) % container._capacity

    local containerIndex = scrollIndex + 1
    local si = IMContainer.GetSlotIndexFromContainerIndex(container, containerIndex)
    local item = data[si] or nil
    if not item then
        while (containerIndex > 0 and containerIndex < container._capacity) and not item do
            containerIndex -= scrollDir
            scrollIndex -= scrollDir
            si = IMContainer.GetSlotIndexFromContainerIndex(container, containerIndex)
            item = data[si] or nil
            task.wait()
        end
    end
    
    callback(item, si)
end


function Hotbar.ConnectScrollingHotbarEvent(container: IMContainer._Container,
    data: { IMUserType.USER_ITEM_TYPE | false },
    callback: (item: IMUserType.USER_ITEM_TYPE?, slotIndex: number) -> ()
)
    if not MOUSE_ENABLED then return end  
    if not container._hotbarConfigs or not container._hotbarConfigs.ScrollingHotbar then return end  

    if not initialized then error("Hotbar module not initialized") end
	if con2 then return end

    container._PARENT_CONTAINER.Active = true

    --[[ scrollDir:
        -1 = scrolling down
         1 = scrolling up
    ]]
    con2 = container._PARENT_CONTAINER.MouseWheelBackward:Connect(function()  
        scrollHotbar(data, container, -1, callback)
    end)

    con3 = container._PARENT_CONTAINER.MouseWheelForward:Connect(function()  
        scrollHotbar(data, container, 1, callback)
    end)
end

--[[
    The scroll index needs to correspond with the currently equipped item.
    This connection is broken when an item is not equipped with scrolling.
    So, whenever that happens, the scroll index must be "refreshed" to
    match the index of the equipped item.
]]
function Hotbar.RefreshScrollIndex(container: IMContainer._Container, slotIndex: number)
    if not MOUSE_ENABLED then return end
    if not container._hotbarConfigs or not container._hotbarConfigs.ScrollingHotbar then return end  
    
    local containerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)
    scrollIndex = containerIndex - 1
end

function Hotbar.Disconnect()
	if con1 and con1.Connected then
		con1:Disconnect()
		con1 = nil
	end

    if con2 and con2.Connected then
        con2:Disconnect()
        con2 = nil
    end

    if con3 and con3.Connected then
        con3:Disconnect()
        con3 = nil
    end
end


return Hotbar