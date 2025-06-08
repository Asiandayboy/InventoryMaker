--!strict
--[[
	DraggableUI forked from v1.3.3 (used in InventoryMaker v1.0.0) 5/17/2025
	------------------------------------------------------------------------
	
	Forked Version Updates:
	--------------
	v1.3.5 5/18/25
		- set z indes on input began instead of when drag initially starts
		
	v1.3.4 5/17/25
		- add _currDraggable to limit only 1 gui object being dragged at a time
]]
local DraggableUI = {
	DEBUG_PRINT_MODE = false
}

local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer::Player
local playerGui = player.PlayerGui

local IMInput = require(script.Parent.IMInput)


export type Draggable = {
	ID: number,
	--[[
		If BeforeDragStart returns true, the drag will start, else it will not start.
	]]
	BeforeDragStart: (() -> boolean)?,
	OnDragStart: (() -> ())?,
	OnDragMove: ((mousePos: Vector2) -> ())?,
	OnDragEnd: ((mousePos: Vector2, guisAtPos: { GuiObject }, wasDragged: boolean) -> ())?
}

type _Draggable = {
	_instance: GuiObject,
	_dragStartInputDown: boolean,
	_dragging: boolean,
	_parent: any,
	_size: Vector2,
	_anchorPoint: Vector2,
	_pos: Vector2,
	_zIndex: number,
	_dragParent: ScreenGui,
	_parentSize: UDim2,
	_parentPos: UDim2,
	_moveCon: RBXScriptConnection?,
	_inputBegan: RBXScriptConnection?,
	_inputEnded: RBXScriptConnection?,
	_guiInsetIgnored: boolean,
	_dragFromCenter: boolean,
}


local _objs: { [number]: _Draggable | boolean } = {}
local _currDraggable: Draggable? = nil


local function disconnectCon(con: RBXScriptConnection?)
	if con and con.Connected then
		con:Disconnect()
	end
end

local function revertToParentProps(_props: _Draggable)
	local guiObj =_props._instance
	guiObj.Parent = _props._parent
	guiObj.Size = _props._parentSize
	guiObj.Position = _props._parentPos
	guiObj.ZIndex = _props._zIndex
	guiObj.AnchorPoint = _props._anchorPoint
end

local function saveParentProps(_props: _Draggable)
	local guiObj =_props._instance
	_props._size = guiObj.AbsoluteSize
	_props._pos = guiObj.AbsolutePosition
	
	_props._parent = guiObj.Parent
	_props._parentSize = guiObj.Size
	_props._parentPos = guiObj.Position
	_props._zIndex = guiObj.ZIndex
	_props._anchorPoint = guiObj.AnchorPoint
end


function DraggableUI.new(guiObj: GuiObject, dragFromCenter: boolean?): Draggable
	local screenGui = guiObj:FindFirstAncestorWhichIsA("ScreenGui") -- used as the parent to guiObj when dragging 
	if not screenGui then error("Could not find an ancestor screenGui to anchor the draggable object", 0) end
	
	local _props = {
		_instance = guiObj,
		_dragStartInputDown = false,
		_dragging = false,
		_parent = nil,
		_anchorPoint = Vector2.zero,
		_size = Vector2.zero,
		_pos = Vector2.zero,
		_zIndex = 1,
		_dragParent = screenGui,
		_parentSize = UDim2.new(),
		_parentPos = UDim2.new(),
		_dragFromCenter = dragFromCenter or false,
		_guiInsetIgnored = screenGui.IgnoreGuiInset::boolean
	}::_Draggable
	
	local id
	local vacantSpotFilled = false
	for i,v in ipairs(_objs) do
		if v then continue end
		_objs[i] = _props
		vacantSpotFilled = true
		id = i
		break
	end
	
	if not vacantSpotFilled then
		table.insert(_objs, _props)
		id = #_objs
	end
	
	local props = {
		ID = id
	}::Draggable
	
	if DraggableUI.DEBUG_PRINT_MODE then
		warn("Draggable created; ID =", props.ID)
	end
	
	return props
end

function DraggableUI.IsDragging(draggableObj: Draggable): boolean
	local _props: _Draggable = _objs[draggableObj.ID]::_Draggable
	return _props._dragging
end

function DraggableUI.Enable(draggableObj: Draggable)
	local _props: _Draggable = _objs[draggableObj.ID]::_Draggable
	local guiObj = _props._instance
	
	local canStartDrag = true
	local dragFromCenter = _props._dragFromCenter
	

	_props._inputBegan = guiObj.InputBegan:Connect(function(input: InputObject)
		if IMInput.IsInputActive(IMInput.DRAG_START, input) then
			if draggableObj.BeforeDragStart then
				canStartDrag = draggableObj.BeforeDragStart()
			end
			
			if not canStartDrag then return end
			if _currDraggable then return end
			
			_props._dragStartInputDown = true
            _currDraggable = draggableObj
            if _props._dragParent.IgnoreGuiInset ~= _props._guiInsetIgnored then
                _props._guiInsetIgnored = _props._dragParent.IgnoreGuiInset
            end
			
			saveParentProps(_props)
			local guiInset = _props._guiInsetIgnored and GuiService:GetGuiInset() or Vector2.zero
			local initialMousePos = UIS:GetMouseLocation()
			local offset = _props._pos - initialMousePos + guiInset -- used for when dragFromCenter = false
			guiObj.ZIndex = 100

			_props._moveCon = UIS.InputChanged:Connect(function(uisInput: InputObject)
				if IMInput.IsInputActive(IMInput.DRAG_MOVE, uisInput) and _props._dragStartInputDown and _currDraggable == draggableObj then
					if not _props._dragging then
						guiObj.Parent = _props._dragParent
						guiObj.Size = UDim2.new(0, _props._size.X, 0, _props._size.Y)

						if dragFromCenter then
							guiObj.AnchorPoint = Vector2.new(0.5, 0.5)
							guiObj.Position = UDim2.new(0, initialMousePos.X, 0, initialMousePos.Y)
						else
							guiObj.AnchorPoint = Vector2.zero
							guiObj.Position = UDim2.new(0, math.ceil(_props._pos.X), 0, (_props._pos.Y+guiInset.Y))
						end
						
						if draggableObj.OnDragStart then task.spawn(draggableObj.OnDragStart) end
					end
					
					_props._dragging = true
					local mouse = UIS:GetMouseLocation()
					if dragFromCenter then
						guiObj.Position = UDim2.new(0, mouse.X, 0, mouse.Y)
					else
						guiObj.Position = UDim2.new(0, mouse.X + offset.X, 0, mouse.Y + offset.Y)
					end
					if draggableObj.OnDragMove then task.spawn(draggableObj.OnDragMove, mouse) end
				end
			end)
		end
	end)
	
	_props._inputEnded = guiObj.InputEnded:Connect(function(input: InputObject)
		if IMInput.IsInputActive(IMInput.DRAG_END, input) then
			if not canStartDrag then return end
			if _currDraggable ~= draggableObj then return end
			
			_props._dragStartInputDown = false
			_currDraggable = nil
			revertToParentProps(_props)
			disconnectCon(_props._moveCon)
			
			local wasDragged = _props._dragging
			_props._dragging = false
			
			if draggableObj.OnDragEnd then 
				local mousePos = UIS:GetMouseLocation()
				local guisAtPos = playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y - GuiService:GetGuiInset().Y)
				task.spawn(draggableObj.OnDragEnd, mousePos, guisAtPos, wasDragged) 
			end
		end
	end)
end

function DraggableUI.Disable(draggableObj: Draggable)
	local _props: _Draggable = _objs[draggableObj.ID]::_Draggable
	_props._dragStartInputDown = false
	
	if _props._instance.Parent ~= nil and _props._dragging then
		revertToParentProps(_props)
	end
	disconnectCon(_props._inputBegan)
	disconnectCon(_props._inputEnded)
	disconnectCon(_props._moveCon)
end

function DraggableUI.Destroy(draggableObj: Draggable)
	if _objs[draggableObj.ID] == nil then error("[DragagbleUI]: Attempt to call DraggableUI.Destroy on nil;", 0) end
	
	DraggableUI.Disable(draggableObj)
	_objs[draggableObj.ID] = false
end





return DraggableUI
