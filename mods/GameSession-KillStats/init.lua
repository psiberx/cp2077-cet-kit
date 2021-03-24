local GameHUD = require('GameHUD')
local GameSession = require('GameSession')

local stats = {
	totalKills = 0,
	totalKillsByGroup = {},
	lastKillLocation = nil,
	lastKillTimestamp = nil,
}

local function getTargetGroups(target)
	local groups = {}

	-- Character Type: Human, Android, etc.
	table.insert(groups, target:GetRecord():CharacterType():Type().value)

	-- Reaction Group: Civilian, Ganger, Police
	if target:GetStimReactionComponent() then
		local reactionGroup = target:GetStimReactionComponent():GetReactionPreset():ReactionGroup()

		if reactionGroup then
			table.insert(groups, reactionGroup)
		end
	end

	-- Tags: Cyberpsycho
	for _, tag in ipairs(target:GetRecord():Tags()) do
		table.insert(groups, Game.NameToString(tag))
	end

	-- Visual Tags: Affiliation, Role, etc.
	for _, tag in ipairs(target:GetRecord():VisualTags()) do
		table.insert(groups, Game.NameToString(tag))
	end

	return groups
end

registerForEvent('onInit', function()
	GameHUD.Init()

	GameSession.StoreInDir('sessions')
	GameSession.Persist(stats)

	GameSession.OnLoad(function()
		print('Total Kills: ' .. stats.totalKills)
	end)

	GameSession.OnStart(function()
		GameHUD.ShowMessage('Total Kills: ' .. stats.totalKills)
	end)

	Observe('NPCPuppet', 'SendAfterDeathOrDefeatEvent', function(self)
		if self.shouldDie and self.myKiller then
			local player = Game.GetPlayer()

			if self.myKiller:GetEntityID().hash == player:GetEntityID().hash then
				stats.totalKills = stats.totalKills + 1
				stats.lastKillLocation = player:GetWorldPosition()
				stats.lastKillTimestamp = Game.GetTimeSystem():GetGameTimeStamp()

				local groups = getTargetGroups(self)

				for _, group in ipairs(groups) do
					if stats.totalKillsByGroup[group] then
						stats.totalKillsByGroup[group] = stats.totalKillsByGroup[group] + 1
					else
						stats.totalKillsByGroup[group] = 1
					end
				end

				print('Kill #' .. stats.totalKills .. ' (' .. table.concat(groups, ', ') .. ')')

				GameHUD.ShowMessage('Kill #' .. stats.totalKills)
			end
		end
	end)
end)
