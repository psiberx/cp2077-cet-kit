--[[
After the fix is applied you have to reequip clothing item with Dead-Eye installed
]]

registerForEvent('onInit', function()
	local deadEyeTweakDbId = TweakDBID.new('Items.PowerfulFabricEnhancer08')
	local deadEyeOnAttach = TweakDB:GetFlat(TweakDBID.new(deadEyeTweakDbId, '.OnAttach'))
	
	-- Check if Dead-Eye is broken
	if #deadEyeOnAttach == 0 then
		deadEyeOnAttach[1] = TweakDBID.new('Items.SimpleFabricEnhancer03_inline0')
		deadEyeOnAttach[2] = TweakDBID.new('Items.SimpleFabricEnhancer04_inline0')
		
		TweakDB:SetFlat(TweakDBID.new(deadEyeTweakDbId, '.OnAttach'), deadEyeOnAttach)
		TweakDB:Update(deadEyeTweakDbId)
		
		print('Dead-Eye Fix Applied')
	end
end)

--[[
Simplified version with no checks:

TweakDB:SetFlat(TweakDBID.new('Items.PowerfulFabricEnhancer08.OnAttach'), {
	TweakDBID.new('Items.SimpleFabricEnhancer03_inline0'),
	TweakDBID.new('Items.SimpleFabricEnhancer04_inline0'),
})

TweakDB:Update(TweakDBID.new('Items.PowerfulFabricEnhancer08'))
]]
