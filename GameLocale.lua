local GameLocale = { version = '0.8.1' }

local languageGroupPath = '/language'
local languageInterfaceVarName = 'OnScreen'
local languageSubtitleVarName = 'Subtitles'
local languageVoiceVarName = 'VoiceOver'

local defaultLanguage = 'en-us'
local currentLanguage = {
	[languageInterfaceVarName] = defaultLanguage,
	[languageSubtitleVarName] = defaultLanguage,
	[languageVoiceVarName] = defaultLanguage,
}

local translationDir = 'data/lang'
local translationData = {}

---@type inkTextWidget
local dummyTextWidget

local function getLanguageFromSettings(languageVarName)
	return Game.NameToString(Game.GetSettingsSystem():GetVar(languageGroupPath, languageVarName):GetValue())
end

local function getCurrentLanguage(languageVarName)
	return currentLanguage[languageVarName] or defaultLanguage
end

local function updateCurrentLanguage(languageVarName)
	currentLanguage[languageVarName] = getLanguageFromSettings(languageVarName)
end

local function loadTranslationData(targetLanguage)
	local chunk = loadfile(translationDir .. '/' .. targetLanguage)

	if chunk then
		translationData[targetLanguage] = chunk()
	else
		translationData[targetLanguage] = {}
	end

	if not translationData[defaultLanguage] then
		chunk = loadfile(translationDir .. '/' .. defaultLanguage)
		translationData[defaultLanguage] = chunk and chunk() or {}
	end
end

local function refreshTranslationData()
	for translationLanguage, _ in pairs(translationData) do
		if translationLanguage ~= defaultLanguage then
			local isUsed = false

			for _, activeLanguage in pairs(currentLanguage) do
				if translationLanguage == activeLanguage then
					isUsed = true
					break
				end
			end

			if not isUsed then
				translationData[translationLanguage] = nil
			end
		end
	end
end

local function getLocalizedText(key, targetLanguage)
	if translationData[targetLanguage] == nil then
		loadTranslationData(targetLanguage)
	end

	if translationData[targetLanguage][key] == nil then
		local translation = Game.GetLocalizedText(key)

		if translation ~= '' and translation ~= key then
			translationData[targetLanguage][key] = translation
		elseif targetLanguage ~= defaultLanguage then
			translationData[targetLanguage][key] = getLocalizedText(key, defaultLanguage)
		else
			translationData[targetLanguage][key] = key
		end
	end

	return translationData[targetLanguage][key]
end

local function getLocalizedDate(timestamp)
	if not dummyTextWidget then
		dummyTextWidget = inkTextWidget.new()
	end

	dummyTextWidget:SetDateTimeByTimestamp(timestamp)

	return dummyTextWidget.text
end

function GameLocale.Initialize(translationDataDir)
	if translationDataDir then
		translationDir = translationDataDir
	end

	languageGroupPath = CName.new(languageGroupPath)

	updateCurrentLanguage(languageInterfaceVarName)
	updateCurrentLanguage(languageSubtitleVarName)
	updateCurrentLanguage(languageVoiceVarName)

	Observe('SettingsMainGameController', 'OnVarModified', function(_, groupPath, varName, _, reason)
		if groupPath == languageGroupPath and reason == InGameConfigChangeReason.Accepted then
			updateCurrentLanguage(Game.NameToString(varName))
			refreshTranslationData()
		end
	end)
end

function GameLocale.GetInterfaceLanguage()
	return getCurrentLanguage(languageInterfaceVarName)
end

function GameLocale.GetSubtitleLanguage()
	return getCurrentLanguage(languageSubtitleVarName)
end

function GameLocale.GetAudioLanguage()
	return getCurrentLanguage(languageVoiceVarName)
end

function GameLocale.Text(key)
	return getLocalizedText(key, currentLanguage[languageInterfaceVarName])
end

function GameLocale.Subtitle(key)
	return getLocalizedText(key, currentLanguage[languageSubtitleVarName])
end

function GameLocale.ActionHold(action)
	return ('(%s) %s'):format(
		getLocalizedText('Gameplay-Devices-Interactions-Helpers-Hold', currentLanguage[languageInterfaceVarName]),
		getLocalizedText(action, currentLanguage[languageInterfaceVarName])
	)
end

function GameLocale.Date(timestamp)
	return getLocalizedDate(timestamp)
end

--function GameLocale.GetTranslator()
--	return getLocalizedText
--end

return GameLocale