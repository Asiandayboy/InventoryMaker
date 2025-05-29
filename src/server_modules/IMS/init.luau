--!strict
--!nolint SameLineStatement

--[[ InventoryMaker

	Created by: robloxdestroyer1035
	Version: v1.2.0
	Last Updated: 5/29/25

	-----------------------------------------------------------------------------
	InventoryMakerServer (IMS)
	-----------------------------------------------------------------------------
    v1.2.0 Update Log (5/29/25)
        - [New Method]: Inventory:DefineSwitchValidation()
        - [New Method]: Inventory:DefineOnSwitched()
        - [New Feature]: Sorting
            - [New Method]: Inventory:DefineCustomSorters()
            - [New Method]: Inventory:Sort()
            - [New Flag]: IMS.NO_SORTING - disables sorting in the container
        - [New Method]: IMS.Reset() - resets the inventory's temporary states; MUST be called when character dies and respawns
        - [Changed]: All the callbacks for stacking confgs now pass in the player as the first argument
        - [Changed]: :AddItem() now automatically creates a new item, when stackOnAdd = true, if a stack cannot be found 

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

local IMS = {
    DEBUG_PRINT_MESSAGES 	= true,

    --[[
        Prevents the container from interacting with other containers
    ]]
	CLOSED 					= 0b1,

    --[[
        Disables stacking in the container
    ]]
	NO_STACKING 			= 0b10,

    --[[
        Forces the hotbar container to prioritize filling its slots
    ]]
	HOTBAR_FILL_FIRST		= 0b100,

    --[[
        Prevents new items added to the contianer from being auto-equipped
    ]]
	NO_AUTO_EQUIP			= 0b1000,

    --[[
        Disables the equipped state in the container
    ]]
	NO_EQUIPPED_STATE		= 0b10000,

    --[[
        Disables sorting in the container
    ]]
    NO_SORTING              = 0b100000,
}

local EMPTY_SLOT = false
local MSG_PREFIX = "[InventoryMaker (IMS)]"
local HOTBAR_CONTAINER_NAME = "Hotbar"

----------------------------------------------------------------------------------
--------------------------[DEFINE YOUR CUSTOM ITEM TYPE]--------------------------
----------------------------------------------------------------------------------

--[[
	This ITEM_TYPE will help improve your typechecking for your items (ITEM_TYPE)
	
	Define the schema of your type here. This type should represent what each item 
	looks like. You can store anything you want.
	
	Don't change the name tho, thanks!
]]
export type ITEM_TYPE = {
	ItemData: { 
		ItemID: number,
		Quantity: number,
		Metadata: { [string]: any } 
	},
	ItemName: string,
	ItemDescription: string,
	ItemType: string,
	InstanceName: string?,
}

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

type Table = { [any]: any }

local function isBitFlagEnabled(flags: number, bitFlag: number): boolean
	return bit32.band(flags, bitFlag) == bitFlag
end

local function deepCopyTable(t: Table)
	local copy = {}

	for k,v in pairs(t) do
		if type(v) == "table" then
			copy[k] = deepCopyTable(v::Table)
		else
			copy[k] = v
		end
	end
	return copy
end

local function debugPrint(msg: string, ...: any)
	if IMS.DEBUG_PRINT_MESSAGES then
		print(string.format("%s: %s", MSG_PREFIX, msg), ...)
	end
end

local function debugWarn(msg: string, ...: any)
	if IMS.DEBUG_PRINT_MESSAGES then
		warn(string.format("%s: %s", MSG_PREFIX, msg), ...)
	end
end

local function throwError(msg: string, errorLevel: number?)
	error(string.format("%s: %s", MSG_PREFIX, msg), if errorLevel == nil then 1 else errorLevel)
end

----------------------------------------------------------------------------------

export type AllowedItemsCallback = (item: ITEM_TYPE) -> boolean
export type Container = {
	DefineAllowedItems: (self: Container, callback: AllowedItemsCallback) -> (),
	Destroy: (self: Container) -> ()
}
type _Container = Container & {
	_name: string,
	_capacity: number,
	_flags: number,
	_currSize: number,
	_inItemspace: boolean,
	_CALLBACKS: { [string]: (item: ITEM_TYPE) -> boolean },
	_invStartIndex: number,
	_invEndIndex: number,
	
	_InitIndicies: (self: _Container, startIndex: number) -> (),
	_IsItemAllowed: (self: _Container, item: ITEM_TYPE) -> boolean,
}

local function newContainer(name: string, capacity: number, flags: number): _Container
	local props = {
		_name = name,
		_capacity = capacity,
		_flags = flags,
		_currSize = 0,
		_inItemspace = false,
		_CALLBACKS = {
			_ALLOWED_ITEMS_FUNC = function(item: ITEM_TYPE) return true end
		},
		_invStartIndex = 0,
		_invEndIndex = 0,
	}
	
	function props:_InitIndicies(startIndex: number)
		self._invStartIndex = startIndex
		self._invEndIndex = startIndex + self._capacity::number - 1
	end
	
	function props:_IsItemAllowed(item: ITEM_TYPE): boolean
		return self._CALLBACKS._ALLOWED_ITEMS_FUNC(item)
	end
	
	--[[
		The AllowedItemsCallback is where you can define logic to determine which items
		are allowed in the container. The callback has 1 param and should return 1 value
		- param1 [ITEM_TYPE]: item - the item to validate
		- return1 [boolean]: - a boolean value indicating if the item is allowed in the container or not
	]]
	function props:DefineAllowedItems(callback: AllowedItemsCallback)
		self._CALLBACKS._ALLOWED_ITEMS_FUNC = callback
	end
	
	function props:Destroy()
		table.clear(self._CALLBACKS)
		table.clear(self)
	end


	return props::_Container
end

local function getContainerFromSlotIndex(builtContainers: { _Container }, slotIndex: number): _Container
	local container: _Container
	for i = 1, #builtContainers do
		local c = builtContainers[i]
		
		if slotIndex >= c._invStartIndex and slotIndex <= c._invEndIndex then
			container = c
			break
		end
	end
	
	return container
end

local function getContainerIndexFromSlotIndex(container: _Container, slotIndex: number): number
    return slotIndex - container._invStartIndex + 1
end

----------------------------------------------------------------------------------

local Inventory = {}
type _DATA = { ITEM_TYPE | false }
export type Inventory = {
    --[[
        A user-defiend table to store any additional info
    ]]
    Metadata: { [any]: any },
    --[[
		Builds the inventory using the provided containers, creating the connections between them
		so that they are interactable with each other, setting up any necessary events and whatnot.
		
		The order of containers matters, as it determines which container get initialized first and
		how each slot is organized. For example, if the first container has a capacity of 20, then
		those slots will be 1-20. And if container 2 has a capacity of 25, then its slots will be
		21-45.
		
		This function accepts a second optional argument, which is used to define an Itemspace.
		An itemspace is the set of containers in which a new item, added with AddItem(), is allowed to
		be added in. By default, if no itemspace is provided, all containers will be included in the itemsapce.
		
		For example, if you build your containers in this order: { c1, c2, c3, c4 }, and your itemspace is 
		{ c2, c3 }, then any items added are allowed to only be added in c2, then c3, even if there is space 
		in c1 and c4. Therefore, if c2 and c3 have reached its max capacity, AddItem() will fail to add any 
		more new items, thus returning false.
		
		When the inventory is built, the initial inventory data will also respect the itemspace as well
		as the containers' allowed items.
	]]
    Build: (self: Inventory, containers: { Container }, itemspace: { Container }) -> (),

    --[[
		Adds a new item, searching through the containers in the order they were built, 
		to find the first empty slot to add the new item in. Only containers in the 
		itemspace are considered. 
		
		If the inventory is at full capacity, this method will return false.
		If the container does not allow the item, this method will return false.
		
		stackOnAdd defaults to false if it's not provided. If stackOnAdd is true,
        the new item will attempt to find a stack based on the ValidateStackFunc
        to stack onto. If it cannot find a stack, the new item will default to 
        being added in the first empty slot, calling AddItem() again, but with 
        stackOnAdd set to false.
	]]
    AddItem: (self: Inventory, newItem: ITEM_TYPE, stackOnAdd: boolean?) -> boolean,

    --[[ 
		Increases the capacity of the container by the amount, pushing all items after it to make
		room for the new empty slots.
		
		When increasing inventory size, make sure the server is the one to inform the client of
		this intent, and not the other way around.
	]]
    IncreaseCapacity: (self: Inventory, buildContainerIndex: number, amount: number) -> (),

    --[[
		Decrease the capcaity of a container by the amount; decreasing the capcaity does NOT
		decrease the current size. If we did that, then that would mean removing items, which 
		we don't want.
		
		When decreasing capacity, make sure the server is the one to inform the client of
		this intent, and not the other way around.
	]]
    DecreaseCapacity: (self: Inventory, buildContainerIndex: number, amount: number) -> (),

    --[[
		Removes the item at the specified slotIndex, setting the slot to an empty slot
		and decrementing the inventory size by 1. 

        If the removed item was the equipped item, then the current equipped item will be
        set to nil.
	]]
    RemoveItem: (self: Inventory, slotIndex: number) -> (),

    --[[
		Switches the item at slotIndex1 (item1) with the item at slotIndex2 (item2).
		item1 is the item being dragged; item2 is the target item to be switched
	]]
    Switch: (self: Inventory, slotIndex1: number, slotIndex2: number) -> (),

    --[[
		targetSlotIndex: the slotIndex for the target stack
		currSlotIndex: the slotIndex for the item being dragged to the stack
	]]
    Stack: (self: Inventory, targetSlotIndex: number, currSlotIndex: number) -> (),

    --[[
		newSlotIndex: the item being dragged and was just split from the stack, being dragged to its NEW slot
		splitSlotIndex: the slotIndex for the stack that has just been split
	]]
    Split: (self: Inventory, newSlotIndex: number, splitSlotIndex: number) -> (),

    --[[
		Sets an equipped item given the slotIndex of the item. If the item at the slotIndex is an empty slot,
		nothing will happen.
		
		If the slotIndex is nil, then the equipped item will be cleared.
	]]
    SetEquippedItem: (self: Inventory, slotIndex: number?) -> (),

    --[[ 
		Returns the equipped item or nil if there isn't one. Remember that this is a logical
		state, which means it does not handle the physical equipping of items.
	]]
    GetEquippedItem: (self: Inventory) -> ITEM_TYPE?,

    --[[ 
        Returns the reference to the underlying inventory data array 
    ]]
    Items: (self: Inventory) -> _DATA,

    --[[ 
        Returns the inventory's current size 
    ]]
    Size: (self: Inventory) -> number,

    --[[ 
        Returns the inventory's capacity
    ]]
    Capacity: (self: Inventory) -> number,

    --[[ 
        Links the given player to the inventory. Setting the player is necessary to 
        build the inventory. 
    ]]
    SetPlayer: (self: Inventory, player: Player) -> (),

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

        ValidateSplitFunc: This callback determines if a stack can be split.
        - param1 (ITEM_TYPE): currItem (the current item to check if it can be split)
        - return1 (boolean): return true if it can be split, else false
        
        UpdateSplitFunc: This callback is used to update items and ui when an item is split. It must return the data for
        the new item, and return a cleanup function to undo the updates if the split operation gets canceled.
        - param1 (ITEM_TYPE): currItem (the item that's being split from a stack and dragged to a new slot)
        - param2 (ITEM_TYPE): newItem (a clone of currItem that must be updated to represent the new item that remains in the old slot)
        - return1 (ITEM_TYPE): the newItem
        - return2 (() -> ()): a cleanup function to undo all the changes and updates when the split operation is canceled
    ]]
    DefineStackingConfigs: (self: Inventory, configs: StackingConfigs) -> (),

    --[[
        This function allows you to define a table of sorter functions,
        each of which can be used to sort items in containers.

        When defining your custom sorters, make sure the client and server
        versions have the exact same logic to ensure data integrity.
    ]]
    DefineCustomSorters: (self: Inventory, sorters: { [string]: Sorter }) -> (),

    --[[
        Applies the sorter function to all containers that do not have
        the NO_SORTING flag enabled.
        
        The sorter function sorts items within its container; it is not a 
        global sort, as that would violate the purpose of containers.
        Sorting pushes all the empty slots to the end of the container.
        
        Sorting is considered a destructive action, in that the effects
        cannot be undone, unlike filters. 
    ]]
    Sort: (self: Inventory, sorterName: string, ...any) -> (),

    --[[
		Define a table of callbacks which get run when an important operation successfully completed. This is meant to be
		used to allow the developer to fire their remotes to the client so that the client can update their inventory.
		
		OnAdd: A callback that gets run when a new item is successfully added.
        - param1 [ITEM_TYPE]: newItem - the new item added
        - param2 [boolean]: stackOnAdd - a boolean that determines whether or not the new item is to be stacked
		
		OnIncreaseCap: An optional callback that gets run when a container has its capacity increased.
        - param1 [Player]: player - the player the inventory belongs to
        - param2 [string]: containerName - the name of the container whose capacity was increased
        - param3 [number]: amount - the increase amount
			
		OnDecreaseCap: An optional callback that gets run when a container has its capacity decreased.
        - param1 [Player]: player - the player the inventory belongs to
        - param2 [string]: containerName - the name of the container whose capacity was decrease
        - param3 [number]: amount - the decrease amount
	]]
    DefineRemotesToClient: (self: Inventory, remoteCallbacks: RemoteCallbacks) -> (),

    --[[
        Define a callback that determines whether two items can be switched with 
        each other. This callback is called after the containers' AllowedItemsCallback
        is called.
        
        Make sure this SwitchValidation function is the same as the client's, and vice versa.

            export type ItemPositionInfo = {
                SlotIndex: number,
                ContainerIndex: number,
                ContainerName: string
            }
    ]]
    DefineSwitchValidation: (self: Inventory, callback: SwitchValidateFunc) -> boolean,

    --[[
        Define a callback that gets called when an item switches its position. This
        callback gets called in a new thread created with task.spawn().

            export type ItemPositionInfo = {
                SlotIndex: number,
                ContainerIndex: number,
                ContainerName: string
            }
    ]]
    DefineOnSwitched: (self: Inventory, callback: OnSwitchedCallback) -> (),

    --[[
		Destroys the inventory, destroying all built containers and removing
        all members
	]]
    Destroy: (self: Inventory) -> (),
}

type _Inventory = {
    _containers: { _Container },
    _hotbarIndex: number,
    _data: _DATA,
    _currSize: number,
    _capacity: number,
    _STACKING_CONFIGS: StackingConfigs?,
    _REMOTE_CALLBACKS: RemoteCallbacks?,
    _CUSTOM_SORTERS: { [string]: Sorter }?,
    _player: Player,
    _equippedItem: ITEM_TYPE?,
    _CALLBACKS: { 
        SWITCH_VALIDATE_FUNC: SwitchValidateFunc?,
        ON_SWITCHED_FUNC: OnSwitchedCallback?,
    }
} & Inventory

export type StackingConfigs = {
	ValidateStackFunc: (player: Player, targetItem: ITEM_TYPE, currItem: ITEM_TYPE) -> (boolean, number),
	UpdateStackFunc: (player: Player, leftover: number, targetItem: ITEM_TYPE, currItem: ITEM_TYPE) -> (),
	ValidateSplitFunc: (player: Player, item: ITEM_TYPE) -> boolean,
	UpdateSplitFunc: (player: Player, currItem: ITEM_TYPE, newItem: ITEM_TYPE) -> (ITEM_TYPE, () -> ())
}
export type ItemPositionInfo = {
	SlotIndex: number,
	ContainerIndex: number,
	ContainerName: string
}
export type OnSwitchedCallback = (player: Player, 
    item: ITEM_TYPE, info: ItemPositionInfo, prevInfo: ItemPositionInfo
) -> ()
export type SwitchValidateFunc = (player: Player,
	item1: ITEM_TYPE, item2: ITEM_TYPE?, 
	item1Info: ItemPositionInfo, item2Info: ItemPositionInfo
) -> boolean
export type Sorter = (item1: ITEM_TYPE, item2: ITEM_TYPE, ...any) -> boolean
export type CapacityChangedCallback = (player: Player, containerName: string, amount: number) -> ()
export type RemoteCallbacks = {
	OnAdd: (player: Player, newItem: ITEM_TYPE, stackOnAdd: boolean) -> (),
	OnIncreaseCap: CapacityChangedCallback?,
	OnDecreaseCap: CapacityChangedCallback?,
}


function Inventory.new(capacity: number, inventoryData: _DATA): Inventory
	local props = {
        _data = table.create(capacity, EMPTY_SLOT)::_DATA,
		_capacity = capacity,
		_containers = {}::{ _Container },	-- stores the containers in the order in which they were built
		_currSize = 0,
		_hotbarIndex = 0,
		_equippedItem = nil::ITEM_TYPE?,
		_STACKING_CONFIGS = nil::StackingConfigs?,
		_REMOTE_CALLBACKS = nil::RemoteCallbacks?,
        _CUSTOM_SORTERS = nil::{ [string]: Sorter }?,
        _CALLBACKS = {}
	}
	

	function props.Build(self: _Inventory, containers: { Container }, itemspace: { Container }?)
		if not self._player then throwError("Player not set.") end
		
		if itemspace then
			for i = 1, #itemspace do
				(itemspace[i]::_Container)._inItemspace = true
			end
		end
		
		-- initialize containers: set start and end indicies and determine if container is in itemspace
		local lastIndex = 1
		for i = 1, #containers do
			local container = containers[i]::_Container
			
			container:_InitIndicies(lastIndex)
			if container._name == HOTBAR_CONTAINER_NAME then self._hotbarIndex = i end
			
			-- all containers are included in the itemspace if no explicit itemspace is provided
			if itemspace == nil then container._inItemspace = true end

			table.insert(self._containers, container)
			lastIndex = lastIndex + container._capacity
		end
		
		-- fill the inventory with the initial data based on container rules and itemspace
		local currContainerIndex = 1
		local currContainer = self._containers[currContainerIndex]
		for slotIndex = 1, capacity do
			local item = inventoryData[slotIndex]
			if not item then continue end
			
			if currContainer._currSize >= currContainer._capacity then 
				currContainerIndex += 1
				currContainer = self._containers[currContainerIndex]
			end
			
			if currContainer:_IsItemAllowed(item) and currContainer._inItemspace then
				self._data[slotIndex] = item
				currContainer._currSize += 1
				self._currSize += 1
				continue
			end
			
			for j = currContainerIndex+1, #self._containers do
				local targetContainer = self._containers[j]
				if not targetContainer._inItemspace then continue end
				if not (targetContainer::_Container):_IsItemAllowed(item) then continue end

				local targetIndex = self._containers[j-1]._invEndIndex + targetContainer._currSize + 1
				self._data[targetIndex] = item
				targetContainer._currSize += 1
				self._currSize += 1
				break
			end
		end
		
		debugPrint("Inventory built; current size:", self._currSize)
	end
	
	function props.AddItem(self: _Inventory, newItem: ITEM_TYPE, stackOnAdd: boolean?): boolean
		if self._currSize >= self._capacity then debugWarn("Failed to add new item; inventory at full capacity.") return false end
		
		stackOnAdd = if stackOnAdd == nil then false else stackOnAdd
		local stackingConfigs: StackingConfigs? = self._STACKING_CONFIGS
		local player = self._player::Player
		
		local fillHotbarFirst = false
		local hotbarContainer = self._hotbarIndex > 0 and self._containers[self._hotbarIndex] or nil
		if hotbarContainer and isBitFlagEnabled(hotbarContainer._flags, IMS.HOTBAR_FILL_FIRST) and hotbarContainer._currSize < hotbarContainer._capacity then
			fillHotbarFirst = true
		end
		
		local newItemClone = deepCopyTable(newItem::Table)::ITEM_TYPE
		local itemspaceHitCount = 0
		for i = 1, #self._containers do
			local container: _Container = self._containers[i]
			if container._currSize >= container._capacity and not stackOnAdd then continue end
			if container._inItemspace == false then itemspaceHitCount += 1 continue end
			if fillHotbarFirst and container ~= hotbarContainer then continue end
			
			if not (container::_Container):_IsItemAllowed(newItem) then continue end
			
			local canAutoEquip = not isBitFlagEnabled(container._flags, IMS.NO_AUTO_EQUIP)
			local leftoverStacking = false
			local canStack = false
			local leftover = 0
			for slotIndex = container._invStartIndex, container._invEndIndex do
				local currItem = self._data[slotIndex]

				if currItem and stackOnAdd and stackingConfigs and not leftoverStacking then -- stack item
					canStack, leftover = stackingConfigs.ValidateStackFunc(self._player, currItem, newItem)
					if not canStack then continue end
					if isBitFlagEnabled(container._flags, IMS.NO_STACKING) then
						debugPrint(string.format("Failed to add new item; stacking disabled on container %s; no stacking will occur.", container._name)) 
						return false 
					end
					
					if leftover > 0 then
						stackingConfigs.UpdateStackFunc(self._player, leftover, currItem, newItem)
						leftoverStacking = true
						continue -- add newItem with leftover amount in the first empty slot in next iteration
					end
					
					stackingConfigs.UpdateStackFunc(self._player, 0, currItem, newItem)
					
					local equippedItem = self:GetEquippedItem()
					if equippedItem then
						local stackable = stackingConfigs.ValidateStackFunc(self._player, currItem, equippedItem)
						if not stackable and canAutoEquip then self:SetEquippedItem(slotIndex) end
					else
						if canAutoEquip then self:SetEquippedItem(slotIndex) end
					end
					
					if self._REMOTE_CALLBACKS then self._REMOTE_CALLBACKS.OnAdd(player, newItemClone, stackOnAdd) end
					debugPrint(string.format("Stack on add:\n\tleftover: 0\n\tslotIndex: %d\n\tcurrent size: %d", slotIndex, self._currSize))
					return true
				end
				
				if (not currItem and fillHotbarFirst) or (not currItem and not stackOnAdd) then -- add in first empty slot
					self._data[slotIndex] = newItem
					self._currSize += 1
					container._currSize += 1
					
					if canAutoEquip then self:SetEquippedItem(slotIndex) end
					
					if leftoverStacking then
						if self._REMOTE_CALLBACKS then self._REMOTE_CALLBACKS.OnAdd(player, newItemClone, stackOnAdd) end
						debugPrint(string.format("Stack on add:\n\tleftover: %d\n\tslotIndex: %d\n\tcurrent size: %d", leftover, slotIndex, self._currSize))
					else
						if self._REMOTE_CALLBACKS then self._REMOTE_CALLBACKS.OnAdd(player, newItemClone, stackOnAdd) end
						debugPrint("New item added; current size:", self._currSize)
					end
					
					return true
				end
			end
		end

        if stackOnAdd then
            -- failed to find stack to stack new item onto; create a new one instead
            return self:AddItem(newItem)
        end
		
		if itemspaceHitCount > 0 then
			debugWarn("Failed to add new item; no space available in itemspace.")
			return false
		end
		
		debugWarn("(Internal): Failed to add new item; max iterations")
		return false
	end
	
	function props.IncreaseCapacity(self: _Inventory, builtContainerIndex: number, amount: number)
		if not builtContainerIndex or typeof(builtContainerIndex) ~= "number" or builtContainerIndex > #self._containers or builtContainerIndex <= 0 then 
			debugWarn("Cannot increase capacity; builtContainerIndex must be an index into the inventory's built containers.") 
			return
		end
		if not amount or typeof(amount) ~= "number" or amount <= 0 then debugWarn("Cannot increase capacity; invalid amount.") return end

		local targetContainer = self._containers[builtContainerIndex]
		local newData = table.create(self._capacity + amount, false)::_DATA
		table.move(self._data, 1, targetContainer._invEndIndex, 1, newData)
		table.move(self._data, targetContainer._invEndIndex+1, self._capacity, targetContainer._invEndIndex+1+amount, newData)

		for i = #self._containers, 1, -1 do
			local c = self._containers[i]
			if c._invStartIndex <= targetContainer._invStartIndex then break end
			c._invStartIndex += amount
			c._invEndIndex += amount
		end	

		self._data = newData
		self._capacity += amount
		targetContainer._invEndIndex += amount
		targetContainer._capacity += amount

		if self._REMOTE_CALLBACKS and self._REMOTE_CALLBACKS.OnIncreaseCap then
			self._REMOTE_CALLBACKS.OnIncreaseCap(self._player::Player, targetContainer._name, amount)
		end

		debugPrint(string.format("Container (%s) capacity increased by %d.", targetContainer._name, amount))
	end

	function props.DecreaseCapacity(self: _Inventory, builtContainerIndex: number, amount: number)
		if not builtContainerIndex or typeof(builtContainerIndex) ~= "number" or builtContainerIndex > #self._containers or builtContainerIndex <= 0 then 
			debugWarn("Cannot decrease capacity; builtContainerIndex must be an index into the inventory's built containers.") 
			return
		end
		if not amount or typeof(amount) ~= "number" or amount <= 0 then 
			debugWarn("Cannot decrease capacity; invalid amount.") 
			return 
		end
		if self._currSize == self._capacity then
			debugWarn("Cannot decrease capacity; inventory is at full capacity.")
			return
		end
		if self._currSize - amount < 0 then 
			debugWarn("Cannot decrease capacity; amount is greater than the current inventory size.")
			return
		end
		
		local targetContainer = self._containers[builtContainerIndex]
		if (targetContainer._capacity - targetContainer._currSize) < amount then
			debugWarn("Cannot decrease capacity; amount is greater than the available container space.")
			return
		end
		
		-- collapse the targetContainer's capacity by the specified amount, pushing its items to the front
		local newContainerCapacity = targetContainer._capacity - amount
		local newContainerData = table.create(newContainerCapacity, false)::_DATA
		local amountLeft = amount
		local containerIndex = 1
		for i = targetContainer._invStartIndex, targetContainer._invEndIndex do
			local item = self._data[i]
			if not item and amountLeft > 0 then
				amountLeft -= 1
				continue
			end
			
			newContainerData[containerIndex] = item
			containerIndex += 1
		end
		
		-- copy over data to smaller array 
		local newData = table.create(self._capacity - amount, false)::_DATA
		table.move(self._data, 1, targetContainer._invStartIndex-1, 1, newData)
		table.move(newContainerData, 1, newContainerCapacity, targetContainer._invStartIndex, newData)
		table.move(self._data, targetContainer._invEndIndex+1, self._capacity, targetContainer._invEndIndex+1-amount, newData)
		
		-- update start and end indicies of containers
		for i = #self._containers, 1, -1 do
			local c = self._containers[i]
			c._invEndIndex -= amount
			if c == targetContainer then break end
			c._invStartIndex -= amount
		end
		
		targetContainer._capacity = newContainerCapacity
		self._capacity -= amount
		self._data = newData
		
		local decreaseCapCallback: CapacityChangedCallback? = 
			(self._REMOTE_CALLBACKS and self._REMOTE_CALLBACKS.OnDecreaseCap) and self._REMOTE_CALLBACKS.OnDecreaseCap or nil
		if decreaseCapCallback then decreaseCapCallback(self._player::Player, targetContainer._name, amount) end

		debugPrint(string.format("Container (%s) capacity decreased by %d:\n\tNew Capacity=%d", targetContainer._name, amount, self._capacity))
	end
	
	function props.RemoveItem(self: _Inventory, slotIndex: number)
		if not slotIndex or typeof(slotIndex) ~= "number" or slotIndex <= 0 or slotIndex > self._capacity then 
			debugWarn("Cannot remove item; invalid slotIndex.")
			return 
		end
		
		if not self._data[slotIndex] then return end
		if self._currSize <= 0 then return end
		
		local targetContainer = getContainerFromSlotIndex(self._containers, slotIndex)
		
        if self._equippedItem == self._data[slotIndex] then
            self:SetEquippedItem(nil)
        end

		targetContainer._currSize -= 1
		self._data[slotIndex] = EMPTY_SLOT
		self._currSize -= 1
        debugPrint("Removed item at slotIndex:", slotIndex)
	end
	
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	---------------------[The 5 methods below should be called in response to the CLIENT]---------------------
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	
	function props.Switch(self: _Inventory, slotIndex1: number, slotIndex2: number)
		if not slotIndex1 or typeof(slotIndex1) ~= "number" or slotIndex1 <= 0 or slotIndex1 > self._capacity then 
			debugWarn("Cannot switch; invalid slotIndex1.")
			return 
		end
		if not slotIndex2 or typeof(slotIndex2) ~= "number" or slotIndex2 <= 0 or slotIndex2 > self._capacity then 
			debugWarn("Cannot switch; invalid slotIndex2.")
			return 
		end
		
		local item1 = self._data[slotIndex1]
		if not item1 then debugWarn("Cannot switch; item at slotIndex1 does not exist") return end
		local item2 = self._data[slotIndex2]
		if item2 == nil then debugWarn("Cannot switch; slot at slotIndex2 does not exist") return end
		
		local container1: _Container
		local container2: _Container
		for i = 1, #self._containers do
			local container = self._containers[i]
			if not container1 and (slotIndex1 >= container._invStartIndex and slotIndex1 <= container._invEndIndex) then
				container1 = container
			end
			
			if not container2 and (slotIndex2 >= container._invStartIndex and slotIndex2 <= container._invEndIndex) then
				container2 = container
			end
		end

		-- check if the switch respects the containers' configs
		if isBitFlagEnabled(container1._flags, IMS.CLOSED) then 
			debugPrint(string.format("Cannot switch; container %s is closed.", container1._name)) 
			return 
		end
		if isBitFlagEnabled(container2._flags, IMS.CLOSED) then
			debugPrint(string.format("Cannot switch; container %s is closed.", container2._name)) 
			return 
		end
		local item1AllowedInC2 = (container2::_Container):_IsItemAllowed(item1)
		local item2AllowedInC1 = if item2 then (container1::_Container):_IsItemAllowed(item2) else true
		if not item1AllowedInC2 then debugPrint("Cannot switch; item1 not allowed in", container2._name) return end
		if not item2AllowedInC1 then debugPrint("Cannot switch; item2 not allowed in", container1._name) return end

        if self._CALLBACKS.SWITCH_VALIDATE_FUNC then
            local info1: ItemPositionInfo = {
                SlotIndex = slotIndex1,
                ContainerIndex = getContainerIndexFromSlotIndex(container1, slotIndex1),
                ContainerName = container1._name
            }
            local info2: ItemPositionInfo = {
                SlotIndex = slotIndex2,
                ContainerIndex = getContainerIndexFromSlotIndex(container2, slotIndex2),
                ContainerName = container2._name
            }
            local canSwitch = self._CALLBACKS.SWITCH_VALIDATE_FUNC(self._player, item1, item2 or nil, info1, info2)
            if not canSwitch then debugPrint("Cannot switch; items failed to pass SwitchValidation.") return end
        end
		
		self._data[slotIndex1], self._data[slotIndex2] = self._data[slotIndex2], self._data[slotIndex1]
		
		if item2 == EMPTY_SLOT then 
			container2._currSize += 1
			container1._currSize -= 1
		end

        local onSwitched = self._CALLBACKS.ON_SWITCHED_FUNC
        if onSwitched then
            -- switched func for item1 which has been switched
            local slot1Info: ItemPositionInfo = {
                SlotIndex = slotIndex1,
                ContainerIndex = getContainerIndexFromSlotIndex(container1, slotIndex1),
                ContainerName = container1._name
            }
            local slot2Info: ItemPositionInfo = {
                SlotIndex = slotIndex2,
                ContainerIndex = getContainerIndexFromSlotIndex(container2, slotIndex2),
                ContainerName = container2._name
            }
            task.spawn(onSwitched, self._player, item1, slot2Info, slot1Info)
            if item2 then
                task.spawn(onSwitched, self._player, item2, slot1Info, slot2Info)
            end
        end

		debugPrint("Switched!")
	end
	
	function props.Stack(self: _Inventory, targetSlotIndex: number, currSlotIndex: number)
		if typeof(targetSlotIndex) ~= "number" or targetSlotIndex <= 0 or targetSlotIndex > self._capacity then 
			debugWarn("Cannot stack; targetSlotIndex out of bounds.")
			return 
		end
		if typeof(currSlotIndex) ~= "number" or currSlotIndex <= 0 or currSlotIndex > self._capacity then 
			debugWarn("Cannot stack; currSlotIndex out of bounds.")
			return 
		end
		
		local stackingConfigs = self._STACKING_CONFIGS
		if not stackingConfigs then return end
		
		local stackItem = self._data[targetSlotIndex]
		local oldItem = self._data[currSlotIndex]
		if not stackItem or not oldItem then return end
		
		local canStack, leftover = stackingConfigs.ValidateStackFunc(self._player, stackItem, oldItem)
		if not canStack then return end
		
		local targetContainer = getContainerFromSlotIndex(self._containers, targetSlotIndex)
		local currContainer = getContainerFromSlotIndex(self._containers, currSlotIndex)
		
		if isBitFlagEnabled(targetContainer._flags, IMS.CLOSED) then
			debugPrint(string.format("Cannot stack; container %s is closed.", targetContainer._name))
			return
		end
		if isBitFlagEnabled(currContainer._flags, IMS.CLOSED) then
			debugPrint(string.format("Cannot stack; container %s is closed.", currContainer._name))
			return
		end
		
		if leftover <= 0 then
			self._data[currSlotIndex] = EMPTY_SLOT
			self._currSize -= 1
			currContainer._currSize -= 1
		end
		
		stackingConfigs.UpdateStackFunc(self._player, leftover, stackItem, oldItem)
		debugPrint(string.format("Stacked!\n\tcurrSize=%d", self._currSize))
	end
	
	function props.Split(self: _Inventory, newSlotIndex: number, splitSlotIndex: number)
		if not newSlotIndex or typeof(newSlotIndex) ~= "number" or newSlotIndex <= 0 or newSlotIndex > self._capacity then 
			debugWarn("Cannot split; invalid newSlotIndex.")
			return 
		end
		if not splitSlotIndex or typeof(splitSlotIndex) ~= "number" or splitSlotIndex <= 0 or splitSlotIndex > self._capacity then 
			debugWarn("Cannot split; invalid splitSlotIndex.")
			return 
		end
		
		local stackingConfigs = self._STACKING_CONFIGS
		if not stackingConfigs then return end
		
		local currItem = self._data[splitSlotIndex]
		if not currItem then return end
		if not stackingConfigs.ValidateSplitFunc(self._player, currItem) then return end
		
		--[[
			possibleNewItem is the stack after it has been updated, after just being split, aka the originating stack.
			
			For example, if we have a stack of 7, and we split in half, it would leave us 4 and 3:
				- 4 is the original stack (splitSlotIndex = possibleNewItem)
				- 3 is the new stack (newSlotIndex = currItem)
		]]
		local possibleNewItem, cancelSplitFunc = stackingConfigs.UpdateSplitFunc(self._player, currItem, deepCopyTable(currItem::Table)::ITEM_TYPE)
		local targetContainer = getContainerFromSlotIndex(self._containers, newSlotIndex)
		local currContainer = getContainerFromSlotIndex(self._containers, splitSlotIndex)
		
		if isBitFlagEnabled(targetContainer._flags, IMS.CLOSED) then
			debugPrint(string.format("Cannot split; container %s is closed.", targetContainer._name))
			return
		end
		if isBitFlagEnabled(currContainer._flags, IMS.CLOSED) then
			debugPrint(string.format("Cannot split; container %s is closed.", currContainer._name))
			return
		end
		
		if not targetContainer:_IsItemAllowed(currItem) then 
			cancelSplitFunc()
			debugWarn("Cannot split; item not allowed in container", targetContainer._name) 
			return 
		end
		
		self._data[newSlotIndex] = currItem
		self._data[splitSlotIndex] = possibleNewItem
		self._currSize += 1
		targetContainer._currSize += 1
		debugPrint(string.format("Split!\n\tcurrSize=%d", self._currSize))
	end
	
	function props.SetEquippedItem(self: _Inventory, slotIndex: number?)
		if slotIndex == nil then
			debugPrint("Unequipped item")
			self._equippedItem = nil
			return
		end
		if typeof(slotIndex) ~= "number" or slotIndex <= 0 or slotIndex > self._capacity then
			debugWarn("Cannot set equipped item; invalid slotIndex.")
			return
		end
		
		local targetContainer = getContainerFromSlotIndex(self._containers, slotIndex)
		if isBitFlagEnabled(targetContainer._flags, IMS.NO_EQUIPPED_STATE) then
			debugWarn("Failed to equip item; item's container has NO_EQUIPPED_STATE flag enabled.")
			return
		end
		
		local item: ITEM_TYPE | false = self._data[slotIndex]
		if not item then debugWarn("No item to equip at slotIndex:", slotIndex) return end
		if self._equippedItem == item then debugPrint("Item already equipped"); return end
		
		self._equippedItem = item
		debugPrint(string.format("Equipped item set at slotIndex: %d ->", slotIndex))
	end
	
    function props.Sort(self: _Inventory, sorterName: string, ...: any)
        if typeof(sorterName) ~= "string" then
            debugWarn("sorterName must be a string")
            return
        end
        
        local data = self._data
        local sort = self._CUSTOM_SORTERS and self._CUSTOM_SORTERS[sorterName]
        if not sort then 
            throwError(string.format("Sorter %s not defined.", sorterName)) 
            return
        end
        
        local varargs = table.unpack({...})
        local containers = self._containers
        
        local debugStr = "Containers sorted:\n"
        for i = 1, #containers do
            local container = containers[i]
            if isBitFlagEnabled(container._flags, IMS.NO_SORTING) then continue end
            if container._currSize <= 0 then continue end -- don't need to sort containers that have no items
            
            local tempSubarr = table.move(data, container._invStartIndex, container._invEndIndex, 1, {})
            table.sort(tempSubarr, function(a: ITEM_TYPE?, b: ITEM_TYPE?)
                if not a then return false end
                if not b then return true end
                return sort(a, b, varargs)
            end)
            table.move(tempSubarr, 1, #tempSubarr, container._invStartIndex, data)
            debugStr = string.format("%s\t- %s\n", debugStr, container._name)
        end
        debugPrint(debugStr)
    end

	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------
	
	function props.GetEquippedItem(self: _Inventory): ITEM_TYPE?
		return self._equippedItem
	end
	
	function props.Items(self: _Inventory): _DATA
		return self._data
	end
	
	function props.Size(self: _Inventory): number
		return self._currSize
	end

	function props.Capacity(self: _Inventory): number
		return self._capacity
	end
	
	function props.SetPlayer(self: _Inventory, player: Player)
		self._player = player
	end

	function props.DefineStackingConfigs(self: _Inventory, configs: StackingConfigs)
		self._STACKING_CONFIGS = configs
	end
	
	function props.DefineRemotesToClient(self: _Inventory, remoteCallbacks: RemoteCallbacks)
		if not remoteCallbacks.OnAdd then throwError("OnAdd callback missing from remoteCallbacks.") end
		self._REMOTE_CALLBACKS = remoteCallbacks
	end

    function props.DefineCustomSorters(self: _Inventory, sorters: { [string]: Sorter })
        self._CUSTOM_SORTERS = sorters
    end

    function props.DefineSwitchValidation(self: _Inventory, callback: SwitchValidateFunc)
        self._CALLBACKS.SWITCH_VALIDATE_FUNC = callback
    end

    function props.DefineOnSwitched(self: _Inventory, callback: OnSwitchedCallback)
        self._CALLBACKS.ON_SWITCHED_FUNC = callback
    end
	
	function props.Destroy(self: _Inventory)
		for i = 1, #self._containers do
			self._containers[i]:Destroy()
		end
		
		table.clear(self::Table)
	end

    -- function props:PrintContainers()
	-- 	for i = 1, #self._containers do
	-- 		local container = self._containers[i]
	-- 		warn(string.format("-----[%s]----", container._name))
	-- 		for j = container._invStartIndex, container._invEndIndex do
	-- 			print(string.format("[%d] =", j), self._data[j])
	-- 		end
	-- 	end
	-- end
	
	return props::Inventory
end

----------------------------------------------------------------------------------
--[[
	Creates a new container given the name and capacity
]]
function IMS.Container(name: string, capacity: number, flags: number?): Container
	return newContainer(name, capacity, flags or 0)
end

--[[
	Creates a new inventory given the capacity and inventory data
]]
function IMS.Inventory(capacity: number, data: _DATA): Inventory
	return Inventory.new(capacity, data)
end

--[[
	Define the same AllowedItems callback for the provided containers
]]
function IMS.DefineAllowedItems(containers: { Container }, callback: AllowedItemsCallback)
	for i = 1, #containers do
		containers[i]:DefineAllowedItems(callback)
	end
end

--[[
    Resets the inventory.
    
    **This function must be called when the player's character DIES and RESPAWNS to prevent
        any lingering states that were once active when the character was alive.**

    *Refer to the demo place to see how it's used*
]]
function IMS.Reset(inventory: Inventory)
    if not inventory then 
        debugWarn("inventory is nil or false; an Inventory obj must be provided to IMS.Reset()") 
        return 
    end
    local inv = inventory::_Inventory
    if not inv._player then return end

    inv._equippedItem = nil
end


return IMS