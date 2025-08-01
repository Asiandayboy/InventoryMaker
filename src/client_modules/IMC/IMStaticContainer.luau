--!strict
local StaticContainer = {}

local Constants = require(script.Parent.IMConstants)
local UserType = require(script.Parent.IMUserType)

type ITEM_TYPE = UserType.USER_ITEM_TYPE
export type ActivatedCallbackStatic = (item: ITEM_TYPE, filledGui: GuiObject, containerIndex: number) -> ()

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

type HoverPromptConfigs = {
	GuiTemplate: GuiObject,
	FixedPosition: boolean,
	Offset: Vector2,
	RenderFunc: (item: ITEM_TYPE, hoverPromptGui: GuiObject) -> (),
	ShowPromptAfterDragging: boolean?,
}

type _HoverPromptInfo = {
	_TEMPLATE: GuiObject,
	_OFFSET: UDim2,
	_FIXED_POSITION: boolean,
	_RENDER_FUNC: (item: ITEM_TYPE, gui: GuiObject) -> (),
	_GUI: GuiObject?,
	_INSET: UDim2?,
	_OPEN_HOVER_PROMPT_AFTER_DRAGGING: boolean,
}

export type StaticContainer = {
    --[[
        Define the layout of the container, which is determined using a UIGridLayout.
        At minimum, the `ParentContainer` field must be defined; it is the gui object
        that the UIGridLayout will be parented to.

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
    ]]
	DefineLayout: (self: StaticContainer, params: GridLayoutParams) -> (),

    --[[
        Define how empty slots are rendered, providing a gui template and a render function.
        The render function should only handle UI logic.  

            type StaticContainerEmptyConfigs = {
                GuiTemplate: GuiObject,
                RenderFunc: ((
                    emptyGui: GuiObject, 
                    containerIndex: number
                ) -> ())?
            }
    ]]
	DefineEmptySlot: (self: StaticContainer, configs: StaticContainerEmptyConfigs) -> (),

    --[[
        Define how filled slots are rendered, providing a gui template and a render function.
        The render function should only handle UI logic.

            type StaticContainerFilledConfigs = {
                GuiTemplate: GuiObject, 
                RenderFunc: (
                    item: ITEM_TYPE, 
                    filledGui: GuiObject, 
                    containerIndex: number,
                    ...any
                ) -> ()
            }
    ]]
	DefineFilledSlot: (self: StaticContainer, configs: StaticContainerFilledConfigs) -> (),

    --[[
        Define a callback that gets called whenever an item is activated in this container.
        An item is activated when it is left-clicked (mobile), double-tapped (mobile, nonhotbar),
        or tapped (mobile, tapped)

            type ActivatedCallbackStatic = (item: ITEM_TYPE, filledGui: GuiObject, containerIndex: number) -> ()
    ]]
	DefineActivatedCallback: (self: StaticContainer, callback: ActivatedCallbackStatic) -> (),

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
    ]]
	DefineHoverPrompt: (self: StaticContainer, configs: HoverPromptConfigs) -> (),

    DefineOpen: (self: StaticContainer, func: (parentContainer: GuiObject, ...any) -> ()) -> (),

    DefineClose: (self: StaticContainer, func: (parentContainer: GuiObject, ...any) -> ()) -> (),

    --[[
        Opens the static container's inventory; renders onto the screen.
    ]]
    Open: (self: StaticContainer, ...any) -> (),

    --[[
        Closes the static inventory's inventory; unrenders from the screen.
    ]]
    Close: (self: StaticContainer, ...any) -> (),

    --[[
        Calls the filled slot's render function defined in DefineFilledSlot(). 
        This function does nothing if it's an empty slot.
    ]]
    RerenderItem: (self: StaticContainer, containerIndex: number, ...any) -> (),
}

type StaticContainerEmptyConfigs = {
    GuiTemplate: GuiObject,
	RenderFunc: ((emptyGui: GuiObject, containerIndex: number) -> ())?
}

type StaticContainerFilledConfigs = {
    GuiTemplate: GuiObject, 
    RenderFunc: (item: ITEM_TYPE, filledGui: GuiObject, containerIndex: number, ...any) -> ()
}

export type _StaticContainer = {
    _opened: boolean,
    _name: string,
    _capacity: number,
    _data: { ITEM_TYPE },
    _slotGuiObjs: { GuiObject },
    _hoverPromptParent: ScreenGui,
    _PARENT_CONTAINER: GuiObject,
    _GRID_LAYOUT: UIGridLayout,
    _EMPTY_TEMPLATE: GuiObject,
    _FILLED_TEMPLATE: GuiObject,
    _RENDER_EMPTY_FUNC: ((emptyGui: GuiObject, containerIndex: number) -> ())?,
    _RENDER_FILLED_FUNC: (item: ITEM_TYPE, filledGui: GuiObject, containerIndex: number, ...any) -> (),

    _HOVER_INFO: _HoverPromptInfo,

    _CALLBACKS: {
        _ON_OPENED_FUNC: (parentContainer: GuiObject, ...any) -> (),
        _ON_CLOSED_FUNC: (parentContainer: GuiObject, ...any) -> (),
        _ACTIVATED_FUNC: ActivatedCallbackStatic,
    }
} & StaticContainer




local DEFAULT_CELL_PADDING = Constants.DEFAULT_CELL_PADDING
local DEFAULT_CELL_SIZE = Constants.DEFAULT_CELL_SIZE
local DEFAULT_FILL_DIRECTION = Constants.DEFAULT_FILL_DIRECTION
local DEFAULT_FILL_DIRECTION_MAX_CELLS = Constants.DEFAULT_FILL_DIRECTION_MAX_CELLS
local DEFAULT_START_CORNER = Constants.DEFAULT_START_CORNER
local DEFAULT_H_ALIGN = Constants.DEFAULT_H_ALIGN
local DEFAULT_V_ALIGN = Constants.DEFAULT_V_ALIGN



function StaticContainer.NewStaticContainer(name: string, capacity: number): StaticContainer
    local _props = {
        _name = name,
        _capacity = capacity,
        _opened = false,
        _CALLBACKS = {},
        _slotGuiObjs = {},
        
        DefineLayout = function(self: _StaticContainer, params: GridLayoutParams)
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
        end,

        DefineEmptySlot = function(self: _StaticContainer, configs: StaticContainerEmptyConfigs)
            self._EMPTY_TEMPLATE = configs.GuiTemplate
            self._RENDER_EMPTY_FUNC = configs.RenderFunc
        end,

        DefineFilledSlot = function(self: _StaticContainer, configs: StaticContainerFilledConfigs)
            self._FILLED_TEMPLATE = configs.GuiTemplate
			self._RENDER_FILLED_FUNC = configs.RenderFunc
        end,

        DefineActivatedCallback = function(self: _StaticContainer, callback: ActivatedCallbackStatic)
			self._CALLBACKS._ACTIVATED_FUNC = callback
		end,

        DefineHoverPrompt = function(self: _StaticContainer, configs: HoverPromptConfigs)
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
			}
        end,

        DefineOpen = function(self: _StaticContainer, func: (parentContainer: GuiObject, ...any) -> ())
            self._CALLBACKS._ON_OPENED_FUNC = func
        end,

        DefineClose = function(self: _StaticContainer, func: (parentContainer: GuiObject, ...any) -> ())
            self._CALLBACKS._ON_CLOSED_FUNC = func
        end,

        Open = function(self: _StaticContainer, ...: any)
            if self._opened then return end
            self._opened = true
            self._CALLBACKS._ON_OPENED_FUNC(self._PARENT_CONTAINER, ...)
        end,

        Close = function(self: _StaticContainer, ...: any)
            if not self._opened then return end
            self._opened = false
            self._CALLBACKS._ON_CLOSED_FUNC(self._PARENT_CONTAINER, ...)
        end,

        RerenderItem = function(self: _StaticContainer, containerIndex: number, ...: any)
            local item = self._data[containerIndex]
            if not item then return end

            local slotGui = self._slotGuiObjs[containerIndex]::{ [string]: GuiObject } & GuiObject
            local filledGui = slotGui[Constants.FILLED_GUI_NAME]
            self._RENDER_FILLED_FUNC(item, filledGui, containerIndex, ...)
        end,
    }

    return _props::StaticContainer
end

local function createStaticContainerEmptySlot(staticContainer: _StaticContainer, containerIndex: number)
    local gui = staticContainer._EMPTY_TEMPLATE:Clone()
	if staticContainer._RENDER_EMPTY_FUNC then
		staticContainer._RENDER_EMPTY_FUNC(gui, containerIndex)
	end
	gui.Name = Constants.SLOT_NAME_PREFIX..tostring(containerIndex)
	gui.LayoutOrder = containerIndex
	gui.Visible = true
	gui.Parent = staticContainer._PARENT_CONTAINER

	return gui
end

local function createStaticContainerFilledSlot(staticContainer: _StaticContainer, item: ITEM_TYPE, containerIndex: number): (GuiObject, GuiObject)
    local slot = createStaticContainerEmptySlot(staticContainer, containerIndex)

	local filledSlotGui = staticContainer._FILLED_TEMPLATE:Clone()
	filledSlotGui.Visible = true
    staticContainer._RENDER_FILLED_FUNC(item, filledSlotGui, containerIndex)
	filledSlotGui.Name = Constants.FILLED_GUI_NAME
	filledSlotGui.Parent = slot

	return filledSlotGui, slot
end

function StaticContainer.InitStaticContainer(staticContainer: _StaticContainer, staticContainerData: { ITEM_TYPE }, 
    onFilledSlotCreatedCallback: (filledGui: GuiObject, containerIndex: number) -> ()
)
    if #staticContainerData > staticContainer._capacity then
        error("the provided inventory data length exceeds the static container capacity.")
    end
    
    for i, item in staticContainerData do
        if not item then continue end

        local filledGui, slotGui = createStaticContainerFilledSlot(staticContainer, item, i)
        table.insert(staticContainer._slotGuiObjs, slotGui)
        onFilledSlotCreatedCallback(filledGui, i)
    end

    staticContainer._data = staticContainerData
    staticContainer._GRID_LAYOUT.Parent = staticContainer._PARENT_CONTAINER
end

function StaticContainer.DestroyStaticContainer(staticContainer: _StaticContainer)
    for i, v in staticContainer._slotGuiObjs do
        v:Destroy()
    end
    table.clear(staticContainer._slotGuiObjs)
    table.clear(staticContainer::{ [string]: any })
end










return StaticContainer