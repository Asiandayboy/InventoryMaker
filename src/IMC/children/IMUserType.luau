local IMUserType = {}



-- This is for if you want better typechecking for your items (ITEM_TYPE)
-- Define the schema of your type here. This type should represent what each item looks like. You can store anything you want
-- The current type is just used as an example
export type USER_ITEM_TYPE = { -- DON'T CHANGE THE NAME OF THE TYPE
	ItemData: { 
		ItemID: number,
		Quantity: number,
		Metadata: { [string]: any } 
	},
	ItemName: string,
	ItemDescription: string,
	ItemType: string,
	Instance: Instance?,
	
	IsEquipped: boolean?
}




return IMUserType
