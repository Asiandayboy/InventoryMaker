--!strict

local BIT_FLAGS = {
	CLOSED 							= 0b1,
	NO_FILTERING 					= 0b10,
	NO_DRAGGING 					= 0b100,
	NO_STACKING						= 0b1000,
	HOTBAR_UNTOGGLED_HOVER 			= 0b10000,
	HOTBAR_COLLAPSE					= 0b100000,
	HOTBAR_FILL_FIRST				= 0b1000000,
	NO_AUTO_EQUIP					= 0b10000000,
	NO_EQUIPPED_STATE				= 0b100000000
	
}


local IMContainer = {
	FLAGS = BIT_FLAGS
}


local camera = workspace.Camera

local DraggableUI = require(script.Parent.DraggableUI)
local Constants = require(script.Parent.IMConstants)
local UserType = require(script.Parent.IMUserType)
local Utility = require(script.Parent.Utility)
local Hotbar = require(script.Parent.IMHotbar)


type ITEM_TYPE = UserType.USER_ITEM_TYPE 

type GridLayoutParams = {
	CellPadding: UDim2?,
	CellSize: UDim2?,
	FillDirection: Enum.FillDirection?,
	FillDirectionMaxCells: number?,
	StartCorner: Enum.StartCorner?,
	HorizontalAlignment: Enum.HorizontalAlignment?,
	VerticalAlignment: Enum.VerticalAlignment?,
	ParentContainer: GuiObject
}

export type ItemPositionInfo = {
	SlotIndex: number,
	ContainerIndex: number,
	ContainerName: string
}

export type EmptyConfigs = {
	GuiTemplate: GuiObject,
	RenderFunc: (slotIndex: number, emptyGui: GuiObject, containerIndex: number) -> ()
}

export type FilledConfigs = {
	GuiTemplate: GuiObject,
	RenderFunc: (slotIndex: number, item: ITEM_TYPE, filledGui: GuiObject, containerIndex: number) -> ()
}

export type HoverPromptConfigs = {
	GuiTemplate: GuiObject,
	FixedPosition: boolean,
	Offset: Vector2,
	RenderFunc: (item: ITEM_TYPE, hoverPromptGui: GuiObject) -> (),
	ShowPromptAfterDragging: boolean?,
}

export type HotbarKeybinds = { Hotbar.HotbarKey }

export type HotbarConfigs = {
	Keybinds: HotbarKeybinds,
	OnKeyPress: (item: ITEM_TYPE, filledGui: GuiObject, emptyGui: GuiObject, info: ItemPositionInfo) -> ()
}

export type _HoverPromptInfo = {
	_TEMPLATE: GuiObject,
	_OFFSET: UDim2,
	_FIXED_POSITION: boolean,
	_RENDER_FUNC: (item: ITEM_TYPE, gui: GuiObject) -> (),
	_GUI: GuiObject?,
	_INSET: UDim2?,
	_OPEN_HOVER_PROMPT_AFTER_DRAGGING: boolean,
}

export type LeftClickCallback = (slotIndex: number, item: ITEM_TYPE, filledGui: GuiObject) -> ()
export type OnItemAddedCallback = (item: ITEM_TYPE, filledGui: GuiObject, info: ItemPositionInfo) -> ()
export type AllowedItemsCallback = (item: ITEM_TYPE) -> boolean

export type Container = {
	DefineLayout: (self: Container, params: GridLayoutParams) -> Container,
	DefineEmptySlot: (self: Container, configs: EmptyConfigs) -> (),
	DefineFilledSlot: (self: Container, configs: FilledConfigs) -> (),
	DefineHoverPrompt: (self: Container, configs: HoverPromptConfigs) -> (),
	DefineLeftClick: (self: Container, callback: LeftClickCallback) -> (),
	SetHotbarConfigs: (self: Container, hbConfigs: HotbarConfigs) -> (),
	DefineOnItemAddedCallback: (self: Container, callback: OnItemAddedCallback) -> (),
	DefineAllowedItems: (self: Container, callback: AllowedItemsCallback) -> (),
	_setHotbarKeybinds: (self: Container, keybinds: HotbarKeybinds) -> (),
	_isItemAllowed: (self: Container, item: ITEM_TYPE) -> boolean,

	_name: string,
	_capacity: number,
	_currSize: number,
	_draggables: { [GuiObject]: DraggableUI.Draggable? },	-- { [filledGui]: Draggable? }
	_invStartIndex: number,
	_invEndIndex: number,
	_flags: number,
	_slotGuiObjs: { [number]: GuiObject | false },		-- { [containerIndex]: SlotGui | false }
	_dummyFilledGuis: { [number]: GuiObject? },			-- { [containerIndex]: DummyFilledGui | nil }: used for splitting
	_filteringEnabled: boolean,
	_stackingEnabled: boolean,
	_closedContainer: boolean,
	_draggingEnabled: boolean,
	_hoverPromptParent: ScreenGui,
	_hotbarConfigs: HotbarConfigs,
	_inItemspace: boolean,
	
	_PARENT_CONTAINER: GuiObject,
	_GRID_LAYOUT: UIGridLayout,
	_EMPTY_TEMPLATE: GuiObject,
	_FILLED_TEMPLATE: GuiObject,
	_RENDER_EMPTY_FUNC: (slotIndex: number, emptyGui: GuiObject, containerIndex: number) -> (),
	_RENDER_FILLED_FUNC: (slotIndex: number, item: ITEM_TYPE, filledGui: GuiObject, containerIndex: number) -> (),
	_LEFT_CLICK_FUNC: LeftClickCallback,
	_HOVER_INFO: _HoverPromptInfo?,
	
	
	_CALLBACKS: {
		_ON_ITEM_ADDED_FUNC: OnItemAddedCallback,
		_ALLOWED_ITEMS_FUNC: AllowedItemsCallback,
	}
}



local DEFAULT_CELL_PADDING = UDim2.new(0, 10, 0, 16)
local DEFAULT_CELL_SIZE = UDim2.new(0, 60, 0, 60)
local DEFAULT_FILL_DIRECTION = Enum.FillDirection.Horizontal
local DEFAULT_FILL_DIRECTION_MAX_CELLS = 6
local DEFAULT_START_CORNER = Enum.StartCorner.TopLeft
local DEFAULT_H_ALIGN = Enum.HorizontalAlignment.Left
local DEFAULT_V_ALIGN = Enum.VerticalAlignment.Top
local NO_CONTEXT_MENU_MODE = 0







local function getContainerIndexFromInvIndex(container: Container, i: number): number
	return i - container._invStartIndex + 1
end


local function destroyDraggable(props: Container, filledGui: GuiObject)
	local draggable = props._draggables[filledGui]
	if not draggable then return end
	
	DraggableUI.Destroy(draggable)
	props._draggables[filledGui] = nil
end

--[[
	Destroys the slot, which also destroys the filledGui at that slot, if there is one.
	Used when calling AddItemAtIndex() or when container capacity is decreased.
	
	If decreaseCapacity = true, the slotGuiObj at the containerIndex will be set to nil
	in the array; if decreaseCapacity = false, it will be set to false instead.
	
	If it is set to nil, the array must be reconciled with IMContainer.ReconcileSlotGuiObjs()
	
]]
local function destroySlot(props: Container, slotIndex: number, decreaseCapacity: boolean)
	local guiContainer = props._PARENT_CONTAINER:FindFirstChild(Constants.SLOT_NAME_PREFIX..tostring(slotIndex))
	if guiContainer then 
		local filledGui = guiContainer:FindFirstChild(Constants.FILLED_GUI_NAME)
		if filledGui and filledGui:IsA("GuiObject") then
			destroyDraggable(props, filledGui)
			filledGui:Destroy()
			props._currSize -= 1
		end
		guiContainer:Destroy() 
		
		if not decreaseCapacity then
			props._slotGuiObjs[getContainerIndexFromInvIndex(props, slotIndex)] = false
		else
			props._slotGuiObjs[getContainerIndexFromInvIndex(props, slotIndex)] = nil
		end
	end
end

local function destroyFilledGui(props: Container, i: number)
	local guiContainer = props._PARENT_CONTAINER:FindFirstChild(Constants.SLOT_NAME_PREFIX..tostring(i))
	if guiContainer then
		local filledGui = guiContainer:FindFirstChild(Constants.FILLED_GUI_NAME)
		if filledGui and filledGui:IsA("GuiObject")  then 
			destroyDraggable(props, filledGui)
			filledGui:Destroy() 
			props._currSize -= 1
		end
	end
end

local function createEmptySlot(props: Container, i: number, containerIndex: number): GuiObject
	local gui = props._EMPTY_TEMPLATE:Clone()
	if props._RENDER_EMPTY_FUNC then
		props._RENDER_EMPTY_FUNC(i, gui, containerIndex)
	end
	gui:SetAttribute(Constants.SLOT_INDEX_ATTRIBUTE_NAME, i)
	gui.Name = Constants.SLOT_NAME_PREFIX..tostring(i)
	gui.LayoutOrder = i
	gui.Visible = true
	gui.Parent = props._PARENT_CONTAINER
	
	props._slotGuiObjs[containerIndex] = gui

	return gui
end

local function createFilledSlot(props: Container, i: number, item: ITEM_TYPE, containerIndex: number): (GuiObject, GuiObject)
	local slot = createEmptySlot(props, i, containerIndex)

	local filledSlotGui = props._FILLED_TEMPLATE:Clone()
	filledSlotGui.Visible = true
	props._RENDER_FILLED_FUNC(i, item, filledSlotGui, containerIndex)
	filledSlotGui.Name = Constants.FILLED_GUI_NAME
	filledSlotGui.Parent = slot
	
	props._currSize += 1
	
	if props._draggingEnabled then
		props._draggables[filledSlotGui] = DraggableUI.new(filledSlotGui, false)
	end

	return filledSlotGui, slot
end

local function createDummyFilledGui(props: Container, slotIndex: number, item: ITEM_TYPE, containerIndex: number): (GuiObject, GuiObject)
	local dummyGui = props._FILLED_TEMPLATE:Clone()
	dummyGui.Visible = true
	props._RENDER_FILLED_FUNC(slotIndex, item, dummyGui, containerIndex)
	dummyGui.Name = Constants.DUMMY_FILLED_GUI_NAME
	
	local slot = props._slotGuiObjs[containerIndex]::GuiObject
	dummyGui.Parent = slot
	
	return dummyGui, slot
end


function IMContainer.new(name: string, capacity: number, flags: number): Container
	local _props: Container = {
		_name = name,
		_dragging = false,
		_capacity = capacity,
		_currSize = 0,
		_HOVER_INFO = nil,
		_draggables = {},
		_slotGuiObjs = {},
		_dummyFilledGuis = {},
		_flags = flags,
		_inItemspace = false,
		_filteringEnabled = not IMContainer.IsBitFlagEnabled(flags, BIT_FLAGS.NO_FILTERING),
		_closedContainer = IMContainer.IsBitFlagEnabled(flags, BIT_FLAGS.CLOSED),
		_draggingEnabled = not IMContainer.IsBitFlagEnabled(flags, BIT_FLAGS.NO_DRAGGING),
		_stackingEnabled = not IMContainer.IsBitFlagEnabled(flags, BIT_FLAGS.NO_STACKING),
		_CALLBACKS = {
			_ALLOWED_ITEMS_FUNC = function(item: ITEM_TYPE) return true end
		},
		_invStartIndex = 0,
		_invEndIndex = 0,
		

		DefineLayout = function(self: Container, params: GridLayoutParams): Container
			if (params.ParentContainer::GuiObject?) == nil then error("[Inventory]: A parent GUI container must be provided for grid layout.") end
			if not params.ParentContainer:IsA("GuiObject") then error("[Inventory]: The provided parent GUI container must be a GuiObject.") end
			
			local layout = Instance.new("UIGridLayout")
			layout.Name = Constants.GRID_LAYOUT_NAME
			layout.CellPadding = params.CellPadding or DEFAULT_CELL_PADDING
			layout.CellSize = params.CellSize or DEFAULT_CELL_SIZE
			layout.FillDirection = params.FillDirection or DEFAULT_FILL_DIRECTION
			layout.FillDirectionMaxCells = params.FillDirectionMaxCells or DEFAULT_FILL_DIRECTION_MAX_CELLS
			layout.StartCorner = params.StartCorner or DEFAULT_START_CORNER
			layout.HorizontalAlignment = params.HorizontalAlignment or DEFAULT_H_ALIGN
			layout.VerticalAlignment = params.VerticalAlignment or DEFAULT_V_ALIGN
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			
			self._PARENT_CONTAINER = params.ParentContainer
			self._GRID_LAYOUT = layout
			
			return self
		end,
		
		DefineEmptySlot = function(self: Container, configs: EmptyConfigs)
			self._EMPTY_TEMPLATE = configs.GuiTemplate
			self._RENDER_EMPTY_FUNC = configs.RenderFunc
		end,
		
		DefineFilledSlot = function(self: Container, configs: FilledConfigs)
			self._FILLED_TEMPLATE = configs.GuiTemplate
			self._RENDER_FILLED_FUNC = configs.RenderFunc
		end,
		
		--[[
			Takes in a table that define how you want to configure your hover prompt. The GuiTemplate
			defines the hover prompt gui to use for displaying the hover information. The RenderFunc defines
			how you display the item information to the gui. It passes in the item data and the hover prompt gui.
			
			The GuiTmeplate is shared across all items; it's a singleton. So be sure to manage your properties 
			appropriately. For example, if hovering over a rare item changes the color to blue, then you'd probably
			change the color back to normal when hovering over a normal item. 
			
			You can provide just the GuiTemplate and RenderFunc and ignore the other fields if you wish to use 
			the default values. It will default to FixedPosition = false and Offset = UDim2.new(0, 20, 0, 0).
			
			If FixedPosition = true, the hover prompt will be position to the top right corner of the 
			inventory item. The offset will apply relative to the top right corner. If no offset is 
			provided, it will default to UDim2.new(0, 0, 0, 0).
			
			If FixedPosition = false, the hover prompt will follow the mouse as long as it's moving within
			the inventory item. The offset will apply relative to the mouse position.
			
			If ShowPromptAfterDragging is true, the hover prompt, if defined, will immediately appear after
			dragging is done.
		]]
		DefineHoverPrompt = function(self: Container, configs: HoverPromptConfigs)
			local offset: UDim2
			if configs.Offset then
				offset = UDim2.fromOffset(configs.Offset.X, configs.Offset.Y)
			else
				offset = UDim2.fromOffset(0, 0)
			end
			
			self._HOVER_INFO = {
				_TEMPLATE = configs.GuiTemplate,
				_FIXED_POSITION = configs.FixedPosition or false,
				_OFFSET = offset,
				_RENDER_FUNC = configs.RenderFunc,
				_OPEN_HOVER_PROMPT_AFTER_DRAGGING = configs.ShowPromptAfterDragging or false
			}::_HoverPromptInfo
		end,
		
		DefineLeftClick = function(self: Container, callback: LeftClickCallback)
			self._LEFT_CLICK_FUNC = callback
		end,
		
		SetHotbarConfigs = function(self: Container, hbConfigs: HotbarConfigs)
			if self._name ~= Constants.CONTAINER_HOTBAR_NAME then 
				error("[InventoryMaker]: This method can only be called for the hotbar container.")
			end
			if not hbConfigs then error("[InventoryMaker]: Missing hotbar configs for hotbar container.") end
			if not hbConfigs.Keybinds then error("[InventoryMaker]: Missing hotbar keybinds.") end
			if not hbConfigs.OnKeyPress then error("[InventoryMaker]: Missing OnKeyPress callback.") end
			
			self._hotbarConfigs = hbConfigs
		end,
		
		
		DefineOnItemAddedCallback = function(self: Container, callback: OnItemAddedCallback)
			self._CALLBACKS._ON_ITEM_ADDED_FUNC = callback
		end,
		
		DefineAllowedItems = function(self: Container, callback: AllowedItemsCallback)
			self._CALLBACKS._ALLOWED_ITEMS_FUNC = callback
		end,
		
		_setHotbarKeybinds = function(self: Container, keybinds: HotbarKeybinds)
			if self._name ~= Constants.CONTAINER_HOTBAR_NAME then 
				error("[InventoryMaker]: This method can only be called for the hotbar container.")
			end
			
			if not self._hotbarConfigs then error("[InventoryMaker]: Cannot call this method; hotbar configs not defined.") end
			self._hotbarConfigs.Keybinds = keybinds
		end,
		
		_isItemAllowed = function(self: Container, item: ITEM_TYPE): boolean
			return self._CALLBACKS._ALLOWED_ITEMS_FUNC(item)
		end,
		
		
	}::Container	
	
	
	return _props
end


function IMContainer.Init(container: Container, data: { ITEM_TYPE | false }, 
	callback: (filledGui: GuiObject, slot: GuiObject, item: ITEM_TYPE, c: Container, slotIndex: number, containerIndex: number) -> ()
)	
	
	local containerIndex = 1
	for i = container._invStartIndex, container._invEndIndex do
		local item = data[i]
		if item then
			local filledGui, slot = createFilledSlot(container, i, item, containerIndex)
			callback(filledGui, slot, item, container, i, containerIndex)		
		else
			createEmptySlot(container, i, containerIndex)
		end
		containerIndex += 1
	end
	
	container._PARENT_CONTAINER:SetAttribute(Constants.CONTAINER_ATTRIBUTE_NAME, container._name)
	container._GRID_LAYOUT.Parent = container._PARENT_CONTAINER
end


--[[
	Destroys the entire slot at the index (including the filledGui, if there is one), 
	creates a new slot in its place, creates the filledGui in the new slot and runs the callback after.
]]
function IMContainer.AddItemAtIndex(container: Container, slotIndex: number, item: ITEM_TYPE, 
	callback: (newFilledGui: GuiObject, newSlot: GuiObject, itemRef: ITEM_TYPE, containerRef: Container, slotIndex: number, containerIndex: number) -> ()
)
	local containerIndex = getContainerIndexFromInvIndex(container, slotIndex)
	destroySlot(container, slotIndex, false)
	local newFilledGui, newSlot = createFilledSlot(container, slotIndex, item, containerIndex)
	callback(newFilledGui, newSlot, item, container, slotIndex, containerIndex)
	
	local onItemAddedCallback = container._CALLBACKS._ON_ITEM_ADDED_FUNC
	if onItemAddedCallback then
		onItemAddedCallback(item, newFilledGui, {
			SlotIndex = slotIndex,
			ContainerIndex = containerIndex,
			ContainerName = container._name
		})
	end
end

--[[
	Destroys the filled GUI at the slot index and decreases the current size of the container.
	Destroying the filled GUI also destroys its draggable, if any, as well and removes it
	from the dictionary of draggables maintained by the container
]]
function IMContainer.DestroyFilledGui(container: Container, slotIndex: number)
	destroyFilledGui(container, slotIndex)
end

--[[
	Destroy the entire slot at the slotIndex. If there is a filledGui at the
	slot, its draggable will be destroyed.
	
	decreaseCapacity should be true if this function is being used to decrease
	the container's capacity, which will set the slot in _slotGuiObjs to nil,
	instead of false, after it has been destroyed.
	
	If decreaseCapacity is false, then the slot will just be set to false, since
	that means a new slot would be created to take its place.
]]
function IMContainer.DestroySlot(container: Container, slotIndex: number, decreaseCapacity: boolean)
	destroySlot(container, slotIndex, decreaseCapacity)	
end

--[[
	Shifts the indicies of the _slotGuiObjs array so that there are no holes--
	nil values--from when .DestroySlot() was called with `decreaseCapacity` set to true
]]
function IMContainer.ReconcileSlotGuiObjs(container: Container, prevSlotGuiObjsLen: number, nilCount: number)
	local slots = container._slotGuiObjs
	
	local newSlotGuiObjsArr = table.create(prevSlotGuiObjsLen-nilCount, false)::{ [number]: GuiObject | false }
	local index = 1
	for i = 1, prevSlotGuiObjsLen do
		local slot = slots[i]
		if slot == nil then continue end
		newSlotGuiObjsArr[index] = slot
		index += 1
	end
	
	container._slotGuiObjs = newSlotGuiObjsArr
end

--[[
	Creates a dummy filled gui at the slotIndex given the item. A dummy filled gui is not meant to be
	interactable; it is completely visual. Creating a dummy filled gui at the slotIndex requires there
	be an actual filledGui at the slotIndex, aka it must be actual filled slot.
	
	Creating a dummy filled gui DOES NOT:
	- affect container size
	- create a new draggable
]]
function IMContainer.CreateDummyFilledGui(container: Container, slotIndex: number, item: ITEM_TYPE): GuiObject
	local containerIndex = getContainerIndexFromInvIndex(container, slotIndex)
	if not container._slotGuiObjs[containerIndex] then error("No filled gui at that slotIndex") end
	
	local newDummyFilledGui = createDummyFilledGui(container, slotIndex, item, containerIndex)
	container._dummyFilledGuis[containerIndex] = newDummyFilledGui
	
	return newDummyFilledGui
end

--[[
	Destroys the dummy filled gui at the slotIndex that was created with CreateDummyFilledGui()
]]
function IMContainer.DestroyDummyFilledGui(container: Container, slotIndex: number)
	local containerIndex = getContainerIndexFromInvIndex(container, slotIndex)
	local dummyFilledGui = container._dummyFilledGuis[containerIndex]
	if not dummyFilledGui then error("No dummy filled gui at slotIndex") end
	
	dummyFilledGui:Destroy()
	container._dummyFilledGuis[containerIndex] = nil
end


--[[
	Creates x empty slots appended to the container, increases the capacity by x, and 
	updates the container's _invEndIndex to account for the empty slots
]]
function IMContainer.AppendNewEmptySlots(container: Container, amount: number)
	container._capacity += amount
	
	local startIndex = container._invEndIndex+1
	local endIndex = startIndex+amount-1
	container._invEndIndex = endIndex
	
	local containerIndex = getContainerIndexFromInvIndex(container, startIndex)
	for i = startIndex, endIndex do
		local slot = createEmptySlot(container, i, containerIndex)
		containerIndex += 1
	end
end


function IMContainer.GetHoverPromptSingleton(container: Container, screenGui: ScreenGui): GuiObject?
	local hoverInfo = container._HOVER_INFO
	if not hoverInfo then return nil end
	
	local gui = hoverInfo._GUI
	if not gui then
		gui = (hoverInfo._TEMPLATE::GuiObject):Clone()
		hoverInfo._GUI = gui
		hoverInfo._INSET = hoverInfo._FIXED_POSITION and -UDim2.new(0, 0, 0, Utility.GetGuiInsetY(screenGui.IgnoreGuiInset)) or
			UDim2.new(0, 0, 0, Utility.GetGuiInsetY(not screenGui.IgnoreGuiInset))
		gui.Name = Constants.HOVER_NAME_PREFIX..container._name
		gui.Visible = false
		gui.AnchorPoint = Vector2.zero
		gui.ZIndex = 100
		gui.Parent = screenGui
		container._hoverPromptParent = screenGui
	end

	return gui
end

function IMContainer.FixedHoverPrompt(container: Container, prompt: GuiObject, item: ITEM_TYPE, filledGui: GuiObject)
	local hoverInfo = container._HOVER_INFO
	if not hoverInfo then return end
	
	prompt.Visible = true
	if hoverInfo._RENDER_FUNC then
		hoverInfo._RENDER_FUNC(item, prompt)
	end
	
	local pos = filledGui.AbsolutePosition
	local size = filledGui.AbsoluteSize
	
	local promptSize = prompt.AbsoluteSize
	local hoverOffset = hoverInfo._OFFSET
	local rightSideX = pos.X + size.X + promptSize.X + hoverOffset.X.Offset
	
	if rightSideX > camera.ViewportSize.X then -- position hover prompt on the left side instead
		prompt.Position = UDim2.fromOffset(pos.X - promptSize.X, pos.Y) - hoverInfo._INSET::UDim2 + UDim2.fromOffset(-hoverOffset.X.Offset, hoverOffset.Y.Offset)
	else
		prompt.Position = UDim2.fromOffset(pos.X + size.X, pos.Y) + hoverOffset - hoverInfo._INSET::UDim2
	end
	
	local promptPos = prompt.AbsolutePosition
	local somePadding = 5
	local bottomSideY = promptPos.Y + promptSize.Y + Utility.GetGuiInsetY(container._hoverPromptParent.IgnoreGuiInset) + somePadding
	local viewportY = camera.ViewportSize.Y
	
	if bottomSideY > viewportY then
		local offset = bottomSideY - (pos.Y + size.Y) - hoverOffset.Y.Offset
		prompt.Position -= UDim2.new(0, 0, 0, offset)
	end
end

function IMContainer.NonFixedHoverPrompt(container: Container, prompt: GuiObject, item: ITEM_TYPE, filledGui: GuiObject, mouse: Vector2)
	local hoverInfo = container._HOVER_INFO
	if not hoverInfo then return end
	
	if not prompt.Visible then
		prompt.Visible = true::any
		if hoverInfo._RENDER_FUNC then
			hoverInfo._RENDER_FUNC(item, prompt)
		end	
	end
	
	local promptSize = prompt.AbsoluteSize
	local hoverOffset = hoverInfo._OFFSET
	local rightSideX = mouse.X + promptSize.X + hoverOffset.X.Offset
	
	if rightSideX > camera.ViewportSize.X then -- position hover prompt on the left side instead
		prompt.Position = UDim2.fromOffset(mouse.X - promptSize.X, mouse.Y) + UDim2.fromOffset(-hoverOffset.X.Offset, hoverOffset.Y.Offset)
	else
		prompt.Position = UDim2.fromOffset(mouse.X, mouse.Y) + hoverInfo._OFFSET
	end
	
	local promptPos = prompt.AbsolutePosition
	local somePadding = 5
	local bottomSideY = promptPos.Y + promptSize.Y + Utility.GetGuiInsetY(container._hoverPromptParent.IgnoreGuiInset) + somePadding
	local viewportY = camera.ViewportSize.Y

	if bottomSideY > viewportY then
		local offset = promptSize.Y
		prompt.Position -= UDim2.new(0, 0, 0, offset)
	end
end

function IMContainer.HideHoverPrompt(container: Container, prompt: GuiObject?)
	if not prompt then return end
	prompt.Visible = false
end

function IMContainer.GetContainerIndex(container: Container, index: number)
	return getContainerIndexFromInvIndex(container, index)
end

function IMContainer.GetFilledGuiFromIndex(container: Container, slotIndex: number): GuiObject?
	local slotGui = container._slotGuiObjs[getContainerIndexFromInvIndex(container, slotIndex)]
	if not slotGui then return nil end
	return slotGui:FindFirstChild(Constants.FILLED_GUI_NAME)::GuiObject?
end

function IMContainer.IsBitFlagEnabled(containerFlags: number, bitFlag: number): boolean
	return bit32.band(containerFlags, bitFlag) == bitFlag
end

--[[
	Changes the name, layout order, and slot attribute of the slot to match the new slot index of the slot gui.
	
	Rerenders the empty slot.
]]
function IMContainer.UpdateSlotIndexOfSlot(container: Container, oldSlotIndex: number, newSlotIndex: number)
	local containerIndex = getContainerIndexFromInvIndex(container, oldSlotIndex)
	local slot = container._slotGuiObjs[containerIndex]
	if not slot then error("No slot to update") end
	
	container._RENDER_EMPTY_FUNC(newSlotIndex, slot, containerIndex)
	slot:SetAttribute(Constants.SLOT_INDEX_ATTRIBUTE_NAME, newSlotIndex)
	slot.LayoutOrder = newSlotIndex
	slot.Name = Constants.SLOT_NAME_PREFIX..tostring(newSlotIndex)
	
end


return IMContainer
