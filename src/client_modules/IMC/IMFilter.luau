--!strict
local IMFilter = {}



local IMContainer = require(script.Parent.IMContainer)
local IMUserType = require(script.Parent.IMUserType)


export type CustomFilterFunc = (slotIndex: number, item: IMUserType.USER_ITEM_TYPE, containerIndex: number) -> boolean

local function searchFilter(
	container: IMContainer._Container, 
	text: string,
	filterFunc: (text: string, item: any) -> boolean, 
	data: any, 
	startIdx: number, endIdx: number
)
	local slots = container._slotGuiObjs

	for i = startIdx, endIdx do
		local item = data[i]
		local slot = slots[IMContainer.GetContainerIndexFromSlotIndex(container, i)]::GuiObject

		local check = item and filterFunc(text, item) or false
		
		if not check and text ~= "" then 
			slot.Visible = false
		else
			slot.Visible = true
		end
	end
	
end


function IMFilter.ConnectSearchBarEvent(
	containers: { IMContainer._Container }, 
	inputGui: TextBox, textFunc: (text: string) -> string, filterFunc: (text: string, item: any) -> boolean,
	data: any
): RBXScriptConnection
	
	local updating = false
	
	return inputGui:GetPropertyChangedSignal("Text"):Connect(function()
		if updating then return end

		local text = textFunc(inputGui.Text)
		updating = true

		inputGui.Text = text
		
		for i = 1, #containers do
			local container = containers[i]
			if not container._filteringEnabled then continue end
			searchFilter(container::IMContainer._Container, text, filterFunc, data, container._invStartIndex, container._invEndIndex)
		end
		
		task.defer(function()
			updating = false
		end)
	end)
end


function IMFilter.ApplyFilterToContainer(container: IMContainer._Container, filterFunc: CustomFilterFunc, data: any)
	local slots = container._slotGuiObjs
	local startIdx = container._invStartIndex
	local endIdx = container._invEndIndex
	
	for slotIndex = startIdx, endIdx do
		local item = data[slotIndex]::(IMUserType.USER_ITEM_TYPE | false)
		local containerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)
		local slot = slots[containerIndex]::GuiObject
		
		local check = item and filterFunc(slotIndex, item, containerIndex) or false

		if not check then 
			slot.Visible = false
		else
			slot.Visible = true
		end
	end
end

function IMFilter.ClearFilterFromContainer(container: IMContainer._Container)
	local slots = container._slotGuiObjs
	
	for i = 1, #slots do
		local slot = slots[i]
		if slot ~= false and slot.Visible == false then
			slot.Visible = true
		end
	end
end


return IMFilter