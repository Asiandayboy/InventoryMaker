--!strict
--!nolint LocalShadow
--!nolint SameLineStatement


--[[ InventoryMaker
	
	Created by: robloxdestroyer1035
	Version: v1.3.1
	Last Updated: 12/18/25
	
	-----------------------------------------------------------------------------
	InventoryMakerClient (IMC)
	-----------------------------------------------------------------------------
    v1.3.1 Update Log (12/18/25)
		- [Changed][Breaking Change]: IMC.Raw() changed to IMC.Items(), which now returns the actual reference to
				the items instead of a copy. This is so it's the same as IMS's Inventory:Items(). Plus, 
				IMC.Raw() returning a copy of the items was just pointless and unnecessary, I think, so...
        - [Changed][Breaking Change]: Correct spelling for what was supposed to be .Initialize() (l0l)
		- [Fix]: Context menu doesnt block input of the item underneath it. (Fixed by putting context 
				menus in their own ScreenGuis)
		- [Fix]: Fixed positioning mistake for hover prompt when out of screen bounds
			- When out of bounds, the hover prompt will just clamp to the top of the screen, right at the 
				guiInset if the first constrain doesn't work.

    v1.3.0 Update Log (9/29/25)
        - [New Feature]: Static Containers; used to render and interact with static inventories. I made
            this primarily to easily render merchant NPCs' inventories that you can sell to and buy from.
            New Methods:
                - IMC.StaticContainer()
                    - StaticContainer:DefineLayout()
                    - StaticContainer:DefineEmptySlot()
                    - StaticContainer:DefineFilledSlot()
                    - StaticContainer:DefineActivatedCallback()
                    - StaticContainer:DefineHoverPrompt()
                    - StaticContainer:DefineOpen()
                    - StaticContainer:DefineClose()
                    - StaticContainer:Open()
                    - StaticContainer:Close()
                    - StaticContainer:RerenderItem()
                - IMC.BuildStaticContainer()
                - IMC.DestroyStaticContainer()
        - [New Method]: IMC.AddItemAtIndex()
        - [New Method]: IMC.SetEquippedItem()
        - [Changed]: You can now return a cleanup function for your hover prompt render funcs, which
            get called when the hover prompt is closed.
        - [Changed]: OnToggledCallback accepts varargs, passed through IMC.ToggleInventory(), 
            IMC.ToggleOn(), and IMC.ToggleOff()
        - [Changed]: IMC.GetItem() now also returns the slotGui and filledGui
        - [Changed]: Made IMS remote callbacks optional
        - [Changed]: Exported Container type; not really sure why I didn't do this already...
        - [Changed]: Exported DATA type, which represents the type of the underlying inventory data array
        - [Changed]: HoverPrompt Render now passes in ItemPositionInfo
        - [Fix]: Fixed some typechecking errors
        - [Fix]: Fix Itemspace bug during Build()
        - [Fix]: Fix leftover stacked item not going into the correct empty slot
        - [Fix]: Fix incorrect argument passed into IncreaseCapacity and DecreaseCapacity 
        - [Fix]: Fix Build() bug with tracking containers' and inventory sizes
        - [Fix]: Fix bug on AddItem when HotbarFillFirst flag is enabled
        - [Fix]: Fix bug when populating inventory with data; wrote in comments to enforce contiguous array
        - [Fix]: Fix bug stackOnAdd = false and HOTBAR_FILL_FIRST is enabled resulting in max iterations error
        - [Fix]: Fix mouse position with gui inset calculation for splitting
        - [Fix]: Fix keybinds referencing stale data when container capacity increases/decreases

    v1.2.1 Update Log (6/8/25)
        - [Bug Fix]: Old gui objects was used when equipping a new item after switching across containers, resulting in a nil error
        - [Bug Fix]: Non-fixed hover prompt not considering GuiInset
        - [Bug Fix]: Static context menu overflow check not considering GuiInset
        - [Changed]: Added another cleanup function to DefineRenderEquippedSlot, used to cleanup UI effects bound to the slotGui
            when the equipped item is moved to a different container
        - [Changed] Removed unnecessary warn statement

    v1.2.0 Update Log (5/29/25)
        - [Bug Fix]: OnSizeChanged callback not called when stacking with 0 leftovers
        - [New Feature]: Sorting
            - [New Method]: IMC.DefineCustomSorters()
            - [New Method]: IMC.Sort()
            - [New Flag]: IMC.NO_SORTING - disables sorting in the container
        - [New Feature]: (PC only) - scrolling hotbar: you can select hotbar items by scrolling with mouse wheel 
            - This feature can be toggled through :SetHotbarConfigs(), by setting ScrollingHotbar = true 
        - [New Methods]: IMC.ToggleOn() - toggles the inventory on; added for convenience
        - [New Method]: IMC.ToggleOff() - toggles the inventory off; added for convenience
        - [New Method]: IMC.DefineOnToggledCallback()
            - removed callback argument from IMC.ToggleInventory() in favor of this new method
        - [New Feature]: Inventory toggles off and prevents further toggling when character is dead.
        - [Changed]: .AddItem() now automatically creates a new item, when stackOnAdd = true, if a stack cannot be found 
        - [New Method]: IMC.DefineRenderEquippedSlots()
            - [New Method]: Container:DefineRenderEquippedSlot()
            - removed IMC.DefineRenderEquippedSlot() since it did not account for containers
		
	-----------------------------------------------------------------------------
	TODO-[KNOWN-BUGS]:	

	-----------------------------------------------------------------------------
	TODO-[FEATURES-TO-BE-ADDED]
	
	-----------------------------------------------------------------------------
	TODO-[POSSIBLE-FEATURES-TO-BE-ADDED]
	- Console support (Help is gladly accepted :D)
	
	-----------------------------------------------------------------------------
	MIT License

	Copyright (c) 2025 robloxdestroyer2035

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
	
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local camera = (workspace::{ Camera: Camera }).Camera
local player = Players.LocalPlayer::Player


local IMInput = require(script.IMInput)
local IMContainer = require(script.IMContainer)
local IMConstants = require(script.IMConstants)
local IMFilter = require(script.IMFilter)
local IMUserType = require(script.IMUserType)
local IMHotbar = require(script.IMHotbar)
local IMDraggableUI = require(script.IMDraggableUI)
local IMUtility = require(script.IMUtility)
local IMStaticContainer = require(script.IMStaticContainer)

local SWITCH_NONE = 0
local SWITCH_ITEM = 1
local SWITCH_CONTAINER = 2
local SWITCH_REJECTED = 3
local NO_CONTEXT_MENU_MODE = 0
local SINGLE_CONTEXT_MENU_MODE = 1
local MULTI_CONTEXT_MENU_MODE = 2
local HOVERED_BOUNDING_BOX_BOUNDING_GUI_PADDING = 5
local HOVERED_BOUNDING_BOX_SIDE_PADDING = 15


local InventoryMaker = {
	DEBUG_PRINT_MESSAGES                = false,
	DEBUG_SHOW_BOUNDING_BOXES           = false,
	DEBUG_PRINT_KEYBIND_MESSAGES        = false,

    --[[
        Set to true to use the IMS functions
    ]]
	USING_IMS                           = false,
	
    --[[
        **Mobile only**

        The maximum time, in seconds, between touch tap inputs to register a double-tap.
        This is for mobile only, and is used to equip and activate slots.
    ]]
	DOUBLE_TAP_THRESHOLD_S              = .25,

    --[[
        Context menus are opened as static context menus
    ]]
    SINGLE_CONTEXT_MENU_MODE            = SINGLE_CONTEXT_MENU_MODE,

    --[[
        **PC only**

        Context menus are opened as hovered context menus (except for root menu) 
    ]]
    MULTI_CONTEXT_MENU_MODE             = MULTI_CONTEXT_MENU_MODE,

    --[[
        **IMC only**

        Disables filtering in the container, which prevents it from being
        affected by the search bar and custom filters
    ]]
    NO_FILTERING                        = IMContainer.FLAGS.NO_FILTERING,

    --[[
        **IMC only**

        Disables dragging in the container, which therefore disables
        stacking and splitting, since you need to be able to drag to do that
    ]]
    NO_DRAGGING                         = IMContainer.FLAGS.NO_DRAGGING,

    --[[
        **IMC only**

        Allows hover prompts for the hotbar to be shown when inventory is
        toggled off
    ]]
    HOTBAR_UNTOGGLED_HOVER              = IMContainer.FLAGS.HOTBAR_UNTOGGLED_HOVER,

    --[[
        **IMC only**

        Empty hotbar slots are hidden when the inventory is toggled off
    ]]
    HOTBAR_COLLAPSE                     =  IMContainer.FLAGS.HOTBAR_COLLAPSE,

    --[[
        Prevents the container from interacting with other containers
    ]]
    CLOSED                              = IMContainer.FLAGS.CLOSED,

    --[[
        Disables stacking in the container
    ]]
    NO_STACKING                         = IMContainer.FLAGS.NO_STACKING,

    --[[
        Forces the hotbar container to prioritize filling its slots
    ]]
    HOTBAR_FILL_FIRST                   = IMContainer.FLAGS.HOTBAR_FILL_FIRST,

    --[[
        Prevents new items added to the contianer from being auto-equipped
    ]]
    NO_AUTO_EQUIP                       = IMContainer.FLAGS.NO_AUTO_EQUIP,

    --[[
        Disables the equipped state in the container
    ]]
    NO_EQUIPPED_STATE                   = IMContainer.FLAGS.NO_EQUIPPED_STATE,

    --[[
        Disables sorting in the container
    ]]
    NO_SORTING                          = IMContainer.FLAGS.NO_SORTING,
}

IMHotbar.DEBUG_PRINT = InventoryMaker.DEBUG_PRINT_KEYBIND_MESSAGES

export type Container = IMContainer.Container
export type StaticContainer = IMStaticContainer.StaticContainer
export type ItemPositionInfo = IMContainer.ItemPositionInfo
export type ITEM_TYPE = IMUserType.USER_ITEM_TYPE
export type DATA = { ITEM_TYPE | false }

type _StaticContainer = IMStaticContainer._StaticContainer


type _ActiveSlot = {
	_item: ITEM_TYPE,
	_filledGui: GuiObject,
	_draggable: IMDraggableUI.Draggable?
}

type _EquippedItem = {
	_item: ITEM_TYPE,
	_filledGui: GuiObject,
	_cleanupFn: IMContainer.EquippedRenderCleanupFunc,
    _cleanupOldGuiFn: IMContainer.EquippedOldGuiRenderCleanupFunc?
}

type _ContextMenuInfo = {
	_TEMPLATE: GuiObject,
	_OFFSET: Vector2,
	_RENDER_FUNC: (slotIndex: number, item: ITEM_TYPE, contextMenuGui: GuiObject, filledGui: GuiObject, containerName: string) -> () -> (),
	_GUI: GuiObject
}

type _OpenedContextMenu = {
	_opened: boolean,
	_cleanupFunc: ((unrenderOnly: boolean) -> ())?,	-- if unrenderOnly is true, bounding boxes will not be cleared. This is for single-context, to avoid calculating it again.	
}

type _BoundingBox = { number }

export type SearchBarConfigs = { 
	SearchBarInputGui: TextBox, 
	TransformTextFunc: (text: string) -> string,
	FilterFunc: (text: string, item: ITEM_TYPE) -> boolean,
}

export type SwitchValidateFunc = (
	item1: ITEM_TYPE, item2: ITEM_TYPE?, 
	item1Info: ItemPositionInfo, item2Info: ItemPositionInfo
) -> boolean

export type StackingValidateFunc = (targetItem: ITEM_TYPE, currItem: ITEM_TYPE) -> (boolean, number)
export type StackingUpdateFunc = (leftover: number, targetItem: ITEM_TYPE, currItem: ITEM_TYPE, targetFilledGui: GuiObject, currFilledGui: GuiObject?) -> ()
export type SplittingValidateFunc = (currItem: ITEM_TYPE) -> boolean
export type SplittingUpdateFunc = (currItem: ITEM_TYPE, newItem: ITEM_TYPE, currFilledGui: GuiObject) -> (ITEM_TYPE, () -> ())

type _StackingConfigs = {
	_STACK_VALIDATE: StackingValidateFunc,
	_STACK_UPDATE: StackingUpdateFunc,
	
	_SPLIT_VALIDATE: SplittingValidateFunc,
	_SPLIT_UPDATE: SplittingUpdateFunc,
}

export type OnToggledCallback = (toggled: boolean, ...any) -> ()
export type OnDraggedOutCallback = (guisAtPosition: { GuiObject }, item: ITEM_TYPE, info: ItemPositionInfo) -> ()
export type OnSizeChangedCallback = (size: number, capacity: number) -> ()
export type Sorter = (itemA: ITEM_TYPE, itemB: ITEM_TYPE, ...any) -> boolean

type _InventoryMakerProps = {
	_containers: { [string]: IMContainer._Container },	-- dict for containers
	_containersIndex: { string },						-- stores the order in which each container was built 
	_data: DATA?,
	_capacity: number,
	_currSize: number,
	_toggled: boolean,
	_equippedItem: _EquippedItem?,
	_activeSlot: _ActiveSlot?,				-- refers to the filled slot that is currently being interacted with
	_dragging: boolean,						-- used to prevent hover prompts from showing when dragging an item
	_scrollCon: RBXScriptConnection?,		-- used to close all context menus and hover prompts on scroll
	_searchBarCon: RBXScriptConnection?,
	_splittingCon: RBXScriptConnection?,

	_CONTEXT_MENU_MODE: number,
	_USER_CONTEXT_MENUS: { _ContextMenuInfo },
	_contextMenusOpened: { _OpenedContextMenu },	-- the first index is reserved as a global value that refers to whether or not any context menu is opened
	_contextMenusStack: { number }, -- stores the menu index for each stack
	_SHOW_HOVER_PROMPT_NEXT_TO_MENU: boolean,
	_PARENT_CONTAINER_SCREEN_GUI: ScreenGui,
	_SEARCH_BAR_CONFIGS: SearchBarConfigs?,
	
	_boundingBoxes: { { _BoundingBox } }, -- stores all active bounding boxes; each is an array of 4 numbers: {topLeftX, topLeftY, botRightX, botRightY}; only 4 points to make a 2d rectangle
	_onFirstHoveredMenu: () -> () -> (),
	
	_STACKING_CONFIGS: _StackingConfigs?,
	_CUSTOM_FILTERS: { [string]: IMFilter.CustomFilterFunc },
	_SWITCH_VALIDATE_FUNC: SwitchValidateFunc,
	
	_CUSTOM_SORTERS: { [string]: Sorter },

	_CALLBACKS: {
		_ON_DRAGGED_OUT: OnDraggedOutCallback,
		_ON_SIZE_CHANGED: OnSizeChangedCallback,
        _ON_TOGGLED: OnToggledCallback,
	}
}

export type RemoteCallbacks = {
	OnSwitch: ((slotIndex1: number, slotIndex2: number) -> ())?,
	OnStack: ((targetSlotIndex: number, currSlotIndex: number) -> ())?,
	OnSplit: ((newSlotIndex: number, splitSlotIndex: number) -> ())?,
	OnEquip: ((slotIndex: number?) -> ())?,
    OnSort: ((sorterName: string, ...any) -> ())?,
}



local _inventoryMakerProps: _InventoryMakerProps
local charDead = false
local initialized = false

local IMS: { _CALLBACKS: RemoteCallbacks? } = {
	_CALLBACKS = nil::RemoteCallbacks?
}



local function debugPrint(msg: string, ...: any)
	if InventoryMaker.DEBUG_PRINT_MESSAGES then
		print("[InventoryMaker]:", msg, ...)
	end
end

local function debugWarn(msg: string, ...: any)
	if InventoryMaker.DEBUG_PRINT_MESSAGES then
		warn("[InventoryMaker]:", msg, ...)
	end
end

--[[
	An active item is the item that is currently being interacted with.
	(Dragging, Hovering, Context Menus opened for that item)
]]
local function setActiveSlot(props: _InventoryMakerProps, item: ITEM_TYPE?, filledGui: GuiObject?, draggable: IMDraggableUI.Draggable?)
	if not item then props._activeSlot = nil return end
	if not filledGui then error("forgot filledgui") return end
	if props._activeSlot and item == props._activeSlot._item and props._activeSlot._filledGui == filledGui then return end
	
	local slot: _ActiveSlot = {
		_item = item,
		_filledGui = filledGui,
		_draggable = draggable
	}
	
	(props::_InventoryMakerProps)._activeSlot = slot
end

local function isItemActiveSlot(props: _InventoryMakerProps, item): boolean
	if not props._activeSlot then return false end
	return props._activeSlot._item == item
end

local function getSlotIndexFromSlot(slotContainer: GuiObject): number?
	return slotContainer:GetAttribute(IMConstants.SLOT_INDEX_ATTRIBUTE_NAME)::number?
end

--[[
    This is guaranteed to return the corresponding item of the filledGui
    FilledGuis are parented under the slot, which is marked with a slotIndex
    attribute, which can be used to index into the _data array to get the item
]]
local function getItemFromFilledGui(filledGui: GuiObject): ITEM_TYPE
    local slot = filledGui.Parent::GuiObject
    local si = getSlotIndexFromSlot(slot)::number
    return (_inventoryMakerProps._data::DATA)[si]::ITEM_TYPE
end

local function getContainerFromSlotIndex(slotIndex: number, props: _InventoryMakerProps): IMContainer._Container?
	local cIndicies = props._containersIndex
	for i = 1, #cIndicies do
        local containerName = cIndicies[i]
		local container = props._containers[containerName]
		if not (slotIndex >= container._invStartIndex and slotIndex <= container._invEndIndex) then continue end
		return container
	end
	
	return nil
end

local function getContainerNameFromSlot(slotContainer: GuiObject): string
	local slot = slotContainer.Parent::GuiObject
	return slot:GetAttribute(IMConstants.CONTAINER_ATTRIBUTE_NAME)::string
end

local function getContainerNameFromFilledGui(filledGui: GuiObject): string
	local slot = filledGui.Parent::GuiObject
	local container = slot.Parent::GuiObject
	
	return container:GetAttribute(IMConstants.CONTAINER_ATTRIBUTE_NAME)::string
end

-- This must be called before the filledGui is destroyed
local function removeEquippedItem(props: _InventoryMakerProps, item: ITEM_TYPE, 
    targetContainer: IMContainer._Container, slotIndex: number
)
	local equippedItem = props._equippedItem
	if equippedItem and equippedItem._item == item then
        local info: ItemPositionInfo = {
            SlotIndex = slotIndex,
            ContainerIndex = IMContainer.GetContainerIndexFromSlotIndex(targetContainer, slotIndex),
            ContainerName = targetContainer._name
        }
        local emptyGui = equippedItem._filledGui.Parent::GuiObject
		equippedItem._cleanupFn(equippedItem._item, equippedItem._filledGui, emptyGui, info)
		props._equippedItem = nil

        IMHotbar.RefreshScrollIndex(targetContainer, slotIndex)
	end
end

local function setEquippedItem(props: _InventoryMakerProps, 
    item: ITEM_TYPE?, 
    filledGui: GuiObject?, 
    container: IMContainer._Container, 
    stacked: boolean,
    scrollingInput: boolean
)
	if IMContainer.IsBitFlagEnabled(container._flags, InventoryMaker.NO_EQUIPPED_STATE) then return end
	
	local equippedItem = props._equippedItem
	if equippedItem and equippedItem._cleanupFn then
        local emptyGui = equippedItem._filledGui.Parent::GuiObject
		local slotIndex = getSlotIndexFromSlot(emptyGui)::number
        local cIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)
        local info: ItemPositionInfo = {
			SlotIndex = slotIndex,
			ContainerIndex = cIndex,
			ContainerName = container._name
		}
		equippedItem._cleanupFn(equippedItem._item, equippedItem._filledGui, emptyGui, info)
	end
	if item and (if equippedItem then equippedItem._item ~= item else item) or (item and stacked) then
		local emptyGui = (filledGui::GuiObject).Parent::GuiObject
		local slotIndex = getSlotIndexFromSlot(emptyGui)::number
		local cIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)
		local info: ItemPositionInfo = {
			SlotIndex = slotIndex,
			ContainerIndex = cIndex,
			ContainerName = container._name
		}

        local newCleanupFn, cleanupOldGuiFn = container._CALLBACKS._EQUIPPED_RENDER_FUNC(item, filledGui::GuiObject, emptyGui, info)
		
		props._equippedItem = {
			_item = item,
			_filledGui = filledGui::GuiObject,
			_cleanupFn = newCleanupFn,
            _cleanupOldGuiFn = cleanupOldGuiFn
		}
		
		if IMS._CALLBACKS then 
            local onEquip = IMS._CALLBACKS.OnEquip
            if onEquip then onEquip(slotIndex) end
        end

        if not scrollingInput then
            IMHotbar.RefreshScrollIndex(container, slotIndex)
        end
	else
		props._equippedItem = nil -- unequipping the same equipped item
		if IMS._CALLBACKS then 
            local onEquip = IMS._CALLBACKS.OnEquip
            if onEquip then onEquip(nil) end
        end
	end
end

--[[
	This function does nothing if there is no equipped item atm
	An equipped item must be refreshed when:
		- it is moved to another container
		- it is split
		- it is merged with another stack
		
	When this happens, the old filled gui is destroyed
]]
local function refreshEquippedItem(props: _InventoryMakerProps, item: ITEM_TYPE, newFilledGui: GuiObject, slotGui: GuiObject, forceSet: boolean?)
	local container = props._containers[getContainerNameFromSlot(slotGui)]
	local equippedItem = props._equippedItem
	if not equippedItem then return end
	
	if IMContainer.IsBitFlagEnabled(container._flags, InventoryMaker.NO_EQUIPPED_STATE) then 
		if equippedItem._item ~= item then return end
		
		-- unequip the equipped item if it gets moved into a container with NO_EQUIPPED_STATE flag enabled
        local slotIndex = getSlotIndexFromSlot(slotGui)::number
        local info: ItemPositionInfo = {
            SlotIndex = slotIndex,
            ContainerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)::number,
            ContainerName = container._name
        }
		equippedItem._cleanupFn(equippedItem._item, newFilledGui, slotGui, info)
		props._equippedItem = nil
		if IMS._CALLBACKS then 
            local onEquip = IMS._CALLBACKS.OnEquip
            if onEquip then onEquip(nil) end
        end
		debugWarn("Item unequipped; item was moved into a container with NO_EQUIPPED_STATE flag enabled.")
		return	
	end
	
	if equippedItem._item == item or forceSet then
		local slotIndex = getSlotIndexFromSlot(newFilledGui.Parent::GuiObject)::number
		local containerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)
		if forceSet then 
			equippedItem._item = item 
			if IMS._CALLBACKS then 
                local onEquip = IMS._CALLBACKS.OnEquip
                if onEquip then onEquip(slotIndex) end
            end
		end
		equippedItem._filledGui = newFilledGui
		local info: ItemPositionInfo = {
            SlotIndex = slotIndex,
			ContainerIndex = containerIndex,
			ContainerName = container._name
		}
		equippedItem._cleanupFn = container._CALLBACKS._EQUIPPED_RENDER_FUNC(item, newFilledGui, slotGui, info)
	end
end

--[[
    Used to cleanup any equipped UI effects that are done to the slotGui itself.
]]
local function cleanupEquippedOldSlotGui(props: _InventoryMakerProps, container: IMContainer._Container, item: ITEM_TYPE, slotGui: GuiObject)
    local equippedItem = props._equippedItem
    if not equippedItem then return end
    if equippedItem._item ~= item then return end

    local fn = equippedItem._cleanupOldGuiFn
    if not fn then return end

    local slotIndex = getSlotIndexFromSlot(slotGui)::number
    local info: ItemPositionInfo = {
        SlotIndex = slotIndex,
        ContainerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex),
        ContainerName = container._name
    }
    fn(item, slotGui, info)
end

local function areContextMenusOpened(menusOpened: { _OpenedContextMenu }): boolean
	if not menusOpened then return false end
	return menusOpened[1]._opened
end

local function toggleHotbarCollapse(data: DATA, container: IMContainer._Container, show: boolean)
	if container._name ~= IMConstants.CONTAINER_HOTBAR_NAME then return end
	if not IMContainer.IsBitFlagEnabled(container._flags, InventoryMaker.HOTBAR_COLLAPSE) then return end
	if container._currSize == container._capacity then return end
	
	local slots = container._slotGuiObjs
	for i = 1, #slots do
		local slot = slots[i]::GuiObject?
		if not slot then continue end
		local slotIndex = getSlotIndexFromSlot(slot)::number
		if not data[slotIndex] then
			slot.Visible = show
		end
	end
end

local function unbindHotbarKey(container: IMContainer._Container, slotIndex: number)
	if container._hotbarConfigs then
		IMHotbar.UnbindKey(IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex))
	end
end

local function bindHotbarKey(container: IMContainer._Container, data: DATA, 
    slotIndex: number, 
    containerIndex: number
)
	local hbConfigs = container._hotbarConfigs
	if not hbConfigs then debugWarn("No hotbar configs to bind keys to hotbar.") return end
	
	IMHotbar.BindKey(containerIndex, hbConfigs.Keybinds[containerIndex], function()
		local item = data[slotIndex]
		if item then
            -- if the item exists, then it has a filledGui, and therefore a slot
            local filledGui = IMContainer.GetFilledGuiFromIndex(container, slotIndex)::GuiObject
            local slotGui = filledGui.Parent::GuiObject
			local info: ItemPositionInfo = {
				SlotIndex = slotIndex,
				ContainerIndex = containerIndex,
				ContainerName = container._name
			}
			hbConfigs.OnKeyPress(item, filledGui, slotGui, info)
		end
	end)
end

local function stackOnDrag(props: _InventoryMakerProps, 
	targetItem: ITEM_TYPE, oldItem: ITEM_TYPE, 
	targetSlot: GuiObject, oldFilledGui: GuiObject, leftover: number
)	
	if not props._data then error("[InventoryMaker]: No data was detected when trying to stack on drag") end
	if targetItem == oldItem then error("[InventoryMaker]: Items are the same ref when stacking.") end
	
	local configs = props._STACKING_CONFIGS
    if not configs then return end
    
    local targetFilledGui = targetSlot:FindFirstChild(IMConstants.FILLED_GUI_NAME)::GuiObject
	local targetSlotIndex = getSlotIndexFromSlot(targetSlot)::number
	local currSlotIndex = getSlotIndexFromSlot(oldFilledGui.Parent::GuiObject)::number
	
	if leftover <= 0 then
		local originContainer = props._containers[getContainerNameFromFilledGui(oldFilledGui)]

		IMContainer.DestroyFilledGui(originContainer, currSlotIndex)
		props._data[currSlotIndex] = false
		props._currSize -= 1
		configs._STACK_UPDATE(leftover, targetItem, oldItem, targetFilledGui, nil)
		
		if IMS._CALLBACKS then
            local onStack = IMS._CALLBACKS.OnStack
            if onStack then onStack(targetSlotIndex, currSlotIndex) end
		end
		
		if props._equippedItem then
			if props._equippedItem._item == oldItem then
				-- moving the equipped item into a bigger stack
				-- bc of this, we have to force the refresh, even tho the equipped item is not equal to targetItem
				-- but it technically will be, since oldItem will be merged with targetItem after this stackOnDrag operation
				refreshEquippedItem(props, targetItem, targetFilledGui, targetSlot, true)
			end
		end
		
		if originContainer._name == IMConstants.CONTAINER_HOTBAR_NAME then
			unbindHotbarKey(originContainer, currSlotIndex)
		end

        local sizeChangedCallback = props._CALLBACKS._ON_SIZE_CHANGED
        if sizeChangedCallback then
            sizeChangedCallback(props._currSize, props._capacity)
        end
		
		debugPrint(string.format("New inventory size after stacking: %d\n\tleftover=%d", props._currSize, 0))	
	else
		configs._STACK_UPDATE(leftover, targetItem, oldItem, targetFilledGui, oldFilledGui)
		
		if IMS._CALLBACKS then
            local onStack = IMS._CALLBACKS.OnStack
            if onStack then onStack(targetSlotIndex, currSlotIndex) end
		end
		
		refreshEquippedItem(props, targetItem, targetFilledGui, targetSlot)
		
		debugPrint(string.format("New inventory size after stacking: %d\n\tleftover=%d", props._currSize, leftover))	
	end
end

--[[ 
	switches the filled guis in the slots instead of the slot containers, which is more consistent 
	bc it preserves the ordering of the slots.
	
	If a filled gui switches container, it will be destroyed and a new filled gui will be created and rendered
	for that container based on the container tmeplate and render func. The callback will be run, in this case.
]]
local function switch(props: _InventoryMakerProps, filledGui1: GuiObject, slot2: GuiObject, 
	callback: (
		props: _InventoryMakerProps, 
		filledGui: GuiObject, slot: GuiObject, 
		item: ITEM_TYPE, container: IMContainer._Container, 
		focusedItemFlag: boolean
	) -> ()
): number
	if props._data == nil then error("No inventory data to switch.") end
	if not props._toggled then return SWITCH_NONE end

	local aIndex = getSlotIndexFromSlot(filledGui1.Parent::GuiObject)::number
	local bIndex = getSlotIndexFromSlot(slot2)::number
	local filledGui2 = slot2:FindFirstChild(IMConstants.FILLED_GUI_NAME)::GuiObject?
	local slot1 = filledGui1.Parent::GuiObject
	
	local container1 = props._containers[getContainerNameFromFilledGui(filledGui1)]
	local container2 = props._containers[getContainerNameFromSlot(slot2)]
	
	if container1 ~= container2 and (container1._closedContainer or container2._closedContainer) then 
        return SWITCH_REJECTED 
    end

	local item1 = props._data[aIndex]
	local item2 = props._data[bIndex]
	
	if item1 == false then return SWITCH_NONE end
	
	local item1AllowedInC2 = (container2::IMContainer._Container):_isItemAllowed(item1)
	local item2AllowedInC1 = if item2 then (container1::IMContainer._Container):_isItemAllowed(item2) else true
	if not item1AllowedInC2 then
		debugWarn("Switch operation canceled; item not allowed in container", (container2::IMContainer._Container)._name)
		return SWITCH_REJECTED
	end
	if not item2AllowedInC1 then
		debugWarn("Switch operation canceled; item not allowed in container", (container1::IMContainer._Container)._name)
		return SWITCH_REJECTED
	end

	
	local switchValidateFunc = props._SWITCH_VALIDATE_FUNC
	if switchValidateFunc then
		local cIndex1 = IMContainer.GetContainerIndexFromSlotIndex(container1::IMContainer._Container, aIndex)
		local cIndex2 = IMContainer.GetContainerIndexFromSlotIndex(container2::IMContainer._Container, bIndex)

        local item1Info: ItemPositionInfo = {
            SlotIndex = aIndex,
            ContainerIndex = cIndex1,
            ContainerName = container1._name
        }
        local item2Info: ItemPositionInfo = {
            SlotIndex = bIndex,
            ContainerIndex = cIndex2,
            ContainerName = container2._name
        }

		if not switchValidateFunc(item1, item2 or nil, item1Info, item2Info) then
			return SWITCH_REJECTED
		end
	end

	props._data[aIndex], props._data[bIndex] = item2, item1
	
	if item1 == props._data[aIndex] then return SWITCH_NONE end
	
	if (container1 and container2) and container1 == container2 then
		local isHotbar = container1._name == IMConstants.CONTAINER_HOTBAR_NAME
		if isHotbar then
			container1._RENDER_FILLED_FUNC(bIndex, item1, filledGui1, IMContainer.GetContainerIndexFromSlotIndex(container1, bIndex)::number)
			bindHotbarKey(container1::IMContainer._Container, props._data, bIndex, IMContainer.GetContainerIndexFromSlotIndex(container1, bIndex))
		end
		filledGui1.Parent = slot2
        cleanupEquippedOldSlotGui(props, container1, item1, slot1)
        refreshEquippedItem(props, item1, filledGui1, slot2)
		
		if filledGui2 then
			if isHotbar then
				container2._RENDER_FILLED_FUNC(aIndex, item2::ITEM_TYPE, filledGui2, IMContainer.GetContainerIndexFromSlotIndex(container2, aIndex)::number)
				bindHotbarKey(container2::IMContainer._Container, props._data, aIndex, IMContainer.GetContainerIndexFromSlotIndex(container2, aIndex)::number)
			end
			filledGui2.Parent = slot1
            cleanupEquippedOldSlotGui(props, container2, item2::ITEM_TYPE, slot2)
            refreshEquippedItem(props, item2::ITEM_TYPE, filledGui2, slot1)
		else
			if isHotbar then
				unbindHotbarKey(container1::IMContainer._Container, aIndex)
			end
		end
		
		if IMS._CALLBACKS then
            local onSwitch = IMS._CALLBACKS.OnSwitch
            if onSwitch then onSwitch(aIndex, bIndex) end
		end
		
		return SWITCH_ITEM
	end
	
	
	if item2 then
		IMContainer.AddItemAtIndex(container1::IMContainer._Container, aIndex, item2, 
			function(filledGui: GuiObject, slot: GuiObject, item: ITEM_TYPE, containerRef: IMContainer._Container)
				callback(props, filledGui, slot, item, containerRef, false)
				refreshEquippedItem(props, item, filledGui, slot)
			end
		)
	else
        cleanupEquippedOldSlotGui(props, container1, item1, slot1)
		IMContainer.DestroyFilledGui(container1::IMContainer._Container, aIndex)	
		if (container1::IMContainer._Container)._name == IMConstants.CONTAINER_HOTBAR_NAME then
			unbindHotbarKey(container1::IMContainer._Container, aIndex)
		end
	end
	
	IMContainer.AddItemAtIndex(container2, bIndex, item1, 
		function(filledGui: GuiObject, slot: GuiObject, item: ITEM_TYPE, containerRef: IMContainer._Container)
			callback(props, filledGui, slot, item, containerRef, true)
			refreshEquippedItem(props, item, filledGui, slot)
			if containerRef._name == IMConstants.CONTAINER_HOTBAR_NAME then
				bindHotbarKey(containerRef, props._data, bIndex, IMContainer.GetContainerIndexFromSlotIndex(containerRef, bIndex))
			end
		end
	)
	
	if IMS._CALLBACKS then
        local onSwitch = IMS._CALLBACKS.OnSwitch
        if onSwitch then onSwitch(aIndex, bIndex) end
	end
	
	return SWITCH_CONTAINER
end

local function closeAllHoverPrompts(containers: { [string]: IMContainer._Container }, screenGui: ScreenGui)
	for i,container in pairs(containers) do
		if not container._HOVER_INFO then continue end
		IMContainer.HideHoverPrompt(container, IMContainer.GetHoverPromptSingleton(container, screenGui))
	end
end


local function forceOpenHoverPrompt(props: _InventoryMakerProps, container: IMContainer._Container, filledGui: GuiObject, item: ITEM_TYPE, draggable: IMDraggableUI.Draggable?)
	local hoverInfo = container._HOVER_INFO
	if not hoverInfo then setActiveSlot(props, nil) return end
	if not hoverInfo._OPEN_HOVER_PROMPT_AFTER_DRAGGING then return end
	if IMInput.GetInputType() ~= IMInput.INPUT_MOUSE then return end
	
	setActiveSlot(props, item, filledGui, draggable)
	local prompt = IMContainer.GetHoverPromptSingleton(container, props._PARENT_CONTAINER_SCREEN_GUI)
	if not prompt then return end

    local slotIndex = getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number
    local containerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)
	
	if hoverInfo._FIXED_POSITION then
		IMContainer.FixedHoverPrompt(container, prompt, item, filledGui, slotIndex, containerIndex)
	else
		IMContainer.NonFixedHoverPrompt(container, prompt, item, filledGui, UIS:GetMouseLocation(), slotIndex, containerIndex)
	end
end


--[[ Menu index refers to the index of the user-defined context menus array ]]
local function getLastOpenedMenuIndex(props: _InventoryMakerProps): number
	local n = #props._contextMenusStack
	if n == 0 then return 1 end
	return props._contextMenusStack[n]
end


local function closeContextMenu(props: _InventoryMakerProps, menuIndex: number, unrenderOnly: boolean)
	local openedIndex = menuIndex+1
	if props._CONTEXT_MENU_MODE == SINGLE_CONTEXT_MENU_MODE and not props._contextMenusOpened[openedIndex]._opened then 
		--[[ 
			In single-context, this branch is triggered when we're clearing the stack from stackIndex 1, while
			the top of the stack is the one currently being rendered. This means, all the previous menus already
			had closeContextMenu() called on them, but with the `unrenderOnly` flag set to true. Because of this,
			the the cleanupFunc still exists in the _contextMenusOpened table. So we need to clear that and the
			bounding boxes.
		]]
		table.remove(props._boundingBoxes)
		props._contextMenusOpened[openedIndex]._cleanupFunc = nil
		debugPrint("Cleanup already called for menu index:", menuIndex)
		return 
	end
	
	props._contextMenusOpened[openedIndex]._opened = false
	props._USER_CONTEXT_MENUS[menuIndex]._GUI.Visible = false
	
	local cleanupFunc = props._contextMenusOpened[openedIndex]._cleanupFunc
	if cleanupFunc then 
		cleanupFunc(unrenderOnly) 
		if not unrenderOnly then
			props._contextMenusOpened[openedIndex]._cleanupFunc = nil
		end
		debugPrint("Cleanup called for menu index:", menuIndex)
	end
end


--[[ 
	Closes the specified context menu and all of its submenus from top of the stack to the stack index; 
	calls all of the cleanup functions
]]
local function closeContextMenuStack(props: _InventoryMakerProps, stackIndex: number)
	-- Bc it's a stack, we gotta work from top to bottom
	for i = #props._contextMenusStack, stackIndex, -1 do
		closeContextMenu(props, props._contextMenusStack[i], false)
		props._contextMenusStack[i] = nil
	end
	
	if stackIndex == 1 then
		props._contextMenusOpened[1]._opened = false
	end
end


local function isPointWithinBoundingBoxes(px: number, py: number, boxes: { _BoundingBox }): boolean
	local checks = table.create(#boxes, false)
	for i,box in ipairs(boxes) do
		checks[i] = IMUtility.IsPointWithinBoundingBox(px, py, box[1], box[2], box[3], box[4])
	end

	for i,check in ipairs(checks) do
		if check then return true end
	end

	return false
end

local function hoveredContextMenuBoundingBoxesCheck(props: _InventoryMakerProps, input: InputObject, insetIgnored: boolean)
	local mouse = UIS:GetMouseLocation()
	local px, py = mouse.X, mouse.Y - IMUtility.GetGuiInsetY(not insetIgnored)
	
	-- check from top of stack to bottom
	for i = #props._boundingBoxes, 2, -1 do
		local bounds = props._boundingBoxes[i]
		local withinBounds = isPointWithinBoundingBoxes(px, py, bounds)
		if withinBounds then return end

		closeContextMenuStack(props, i)
	end
end

--[[
	Closes all the context menus, sets the active slot to nil, and hides all hover prompts for all containers
]]
local function closeAllContextMenusAndHoverPrompts(props: _InventoryMakerProps)
	closeAllHoverPrompts(props._containers, props._PARENT_CONTAINER_SCREEN_GUI)
	if props._USER_CONTEXT_MENUS and areContextMenusOpened(props._contextMenusOpened)  then
		closeContextMenuStack(props, 1)
	end
	setActiveSlot(props, nil)
end

local function setContextMenuParent(mainScreenGui: ScreenGui, contextMenuGui: GuiObject)
	local p = Instance.new("ScreenGui")
	p.Name = contextMenuGui.Name
	p.ResetOnSpawn = false
	p.IgnoreGuiInset = mainScreenGui.IgnoreGuiInset
	p.DisplayOrder = 100
	p.Parent = player.PlayerGui

	contextMenuGui.Active = true
	contextMenuGui.Parent = p
end

local function openHoveredContextMenu(props: _InventoryMakerProps, container: IMContainer._Container, menuIndex: number, boundingGui: GuiObject)
	if IMInput.GetInputType() == IMInput.INPUT_TOUCH then error("[InventoryMaker]: Hovered context menus are disabled on mobile.") end
	if props._CONTEXT_MENU_MODE ~= MULTI_CONTEXT_MENU_MODE then error("[InventoryMaker]: Multi-context mode is required to opened a hovered context menu.") end
	if not props._activeSlot then error("[InventoryMaker]: No slot active to open context menu for.") end
	if menuIndex == 1 then error("[InventoryMaker]: The primary context menu cannot be a hovered context menu.") end
	if #props._contextMenusStack == 0 then error("[InventoryMaker]: The primary context menu cannot be the the first in the stack as a hovered context menu.") end
	if props._contextMenusOpened[menuIndex + 1]._opened then return end
	
	
	props._contextMenusOpened[1]._opened = true
	props._contextMenusOpened[menuIndex + 1]._opened = true
	
	-- local isPrimaryContextMenu = menuIndex == 1
	local activeSlot = props._activeSlot
	local item = activeSlot._item
	local filledGui = activeSlot._filledGui

	-- local guiPos = filledGui.AbsolutePosition
	-- local guiSize = filledGui.AbsoluteSize
	local insetIgnored = props._PARENT_CONTAINER_SCREEN_GUI.IgnoreGuiInset
	local guiInsetY = IMUtility.GetGuiInsetY(insetIgnored)
	local containerName = getContainerNameFromFilledGui(filledGui)

	local contextMenuInfo = props._USER_CONTEXT_MENUS[menuIndex]
	local contextMenuGui = contextMenuInfo._GUI
	local slotIndex = getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number
	local cleanupRenderFunc = contextMenuInfo._RENDER_FUNC(slotIndex, item, contextMenuGui, filledGui, containerName)
	
	local hoverInfo = container._HOVER_INFO
	local hoverPrompt = IMContainer.GetHoverPromptSingleton(container, props._PARENT_CONTAINER_SCREEN_GUI)::GuiObject?
	if hoverInfo and props._SHOW_HOVER_PROMPT_NEXT_TO_MENU then
		closeAllHoverPrompts(props._containers, props._PARENT_CONTAINER_SCREEN_GUI)
		if hoverPrompt then 
			hoverPrompt.Visible = true

            local itemPositionInfo: ItemPositionInfo = {
                ContainerName = containerName,
                ContainerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex),
                SlotIndex = slotIndex
            }

			hoverInfo._RENDER_FUNC(item, hoverPrompt, itemPositionInfo) 
		end
	end
	-- position context menu next to the last opened context menu
	local lastMenuInfo = props._USER_CONTEXT_MENUS[getLastOpenedMenuIndex(props)]
	local lastPos, lastSize = lastMenuInfo._GUI.AbsolutePosition, lastMenuInfo._GUI.AbsoluteSize
	local userOffset = contextMenuInfo._OFFSET
	local anchorFromTopOffset = boundingGui.AbsolutePosition.Y + guiInsetY - HOVERED_BOUNDING_BOX_BOUNDING_GUI_PADDING
	local anchorFromBotOffset = anchorFromTopOffset - contextMenuGui.AbsoluteSize.Y + (boundingGui.AbsoluteSize.Y + HOVERED_BOUNDING_BOX_BOUNDING_GUI_PADDING*2)
	local contextMenuPos = UDim2.new(0, lastPos.X + lastSize.X, 0, anchorFromBotOffset) + UDim2.fromOffset(userOffset.X, userOffset.Y)
	
	local menuSize = contextMenuGui.AbsoluteSize
	local promptSize = hoverPrompt and hoverPrompt.AbsoluteSize or Vector2.zero
	local promptOffset = hoverInfo and hoverInfo._OFFSET or UDim2.new(0, 0, 0, 0)
	
	
	local rightSideX = ((lastPos.X <= contextMenuPos.X.Offset) and lastPos.X or lastPos.X*2) 
		+ lastSize.X + userOffset.X + menuSize.X + promptOffset.X.Offset + promptSize.X
	local leftAlign = rightSideX > camera.ViewportSize.X
	
	if leftAlign then
		contextMenuPos = UDim2.new(0, lastPos.X - contextMenuGui.AbsoluteSize.X, 0, anchorFromBotOffset) 
			+ UDim2.fromOffset(-userOffset.X, userOffset.Y)
	end


	contextMenuGui.Position = contextMenuPos
	contextMenuGui.Visible = true

	if contextMenuGui.Parent == nil then
		setContextMenuParent(props._PARENT_CONTAINER_SCREEN_GUI, contextMenuGui)
	end

	if hoverInfo and props._SHOW_HOVER_PROMPT_NEXT_TO_MENU and hoverPrompt then
		if leftAlign then
			hoverPrompt.Position = contextMenuPos - UDim2.new(0, promptSize.X, 0, 0) + UDim2.fromOffset(-promptOffset.X.Offset, promptOffset.Y.Offset)
		else
			hoverPrompt.Position = contextMenuPos + UDim2.new(0, contextMenuGui.AbsoluteSize.X, 0, 0) + hoverInfo._OFFSET
		end
	end
	
	--[[
		We need to make sure that the bounding box is expanded to account for submenus. We do this by adding 
		the bounding boxes of the submenu to its parent menu. We will use a table to store the bounding boxes.
		A context menu will only ever store 4 bounding boxes--2 for its own and 2 for its child.
	]]
	
	local _ 			= #props._contextMenusStack
	local lastGui 					= props._USER_CONTEXT_MENUS[getLastOpenedMenuIndex(props)]._GUI
	local lastPos, lastSize 		= lastGui.AbsolutePosition, lastGui.AbsoluteSize
	local _, heightA 			= lastSize.X, boundingGui.AbsoluteSize.Y
	local widthB, heightB 			= contextMenuGui.AbsoluteSize.X, contextMenuGui.AbsoluteSize.Y
	local topLeftAx, topLeftAy 		= lastPos.X, anchorFromTopOffset
	local botRightAx, botRightAy 	= topLeftAx + lastSize.X, topLeftAy + heightA + HOVERED_BOUNDING_BOX_BOUNDING_GUI_PADDING*2
	local boundingBoxes = {
		{ topLeftAx, topLeftAy, botRightAx+userOffset.X, botRightAy },
		{ 
			contextMenuPos.X.Offset - (not leftAlign and (userOffset.X + HOVERED_BOUNDING_BOX_SIDE_PADDING) or 0), 
			contextMenuPos.Y.Offset, 
			contextMenuPos.X.Offset+widthB + (leftAlign and (userOffset.X + HOVERED_BOUNDING_BOX_SIDE_PADDING) or 0), 
			contextMenuPos.Y.Offset+heightB 
		}
	}
	table.insert(props._contextMenusStack, menuIndex )
	table.insert(props._boundingBoxes, boundingBoxes)
	
	local currStackIndex = #props._contextMenusStack
	
	
	local bounds1: Frame?
	local bounds2: Frame?
	if InventoryMaker.DEBUG_SHOW_BOUNDING_BOXES then
		local boundsColor = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
		bounds1 = Instance.new("Frame")
		bounds1.BackgroundColor3 = boundsColor
		bounds1.Transparency = 0.6
		bounds1.ZIndex = 200
		bounds1.Size = UDim2.new(0, boundingBoxes[1][3] - boundingBoxes[1][1], 0, boundingGui.AbsoluteSize.Y + HOVERED_BOUNDING_BOX_BOUNDING_GUI_PADDING*2)
		bounds1.Position = UDim2.new(0, boundingBoxes[1][1], 0, boundingBoxes[1][2])
		bounds1.Parent = props._PARENT_CONTAINER_SCREEN_GUI
		
		bounds2 = Instance.new("Frame")
		bounds2.BackgroundColor3 = boundsColor
		bounds2.Transparency = 0.6
		bounds2.ZIndex = 200
		bounds2.Size = UDim2.new(0, boundingBoxes[2][3] - boundingBoxes[2][1], 0, contextMenuGui.AbsoluteSize.Y)
		bounds2.Position = UDim2.new(0, boundingBoxes[2][1], 0, boundingBoxes[2][2])
		bounds2.Parent = props._PARENT_CONTAINER_SCREEN_GUI
	end

	local function cleanupBoundingBoxes()
		table.remove(props._boundingBoxes)
		
		if InventoryMaker.DEBUG_SHOW_BOUNDING_BOXES then
            if bounds1 then bounds1:Destroy() end
            if bounds2 then bounds2:Destroy() end
			debugPrint("bounding boxes visualization destroyed for stack index:", currStackIndex)
		end
	end

	local onFirstHoveredCleanup
	if currStackIndex == 2 then -- 2 is the index of the first submenu (1 is the PCM), which means the first hovered menu in multi-context mode
		onFirstHoveredCleanup = props._onFirstHoveredMenu()
	end
	
	props._contextMenusOpened[menuIndex+1]._cleanupFunc = function()
		cleanupBoundingBoxes()
		cleanupRenderFunc()
		if onFirstHoveredCleanup then onFirstHoveredCleanup() end
		
		if container._HOVER_INFO and props._SHOW_HOVER_PROMPT_NEXT_TO_MENU then
			local hoverPrompt = IMContainer.GetHoverPromptSingleton(container, props._PARENT_CONTAINER_SCREEN_GUI)
			if not hoverPrompt then return end
			if leftAlign then
				hoverPrompt.Position = UDim2.new(0, lastPos.X - promptSize.X, 0, lastPos.Y + guiInsetY) 
					+ UDim2.fromOffset(-promptOffset.X.Offset, promptOffset.Y.Offset)
			else
				hoverPrompt.Position = UDim2.new(0, lastPos.X + lastGui.AbsoluteSize.X, 0, lastPos.Y + guiInsetY) + container._HOVER_INFO._OFFSET
			end
		end
	end
end



--[[
	A primary context menu is the first context menu that is defined by the user, and appears first in the
	context menu stack. It is opened on right-click and is closed when left-clicking out of its bounds. When
	the primary context menu is closed, its submenus are closed as well.
	
	The returnToParent flag is true when openStaticContextMenu() is called to return to the parent context menu.
]]
local function openStaticContextMenu(props: _InventoryMakerProps, container: IMContainer._Container, menuIndex: number, returnToParent: boolean)
	local activeSlot = props._activeSlot
	
	if not activeSlot then error("[Inventory]: No slot active to open context menu for.") end
	if activeSlot._draggable and IMDraggableUI.IsDragging(activeSlot._draggable) then debugWarn("cannot open menu while dragging") return end
	

	local isSingleContext = props._CONTEXT_MENU_MODE == SINGLE_CONTEXT_MENU_MODE
	if isSingleContext then
		if #props._contextMenusStack > 0 and not returnToParent then
			debugPrint("unrendering current context menu")
			closeContextMenu(props, getLastOpenedMenuIndex(props), true)
		end
	end
	
	props._contextMenusOpened[menuIndex + 1]._opened = true
	props._contextMenusOpened[1]._opened = true
	
	local item = activeSlot._item
	local filledGui = activeSlot._filledGui
	local containerName = container._name
	
	local guiPos = filledGui.AbsolutePosition
	local guiSize = filledGui.AbsoluteSize
	local insetIgnored = props._PARENT_CONTAINER_SCREEN_GUI.IgnoreGuiInset
	local guiInsetY = IMUtility.GetGuiInsetY(insetIgnored)
	

	local contextMenuInfo = props._USER_CONTEXT_MENUS[menuIndex]
	local userOffset = contextMenuInfo._OFFSET
	local userOffsetUDim2 = UDim2.fromOffset(userOffset.X, userOffset.Y)
    local slotIndex = getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number
	
	local hoverInfo = container._HOVER_INFO
	local hoverPrompt = IMContainer.GetHoverPromptSingleton(container, props._PARENT_CONTAINER_SCREEN_GUI)
	if hoverInfo then
		if props._SHOW_HOVER_PROMPT_NEXT_TO_MENU and hoverPrompt then
			closeAllHoverPrompts(props._containers, props._PARENT_CONTAINER_SCREEN_GUI)
			hoverPrompt.Visible = true

            local itemPositionInfo: ItemPositionInfo = {
                ContainerName = containerName,
                ContainerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex),
                SlotIndex = slotIndex
            }

			hoverInfo._RENDER_FUNC(item, hoverPrompt, itemPositionInfo)
		else
			IMContainer.HideHoverPrompt(container, hoverPrompt)
		end
	end
	local promptSize = hoverPrompt and hoverPrompt.AbsoluteSize or Vector2.zero
	local contextMenuPos: UDim2 = UDim2.new(0, guiPos.X + guiSize.X, 0, guiPos.Y + guiInsetY) + userOffsetUDim2
	local contextMenuGui = contextMenuInfo._GUI
	local cleanupRenderFunc = contextMenuInfo._RENDER_FUNC(slotIndex, item, contextMenuGui, filledGui, containerName)

	
	local menuSize = contextMenuGui.AbsoluteSize
	local rightSideX = contextMenuPos.X.Offset + promptSize.X + menuSize.X
	local rightSideOverflow = rightSideX > camera.ViewportSize.X

	if rightSideOverflow then
		contextMenuPos = UDim2.fromOffset(guiPos.X - menuSize.X, guiPos.Y + guiInsetY) 
			+ UDim2.fromOffset(-userOffset.X, userOffset.Y)
	end
	
    local inset = IMUtility.GetGuiInsetY(not props._PARENT_CONTAINER_SCREEN_GUI.IgnoreGuiInset)
	local bottomSideY = contextMenuPos.Y.Offset + menuSize.Y + inset
	local bottomSideOverflow = bottomSideY > camera.ViewportSize.Y
	
	if bottomSideOverflow then
		contextMenuPos = UDim2.fromOffset(contextMenuPos.X.Offset, guiPos.Y + guiInsetY - menuSize.Y + guiSize.Y) 
			+ UDim2.fromOffset(-userOffset.X, userOffset.Y)
	end
	

	contextMenuGui.Position = contextMenuPos
	contextMenuGui.Visible = true

	if contextMenuGui.Parent == nil then
		setContextMenuParent(props._PARENT_CONTAINER_SCREEN_GUI, contextMenuGui)
	end
	
	-- position hover prompt next to context menu on the right (not overflowed) or left (overflowed)
	if hoverInfo and props._SHOW_HOVER_PROMPT_NEXT_TO_MENU and hoverPrompt then
		if rightSideOverflow then
			hoverPrompt.Position = contextMenuPos - UDim2.new(0, promptSize.X, 0, 0) + 
				UDim2.fromOffset(-hoverInfo._OFFSET.X.Offset, hoverInfo._OFFSET.Y.Offset)
		else
			hoverPrompt.Position = contextMenuPos + UDim2.new(0, contextMenuGui.AbsoluteSize.X, 0, 0) + hoverInfo._OFFSET
		end
		
		if rightSideOverflow then
			local leftSideX = hoverPrompt.Position.X.Offset
			local leftSideOverflow = leftSideX < 0
			if leftSideOverflow then
				-- if the hoverprompt overflows on the left side too, position it back to the right side of the menu
				hoverPrompt.Position = contextMenuPos + UDim2.new(0, contextMenuGui.AbsoluteSize.X, 0, 0) + hoverInfo._OFFSET
			end
		end
	end
	
	
	
	local contextMenuPosX = contextMenuPos.X.Offset
	local contextMenuPosY = contextMenuPos.Y.Offset
	
	local stackLen = #props._contextMenusStack
	local menuIndexAlreadyInStack = props._contextMenusStack[stackLen] and props._contextMenusStack[stackLen] == menuIndex
	local menuIndexNotInStackYet = not props._contextMenusStack[#props._contextMenusStack+1]
	if not menuIndexAlreadyInStack and menuIndexNotInStackYet then
		table.insert(props._contextMenusStack, menuIndex)
		table.insert(props._boundingBoxes, {
			{ contextMenuPosX, contextMenuPosY, contextMenuPosX + contextMenuGui.AbsoluteSize.X, contextMenuPosY + contextMenuGui.AbsoluteSize.Y }
		})
		stackLen += 1
	end
	
	local bounds2: Frame?
	if InventoryMaker.DEBUG_SHOW_BOUNDING_BOXES then
		local box = props._boundingBoxes[stackLen][1]
		bounds2 = Instance.new("Frame")
		bounds2.BackgroundColor3 = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
		bounds2.Transparency = 0.6
		bounds2.ZIndex = 200
		bounds2.Size = UDim2.new(0, box[3] - box[1], 0, contextMenuGui.AbsoluteSize.Y)
		bounds2.Position = UDim2.new(0, box[1], 0, box[2])
		bounds2.Parent = props._PARENT_CONTAINER_SCREEN_GUI
	end
	
	
	local function cleanupBoundingBoxes()
		table.remove(props._boundingBoxes) -- bug here???
	end
	

	local con: RBXScriptConnection?
	con = UIS.InputBegan:Connect(function(input, gpe)
		if IMInput.IsInputActive(IMInput.ROOT_MENU_BOUNDS_CHECK, input) then
			local mouse = UIS:GetMouseLocation() -- I'm not sure how, but this somehow works on mobile??
			local px, py = mouse.X, mouse.Y - IMUtility.GetGuiInsetY(not insetIgnored)
			
			local check = false
			for i,v in ipairs(props._boundingBoxes) do
				check = isPointWithinBoundingBoxes(px, py, v)
			end
			
			if not check then
                -- ugly type assertions bc of typechecker, btw
				if con ~= nil and (con::RBXScriptConnection).Connected then (con::RBXScriptConnection):Disconnect() end
				closeContextMenuStack(props, 1)
				setActiveSlot(props, nil)
				if container._HOVER_INFO then
					IMContainer.HideHoverPrompt(container, IMContainer.GetHoverPromptSingleton(container, props._PARENT_CONTAINER_SCREEN_GUI))
				end
			end
		end
	end)
	
	if not isSingleContext then
		-- callback that gets run whenever the first hovered menu is opened, and the returned cleanup func is called when it closes
		props._onFirstHoveredMenu = function()
			local checkCon: RBXScriptConnection?
			checkCon = UIS.InputChanged:Connect(function(input)
				if not IMInput.IsInputActive(IMInput.MULTI_CONTEXT_BOUNDS_CHECK, input) then return end
				
				hoveredContextMenuBoundingBoxesCheck(props, input, insetIgnored)
			end)
			
			return function()
				if checkCon ~= nil and checkCon.Connected then checkCon:Disconnect() end
			end
		end	
	end
	
	props._contextMenusOpened[menuIndex + 1]._cleanupFunc = function(unrenderOnly: boolean)
		if con ~= nil and con.Connected then con:Disconnect() end
		if InventoryMaker.DEBUG_SHOW_BOUNDING_BOXES then 
            if bounds2 then bounds2:Destroy() end
			debugPrint("Bounding boxes visualization destroyed for stack index:", #props._contextMenusStack)
		end
		if not unrenderOnly then cleanupBoundingBoxes() end
		cleanupRenderFunc()
	end
end

local function connectContextMenuEvents(props: _InventoryMakerProps, 
    filledGui: GuiObject, 
    draggable: IMDraggableUI.Draggable?, 
    container: IMContainer._Container
)
	local inputType = IMInput.GetInputType()
	
	local function openRootMenu()
		if not props._toggled then debugPrint("Cannot open context menu while inventory is toggled off.") return end
        local item = getItemFromFilledGui(filledGui)
		if isItemActiveSlot(props, item) and areContextMenusOpened(props._contextMenusOpened) then return end

		if inputType == IMInput.INPUT_TOUCH then
            --[[ Mobile only issue:
                Bc both the input triggers for opening the root menu and checking the root menu bounds is the same,
                what happens is, without the task.wait(), our root menu will open and then immediately close on the same
                frame, due to the connection we connect in openStaticContextMenu().
                
                Warning: Not even sure if this is a 100% guarantee reliable solution......
            ]]
            task.wait()
        end
            
        setActiveSlot(props, item, filledGui, draggable)
        closeContextMenuStack(props, 1)
        openStaticContextMenu(props, container, 1, false) -- all PCM are static context menus in both single-context and multi-context
	end
	
    filledGui.InputBegan:Connect(function(input)
        if IMInput.IsInputActive(IMInput.CONTEXT_MENU_OPEN, input) then
            openRootMenu()
        end
    end)
end


--[[
    This function assumes the items are fixed in position, never changing in order in the array
    during runtime, hence the "static"
]]
local function connectActivatedEventForStaticContainer(staticContainer: IMStaticContainer._StaticContainer, filledGui: GuiObject, containerIndex: number)
    local activatedFunc = staticContainer._CALLBACKS._ACTIVATED_FUNC
    if not activatedFunc then return end

    local input = IMInput.GetInputType()

    if input == IMInput.INPUT_MOUSE then
        filledGui.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local item = staticContainer._data[containerIndex]
                activatedFunc(item, filledGui, containerIndex)
            end
        end)
    elseif input == IMInput.INPUT_TOUCH then
        filledGui.TouchTap:Connect(function()
            local item = staticContainer._data[containerIndex]
            activatedFunc(item, filledGui, containerIndex)
        end)
    end
end

--[[
    This function assumes the items are fixed in position, never changing in order in the array
    during runtime, hence the "static"
]]
local function connectFilledSlotHoverEventsForStaticContainer(props: _InventoryMakerProps,
    staticContainer: IMStaticContainer._StaticContainer,
    filledGui: GuiObject,
    containerIndex: number
)
    local hoverInfo  = staticContainer._HOVER_INFO
    if not hoverInfo then return end

    local fixedPos = hoverInfo._FIXED_POSITION
    local prompt = IMContainer.GetHoverPromptSingleton(staticContainer, staticContainer._HOVER_PROMPT_SCREEN_GUI)
    if not prompt then return end

    --[[
        Everytime :Close() is called, it will hide the hover prompt
    ]]
    local onClosedFunc = staticContainer._CALLBACKS._ON_CLOSED_FUNC
    staticContainer:DefineClose(function()
        IMContainer.HideHoverPrompt(staticContainer, prompt)
        if onClosedFunc then
            onClosedFunc(staticContainer._PARENT_CONTAINER)
        end
    end)
    
    if fixedPos then
   		filledGui.InputBegan:Connect(function(input)
			if IMInput.IsInputActive(IMInput.HOVER_PROMPT_START, input) and not areContextMenusOpened(props._contextMenusOpened) then
                local item = staticContainer._data[containerIndex]
				
				if props._dragging then return end
				if isItemActiveSlot(props::_InventoryMakerProps, item) then return end
				setActiveSlot(props::_InventoryMakerProps, item, filledGui)
				
				IMContainer.FixedHoverPrompt(staticContainer, prompt, item, filledGui, containerIndex, containerIndex)
			end
		end)     
    else
        filledGui.InputChanged:Connect(function(input)
			if IMInput.IsInputActive(IMInput.HOVER_PROMPT_START, input) and not areContextMenusOpened(props._contextMenusOpened) then
				if props._dragging then return end

                local item = staticContainer._data[containerIndex]
				if not props._activeSlot then
					setActiveSlot(props::_InventoryMakerProps, item, filledGui)
				end
				
				IMContainer.NonFixedHoverPrompt(staticContainer, prompt, item, filledGui, UIS:GetMouseLocation(), containerIndex, containerIndex)
			end
		end)
    end

    filledGui.InputEnded:Connect(function(input)
		if IMInput.IsInputActive(IMInput.HOVER_PROMPT_END, input) and not areContextMenusOpened(props._contextMenusOpened) then
            if props._dragging then return end
            
            if IMInput.GetInputType() == IMInput.INPUT_TOUCH then
                if filledGui.Parent == nil then return end
            end

            local item = staticContainer._data[containerIndex]
            if isItemActiveSlot(props::_InventoryMakerProps, item) then
                IMContainer.HideHoverPrompt(staticContainer, prompt)		
                setActiveSlot(props::_InventoryMakerProps, nil)
            end
		end
	end)
end

local function connectFilledSlotHoverEvents(props: _InventoryMakerProps, 
    filledGui: GuiObject, 
    draggable: IMDraggableUI.Draggable?, 
    container: IMContainer._Container
)
	local hoverInfo = container._HOVER_INFO::IMContainer._HoverPromptInfo
	local fixedPos = hoverInfo._FIXED_POSITION
	local prompt = IMContainer.GetHoverPromptSingleton(container, props._PARENT_CONTAINER_SCREEN_GUI)
	if not prompt then return end
	
	local canHotbarHover = container._name == IMConstants.CONTAINER_HOTBAR_NAME 
		and IMContainer.IsBitFlagEnabled(container._flags, InventoryMaker.HOTBAR_UNTOGGLED_HOVER)
	

	if fixedPos then
		filledGui.InputBegan:Connect(function(input)
			if IMInput.IsInputActive(IMInput.HOVER_PROMPT_START, input) and not areContextMenusOpened(props._contextMenusOpened) then
				if not props._toggled and not canHotbarHover then 
					debugPrint("Cannot hover while inventory is toggled off.") 
					return 
				end

                local item = getItemFromFilledGui(filledGui)
				
				if props._dragging then return end
				if isItemActiveSlot(props::_InventoryMakerProps, item) then return end
				if draggable and IMDraggableUI.IsDragging(draggable) then return end
				setActiveSlot(props::_InventoryMakerProps, item, filledGui, draggable)

                local slotIndex = getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number
                local containerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)
				
				IMContainer.FixedHoverPrompt(container, prompt, item, filledGui, slotIndex, containerIndex)
			end
		end)
	else
		filledGui.InputChanged:Connect(function(input)
			if IMInput.IsInputActive(IMInput.HOVER_PROMPT_START, input) and not areContextMenusOpened(props._contextMenusOpened) then
				if not props._toggled and not canHotbarHover then 
					debugPrint("Cannot hover while inventory is toggled off.") 
					return 
				end
				if props._dragging then return end

                local item = getItemFromFilledGui(filledGui)
				if not props._activeSlot then
					setActiveSlot(props::_InventoryMakerProps, item, filledGui, draggable)
				end
				if draggable and IMDraggableUI.IsDragging(draggable) then return end

                local slotIndex = getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number
                local containerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)
				
				IMContainer.NonFixedHoverPrompt(container, prompt, item, filledGui, UIS:GetMouseLocation(), slotIndex, containerIndex)
			end
		end)
	end
	
	filledGui.InputEnded:Connect(function(input)
		if IMInput.IsInputActive(IMInput.HOVER_PROMPT_END, input) and not areContextMenusOpened(props._contextMenusOpened) then
			if not props._toggled and not canHotbarHover then 
				debugPrint("Cannot hover while inventory is toggled off.") 
				return 
			end
            if props._dragging then return end
            
            if IMInput.GetInputType() == IMInput.INPUT_TOUCH then
                if filledGui.Parent == nil then return end
            end

            local item = getItemFromFilledGui(filledGui)
            if isItemActiveSlot(props::_InventoryMakerProps, item) then
                IMContainer.HideHoverPrompt(container, prompt)		
                setActiveSlot(props::_InventoryMakerProps, nil)
            end
		end
	end)
end

local function connectFilledGuiEvents(props: _InventoryMakerProps, 
    filledGui: GuiObject,  
    container: IMContainer._Container
): IMDraggableUI.Draggable?

	local draggable = container._draggables[filledGui]
	local screenGui = props._PARENT_CONTAINER_SCREEN_GUI
	local stackingConfigs = props._STACKING_CONFIGS
	local isHotbarContainer = container._name == IMConstants.CONTAINER_HOTBAR_NAME
	local touchedEnabled = IMInput.GetInputType() == IMInput.INPUT_TOUCH
	local mouseEnabled = IMInput.GetInputType() == IMInput.INPUT_MOUSE
	local containerCallbacks = container._CALLBACKS
	
	if touchedEnabled then
		filledGui.Active = true
	end
	
	if container._HOVER_INFO then
		connectFilledSlotHoverEvents(props, filledGui, draggable, container)
	end

	if props._USER_CONTEXT_MENUS and not isHotbarContainer then
		connectContextMenuEvents(props, filledGui, draggable, container)
	end
	
	local function equipItemToggle(itemToToggleEquip: ITEM_TYPE)
		if props._USER_CONTEXT_MENUS and areContextMenusOpened(props._contextMenusOpened) then
			closeContextMenuStack(props, 1)
		end
		setActiveSlot(props, itemToToggleEquip, filledGui, draggable)
		setEquippedItem(props, itemToToggleEquip, filledGui, container, false, false)
	end
	
	--[[
		Connect double-tap event to equip an item in a nonhotbar container,
		since tap-to-equip for nonhotbar slots is disabled
		
		If dragging is enabled, then we only allow the double-tap for nonhotbar slots.
		If dragging is disabled, then we also allow the double-tap for hotbar slots
		since the single-tap functionality uses the draggable object (which will be nil
		when dragging is disabled)
	]]
	if (draggable and touchedEnabled and not isHotbarContainer) or (not draggable and touchedEnabled) then
		local lastTap = 0
		filledGui.TouchTap:Connect(function()
			if os.clock() - lastTap <= InventoryMaker.DOUBLE_TAP_THRESHOLD_S then
                local item = getItemFromFilledGui(filledGui)
				equipItemToggle(item)
				
				if containerCallbacks._ACTIVATED_FUNC then
					containerCallbacks._ACTIVATED_FUNC(item, filledGui, getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number)
				end
			end
			lastTap = os.clock()
		end)
	end

		
	if not draggable then 
		if touchedEnabled then return nil end
		
		filledGui.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local item = getItemFromFilledGui(filledGui)
				equipItemToggle(item)
				
				if containerCallbacks._ACTIVATED_FUNC then
					containerCallbacks._ACTIVATED_FUNC(item, filledGui, getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number)
				end
			end
		end)
		
		return nil 
	end
	
	
	-------------------------------------------------------------
	---------------[When container allows dragging]---------------
	--------------------------------------------------------------
	
	draggable.BeforeDragStart = function()
		local toggled = props._toggled
		if isHotbarContainer and not toggled then
            local item = getItemFromFilledGui(filledGui)
			setEquippedItem(props, item, filledGui, container, false, false)
			
			-- disable left click callback on mobile since mobile does not have a left click mouse button
			if containerCallbacks._ACTIVATED_FUNC and mouseEnabled then 
				containerCallbacks._ACTIVATED_FUNC(item, filledGui, getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number) 
			end
			return false
		end
		
		if not toggled then debugWarn("Cannot drag while inventory is toggled off.") end
		return toggled
	end
	
	draggable.OnDragStart = function()
		props._dragging = true
        local item = getItemFromFilledGui(filledGui)
		setActiveSlot(props, item, filledGui, draggable)
		if container._HOVER_INFO then
			IMContainer.HideHoverPrompt(container, IMContainer.GetHoverPromptSingleton(container, screenGui))
		end

		if props._USER_CONTEXT_MENUS then
			closeContextMenuStack(props, 1)
		end
	end
	
	draggable.OnDragEnd = function(mousePos, guis: { GuiObject }, wasDragged: boolean)
        local item = getItemFromFilledGui(filledGui)
		if not wasDragged then	
			-- disable left click callback and tapping to equip on mobile for all non-hotbar slots
			if touchedEnabled and not isHotbarContainer then return end
			equipItemToggle(item)
			if containerCallbacks._ACTIVATED_FUNC then 
				containerCallbacks._ACTIVATED_FUNC(item, filledGui, getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number) 
			end
			return
		end
		
		props._dragging = false
		local switchFlag = SWITCH_NONE
		local stackedOnDrag = false
		local slotInGuisArray = false
		for _, possibleSlot in ipairs(guis) do
			local targetSlotIndex = getSlotIndexFromSlot(possibleSlot)
			if not targetSlotIndex then continue end -- we obviously only want to work with slots, and not some other gui
			
			if targetSlotIndex > props._capacity then error("[InventoryMaker] (Internal): Target slot index > inv capacity") end
			
			if possibleSlot == filledGui.Parent then slotInGuisArray = true end
			if possibleSlot == filledGui or 
				possibleSlot == filledGui.Parent then continue end -- we don't wanna switch with itself
			
			if stackingConfigs then
				local targetContainer = props._containers[getContainerNameFromSlot(possibleSlot)]
				local oldItem = (props._data::DATA)[getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number]::ITEM_TYPE
				local targetItem = (props._data::DATA)[targetSlotIndex]::ITEM_TYPE
				
				if targetItem then
					local canStack, leftover = (stackingConfigs::_StackingConfigs)._STACK_VALIDATE(targetItem, oldItem)
					if canStack then
						if container ~= targetContainer and targetContainer._closedContainer then 
							debugPrint("Stacking operation canceled; cannot stack from an open container to a closed one")
							break
						end
						
						if container._closedContainer and not (targetContainer::IMContainer._Container)._closedContainer then 
							debugPrint("Stacking operation canceled; cannot stack from a closed container to an open one")
							break 
						end
						
						if (targetContainer::IMContainer._Container)._stackingEnabled then
							stackOnDrag(props, targetItem, oldItem, possibleSlot, filledGui::any, leftover)
							stackedOnDrag = true
							local targetFilledGui = IMContainer.GetFilledGuiFromIndex(targetContainer::IMContainer._Container, targetSlotIndex)::GuiObject
							local targetDraggable = targetContainer._draggables[targetFilledGui]
							setActiveSlot(props, targetItem, targetFilledGui, targetDraggable)
							forceOpenHoverPrompt(props, targetContainer::IMContainer._Container, targetFilledGui, targetItem, targetDraggable)
							break
						else
							debugPrint(string.format("Stacking disabled on container (%s); switching instead", targetContainer._name))
						end
					end
					-- if it doesnt pass the stacking validate func or if the currItem is false (aka empty slot), then we just switch
				end
			end
			

			switchFlag = switch(props, filledGui::any, possibleSlot, 
				function(propsRef: _InventoryMakerProps, newFilledGui, newSlot, itemRef, containerRef, focusedItem)
					local newDraggable = connectFilledGuiEvents(propsRef, newFilledGui, containerRef)
					if not focusedItem then return end
					
					forceOpenHoverPrompt(propsRef, containerRef, newFilledGui, itemRef, newDraggable)
				end
			)
			break
		end
		
        
		if switchFlag == SWITCH_NONE and not stackedOnDrag then
			local onDraggedOutFunc = props._CALLBACKS._ON_DRAGGED_OUT
			local slotIndex = getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number
			local info: ItemPositionInfo = {
				SlotIndex = slotIndex,
				ContainerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex),
				ContainerName = container._name
			}
			if onDraggedOutFunc and not slotInGuisArray then task.defer(onDraggedOutFunc, guis, item, info) end
			return
		end

		--[[
			if switching between containers, the old filledGui will be destroyed (due to switch()), 
			which means we lose the reference to force open the hover prompt below. Thus, we return 
			when the switch flag is also SWITCH_CONTAINER, since we don't need to show the hover prompt 
			on a destroyed gui. Instead, we do it in the callback for switching, which will provide us the
			new filledGui, as you can see above.
		]]
		if switchFlag == SWITCH_CONTAINER or switchFlag == SWITCH_REJECTED or switchFlag == SWITCH_NONE then return end
		
		forceOpenHoverPrompt(props, container, filledGui, item, draggable)
	end
	
	IMDraggableUI.Enable(draggable)
	
	return draggable
end


local splittingActive = false
local function split(props: _InventoryMakerProps, splitSlotIndex: number, currFilledGui: GuiObject)
	if splittingActive then return end
	
	if props._data == nil then error("[InventoryMaker] (Internal): Data is nil") end
	if props._currSize >= props._capacity then debugWarn("Not enough space in inventory to split.") return end

	local configs = props._STACKING_CONFIGS
    if not configs then return end

	local currItem = props._data[splitSlotIndex]::ITEM_TYPE
	local newItemContainer = props._containers[getContainerNameFromFilledGui(currFilledGui)]
	
	if not newItemContainer._draggingEnabled then debugPrint("Dragging disabled on container; no splitting will occur.") return end
	if not newItemContainer._stackingEnabled then debugPrint("Stacking disabled on container; no splitting will occur.") return end
	
	local canSplit = configs._SPLIT_VALIDATE(currItem)
	if not canSplit then debugPrint("Cannot perform split operation.") return end

	local possibleNewItem, cancelSplitFunc = configs._SPLIT_UPDATE(currItem, IMUtility.DeepCopyTable(currItem::IMUtility.Table)::ITEM_TYPE, currFilledGui)
	
	
	splittingActive = true
	
	
	-- bc the currItem is still within the slot, we need to create a dummy filled gui
	IMContainer.CreateDummyFilledGui(newItemContainer::IMContainer._Container, splitSlotIndex, possibleNewItem)

	local currDraggable = newItemContainer._draggables[currFilledGui]::IMDraggableUI.Draggable
	local prevOnDragEnd = currDraggable.OnDragEnd
	
	local function cancelSplitOperation()
		cancelSplitFunc()
		IMContainer.DestroyDummyFilledGui(newItemContainer::IMContainer._Container, splitSlotIndex)
		currDraggable.OnDragEnd = prevOnDragEnd
		props._dragging = false
		
		splittingActive = false 
	end	
	
	-- override the draggable's OnDragEnd callback of the currFilledGui to use logic for splitting instead of logic for switching and clicking
	currDraggable.OnDragEnd = function(mousePos, guis: { GuiObject }, wasDragged: boolean)
		if not wasDragged then
			cancelSplitOperation()
			debugWarn("Split operation canceled")
			return
		end
		
		local emptySlotIndex: number = -1
		local targetContainer: IMContainer._Container?
		for _, possibleSlot in ipairs(guis) do
			local slotIndex = getSlotIndexFromSlot(possibleSlot)
			if not slotIndex then continue end
			local isEmptySlot = props._data[slotIndex] == false
			if isEmptySlot then 
				targetContainer = props._containers[getContainerNameFromSlot(possibleSlot)]
				emptySlotIndex = slotIndex 
			end
			break
		end
		
		if emptySlotIndex == -1 or not targetContainer then 
			cancelSplitOperation() 
			debugWarn("Split operation canceled; an item split from a stack can only be dragged into an empty slot")
		else
			if (targetContainer._closedContainer or newItemContainer._closedContainer) and targetContainer ~= newItemContainer then
				cancelSplitOperation()
				debugWarn("Split operation canceled; cannot split into/from a closed container")
				return
			end 
			
			if not (targetContainer::IMContainer._Container):_isItemAllowed(currItem) then
				cancelSplitOperation()
				debugWarn("Split operation canceled; item not allowed in container", targetContainer._name)
				return
			end
			
			IMContainer.DestroyDummyFilledGui(newItemContainer::IMContainer._Container, splitSlotIndex)
			IMContainer.AddItemAtIndex(targetContainer::IMContainer._Container, emptySlotIndex, currItem, 
				function(newFilledGui, newSlot, itemRef, cRef, slotIndex: number, cIndex: number)
					connectFilledGuiEvents(props, newFilledGui, cRef)
					props._data[emptySlotIndex] = itemRef

					refreshEquippedItem(props, itemRef, newFilledGui, newSlot)

					if cRef._name == IMConstants.CONTAINER_HOTBAR_NAME then
						bindHotbarKey(cRef, props._data, slotIndex, cIndex)
					end
				end
			)

			IMContainer.AddItemAtIndex(newItemContainer::IMContainer._Container, splitSlotIndex, possibleNewItem, 
				function(newFilledGui, newSlot, itemRef, cRef, slotIndex: number, cIndex: number)
					connectFilledGuiEvents(props, newFilledGui, cRef)
					props._data[splitSlotIndex] = itemRef
					props._currSize += 1

					if cRef._name == IMConstants.CONTAINER_HOTBAR_NAME then
						bindHotbarKey(cRef, props._data, slotIndex, cIndex)
					end
				end
			)
			
			if props._CALLBACKS and props._CALLBACKS._ON_SIZE_CHANGED then
				props._CALLBACKS._ON_SIZE_CHANGED(props._currSize, props._capacity)
			end
			
			debugPrint("New inventory size after splitting:", props._currSize)
			currDraggable.OnDragEnd = prevOnDragEnd
			props._dragging = false
			
			splittingActive = false

			if IMS._CALLBACKS then
                local onSplit = IMS._CALLBACKS.OnSplit
                if onSplit then onSplit(emptySlotIndex, splitSlotIndex) end
			end
		end
	end
end


local function stackOnAddItem(
	props: _InventoryMakerProps, updateFunc: StackingUpdateFunc, container: IMContainer._Container, 
	newItem: ITEM_TYPE, targetItem: ITEM_TYPE, targetSlotIndex: number, leftover: number
): boolean

	if not props._data then error("[InventoryMaker]: (Internal) _data is nil") end
	local targetFilledGui = IMContainer.GetFilledGuiFromIndex(container, targetSlotIndex)
	if not targetFilledGui then debugWarn("Could not find filled gui for stacking.") return false end

    local stackingConfigs = props._STACKING_CONFIGS
    if not stackingConfigs then return false end
	
	if leftover <= 0 then
		updateFunc(leftover, targetItem, newItem, targetFilledGui)
		
		local equippedItem = props._equippedItem
		local canAutoEquip = not IMContainer.IsBitFlagEnabled(container._flags, InventoryMaker.NO_AUTO_EQUIP)
		
		if equippedItem then
			local canStack = stackingConfigs._STACK_VALIDATE(targetItem, equippedItem._item)
			if not canStack and canAutoEquip then
				setEquippedItem(props, targetItem, targetFilledGui, container, true, false)
			end
		elseif canAutoEquip then
			setEquippedItem(props, targetItem, targetFilledGui, container, true, false)
		end
		
		local cIndex = IMContainer.GetContainerIndexFromSlotIndex(container, targetSlotIndex)
		local onItemAddedCallback = container._CALLBACKS._ON_ITEM_ADDED_FUNC
		if onItemAddedCallback then
			onItemAddedCallback(targetItem, targetFilledGui, { 
				SlotIndex = targetSlotIndex, 
				ContainerIndex = cIndex,
				ContainerName = container._name
			})
		end
			
		debugPrint("Stack on add; no leftovers")	
		return true
	end


    -- find the nearest available container
	local targetContainer: IMContainer._Container do
        local indexedContainers = props._containersIndex
        for c = 1, #indexedContainers do
            local currContainer = props._containers[indexedContainers[c]]
            if currContainer._currSize >= currContainer._capacity then continue end
            if currContainer._inItemspace == false then continue end
            targetContainer = currContainer
            break
        end
	end
    
    
	for i, item in props._data do
        if item then continue end
        if i < targetContainer._invStartIndex then continue end
        if i > targetContainer._invEndIndex then continue end

        local targetLeftoverIndex: number = i

		IMContainer.AddItemAtIndex(targetContainer, targetLeftoverIndex, newItem, 
			function(newFilledGui: GuiObject, newSlot: GuiObject, itemRef: ITEM_TYPE, cRef: IMContainer._Container, slotIndex: number, containerIndex: number)
				connectFilledGuiEvents(props, newFilledGui, cRef)
				updateFunc(leftover, targetItem, itemRef, targetFilledGui, newFilledGui)
				props._data[targetLeftoverIndex] = itemRef
				props._currSize += 1
				
				if not IMContainer.IsBitFlagEnabled(targetContainer._flags, InventoryMaker.NO_AUTO_EQUIP) then
					setEquippedItem(props, itemRef, newFilledGui, targetContainer, true, false)
				end

				if cRef._name == IMConstants.CONTAINER_HOTBAR_NAME then
					unbindHotbarKey(cRef, slotIndex)
					bindHotbarKey(cRef, props._data, slotIndex, containerIndex)
				end
			end
		)
		
		if props._CALLBACKS and props._CALLBACKS._ON_SIZE_CHANGED then
			props._CALLBACKS._ON_SIZE_CHANGED(props._currSize, props._capacity)
		end

		debugPrint(string.format("Stack on add:\n\tleftover: %d\n\tcurrent size: %d", leftover, props._currSize))	
		return true
	end

	return false
end

local function enableSplitting(props: _InventoryMakerProps): RBXScriptConnection?
	local configs = props._STACKING_CONFIGS
	if not configs then return nil end
	
    -- dealing with guiinset is so annoying, oh my god
	-- local inset = IMUtility.GetGuiInsetY(props._PARENT_CONTAINER_SCREEN_GUI.IgnoreGuiInset)
    local inset = IMUtility.GetGuiInsetY(true)
	
	local function getFilledGuis(): { GuiObject }
		local allguis = {}
		for i,v in pairs(props._containers) do
			for j,f in pairs(v._slotGuiObjs) do
				if not f then continue end
				local filledGui = f:FindFirstChild(IMConstants.FILLED_GUI_NAME)::GuiObject?
				if filledGui then
					table.insert(allguis, filledGui)
				end
			end
		end
		
		return allguis
	end
	
	local function findItemToSplit()
		if splittingActive then return end
		
		local mouse = UIS:GetMouseLocation()

		local guis = getFilledGuis()
		for i = 1, #guis do
			local filledGui = guis[i]
			if not filledGui.Visible or not (filledGui.Parent::GuiObject).Visible then continue end
			local withinGui = IMUtility.IsMouseWithinGui(mouse.X, mouse.Y - inset, filledGui)
			if not withinGui then continue end
			
			local slotIndex = getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number
			split(props, slotIndex, filledGui)

			break
		end
	end
	
	local inputType = IMInput.GetInputType()
	
	if inputType == IMInput.INPUT_MOUSE then
		return UIS.InputBegan:Connect(function(input, gpe)
			if IMInput.IsInputActive(IMInput.SPLIT, input) then
				findItemToSplit()
			end
		end)	
	elseif inputType == IMInput.INPUT_TOUCH then
		return UIS.TouchLongPress:Connect(function(pos, state: Enum.UserInputState)
			if IMInput.IsInputActive(IMInput.SPLIT, state) then
				findItemToSplit()
			end
		end)
	end
	
	return nil
end

local function enableSearchBar(props: _InventoryMakerProps): RBXScriptConnection?
	local configs = props._SEARCH_BAR_CONFIGS
	if not configs then debugPrint("Search bar configs not found; not enabling it") return nil end

	local containers = {}
	for i,v in pairs(props._containers) do
		table.insert(containers, v)
	end

	return IMFilter.ConnectSearchBarEvent(containers, configs.SearchBarInputGui, configs.TransformTextFunc, configs.FilterFunc, props._data)
end

local function enableScrollClosing(props: _InventoryMakerProps): RBXScriptConnection?
	if IMInput.GetInputType() == IMInput.INPUT_TOUCH then return nil end
	
	return UIS.InputChanged:Connect(function(input, gpe)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
		
		closeAllHoverPrompts(props._containers, props._PARENT_CONTAINER_SCREEN_GUI)
		if props._USER_CONTEXT_MENUS and areContextMenusOpened(props._contextMenusOpened) then
			closeContextMenuStack(props, 1)
		end	
	end)
end

local function inventoryOn(props: _InventoryMakerProps): (boolean, boolean)
    if props._dragging then return false, props._toggled end

    props._toggled = true
    InventoryMaker.Toggled = true

    props._scrollCon = enableScrollClosing(props)
    props._searchBarCon = enableSearchBar(props)
    props._splittingCon = enableSplitting(props)
    
    local hotbar = props._containers[IMConstants.CONTAINER_HOTBAR_NAME]
    if hotbar then
        toggleHotbarCollapse(props._data::DATA, hotbar, true)
    end

    return true, props._toggled
end

local function inventoryOff(props: _InventoryMakerProps): (boolean, boolean)
    if props._dragging then return false, props._toggled end
    
    if props._CUSTOM_FILTERS then
		InventoryMaker.Filter(nil)
	end

    props._toggled = false
    InventoryMaker.Toggled = false

    closeAllHoverPrompts(props._containers, props._PARENT_CONTAINER_SCREEN_GUI)

    if props._USER_CONTEXT_MENUS and areContextMenusOpened(props._contextMenusOpened) then
        closeContextMenuStack(props, 1)
    end	
    
    if props._scrollCon and props._scrollCon.Connected then
        props._scrollCon:Disconnect()
    end
    
    if props._searchBarCon and props._searchBarCon.Connected then
        props._searchBarCon:Disconnect()
    end
    
    if props._splittingCon and props._splittingCon.Connected then
        props._splittingCon:Disconnect()
    end
    
    local hotbar = props._containers[IMConstants.CONTAINER_HOTBAR_NAME]
    if hotbar then
        toggleHotbarCollapse(props._data::DATA, hotbar, false)
    end

    if props._activeSlot then
        setActiveSlot(props, nil)
    end

    return true, props._toggled
end

--[[
	Returns true if successful, else false. When the inventory is toggled on, it can be
	interacted with. Also returns the toggled state as the second return value.
]]
local function toggle(props: _InventoryMakerProps): (boolean, boolean)
	if not props._toggled then
		return inventoryOn(props)
	else
		return inventoryOff(props)
	end
end

local function initNewItemAdded(filledGui: GuiObject, slot: GuiObject, item: ITEM_TYPE, c: IMContainer._Container, slotIndex: number, cIndex: number)
    connectFilledGuiEvents(_inventoryMakerProps, filledGui, c)
    
    if not IMContainer.IsBitFlagEnabled(c._flags, InventoryMaker.NO_AUTO_EQUIP) then
        setEquippedItem(_inventoryMakerProps, item, filledGui, c, false, false)
    end
    
    if c._name == IMConstants.CONTAINER_HOTBAR_NAME then
        bindHotbarKey(c, _inventoryMakerProps._data::DATA, slotIndex, cIndex)
    end
end

--[[
    The purpose of this function mainly serves for backwards compatibility. I'm not tryna
    break ppl's data who use the HOTBAR_FILL_FIRST flag. I hope I didn't and do not...
]]
local function stackAddFillHotbarFirst(newItem: ITEM_TYPE): boolean
    local stackOnAdd = true
    local hotbarContainer = _inventoryMakerProps._containers[IMConstants.CONTAINER_HOTBAR_NAME]
    local stackingConfigs = _inventoryMakerProps._STACKING_CONFIGS

    local DATA = _inventoryMakerProps._data::DATA

    for _, name in _inventoryMakerProps._containersIndex do
		local currContainer = _inventoryMakerProps._containers[name]
		if currContainer._currSize >= currContainer._capacity and not stackOnAdd then continue end
		if currContainer._inItemspace == false then continue end
        if currContainer == hotbarContainer then continue end
		
		if not (currContainer::IMContainer._Container):_isItemAllowed(newItem) then continue end
		
		for currSlotIndex = currContainer._invStartIndex, currContainer._invEndIndex do
			local currSlotItem = DATA[currSlotIndex]
			
			if currSlotItem and stackOnAdd and stackingConfigs then
				local canStack, leftover = stackingConfigs._STACK_VALIDATE(currSlotItem, newItem)
				if not canStack then continue end
				if not currContainer._stackingEnabled then 
					debugPrint("Failed to add new item; stacking disabled on container; no stacking will occur.") 
					return false 
				end
				
				local targetSlot = currContainer._slotGuiObjs[IMContainer.GetContainerIndexFromSlotIndex(currContainer::IMContainer._Container, currSlotIndex)]::GuiObject
				local targetIndex = getSlotIndexFromSlot(targetSlot)
				if targetIndex ~= currSlotIndex then continue end

				local ret = stackOnAddItem(
					_inventoryMakerProps::_InventoryMakerProps, 
					stackingConfigs._STACK_UPDATE, 
					currContainer::IMContainer._Container, 
					newItem, 
					currSlotItem, 
					currSlotIndex, 
					leftover
				)
				if not ret then debugWarn("Failed to stack item on add; inventory at full capacity.") end
				return ret
			end
			
			-- adding item in empty slot
			if not currSlotItem then
				DATA[currSlotIndex] = newItem
				_inventoryMakerProps._currSize += 1
				IMContainer.AddItemAtIndex((currContainer::IMContainer._Container), currSlotIndex, newItem, initNewItemAdded)
				if _inventoryMakerProps._CALLBACKS and _inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED then
					_inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED(_inventoryMakerProps._currSize, _inventoryMakerProps._capacity)
				end
				debugPrint("New item added; current size:", _inventoryMakerProps._currSize)
				return true
			end
		end
	end

    if _inventoryMakerProps._currSize == _inventoryMakerProps._capacity then
        debugWarn("Failed to add new item; inventory at full capacity.")
    else
        debugWarn("Failed to add new item; no space available in itemspace.")
    end

    return false
end


-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
-------------------------------------------API-------------------------------------------
-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------


--[[
	Initializes the InventoryMaker module.
	
	Takes in a ScreenGui. This screen gui will be used to contain EVERY UI element
	of your inventory.
]]
function InventoryMaker.Initialize(screenGui: ScreenGui)
	if not screenGui or not screenGui:IsA("ScreenGui") then 
		error("[InventoryMaker]: A ScreenGui is required to initalize the inventory. This single ScreenGui will be used to contain all UI elements.", 2) 
	end
	
	_inventoryMakerProps = {
		_containers = {},
		_containersIndex = {},
		_data = nil,
		_capacity = 0,
		_currSize = 0,
		_toggled = false,
		_activeSlot = nil,
		_boundingBoxes = {},
		_OPEN_HOVER_PROMPT_AFTER_SWAPPING = true,
		_CONTEXT_MENU_MODE = NO_CONTEXT_MENU_MODE,
		_PARENT_CONTAINER_SCREEN_GUI = screenGui,
		_CALLBACKS = {},
	}::_InventoryMakerProps
	
    initialized = true
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end

--[[
	Creates a new container for your inventory. Takes in a name, a capacity, and an optional filtering argument, which describes 
	if you want the container to be affected by the search filter (defaults to true). The `closed` argument describes whether or 
	not it allows its items to be dragged out of the container and items from other containers to be dragged into it (defaults to false).
	
	If a container is named "Hotbar", it will become a hotbar container. Only one hotbar container can exist. A hotbar container
	requires an additional HotbarConfigs when defining its layout with container:DefineLayout().
	
	By default, all containers are open, and allows filtering, dragging, and stacking.
		- open (its items can be dragged out of its container and items from other containers can be dragged into it)
		- filtering (able to be searched through the search bar)
		- dragging (container allows its items to be dragged)
		
	If you want to disable these states, you can target them specifically with the bit flags :D
	- InventoryMaker.CLOSED - no interactions with other containers
	- InventoryMaker.NO_FILTERING - not filtered by search bar
	- InventoryMaker.NO_STACKING (and splitting) - no stacking or splitting allowed in the container
	- InventoryMaker.NO_DRAGGING - no dragging allowed within container (which also disables stacking/splitting)
	- InventoryMaker.HOTBAR_UNTOGGLED_HOVER - allows hover prompt for hotbar container when inventory is toggled off
	- InventoryMaker.HOTBAR_COLLAPSE - allows hotbar container to hide empty slots when not at full capacity
	- InventoryMaker.HOTHBAR_FILL_FIRST - forces hotbar to prioritize filling its slots
    - InventoryMaker.NO_AUTO_EQUIP - prevents new items from being automatically equipped in the container
    - InventoryMaker.NO_EQUIPPED_STATE - disables the equipped state in the container
    - InventoryMaker.NO_SORTING - disables sorting in the container
	
	Combine the bit flags with the "+" operator (usually it would be done with |, but luau doesn't have that). For example:
	
	<code>local c = InventoryMaker.Container("2", 25, InventoryMaker.CLOSED + InventoryMaker.NO_FILTERING)</code>
]]
function InventoryMaker.Container(name: string, capacity: number, flags: number?): Container
	return IMContainer.new(name, capacity, flags or 0)::Container
end

--[[
    Creates a new static container, which is used to render static inventories and 
    allows for the player to interact with it with their inventory.

    The first arg, **name**, should be a unique name for the contianer
    The second arg, **capacity**, is the max size of the inventory.
]]
function InventoryMaker.StaticContainer(name: string, capacity: number): IMStaticContainer.StaticContainer
    return IMStaticContainer.NewStaticContainer(name, capacity)
end

--[[
	NOTE: This module uses <strong>false</strong> to fill in unoccupied slots. This is how
	empty slots are marked.
	
	The method used to populate the inventory with user data.
	Takes in 2 arguments: the inventory object and a populatorFunc callback.
	- The inventory object is self-explanatory.
	- The callback is used to fetch your inventory data and should return that data
	so that the inventory can be POPULATED with the data. If the callback returns
	nil, an empty table will be set for the inventory data
	
	The callback should return two values: the items in the inventory and a max capacity
	of the inventory.
	
    The array of items returned in the populatorFunc must not have gaps; it must be
    contiguous. For example, if your array only has two items that are spaced apart from
    each other, the elements in between must be marked as false.

        -- Allowed:
        local items = {
            { Name = "Item1" },
            false,
            false,
            false,
            false,
            false,
            { Name = "Item2" },
        }

        -- Allowed:
        local items = {
            [1] = { Name = "Item1" },
            [2] = false,
            [3] = false,
            [4] = false,
            [5] = false,
            [6] = false,
            [7] = { Name = "Item2" },
        }

        -- Not Allowed:
        local items = {
            [1] = { Name = "Item1" },
            [7] = { Name = "Item2" },
        }
]]
function InventoryMaker.Populate(populatorFunc: () -> (DATA, number))
	local items, capacity = populatorFunc()
	if items == nil then error("[Inventory]: No data returned; populatorFunc must return a table of items as the first return value.") end
	if not capacity or capacity % 1 ~= 0 or capacity <= 0 then 
		error("[Inventory]: Invalid capacity returned; populatorFunc must return a capacity greater than 0 as the second return value.") 
	end

	_inventoryMakerProps._capacity = capacity

    local data = table.create(capacity, false)::DATA
    for i = 1, capacity do
        local item = items[i]
        if item then
            data[i] = item
        end
    end
    _inventoryMakerProps._data = data
end

--[[
	Builds the inventory using the provided containers, creating the connections between them
	so that they are interactable with each other, setting up any necessary events and whatnot.
	
	The order of containers matters, as it determines which container get initialized first and
	how each slot is organized. For example, if the first container has a capacity of 20, then
	those slots will be 1-20. And if container 2 has a capacity of 25, then its slots will be
	21-45.
	
	This function accepts a second optional argument, which is used to define an Itemspace.
	An Itemspace is the set of containers in which a new item, added with AddItem(), is allowed to
	be added in. By default, if no itemspace is provided, all containers will be included in the itemsapce.
	
	For example, if you build your containers in this order: { c1, c2, c3, c4 }, and your itemspace is 
	{ c2, c3 }, then ny new items added are allowed to only be added in c2, then c3, even if there is space 
	in c1 and c4. Therefore, if c2 and c3 have reached its max capacity, AddItem() will fail to add any more 
	new items, thus returning false.
]]
function InventoryMaker.Build(containers: { IMContainer.Container }, itemspace: { IMContainer.Container }?)
	if not _inventoryMakerProps._data then error("[InventoryMaker]: Data is required to build your inventory.") end
	if not _inventoryMakerProps._data then error("No inventory data to build.") end
	if #containers == 0 then error("[InventoryMaker]: Containers are required to build an inventory.") end
	
    local CONTAINERS: { IMContainer._Container } = containers::{ IMContainer._Container }
    local ITEMSPACE: { IMContainer._Container } = itemspace::{ IMContainer._Container }

	local configs = _inventoryMakerProps._SEARCH_BAR_CONFIGS
	if configs and (not configs.SearchBarInputGui or not configs.TransformTextFunc or not configs.FilterFunc) then
		error("[InventoryMaker]: Search bar configs have missing fields.", 2)
	end
	
	if InventoryMaker.USING_IMS and IMS._CALLBACKS == nil then
		error("[InventoryMaker]: You must define remotes to server with InventoryMaker.IMS.DefineRemotesToServer() in order to build the inventory.")
	end

	local invCapacity = _inventoryMakerProps._capacity
	
	local function onFilledSlotCreated(filledGui: GuiObject, slot: GuiObject, item: ITEM_TYPE, container: IMContainer._Container, slotIndex: number, cIndex: number)
		connectFilledGuiEvents(_inventoryMakerProps, filledGui, container)

        _inventoryMakerProps._currSize += 1
		
		if container._name == IMConstants.CONTAINER_HOTBAR_NAME then
			bindHotbarKey(container, _inventoryMakerProps._data::DATA, slotIndex, cIndex)
		end
	end
	
	local function initHotbarContainer(container: IMContainer._Container)
		toggleHotbarCollapse(_inventoryMakerProps._data::DATA, container, false)
		if container._hotbarConfigs then
			local onKeyPress = container._hotbarConfigs.OnKeyPress

			container._hotbarConfigs.OnKeyPress = function(item: ITEM_TYPE, filledGui: GuiObject, emptyGui: GuiObject, info: ItemPositionInfo)
				if _inventoryMakerProps._dragging then return end
				setEquippedItem(_inventoryMakerProps, item, filledGui, container, false, false)
				onKeyPress(item, filledGui, emptyGui, info)
			end

			IMHotbar.ConnectKeybinds()
            IMHotbar.SetDataRef(_inventoryMakerProps._data::DATA)
            IMHotbar.ConnectScrollingHotbarEvent(container, function(item: ITEM_TYPE?, slotIndex: number)
                local filledGui = IMContainer.GetFilledGuiFromIndex(container, slotIndex)
                setEquippedItem(_inventoryMakerProps, item, filledGui, container, false, true)
            end)
		end
	end
	
	if ITEMSPACE then
		for i = 1, #ITEMSPACE do
			ITEMSPACE[i]._inItemspace = true
		end
	end
	
	-- initialize containers: set start and end indicies and set itemspace boolean
	local lastIndex = 1
	for i = 1, #CONTAINERS do
		local container = CONTAINERS[i]
		
		container._invStartIndex = lastIndex
		container._invEndIndex = lastIndex + container._capacity - 1

		-- all containers are included in the itemspace if no explicit itemspace is provided
		if itemspace == nil then container._inItemspace = true end

		lastIndex = lastIndex::number + container._capacity
	end
	
	lastIndex = 1
	for i,container in ipairs(CONTAINERS) do
		local capacity = container._capacity
		do
			if _inventoryMakerProps._containers[container._name] then
				error(string.format("[InventoryMaker]: A container already exists with the name: %s", container._name), 2)
			end
			if lastIndex > _inventoryMakerProps._capacity then
				error(string.format("[InventoryMaker: Containers collectively exceed inventory capacity of %d.", invCapacity), 2)
			end
			if capacity > invCapacity then 
				error(string.format("[InventoryMaker]: Container '%s' exceeds inventory capacity of %d.", container._name, invCapacity), 2)
			end
			if not container._EMPTY_TEMPLATE then 
				error(string.format("[InventoryMaker]: No gui template for empty slots defined for container (%s).", container._name))
			end
            if not container._CALLBACKS._EQUIPPED_RENDER_FUNC and 
                not IMContainer.IsBitFlagEnabled(container._flags, InventoryMaker.NO_EQUIPPED_STATE) then
                error(string.format("[InventoryMaker]: No EquippedRenderFunc defined for container %s", container._name))
            end
		end
		
		_inventoryMakerProps._containers[container._name] = container
        
		if container._name == IMConstants.CONTAINER_HOTBAR_NAME then 
            IMHotbar.Init(container._capacity) 
        end

		IMContainer.Init(container, _inventoryMakerProps._data, onFilledSlotCreated)
		table.insert(_inventoryMakerProps._containersIndex, container._name)

		if container._name == IMConstants.CONTAINER_HOTBAR_NAME then initHotbarContainer(container::IMContainer._Container) end
		if itemspace == nil then container._inItemspace = true end

		lastIndex = lastIndex + capacity
	end
	
	if _inventoryMakerProps._CALLBACKS and _inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED then
		_inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED(_inventoryMakerProps._currSize, _inventoryMakerProps._capacity)
	end
	
	debugPrint("Inventory built; current size:", _inventoryMakerProps._currSize)
end

--[[
    Builds the static container after it has been configured, and takes in an 
    inventory data to render.
]]
function InventoryMaker.BuildStaticContainer(staticContainer: IMStaticContainer.StaticContainer, staticContainerData: { any })
    IMStaticContainer.InitStaticContainer(staticContainer::IMStaticContainer._StaticContainer, staticContainerData, function(filledGui: GuiObject, containerIndex: number)  
        if IMInput.GetInputType() == IMInput.INPUT_TOUCH then
            filledGui.Active = true
        end
        connectActivatedEventForStaticContainer(staticContainer::IMStaticContainer._StaticContainer, filledGui, containerIndex)
        connectFilledSlotHoverEventsForStaticContainer(_inventoryMakerProps, staticContainer::IMStaticContainer._StaticContainer, filledGui, containerIndex)
    end)
end

--[[
    Calls the :Close() method on the static container and then destroys the 
    container entirely, removing it from memory.
]]
function InventoryMaker.DestroyStaticContainer(staticContainer: IMStaticContainer.StaticContainer)
    local c = staticContainer::IMStaticContainer._StaticContainer
    c:Close()
    IMStaticContainer.DestroyStaticContainer(c)
end

--[[
	Toggles inventory for state modification. If toggled = true,
	inventory items can be interacted with.

    Calls the OnToggledCallback in a separate thread.
]]
function InventoryMaker.ToggleInventory(...: any)
    if charDead then debugWarn("Character is dead; cannot toggle inventory") return end
	if _inventoryMakerProps._data == nil then error("No inventory data to toggle.") end

	local success, toggledState = toggle(_inventoryMakerProps)
    local onToggledCb = _inventoryMakerProps._CALLBACKS._ON_TOGGLED
	if success and onToggledCb then
		task.spawn(onToggledCb, toggledState, ...)
	end
end

--[[
    Toggles the inventory on and calls the OnToggledCallback in a separate thread.
]]
function InventoryMaker.ToggleOn(...: any)
    if charDead then debugWarn("Character is dead; cannot toggle inventory") return end
    if _inventoryMakerProps._toggled then return end
    local success, toggledState = inventoryOn(_inventoryMakerProps)

    local onToggledCb = _inventoryMakerProps._CALLBACKS._ON_TOGGLED
    if success then
        task.spawn(onToggledCb, toggledState, ...)
    end
end

--[[
    Toggles the inventory off and calls the OnToggledCallback in a separate thread.
]]
function InventoryMaker.ToggleOff(...: any)
    if charDead then debugWarn("Character is dead; cannot toggle inventory") return end
    if not _inventoryMakerProps._toggled then return end
    local success, toggledState = inventoryOff(_inventoryMakerProps)

    local onToggledCb = _inventoryMakerProps._CALLBACKS._ON_TOGGLED
    if success then
        task.spawn(onToggledCb, toggledState, ...)
    end
end

--[[
	Inserts a new inventory item in the first empty slot found, and increments the current inventory 
	size. A boolean will be returned indicating if the operation was successful. True if successful, else false.
	
	stackOnAdd determines if you want to automatically stack the new item (true) (if it can be stacked, based on your
	defined configs). Otherwise, it will just be added regularly (false), in the first empty slot.
	
	stackOnAdd defaults to false.
]]
function InventoryMaker.AddItem(newItem: ITEM_TYPE, stackOnAdd: boolean?): boolean
	if not newItem then error("[InventoryMaker]: newItem is nil.", 2) end
	if _inventoryMakerProps._data == nil then error("[InventoryMaker]: No inventory data to add to.") end
    if _inventoryMakerProps._currSize == _inventoryMakerProps._capacity and not stackOnAdd then 
		debugWarn("Inventory at full capacity.") 
		return false
	end
	
	local stackingConfigs = _inventoryMakerProps._STACKING_CONFIGS
	stackOnAdd = if stackOnAdd == nil then false else stackOnAdd

    local fillHotbarFirst = false
	local hotbarContainer = _inventoryMakerProps._containers[IMConstants.CONTAINER_HOTBAR_NAME] or nil
    if hotbarContainer then
        local fillHotbarFirstFlag = IMContainer.IsBitFlagEnabled(hotbarContainer._flags, InventoryMaker.HOTBAR_FILL_FIRST)
        
        if fillHotbarFirstFlag and hotbarContainer._currSize < hotbarContainer._capacity then 
            fillHotbarFirst = true
        end
    end
	
	local itemspaceHitCount = 0
	for _, name in _inventoryMakerProps._containersIndex do
		local currContainer = _inventoryMakerProps._containers[name]
		if currContainer._currSize >= currContainer._capacity and not stackOnAdd then continue end
		if currContainer._inItemspace == false then itemspaceHitCount += 1 continue end
		if fillHotbarFirst and currContainer ~= hotbarContainer then continue end
		
		if not (currContainer::IMContainer._Container):_isItemAllowed(newItem) then continue end
		
		for currSlotIndex = currContainer._invStartIndex, currContainer._invEndIndex do
			local currSlotItem = _inventoryMakerProps._data[currSlotIndex]
			
			if currSlotItem and stackOnAdd and stackingConfigs then
				local canStack, leftover = stackingConfigs._STACK_VALIDATE(currSlotItem, newItem)
				if not canStack then 
                    if currSlotIndex == currContainer._invEndIndex and fillHotbarFirst then
                        return stackAddFillHotbarFirst(newItem)
                    end
                    continue 
                end
				if not currContainer._stackingEnabled then 
					debugPrint("Failed to add new item; stacking disabled on container; no stacking will occur.") 
					return false 
				end
				
				local targetSlot = currContainer._slotGuiObjs[IMContainer.GetContainerIndexFromSlotIndex(currContainer::IMContainer._Container, currSlotIndex)]::GuiObject
				local targetIndex = getSlotIndexFromSlot(targetSlot)
				if targetIndex ~= currSlotIndex then continue end

				local ret = stackOnAddItem(
					_inventoryMakerProps::_InventoryMakerProps, 
					stackingConfigs._STACK_UPDATE, 
					currContainer::IMContainer._Container, 
					newItem, 
					currSlotItem, 
					currSlotIndex, 
					leftover
				)
				if not ret then debugWarn("Failed to stack item on add; inventory at full capacity.") end
				return ret
			end
			
			-- adding item in empty slot
			if (not currSlotItem and fillHotbarFirst) or (not currSlotItem and not stackOnAdd) then
				_inventoryMakerProps._data[currSlotIndex] = newItem
				_inventoryMakerProps._currSize += 1
				IMContainer.AddItemAtIndex((currContainer::IMContainer._Container), currSlotIndex, newItem, initNewItemAdded)
				if _inventoryMakerProps._CALLBACKS and _inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED then
					_inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED(_inventoryMakerProps._currSize, _inventoryMakerProps._capacity)
				end
				debugPrint("New item added; current size:", _inventoryMakerProps._currSize)
				return true
			end
		end
	end

    if stackOnAdd then
        -- failed to find stack to stack new item onto; create a new one instead
        -- if you're using IMS, then this block of code won't ever get called
        return InventoryMaker.AddItem(newItem)
    end
	
	if itemspaceHitCount > 0 then
		debugWarn("Failed to add new item; containers in itemspace at full capacity.")
		return false
	end
	
	
	debugWarn("(Internal): Failed to add new item; max iterations.")
	return false
end

--[[
    Inserts a new item at the specified slotIndex and increments the current inventory size.
    A boolean will be returned indicating the success of the operation.

    stackOnAdd defaults to false if not provided.
]]
function InventoryMaker.AddItemAtIndex(slotIndex: number, newItem: ITEM_TYPE, stackOnAdd: boolean?): boolean
    if not newItem then error("[InventoryMaker]: newItem is nil.", 2) end
	if _inventoryMakerProps._data == nil then error("[InventoryMaker]: No inventory data to add to.") end
	if _inventoryMakerProps._currSize == _inventoryMakerProps._capacity then 
		debugWarn("Inventory at full capacity.") 
		return false
	end

    if slotIndex <= 0 or slotIndex > _inventoryMakerProps._capacity then
        error("[InventoryMaker]: slotIndex out of bounds")
    end

    local targetContainer = getContainerFromSlotIndex(slotIndex, _inventoryMakerProps)::IMContainer._Container
    local containerName = targetContainer._name
    if targetContainer._currSize >= targetContainer._capacity then 
        debugWarn(string.format("Cannot add item at slotIndex %d; container %s at full capacity.", slotIndex, containerName))
        return false
    end

    if not targetContainer:_isItemAllowed(newItem) then 
        debugWarn(string.format("Cannot add item at slotIndex %d; item not allowed in container %s.", slotIndex, containerName))
        return false
    end

    if targetContainer._inItemspace == false then
        debugWarn(string.format("Cannot add item at slotIndex %d; container %s not in itemspace.", slotIndex, containerName))
        return false 
    end

    local stackingConfigs = _inventoryMakerProps._STACKING_CONFIGS
	stackOnAdd = if stackOnAdd == nil then false else stackOnAdd

    local function callback(filledGui: GuiObject, slot: GuiObject, item: ITEM_TYPE, c: IMContainer._Container, slotIndex: number, cIndex: number)
		connectFilledGuiEvents(_inventoryMakerProps, filledGui, c)
		
		if not IMContainer.IsBitFlagEnabled(c._flags, InventoryMaker.NO_AUTO_EQUIP) then
			setEquippedItem(_inventoryMakerProps, item, filledGui, c, false, false)
		end
		
		if c._name == IMConstants.CONTAINER_HOTBAR_NAME then
			bindHotbarKey(c, _inventoryMakerProps._data::DATA, slotIndex, cIndex)
		end
	end

    local itemAtSlot = _inventoryMakerProps._data[slotIndex]
    if not itemAtSlot then
        _inventoryMakerProps._data[slotIndex] = newItem
        _inventoryMakerProps._currSize += 1
        IMContainer.AddItemAtIndex(targetContainer, slotIndex, newItem, callback)
        if _inventoryMakerProps._CALLBACKS and _inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED then
            _inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED(_inventoryMakerProps._currSize, _inventoryMakerProps._capacity)
        end
        debugPrint(string.format("New item at slotIndex %d; current size: %d", slotIndex, _inventoryMakerProps._currSize))
    else
        if not stackOnAdd then
            debugWarn(string.format("Cannot add item at slotIndex %d; item already exists at that slot.", slotIndex))
            return false
        end
        if not stackingConfigs then
            debugWarn(string.format("Cannot add item at slotIndex %d with stackOnAdd; Stacking configs not defined.", slotIndex))
            return false
        end

        local canStack, leftover = stackingConfigs._STACK_VALIDATE(itemAtSlot, newItem)
        if not canStack then
            debugWarn(string.format("Cannot add item at slotIndex %d; failed to pass stack validation.", slotIndex))
            return false
        end
        if targetContainer._stackingEnabled == false then
            debugWarn(string.format("Cannot add item at slotIndex %d; container %s has stacking disabled.", slotIndex, containerName))
            return false
        end

        local res = stackOnAddItem(
            _inventoryMakerProps,
            stackingConfigs._STACK_UPDATE, 
            targetContainer, 
            newItem, 
            itemAtSlot, 
            slotIndex, 
            leftover
        )
        if not res then
            debugWarn(string.format("Failed to add item at slotIndex %d; inventory at full capacity", slotIndex))
            return false
        end
    end

    return true
end

--[[
	Removes the item from the inventory at the slotIndex provided, destroying the filledGui and thus any events connected
	to it, setting the slotIndex of the inventory to false, and decrementing the current inventory size by 1. If the
	item removed was also an equipped item, the equipped cleanup function will be called before the filledGui is
	destroyed, and before the slotIndex is set to false and inventory size decremented.
	
	If the item was part of the hotbar, the key will be unbound as well and the hotbar will collapse the empty slot
	(if the HOTBAR_COLLAPSE flag is set).
	
	A boolean will be returned indicating the operation's success: True if successful, else false.
]]
function InventoryMaker.RemoveItem(slotIndex: number): boolean
	if _inventoryMakerProps._data == nil then error("No inventory data to remove from.") end
	if not _inventoryMakerProps._data[slotIndex] then debugWarn("No item at that index to remove.") return false end
	if _inventoryMakerProps._currSize == 0 then debugWarn("No items in inventory to remove.") return false end
    
    local targetContainer = getContainerFromSlotIndex(slotIndex, _inventoryMakerProps)
    if not targetContainer or slotIndex <= 0 or slotIndex > _inventoryMakerProps._capacity then 
        error("[IMC]: RemoveItem failed; slotIndex out of bounds")
    end

    if isItemActiveSlot(_inventoryMakerProps::_InventoryMakerProps, _inventoryMakerProps._data[slotIndex]) then
        IMContainer.HideHoverPrompt(targetContainer, IMContainer.GetHoverPromptSingleton(targetContainer, _inventoryMakerProps._PARENT_CONTAINER_SCREEN_GUI))
        setActiveSlot(_inventoryMakerProps::_InventoryMakerProps, nil)
    end
    removeEquippedItem(_inventoryMakerProps::_InventoryMakerProps, _inventoryMakerProps._data[slotIndex]::ITEM_TYPE, targetContainer, slotIndex)
    IMContainer.DestroyFilledGui(targetContainer, slotIndex)
    _inventoryMakerProps._data[slotIndex] = false
    _inventoryMakerProps._currSize -= 1
    if targetContainer._name == IMConstants.CONTAINER_HOTBAR_NAME then
        toggleHotbarCollapse(_inventoryMakerProps._data::DATA, targetContainer, _inventoryMakerProps._toggled and true or false)
        unbindHotbarKey(targetContainer, slotIndex)
    end

	if _inventoryMakerProps._CALLBACKS and _inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED then
		_inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED(_inventoryMakerProps._currSize, _inventoryMakerProps._capacity)
	end
	
	debugPrint("Item removed; current size:", _inventoryMakerProps._currSize)

	return true
end

--[[
	Define the same hover prompt configs for all provided containers
]]
function InventoryMaker.DefineHoverPrompts(containers: { IMContainer.Container }, configs: IMContainer.HoverPromptConfigs)
	for i = 1, #containers do
		containers[i]:DefineHoverPrompt(configs)
	end
end

--[[
	Define the same empty slot configs for all provided containers
]]
function InventoryMaker.DefineEmptySlots(containers: { IMContainer.Container }, configs: IMContainer.EmptyConfigs)
	for i = 1, #containers do
		containers[i]:DefineEmptySlot(configs)
	end
end

--[[
	Define the same filled slot configs for all provided containers
]]
function InventoryMaker.DefineFilledSlots(containers: { IMContainer.Container }, configs: IMContainer.FilledConfigs)
	for i = 1, #containers do
		containers[i]:DefineFilledSlot(configs)
	end
end

--[[
	Define the same activated callback for all provided containers 
]]
function InventoryMaker.DefineActivatedCallbacks(containers: { IMContainer.Container }, callback: IMContainer.ActivatedCallback)
	for i = 1, #containers do
		containers[i]:DefineActivatedCallback(callback)
	end
end

--[[
	Define the same OnItemAdded callback for all provided containers
]]
function InventoryMaker.DefineOnItemAddedCallbacks(containers: { IMContainer.Container }, callback: IMContainer.OnItemAddedCallback)
	for i = 1, #containers do
		containers[i]:DefineOnItemAddedCallback(callback)
	end
end

--[[
	Define the same AllowedItems callback for all provided containers
]]
function InventoryMaker.DefineAllowedItems(containers: { IMContainer.Container }, callback: IMContainer.AllowedItemsCallback)
	for i = 1, #containers do
		containers[i]:DefineAllowedItems(callback)
	end
end

--[[
	Context menus are side-prompts that appear when you right-click an item. This function will define context menus for all containers
	(except the Hotbar, because the Hotbar does not allow context menus).
	
	Takes in an array of ContextMenuConfigs, which is a table of configs where you define the properties for a single context menu. 
	Context menus are triggered when right-clicking an item.
	
	In multi-context mode, the entire chain of context menus is rendered on your screen. The first context menu defined in 
	the array is the PCM (primary context menu). The PCM is the context menu that gets opened first when right-click an inventory item. 
	It acts as the anchor to all submenus. All submenus of the PCM are opened as "hovered context menus", which means they remain opened 
	as long as your mouse stays within the bounds of the hovered context menu. The chain of context menus is destroyed when clicking
	out of bounds of the PCM, which closes all context menus.
	
	Unlike multi-context mode, in single-context mode, the chain of context menus only renders one context menu at a time.
	This means only one context can be opened on your screen. So, when you open a submenu, the parent menu gets closed and 
	the submenu gets rendered. Likewise, if you want to go back to the parent menu, the submenu will be closed and the parent
	menu will be rendered again. The first context menu defined in the array of ContextMenuConfigs is the PCM. The PCM is the 
	context menu that gets opened first when right-click an inventory item. It is the first menu in the chain of context menus. 
	The chain of contxt menus is destroyed whenn clicking out of bounds of the currently opened context menu, which closes all
	the context menus.
	
	Multi-context mode is disabled on mobile. So, if you set the mode to multi-context mode, it will default to single-context mode on mobile.
	
	
	GuiTemplate - the GuiObject of your context menu; create your design of what you want your context
	menu to look like, such as adding a TextLabel for a title and TextButton you want clicked to perform
	some action.
	
	Offset - The offset is a UDim2 value that gets added to position the context menu relative to the
	top-right corner of the inventory item gui. You can just ignore this if you want to use the default value.
	
	RenderFunc - a callback that passes in four arguments: the item, the context menu gui, the filledGui, and the containerName. 
	The RenderFunc must return a cleanup function, which gets run when the context menu closes. The cleanup function
	allows you to collect variables that won't be used anymore, such as disconnecting events to avoid memory leaks.
	The RenderFunc is where you can perform logic to determine how you want your context menu to behave. For example, 
	if your template had a button, you can connect an Activated event which when triggered, opens up another context 
	menu that you've defined. Then you return a cleanup function that disconnects that Activated event. 
	- param1 (ITEM_TYPE): the currently active item the context menu is opened for
	- param2 (GuiObject): the gui object for the context menu
	- param3 (GuiObject): the filledGui for the item
	- param4 (string): the name of the container the item is in.
	- return1 (() -> ()): a cleanup function to destroy any objects created or disconnect any events you've connected; it gets
	executd when the menu closes. MEMORY LEAKS, BAD!!!!
	
]]
function InventoryMaker.DefineContextMenus(
	contextMenus: {{
		GuiTemplate: GuiObject,
		Offset: Vector2?,
		RenderFunc: (slotIndex: number, item: ITEM_TYPE, contextMenuGui: GuiObject, filledGui: GuiObject, containerName: string) -> () -> ()
	}}, 
	contextMode: number,
	showHoverPromptNextToMenu: boolean?
)
	if contextMode ~= SINGLE_CONTEXT_MENU_MODE and contextMode ~= MULTI_CONTEXT_MENU_MODE then
		error("[Inventory]: Context mode must either be single-context or multi-context.")
	end
	if #contextMenus == 0 then error("[Inventory]: Why did you pass in an empty contextMenus array? Define a context menu bruh.") end
	for i, configs in ipairs(contextMenus) do
		local template = configs.GuiTemplate
		if not template or not template:IsA("GuiObject") then error(string.format("[Inventory]: GuiTemplate for context menu %d must be a GuiObject.", i)) end
		if not configs.RenderFunc then
			error(string.format("[Inventory]: A render func for context menu %d must be provided when defining a context menu.", i)) 
		end

		local info: _ContextMenuInfo = {
			_TEMPLATE = template,
			_OFFSET = configs.Offset or Vector2.zero,
			_RENDER_FUNC = configs.RenderFunc,
			_GUI = template:Clone()
		}

		info._GUI.Name = "CONTEXT_MENU_"..tostring(i)

		if not _inventoryMakerProps._USER_CONTEXT_MENUS then
			local n = #contextMenus
			;(_inventoryMakerProps::_InventoryMakerProps)._USER_CONTEXT_MENUS = table.create(n, nil::any)
			_inventoryMakerProps._contextMenusOpened = table.create(n+1, nil::any)
			_inventoryMakerProps._contextMenusOpened[1] = { _opened = false, _cleanupFunc = nil }::_OpenedContextMenu
			_inventoryMakerProps._contextMenusStack = {}
		end

		_inventoryMakerProps._USER_CONTEXT_MENUS[i] = info
		_inventoryMakerProps._contextMenusOpened[i+1] = { _opened = false, _cleanupFunc = nil }::_OpenedContextMenu
	end
	_inventoryMakerProps._SHOW_HOVER_PROMPT_NEXT_TO_MENU = showHoverPromptNextToMenu == nil and true or showHoverPromptNextToMenu::boolean
	_inventoryMakerProps._CONTEXT_MENU_MODE = contextMode
	
	if IMInput.GetInputType() == IMInput.INPUT_TOUCH and contextMode == MULTI_CONTEXT_MENU_MODE then
		debugWarn("Multi-context mode disabled on mobile; defaulting to single-context mode.")
		_inventoryMakerProps._CONTEXT_MENU_MODE = SINGLE_CONTEXT_MENU_MODE
	end
end

--[[
	After you've designed and created your search bar, link its text box input to the inventory 
	with this method. Every time a user types in the search bar, the filter will apply to all 
	built containers and that aren't marked with filtering = false.
	
	Configs:
	SearchBarInputGui: your text box gui
	
	TransformTextFunc: a function to transform the text box input; passes in the text and must return the transformed string;
	the transformed string is what gets used to filter the items
	- param1 (string): the string to transform
	- return1 (string): the transformed string
	
	FilterFunc: Defines how you want to filter the items based on the transformed text; return true if it passes the filter, else
	false; passes in the transformed text, and your item data.
	- param1 (string): the transformed string
	- param2 (ITEM_TYPE): the item data that can be used to filter
	- return1 (boolean): return true if it passes the filter, else false
	
	Here's a basic search bar config
	InventoryMaker.DefineSearchBar({ 
		SearchBarInputGui = <your search bar text box gui goes here>
		TransformTextFunc = function(text: string)
			return text
		end,
		FilterFunc = function(text: string, item: ITEM_TYPE)
			local name: string = item.ItemName
			return name:lower():find(text:lower()) ~= nil
		end,
	})
]]
function InventoryMaker.DefineSearchBar(configs: SearchBarConfigs)
	_inventoryMakerProps._SEARCH_BAR_CONFIGS = configs
end

--[[
	Define a callback that gets run when an item is dragged out of a container into empty space.
	Empty space is anywhere on the screen that is not a container.
	
	The callback has 3 parameters:
	- param1 [{ GuiObjec }]: guisAtPosition - an array of guis at the position the drag ended at
	- param2 [ITEM_TYPE]: item - the item being dragged
	- param3 [ItemPositionInfo]: info - position info of the item; it contains the Slotindex, ContainerIndex, and ContainerName
]]
function InventoryMaker.DefineOnDraggedOutCallback(callback: OnDraggedOutCallback)
	_inventoryMakerProps._CALLBACKS._ON_DRAGGED_OUT = callback
end

--[[ 
	Stacking allows you to combine the same type of items into one item to create a "stack." You can
	split this stack by left-clicking while holding down left-control. Stacking does not work with containers 
	that have the NO_DRAGGING flag turned on
	
	Takes in a table of 4 callback functions:
	
	ValidateStackFunc: This callback is used to determine whether can item can be stacked with the targetItem. The callback 
	is executed for each filled slot in the inventory when adding a new item, and whenever you drag an item onto another.
	- param1 (ITEM_TYPE): targetItem (the stack of items)
	- param2 (ITEM_TYPE): currItem (the item that's being dragged/going to be combined with targetItem)
	- return1 (boolean): a value indicating whether to stack (true) or not (false). 
	- return2 (number): the leftover amount after stacking (used for if you require a limit to stacks); 
	return 0 if you don't plan on adding a limit to stacks

	
	UpdateStackFunc: This callback is used to determine how to update items and ui when an item is added to a stack.
	It is your responsibilty to ensure that you update targetItem and oldItem appropriately, as well as the UI.
	- param1 (number): leftover (the leftover amount after stacking; this value is to be used to update currItem)
	- param2 (ITEM_TYPE): a reference to the targetItem (the resulting stack)
	- param3 (ITEM_TYPE): a reference to  the currItem (the item that was added to the stack)
	- param4 (GuiObject): targetFilledGui (the corresponding filled gui for targetItem)
	- param5 (GuiObject?): currFilledGui (the corresponding filled gui for currItem; this param is nil if there are no leftovers)
	
	ValidateSplitFunc: This callback determines if a stack can be split.
	- param1 (ITEM_TYPE): currItem (the current item to check if it can be split)
	- return1 (boolean): return true if it can be split, else false
	
	UpdateSplitFunc: This callback is used to update items and ui when an item is split. It must return the data for
	the new item, and return a cleanup function to undo the updates if the split operation gets canceled.
	- param1 (ITEM_TYPE): currItem (the item that's being split from a stack and dragged to a new slot)
	- param2 (ITEM_TYPE): newItem (a clone of currItem that must be updated to represent the new item that remains in the old slot)
	- param3 (GuiObject): currFilledGui (the corresponding filledGui for currItem)
	- return1 (ITEM_TYPE): the newItem
	- return2 (() -> ()): a cleanup function to undo all the changes and updates when the split operation is canceled
]]
function InventoryMaker.DefineStackingConfigs(configs: {
	ValidateStackFunc: StackingValidateFunc, 
	UpdateStackFunc: StackingUpdateFunc,
	ValidateSplitFunc: SplittingValidateFunc,
	UpdateSplitFunc: SplittingUpdateFunc,
})
	if not configs.ValidateStackFunc then error("[InventoryMaker]: Missing ValidateStackFunc for stacking configs.") end
	if not configs.UpdateStackFunc then error("[InventoryMaker]: Missing UpdateStackFunc for stacking configs.") end
	if not configs.ValidateSplitFunc then error("[InventoryMaker]: Missing ValidateSplitFunc for stacking configs.") end
	if not configs.UpdateSplitFunc then error("[InventoryMaker]: Missing UpdateSplitFunc for stacking configs.") end

	_inventoryMakerProps._STACKING_CONFIGS = {
		_STACK_VALIDATE = configs.ValidateStackFunc,
		_STACK_UPDATE = configs.UpdateStackFunc,
		_SPLIT_VALIDATE = configs.ValidateSplitFunc,
		_SPLIT_UPDATE = configs.UpdateSplitFunc
	}
end

--[[
	Custom filers allow you to filter items based on its properties. It is different from the search bar
	filter because it only requires one function to be defined for each filter.
	
	Takes in a dictionary of filters, with the key as the name of the filter, and value as the function.
	
	Each function passes has 3 parameters and must return a boolean
	- param1 (number): the slot index (its position in the entire inventory)
	- param2 (ITEM_TYPE): the item data
	- param3 (number): the container index (its position relative to its container)
	- return1 (boolean): return true if it passes the filter, else false
]]
function InventoryMaker.DefineCustomFilters(configs: { [string]: IMFilter.CustomFilterFunc })
	for i,v in pairs(configs) do
		if typeof(i) ~= "string" then
			error("[InventoryMaker]: Key must be a string that corresponding to the name of the custom filter function.")
		end
		if typeof(v) ~= "function" then 
			error("[InventoryMaker]: Configs must be a dictionary of functions, where the key is the name of the function, and the value is the function.") 
		end
	end

	_inventoryMakerProps._CUSTOM_FILTERS = configs
end

--[[
	Define a callback to determine whether two items can switch with each other.
    If you're using IMS, ensure the callbacks have the same logic on both the
    server and client.

	The callback has 6 paramters and returns 1 value:
	- param1 (ITEM_TYPE): item1 - the item being dragged
	- param2 (ITEM_TYPE?): item2 - the item being switched with; item2 is nil if it's an empty slot
	- param3 (ItemPositionInfo): position info for item1
	- param4 (ItemPositionInfo): position info for item2
	- return1 (boolean): return true if can switch, else false
]]
function InventoryMaker.DefineSwitchValidation(validateFunc: SwitchValidateFunc)
	_inventoryMakerProps._SWITCH_VALIDATE_FUNC = validateFunc
end

--[[
	Opens up a new context menu for multi-context.

	With the primary context menu opened, this method opens a submenu as a hovered context menu. A hovered context menu is
	closed when the mouse moves of out of its bounding box. It takes in the index of the context menu and a `boundingGui`, 
	which is a GuiObject that is used to calculate the bounding box for the context menu
	
	The index refers to the array position of context menu configs you defined. For example, OpenHoveredContextMenu(2, someExampleGui) 
	will open the second context menu that you defined in DefineContextMenus()
	
	If touch is enabled, multi-context mode is automatically defaulted to single-context mode, causing this function
	to open a static context menu instead.
]]
function InventoryMaker.OpenHoveredContextMenu(containerName: string, menuIndex: number, boundingGui: GuiObject)
	-- this wait allows menus that are currently being closed to close first before a new one is opened with this method.
	-- this current solution is more of a bandaid (not even sure it works for all cases) bc I didn't feel like adding a queue or something atm
	-- concurrency issues, amirite?
	task.wait()
	
	local mouseEnabled = IMInput.GetInputType() == IMInput.INPUT_MOUSE
	
	if not _inventoryMakerProps._activeSlot then error("[Inventory]: Must have an active slot to open a context menu.") end
	if _inventoryMakerProps._CONTEXT_MENU_MODE ~= MULTI_CONTEXT_MENU_MODE and mouseEnabled then 
		error("[Inventory]: Context menu mode must be multi-context to open a hovered context menu.") 
	end
	if menuIndex > #_inventoryMakerProps._USER_CONTEXT_MENUS then error("[Inventory]: Menu index is out of bounds of the defined context menus.") end
	if _inventoryMakerProps._contextMenusOpened[menuIndex+1]._opened then return end
	if menuIndex <= 1 then error("[Inventory]: The primary context menu cannot be submenu; menuIndex be greater than 1 to open a hovered context menu.") end
	if not boundingGui:FindFirstAncestor(_inventoryMakerProps._USER_CONTEXT_MENUS[getLastOpenedMenuIndex(_inventoryMakerProps::_InventoryMakerProps)]._GUI.Name) then
		error("[Inventory]: Bounding gui must be a descendant of the last opened context menu template.")
	end
	
	if mouseEnabled then 
		openHoveredContextMenu(_inventoryMakerProps::_InventoryMakerProps, _inventoryMakerProps._containers[containerName], menuIndex, boundingGui)
	else
		openStaticContextMenu(_inventoryMakerProps::_InventoryMakerProps, _inventoryMakerProps._containers[containerName], menuIndex, false)
	end
end

--[[
	Opens up a new submenu for single-context.
	
	After the primary context has been opened and is in the context menu chain, a submenu can be opened as a static context menu 
	with this method. A static context menu is only closed when explicitly closed with ReturnToParentMenu() or when left-clicking out of bounds.
	This method closes the previous menu and opens this new one. If you want to return to the preview context menu, your
	context menu template at `menuIndex` must be able to call ReturnToParentMenu(). Refer to that method for more info.
	
	The context menu is closed when you left-click out of its bounding boxes.
]]
function InventoryMaker.OpenStaticContextMenu(containerName: string, menuIndex: number)
	if not _inventoryMakerProps._activeSlot then error("[Inventory]: Must have an active slot to open a context menu.") end
	if _inventoryMakerProps._CONTEXT_MENU_MODE ~= SINGLE_CONTEXT_MENU_MODE then error("[Inventory]: Context menu mode must be single-context to open a static context menu.") end
	if menuIndex > #_inventoryMakerProps._USER_CONTEXT_MENUS then error("[Inventory]: Menu index is out of bounds of the defined context menus.") end
	if _inventoryMakerProps._contextMenusOpened[menuIndex+1]._opened then return end
	if menuIndex <= 1 then error("[Inventory]: The primary context menu cannot be a submenu; menuIndex be greater than 1 to open a static context menu.") end
	if not containerName then error("[InventoryMaker]: container name required.", 2) end

	openStaticContextMenu(_inventoryMakerProps::_InventoryMakerProps, _inventoryMakerProps._containers[containerName], menuIndex, false)
end

--[[
	Closes the currently opened submenu for single-context and returns to the parent submenu,
	rendering it again onto the screen.
]]
function InventoryMaker.ReturnToParentMenu(containerName: string)
	if _inventoryMakerProps._CONTEXT_MENU_MODE ~= SINGLE_CONTEXT_MENU_MODE then 
		error("[Inventory]: ReturnToParentMenu() can only be called in single-context mode.")
	end
	if #_inventoryMakerProps._contextMenusStack <= 1 then
		error("[Inventory]: ReturnToParentMenu() can only be called on single-context submenus.")
	end
	if not containerName then error("[InventoryMaker]: container name required.", 2) end

	closeContextMenuStack(_inventoryMakerProps, #_inventoryMakerProps._contextMenusStack)
	openStaticContextMenu(_inventoryMakerProps, _inventoryMakerProps._containers[containerName], getLastOpenedMenuIndex(_inventoryMakerProps), true)
end

--[[
	Closes all context menus and any opened hover prompts with it; clears the entire context menu chain;
	can be used in both context modes.
]]
function InventoryMaker.CloseAllContextMenus()
	closeAllContextMenusAndHoverPrompts(_inventoryMakerProps)
end


--[[
	This function rerenders the item at the specified slot index, updating the filled gui of
	the item based on its item data (ITEM_TYPE). If the data hasn't changed, then the gui
	will of course, remain the same.
	
	If an item cannot be found at the slotIndex, an error will be raised.
]]
function InventoryMaker.RerenderItem(slotIndex: number)
	if _inventoryMakerProps._data == nil then error("InventoryMaker] No data.") end
	if not _inventoryMakerProps._data[slotIndex] then error(string.format("[InventoryMaker]: No item found at slotIndex %d to rerender.", slotIndex)) end
	
	local cIndex = _inventoryMakerProps._containersIndex
	for i = 1, #cIndex do
		local container = _inventoryMakerProps._containers[cIndex[i]]
		if not (slotIndex >= container._invStartIndex and slotIndex <= container._invEndIndex) then continue end
		
		local containerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)
		local filledGui = IMContainer.GetFilledGuiFromIndex(container, slotIndex)::GuiObject
		container._RENDER_FILLED_FUNC(slotIndex, _inventoryMakerProps._data[slotIndex]::ITEM_TYPE, filledGui, containerIndex)
		
		break
	end
end


--[[
	Updates an item at the specified slotIndex using a defined callback. Within this callback, you are allowed
	to update the item's data and any of its UI. The callback has 4 parameters:
	- param1 (ITEM_TYPE): the data for the item
	- param2 (GuiObject): the filled gui of the item
	- param4 (number): the container index of the item
	- param5 (string): the container's name
]]
function InventoryMaker.UpdateItem(slotIndex: number, 
	updateFunc: (item: ITEM_TYPE, filledGui: GuiObject, containerIndex: number, containerName: string) -> ()
)
	if _inventoryMakerProps._data == nil then error("[InventoryMaker] No data.") end
	
	local item = _inventoryMakerProps._data[slotIndex]
	if not item then error(string.format("[InventoryMaker]: No item at slotIndex %d.", slotIndex)) end
	
	-- local cIndicies = _inventoryMakerProps._containersIndex
	local container = getContainerFromSlotIndex(slotIndex, _inventoryMakerProps)::IMContainer._Container
	local filledGui = IMContainer.GetFilledGuiFromIndex(container, slotIndex)::GuiObject
	local containerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex)::number
	
	updateFunc(item, filledGui, containerIndex, container._name)
end


--[[
	Define the same EquippedRenderFunc for all provided containers
]]
function InventoryMaker.DefineRenderEquippedSlots(containers: { Container }, renderFunc: IMContainer.EquippedRenderFunc)
	for i = 1, #containers do
        containers[i]:DefineRenderEquippedSlot(renderFunc)
	end
end


--[[
	This function returns the equipped item and its slotIndex. If no item is equipped,
	nil and 0 is returned
]]
function InventoryMaker.GetEquippedItem(): (ITEM_TYPE?, number)
	if _inventoryMakerProps._data == nil then error("[InventoryMaker] No data.") end
	
	local equippedItem = _inventoryMakerProps._equippedItem
	if not equippedItem then return nil, 0 end
	
	local slotIndex = getSlotIndexFromSlot(equippedItem._filledGui.Parent::GuiObject)::number
	
	return equippedItem._item, slotIndex
end

--[[
	This function allows you to rebind the hotbar keybinds after the inventory has been built.
	Setting new keybinds will rerender the hotbar filled slots
]]
function InventoryMaker.SetHotbarKeybinds(keybinds: IMContainer.HotbarKeybinds)
	local hotbarContainer = _inventoryMakerProps._containers[IMConstants.CONTAINER_HOTBAR_NAME]
	if not hotbarContainer then 
		error("[InventoryMaker]: No hotbar container exists.")
	end

	if not _inventoryMakerProps._data then error("[InventoryMaker]: Data is nil.") end
	
	hotbarContainer:_setHotbarKeybinds(keybinds)
	local data = _inventoryMakerProps._data
	for i = 1, hotbarContainer._capacity do
		local slot = hotbarContainer._slotGuiObjs[i]::GuiObject
		local slotIndex = getSlotIndexFromSlot(slot)::number
		local filledGui = IMContainer.GetFilledGuiFromIndex(hotbarContainer, slotIndex)
		if not filledGui then continue end
		
		bindHotbarKey(hotbarContainer, data, slotIndex, i)
		hotbarContainer._RENDER_FILLED_FUNC(slotIndex, data[slotIndex]::ITEM_TYPE, filledGui, i)
	end
end


--[[
	Takes in a string, which is the name of one of the defined custom filters, and applies the filter to 
	all containers that have filtering enabled.
	
	If the name is not given (aka the name == nil), then the filter will be cleared from the containers.
	
	Filter("rare") - applies the filter that is named "rare"
	Filter(nil) - clears all filters (including the search bar filter)
]]
function InventoryMaker.Filter(customFilterName: string?)
	if not _inventoryMakerProps._CUSTOM_FILTERS then
		error("[InventoryMaker]: No custom filter functions defined to use.")
	end
	if not _inventoryMakerProps._toggled then
		error("[InventoryMaker]: Custom filters can only be applied when inventory is toggled on.")
	end
	
	if customFilterName == nil then
		local cIndices = _inventoryMakerProps._containersIndex
		for i = 1, #cIndices do
			local container = _inventoryMakerProps._containers[cIndices[i]]
			if not container._filteringEnabled then continue end
			IMFilter.ClearFilterFromContainer(container::IMContainer._Container)
		end
		return
	end
	
	local filterFunc = _inventoryMakerProps._CUSTOM_FILTERS[customFilterName]
	local cIndices = _inventoryMakerProps._containersIndex
	for i = 1, #cIndices do
		local container = _inventoryMakerProps._containers[cIndices[i]]
		if not container._filteringEnabled then continue end
		
		IMFilter.ApplyFilterToContainer(container::IMContainer._Container, filterFunc, _inventoryMakerProps._data)
	end
end

--[[
	Increases the capacity of a container by the specified amount. 
	
	Increasing the capacity of a container creates `amount` empty slots at the end of the container, 
	which pushes back all the slots in next containers to make room for the new ones. This will increase 
	indices of those slots while maintaining it's relative position. In other words, the position of items 
	will remain the same. It's just offset to make room for the new empty slots.
]]
function InventoryMaker.IncreaseCapacity(builtContainerIndex: number, amount: number)
	if type(amount) ~= "number" then error("[InventoryMaker]: Amount must be a number.", 2) end
	if amount <= 0 or amount % 1 ~= 0 then error("[InventoryMaker]: Amount must be a non-zero positive integer to increase container capacity.") end
	if #_inventoryMakerProps._containersIndex == 0 then error("[InventoryMaker]: IncreaseCapacity() can only be called after the inventory is built.") end
	if not _inventoryMakerProps._data then error("[InventoryMaker]: No data in inventory to increase capacity for.") end
	
    local targetContainerName = _inventoryMakerProps._containersIndex[builtContainerIndex]
	local targetContainer = _inventoryMakerProps._containers[targetContainerName]
	if not targetContainer then
		error(string.format("[InventoryMaker]: targetContainer (%s) does not exist", targetContainerName))
	end

	local newData = table.create(_inventoryMakerProps._capacity + amount, false)::DATA
	table.move(_inventoryMakerProps._data, 1, targetContainer._invEndIndex, 1, newData)
	table.move(_inventoryMakerProps._data, targetContainer._invEndIndex+1, _inventoryMakerProps._capacity , targetContainer._invEndIndex+1+amount, newData)
	
	IMContainer.AppendNewEmptySlots(targetContainer, amount)
	
	
	-- update the slot UI and container indicies
	local containersIndex = _inventoryMakerProps._containersIndex
	for i = #containersIndex, 1, -1 do
		local c = _inventoryMakerProps._containers[containersIndex[i]]
		--[[
			we don't need to update containers before the targetContainer bc 
			the new slots are added at the end of it; the containers before
			targetContainer are unaffected. So, we only need to worry about
			the containers after targetContainer. 
			
			Since we're looping backwards in the reverse order the containers 
			were built, we can just break once c == targetContainer.
		]]
		if c == targetContainer then break end
		
		local slots = c._slotGuiObjs
		for i = #slots, 1, -1 do
			local slot = slots[i]
			if not slot then continue end
			local oldSlotIndex = getSlotIndexFromSlot(slot)::number
			local newSlotIndex = oldSlotIndex + amount

            unbindHotbarKey(c, oldSlotIndex)
			IMContainer.UpdateSlotIndexOfSlot(c, oldSlotIndex, newSlotIndex)
            bindHotbarKey(c, newData, newSlotIndex, i)
		end

		c._invStartIndex += amount
		c._invEndIndex += amount
	end
	
	_inventoryMakerProps._data = newData
	_inventoryMakerProps._capacity += amount
    IMHotbar.SetDataRef(_inventoryMakerProps._data)
	
	if _inventoryMakerProps._CALLBACKS and _inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED then
		_inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED(_inventoryMakerProps._currSize, _inventoryMakerProps._capacity)
	end
	
	debugPrint(string.format("Container (%s) capacity increased by %d.", targetContainerName, amount))
end

--[[
	Decreases the capcaity of a container by the specified amount.
	
	Decreasing the capacity of a container removes the necessary empty slots in the container,
	searching from the start to the end of the container, pushing all items towards the front
	as a result. Because of this shift, all containers after the targetContainer is shifted
	as well.
	
	Decreasing the capacity does not alter the current size of the container or inventory.
	If it did, that wouldn't make sense, since it would mean deleting items from the
	inventory. 
]]
function InventoryMaker.DecreaseCapacity(builtContainerIndex: number, amount: number)
	if type(amount) ~= "number" then error("[InventoryMaker]: Amount must be a number.", 2) end
	if amount <= 0 or amount % 1 ~= 0 then error("[InventoryMaker]: Amount must be a non-zero positive integer to decrease container capacity.") end
	if #_inventoryMakerProps._containersIndex == 0 then error("[InventoryMaker]: DecreaseCapacity() can only be called after the inventory is built.") end
	if not _inventoryMakerProps._data then error("[InventoryMaker]: No data in inventory to decrease capacity for.") end
	
    local targetContainerName = _inventoryMakerProps._containersIndex[builtContainerIndex]
	local targetContainer = _inventoryMakerProps._containers[targetContainerName]
	if not targetContainer then
		error(string.format("[InventoryMaker]: targetContainer (%s) does not exist", targetContainerName))
	end
	
	-- collapse the targetContainer's capacity by the specified amount, pushing its items to the front
	-- destroy the slots that are collapsed
	-- update the remaining slots
	local newContainerCapacity = targetContainer._capacity - amount
	local newContainerData = table.create(newContainerCapacity, false)::DATA
	local amountLeft = amount
	local newContainerIndex = 1
	local oldContainerIndex = 0
	local prevSlotGuiObjsLen = #targetContainer._slotGuiObjs
	for i = targetContainer._invStartIndex, targetContainer._invEndIndex do
		local item = _inventoryMakerProps._data[i]
		oldContainerIndex += 1
		if not item and amountLeft > 0 then
			amountLeft -= 1
			local slot = targetContainer._slotGuiObjs[oldContainerIndex]::GuiObject
			local slotIndex = getSlotIndexFromSlot(slot)::number
			IMContainer.DestroySlot(targetContainer, slotIndex, true)
			continue
		end
		
		IMContainer.UpdateSlotIndexOfSlot(targetContainer, oldContainerIndex, newContainerIndex)
		
		newContainerData[newContainerIndex] = item
		newContainerIndex += 1
	end
	
	IMContainer.ReconcileSlotGuiObjs(targetContainer, prevSlotGuiObjsLen, amount)
	
	-- copy over data to smaller array 
	local newData = table.create(_inventoryMakerProps._capacity - amount, false)::DATA
	table.move(_inventoryMakerProps._data, 1, targetContainer._invStartIndex-1, 1, newData)
	table.move(newContainerData, 1, newContainerCapacity, targetContainer._invStartIndex, newData)
	table.move(_inventoryMakerProps._data, targetContainer._invEndIndex+1, _inventoryMakerProps._capacity, targetContainer._invEndIndex+1-amount, newData)
	
	
	-- update the slot UI and container indicies
	targetContainer._invEndIndex -= amount

	local containersIndex = _inventoryMakerProps._containersIndex
	for i = #containersIndex, 1, -1 do
		local c = _inventoryMakerProps._containers[containersIndex[i]]
		if c == targetContainer then break end -- don't need to update indices for targetContainer, since we already did it above.
		
		--[[
			we don't need to update containers before the targetContainer bc 
			when we decrease the capacity, only the containrs after it are
			affected, since they are pushed forwards. So, we only need to 
			worry about the containers after targetContainer. 
		]]
		local slots = c._slotGuiObjs
		for i = #slots, 1, -1 do
			local slot = slots[i]
			if not slot then continue end
			
			local oldSlotIndex = getSlotIndexFromSlot(slot)::number
			local newSlotIndex = oldSlotIndex - amount
			
            unbindHotbarKey(c, oldSlotIndex)
			IMContainer.UpdateSlotIndexOfSlot(c, oldSlotIndex, newSlotIndex)
            bindHotbarKey(c, newData, newSlotIndex, i)
		end

		c._invEndIndex -= amount
		c._invStartIndex -= amount
	end
	
	targetContainer._capacity = newContainerCapacity
	_inventoryMakerProps._data = newData
	_inventoryMakerProps._capacity -= amount
    IMHotbar.SetDataRef(_inventoryMakerProps._data)
	
	if _inventoryMakerProps._CALLBACKS and _inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED then
		_inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED(_inventoryMakerProps._currSize, _inventoryMakerProps._capacity)
	end
	
	debugPrint(string.format("Container (%s) capacity decreased by %d:\n\tNew Capacity=%d", targetContainerName, amount, _inventoryMakerProps._capacity))
end

--[[
	Define a callback that gets run when the size and capacity of the inventory changes.
	The callback passes in the changed size and capacity of the inventory
	
	This callback gets called initially when the inventory is built with .Build(), and
	then gets called whenever the current size of the inventory changes:
		- a new item is added
		- an item is removed
		- a new stack with 0 leftovers is created
		- a new split item is created
]]
function InventoryMaker.DefineOnSizeChangedCallback(callback: OnSizeChangedCallback)
	_inventoryMakerProps._CALLBACKS._ON_SIZE_CHANGED = callback
end

--[[
	Returns the reference to the item at the slotIndex or returns false if it's an empty slot,
    and returns the slotGui and filledGui.
]]
function InventoryMaker.GetItem(slotIndex: number): (ITEM_TYPE | false, GuiObject?, GuiObject?)
	if _inventoryMakerProps._data == nil then error("No inventory data.") end
    if slotIndex < 1 or slotIndex > _inventoryMakerProps._capacity then error("slotIndex out of bounds") end

    local targetContainer = getContainerFromSlotIndex(slotIndex, _inventoryMakerProps)
    if not targetContainer then return false, nil, nil end

    local slotGui = IMContainer.GetSlotFromSlotIndex(targetContainer, slotIndex)
    local filledGui = IMContainer.GetFilledGuiFromIndex(targetContainer, slotIndex)
    local item = _inventoryMakerProps._data[slotIndex]
	
	return item, slotGui, filledGui
end

-- Return inventory current size
function InventoryMaker.Size(): number
	return _inventoryMakerProps._currSize
end

-- Returns inventory capacity
function InventoryMaker.Capacity(): number
	return _inventoryMakerProps._capacity
end


--[[
	Returns the reference to the underlying array of your inventory data, which contains the empty and filled slots. 
	Empty slots are marked with `false` and filled slots contain the data you passed in. The index of each
	element represents the position in the inventory, aka the slot index.
	
	Foe example, if your schema looks like this:
	type Item = {
		ItemName: string,
		ItemDescription: string
		ItemType: number,
	}
	
	then the returned data will look like this:
		type Data = { Item | false }
		local someData: Data = { item1, item2, item3, <strong>false</strong>, item4, <strong>false</strong>, item5 }
	
]]
function InventoryMaker.Items(): DATA
	if _inventoryMakerProps._data == nil then error("No inventory data to send.") end

	return _inventoryMakerProps._data
end


--[[
	This function allows you to define a table of sorter functions,
	each of which can be used to sort items in containers.
]]
function InventoryMaker.DefineCustomSorters(sorters: { [string]: Sorter })
	_inventoryMakerProps._CUSTOM_SORTERS = sorters
end

--[[
	Applies the sorter function to all containers that do not have
	the NO_SORTING flag enabled.
	
	The sorter function sorts items within its container; it is not a 
	global sort, as that would violate the purpose of containers.
	Sorting pushes all the empty slots to the end of the container.
	
	Sorting is considered a destructive operation, in that the effects
	cannot be undone, unlike filters. 
]]
function InventoryMaker.Sort(sorterName: string, ...: any)
	local data = _inventoryMakerProps._data
	local sort = _inventoryMakerProps._CUSTOM_SORTERS[sorterName]
	if not sort then error(string.format("[InventoryMaker]: Sorter %s does not exist.", sorterName)) end
	if not data then error("[InventoryMaker]: No data.") end
	
	local varargs = table.unpack({...})
	local containersIndex = _inventoryMakerProps._containersIndex
	local containers = _inventoryMakerProps._containers
	
    local sortedCount = 0
	for i = 1, #containersIndex do
		local container = containers[containersIndex[i]]
        if IMContainer.IsBitFlagEnabled(container._flags, InventoryMaker.NO_SORTING) then continue end
		if container._currSize <= 0 then continue end -- don't need to sort containers that have no items
        local isHotbarContainer = container._name == IMConstants.CONTAINER_HOTBAR_NAME
		
		local tempSubarr = table.move(data, container._invStartIndex, container._invEndIndex, 1, {}::DATA)

		table.sort(tempSubarr, function(a: ITEM_TYPE | false, b: ITEM_TYPE | false)
			if not a then return false end
			if not b then return true end
			return sort(a, b, varargs)
		end)

        for si = container._invStartIndex, container._invEndIndex do
            if isHotbarContainer then
                unbindHotbarKey(container, si)
            end
        end

		table.move(tempSubarr, 1, #tempSubarr, container._invStartIndex, data)
		
        sortedCount += 1

		--[[
			In order to rerender the filled guis:
				1. collect the filled guis into an array--all the guis will naturally be
					in front of the array because all the empty slots are at the end of the container
				2. loop from the start and end of the container, while keeping track of the container index
				3. get the filled gui and sorted item using the container index
				4. rerender the filled gui with the data from the sorted item
				5. reparent the filled gui to the slot at the container index
				5. break when there's no more filled guis
				
            Note - Consequences of how we rerender the sorted items:
                Because we are overwriting over the existing filledGuis, it will
                be rendered with the new item data and moved into the correct slot.
                This means, we'll be able to retrieve the item from a filledGui,
                using the slot it's parented to. This is why we have the function
                getItemFromFilledGui() defined above for us to use throughout IMC.

                We no longer can rely on passing the item reference directly to all
                our functions, since it depends on the filledGui being the same. 
                Hence, getItemFromFilledGui().

                We could avoid all this by destroying all the filledGuis and creating
                new ones for the sorted items, but that is too much. Why create when
                we can reuse.

                We also need to handle how the equipped item is rendered. We need to
                save the equip filledGui and make sure we're using it to render
                the data belonging to the equipped item.

                Before sort: B C A
                                 ^ - equipped
                          
                After sort: A B C
                            |   ^ - equipped filled gui: this is wrong
                            ^ - actual equipped item

                After sort: A B C
                            ^ - equipped: this is right

		]]
		
        local equippedItem = _inventoryMakerProps._equippedItem
        local notEquippedFilledGui: GuiObject? = nil
        local notEquippedSlotIndex: number? = nil
        local actualEquippedSlotIndex: number? = nil

        local ci = 1
		for si = container._invStartIndex, container._invEndIndex do
			local filledGui = IMContainer.GetFilledGuiFromIndex(container, si)
            if not filledGui then continue end

            local newSlotIndex = container._invStartIndex + ci - 1
            local slot = IMContainer.GetSlotFromSlotIndex(container, newSlotIndex)
            container._RENDER_FILLED_FUNC(newSlotIndex, tempSubarr[ci]::ITEM_TYPE, filledGui, ci)
            filledGui.Parent = slot
            
            if isHotbarContainer then
                bindHotbarKey(container, data, newSlotIndex, ci)
            end

            if equippedItem and equippedItem._item == tempSubarr[ci] then
                actualEquippedSlotIndex = newSlotIndex
                notEquippedFilledGui = filledGui
            end
            if equippedItem and equippedItem._filledGui == filledGui then
                notEquippedSlotIndex = newSlotIndex
            end

            ci += 1
		end

        if not equippedItem then continue end
        if notEquippedFilledGui and actualEquippedSlotIndex and notEquippedSlotIndex then
            local equippedFilledGui = equippedItem._filledGui
            if notEquippedFilledGui == equippedFilledGui then continue end
            
            notEquippedFilledGui.Parent, equippedFilledGui.Parent = 
                equippedFilledGui.Parent, notEquippedFilledGui.Parent

            local equippedCi = IMContainer.GetContainerIndexFromSlotIndex(container, actualEquippedSlotIndex)
            local notEquippedCi = IMContainer.GetContainerIndexFromSlotIndex(container, notEquippedSlotIndex)
            
            container._RENDER_FILLED_FUNC(
                actualEquippedSlotIndex, 
                data[actualEquippedSlotIndex]::ITEM_TYPE, 
                equippedFilledGui, 
                equippedCi
            )

            container._RENDER_FILLED_FUNC(
                notEquippedSlotIndex, 
                data[notEquippedSlotIndex]::ITEM_TYPE, 
                notEquippedFilledGui, 
                notEquippedCi
            )

            if isHotbarContainer then
                bindHotbarKey(container, data, actualEquippedSlotIndex, equippedCi)
                bindHotbarKey(container, data, notEquippedSlotIndex, notEquippedCi)

                local emptyGui = equippedItem._filledGui.Parent::GuiObject
                local si = getSlotIndexFromSlot(emptyGui)::number

                if si >= container._invStartIndex and si <= container._invEndIndex then
                    IMHotbar.RefreshScrollIndex(container, si)
                end
            end

        end
    end

    local sortIMSFunc = (IMS._CALLBACKS::RemoteCallbacks).OnSort
    if sortedCount >= 1 and sortIMSFunc then
        task.spawn(sortIMSFunc, sorterName, varargs)
    end
end

--[[
    Define a callback that gets called when the inventory is toggled on and off.
]]
function InventoryMaker.DefineOnToggledCallback(callback: OnToggledCallback)
    _inventoryMakerProps._CALLBACKS._ON_TOGGLED = callback
end

--[[
    Equips the item at the slotIndex. 
    - If there is no item at the slotIndex, this function will do nothing. 
    - If the slotIndex is **nil**, the item that is currently equipped will be unequipped;
    if no item is equipped, then this function will do nothing.
    - If there is an item at the slotIndex, and it is already the equipped item, this
    function will do nothing.
]]
function InventoryMaker.SetEquippedItem(slotIndex: number?)
    local data = _inventoryMakerProps._data::DATA
    
    local equippedItem = _inventoryMakerProps._equippedItem
    if slotIndex == nil then
        if not equippedItem then return end
        
        local filledGui = equippedItem._filledGui
        local equippedItemSlotIndex = getSlotIndexFromSlot(filledGui.Parent::GuiObject)::number
        local targetContainer = getContainerFromSlotIndex(equippedItemSlotIndex, _inventoryMakerProps)::IMContainer._Container

        setEquippedItem(_inventoryMakerProps, equippedItem._item, filledGui, targetContainer, false, false)
    else
        local item = data[slotIndex]
        if not item then return end

        -- do nothing if the item is already the equipped item
        if equippedItem and equippedItem._item == item then return end

        local targetContainer = getContainerFromSlotIndex(slotIndex, _inventoryMakerProps)::IMContainer._Container
        local filledGui = IMContainer.GetFilledGuiFromIndex(targetContainer, slotIndex)

        setEquippedItem(_inventoryMakerProps, item, filledGui, targetContainer, false, false)
    end
end

-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
-----------------------------------IMS API for IMC---------------------------------------
-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
InventoryMaker.IMS = {}::{ 
    --[[
        Define a table of callbacks which get run when an important operation successfully completed. This is meant to be
        used to allow the developer to fire their remotes to the server so that the server can update their inventory.
        These operations include:
        - Switching
        - Stacking
        - Splitting
        - Equipping
        - Sorting

        These operations, by design, are able to afford having their remotes being 
        sent by the client because they only rearrange the inventory data that already 
        exists. Any exploiter that messes with the remotes would only be inconveniencing 
        themselves. The server operate on their own defined configs which matches that of 
        the client's, which ensures data integrity. 
        
        ---
        **Callbacks**
        
        OnSwitch: A callback that gets run when a new item is successfully switched.
        - param1 [number]: slotIndex1 - slotIndex for the current item
        - param2 [number]: slotIndex2 - slotIndex for the item to be switched

        OnStack: A callback that gets run when an item has been stacked with another
        - param1 [number]: targetSlotIndex - slotIndex for the target item/the stack that's being dragged into
        - param2 [number]: currSlotIndex - slotIndex for the current item that's being dragged into the stack at targetSlotIndex
        
        OnSplit: A callback that gets run when a stack has been split and the split item has been moved to another slot
        - param1 [number]: newSlotIndex - slotIndex for item that was split from the stack and was moved to a new slot
        - param2 [number]: splitSlotIndex - slotIndex for the stack that was split
        
        OnEquip: A callback that gets run when an equipped item is set, including if it's set to nil, which will unequip the current item.
        - param1 [number?]: slotIndex - the slotIndex of the equipped item; if nil, the current equipped item will be set to nil
        
        OnSort: A callback that gets run when a sorter is executed
        - param1 [string]: sorterName - the name of the sorter used
        - param2 [...any]: the variadic argument passed from .Sort()
    ]]
    DefineRemotesToServer: (callbacks: RemoteCallbacks) -> () 
}

function InventoryMaker.IMS.DefineRemotesToServer(callbacks: RemoteCallbacks)
	if not InventoryMaker.USING_IMS then error("[InventoryMaker]: Cannot use IMS functions; USING_IMS mode is not enabled.") end
	
	IMS._CALLBACKS = callbacks
end


-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------


--[[
    Resets the inventory, toggling the inventory off and setting the 
    inventory's temporary states to its default values. This is to be 
    used when the character dies.
]]
local function resetInventory()
    InventoryMaker.ToggleOff()
    local equippedItem = _inventoryMakerProps._equippedItem
    if equippedItem then
        local emptyGui = equippedItem._filledGui.Parent::GuiObject
        local slotIndex = getSlotIndexFromSlot(emptyGui)::number
        local containerName = getContainerNameFromSlot(emptyGui)
        local container = _inventoryMakerProps._containers[containerName]
        local info: ItemPositionInfo = {
            SlotIndex = slotIndex,
            ContainerIndex = IMContainer.GetContainerIndexFromSlotIndex(container, slotIndex),
            ContainerName = containerName
        }
        equippedItem._cleanupFn(equippedItem._item, equippedItem._filledGui, emptyGui, info)
        _inventoryMakerProps._equippedItem = nil
    end
end

local function initCharDeathEvent(char: Model)
    local humanoid = char:WaitForChild("Humanoid", 5)::Humanoid?
    if humanoid then
        humanoid.Died:Once(function()
            resetInventory()
            charDead = true
        end)
    end
end

player.CharacterAdded:Connect(function(newChar: Model)
    initCharDeathEvent(newChar)
    charDead = false
    if initialized then
        resetInventory()
    end
end)

if player.Character then
    initCharDeathEvent(player.Character)
end






return InventoryMaker
