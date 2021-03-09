local GameUI = require('GameUI')

local WhereAmI = {
	visible = false,
	districtId = nil,
	districtLabels = nil,
	districtCaption = nil,
	factionLabels = nil,
}

function WhereAmI.Update()
	local preventionSystem = Game.GetScriptableSystemsContainer():Get('PreventionSystem')
	local districtManager = preventionSystem.districtManager

	if districtManager and districtManager:GetCurrentDistrict() then
		WhereAmI.districtId = districtManager:GetCurrentDistrict():GetDistrictID()
		WhereAmI.districtLabels = {}
		WhereAmI.factionLabels = {}

		local tweakDb = GetSingleton('gamedataTweakDBInterface')
		local districtRecord = tweakDb:GetDistrictRecord(WhereAmI.districtId)
		repeat
			local districtLabel = Game.GetLocalizedText(districtRecord:LocalizedName())

			table.insert(WhereAmI.districtLabels, 1, districtLabel)

			for _, falctionRecord in ipairs(districtRecord:Gangs()) do
				local falctionLabel = Game.GetLocalizedTextByKey(falctionRecord:LocalizedName())

				table.insert(WhereAmI.factionLabels, 1, falctionLabel)
			end

			districtRecord = districtRecord:ParentDistrict()
		until districtRecord == nil

		WhereAmI.districtCaption = table.concat(WhereAmI.districtLabels, ' / ')
	end
end

function WhereAmI.Toggle(visible)
	WhereAmI.visible = visible
end

registerForEvent('onInit', function()
	WhereAmI.Update()

	Observe('DistrictManager', 'NotifySystem', function()
		WhereAmI.Update() 
	end)

	GameUI.Observe(function(state)
		WhereAmI.Toggle(state.isDefault)
	end)
end)

registerForEvent('onDraw', function()
	if WhereAmI.visible and WhereAmI.districtId then
		local windowWidth = 220
		local screenWidth, screenHeight = GetDisplayResolution()
		local screenRatioX, screenRatioY = screenWidth / 1920, screenHeight / 1200

		ImGui.SetNextWindowPos(screenWidth - windowWidth - 320 * screenRatioX, 68 * screenRatioY)
		ImGui.SetNextWindowSize(windowWidth, 0)

		ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8)
		ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 8, 7)
		ImGui.PushStyleColor(ImGuiCol.WindowBg, 0xaa000000)
		ImGui.PushStyleColor(ImGuiCol.Border, 0x8ffefd01)

		ImGui.Begin('Where Am I', ImGuiWindowFlags.NoDecoration)

		for i, districtLabel in ipairs(WhereAmI.districtLabels) do
			if i == 1 then
				ImGui.PushStyleColor(ImGuiCol.Text, 0xfffefd01)
				ImGui.Text(districtLabel:upper())
			else
				ImGui.PushStyleColor(ImGuiCol.Text, 0xff5461ff)
				ImGui.Text(districtLabel)
			end

			ImGui.PopStyleColor()
		end

		if #WhereAmI.factionLabels > 0 then
			for _, factionLabel in ipairs(WhereAmI.factionLabels) do
				ImGui.Text('· ' .. factionLabel)
			end
		end

		ImGui.End()

		ImGui.PopStyleColor(2)
		ImGui.PopStyleVar(2)
	end
end)
