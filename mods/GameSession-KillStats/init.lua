local GameSession = require('GameSession')
local GameHUD = require('GameHUD')

local KillStats = {
	totalKills = 0,
	totalKillsByGroup = {},
	lastKillLocation = nil,
	lastKillTimestamp = nil,
}

function KillStats.IsPlayer(target)
	return target and target:GetEntityID().hash == Game.GetPlayer():GetEntityID().hash
end

function KillStats.TrackKill(target)
	local kill = {
		confirmed = false,
		number = 0,
		groups = nil,
	}

	if target.shouldDie and (KillStats.IsPlayer(target.myKiller) or target.wasJustKilledOrDefeated) then
		KillStats.totalKills = KillStats.totalKills + 1
		KillStats.lastKillLocation = Game.GetPlayer():GetWorldPosition()
		KillStats.lastKillTimestamp = Game.GetTimeSystem():GetGameTimeStamp()

		local groups = KillStats.GetTargetGroups(target)

		for _, group in ipairs(groups) do
			KillStats.totalKillsByGroup[group] = (KillStats.totalKillsByGroup[group] or 0) + 1
		end

		kill.confirmed = true
		kill.number = KillStats.totalKills
		kill.groups = groups
	end

	return kill
end

function KillStats.GetTargetGroups(target)
	local groups = {}

	-- Reaction Group: Civilian, Ganger, Police
	if target:GetStimReactionComponent() then
		local reactionGroup = target:GetStimReactionComponent():GetReactionPreset():ReactionGroup()

		if reactionGroup then
			table.insert(groups, reactionGroup)
		end
	end

	-- Character Type: Human, Android, etc.
	table.insert(groups, target:GetRecord():CharacterType():Type().value)

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
	GameSession.Persist(KillStats, true)

	GameSession.OnLoad(function()
		print('Total Kills: ' .. KillStats.totalKills)
	end)

	GameSession.OnStart(function()
		GameHUD.ShowWarning('Total Kills: ' .. KillStats.totalKills, 5.0)
	end)

	Observe('NPCPuppet', 'SendAfterDeathOrDefeatEvent', function(self)
		local kill = KillStats.TrackKill(self)

		if kill.confirmed then
			GameHUD.ShowMessage('Kill #' .. kill.number .. ' ' .. kill.groups[1])

			print('Kill #' .. kill.number .. ' (' .. table.concat(kill.groups, ', ') .. ')')
		end
	end)
end)
