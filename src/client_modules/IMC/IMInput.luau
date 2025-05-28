--!strict
local UIS = game:GetService("UserInputService")

type ActionValidator = (input: InputObject) -> boolean
type ActionValidator2 = (input: InputObject | Enum.UserInputState) -> boolean

local IMInput = {
	HOVER_PROMPT_START = 1,
	HOVER_PROMPT_END = 2,
	SPLIT = 3,
	CONTEXT_MENU_OPEN = 5,
	MULTI_CONTEXT_BOUNDS_CHECK = 6,
	DRAG_START = 7,
	DRAG_MOVE = 8,
	DRAG_END = 9,
	ROOT_MENU_BOUNDS_CHECK = 10,
	
	INPUT_NONE = 0,
	INPUT_TOUCH = 1,
	INPUT_MOUSE = 2,
}


local TOUCH_ENABLED = UIS.TouchEnabled
local MOUSE_ENABLED = UIS.MouseEnabled



local function validateInputHoverPromptStart(input: InputObject)
	if MOUSE_ENABLED then
		return input.UserInputType == Enum.UserInputType.MouseMovement
	end
	if TOUCH_ENABLED then
		return input.UserInputType == Enum.UserInputType.Touch and input.UserInputState == Enum.UserInputState.Change
	end

	return false
end

local function validateInputHoverPromptEnd(input: InputObject)
	if MOUSE_ENABLED then
		return input.UserInputType == Enum.UserInputType.MouseMovement
	end
	if TOUCH_ENABLED then
		return input.UserInputType == Enum.UserInputType.Touch and 
			(input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Change)
	end

	return false
end

local function validateInputSplit(input: InputObject | Enum.UserInputState)
	local validated = false
	if MOUSE_ENABLED then
		validated = (input::InputObject).UserInputType == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.LeftControl)
	elseif TOUCH_ENABLED then
		validated = (input::Enum.UserInputState) == Enum.UserInputState.Begin
	end
	
	return validated
end

local function validateInputContextMenuOpen(input: InputObject)	
	if MOUSE_ENABLED then
		return input.UserInputType == Enum.UserInputType.MouseButton2
	end
	if TOUCH_ENABLED then
		return input.UserInputType == Enum.UserInputType.Touch and input.UserInputState == Enum.UserInputState.Begin
	end

	return false
end

local function validateInputRootMenuBoundsCheck(input: InputObject)
	if MOUSE_ENABLED then
		return input.UserInputType == Enum.UserInputType.MouseButton1
	end
	if TOUCH_ENABLED then
		return input.UserInputType == Enum.UserInputType.Touch and input.UserInputState == Enum.UserInputState.Begin
	end
	
	return false
end

local function validateInputMultiContextBoundsCheck(input: InputObject)
	if MOUSE_ENABLED then
		return input.UserInputType == Enum.UserInputType.MouseMovement	
	end

	return false
end

local function validateInputDragStart(input: InputObject)
	local validated = false
	if MOUSE_ENABLED then
		validated = input.UserInputType == Enum.UserInputType.MouseButton1
	end
	if TOUCH_ENABLED then
		validated = input.UserInputType == Enum.UserInputType.Touch and input.UserInputState == Enum.UserInputState.Begin
	end
	
	return validated
end

local function validateInputDragMove(input: InputObject)
	local validated = false
	if MOUSE_ENABLED then
		validated = input.UserInputType == Enum.UserInputType.MouseMovement
	end
	if TOUCH_ENABLED then
		validated = input.UserInputType == Enum.UserInputType.Touch and input.UserInputState == Enum.UserInputState.Change
	end
	
	return validated
end

local function validateInputDragEnd(input: InputObject)
	local validated = false
	if MOUSE_ENABLED then
		validated = input.UserInputType == Enum.UserInputType.MouseButton1
	end
	if TOUCH_ENABLED then
		validated = input.UserInputType == Enum.UserInputType.Touch and input.UserInputState == Enum.UserInputState.End
	end

	return validated
end

local ACTIONS: { [number]: ActionValidator | ActionValidator2 } = {
	[IMInput.HOVER_PROMPT_START] = validateInputHoverPromptStart,
	[IMInput.HOVER_PROMPT_END] = validateInputHoverPromptEnd,
	[IMInput.SPLIT] = validateInputSplit,
	[IMInput.CONTEXT_MENU_OPEN] = validateInputContextMenuOpen,
	[IMInput.MULTI_CONTEXT_BOUNDS_CHECK] = validateInputMultiContextBoundsCheck,
	[IMInput.ROOT_MENU_BOUNDS_CHECK] = validateInputRootMenuBoundsCheck,
	[IMInput.DRAG_START] = validateInputDragStart,
	[IMInput.DRAG_MOVE] = validateInputDragMove,
	[IMInput.DRAG_END] = validateInputDragEnd,
}



--[[
	Returns true if the input for the specified action is active.
]]
function IMInput.IsInputActive(action: number, input: InputObject | Enum.UserInputState): boolean
	if action == IMInput.SPLIT then
		return (ACTIONS[action]::ActionValidator2)(input)
	end
	
	return (ACTIONS[action]::ActionValidator)(input::InputObject)
end


function IMInput.GetInputType(): number
	if TOUCH_ENABLED then return IMInput.INPUT_TOUCH end
	if MOUSE_ENABLED then return IMInput.INPUT_MOUSE end
	
	return IMInput.INPUT_NONE
end




return IMInput