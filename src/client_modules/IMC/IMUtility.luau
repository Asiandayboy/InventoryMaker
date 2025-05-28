--!strict
local Utility = {}

local GuiService = game:GetService("GuiService")

export type Table = { [any]: any }


function Utility.GetGuiInsetY(guiInsetIgnored: boolean): number
	return guiInsetIgnored and GuiService:GetGuiInset().Y or 0
end


function Utility.DeepCopyTable(t: Table)
	local copy = {}

	for k,v in pairs(t) do
		if type(v) == "table" then
			copy[k] = Utility.DeepCopyTable(v::Table)
		else
			copy[k] = v
		end
	end
	return copy
end

function Utility.DeepTableClear(t: Table)
	for k,v in pairs(t) do
		if type(v) == "table" then
			Utility.DeepTableClear(v::Table)
		end
		t[k] = nil
	end
end


function Utility.IsPointWithinBoundingBox(
	px: number, py: number, 
	minX: number, minY: number, 
	maxX: number, maxY: number): boolean
	return px >= minX and px <= maxX and py >= minY and py <= maxY
end


function Utility.IsMouseWithinGui(mx: number, my: number, gui: GuiObject): boolean
	local pos = gui.AbsolutePosition
	local size = gui.AbsoluteSize

	return mx >= pos.X and mx <= pos.X + size.X and my >= pos.Y and my <= pos.Y + size.Y
end


return Utility