local GameSession = require('GameSession')

local session = {
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
	GameSession.StoreInDir('sessions')
	GameSession.Persist(session)

	Observe('NPCPuppet', 'SendAfterDeathOrDefeatEvent', function(self)
		if self.shouldDie and self.myKiller then
			local player = Game.GetPlayer()

			if self.myKiller:GetEntityID().hash == player:GetEntityID().hash then
				session.totalKills = session.totalKills + 1
				session.lastKillLocation = player:GetWorldPosition()
				session.lastKillTimestamp = Game.GetTimeSystem():GetGameTimeStamp()

				local groups = getTargetGroups(self)

				for _, group in ipairs(groups) do
					if session.totalKillsByGroup[group] then
						session.totalKillsByGroup[group] = session.totalKillsByGroup[group] + 1
					else
						session.totalKillsByGroup[group] = 1
					end
				end

				print('Kill #' .. session.totalKills .. ' (' .. table.concat(groups, ', ') .. ')')
			end
		end
	end)
end)
