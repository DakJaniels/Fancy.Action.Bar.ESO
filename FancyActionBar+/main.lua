--- @class (partial) FancyActionBar
local FancyActionBar = FancyActionBar
-------------------------------------------------------------------------------
-----------------------------[    Constants   ]--------------------------------
-------------------------------------------------------------------------------
local NAME = "FancyActionBar+"
local VERSION = "2.19.7"
local slashCommand = "/fab" or "/FAB"
local EM = GetEventManager()
local WM = GetWindowManager()
local SM = SCENE_MANAGER
local strformat = string.format
local tableInsert = table.insert
local tableRemove = table.remove
local time = GetGameTimeSeconds
local MIN_INDEX = 3                          -- first ability index
local MAX_INDEX = 7                          -- last ability index
local ULT_INDEX = 8                          -- ultimate slot index
local QUICK_SLOT = 9                         -- ACTION_BAR_FIRST_UTILITY_BAR_SLOT + 1
local SLOT_INDEX_OFFSET = 20                 -- offset for backbar abilities indices
local COMPANION_INDEX_OFFSET = 30            -- offset for companion ultimate
local SLOT_COUNT = MAX_INDEX - MIN_INDEX + 1 -- total number of slots
local ACTION_BAR = GetControl("ZO_ActionBar1")
local weaponSwapControl = ACTION_BAR:GetNamedChild("WeaponSwap")
local FAB_Default_Bar_Position = GetControl("FAB_Default_Bar_Position")
local FAB_ActionBarFakeQS = GetControl("FAB_ActionBarFakeQS")
local currentWeaponPair = GetHeldWeaponPair()
local isWeaponSwapLocked = false                     -- for tracking weapon swap lock state
local specialHotbarActive = false                    -- for tracking if a specialHotbar is active
local layoutHotbarCategory = HOTBAR_CATEGORY_PRIMARY -- visual row layout; lags GetActiveHotbarCategory during swap
local doneInitialHotbarSetup = false                 -- one-time zone-in setup (rebuild, update loop)
-------------------------------------------------------------------------------
-----------------------------[    Global    ]----------------------------------
-------------------------------------------------------------------------------
FancyActionBar.effects = {}
FancyActionBar.stackMapCache = {}

--- @type table<integer, boolean>
FancyActionBar.toggles = {}        -- works together with effects to update toggled abilities activation
FancyActionBar.stashedEffects = {} -- Used with specialEffects to track prioritized effects from skills that apply multiple with different durations
FancyActionBar.slotStateSpecialEffects = {}

-- Backbar buttons.
FancyActionBar.buttons = {} -- Contains: abilities duration, number of stacks and debuffed targets, and visual effects.
FancyActionBar.slotHidden = {}

--- @type {[1]:(FAB_ActionButtonOverlay_Keyboard_Template|FAB_ActionButtonOverlay_Gamepad_Template),[any] : any|userdata}
FancyActionBar.overlays = {}    -- normal skill button overlays
--- @type {[1]:(FAB_UltimateButtonOverlay_Keyboard_Template|FAB_UltimateButtonOverlay_Gamepad_Template),[any] : any|userdata}
FancyActionBar.ultOverlays = {} -- player and companion ultimate skill button overlays

FancyActionBar.qsOverlay = nil  -- shortcut for.. reasons..
FancyActionBar.effectWidgets = {}
FancyActionBar.effectWidgetControls = {}
FancyActionBar.widgetEffects = {} -- external end-times keyed by abilityId, isolated from main effects table
FancyActionBar.externalTrackingIds = {}

FancyActionBar.wasMoved = false              -- don't move action bar if it wasn't moved to begin with
FancyActionBar.wasStopped = false            -- don't register updates if already registered
FancyActionBar.useGamepadActionBar = false   -- gamepad action bar style active
FancyActionBar.style = nil                   -- 1 = keyboard, 2 = gamepad (set by UpdateStyle)

FancyActionBar.inCombat = false              -- for GCD

FancyActionBar.weaponFront = WEAPONTYPE_NONE -- for getting correct id's for destro staff skills on back bar
FancyActionBar.weaponBack = WEAPONTYPE_NONE
FancyActionBar.oakensoul = "/esoui/art/icons/u34_mythic_oakensoul_ring.dds"
FancyActionBar.oakensoulEquipped = false
FancyActionBar.isWerewolf = false

FancyActionBar.durationMin = 4
FancyActionBar.durationMax = 99

FancyActionBar.player = { name = "", id = 0 } -- might be needed to check for some effects before updating timer

-- all current values for the UI and configuration to use. not sure why I called it 'constants' when they are all in fact variables.
FancyActionBar.constants = nil
-------------------------------------------------------------------------------
-----------------------------[    Tables    ]----------------------------------
-------------------------------------------------------------------------------
local defaultSettings = FancyActionBar.defaultSettings -- default settings variables...
local abilityConfig = {}                               -- parsed FancyActionBar.abilityConfig.
local slots = {}
local sourceAbilities = {}                             -- to track which abilities are currently slotting effects
local slottedEffectIds = {}                            -- to match skills with their tracked effect
local lastAreaTargets = {}                             -- unit id for 'offline' target when casting ground effects always change. check if it was the same target id before fading if before 0
local registeredSkillLines = {}                        -- to track skill lines that have been registered for ability changes
-------------------------------------------------------------------------------
---------------------------[   Local Variables   ]-----------------------------
-------------------------------------------------------------------------------
local SV = ...         -- saved variables (accountwide)
local CV = ...         -- saved variables (character)
local debug = false    -- debug mode

local scale = 1        -- action bar scale factor (ApplyBarFoundation)
local updateRate = 100 -- overlay update interval

local hasEnabledEffectWidgets = false
local companionOverlayActive = false

local channeledAbility =
{
    id = nil,               -- ability id being tracked (pending or active)
    pending = false,        -- true after OnAbilityUsed when castDuration discovered
    active = false,         -- true while channel/cast is active
    castEndTime = nil,      -- cast end time (seconds)
    castDuration = nil,     -- recorded cast duration (seconds)
    wasBlockActive = false, -- previous frame block state for edge-triggered channel cancel
}

local ULT_STUB_EFFECT = { id = 0, endTime = -1 }
local playerUltTimer = { endTime = nil, instantFade = nil, beginTime = nil, isParentTime = nil, lastTime = -1 }
local highlights = { regular = {}, ult = {} }
local ultCosts = { guardId = 0, cost1 = 0, cost2 = 0, cost3 = 0, costAlt = 0 }
local WT =
{
    NONE = WEAPONTYPE_NONE,
    FIRE = WEAPONTYPE_FIRE_STAFF,
    FROST = WEAPONTYPE_FROST_STAFF,
    LIGHTNING = WEAPONTYPE_LIGHTNING_STAFF,
}

local function GetInactiveHotbarCategory(activeHotbarCategory)
    if activeHotbarCategory ~= HOTBAR_CATEGORY_PRIMARY and activeHotbarCategory ~= HOTBAR_CATEGORY_BACKUP then
        activeHotbarCategory = HOTBAR_CATEGORY_PRIMARY
    end
    if activeHotbarCategory == HOTBAR_CATEGORY_PRIMARY then
        return HOTBAR_CATEGORY_BACKUP
    end
    if activeHotbarCategory == HOTBAR_CATEGORY_BACKUP then
        return HOTBAR_CATEGORY_PRIMARY
    end
    return HOTBAR_CATEGORY_BACKUP
end

local function HideAllAbilityActionButtonDropCallouts()
    for i = MIN_INDEX, ULT_INDEX do
        local button = ZO_ActionBar_GetButton(i)
        if button and button.slot then
            local callout = button.slot:GetNamedChild("DropCallout")
            if callout then
                callout:SetHidden(true)
            end
        end
    end

    for i = MIN_INDEX + SLOT_INDEX_OFFSET, MAX_INDEX + SLOT_INDEX_OFFSET do
        local button = FancyActionBar.buttons[i]
        if button and button.slot then
            local callout = button.slot:GetNamedChild("DropCallout")
            if callout then
                callout:SetHidden(true)
            end
        end
    end
end

local function ShowAppropriateAbilityActionButtonDropCallouts(actionType, actionValue)
    local validityFunction = FancyActionBar.dropCalloutValidityByActionType[actionType]
    if not validityFunction then
        return
    end

    HideAllAbilityActionButtonDropCallouts()

    for i = MIN_INDEX, ULT_INDEX do
        local button = ZO_ActionBar_GetButton(i)
        if button and button.slot then
            local callout = button.slot:GetNamedChild("DropCallout")
            if callout then
                local isValid = validityFunction(actionValue, i)
                callout:SetColor(1, isValid and 1 or 0, isValid and 1 or 0, 1)
                callout:SetHidden(false)
            end
        end
    end

    for i = MIN_INDEX + SLOT_INDEX_OFFSET, MAX_INDEX + SLOT_INDEX_OFFSET do
        local button = FancyActionBar.buttons[i]
        if button and button.slot then
            local callout = button.slot:GetNamedChild("DropCallout")
            if callout then
                local isValid = validityFunction(actionValue, i - SLOT_INDEX_OFFSET)
                callout:SetColor(1, isValid and 1 or 0, isValid and 1 or 0, 1)
                callout:SetHidden(false)
            end
        end
    end
end

local function AttemptPlacement(slotNum, hotbarCategory)
    CallSecureProtected("PlaceInActionBar", unpack({ slotNum, hotbarCategory }))
end

local function AttemptPickup(slotNum, hotbarCategory)
    if ZO_ActionBar_AreActionBarsLocked() then
        return
    end

    CallSecureProtected("PickupAction", unpack({ slotNum, hotbarCategory }))
    ClearTooltip(AbilityTooltip)
end
--------------------------------------------------------------------------------
-----------------------------[ 		Utility    ]----------------------------------
--------------------------------------------------------------------------------

do
    --- Adds a system message to the chat.
    --- @param messageOrFormatter string: The message to be printed.
    --- @param ... string: Variable number of arguments to be formatted into the message.
    local function AddSystemMessage(messageOrFormatter, ...)
        if not SV.debug then
            return
        end
        local formattedMessage
        if select("#", ...) > 0 then
            formattedMessage = strformat(messageOrFormatter or "", ...)
        else
            formattedMessage = messageOrFormatter or ""
        end
        CHAT_ROUTER:AddSystemMessage(formattedMessage)
    end

    FancyActionBar.AddSystemMessage = AddSystemMessage
end

--- Slash command handler
--- @param str string
function FancyActionBar.SlashCommand(str)
    local setting
    if SV.debuffTable == nil then
        SV.debuffTable = {}
    end
    local cmd = string.lower(str)
    if cmd == "dbg 0" then
        SV.debug = false
        SV.debugAll = false
        FancyActionBar.AddSystemMessage("[FAB+] debug: Off.")
    elseif cmd == "dbg 1" then
        SV.debug = not SV.debug
        if SV.debug then
            setting = "On."
        else
            setting = "Off."
        end
        FancyActionBar.AddSystemMessage("[FAB+] debug1: " .. setting)
    elseif cmd == "dbg 2" then
        SV.debugAll = not SV.debugAll
        if SV.debugAll then
            setting = "On."
        else
            setting = "Off."
        end
        FancyActionBar.AddSystemMessage("[FAB+] debugAll: " .. setting)
    elseif cmd == "dbg 3" then
        SV.debugVerbose = not SV.debugVerbose
        if SV.debugVerbose then
            setting = "On."
        else
            setting = "Off."
        end
        FancyActionBar.AddSystemMessage("[FAB+] Verbose debug: " .. setting)
    elseif cmd == "bar1" then
        FancyActionBar.PostSlottedSkills(1)
    elseif cmd == "bar2" then
        FancyActionBar.PostSlottedSkills(2)
    elseif cmd == "bars" then
        FancyActionBar.PostSlottedSkills(3)
    elseif cmd == "overlay" then
        FancyActionBar.PostOverlayEffects()
    elseif cmd == "track" then
        FancyActionBar.PostAbilityConfig()
    elseif cmd == "stacks" then
        for id, effect in pairs(FancyActionBar.stackMap) do
            for i = 1, #effect do
                FancyActionBar.AddSystemMessage("[" .. id .. "] = " .. effect[i])
            end
        end
    elseif cmd == "targets" then
        for id, effect in pairs(FancyActionBar.effects) do
            if effect and effect.targets then
                FancyActionBar.AddSystemMessage("[" .. id .. "] targets = " .. tostring(effect.targets.unitCount or 0))
            end
        end
    elseif cmd == "dbt" then
        FancyActionBar.AddSystemMessage("[FAB+] Registered Debuff IDs:")
        for id in pairs(SV.debuffTable) do
            FancyActionBar.AddSystemMessage(tostring(id))
        end
    end
end

--- @param index number
--- @param bar? HotBarCategory
--- @return integer abilityId
function FancyActionBar.GetSlotBoundAbilityId(index, bar)
    bar = bar or GetActiveHotbarCategory()
    local id = GetSlotBoundId(index, bar)
    local actionType = GetSlotType(index, bar)
    if actionType == ACTION_TYPE_CRAFTED_ABILITY then
        id = GetAbilityIdForCraftedAbilityId(id)
    elseif FancyActionBar.barHighlightDestroFix[id] then
        local weaponType = bar == HOTBAR_CATEGORY_BACKUP and FancyActionBar.weaponBack or FancyActionBar.weaponFront
        id = FancyActionBar.GetCorrectedAbilityId(id, weaponType)
    end
    return id
end

--- Gets corrected ability ID based on weapon type and special cases
--- @param abilityId integer Original ability ID
--- @param weaponType number Weapon type (WEAPONTYPE_* constants)
--- @return integer Corrected ability ID
function FancyActionBar.GetCorrectedAbilityId(abilityId, weaponType)
    local correctedAbilityId = abilityId
    local barHighlightDestroFix = FancyActionBar.barHighlightDestroFix

    -- Only process abilities that have staff variants defined in the fix table
    if not barHighlightDestroFix[abilityId] then
        return abilityId
    end

    -- Only apply correction for staff weapon types
    if weaponType == WT.FIRE or weaponType == WT.FROST or weaponType == WT.LIGHTNING or weaponType == WT.NONE then
        if barHighlightDestroFix[abilityId] and barHighlightDestroFix[abilityId][weaponType] then
            correctedAbilityId = barHighlightDestroFix[abilityId][weaponType]

            -- Debug output if enabled
            if FancyActionBar.IsDebugMode() then
                local staffType = "unknown"
                if weaponType == WT.FIRE then
                    staffType = "fire"
                elseif weaponType == WT.FROST then
                    staffType = "frost"
                elseif weaponType == WT.LIGHTNING then
                    staffType = "lightning"
                elseif weaponType == WT.NONE then
                    staffType = "none"
                end

                FancyActionBar.AddSystemMessage("Corrected ability ID from %d to %d for %s staff",
                    abilityId, correctedAbilityId, staffType)
            end
        end
    end

    return correctedAbilityId
end

function FancyActionBar.GetAbilityDuration(abilityId, overrideActiveRank, overrideCasterUnitTag)
    overrideCasterUnitTag = overrideCasterUnitTag or "player"
    return GetAbilityDuration(abilityId, overrideActiveRank, overrideCasterUnitTag)
end

function FancyActionBar.GetSkillStyleIconForAbilityId(abilityId)
    if FancyActionBar.barHighlightDestroFix[abilityId] then
        abilityId = FancyActionBar.GetCorrectedAbilityId(abilityId, WT.NONE)
    elseif FancyActionBar.styleFix[abilityId] then
        abilityId = FancyActionBar.styleFix[abilityId]
    end
    local skillType, skillLineIndex, skillIndex = GetSpecificSkillAbilityKeysByAbilityId(abilityId)
    local progressionId = GetProgressionSkillProgressionId(skillType, skillLineIndex, skillIndex)
    local collectibleId = GetActiveProgressionSkillAbilityFxOverrideCollectibleId(progressionId)
    if not collectibleId or collectibleId == 0 then
        return nil
    end
    local collectibleIcon = GetCollectibleIcon(collectibleId)
    return collectibleIcon
end

function FancyActionBar.SkillStyleCollectibleUpdated(collectibleId)
    if not SV.applyActionBarSkillStyles then
        return
    end
    FancyActionBar.PaintAbilityOverlays()
    FancyActionBar.RefreshActiveBarIconVisuals()
end

local function GetConfiguredStackSources(spec)
    return spec and (spec.stackSources or spec.stackId) or FancyActionBar.emptyStackList
end

do
    local function lookupInStackMap(mapTable, memberIndex, abilityId)
        if not mapTable then
            return nil, nil
        end
        if mapTable[abilityId] then
            return mapTable[abilityId], abilityId
        end
        local memberEntry = memberIndex and memberIndex[abilityId]
        if memberEntry then
            return memberEntry.sources, memberEntry.sourceId
        end
        return nil, nil
    end

    local function buildStackMapMemberIndex(stackMapTable)
        local memberIndex = {}
        if not stackMapTable then
            return memberIndex
        end
        for sourceId, configuredSourceIds in pairs(stackMapTable) do
            for i = 1, #configuredSourceIds do
                local memberId = configuredSourceIds[i]
                if not stackMapTable[memberId] and not memberIndex[memberId] then
                    memberIndex[memberId] = { sources = configuredSourceIds, sourceId = sourceId }
                end
            end
        end
        return memberIndex
    end

    local function resolveStackMapEntry(abilityId, mapType)
        local stackMap = FancyActionBar.stackMap or {}
        local debuffStackMap = FancyActionBar.debuffStackMap or {}
        local primary = (mapType == "debuff") and debuffStackMap or stackMap
        local secondary = (mapType == "debuff") and stackMap or debuffStackMap
        local stackMapMemberIndex = FancyActionBar.stackMapMemberIndex
        local debuffStackMapMemberIndex = FancyActionBar.debuffStackMapMemberIndex
        local primaryMemberIndex = (mapType == "debuff") and debuffStackMapMemberIndex or stackMapMemberIndex
        local secondaryMemberIndex = (mapType == "debuff") and stackMapMemberIndex or debuffStackMapMemberIndex

        local configuredSourceIds, sourceId = lookupInStackMap(primary, primaryMemberIndex, abilityId)
        if not configuredSourceIds then
            configuredSourceIds, sourceId = lookupInStackMap(secondary, secondaryMemberIndex, abilityId)
        end
        if not configuredSourceIds then
            configuredSourceIds = { abilityId }
            sourceId = nil
        end
        local ownerId = sourceId or abilityId
        return { sources = configuredSourceIds, sourceId = sourceId, ownerId = ownerId }
    end

    local function collectStackMapIds(allIds, stackMapTable)
        if not stackMapTable then
            return
        end
        for sourceId, configuredSourceIds in pairs(stackMapTable) do
            allIds[sourceId] = true
            for i = 1, #configuredSourceIds do
                allIds[configuredSourceIds[i]] = true
            end
        end
    end

    function FancyActionBar.BuildStackMapLookups()
        FancyActionBar.stackMapMemberIndex = buildStackMapMemberIndex(FancyActionBar.stackMap)
        FancyActionBar.debuffStackMapMemberIndex = buildStackMapMemberIndex(FancyActionBar.debuffStackMap)

        local cache = FancyActionBar.stackMapCache
        for cacheKey in pairs(cache) do
            cache[cacheKey] = nil
        end

        local allIds = {}
        collectStackMapIds(allIds, FancyActionBar.stackMap)
        collectStackMapIds(allIds, FancyActionBar.debuffStackMap)

        for abilityId in pairs(allIds) do
            cache[abilityId] = resolveStackMapEntry(abilityId, nil)
            cache[abilityId .. ":debuff"] = resolveStackMapEntry(abilityId, "debuff")
        end
    end

    function FancyActionBar.GetStackMap(abilityId, mapType)
        if not abilityId or abilityId == 0 then
            return { sources = FancyActionBar.emptyStackList, sourceId = nil, ownerId = abilityId }
        end

        local cache = FancyActionBar.stackMapCache
        local cacheKey = mapType and (abilityId .. ":" .. mapType) or abilityId
        local cached = cache[cacheKey]
        if cached then
            return cached
        end

        local entry = resolveStackMapEntry(abilityId, mapType)
        cache[cacheKey] = entry
        return entry
    end
end

function FancyActionBar.GetStackOwnerId(abilityId, mapType)
    return FancyActionBar.GetStackMap(abilityId, mapType).ownerId
end

function FancyActionBar.GetStackSourceId(abilityId, mapType)
    return FancyActionBar.GetStackMap(abilityId, mapType).sourceId
end

function FancyActionBar.IsStackMapMember(abilityId)
    if not abilityId or abilityId == 0 then return false end
    if FancyActionBar.fixedStacks[abilityId] ~= nil then return true end
    local stackMap = FancyActionBar.stackMap
    local debuffStackMap = FancyActionBar.debuffStackMap
    if (stackMap and stackMap[abilityId]) or (debuffStackMap and debuffStackMap[abilityId]) then
        return true
    end
    local sourceId = FancyActionBar.GetStackSourceId(abilityId)
    return sourceId ~= nil and sourceId ~= abilityId
end

function FancyActionBar.GetStacks(abilityId, currentTime, mapType)
    if not abilityId or abilityId == 0 then
        return 0
    end

    currentTime = currentTime or time()
    local ownerId = FancyActionBar.GetStackOwnerId(abilityId, mapType)
    local stackableBuff = FancyActionBar.stackableBuff
    local trackedId = (stackableBuff and stackableBuff[ownerId]) or ownerId
    local effects = FancyActionBar.effects
    local trackedEffect = effects and effects[trackedId]
    local fixedStacks = FancyActionBar.fixedStacks

    if fixedStacks[trackedId] then
        if trackedEffect and trackedEffect.stacks then
            if type(trackedEffect.stacks) == "string" then
                return trackedEffect.stacks ~= "" and fixedStacks[trackedId] or 0
            elseif trackedEffect.stacks > 0 then
                return fixedStacks[trackedId]
            end
        end
        return 0
    end

    if trackedEffect then
        if trackedEffect.sources and trackedEffect.sources.times and FancyActionBar.IsStackableBuff(trackedId) then
            return FancyActionBar.RecomputeUnits(trackedId, currentTime, "sources") or 0
        end
        if trackedEffect.stacks ~= nil then
            return trackedEffect.stacks
        end
    end

    return 0
end

function FancyActionBar.SetStacks(abilityId, stacks, force, mapType)
    if not abilityId then return end

    local ownerId = FancyActionBar.GetStackOwnerId(abilityId, mapType)
    local effects = FancyActionBar.effects
    if not effects then return end
    local eff = effects[ownerId] or FancyActionBar.GetEffect(ownerId)
    if not eff then return end

    local currentTime = time()
    if type(stacks) == "string" and FancyActionBar.fixedStacks[ownerId] == nil then
        stacks = 0
    end
    if stacks == nil and not force and eff.sources and eff.sources.times and FancyActionBar.IsStackableBuff(ownerId) then
        stacks = FancyActionBar.RecomputeUnits(ownerId, currentTime, "sources") or 0
    elseif stacks == nil and not force then
        return
    end
    if eff.stacks == stacks and not force then return end
    eff.stacks = stacks
    effects[ownerId] = eff
end

local function AccumulateMaxStacks(maxStacks, sourceStacks)
    if type(sourceStacks) == "string" then
        return sourceStacks
    end
    if type(sourceStacks) == "number" and sourceStacks > maxStacks then
        return sourceStacks
    end
    return maxStacks
end

function FancyActionBar.GetDisplayStacks(effect, currentTime)
    if not effect then return 0 end
    currentTime = currentTime or time()
    local isDebuff = effect.isDebuff == true
    local sourceIds = effect.stackSources
    if not sourceIds or #sourceIds == 0 then
        local entry = FancyActionBar.GetStackMap(effect.id, isDebuff and "debuff" or nil)
        sourceIds = entry.sources
    end
    local count = #sourceIds
    if count == 0 then return 0 end

    if isDebuff then
        local debuffStackMap = FancyActionBar.debuffStackMap
        local maxStacks = 0
        local ownerId = effect.stackOwnerId or effect.id
        local ownerMapType = debuffStackMap and debuffStackMap[ownerId] and "debuff" or nil
        if ownerMapType then
            maxStacks = AccumulateMaxStacks(maxStacks, FancyActionBar.GetStacks(ownerId, currentTime, ownerMapType))
            if type(maxStacks) == "string" then return maxStacks end
        end
        for i = 1, count do
            local sourceId = sourceIds[i]
            if sourceId ~= ownerId or not ownerMapType then
                local sourceMapType = debuffStackMap and debuffStackMap[sourceId] and "debuff" or nil
                local sourceStacks = FancyActionBar.GetStacks(sourceId, currentTime, sourceMapType)
                maxStacks = AccumulateMaxStacks(maxStacks, sourceStacks)
                if type(maxStacks) == "string" then return maxStacks end
            end
        end
        return maxStacks
    end

    if count == 1 then
        local sourceId = sourceIds[1]
        local lookupId = effect.stackOwnerId
        if not lookupId then
            lookupId = FancyActionBar.GetStackOwnerId(sourceId)
        end
        return FancyActionBar.GetStacks(lookupId or sourceId, currentTime)
    end

    local commonOwner = effect.stackOwnerId
    if not commonOwner then
        commonOwner = FancyActionBar.GetStackOwnerId(sourceIds[1])
    end
    commonOwner = commonOwner or sourceIds[1]
    local canUseOwnerShortcut = not FancyActionBar.IsStackableBuff(sourceIds[1])
    local stackableBuff = FancyActionBar.stackableBuff
    if canUseOwnerShortcut and stackableBuff and stackableBuff[sourceIds[1]] then
        canUseOwnerShortcut = false
    end
    for i = 2, count do
        local sourceId = sourceIds[i]
        local owner = FancyActionBar.GetStackSourceId(sourceId)
        owner = owner or sourceId
        if owner ~= commonOwner
            or FancyActionBar.IsStackableBuff(sourceId)
            or (stackableBuff and stackableBuff[sourceId])
        then
            canUseOwnerShortcut = false
            break
        end
    end
    if canUseOwnerShortcut then
        return FancyActionBar.GetStacks(commonOwner, currentTime)
    end

    local maxStacks = 0
    for i = 1, count do
        maxStacks = AccumulateMaxStacks(maxStacks, FancyActionBar.GetStacks(sourceIds[i], currentTime))
        if type(maxStacks) == "string" then return maxStacks end
    end
    return maxStacks
end

function FancyActionBar.UpdateStacksFromEvent(abilityId, stackCount, isFade)
    local debuffStackMap = FancyActionBar.debuffStackMap
    local debuffMapType = debuffStackMap and debuffStackMap[abilityId] and "debuff" or nil
    local stackEntry = FancyActionBar.GetStackMap(abilityId, debuffMapType)
    local configuredSourceIds = stackEntry.sources
    local sourceId = stackEntry.sourceId
    local fixedDisplayId = nil
    local fixedDisplayCount = 0
    local effects = FancyActionBar.effects
    local ownsStackStorage = not sourceId or sourceId == abilityId

    for i = 1, #configuredSourceIds do
        local configuredId = configuredSourceIds[i]
        if FancyActionBar.fixedStacks[configuredId] then
            fixedDisplayCount = fixedDisplayCount + 1
            if configuredId == abilityId then
                fixedDisplayId = configuredId
                break
            end
            local configuredEffect = effects and effects[configuredId]
            if configuredEffect and (configuredEffect.slot1 or configuredEffect.slot2) then
                fixedDisplayId = configuredId
                break
            end
            for _, slot in pairs(slots) do
                if slot.abilityId == configuredId or slot.effectId == configuredId then
                    fixedDisplayId = configuredId
                    break
                end
            end
            if fixedDisplayId then break end
            if not fixedDisplayId then
                fixedDisplayId = configuredId
            end
        end
    end

    if fixedDisplayCount > 1 and FancyActionBar.fixedStacks[abilityId] == nil then
        return
    end

    if debuffMapType == nil and fixedDisplayId and debuffStackMap[abilityId] and fixedDisplayId ~= abilityId and not FancyActionBar.fixedStacks[abilityId] then
        return
    end

    if not ownsStackStorage and not fixedDisplayId and not sourceId and debuffMapType == nil then
        return
    end

    local stackSourceId
    if debuffMapType and not FancyActionBar.fixedStacks[abilityId] then
        stackSourceId = sourceId or abilityId
    else
        stackSourceId = fixedDisplayId or sourceId or abilityId
    end
    local fixedStackValue = FancyActionBar.fixedStacks[stackSourceId]

    if fixedStackValue then
        local val = isFade and 0 or fixedStackValue
        FancyActionBar.SetStacks(stackSourceId, val, true, debuffMapType)
        return
    end

    if stackCount ~= nil then
        local nextStacks = stackCount
        if isFade and stackCount > 0 then
            local currentStacks = FancyActionBar.GetStacks(stackSourceId, nil, debuffMapType) or 0
            nextStacks = zo_max(currentStacks - stackCount, 0)
        end
        FancyActionBar.SetStacks(stackSourceId, nextStacks, true, debuffMapType)
        return
    end

    if isFade then
        FancyActionBar.SetStacks(stackSourceId, 0, true, debuffMapType)
    end
end

function FancyActionBar.IsStackableBuff(id)
    local set = FancyActionBar.stackableBuffSet
    if set then
        return set[id] == true
    end
    local sb = FancyActionBar.stackableBuff
    if not sb then return false end
    if sb[id] then return true end
    for _, v in pairs(sb) do
        if v == id then return true end
    end
    return false
end

local function WasEffectCastByPlayer(effect)
    if not effect then
        return false
    end
    if effect.hasActiveCast then
        return true
    end
    if not (effect.sources and effect.sources.times) then
        return false
    end

    for _, entry in pairs(effect.sources.times) do
        if entry.meta and entry.meta.castByPlayer then
            return true
        end
    end

    return false
end

---
--- @param index number
--- @param bar HotBarCategory
--- @return string
local function GetSlotInfoString(index, bar)
    local slot = index == 8 and "Ult" or tostring(index - 2)
    local string = "[" .. slot .. "] "
    local id = FancyActionBar.GetSlotBoundAbilityId(index, bar)
    if id > 0 then
        local name = GetAbilityName(id)
        string = string .. "<" .. name .. "> " .. id
    end
    return string
end

function FancyActionBar.PostAbilityConfig()
    FancyActionBar.AddSystemMessage("FAB+ Ability Configuration:")

    local s = FancyActionBar.abilityConfig

    for skill, id in pairs(s) do
        local v --- @type string

        if type(id) == "table" then
            if id[1] == nil then
                v = "{}"
            else
                v = tostring(id[1])
            end
        else
            v = tostring(id)
        end
        FancyActionBar.AddSystemMessage("[|cffffff" .. tostring(skill) .. "|r] = |cff6600" .. v .. "|r")
    end
end

---
--- @param bar HotBarCategory
function FancyActionBar.PostSlottedSkills(bar)
    FancyActionBar.AddSystemMessage("[FAB+] Current Skills:")
    if bar == 1 or bar == 3 then
        FancyActionBar.AddSystemMessage("Front Bar")
        for i = 3, 8 do
            FancyActionBar.AddSystemMessage(GetSlotInfoString(i, 0))
        end
    end
    if bar == 2 or bar == 3 then
        FancyActionBar.AddSystemMessage("Back Bar")
        for i = 3, 8 do
            FancyActionBar.AddSystemMessage(GetSlotInfoString(i, 1))
        end
    end
end

function FancyActionBar.PostOverlayEffects()
    for i = 3, 7 do
        local o1 = FancyActionBar.overlays[i]
        local o2 = FancyActionBar.overlays[i + 20]
        if o1.effect and o1.effect.id and o1.effect.id > 0 then
            FancyActionBar.AddSystemMessage("[" .. i .. "]: " .. o1.effect.id)
            for k, v in pairs(o1.effect) do
                FancyActionBar.AddSystemMessage(" - [" .. k .. "]: " .. tostring(v))
            end
        end
        if o2.effect and o2.effect.id and o2.effect.id > 0 then
            FancyActionBar.AddSystemMessage("[" .. i + 20 .. "]: " .. o2.effect.id)
            for k, v in pairs(o2.effect) do
                FancyActionBar.AddSystemMessage(" - [" .. k .. "]: " .. tostring(v))
            end
        end
    end
end

function FancyActionBar.IsDebugMode()
    return debug
end

---
--- @param mode boolean
function FancyActionBar.SetDebugMode(mode)
    assert(type(mode) == "boolean", "Debug mode must be boolean.")
    debug = mode
end

---
--- @return string
function FancyActionBar.GetName()
    return NAME
end

---
--- @return string
function FancyActionBar.GetVersion()
    return VERSION
end

---
--- @return number
function FancyActionBar.GetScale()
    return scale
end

--- @return table style template for the active UI mode
function FancyActionBar.GetConstants()
    if not (FancyActionBar.constants and FancyActionBar.constants.style) then
        FancyActionBar.UpdateStyle()
    end
    return FancyActionBar.constants.style
end

---
--- @return table
function FancyActionBar.GetExternalBlacklist()
    return SV.externalBlackList
end

---
--- @return table
function FancyActionBar.GetMultiTargetBlacklist()
    return SV.multiTargetBlacklist
end

---
--- @return table
function FancyActionBar.GetParentTimeBlacklist()
    return SV.parentTimeBlacklist
end

---
--- @return table var
--- @return table def
function FancyActionBar:GetMovableVarsForUI()
    local c = FancyActionBar.constants
    return c.move, c.mode == 2 and defaultSettings.abMove.gp or defaultSettings.abMove.kb
end

---
--- @return number durationMin
--- @return number durationMax
function FancyActionBar.GetAbilityDurationLimits()
    return SV.durationMin, SV.durationMax
end

function FancyActionBar.UpdateDurationLimits()
    FancyActionBar.durationMin, FancyActionBar.durationMax = FancyActionBar.GetAbilityDurationLimits()
end

--- @class ActionBarConstants
--- @field abilitySlotWidth integer
--- @field actionBarOffset integer
--- @field anchor table|ZO_Anchor
--- @field anchorOffsetY integer
--- @field attributesOffset integer
--- @field bindingTextOnUlt boolean
--- @field buttonTemplate string
--- @field buttonTextOffsetY integer
--- @field dimensions integer
--- @field flipCardSize integer
--- @field overlayTemplate string
--- @field qsOverlayTemplate string
--- @field quickslotOffsetX integer
--- @field showKeybindBG boolean
--- @field ultButtonTemplate string
--- @field ultFlipCardSize integer
--- @field ultOverlayTemplate string
--- @field ultSize integer
--- @field ultimateSlotOffsetX integer
--- @field width integer

--- @class FancyActionBarConstants
--- @field abScale table
--- @field ultScale table
--- @field qsScale table
--- @field abilitySlot table
--- @field duration table
--- @field hideOnNoTargetGlobal {[integer]:boolean}
--- @field hideOnNoTargetList {[integer]:boolean}
--- @field move table
--- @field noTargetAlpha integer
--- @field noTargetFade any
--- @field qs table
--- @field stacks table
--- @field style ActionBarConstants
--- @field mode integer
--- @field isGamepad boolean
--- @field layout table
--- @field scaled table
--- @field targets table
--- @field ult table
--- @field update table

local function GetBarEndOffset(c, style)
    local slotOffsetX = c.abilitySlot.offsetX
    local f1 = style.abilitySlotWidth + slotOffsetX
    return (f1 * SLOT_COUNT) - 2
end

local function GetEffectiveBarScale()
    local c = FancyActionBar.constants
    if c and c.abScale.enable and not SV.forceAzurahMover then
        return c.abScale.scale / 100
    end
    return 1
end

local function GetEffectiveUltScale()
    local c = FancyActionBar.constants
    if c and c.ultScale.enable then
        return c.ultScale.scale / 100
    end
    return scale or 1
end

local function GetUltChildScale()
    local barScale = scale or 1
    return barScale == 0 and 1 or GetEffectiveUltScale() / barScale
end

local function GetEffectiveQsScale()
    local c = FancyActionBar.constants
    if c and c.qsScale and c.qsScale.enable then
        return c.qsScale.scale / 100
    end
    return scale or 1
end

local function GetQsChildScale()
    local barScale = scale or 1
    return barScale == 0 and 1 or GetEffectiveQsScale() / barScale
end

function FancyActionBar.ApplyScaleToLayout(s)
    local c = FancyActionBar.constants
    local layout = c.layout
    local style = c.style
    local slotOffsetX = c.abilitySlot.offsetX
    local qsAnchor = style.quickSlotAnchor
    local slotSpan = qsAnchor.multiplySlotCount and (SLOT_COUNT * slotOffsetX) or slotOffsetX
    local ultSpace = style.ultimateSpacing or {}
    local ultS = GetEffectiveUltScale()

    c.scaled =
    {
        quickSlot =
        {
            x = layout.quickSlot.x * s,
            y = layout.quickSlot.y * s,
            anchorX = -(qsAnchor.base + slotSpan + layout.quickSlot.x) * s,
        },
        ultimate =
        {
            anchorX = (style.ultimateSlotOffsetX + layout.ultimate.x) * s,
            anchorY = layout.ultimate.y * s,
            companionGap = (ultSpace.companionExtraX or style.ultimateSlotOffsetX) * ultS,
            slotGap = style.ultimateSlotOffsetX * ultS,
            trailing = ultSpace.trailing or 0,
            barEndX = GetBarEndOffset(c, style),
            ultWidth = (ultSpace.ultWidth or 65) * ultS,
            baseX = (ultSpace.baseX or 10) * ultS,
            baseGap = (ultSpace.baseGap or 10) * ultS,
        },
        bar =
        {
            x = layout.bar.halfX,
            y = layout.bar.halfY,
        },
    }
end

function FancyActionBar.RefreshLayoutConstants()
    local c = FancyActionBar.constants
    c.layout = FancyActionBar.BuildLayout(SV, c.mode)
    c.abilitySlot.offsetX = SV[FancyActionBar.SvKey("abilitySlotOffsetX", c.mode)]
    FancyActionBar.ApplyScaleToLayout(scale)
end

function FancyActionBar.SetScale()
    if not FancyActionBar.constants then
        return
    end
    scale = GetEffectiveBarScale()
    FancyActionBar.UpdateScale(scale)
    FancyActionBar.ApplyScaleToLayout(scale)
    FancyActionBar.SetUltScale()
    FancyActionBar.SetQsScale()
end

---
--- @return table
function FancyActionBar.GetAbilityConfig()
    return FancyActionBar.abilityConfig
end

local function GetAbilityConfigSavedVars()
    if CV.useAccountWide then
        return SV
    end
    return CV
end

local function GetFirstAbilityConfigProfileId(profiles)
    local firstProfileId = nil

    for profileId in pairs(profiles) do
        if firstProfileId == nil or profileId < firstProfileId then
            firstProfileId = profileId
        end
    end

    return firstProfileId
end

local function GetUniqueAbilityConfigProfileName(savedVars, profileName, ignoredProfileId)
    local trimmedName = type(profileName) == "string" and profileName:match("^%s*(.-)%s*$") or ""
    local candidateName
    local suffix = 2

    if trimmedName == "" then
        trimmedName = FancyActionBar.defaultAbilityConfigProfileName
    end

    candidateName = trimmedName

    while true do
        local duplicateFound = false

        for profileId, profile in pairs(savedVars.configProfiles) do
            if profileId ~= ignoredProfileId and string.lower(profile.name) == string.lower(candidateName) then
                duplicateFound = true
                candidateName = string.format("%s (%d)", trimmedName, suffix)
                suffix = suffix + 1
                break
            end
        end

        if not duplicateFound then
            break
        end
    end

    return candidateName
end

local function EnsureAbilityConfigProfiles(savedVars)
    local profiles = savedVars.configProfiles
    local maxProfileId = 0

    if type(profiles) ~= "table" then
        profiles = {}
        savedVars.configProfiles = profiles
    end

    for profileId, profile in pairs(profiles) do
        if type(profileId) == "number" and profileId > maxProfileId then
            maxProfileId = profileId
        end

        if type(profile) ~= "table" then
            profiles[profileId] =
            {
                name = FancyActionBar.defaultAbilityConfigProfileName .. " " .. tostring(profileId),
                changes = {},
            }
        else
            if type(profile.name) ~= "string" or profile.name == "" then
                profile.name = profileId == 1 and FancyActionBar.defaultAbilityConfigProfileName or ("Profile " .. tostring(profileId))
            end
            if type(profile.changes) ~= "table" then
                profile.changes = {}
            end
        end
    end

    if next(profiles) == nil then
        local legacyChanges = {}

        if type(savedVars.configChanges) == "table" and next(savedVars.configChanges) then
            legacyChanges = ZO_DeepTableCopy(savedVars.configChanges)
        end

        profiles[1] =
        {
            name = FancyActionBar.defaultAbilityConfigProfileName,
            changes = legacyChanges,
        }
        maxProfileId = 1
    end

    if not savedVars.selectedConfigProfile or not profiles[savedVars.selectedConfigProfile] then
        savedVars.selectedConfigProfile = GetFirstAbilityConfigProfileId(profiles)
    end

    maxProfileId = maxProfileId > 0 and maxProfileId or (GetFirstAbilityConfigProfileId(profiles) or 0)
    savedVars.nextConfigProfileId = math.max(tonumber(savedVars.nextConfigProfileId) or 1, maxProfileId + 1)
    savedVars.configChanges = {}
end

function FancyActionBar.EnsureUserUIPresetsStored(savedVars)
    savedVars = savedVars or SV
    local defaultPresets = FancyActionBar.defaultSettings.userUIPresets

    if type(savedVars.userUIPresets) ~= "table" or savedVars.userUIPresets == defaultPresets then
        if type(savedVars.userUIPresets) == "table" and next(savedVars.userUIPresets) ~= nil then
            savedVars.userUIPresets = ZO_DeepTableCopy(savedVars.userUIPresets)
        else
            savedVars.userUIPresets = {}
        end
    end

    if type(savedVars.nextUIPresetId) ~= "number" or savedVars.nextUIPresetId < 1 then
        savedVars.nextUIPresetId = 1
    end

    return savedVars.userUIPresets
end

function FancyActionBar.GetAbilityConfigProfiles()
    local savedVars = GetAbilityConfigSavedVars()

    EnsureAbilityConfigProfiles(savedVars)

    return savedVars.configProfiles
end

function FancyActionBar.GetSelectedAbilityConfigProfileId()
    local savedVars = GetAbilityConfigSavedVars()

    EnsureAbilityConfigProfiles(savedVars)

    return savedVars.selectedConfigProfile
end

function FancyActionBar.GetSelectedAbilityConfigProfile()
    local savedVars = GetAbilityConfigSavedVars()

    EnsureAbilityConfigProfiles(savedVars)

    return savedVars.configProfiles[savedVars.selectedConfigProfile], savedVars.selectedConfigProfile
end

function FancyActionBar.SetSelectedAbilityConfigProfile(profileId)
    local savedVars = GetAbilityConfigSavedVars()

    EnsureAbilityConfigProfiles(savedVars)

    if savedVars.configProfiles[profileId] == nil then
        return false
    end

    savedVars.selectedConfigProfile = profileId

    return true
end

function FancyActionBar.CreateAbilityConfigProfile(profileName)
    local savedVars = GetAbilityConfigSavedVars()
    local candidateName
    local profileId

    EnsureAbilityConfigProfiles(savedVars)
    candidateName = GetUniqueAbilityConfigProfileName(savedVars, profileName)

    profileId = tonumber(savedVars.nextConfigProfileId) or 1
    while savedVars.configProfiles[profileId] do
        profileId = profileId + 1
    end

    savedVars.configProfiles[profileId] =
    {
        name = candidateName,
        changes = {},
    }
    savedVars.selectedConfigProfile = profileId
    savedVars.nextConfigProfileId = profileId + 1

    return profileId, candidateName
end

function FancyActionBar.SetAbilityConfigProfileName(profileId, profileName)
    local savedVars = GetAbilityConfigSavedVars()
    local profile
    local candidateName

    EnsureAbilityConfigProfiles(savedVars)

    profile = savedVars.configProfiles[profileId]
    if profile == nil then
        return false
    end

    candidateName = GetUniqueAbilityConfigProfileName(savedVars, profileName, profileId)
    profile.name = candidateName

    return true, candidateName
end

function FancyActionBar.DuplicateAbilityConfigProfile(profileId)
    local savedVars = GetAbilityConfigSavedVars()
    local sourceProfile
    local newProfileId
    local newProfileName

    EnsureAbilityConfigProfiles(savedVars)

    sourceProfile = savedVars.configProfiles[profileId]
    if sourceProfile == nil then
        return false
    end

    newProfileId, newProfileName = FancyActionBar.CreateAbilityConfigProfile(sourceProfile.name .. " (Copy)")
    savedVars.configProfiles[newProfileId].changes = ZO_DeepTableCopy(sourceProfile.changes)

    return newProfileId, newProfileName
end

function FancyActionBar.DeleteAbilityConfigProfile(profileId)
    local savedVars = GetAbilityConfigSavedVars()

    EnsureAbilityConfigProfiles(savedVars)

    if savedVars.configProfiles[profileId] == nil then
        return false
    end

    savedVars.configProfiles[profileId] = nil

    if next(savedVars.configProfiles) == nil then
        savedVars.configProfiles[1] =
        {
            name = FancyActionBar.defaultAbilityConfigProfileName,
            changes = {},
        }
        savedVars.selectedConfigProfile = 1
        savedVars.nextConfigProfileId = math.max(tonumber(savedVars.nextConfigProfileId) or 1, 2)
        return true, savedVars.selectedConfigProfile
    end

    if savedVars.selectedConfigProfile == profileId or savedVars.configProfiles[savedVars.selectedConfigProfile] == nil then
        savedVars.selectedConfigProfile = GetFirstAbilityConfigProfileId(savedVars.configProfiles)
    end

    return true, savedVars.selectedConfigProfile
end

---
--- @return table
function FancyActionBar.GetAbilityConfigChanges()
    local profile = FancyActionBar.GetSelectedAbilityConfigProfile()

    if profile == nil then
        return {}
    end

    if type(profile.changes) ~= "table" then
        profile.changes = {}
    end

    return profile.changes
end

function FancyActionBar.GetHideOnNoTargetGlobalSetting()
    if CV.useAccountWide
    then
        return SV.hideOnNoTargetGlobal
    else
        return CV.hideOnNoTargetGlobal
    end
end

function FancyActionBar.GetHideOnNoTargetList()
    if CV.useAccountWide
    then
        return SV.hideOnNoTargetList
    else
        return CV.hideOnNoTargetList
    end
end

function FancyActionBar.GetNoTargetFade()
    if CV.useAccountWide
    then
        return SV.noTargetFade
    else
        return CV.noTargetFade
    end
end

function FancyActionBar.SetNoTargetFade(fade)
    if CV.useAccountWide
    then
        SV.noTargetFade = fade
    else
        CV.noTargetFade = fade
    end
    if FancyActionBar.constants then
        FancyActionBar.constants.noTargetFade = fade
    end
end

function FancyActionBar.GetNoTargetAlpha()
    if CV.useAccountWide
    then
        return SV.noTargetAlpha / 100
    else
        return CV.noTargetAlpha / 100
    end
end

function FancyActionBar.SetNoTargetAlpha(alpha)
    if CV.useAccountWide
    then
        SV.noTargetAlpha = alpha
    else
        CV.noTargetAlpha = alpha
    end
    if FancyActionBar.constants then
        FancyActionBar.constants.noTargetAlpha = alpha / 100
    end
end

function FancyActionBar.UpdateHideOnNoTargetForSkill(id, hide)
    local cfg = abilityConfig[id]
    local effectId = 0

    if cfg then
        if type(cfg) == "table" then
            cfg[5] = hide
            effectId = cfg[1]
        end

        if effectId > 0 then
            local effect = FancyActionBar.effects[effectId]
            if effect then
                effect.hideOnNoTarget = hide
            end
        end
    end
end

function FancyActionBar.SlotCurrentAbilityConfiguration(id)
    local currentSlots = {}

    for i = MIN_INDEX, ULT_INDEX do
        local I0 = FancyActionBar.GetSlotBoundAbilityId(i, HOTBAR_CATEGORY_PRIMARY)
        local I1 = FancyActionBar.GetSlotBoundAbilityId(i, HOTBAR_CATEGORY_BACKUP)
        if I0 == id then
            currentSlots[i] = true
        end
        if I1 == id then
            currentSlots[i + SLOT_INDEX_OFFSET] = true
        end
    end

    for slot in pairs(currentSlots) do
        FancyActionBar.UnslotEffect(slot)
        FancyActionBar.SlotEffect(slot, id, nil, nil, true)
    end
end

-- Index conventions:
--   data index  — hotbar-keyed slot id (3-7/8 primary, 23-27/28 backup); used by slots[], effects
--   physical index — fixed UI row (3-7/8 front bar, 23-27/28 back bar); used by overlays[], paint

local function GetOverlayIndex(slot, hotbarCategory)
    return hotbarCategory == HOTBAR_CATEGORY_BACKUP and slot + SLOT_INDEX_OFFSET or slot
end

local function GetSlotFromOverlayIndex(overlayIndex)
    return overlayIndex >= MIN_INDEX + SLOT_INDEX_OFFSET and overlayIndex - SLOT_INDEX_OFFSET or overlayIndex
end

local function GetHotbarCategoryForOverlayIndex(overlayIndex)
    return overlayIndex >= MIN_INDEX + SLOT_INDEX_OFFSET and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
end

local function GetBackbarButton(slot)
    return FancyActionBar.buttons[slot + SLOT_INDEX_OFFSET]
end

local function IsPhysicalBackRow(physicalIndex)
    return physicalIndex >= MIN_INDEX + SLOT_INDEX_OFFSET
end

local function GetPhysicalOverlayIndexForData(dataIndex, activeHotbar)
    activeHotbar = activeHotbar or GetActiveHotbarCategory()
    if activeHotbar ~= HOTBAR_CATEGORY_PRIMARY and activeHotbar ~= HOTBAR_CATEGORY_BACKUP then
        activeHotbar = HOTBAR_CATEGORY_PRIMARY
    end
    local slot = GetSlotFromOverlayIndex(dataIndex)
    local dataHotbar = GetHotbarCategoryForOverlayIndex(dataIndex)
    if dataHotbar == activeHotbar then
        return slot
    end
    return slot + SLOT_INDEX_OFFSET
end

local function GetOverlayForData(dataIndex, activeHotbar)
    if dataIndex == ULT_INDEX + COMPANION_INDEX_OFFSET then
        return FancyActionBar.ultOverlays[dataIndex]
    end
    return FancyActionBar.GetOverlay(GetPhysicalOverlayIndexForData(dataIndex, activeHotbar))
end

local function IsInactiveSlotVisibilityHidden(slotNum, activeHotbar)
    activeHotbar = activeHotbar or GetActiveHotbarCategory()
    local dataIndex = GetOverlayIndex(slotNum, GetInactiveHotbarCategory(activeHotbar))
    return (SV.hideInactiveSlots and FancyActionBar.slotHidden[dataIndex])
        or (SV.hideLockedBar and isWeaponSwapLocked)
end

local function ApplyActiveBarIconVisualState(button)
    if not button or not button.icon then
        return
    end

    local usable = button.usable
    local icon = button.icon

    if SV.applyActiveBarTint then
        local tintKey = usable and "tintUsable" or "tintUnusable"
        local tint = SV[tintKey] or defaultSettings[tintKey]
        local colorAlpha = SV.applyActiveBarAlpha and 1 or (tint[4] or 1)
        icon:SetColor(tint[1], tint[2], tint[3], colorAlpha)
    end

    if SV.applyActiveBarAlpha then
        local alphaKey = usable and "alphaUsable" or "alphaUnusable"
        local alpha = SV[alphaKey]
        if alpha == nil then
            alpha = defaultSettings[alphaKey]
        end
        icon:SetAlpha(alpha / 100)
    end

    if SV.applyActiveBarDesaturation then
        local desatKey = usable and "desatUsable" or "desatUnusable"
        local desat = SV[desatKey]
        if desat == nil then
            desat = defaultSettings[desatKey]
        end
        icon:SetDesaturation(desat / 100)
    end
end

local function GetBarSlotIcon(slot, hotbar)
    local id = FancyActionBar.GetSlotBoundAbilityId(slot, hotbar)
    if id <= 0 then
        return nil
    end
    if FancyActionBar.barHighlightDestroFix[id] then
        local weaponType = hotbar == HOTBAR_CATEGORY_BACKUP and FancyActionBar.weaponBack or FancyActionBar.weaponFront
        id = FancyActionBar.GetCorrectedAbilityId(id, weaponType)
    else
        id = GetEffectiveAbilityIdForAbilityOnHotbar(id, hotbar)
    end
    if SV.applyActionBarSkillStyles then
        return FancyActionBar.GetSkillStyleIconForAbilityId(id) or GetAbilityIcon(id)
    end
    return GetAbilityIcon(id)
end

--- Apply FAB icon policy and active-bar theme to one live action-bar button.
local function applyActiveBarSlotAppearance(btn, slot, hotbar)
    if not btn or not btn.icon or not IsSlotUsed(slot, hotbar) then
        return
    end

    local needsTheme = SV.applyActiveBarAlpha or SV.applyActiveBarDesaturation or SV.applyActiveBarTint
    local needsIcon = SV.applyActionBarSkillStyles
        or (hotbar ~= HOTBAR_CATEGORY_PRIMARY and hotbar ~= HOTBAR_CATEGORY_BACKUP)

    if not needsTheme and not needsIcon then
        return
    end

    if needsIcon then
        local icon = GetBarSlotIcon(slot, hotbar)
        if icon then
            btn.icon:SetTexture(icon)
        end
    end

    if needsTheme then
        ApplyActiveBarIconVisualState(btn)
    end
end

local function applyInactiveSlotVisibility(slot, activeHotbar)
    activeHotbar = activeHotbar or GetActiveHotbarCategory()
    local inactiveHotbar = GetInactiveHotbarCategory(activeHotbar)
    local hidden = IsInactiveSlotVisibilityHidden(slot, activeHotbar)
    local overlay = slot == ULT_INDEX
        and FancyActionBar.ultOverlays[slot + SLOT_INDEX_OFFSET]
        or FancyActionBar.overlays[slot + SLOT_INDEX_OFFSET]
    if overlay then
        overlay:SetHidden(hidden)
    end
    local btn = GetBackbarButton(slot)
    if not btn then
        return
    end
    if btn.slot then
        btn.slot:SetHidden(hidden)
    end
    if btn.bg then
        btn.bg:SetHidden(hidden)
    end
    if btn.icon then
        if hidden then
            btn.icon:SetTexture("")
            btn.icon:SetAlpha(0)
            btn.icon:SetHidden(true)
        elseif FancyActionBar.GetSlotBoundAbilityId(slot, inactiveHotbar) <= 0 then
            btn.icon:SetTexture("")
            btn.icon:SetHidden(true)
        end
    end
end

local function PaintAbilityOverlay(physicalIndex, layoutHotbar, abilityHotbar)
    layoutHotbar = layoutHotbar or GetActiveHotbarCategory()
    if layoutHotbar ~= HOTBAR_CATEGORY_PRIMARY and layoutHotbar ~= HOTBAR_CATEGORY_BACKUP then
        layoutHotbar = HOTBAR_CATEGORY_PRIMARY
    end
    local slot = GetSlotFromOverlayIndex(physicalIndex)
    local isActive = not IsPhysicalBackRow(physicalIndex)
    local hotbar = isActive and (abilityHotbar or layoutHotbar) or GetInactiveHotbarCategory(layoutHotbar)
    local overlay = FancyActionBar.GetOverlay(physicalIndex)
    local btn = FancyActionBar.GetActionButton(physicalIndex)

    if overlay then
        local frame = overlay:GetNamedChild("Frame")
        if frame then
            local frameAlpha = isActive
                and (SV.overlayFrameAlphaActive or defaultSettings.overlayFrameAlphaActive)
                or (SV.overlayFrameAlphaInactive or defaultSettings.overlayFrameAlphaInactive)
            frame:SetAlpha(frameAlpha / 100)
        end
    end

    local bgAlpha = (isActive
        and (SV.overlayBgAlphaActive or defaultSettings.overlayBgAlphaActive)
        or (SV.overlayBgAlphaInactive or defaultSettings.overlayBgAlphaInactive)) / 100
    if btn and btn.bg then
        btn.bg:SetAlpha(bgAlpha)
    end
    local backdrop = btn and btn.slot and btn.slot:GetNamedChild("Backdrop")
    if backdrop then
        backdrop:SetAlpha(bgAlpha)
    end
    if overlay and overlay.bg then
        overlay.bg:SetAlpha(bgAlpha)
    end

    if isActive then
        applyActiveBarSlotAppearance(btn, slot, hotbar)
    elseif btn and btn.icon and not IsInactiveSlotVisibilityHidden(slot, layoutHotbar) then
        local icon = GetBarSlotIcon(slot, hotbar)
        if icon then
            btn.icon:SetTexture(icon)
            local tint = SV.tintInactive or defaultSettings.tintInactive
            btn.icon:SetColor(tint[1], tint[2], tint[3], 1)
            btn.icon:SetAlpha((SV.alphaInactive or defaultSettings.alphaInactive) / 100)
            btn.icon:SetDesaturation((SV.desaturationInactive or defaultSettings.desaturationInactive) / 100)
            btn.icon:SetHidden(false)
        else
            btn.icon:SetTexture("")
            btn.icon:SetHidden(true)
        end
    end
end

local function PaintDataOverlay(dataIndex, activeHotbar)
    activeHotbar = activeHotbar or GetActiveHotbarCategory()
    local layoutHotbar = activeHotbar
    if layoutHotbar ~= HOTBAR_CATEGORY_PRIMARY and layoutHotbar ~= HOTBAR_CATEGORY_BACKUP then
        layoutHotbar = HOTBAR_CATEGORY_PRIMARY
    end
    local physicalIndex = GetPhysicalOverlayIndexForData(dataIndex, layoutHotbar)
    PaintAbilityOverlay(physicalIndex, layoutHotbar, (not IsPhysicalBackRow(physicalIndex)) and activeHotbar or nil)
end

-- hideInactiveSlots: track whether inactive row slot has nothing to show (timers/stacks).
local function syncInactiveSlotEmptyVisibility(dataIndex, hasDisplay, activeHotbar)
    if not SV.hideInactiveSlots then
        return
    end
    activeHotbar = activeHotbar or GetActiveHotbarCategory()
    if GetHotbarCategoryForOverlayIndex(dataIndex) ~= GetInactiveHotbarCategory(activeHotbar) then
        return
    end
    local hideEmpty = not hasDisplay
    if FancyActionBar.slotHidden[dataIndex] == hideEmpty then
        return
    end
    FancyActionBar.slotHidden[dataIndex] = hideEmpty
    local slot = GetSlotFromOverlayIndex(dataIndex)
    applyInactiveSlotVisibility(slot, activeHotbar)
    if not hideEmpty then
        PaintDataOverlay(dataIndex, activeHotbar)
    end
end

function FancyActionBar.RefreshActiveBarIconVisuals()
    local hotbar = GetActiveHotbarCategory()
    for slot = MIN_INDEX, ULT_INDEX do
        local btn = ZO_ActionBar_GetButton(slot)
        if btn then
            btn.usable = nil
            btn.useDesaturation = nil
            if btn.UpdateUsable then
                btn:UpdateUsable()
            elseif btn.UpdateState then
                btn:UpdateState()
            end
            applyActiveBarSlotAppearance(btn, slot, hotbar)
        end
    end
end

function FancyActionBar.PaintAbilityOverlays(hotbarCategory, activeHotbar)
    activeHotbar = activeHotbar or GetActiveHotbarCategory()
    local layoutHotbar = activeHotbar
    if layoutHotbar ~= HOTBAR_CATEGORY_PRIMARY and layoutHotbar ~= HOTBAR_CATEGORY_BACKUP then
        layoutHotbar = HOTBAR_CATEGORY_PRIMARY
    end
    local function paintPhysicalRow(isBackRow)
        local abilityHotbar = (not isBackRow) and activeHotbar or nil
        for slot = MIN_INDEX, MAX_INDEX do
            local physicalIndex = isBackRow and (slot + SLOT_INDEX_OFFSET) or slot
            PaintAbilityOverlay(physicalIndex, layoutHotbar, abilityHotbar)
        end
        PaintAbilityOverlay(isBackRow and (ULT_INDEX + SLOT_INDEX_OFFSET) or ULT_INDEX, layoutHotbar, abilityHotbar)
    end
    if not hotbarCategory or hotbarCategory == layoutHotbar then
        paintPhysicalRow(false)
    end
    if not hotbarCategory or hotbarCategory ~= layoutHotbar then
        paintPhysicalRow(true)
    end
end

-- Physical overlay indices: front row 3-7/8, back row 23-27/28. Data indices stay hotbar-keyed.
local function AnchorOverlayToSlot(overlay, slotControl)
    if overlay and slotControl then
        overlay:ClearAnchors()
        overlay:SetAnchor(TOPLEFT, slotControl, TOPLEFT, 0, 0)
        overlay:SetAnchor(BOTTOMRIGHT, slotControl, BOTTOMRIGHT, 0, 0)
    end
end

function FancyActionBar.GetActionButton(index) -- get actionbutton by overlay/backbar index.
    if index == ULT_INDEX or index == ULT_INDEX + SLOT_INDEX_OFFSET then
        if index > SLOT_INDEX_OFFSET then
            return FancyActionBar.buttons[index]
        end
        return ZO_ActionBar_GetButton(ULT_INDEX)
    end
    if index > SLOT_INDEX_OFFSET then
        return FancyActionBar.buttons[index]
    end
    return ZO_ActionBar_GetButton(index)
end

local function GetFrontBarRootSlot()
    local btn = ZO_ActionBar_GetButton(MIN_INDEX)
    return btn and btn.slot or btn
end

local function GetBackbarRootSlot()
    local btn = GetBackbarButton(MIN_INDEX)
    return btn and btn.slot or btn
end

local function GetActiveBarButtonContext(self)
    if not self or not self.GetSlot then
        return
    end
    local slot = self:GetSlot()
    if slot < MIN_INDEX or slot > ULT_INDEX or ZO_ActionBar_GetButton(slot) ~= self then
        return
    end
    return slot, GetActiveHotbarCategory()
end

local function OnActiveActionButtonVisualUpdate(self)
    local slot, hotbar = GetActiveBarButtonContext(self)
    if not slot then
        return
    end
    if SV.applyActionBarSkillStyles
        or (hotbar ~= HOTBAR_CATEGORY_PRIMARY and hotbar ~= HOTBAR_CATEGORY_BACKUP) then
        local icon = GetBarSlotIcon(slot, hotbar)
        if icon and self.icon then
            self.icon:SetTexture(icon)
        end
    end
    if SV.applyActiveBarAlpha or SV.applyActiveBarDesaturation or SV.applyActiveBarTint then
        ApplyActiveBarIconVisualState(self)
    end
end

function FancyActionBar.GetOverlay(index)
    if index == ULT_INDEX or index == ULT_INDEX + SLOT_INDEX_OFFSET then
        return FancyActionBar.ultOverlays[index]
    end
    return FancyActionBar.overlays[index]
end

function FancyActionBar.ChanneledAbilityQueued(effectId, castDuration)
    channeledAbility.id = effectId
    channeledAbility.pending = true
    channeledAbility.active = false
    channeledAbility.castDuration = castDuration
    channeledAbility.castEndTime = nil
end

function FancyActionBar.ChanneledAbilityBegin(effectId, castEndTime)
    if channeledAbility.active and channeledAbility.id == effectId and channeledAbility.castEndTime == castEndTime then
        return
    end
    channeledAbility.id = effectId
    channeledAbility.pending = false
    channeledAbility.active = true
    channeledAbility.castEndTime = castEndTime
    local effect = FancyActionBar.effects[effectId]
    if effect and castEndTime and castEndTime > time() then
        effect.castEndTime = castEndTime
        -- Keep effect.endTime staged by slot updates for the post-cast handoff.
    end
end

function FancyActionBar.ChanneledAbilityEnd(effectId)
    if not channeledAbility.id then
        return
    end
    if (not effectId) or (channeledAbility.id == effectId) then
        local id = channeledAbility.id
        local effect = FancyActionBar.effects[id]
        local currentTime = time()
        channeledAbility.id = nil
        channeledAbility.pending = false
        channeledAbility.active = false
        channeledAbility.castEndTime = nil
        channeledAbility.castDuration = nil
        if effect and effect.castEndTime and effect.castEndTime > currentTime then
            effect.castEndTime = 0
            if not effect.endTime or effect.endTime < currentTime then
                effect.endTime = currentTime
            end
        end
    end
end

-- castEndTime == 0 marks an early channel cancel; endTime anchors the post-cancel fade window.
local function IsChannelCancelFade(effect, currentTime)
    return effect.castEndTime == 0 and effect.endTime and effect.endTime + SV.fadeDelay > currentTime
end

local function IsChanneledRecast(effectId)
    return channeledAbility.id == effectId and (channeledAbility.pending or channeledAbility.active)
end

local function GetChannelEndTime(effect)
    if effect and effect.castEndTime and effect.castEndTime > 0 then
        return effect.castEndTime
    end
    return nil
end

function FancyActionBar.IsChanneledAbilityActive(effect, currentTime)
    currentTime = currentTime or time()
    if not effect then
        return false
    end
    local channelEnd = GetChannelEndTime(effect)
    if channelEnd and channelEnd > currentTime then
        return true
    end
    if channeledAbility.id == effect.id and channeledAbility.pending then
        return true
    end
    return false
end

local function UpdateChanneledAbilityCastState(effect, currentTime)
    local isBlockActive = IsBlockActive()
    -- Cancel only when block is newly pressed during an active channel. Holding block does
    -- nothing; releasing block (e.g. because a channel started) must not cancel.
    local blockCancelled = channeledAbility.active and isBlockActive and not channeledAbility.wasBlockActive
    channeledAbility.wasBlockActive = isBlockActive

    if blockCancelled then
        FancyActionBar.ChanneledAbilityEnd(effect and effect.id or nil)
        return false
    end
    if effect and channeledAbility.id == effect.id and channeledAbility.active
        and effect.castEndTime and effect.castEndTime <= currentTime then
        FancyActionBar.ChanneledAbilityEnd(effect.id)
        return false
    end
    return true
end

local function IsAbilityConfigured(abilityId)
    local cfg = abilityConfig[abilityId]
    return cfg == false or (cfg ~= nil and cfg ~= false) or FancyActionBar.specialEffects[abilityId] ~= nil
end

local function ResolveStackSources(abilityId, effectId, effectEntry, abilityEntry)
    effectEntry = effectEntry or FancyActionBar.GetStackMap(effectId)
    if (effectEntry.sourceId and effectEntry.sourceId ~= effectId) or #effectEntry.sources > 1 then
        return effectEntry.sources
    end
    abilityEntry = abilityEntry or FancyActionBar.GetStackMap(abilityId)
    if abilityEntry.sourceId and abilityEntry.sourceId ~= abilityId then
        return abilityEntry.sources
    end
    return effectEntry.sources
end

local function ApplyEffectBind(effect, abilityId, effectId, overrideRank, casterUnitTag)
    local cfg = abilityConfig[abilityId]
    local ignore = cfg == false
    local configured = IsAbilityConfigured(abilityId)
    local toggled, tickRate, passive, instantFade, dontFade

    if ignore then
        toggled = false
        tickRate = 0
        passive = false
        instantFade = FancyActionBar.removeInstantly[effectId] or false
    else
        if FancyActionBar.bannerBearer[effectId] or FancyActionBar.bannerBearer[abilityId] then
            toggled = true
        elseif configured then
            toggled = cfg and cfg[3] or FancyActionBar.toggled[effectId] or FancyActionBar.toggled[abilityId] or false
        else
            toggled = FancyActionBar.toggled[effectId] or false
        end
        if configured then
            tickRate = ((FancyActionBar.toggleTickRate[effectId] or FancyActionBar.toggleTickRate[abilityId] or GetAbilityFrequencyMS(effectId, "player") or 0) / 1000)
            instantFade = cfg and cfg[4] or FancyActionBar.removeInstantly[effectId] or false
        else
            tickRate = ((FancyActionBar.toggleTickRate[effectId] or GetAbilityFrequencyMS(effectId, "player") or 0) / 1000)
            instantFade = FancyActionBar.removeInstantly[effectId] or false
        end
        passive = FancyActionBar.passive[effectId] or FancyActionBar.passive[abilityId] or false
        dontFade = (not instantFade and FancyActionBar.dontFade[effectId]) or false
    end

    if configured and FancyActionBar.guard.ids[abilityId] then
        ultCosts.guardId = abilityId
    end

    effect.ignore = ignore
    effect.toggled = toggled
    effect.tickRate = tickRate
    effect.passive = passive
    effect.instantFade = instantFade
    effect.dontFade = dontFade
    effect.isChanneled = GetAbilityCastInfo(abilityId, overrideRank, casterUnitTag)
    local effectStackEntry = FancyActionBar.GetStackMap(effectId)
    local abilityStackEntry = FancyActionBar.GetStackMap(abilityId)
    effect.stackSources = ResolveStackSources(abilityId, effectId, effectStackEntry, abilityStackEntry)
    effect.stackOwnerId = effectStackEntry.ownerId

    local duration = -1
    if toggled == false and not ignore then
        duration = (FancyActionBar.GetAbilityDuration(effectId) or -1) / 1000
        duration = duration > 0 and duration or -1
    end
    effect.duration = duration
end

function FancyActionBar.GetEffect(id, opts)
    --- @alias effect table
    opts = opts or {}
    local effect = FancyActionBar.effects[id]
    local isNew = not effect

    if isNew then
        effect =
        {
            id = id,
            endTime = -1,
            faded = true,
            isDebuff = false,
            activeOnTarget = false,
            sources = FancyActionBar.EnsureUnits(nil, "sources"),
            targets = FancyActionBar.EnsureUnits(nil, "targets"),
        }
    end

    if opts.abilityId then
        ApplyEffectBind(effect, opts.abilityId, id, opts.overrideRank, opts.casterUnitTag)
    elseif opts.stackSources then
        if effect.stackSources ~= opts.stackSources then
            effect.stackSources = opts.stackSources
        end
    else
        local stackEntry = FancyActionBar.GetStackMap(id)
        if effect.stackSources ~= stackEntry.sources then
            effect.stackSources = stackEntry.sources
        end
        if effect.stackSources then
            effect.stackOwnerId = stackEntry.ownerId
        end
    end

    if opts.reset or isNew then
        effect.endTime = -1
        effect.faded = true
        effect.isDebuff = false
        effect.activeOnTarget = false
    end

    FancyActionBar.effects[id] = effect
    if effect.dontFade == nil then
        effect.dontFade = (not (effect.instantFade or FancyActionBar.removeInstantly[id]) and FancyActionBar.dontFade[id]) or false
    end
    return effect
end

function FancyActionBar.GetConfiguredEffectId(abilityId)
    if not abilityId or abilityId == 0 then
        return 0
    end

    local cfg = abilityConfig[abilityId]
    if cfg == false then
        return abilityId
    end

    if abilityId == 81420 and ultCosts.guardId > 0 then
        return ultCosts.guardId
    end

    local special = FancyActionBar.specialEffects[abilityId]
    if cfg or special then
        local craftedId = GetAbilityCraftedAbilityId(abilityId)
        if craftedId ~= 0 then
            local scripts = { GetCraftedAbilityActiveScriptIds(craftedId) }
            local scriptKey = (scripts[1] or 0) .. "_" .. (scripts[2] or 0) .. "_" .. (scripts[3] or 0)
            return (cfg and ((cfg[2] and cfg[2][scriptKey] and cfg[2][scriptKey][1]) or cfg[1]))
                or (special and special.id)
                or abilityId
        end
        return (cfg and cfg[1]) or (special and special.id) or abilityId
    end

    return abilityId
end

function FancyActionBar.GetTrackedEffectId(abilityId)
    if not abilityId or abilityId == 0 then
        return 0
    end
    return sourceAbilities[abilityId] or FancyActionBar.GetConfiguredEffectId(abilityId)
end

function FancyActionBar.GetSlottedEffect(index)
    local slot = slots[index]
    if not slot then
        return 0, 0
    end
    return slot.effectId, slot.abilityId
end

function FancyActionBar.SetSlottedEffect(index, abilityId, effectId)
    local prev = slots[index]

    if not abilityId or abilityId == 0 then
        if prev and prev.abilityId then
            sourceAbilities[prev.abilityId] = nil
        end
        slots[index] = nil
        return
    end

    if prev and prev.abilityId ~= abilityId then
        sourceAbilities[prev.abilityId] = nil
        FancyActionBar.slotStateSpecialEffects[index] = nil
    end

    local showStacks = FancyActionBar.IsStackMapMember(abilityId)
    if effectId ~= 0 then
        local abilitySourceId = FancyActionBar.GetStackSourceId(abilityId)
        local effectSourceId = FancyActionBar.GetStackSourceId(effectId)
        showStacks = showStacks
            or abilitySourceId ~= abilityId
            or effectSourceId ~= effectId
            or effectId == abilityId
            or FancyActionBar.IsAbilityTaunt(effectId)
            or FancyActionBar.IsAbilityTaunt(abilityId)
            or (FancyActionBar.debuffStackSourceIds and FancyActionBar.debuffStackSourceIds[effectId])
    end

    slots[index] =
    {
        abilityId = abilityId,
        effectId = effectId,
        parentEndTime = nil,
        showStacks = showStacks,
    }
    sourceAbilities[abilityId] = effectId

    for k in pairs(slottedEffectIds) do
        slottedEffectIds[k] = nil
    end
    for _, slot in pairs(slots) do
        if slot.effectId and slot.effectId ~= 0 then
            slottedEffectIds[slot.effectId] = true
        end
        if slot.abilityId and slot.abilityId ~= 0 then
            local members = FancyActionBar.GetStackMap(slot.abilityId).sources
            for i = 1, #members do
                slottedEffectIds[members[i]] = true
            end
        end
    end
end

function FancyActionBar.IsEffectSlotted(effectId)
    if not effectId or effectId == 0 then
        return false
    end
    for _, slot in pairs(slots) do
        if slot.effectId == effectId then
            return true
        end
    end
    return false
end

local function GetWidgetEffectId(abilityId)
    if abilityConfig[abilityId] == false then
        return nil
    end
    return FancyActionBar.GetTrackedEffectId(abilityId)
end

function FancyActionBar.IsEffectWidgetTracked(effectId)
    if not effectId or effectId == 0 then
        return false
    end
    local widgets = GetAbilityConfigSavedVars().effectWidgets
    if not widgets then
        return false
    end
    for abilityId, widget in pairs(widgets) do
        if widget and widget.enabled ~= false then
            if abilityId == effectId or GetWidgetEffectId(abilityId) == effectId then
                return true
            end
        end
    end
    return false
end

local function ShouldTrackEffectChange(abilityId)
    local trackedId = FancyActionBar.GetTrackedEffectId(abilityId)
    if trackedId ~= 0 and FancyActionBar.effects[trackedId] then
        return true
    end

    if FancyActionBar.IsStackMapMember(abilityId) then
        return true
    end

    local widgets = GetAbilityConfigSavedVars().effectWidgets
    if abilityConfig[abilityId]
        or FancyActionBar.toggled[abilityId]
        or FancyActionBar.passive[abilityId]
        or FancyActionBar.specialEffects[abilityId]
        or FancyActionBar.stackableBuff[abilityId]
        or FancyActionBar.bannerBearer[abilityId]
        or FancyActionBar.fixedStacks[abilityId]
        or (SV.debuffTable and SV.debuffTable[abilityId])
        or (widgets and widgets[abilityId])
        or trackedId ~= abilityId
    then
        return true
    end

    return FancyActionBar.IsAbilitySlotted(abilityId)
        or FancyActionBar.IsEffectSlotted(abilityId)
        or FancyActionBar.IsEffectWidgetTracked(abilityId)
end

function FancyActionBar.IsAbilitySlotted(abilityId, excludeIndex)
    if not abilityId or abilityId == 0 then
        return false
    end
    for index, slot in pairs(slots) do
        if index ~= excludeIndex and slot.abilityId == abilityId then
            return true
        end
    end
    return false
end

function FancyActionBar.HandleCompanionUltimate()
    -- Get companion ultimate button and early validation
    local companionButton = ZO_ActionBar_GetButton(ULT_INDEX, HOTBAR_CATEGORY_COMPANION)
    if not companionButton then
        companionOverlayActive = false
        return
    end

    local function updateVisuals(shouldShow, currentPower)
        if not CompanionUltimateButton then return end

        -- Update visibility state
        CompanionUltimateButton:SetHidden(not shouldShow)

        -- Update button text if it exists
        if companionButton.buttonText then
            local shouldHideText = not shouldShow or FancyActionBar.constants.mode == 2 or not SV.showHotkeys
            companionButton.buttonText:SetHidden(shouldHideText)
        end

        -- Update icon if showing
        if shouldShow then
            local ultimateId = GetSlotBoundId(ULT_INDEX, HOTBAR_CATEGORY_COMPANION)
            if ultimateId then
                local iconControl = CompanionUltimateButton:GetNamedChild("Icon")
                if iconControl then
                    local icon = SV.applyActionBarSkillStyles and FancyActionBar.GetSkillStyleIconForAbilityId(ultimateId) or GetAbilityIcon(ultimateId)
                    iconControl:SetTexture(icon)
                end
            end

            -- Update power display
            FancyActionBar.UpdateUltimateValueLabels(false, currentPower)
        end
    end

    -- Check if companion ultimate should be displayed
    local shouldShowUltimate = not SV.hideCompanionUlt
        and HasActiveCompanion()
        and DoesUnitExist("companion")
        and companionButton.hasAction

    -- Get current power and cost if should show
    local currentPower, cost = 0, 0
    if shouldShowUltimate then
        currentPower = GetUnitPower("companion", COMBAT_MECHANIC_FLAGS_ULTIMATE)
        cost = GetSlotAbilityCost(ULT_INDEX, COMBAT_MECHANIC_FLAGS_ULTIMATE, HOTBAR_CATEGORY_COMPANION)
        shouldShowUltimate = cost and cost > 0
    end

    -- Update base button state
    companionButton:SetupBounceAnimation()
    companionButton:SetupKeySlideAnimation()
    companionButton:SetupTimerSwapAnimation()
    companionButton:UpdateUltimateMeter()

    EM:UnregisterForEvent(NAME .. "UltValueCompanion", EVENT_POWER_UPDATE)
    if shouldShowUltimate and FancyActionBar.constants.ult.companion.show then
        EM:RegisterForEvent(NAME .. "UltValueCompanion", EVENT_POWER_UPDATE, FancyActionBar.OnUltChangedCompanion)
        EM:AddFilterForEvent(NAME .. "UltValueCompanion", EVENT_POWER_UPDATE,
            REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE,
            REGISTER_FILTER_UNIT_TAG, "companion")
    end

    updateVisuals(shouldShowUltimate, currentPower)
    companionOverlayActive = shouldShowUltimate
end

-------------------------------------------------------------------------------
-----------------------------[ 		UI Updates    ]------------------------------
-------------------------------------------------------------------------------

function FancyActionBar.CheckForActiveEffect(id)
    if not id then return false, -1, 0, 0, 0, false end
    local now = time()
    local effects = FancyActionBar.effects
    local stackableBuff = FancyActionBar.stackableBuff

    local eff = effects and (effects[id] or (stackableBuff and stackableBuff[id] and effects[stackableBuff[id]]))
    if not eff then
        return false, -1, 0, 0, 0, false
    end

    local hasEffect = false
    local duration = -1
    local start = eff.beginTime or 0
    local finish = eff.endTime or 0
    local currentStacks = 0
    local wasCastByPlayer = eff.hasActiveCast or false
    local sourceId = (stackableBuff and stackableBuff[id]) or eff.id

    if FancyActionBar.IsStackableBuff(sourceId) then
        local stackEff = effects and effects[sourceId]
        if stackEff and stackEff.sources and stackEff.sources.times then
            local activeCount, _, maxEnd = FancyActionBar.RecomputeUnits(sourceId, now, "sources")
            if activeCount and activeCount > 0 then
                currentStacks = activeCount
                hasEffect = true
                duration = maxEnd and (maxEnd - now) or -1
                start = stackEff.beginTime or start
                finish = maxEnd or finish
            end
        end
    elseif eff.sources and eff.sources.times then
        local activeCount, _, maxEnd = FancyActionBar.RecomputeUnits(eff.id, now, "sources")
        if activeCount and activeCount > 0 then
            currentStacks = activeCount
            hasEffect = true
            duration = maxEnd and (maxEnd - now) or -1
            start = eff.beginTime or start
            finish = maxEnd or finish
        end
    end

    if not hasEffect then
        local targetCount, _, maxEnd = FancyActionBar.RecomputeUnits(eff.id, now, "targets")
        if targetCount and targetCount > 0 then
            hasEffect = true
            duration = maxEnd and (maxEnd - now) or -1
            finish = maxEnd or finish
        end
    end

    if not hasEffect and finish and finish > now and not eff.isDebuff then
        if not eff.dontFade or not SV.externalBuffs then
            hasEffect = true
            duration = finish - now
        end
    end

    local resolvedStacks = FancyActionBar.GetDisplayStacks(eff, now)
    if resolvedStacks ~= 0 then
        currentStacks = resolvedStacks
    elseif currentStacks == 0 and hasEffect and FancyActionBar.fixedStacks[id] then
        currentStacks = FancyActionBar.fixedStacks[id]
    end

    return hasEffect, duration, currentStacks or 0, start or 0, finish or 0, wasCastByPlayer
end

-- Recompute and prune per-unit target times for an effect.
function FancyActionBar.EnsureUnits(effect, which)
    effect = effect or {}
    effect[which] = effect[which] or { unitCount = 0, maxEndTime = 0, times = {} }
    return effect[which]
end

-- Prune expired entries from targets table and compute required times.
function FancyActionBar.PruneUnits(unitData, currentTime)
    if not unitData or not unitData.times then return nil, 0, 0 end
    local activeCount = 0
    local maxEnd = 0
    local soonest = nil
    for unitId, times in pairs(unitData.times) do
        local et = times and times.endTime
        if et and et > currentTime then
            activeCount = activeCount + 1
            if et > maxEnd then maxEnd = et end
            if not soonest or et < soonest then soonest = et end
        else
            unitData.times[unitId] = nil
        end
    end
    unitData.unitCount = activeCount
    unitData.maxEndTime = maxEnd
    unitData.soonest = soonest
    unitData.prunedAt = currentTime
    return activeCount, soonest, maxEnd
end

-- Recompute unit counts and soonest expiry for an effect.
function FancyActionBar.RecomputeUnits(id, currentTime, which)
    local effect = FancyActionBar.effects and FancyActionBar.effects[id]
    local unitData = effect and effect[which]
    if not unitData or not unitData.times then return nil, 0, 0 end
    if unitData.prunedAt == currentTime then
        return unitData.unitCount, unitData.soonest, unitData.maxEndTime
    end
    local activeCount, soonest, maxEnd = FancyActionBar.PruneUnits(unitData, currentTime)
    if effect then
        effect[which] = unitData
        FancyActionBar.effects[id] = effect
    end
    return activeCount, soonest, maxEnd
end

function FancyActionBar.RecordUnit(id, effect, unitKey, currentTime, beginTime, endTime, which, meta)
    if not id then return end
    unitKey = unitKey or 0
    effect = effect or FancyActionBar.GetEffect(id)
    local unitData = FancyActionBar.EnsureUnits(effect, which)
    local setEnd = endTime or currentTime
    if setEnd <= currentTime then setEnd = currentTime + 0.01 end
    local resolvedBegin = beginTime or currentTime
    local existing = unitData.times[unitKey]
    if existing and existing.beginTime == resolvedBegin and existing.endTime == setEnd then
        if meta and type(meta) == "table" then
            existing.meta = existing.meta or {}
            for k, v in pairs(meta) do
                existing.meta[k] = v
            end
        end
        FancyActionBar.effects[id] = effect
        return FancyActionBar.PruneUnits(unitData, currentTime)
    end
    local entry = existing or {}
    entry.beginTime = resolvedBegin
    entry.endTime = setEnd
    if meta and type(meta) == "table" then
        entry.meta = meta
    end
    unitData.prunedAt = nil
    unitData.times[unitKey] = entry
    unitData.maxEndTime = zo_max(unitData.maxEndTime or 0, setEnd)

    effect[which] = unitData

    local activeCount, soonest, maxEnd = FancyActionBar.PruneUnits(unitData, currentTime)
    if effect and maxEnd and maxEnd > (effect.endTime or 0) then
        if which == "targets" or SV.externalBuffs then
            effect.endTime = maxEnd
        end
    end

    FancyActionBar.effects[id] = effect
    return activeCount, soonest, maxEnd
end

function FancyActionBar.GetUnits(id, which)
    local eff = FancyActionBar.effects and FancyActionBar.effects[id]
    return eff and eff[which]
end

--- Resolve the canonical unit key used for per-target tracking.
--- Prefer the runtime `unitId` so target-count bookkeeping remains stable
--- across reticle changes and effect-slot reuse; only fall back to
--- `effectSlot` when the event does not provide a usable unit id.
--- @param which string "sources" or "targets"
--- @param unitTag string
--- @param unitId number
--- @param effectSlot number
--- @return number unitKey
function FancyActionBar.ResolveUnitKey(which, unitTag, unitId, effectSlot)
    if which == "sources" and unitTag == "player" then return effectSlot else return unitId end
end

function FancyActionBar.RemoveUnit(id, unitKey, currentTime, which)
    if not id then return 0 end
    unitKey = unitKey or 0
    local effect = FancyActionBar.effects[id]
    local unitData = effect and effect[which]
    if unitData and unitData.times then
        unitData.prunedAt = nil
        unitData.times[unitKey] = nil
        if effect then
            effect[which] = unitData
            FancyActionBar.effects[id] = effect
        end
    end

    local activeCount, soonest, maxEnd = FancyActionBar.PruneUnits(unitData, currentTime)
    if effect then
        if which == "targets" or SV.externalBuffs then
            if activeCount > 0 and maxEnd and maxEnd > (effect.endTime or 0) then
                effect.endTime = maxEnd
            elseif activeCount == 0 and not effect.dontFade then
                effect.endTime = currentTime
            end
        end
        effect[which] = unitData
        FancyActionBar.effects[id] = effect
    end
    return activeCount, soonest, maxEnd
end

--------------
-- abilities
--------------

function FancyActionBar.ResetOverlayDuration(overlay)
    if not overlay then
        return
    end
    overlay.timer:SetText("")
    overlay.bg:SetHidden(true)
    overlay.target:SetText("")
    if overlay.stack then
        overlay.stack:SetText("")
    end
end

function FancyActionBar.GetHighlightColor(fading, isToggle, isToggled, isParentTime, profile)
    if isToggle and isToggled then
        if profile.toggled then
            return profile.toggledColor
        elseif profile.show then
            return profile.color
        end
    elseif fading or isParentTime then
        if profile.expire then
            return profile.expireColor
        elseif profile.show then
            return profile.color
        end
    elseif profile.show then
        return profile.color
    end
    return nil
end

local function UpdateBackgroundVisuals(background, color, index)
    if color then
        background:SetHidden(false)
        background:SetColor(color[1], color[2], color[3], color[4])
    else
        background:SetHidden(true)
    end

    if index <= 0 then
        FancyActionBar.AddSystemMessage("Index 0 Error!")
    end
end

function FancyActionBar.ShouldShowExpire(duration)
    local u = FancyActionBar.constants.update
    return u.showDecimal and duration <= u.showDecimalStart
end

function FancyActionBar.FormatTextForDurationOfActiveEffect(fading, toggle, effect, duration, currentTime)
    local timer, color = "", nil
    if duration <= 0 then
        local hadTimedEffect = effect.beginTime and effect.endTime and effect.endTime >= effect.beginTime
        local isBlockCancelFade = IsChannelCancelFade(effect, currentTime)
        local isWaitingForRefreshedEffect = effect.castTime and effect.endTime and effect.castTime >= effect.endTime
        local canDelayFade = (SV.delayFade and not effect.instantFade) or (effect.isDebuff and (effect.endTime > currentTime) and (SV.keepLastTarget == false))
        if (fading or hadTimedEffect or isBlockCancelFade) and canDelayFade then
            -- adding or (effect.isDebuff and SV.keepLastTarget == false) is to try to prevent a flicker of 0 on reticleover when a debuff isn't active
            local delayEnd = (effect.endTime + SV.fadeDelay) - currentTime
            if delayEnd > 0 and not isWaitingForRefreshedEffect then
                timer = tostring(zo_max(0, zo_ceil(assert(tonumber(duration)))))
            end
        end
    else
        if FancyActionBar.ShouldShowExpire(duration)
        then
            timer = strformat("%0.1f", duration)
        else
            timer = strformat("%0.0f", duration)
        end
    end

    if effect.toggled or toggle then
        local expire = fading or (not toggle)
        if SV.showTickExpire and expire then
            color = SV.tickColor
        else
            color = (expire and SV.showExpire) and SV.expireColor or SV.toggledColor
        end
    elseif (fading and SV.showExpire) then
        color = SV.expireColor
    else
        color = FancyActionBar.constants.duration.color
    end
    return timer, color
end

local function refreshPlayerUltTimer(currentTime)
    if playerUltTimer.lastTime == currentTime then
        return
    end
    playerUltTimer.lastTime = currentTime

    local ultFadeDelay = (SV.delayFade and SV.fadeDelay or 0)
    local pickSoonest = SV.showSoonestExpire
    local bestEnd, bestInstantFade, bestBeginTime, bestIsParentTime

    for idx = ULT_INDEX, ULT_INDEX + SLOT_INDEX_OFFSET, SLOT_INDEX_OFFSET do
        local effectId = FancyActionBar.GetSlottedEffect(idx)
        local effect = effectId ~= 0 and FancyActionBar.effects[effectId]
        local slot = slots[idx]
        local slotEnd, slotInstantFade, slotBeginTime, slotIsParentTime

        if effect and effect.endTime and not effect.toggled and not effect.passive then
            local fadeThreshold = currentTime - ((not effect.instantFade and ultFadeDelay) or 0)
            if effect.endTime > fadeThreshold then
                slotEnd = effect.endTime
                slotInstantFade = effect.instantFade
                slotBeginTime = effect.beginTime
                slotIsParentTime = false
            end
        end

        if not slotEnd and SV.allowParentTime and slot and slot.parentEndTime and slot.parentEndTime > currentTime then
            slotEnd = slot.parentEndTime
            slotInstantFade = effect and effect.instantFade
            slotIsParentTime = true
        end

        if slotEnd then
            if not bestEnd
                or (pickSoonest and slotEnd < bestEnd)
                or (not pickSoonest and slotEnd > bestEnd) then
                bestEnd = slotEnd
                bestInstantFade = slotInstantFade
                bestBeginTime = slotBeginTime
                bestIsParentTime = slotIsParentTime
            end
        end
    end

    playerUltTimer.endTime = bestEnd
    playerUltTimer.instantFade = bestInstantFade
    playerUltTimer.beginTime = bestBeginTime
    playerUltTimer.isParentTime = bestIsParentTime
end

function FancyActionBar.UpdateEffectDuration(index, updateTime, overlay, stacksOnly)
    local isUlt = (index == ULT_INDEX) or (index == ULT_INDEX + SLOT_INDEX_OFFSET) or (index == ULT_INDEX + COMPANION_INDEX_OFFSET)
    local isPlayerUlt = isUlt and index ~= ULT_INDEX + COMPANION_INDEX_OFFSET
    local useUltDisplay = isUlt and not stacksOnly and FancyActionBar.constants.ult.duration.show
    local slot = slots[index]
    local effectId, abilityId = FancyActionBar.GetSlottedEffect(index)
    local effect = effectId ~= 0 and FancyActionBar.effects[effectId]
    if not effect and isUlt then
        effect = ULT_STUB_EFFECT
    end

    if not isUlt then
        if not slot or abilityConfig[slot.abilityId] == false or not slot.effectId or slot.effectId == 0 then
            FancyActionBar.ResetOverlayDuration(overlay)
            return false
        end
        if not effect or effect.ignore or not effect.id or effect.id == 0 then
            FancyActionBar.ResetOverlayDuration(overlay)
            return false
        end
    end

    local currentTime = updateTime or time()
    if effect.slotStateEndTime and effect.slotStateEndTime <= currentTime then
        effect.slotStateEndTime = nil
        effect.slotStateBeginTime = nil
        effect.slotStateAbilityId = nil
        if effect.origDontFade then
            effect.dontFade = effect.origDontFade
            effect.origDontFade = nil
        end
        if effect.origForceExpireStacks then
            effect.forceExpireStacks = effect.origForceExpireStacks
            effect.origForceExpireStacks = nil
        end
        if effect.origStackSources then
            effect.stackSources = effect.origStackSources
            effect.origStackSources = nil
            effect.stackOwnerId = FancyActionBar.GetStackOwnerId(effect.id)
        end
    end

    local fadeDelay = SV.showExpire and SV.fadeDelay or 0
    local hasDuration, duration = true, 0
    local isCastTime, isParentTime, isFading = false, false, false
    local targetsActiveCount = nil
    local parentEndTime = slot and SV.allowParentTime and slot.parentEndTime and slot.parentEndTime > currentTime and slot.parentEndTime or nil
    local ultEndTime, instantFade, timerColor
    local hasActiveCastWindow = FancyActionBar.IsChanneledAbilityActive(effect, currentTime)

    if SV.showCastDuration and hasActiveCastWindow then
        UpdateChanneledAbilityCastState(effect, currentTime)
        if effect.castEndTime and effect.castEndTime >= currentTime then
            duration = effect.castEndTime - currentTime
            isCastTime = true
        end
    end

    if not isCastTime then
        local skipSharedDuration = useUltDisplay and isPlayerUlt

        if not skipSharedDuration then
            if isUlt and not stacksOnly and not FancyActionBar.constants.ult.duration.show then
                if overlay then
                    overlay.timer:SetText("")
                end
                hasDuration = false
            else
                if effect.slotStateEndTime and effect.slotStateEndTime + fadeDelay > currentTime then
                    duration = effect.slotStateEndTime - currentTime
                    isParentTime = true
                elseif effect.endTime and (effect.endTime + fadeDelay > currentTime) then
                    duration = effect.endTime - currentTime
                else
                    hasDuration = false
                end

                local targets = FancyActionBar.GetUnits(effect.id, "targets")
                local activeCount, soonest, maxEnd = nil, -1, -1
                if targets and targets.times and not (SV.advancedDebuff and effect.isDebuff) then
                    activeCount, soonest, maxEnd = FancyActionBar.RecomputeUnits(effect.id, currentTime, "targets")
                    targetsActiveCount = activeCount
                    if maxEnd and maxEnd + fadeDelay > currentTime then
                        duration = SV.showSoonestExpire and (soonest + fadeDelay > currentTime) and (soonest - currentTime) or (maxEnd + fadeDelay > currentTime) and (maxEnd - currentTime)
                        hasDuration = true
                    end
                elseif SV.externalBuffs and effect.sources and effect.sources.times then
                    activeCount, soonest, maxEnd = FancyActionBar.RecomputeUnits(effect.id, currentTime, "sources")
                    if maxEnd and maxEnd + fadeDelay > currentTime then
                        duration = SV.showSoonestExpire and (soonest + fadeDelay > currentTime) and (soonest - currentTime) or (maxEnd + fadeDelay > currentTime) and (maxEnd - currentTime)
                        hasDuration = true
                    end
                end

                if SV.allowParentTime and duration <= 0 and parentEndTime then
                    duration = parentEndTime - currentTime
                    isParentTime = true
                end
            end
        end

        if useUltDisplay then
            timerColor = FancyActionBar.constants.ult.duration.color
            if isPlayerUlt then
                ultEndTime = playerUltTimer.endTime
                instantFade = playerUltTimer.instantFade
                isParentTime = playerUltTimer.isParentTime
                hasDuration = ultEndTime ~= nil
            else
                ultEndTime = (duration > 0 or isParentTime) and (currentTime + duration) or nil
                instantFade = effect.instantFade
            end
            duration = ultEndTime and (ultEndTime - currentTime) or -999
        end
    end

    local toggleKey = (FancyActionBar.bannerBearer[effect.id] or FancyActionBar.bannerBearer[abilityId]) and "banner" or effect.id
    local isToggled = FancyActionBar.toggles[toggleKey]
    if effect.toggled then
        local activeHotbar = GetActiveHotbarCategory()
        if activeHotbar ~= HOTBAR_CATEGORY_PRIMARY and activeHotbar ~= HOTBAR_CATEGORY_BACKUP then
            activeHotbar = HOTBAR_CATEGORY_PRIMARY
        end
        if GetHotbarCategoryForOverlayIndex(index) == activeHotbar then
            isToggled = IsSlotToggled(GetSlotFromOverlayIndex(index), activeHotbar)
            FancyActionBar.toggles[toggleKey] = isToggled
        end
        local tickRate = isToggled and SV.showToggleTicks and effect.tickRate or 0
        if tickRate ~= 0 and effect.beginTime then
            duration = tickRate - ((currentTime - effect.beginTime) % tickRate)
            isFading = duration <= SV.showTickStart and SV.showTickExpire or false
        end
        hasDuration = isToggled or hasDuration
    elseif hasDuration and SV.showExpire and duration <= SV.showExpireStart then
        isFading = true
    end

    local highlightOn = hasDuration or isFading or isParentTime or isToggled or effect.passive
    local highlightToggled = isToggled or effect.passive
    local highlightProfile = isUlt and highlights.ult or highlights.regular

    local labelText, labelColor = "", nil
    local bgColor = nil
    if useUltDisplay then
        timerColor = timerColor or FancyActionBar.constants.ult.duration.color
        local durationControl = overlay.timer
        local displayThreshold = -((SV.delayFade and not instantFade and not isCastTime) and SV.fadeDelay or 0.1)
        if duration > displayThreshold then
            if duration > 0 then
                if (FancyActionBar.constants.update.showDecimal and (duration <= FancyActionBar.constants.update.showDecimalStart)) then
                    durationControl:SetText(strformat("%0.1f", duration))
                else
                    durationControl:SetText(zo_ceil(duration))
                end
                if (duration <= SV.showExpireStart) and SV.showExpire then
                    durationControl:SetColor(unpack(SV.expireColor))
                else
                    durationControl:SetColor(unpack(timerColor))
                end
            else
                local timerBeginTime = (isPlayerUlt and playerUltTimer.endTime and playerUltTimer.beginTime) or effect.beginTime
                local hadTimedEffect = timerBeginTime and ultEndTime and ultEndTime >= timerBeginTime
                local isBlockCancelFade = IsChannelCancelFade(effect, currentTime)
                if (hadTimedEffect or isBlockCancelFade) and not isCastTime and SV.delayFade and not instantFade then
                    local delayEnd = (ultEndTime + SV.fadeDelay) - currentTime
                    if delayEnd > 0 then
                        durationControl:SetText(0)
                        if SV.showExpire then durationControl:SetColor(unpack(SV.expireColor)) else durationControl:SetColor(unpack(timerColor)) end
                    else
                        durationControl:SetText("")
                    end
                else
                    durationControl:SetText("")
                end
            end
            hasDuration = true
        else
            durationControl:SetText("")
        end
    elseif not stacksOnly then
        if hasDuration or isToggled or isFading or isParentTime then
            labelText, labelColor = FancyActionBar.FormatTextForDurationOfActiveEffect(isFading, isToggled, effect, duration, currentTime)
        end
    end

    if not stacksOnly and highlightOn then
        bgColor = FancyActionBar.GetHighlightColor(isFading, effect.toggled or effect.passive or isToggled, highlightToggled, isParentTime, highlightProfile)
    end

    local hasDisplay = useUltDisplay and (duration > -((SV.delayFade and not instantFade and not isCastTime) and SV.fadeDelay or 0.1)) or hasDuration or isToggled or isFading or isParentTime
    local hasStacks = false
    if overlay then
        hasStacks = FancyActionBar.UpdateStacksControl(slot, overlay.stack, currentTime, index)
        FancyActionBar.UpdateTargetsControl(effect, overlay.target, currentTime, targetsActiveCount)
        if not stacksOnly then
            if not isUlt then
                overlay.timer:SetText(labelText)
                if labelColor then
                    overlay.timer:SetColor(unpack(labelColor))
                end
            end
            UpdateBackgroundVisuals(overlay.bg, bgColor, index)
        end
    end

    return hasDisplay or hasStacks
end

function FancyActionBar.UpdateStacksControl(slot, stacksControl, currentTime, index)
    if not slot or not slot.effectId or slot.effectId == 0 then
        stacksControl:SetText("")
        return false
    end

    if not SV.showStackCount or not slot.showStacks then
        stacksControl:SetText("")
        return false
    end

    local effect = FancyActionBar.effects[slot.effectId]
    if (not effect or effect.ignore) and slot.abilityId and FancyActionBar.debuffStackSourceIds and FancyActionBar.debuffStackSourceIds[slot.effectId] then
        local debuffStackEntry = FancyActionBar.GetStackMap(slot.effectId, "debuff")
        effect =
        {
            id = slot.effectId,
            isDebuff = true,
            stackSources = debuffStackEntry.sources,
            stackOwnerId = debuffStackEntry.ownerId,
        }
    elseif slot.abilityId and FancyActionBar.IsStackMapMember(slot.abilityId) then
        local stackEntry = FancyActionBar.GetStackMap(slot.abilityId)
        effect =
        {
            id = stackEntry.ownerId,
            stackSources = stackEntry.sources,
            stackOwnerId = stackEntry.ownerId,
        }
    elseif not effect or effect.ignore then
        stacksControl:SetText("")
        return false
    end

    local activeEndTime = (effect.slotStateEndTime and effect.slotStateEndTime > currentTime and effect.slotStateEndTime) or effect.endTime
    if effect.forceExpireStacks and (activeEndTime <= currentTime) then
        stacksControl:SetText("")
        return false
    end

    if index and index == ULT_INDEX and IsPlayerInWerewolfForm() then
        local fury = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_WEREWOLF)
        stacksControl:SetColor(unpack(FancyActionBar.constants.stacks.color))
        stacksControl:SetText(fury > 0 and fury or "")
        return fury > 0
    end

    local resolvedStacks = FancyActionBar.GetDisplayStacks(effect, currentTime)
    stacksControl:SetColor(unpack(FancyActionBar.constants.stacks.color))
    stacksControl:SetText(resolvedStacks and resolvedStacks ~= 0 and resolvedStacks or "")
    return resolvedStacks ~= nil and resolvedStacks ~= 0 and resolvedStacks ~= ""
end

function FancyActionBar.UpdateOverlay(index, updateTime, activeHotbarCategory, inactiveHotbarCategory) -- timer label updates.
    activeHotbarCategory = activeHotbarCategory or layoutHotbarCategory
    inactiveHotbarCategory = inactiveHotbarCategory or GetInactiveHotbarCategory(activeHotbarCategory)
    local isUlt = (index == ULT_INDEX) or (index == ULT_INDEX + SLOT_INDEX_OFFSET) or (index == ULT_INDEX + COMPANION_INDEX_OFFSET)
    local overlay = GetOverlayForData(index, activeHotbarCategory)
    if not overlay then
        return
    end
    if isUlt then
        if index ~= ULT_INDEX + COMPANION_INDEX_OFFSET and FancyActionBar.constants.ult.duration.show then
            refreshPlayerUltTimer(updateTime or time())
        end
        local hasDisplay = FancyActionBar.UpdateEffectDuration(index, updateTime, overlay)
        if index == ULT_INDEX + COMPANION_INDEX_OFFSET then
            overlay:SetHidden(SV.hideCompanionUlt)
        end
        return
    end
    local hasDisplay = FancyActionBar.UpdateEffectDuration(index, updateTime, overlay)
    if GetHotbarCategoryForOverlayIndex(index) == inactiveHotbarCategory then
        syncInactiveSlotEmptyVisibility(index, hasDisplay, activeHotbarCategory)
    end
end

function FancyActionBar.ShouldShowTargetCount(effect, activeCount)
    if not (SV.showTargetCount and activeCount and activeCount ~= 0) then return nil end

    if activeCount > 1
        or (effect and effect.isDebuff and (SV.showSingleTargetInstance or SV.advancedDebuff)) then
        return activeCount
    end
end

function FancyActionBar.UpdateTargetsControl(effect, targetsControl, currentTime, precomputedActiveCount)
    local targetData = FancyActionBar.GetUnits(effect.id, "targets")
    if not targetData or not targetData.times then
        targetsControl:SetText("")
        return
    end
    local activeCount = precomputedActiveCount
    if activeCount == nil then
        activeCount = FancyActionBar.RecomputeUnits(effect.id, currentTime, "targets")
    end
    if not activeCount or activeCount == 0 then
        targetsControl:SetText("")
        return
    end
    local displayCount = FancyActionBar.ShouldShowTargetCount(effect, activeCount)
    if displayCount then
        targetsControl:SetText(displayCount)
        targetsControl:SetColor(unpack(FancyActionBar.constants.targets.color))
        return
    end
    targetsControl:SetText("")
end

function FancyActionBar.UpdateToggledAbility(id, active)
    FancyActionBar.toggles[FancyActionBar.bannerBearer[id] and "banner" or id] = active
    for index, slot in pairs(slots) do
        local match
        if FancyActionBar.bannerBearer[id] then
            match = FancyActionBar.bannerBearer[slot.effectId] or FancyActionBar.bannerBearer[slot.abilityId]
        else
            match = slot.effectId == id or slot.abilityId == id
        end
        if match then
            FancyActionBar.UpdateOverlay(index)
        end
    end
end

function FancyActionBar.UpdatePassiveEffect(id, active)
    local effect = FancyActionBar.effects[id]
    if effect then
        effect.passive = active
    end
end

function FancyActionBar.UnslotEffect(index) -- Remove effect from overlay index.
    if (index == ULT_INDEX) or (index == (ULT_INDEX + SLOT_INDEX_OFFSET)) then
        if index == ULT_INDEX then
            ultCosts.cost1 = 0
        elseif index == (ULT_INDEX + SLOT_INDEX_OFFSET) then
            ultCosts.cost2 = 0
        end
    end

    local overlay = GetOverlayForData(index)
    if overlay then
        FancyActionBar.ResetOverlayDuration(overlay)
    end
    FancyActionBar.slotStateSpecialEffects[index] = nil
    FancyActionBar.SetSlottedEffect(index, 0, 0)
end

function FancyActionBar.SlotEffect(index, abilityId, overrideRank, casterUnitTag, effectChanged) -- assign effect and instructions to overlay index.
    if (not abilityId or abilityId == 0) then
        FancyActionBar.UnslotEffect(index)
        return
    end

    local overlay = GetOverlayForData(index)
    if not overlay then
        return
    end

    if not effectChanged then
        local existing = slots[index]
        if existing and existing.abilityId == abilityId and existing.effectId then
            local existingEffect = FancyActionBar.effects[existing.effectId]
            if existingEffect then
                return existingEffect
            end
            return FancyActionBar.GetEffect(existing.effectId,
                {
                    abilityId = abilityId,
                    overrideRank = overrideRank,
                    casterUnitTag = casterUnitTag,
                })
        end
    end

    for idx, slot in pairs(slots) do
        if idx ~= index and slot.abilityId == abilityId then
            local slotNum = GetSlotFromOverlayIndex(idx)
            local hotbar = GetHotbarCategoryForOverlayIndex(idx)
            if FancyActionBar.GetSlotBoundAbilityId(slotNum, hotbar) ~= abilityId then
                FancyActionBar.UnslotEffect(idx)
            end
        end
    end

    local effectId = FancyActionBar.GetConfiguredEffectId(abilityId)
    FancyActionBar.SetSlottedEffect(index, abilityId, effectId)

    local effect = FancyActionBar.GetEffect(effectId,
        {
            abilityId = abilityId,
            overrideRank = overrideRank,
            casterUnitTag = casterUnitTag,
            reset = effectChanged,
        })

    if not SV.advancedDebuff and effect.isDebuff then
        effect.isDebuff = false
    end

    if not effect.isDebuff then
        local ownerId = FancyActionBar.GetStackOwnerId(abilityId)
        if ownerId == abilityId then
            ownerId = FancyActionBar.GetStackOwnerId(effectId)
        end
        local hasActiveEffect, activeDuration, activeStacks = FancyActionBar.CheckForActiveEffect(ownerId)
        if hasActiveEffect then
            effect.endTime = activeDuration == -1 and -1 or (time() + activeDuration)
        else
            effect.endTime = -1
        end
        FancyActionBar.SetStacks(ownerId, activeStacks, true)
    end

    local isFrontBar = index < SLOT_INDEX_OFFSET
    if isFrontBar then
        effect.slot1 = index
        if FancyActionBar.guard.ids[effect.id] then
            FancyActionBar.guard.slot1 = index
        end
    else
        effect.slot2 = index
        if FancyActionBar.guard.ids[effect.id] then
            FancyActionBar.guard.slot2 = index
        end
    end

    if index == ULT_INDEX or index == (ULT_INDEX + SLOT_INDEX_OFFSET) then
        if isFrontBar then
            ultCosts.cost1 = (abilityId == 113105) and 70 or GetAbilityCost(abilityId, COMBAT_MECHANIC_FLAGS_ULTIMATE, overrideRank, casterUnitTag)
        else
            ultCosts.cost2 = (abilityId == 113105) and 70 or GetAbilityCost(abilityId, COMBAT_MECHANIC_FLAGS_ULTIMATE, overrideRank, casterUnitTag)
        end
    end

    return effect
end

function FancyActionBar.SlotEffects(hotbarCategory)
    local currentHotbarCategory = hotbarCategory or GetActiveHotbarCategory()
    if currentHotbarCategory == HOTBAR_CATEGORY_PRIMARY or currentHotbarCategory == HOTBAR_CATEGORY_BACKUP then
        for i = MIN_INDEX, MAX_INDEX do
            FancyActionBar.SlotEffect(i, FancyActionBar.GetSlotBoundAbilityId(i, HOTBAR_CATEGORY_PRIMARY))
            FancyActionBar.SlotEffect(i + SLOT_INDEX_OFFSET, FancyActionBar.GetSlotBoundAbilityId(i, HOTBAR_CATEGORY_BACKUP))
        end
        FancyActionBar.SlotEffect(ULT_INDEX, FancyActionBar.GetSlotBoundAbilityId(ULT_INDEX, HOTBAR_CATEGORY_PRIMARY))
        FancyActionBar.SlotEffect(ULT_INDEX + SLOT_INDEX_OFFSET, FancyActionBar.GetSlotBoundAbilityId(ULT_INDEX, HOTBAR_CATEGORY_BACKUP))
    else
        -- slot effects for special bar.
        for i = MIN_INDEX, ULT_INDEX do
            FancyActionBar.SlotEffect(i, FancyActionBar.GetSlotBoundAbilityId(i, currentHotbarCategory))
        end
    end
    FancyActionBar.UpdateUltimateCost()
end

--------------
-- Quick Slot
--------------
function FancyActionBar.UpdateQuickSlotOverlay() -- from LUI. update every 500ms
    local t = FancyActionBar.qsOverlay.timer
    local slotIndex = GetCurrentQuickslot()
    local remain, duration, global = GetSlotCooldownInfo(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if (duration > 5000) then
        t:SetHidden(false)
        if remain > 86400000 then    -- more then 1 day
            t:SetText(string.format("%d d", zo_floor(remain / 86400000)))
        elseif remain > 6000000 then -- over 100 minutes - display XXh
            t:SetText(string.format("%dh", zo_floor(remain / 3600000)))
        elseif remain > 600000 then  -- over 10 minutes - display XXm
            t:SetText(string.format("%dm", zo_floor(remain / 60000)))
        elseif remain > 60000 then
            local m = zo_floor(remain / 60000)
            local s = remain / 1000 - 60 * m
            t:SetText(string.format("%d:%.2d", m, s))
        else
            t:SetText(string.format("%.1d", 0.001 * remain))
        end
    else
        if not FancyActionBar.InMenu() then
            t:SetText("")
        end
    end
end

--------------
-- GCD
--------------

-- Helper function to get just cooldown and duration
local function GetCooldownInfo(slotIndex)
    local cooldown, duration = GetSlotCooldownInfo(slotIndex, HOTBAR_CATEGORY_PRIMARY)
    return cooldown, duration
end

function FancyActionBar.UpdateGCD()
    local cooldown, duration = GetCooldownInfo(MIN_INDEX)
    local cooldown2, duration2 = GetCooldownInfo(MIN_INDEX + 1)

    if (cooldown2 > cooldown) or (duration2 > duration) then
        cooldown = cooldown2
        duration = duration2
    end

    if duration <= 1 then
        duration = 1
    end

    local height = (cooldown / duration) * SV.gcd.sizeY
    FAB_GCD.fill:SetHeight(height)
end

--------------
-- Ultimate
--------------
function FancyActionBar.GetValueString(mode, value, cost) -- format label text
    local string = ""
    if mode == 1 then
        string = value
    elseif mode == 3 then
        string = value .. "/" .. cost
    else
        if value >= cost
        then
            string = value
        else
            string = value .. "/" .. cost
        end
    end
    return string
end

function FancyActionBar.UpdateUltimateValueLabels(player, value) -- update ultimate value displays
    local modeP = FancyActionBar.constants.ult.value.mode
    local modeC = FancyActionBar.constants.ult.companion.mode
    local alpha = (value < 10) and 0 or 1
    local currentHotbarCategory = GetActiveHotbarCategory()
    if (player and FancyActionBar.constants.ult.value.show) then
        ActionButton8LeadingEdge:SetAlpha(alpha)
        -- ActionButton8UltimateBar:SetHidden(false)

        local activeOverlay = FancyActionBar.ultOverlays[ULT_INDEX]
        local inactiveOverlay = FancyActionBar.ultOverlays[ULT_INDEX + SLOT_INDEX_OFFSET]

        if activeOverlay and activeOverlay.value then
            activeOverlay.value:SetText(FancyActionBar.GetValueString(modeP, value, ultCosts.costAlt))
            activeOverlay.value:SetColor(unpack(FancyActionBar.GetUltimateValueColor(value, currentHotbarCategory)))
        end
        if inactiveOverlay and inactiveOverlay.value then
            inactiveOverlay.value:SetText("")
        end
    else
        local o3 = FancyActionBar.ultOverlays[ULT_INDEX + COMPANION_INDEX_OFFSET]
        if CompanionUltimateButtonLeadingEdge then
            CompanionUltimateButtonLeadingEdge:SetAlpha(SV.hideCompanionUlt and 0 or alpha)
        end
        if CompanionUltimateButton then
            CompanionUltimateButton:SetHidden(SV.hideCompanionUlt)
        end
        if o3 and o3.value then
            o3.value:SetText(SV.hideCompanionUlt and "" or FancyActionBar.GetValueString(modeC, value, ultCosts.cost3))
        end
    end
end

function FancyActionBar.OnUltChanged(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
    if powerType == COMBAT_MECHANIC_FLAGS_ULTIMATE then
        local current, _, _ = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
        FancyActionBar.UpdateUltimateValueLabels(true, current)
    end
end

function FancyActionBar.OnUltChangedCompanion(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
    if powerType == COMBAT_MECHANIC_FLAGS_ULTIMATE then
        local current, _, _ = GetUnitPower("companion", COMBAT_MECHANIC_FLAGS_ULTIMATE)
        FancyActionBar.UpdateUltimateValueLabels(false, current)
    end
end

function FancyActionBar.UpdateUltimateCost() -- manual ultimate value update
    if not FancyActionBar.constants.ult.value.show then
        return
    end

    local function ResolveUltCost(id, overrideActiveRank, overrideCasterUnitTag)
        overrideCasterUnitTag = overrideCasterUnitTag or "player"
        local incap = 113105
        local cost = 0
        if id > 0 then
            if id == incap
            then
                cost = 70
            else
                cost = GetAbilityCost(id, COMBAT_MECHANIC_FLAGS_ULTIMATE, overrideActiveRank, overrideCasterUnitTag)
            end
        end
        return cost
    end
    local currentHotbarCategory = GetActiveHotbarCategory()
    ultCosts.cost1 = ResolveUltCost(FancyActionBar.GetSlotBoundAbilityId(ULT_INDEX, HOTBAR_CATEGORY_PRIMARY))
    ultCosts.cost2 = ResolveUltCost(FancyActionBar.GetSlotBoundAbilityId(ULT_INDEX, HOTBAR_CATEGORY_BACKUP))
    ultCosts.costAlt = ResolveUltCost(FancyActionBar.GetSlotBoundAbilityId(ULT_INDEX, currentHotbarCategory))

    local current, _, _ = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
    FancyActionBar.UpdateUltimateValueLabels(true, current)
end

function FancyActionBar.GetUltimateValueColor(current, hotbar)
    -- Localize constants to avoid repeated table lookups
    local constants = FancyActionBar.constants.ult.value
    local baseColor = constants.color
    local maxColor = constants.maxColor

    -- Early return for max value case
    if current == 500 then return maxColor end

    -- Get ability ID and handle special cases
    local ultAbilityId = FancyActionBar.GetSlotBoundAbilityId(ULT_INDEX, hotbar)
    if not ultAbilityId or ultAbilityId <= 0 then return baseColor end

    -- Calculate cost
    local cost = ultAbilityId == 113105 and 70 or GetAbilityCost(ultAbilityId, COMBAT_MECHANIC_FLAGS_ULTIMATE, nil, "player")
    if cost == 0 then return baseColor end

    -- Calculate color based on thresholds
    local ratio = current / cost
    local usableColor = constants.usableColor
    local threshold = constants.threshold
    local thresholdColor = constants.usableThresholdColor

    if current >= cost then
        return usableColor
    elseif ratio >= threshold then
        return thresholdColor
    end

    return baseColor
end

--------------------------------------------------------------------------------
-----------------------------[ 		Configuration    ]----------------------------
--------------------------------------------------------------------------------
function FancyActionBar.RefreshUpdateConfiguration() -- set overlays refresh rate
    local update =
    {
        showDecimal = false,
        showDecimalStart = 0,
    }
    if (SV.showDecimal == "Never") then
        update.showDecimal = false
        update.showDecimalStart = 0
    elseif (SV.showDecimal == "Always") then
        update.showDecimal = true
        update.showDecimalStart = SV.durationMax
    elseif (SV.showDecimal == "Expire") then
        update.showDecimal = true
        update.showDecimalStart = SV.showDecimalStart
    end
    return update
end

function FancyActionBar.RefreshHighlightConfiguration()
    highlights.regular.show = SV.showHighlight
    highlights.regular.color = SV.highlightColor
    highlights.regular.expire = SV.highlightExpire
    highlights.regular.expireColor = SV.highlightExpireColor
    highlights.regular.toggled = SV.toggledHighlight
    highlights.regular.toggledColor = SV.toggledColor

    highlights.ult.show = SV.showUltHighlight
    highlights.ult.color = SV.ultHighlightColor
    highlights.ult.expire = SV.ultHighlightExpire
    highlights.ult.expireColor = SV.ultHighlightExpireColor
    highlights.ult.toggled = SV.ultToggledHighlight
    highlights.ult.toggledColor = SV.ultToggledColor
end

--  ---------------------------------
--  Load Saved Ability Configuration
--  ---------------------------------
function FancyActionBar.BuildAbilityConfig() -- Parse FancyActionBar.abilityConfig for faster access.
    abilityConfig = {}
    local config = FancyActionBar.GetAbilityConfig()
    local customConfig = FancyActionBar.GetAbilityConfigChanges()

    -- for id, cfg in pairs(FancyActionBar.abilityConfig) do
    -- local debuffs = FancyActionBar.constants.hideOnNoTargetList

    local parsedCustomConfig = {}
    for id, cfg in pairs(config) do
        local toggled, hide = false, false
        local craftedId = GetAbilityCraftedAbilityId(id)
        if customConfig[id] then
            cfg = customConfig[id]
            parsedCustomConfig[id] = true
        end

        -- if debuffs[id]
        -- then hide = debuffs[id]
        -- else hide = FancyActionBar.GetHideOnNoTargetGlobalSetting() end

        if FancyActionBar.toggled[id] then
            toggled = true
            FancyActionBar.toggles[FancyActionBar.bannerBearer[id] and "banner" or id] = false
        end

        local cI, rI = id, false

        if type(cfg) == "table" then
            if craftedId ~= 0 then
                if cfg[1] and cfg[2] and not cfg[2]["0_0_0"] then
                    cfg[2]["0_0_0"] = cfg[1]
                end
            end
        end

        if FancyActionBar.removeInstantly[cI] then
            rI = true
        end

        if type(cfg) == "table" then
            abilityConfig[id] = { cfg[1], cfg[2], toggled, rI }
        elseif cfg then
            abilityConfig[id] = { cfg[1], nil, toggled, rI }
        elseif cfg == false then
            abilityConfig[id] = false
        else
            abilityConfig[id] = nil
        end
    end

    for id, cfg in pairs(customConfig) do
        if not parsedCustomConfig[id] then
            local toggled, hide = false, false
            local cI, rI = id, false
            local craftedId = GetAbilityCraftedAbilityId(id)

            cfg = customConfig[id]
            if FancyActionBar.toggled[id] then
                toggled = true
                FancyActionBar.toggles[FancyActionBar.bannerBearer[id] and "banner" or id] = false
            end
            if FancyActionBar.removeInstantly[cI] then
                rI = true
            end
            if cfg == false then
                abilityConfig[id] = false
            elseif (cfg and cfg[1]) or cfg[2] then
                if craftedId ~= 0 then
                    if cfg[1] and cfg[2] and not cfg[2]["0_0_0"] then
                        cfg[2]["0_0_0"] = cfg[1]
                    end
                    abilityConfig[id] = { cfg[1], cfg[2], toggled, rI }
                else
                    abilityConfig[id] = { cfg[1], nil, toggled, rI }
                end
            else
                abilityConfig[id] = nil
            end
        end
    end

    -- for id, isToggled in pairs(FancyActionBar.toggled) do
    --   if id then
    --     local i
    --     -- if FancyActionBar.abilityConfig[id] then i = FancyActionBar.abilityConfig[id]
    --     if config[id] then i = config[id]
    --       if type(i) == 'table'
    --       then i = i[1] or id
    --       else i = id end
    --     else i = id end
    --     abilityConfig[id] = {i, true, isToggled}
    --     FancyActionBar.toggles[id]   = false
    --   end
    -- end

    local debuffStackSourceIds = {}
    local debuffStackMap = FancyActionBar.debuffStackMap
    if debuffStackMap then
        for ownerId, abilityIds in pairs(debuffStackMap) do
            debuffStackSourceIds[ownerId] = true
            if abilityIds then
                for i = 1, #abilityIds do
                    debuffStackSourceIds[abilityIds[i]] = true
                end
            end
        end
    end
    FancyActionBar.debuffStackSourceIds = debuffStackSourceIds

    local stackableBuffSet = {}
    local stackableBuff = FancyActionBar.stackableBuff
    if stackableBuff then
        for key, value in pairs(stackableBuff) do
            stackableBuffSet[key] = true
            if value ~= key then
                stackableBuffSet[value] = true
            end
        end
    end
    FancyActionBar.stackableBuffSet = stackableBuffSet
end

function FancyActionBar.DebugConfig(abilityId)
    return abilityConfig[abilityId]
end

--  ---------------------------------
--  Buffs gained by player from others
--  ---------------------------------
function FancyActionBar.OnEffectGainedFromAlly(eventCode, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return
    end
    if not AreUnitsEqual("player", unitTag) then
        return
    end
    local t = time()
    local fadeHasEffect, fadeDuration
    local doFullUpdate = true
    local trackExternalForWidgets = FancyActionBar.IsEffectWidgetExternalAllowed(abilityId)
    local allowExternalTracking = SV.externalBuffs or trackExternalForWidgets
    local stackableBuff = FancyActionBar.stackableBuff[abilityId]
    local didSourceAction = false
    local sourceCount
    if stackableBuff then
        if (change == EFFECT_RESULT_GAINED or (change == EFFECT_RESULT_UPDATED and buffType ~= BUFF_EFFECT_TYPE_DEBUFF)) then
            if beginTime ~= endTime and (endTime > t + FancyActionBar.durationMin and endTime < t + FancyActionBar.durationMax) then
                if unitId and unitId ~= 0 then
                    sourceCount = select(1, FancyActionBar.RecordUnit(stackableBuff, nil, effectSlot, t, beginTime, endTime, "sources", { castByPlayer = (sourceType == COMBAT_UNIT_TYPE_PLAYER) }))
                end
            end
        elseif (change == EFFECT_RESULT_FADED) then
            sourceCount = select(1, FancyActionBar.RemoveUnit(stackableBuff, effectSlot, t, "sources"))
        end
        didSourceAction = true
    end

    if not allowExternalTracking then
        if didSourceAction then
            FancyActionBar.SetStacks(stackableBuff, sourceCount, sourceCount ~= nil)
        end
        return
    end

    if SV.externalBuffs then
        local effectId = abilityId
        local effect = FancyActionBar.effects[effectId]
        if effect then
            if SV.externalBlackList[abilityId] then
                if not stackableBuff then
                    return
                else
                    doFullUpdate = false
                end
            end

            if (change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED and buffType ~= BUFF_EFFECT_TYPE_DEBUFF) then
                if beginTime == endTime and doFullUpdate then
                    FancyActionBar.UpdatePassiveEffect(effectId, true)
                    return
                end

                if (endTime > t + FancyActionBar.durationMin and endTime < t + FancyActionBar.durationMax and endTime > effect.endTime) then
                    -- per-source `sources` already handled above for stackableBuff
                    if doFullUpdate then
                        effect.endTime = endTime
                    end
                end
            elseif (change == EFFECT_RESULT_FADED) then
                if doFullUpdate and not (effect.dontFade and effect.endTime > t) then
                    fadeHasEffect, fadeDuration = FancyActionBar.CheckForActiveEffect(abilityId)
                    if fadeHasEffect then
                        effect.endTime = fadeDuration == -1 and -1 or ((fadeDuration and fadeDuration ~= 0) and (t + fadeDuration) or -1)
                    else
                        effect.endTime = t
                        if beginTime == endTime then
                            FancyActionBar.UpdatePassiveEffect(effectId, false)
                        end
                    end
                end
                -- per-source `sources` already handled above for stackableBuff
            end
        end
    end

    -- Widget-level external tracking: keep a dedicated table so widgets can reliably
    -- resolve external-only timing without depending on shared effect state.
    if trackExternalForWidgets then
        local slotMapped = sourceAbilities[abilityId]
        if not slotMapped or slotMapped == abilityId then
            local widgetStateId = abilityId
            local we = FancyActionBar.widgetEffects[widgetStateId] or { endTime = 0, stacks = 0 }
            if (change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED and buffType ~= BUFF_EFFECT_TYPE_DEBUFF) then
                if beginTime ~= endTime
                    and endTime > t + FancyActionBar.durationMin
                    and endTime < t + FancyActionBar.durationMax
                then
                    if endTime > (we.endTime or 0) then
                        we.endTime = endTime
                    end
                end

                we.stacks = stackCount or we.stacks
            elseif change == EFFECT_RESULT_FADED then
                if fadeHasEffect == nil then
                    fadeHasEffect, fadeDuration = FancyActionBar.CheckForActiveEffect(abilityId)
                end
                if fadeHasEffect then
                    we.endTime = fadeDuration == -1 and -1 or ((fadeDuration and fadeDuration ~= 0) and (t + fadeDuration) or -1)
                else
                    we.endTime = t
                end
                we.stacks = stackCount or (fadeHasEffect and we.stacks or 0)
            end

            FancyActionBar.widgetEffects[widgetStateId] = we
        end
    end
    if stackableBuff then
        FancyActionBar.SetStacks(stackableBuff, sourceCount, sourceCount ~= nil)
    end

    -- local ts = tostring
    -- FancyActionBar.AddSystemMessage('['..ts(abilityId)..'] '..effectName..' '..sourceType..': '..effectType..' --> '..unitName..endTime-beginTime..' ('..stackCount..')')
end

function FancyActionBar.SetExternalBuffTracking() -- buffs gained from others
    EM:UnregisterForEvent(NAME .. "External", EVENT_EFFECT_CHANGED)
    for abilityId in pairs(FancyActionBar.externalTrackingIds) do
        EM:UnregisterForEvent(NAME .. "External_" .. abilityId, EVENT_EFFECT_CHANGED)
        FancyActionBar.externalTrackingIds[abilityId] = nil
    end

    if SV.externalBuffs then
        EM:RegisterForEvent(NAME .. "External", EVENT_EFFECT_CHANGED, FancyActionBar.OnEffectGainedFromAlly)
        EM:AddFilterForEvent(NAME .. "External", EVENT_EFFECT_CHANGED, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    else
        local trackedExternalIds = {}
        for id in pairs(FancyActionBar.stackableBuff) do
            trackedExternalIds[id] = true
        end

        local widgets = GetAbilityConfigSavedVars().effectWidgets
        for abilityId, widget in pairs(widgets) do
            if widget and widget.enabled ~= false and widget.allowExternal then
                trackedExternalIds[abilityId] = true
                local trackedEffectId = GetWidgetEffectId(abilityId)
                if trackedEffectId and trackedEffectId ~= abilityId then
                    trackedExternalIds[trackedEffectId] = true
                end
            end
        end

        for id in pairs(trackedExternalIds) do
            EM:RegisterForEvent(NAME .. "External_" .. id, EVENT_EFFECT_CHANGED, FancyActionBar.OnEffectGainedFromAlly)
            EM:AddFilterForEvent(NAME .. "External_" .. id, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id)
            EM:AddFilterForEvent(NAME .. "External_" .. id, EVENT_EFFECT_CHANGED, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
            FancyActionBar.externalTrackingIds[id] = true
        end
    end
end

--  ---------------------------------
--  UI Setup
--  ---------------------------------

-- Move action bar and attributes up a bit.
function FancyActionBar:AdjustControlsPositions() -- resource bars and default action bar position
    if FAB_ActionBarFakeQS == nil then
        FAB_ActionBarFakeQS = GetControl("FAB_ActionBarFakeQS")
    end
    FAB_ActionBarFakeQS:ClearAnchors()
    FAB_ActionBarFakeQS:SetAnchor(LEFT, ACTION_BAR, LEFT, 0, -5, FAB_ActionBarFakeQS:GetResizeToFitConstrains())

    local style = FancyActionBar.constants.style
    local anchor = style.anchor
    anchor:SetFromControlAnchor(ACTION_BAR)
    anchor:SetOffsets(nil, style.actionBarOffset)
    anchor:Set(ACTION_BAR)
    anchor:SetFromControlAnchor(ZO_PlayerAttribute)
    anchor:SetOffsets(nil, style.attributesOffset)
    anchor:Set(ZO_PlayerAttribute)
end

function FancyActionBar.AdjustQuickSlotSpacing(lock)
    if SV.hideLockedBar then
        lock = lock or isWeaponSwapLocked
    end

    local c = FancyActionBar.constants
    local scaled = c.scaled.quickSlot
    local QSB = GetControl("QuickslotButton")
    local anchorOffsetY = scaled.y
    local anchorControl, anchorPoint, relPoint, anchorX

    if not SV.showArrow or lock then
        if SV.moveQS and weaponSwapControl then
            anchorControl = weaponSwapControl
            anchorPoint = RIGHT
            relPoint = RIGHT
            anchorX = scaled.anchorX
        else
            anchorControl = FAB_ActionBarFakeQS
            anchorPoint = LEFT
            relPoint = LEFT
            anchorX = scaled.x
        end
    else
        anchorControl = FAB_ActionBarFakeQS
        anchorPoint = LEFT
        relPoint = LEFT
        anchorX = scaled.x
        if (not SV.useDefaultWeaponSwap) and FAB_ActionBarArrow then
            FAB_ActionBarArrow:SetColor(unpack(SV.arrowColor))
        end
    end

    QSB:ClearAnchors()
    QSB:SetAnchor(anchorPoint, anchorControl, relPoint, anchorX, anchorOffsetY, QSB:GetResizeToFitConstrains())
    FancyActionBar.UpdateWeaponSwapControlVisibility(lock)
end

function FancyActionBar.AdjustUltimateSpacing() -- place the ultimate button according to variables
    if FancyActionBar.constants.mode == 1 then
        return
    end

    local ult = FancyActionBar.constants.scaled.ultimate
    local ultSpace = FancyActionBar.constants.style.ultimateSpacing or {}

    ActionButton8:ClearAnchors()
    CompanionUltimateButton:ClearAnchors()

    local ultCX = ult.companionGap
    local ultCY = 0
    local u = ult.ultWidth
    local f2 = ult.barEndX

    if SV.showHotkeysUltGP then
        ActionButton8:SetAnchor(LEFT, weaponSwapControl, RIGHT, f2 + u + ult.anchorX, ult.anchorY, ActionButton8:GetResizeToFitConstrains())
        CompanionUltimateButton:SetAnchor(LEFT, ActionButton8, RIGHT, u + ultCX, ultCY, CompanionUltimateButton:GetResizeToFitConstrains())
        return
    end

    if SV.moveQS then
        ActionButton8:SetAnchor(LEFT, weaponSwapControl, RIGHT, f2 + ult.baseX + ult.anchorX, ult.anchorY, ActionButton8:GetResizeToFitConstrains())
        CompanionUltimateButton:SetAnchor(LEFT, ActionButton8, RIGHT, ult.baseGap + ultCX, 0, CompanionUltimateButton:GetResizeToFitConstrains())
    else
        ActionButton8:SetAnchor(LEFT, weaponSwapControl, RIGHT, f2 + u + ult.anchorX, ult.anchorY, ActionButton8:GetResizeToFitConstrains())
        CompanionUltimateButton:SetAnchor(LEFT, ActionButton8, RIGHT, u + ultCX, ultCY, CompanionUltimateButton:GetResizeToFitConstrains())
    end
end

function FancyActionBar:ApplySettings() -- overlay fonts, frames, and timers (layout scopes handle position/spacing)
    self.ConfigureFrames()
    self.ApplyTimerFont()
    self.AdjustTimerY()

    self.ApplyStackFont()
    self.ApplyStackPosition()

    self.ApplyTargetFont()
    self.ApplyTargetPosition()

    self.AdjustUltTimer(false)
    self.ApplyUltFont(false)

    self.AdjustUltValue()
    self.ApplyUltValueColor()
    self.AdjustCompanionUltValue()
    self.ApplyUltValueFont()

    self:AdjustQuickSlotTimer()
    self.ApplyQuickSlotFont()
    self.ToggleQuickSlotDuration()

    self.ToggleGCD()
end

function FancyActionBar.ToggleQuickSlotDuration() -- enable / disable quickslot timer
    local enable = FancyActionBar.constants.qs.show
    EM:UnregisterForUpdate(NAME .. "UpdateQuickSlot")
    if enable
    then
        EM:RegisterForUpdate(NAME .. "UpdateQuickSlot", 500, FancyActionBar.UpdateQuickSlotOverlay)
    else
        FancyActionBar.qsOverlay:GetNamedChild("Duration"):SetText("")
    end
end

local function hideUltimateNumberIfNeeded()
    if ZO_IsConsoleOrGameCoreUI() then
        return
    end
    if FancyActionBar.constants.ult.value.show then
        SetSetting(SETTING_TYPE_UI, UI_SETTING_ULTIMATE_NUMBER, "false")
    end
end

function FancyActionBar.ToggleUltimateValue() -- enable / disable ultimate value
    local function clearUltimateOverlays()
        for i in pairs(FancyActionBar.ultOverlays) do
            local valueControl = FancyActionBar.ultOverlays[i]:GetNamedChild("Value")
            if valueControl then
                valueControl:SetText("")
            end
        end
    end

    local function setupPlayerUltimate(showValue)
        if showValue then
            local current = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
            FancyActionBar.UpdateUltimateValueLabels(true, current)
            EM:RegisterForEvent(NAME .. "UltValue", EVENT_POWER_UPDATE, FancyActionBar.OnUltChanged)
            EM:AddFilterForEvent(NAME .. "UltValue", EVENT_POWER_UPDATE,
                REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE,
                REGISTER_FILTER_UNIT_TAG, "player")
        end
    end

    EM:UnregisterForEvent(NAME .. "UltValue", EVENT_POWER_UPDATE)
    clearUltimateOverlays()

    setupPlayerUltimate(FancyActionBar.constants.ult.value.show)
    hideUltimateNumberIfNeeded()
    FancyActionBar.HandleCompanionUltimate()
end

local function initializeOverlayControls(overlayControl, includeValue)
    overlayControl.timer = overlayControl:GetNamedChild("Duration")
    overlayControl.bg = overlayControl:GetNamedChild("BG")
    overlayControl.stack = overlayControl:GetNamedChild("Stacks")
    overlayControl.target = overlayControl:GetNamedChild("Targets")
    if includeValue then
        overlayControl.value = overlayControl:GetNamedChild("Value")
    end
end

local overlayTemplatesApplied = {}

local function applyOverlayTemplate(overlay, template)
    if overlayTemplatesApplied[overlay] == template then
        return false
    end
    WM:ApplyTemplateToControl(overlay, template)
    overlayTemplatesApplied[overlay] = template
    return true
end

---
--- @param index integer
--- @return Control|FAB_ActionButtonOverlay_Gamepad_Template|FAB_ActionButtonOverlay_Keyboard_Template
function FancyActionBar.CreateOverlay(index) -- create normal skill button overlay.
    local template = FancyActionBar.constants.style.overlayTemplate
    --- @type Control
    local overlay = FancyActionBar.overlays[index]
    if overlay then
        local templateChanged = applyOverlayTemplate(overlay, template)
        overlay:ClearAnchors()
        if templateChanged then
            overlay.activeEffects = {}
        end
    else
        overlay = WM:CreateControlFromVirtual("ActionButtonOverlay", ACTION_BAR, template, index)
        overlayTemplatesApplied[overlay] = template
        FancyActionBar.overlays[index] = overlay
    end
    initializeOverlayControls(overlay)
    return overlay
end

---
--- Creates or updates an ultimate button overlay
--- @param index integer The index of the ultimate button
--- @return FAB_UltimateButtonOverlay_Gamepad_Template|FAB_UltimateButtonOverlay_Keyboard_Template
function FancyActionBar.CreateUltOverlay(index)
    local function getParentButton(buttonIndex)
        if buttonIndex == ULT_INDEX + COMPANION_INDEX_OFFSET then
            return ZO_ActionBar_GetButton(ULT_INDEX, HOTBAR_CATEGORY_COMPANION)
        end
        return ZO_ActionBar_GetButton(ULT_INDEX)
    end

    -- Get the template for the overlay
    local template = FancyActionBar.constants.style.ultOverlayTemplate
    local overlay = FancyActionBar.ultOverlays[index]

    -- Update existing overlay if it exists
    if overlay then
        applyOverlayTemplate(overlay, template)
        overlay:ClearAnchors()
        initializeOverlayControls(overlay, true)
        return overlay
    end

    -- Create new overlay
    local parent = getParentButton(index)
    overlay = WM:CreateControlFromVirtual("UltimateButtonOverlay", parent.slot, template, index)
    overlayTemplatesApplied[overlay] = template

    initializeOverlayControls(overlay, true)

    -- Store the overlay
    FancyActionBar.ultOverlays[index] = overlay

    return overlay
end

---
--- @param index integer
--- @return FAB_QuickSlotOverlay_Gamepad_Template|FAB_QuickSlotOverlay_Keyboard_Template
function FancyActionBar.CreateQuickSlotOverlay(index) -- create quickslot button overlay.
    local template = FancyActionBar.constants.style.qsOverlayTemplate
    local overlay = FancyActionBar.qsOverlay
    if overlay then
        applyOverlayTemplate(overlay, template)
        overlay:ClearAnchors()
    else
        overlay = WM:CreateControlFromVirtual("QuickSlotOverlay", ACTION_BAR, template, index)
        overlayTemplatesApplied[overlay] = template
        FancyActionBar.qsOverlay = overlay
    end
    return overlay
end

function FancyActionBar.SaveEffectWidgetPosition(abilityId)
    local widgets = GetAbilityConfigSavedVars().effectWidgets
    local widget = widgets[abilityId]
    local control = FancyActionBar.effectWidgetControls[abilityId]
    if not widget or not control then
        return
    end

    local cx, cy = control:GetCenter()
    widget.x = cx
    widget.y = cy
    -- If the settings menu is open, update the sliders so they show the new values
    local sliderX = WM:GetControlByName("EffectWidget_X_Slider")
    if sliderX and sliderX.UpdateValue then
        sliderX:UpdateValue()
    end
    local sliderY = WM:GetControlByName("EffectWidget_Y_Slider")
    if sliderY and sliderY.UpdateValue then
        sliderY:UpdateValue()
    end
end

local function EnsureEffectWidgetPositionDefaults(abilityId, widget)
    if widget.x and widget.y then
        return
    end

    local actionBarLeft = ACTION_BAR and ACTION_BAR:GetLeft() or 0
    local actionBarTop = ACTION_BAR and ACTION_BAR:GetTop() or 0
    local widgetCount = 0
    for _ in pairs(FancyActionBar.effectWidgetControls) do
        widgetCount = widgetCount + 1
    end
    local rowIndex = (widgetCount % 6)
    local columnIndex = zo_floor(widgetCount / 6)

    -- Compute defaults as center coordinates. Account for any saved scale if present.
    local control = FancyActionBar.effectWidgetControls[abilityId]
    local baseW, baseH = 50, 50
    if control then
        baseW = control:GetWidth() or baseW
        baseH = control:GetHeight() or baseH
    end
    local widgetScale = tonumber(widget and widget.scale) or 1
    local topLeftX = (actionBarLeft or 0) + (rowIndex * 55)
    local topLeftY = (actionBarTop or 0) - 60 - (columnIndex * 55)
    widget.x = topLeftX + (baseW * widgetScale) / 2
    widget.y = topLeftY + (baseH * widgetScale) / 2
end

local function CreateEffectWidgetControl(abilityId, widget)
    local control = FancyActionBar.effectWidgetControls[abilityId]
    local parent = GuiRoot
    if not control then
        control = WM:CreateControlFromVirtual("FAB_EffectWidget" .. tostring(abilityId), parent, "FAB_EffectWidget_Template")
        control.icon = control:GetNamedChild("Icon")
        control.timer = control:GetNamedChild("Duration")
        control.stack = control:GetNamedChild("Stacks")
        control.target = control:GetNamedChild("Targets")
        control.bg = control:GetNamedChild("BG")
        control:SetHandler("OnMoveStop", function ()
            FancyActionBar.SaveEffectWidgetPosition(abilityId)
        end)
        FancyActionBar.effectWidgetControls[abilityId] = control
    end

    EnsureEffectWidgetPositionDefaults(abilityId, widget)
    local x = widget and widget.x or 0
    local y = widget and widget.y or 0
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y, control:GetResizeToFitConstrains())
    control:SetScale(tonumber(widget and widget.scale) or 1)
    local locked = GetAbilityConfigSavedVars().effectWidgetsLocked ~= false
    control:SetMovable(not locked)
    control:SetMouseEnabled(not locked)
    control:SetClampedToScreen(true)

    if control.icon then
        local iconTexture = GetAbilityIcon(abilityId)
        if iconTexture and iconTexture ~= "" then
            control.icon:SetTexture(iconTexture)
        end
    end

    return control
end

local function RemoveEffectWidgetControl(abilityId)
    local control = FancyActionBar.effectWidgetControls[abilityId]
    if control then
        control:SetHidden(true)
        FancyActionBar.effectWidgetControls[abilityId] = nil
    end
end

local function FormatEffectWidgetDurationText(duration)
    local updateConfig = FancyActionBar.constants.update or FancyActionBar.RefreshUpdateConfiguration()
    if duration <= 0 then
        return ""
    end

    if updateConfig.showDecimal and duration <= updateConfig.showDecimalStart then
        return strformat("%0.1f", duration)
    end

    return strformat("%0.0f", duration)
end

local function ResolveWidgetDuration(effect, currentTime, allowExternal, externalOnly)
    local duration = 0
    local activeSources = 0
    local we = effect and FancyActionBar.widgetEffects[effect.id]
    local instantWidgetFade = effect and (effect.instantFade or FancyActionBar.removeInstantly[effect.id])

    if not externalOnly and effect and effect.endTime and effect.endTime > currentTime then
        duration = effect.endTime - currentTime
    end

    if we and instantWidgetFade then
        we.persistEndTime = nil
        we.endTime = 0
    end

    if we and we.persistEndTime and not instantWidgetFade then
        if we.persistEndTime > currentTime then
            duration = zo_max(duration, we.persistEndTime - currentTime)
        else
            we.persistEndTime = nil
        end
    end

    -- Merge widget-only external end time (populated when SV.externalBuffs is off but widget allows external)
    if (allowExternal or externalOnly) and effect and not instantWidgetFade then
        if we and we.endTime and we.endTime > currentTime then
            duration = zo_max(duration, we.endTime - currentTime)
        end
    end

    local playerOnlyEnd = nil
    local externalOnlyEnd = nil
    if effect and effect.sources and effect.sources.times then
        local sourceCount, _, maxEndTime = FancyActionBar.RecomputeUnits(effect.id, currentTime, "sources")
        activeSources = sourceCount or 0
        if activeSources and activeSources > 0 then
            if externalOnly then
                for _, entry in pairs(effect.sources.times) do
                    if entry
                        and entry.endTime
                        and entry.endTime > currentTime
                        and not (entry.meta and entry.meta.castByPlayer)
                    then
                        externalOnlyEnd = externalOnlyEnd and zo_max(externalOnlyEnd, entry.endTime) or entry.endTime
                    end
                end
                if externalOnlyEnd and externalOnlyEnd > currentTime then
                    duration = zo_max(duration, externalOnlyEnd - currentTime)
                end
            elseif allowExternal then
                if maxEndTime and maxEndTime > currentTime then
                    duration = zo_max(duration, maxEndTime - currentTime)
                end
            else
                for _, entry in pairs(effect.sources.times) do
                    if entry and entry.endTime and entry.endTime > currentTime and entry.meta and entry.meta.castByPlayer then
                        playerOnlyEnd = playerOnlyEnd and zo_max(playerOnlyEnd, entry.endTime) or entry.endTime
                    end
                end
                if playerOnlyEnd and playerOnlyEnd > currentTime then
                    duration = zo_max(duration, playerOnlyEnd - currentTime)
                end
            end
        end
    end

    return duration, playerOnlyEnd, externalOnlyEnd, activeSources
end

function FancyActionBar.UpdateSingleEffectWidget(abilityId, widget, control, updateTime)
    local widgetVars = GetAbilityConfigSavedVars()
    local showForMove = widgetVars.effectWidgetsLocked == false
    local activeAlpha = zo_clamp(tonumber(widget.activeAlpha) or widgetVars.effectWidgetActiveAlphaDefault or defaultSettings.effectWidgetActiveAlphaDefault, 0, 1)
    local inactiveAlpha = zo_clamp(tonumber(widget.inactiveAlpha) or widgetVars.effectWidgetInactiveAlphaDefault or defaultSettings.effectWidgetInactiveAlphaDefault, 0, 1)
    local showWhenInactive = not showForMove and inactiveAlpha > 0
    local effectId = GetWidgetEffectId(abilityId)
    local effect = effectId and FancyActionBar.effects[effectId] or nil
    if not effect then
        control:SetHidden(not (showForMove or showWhenInactive))
        if showForMove or showWhenInactive then
            control:SetAlpha(showForMove and activeAlpha or inactiveAlpha)
            control.timer:SetText("")
            control.stack:SetText("")
            control.target:SetText("")
        end
        return
    end

    local currentTime = updateTime or time()
    local duration, playerOnlyEnd, externalOnlyEnd, activeSources = ResolveWidgetDuration(effect, currentTime, widget.allowExternal, widget.externalOnly)
    if effect.endTime and effect.endTime > currentTime and not (effect.instantFade or FancyActionBar.removeInstantly[effect.id]) then
        local we = FancyActionBar.widgetEffects[effect.id] or {}
        we.persistEndTime = zo_max(we.persistEndTime or 0, effect.endTime)
        FancyActionBar.widgetEffects[effect.id] = we
    end
    local hasDuration = duration > 0
    local isToggled = FancyActionBar.toggles[FancyActionBar.bannerBearer[effect.id] and "banner" or effect.id]

    local restrictSources = widget.externalOnly or not widget.allowExternal
    if restrictSources then
        local trackingEnd = widget.externalOnly and externalOnlyEnd or playerOnlyEnd
        if trackingEnd then
            hasDuration = true
        elseif activeSources > 0 and not effect.hasActiveCast and not isToggled then
            hasDuration = false
            duration = 0
        end
    end

    local isActive = hasDuration or isToggled
    local showWidget = isActive or showForMove or showWhenInactive
    control:SetHidden(not showWidget)

    if not showWidget then
        return
    end

    if showForMove or isActive then
        control:SetAlpha(activeAlpha)
    else
        control:SetAlpha(inactiveAlpha)
    end

    if isToggled and not hasDuration then
        control.timer:SetText("T")
    else
        control.timer:SetText(FormatEffectWidgetDurationText(duration))
    end

    if not effect.stackSources then
        local effectStackEntry = FancyActionBar.GetStackMap(effect.id)
        local abilityStackEntry = FancyActionBar.GetStackMap(abilityId)
        effect.stackSources = ResolveStackSources(abilityId, effect.id, effectStackEntry, abilityStackEntry)
        effect.stackOwnerId = effectStackEntry.ownerId
    end

    local resolvedStacks = FancyActionBar.GetDisplayStacks(effect, currentTime)
    if (not resolvedStacks or resolvedStacks == 0) and widget.allowExternal then
        local we = FancyActionBar.widgetEffects[effect.id]
        if we and we.stacks and we.stacks ~= 0 then
            resolvedStacks = we.stacks
        end
    end
    control.stack:SetText(resolvedStacks and resolvedStacks ~= 0 and tostring(resolvedStacks) or "")

    local targetData = FancyActionBar.GetUnits(effect.id, "targets")
    if targetData and targetData.times then
        local activeCount, _, _ = FancyActionBar.RecomputeUnits(effect.id, currentTime, "targets")
        local displayCount = FancyActionBar.ShouldShowTargetCount(effect, activeCount)
        control.target:SetText(displayCount and tostring(displayCount) or "")
    else
        control.target:SetText("")
    end
end

function FancyActionBar.IsEffectWidgetExternalAllowed(abilityId)
    local widgets = GetAbilityConfigSavedVars().effectWidgets
    for widgetAbilityId, widget in pairs(widgets) do
        if widget and widget.enabled ~= false and widget.allowExternal then
            local trackedEffectId = GetWidgetEffectId(widgetAbilityId)
            if widgetAbilityId == abilityId or trackedEffectId == abilityId then
                return true
            end
        end
    end
    return false
end

function FancyActionBar.AddEffectWidget(abilityId, allowExternal, scaleOffset, activeAlpha, inactiveAlpha, externalOnly)
    if not abilityId then
        return false
    end

    local widgetVars = GetAbilityConfigSavedVars()
    local widgets = widgetVars.effectWidgets
    local widget = widgets[abilityId] or {}
    local resolvedScale = tonumber(scaleOffset)
    if resolvedScale == nil then
        resolvedScale = tonumber(widget.scale) or 1
    end
    local resolvedActiveAlpha = activeAlpha
    if resolvedActiveAlpha == nil then
        resolvedActiveAlpha = widget.activeAlpha
    end
    resolvedActiveAlpha = zo_clamp(tonumber(resolvedActiveAlpha) or widgetVars.effectWidgetActiveAlphaDefault or defaultSettings.effectWidgetActiveAlphaDefault, 0, 1)

    local resolvedInactiveAlpha = inactiveAlpha
    if resolvedInactiveAlpha == nil then
        resolvedInactiveAlpha = widget.inactiveAlpha
    end
    resolvedInactiveAlpha = zo_clamp(tonumber(resolvedInactiveAlpha) or widgetVars.effectWidgetInactiveAlphaDefault or defaultSettings.effectWidgetInactiveAlphaDefault, 0, 1)

    local resolvedExternalOnly = externalOnly
    if resolvedExternalOnly == nil then
        resolvedExternalOnly = widget.externalOnly == true
    end

    widget.enabled = true
    widget.allowExternal = allowExternal == true
    widget.externalOnly = widget.allowExternal and resolvedExternalOnly == true
    widget.scale = resolvedScale
    widget.activeAlpha = resolvedActiveAlpha
    widget.inactiveAlpha = resolvedInactiveAlpha

    EnsureEffectWidgetPositionDefaults(abilityId, widget)
    widgets[abilityId] = widget

    FancyActionBar.RefreshEffectWidgets()
    FancyActionBar.SetExternalBuffTracking()

    return true
end

function FancyActionBar.RemoveEffectWidget(abilityId)
    if not abilityId then
        return
    end

    local widgets = GetAbilityConfigSavedVars().effectWidgets
    widgets[abilityId] = nil
    FancyActionBar.widgetEffects[abilityId] = nil
    local trackedEffectId = GetWidgetEffectId(abilityId)
    if trackedEffectId and trackedEffectId ~= abilityId then
        FancyActionBar.widgetEffects[trackedEffectId] = nil
    end
    RemoveEffectWidgetControl(abilityId)
    FancyActionBar.SetExternalBuffTracking()
end

function FancyActionBar.RefreshEffectWidgets()
    local widgets = GetAbilityConfigSavedVars().effectWidgets
    hasEnabledEffectWidgets = false

    for abilityId in pairs(FancyActionBar.effectWidgetControls) do
        local widget = widgets[abilityId]
        if not widget or widget.enabled == false then
            RemoveEffectWidgetControl(abilityId)
        else
            hasEnabledEffectWidgets = true
            CreateEffectWidgetControl(abilityId, widget)
        end
    end

    for abilityId, widget in pairs(widgets) do
        if widget and widget.enabled ~= false then
            hasEnabledEffectWidgets = true
            if not FancyActionBar.effectWidgetControls[abilityId] then
                CreateEffectWidgetControl(abilityId, widget)
            end
        end
    end
end

function FancyActionBar.UpdateEffectWidgets(updateTime)
    for abilityId, widget in pairs(GetAbilityConfigSavedVars().effectWidgets) do
        if widget and widget.enabled ~= false then
            local control = FancyActionBar.effectWidgetControls[abilityId]
            if control then
                FancyActionBar.UpdateSingleEffectWidget(abilityId, widget, control, updateTime)
            end
        end
    end
end

local function positionUltimateSlots()
    if FancyActionBar.constants.mode == 2 then
        FancyActionBar.AdjustUltimateSpacing()
        return
    end
    local ult = FancyActionBar.constants.scaled.ultimate
    ActionButton8:ClearAnchors()
    CompanionUltimateButton:ClearAnchors()
    ActionButton8:SetAnchor(LEFT, weaponSwapControl, RIGHT, ult.barEndX + ult.anchorX, ult.anchorY, ActionButton8:GetResizeToFitConstrains())
    CompanionUltimateButton:SetAnchor(LEFT, ActionButton8, RIGHT, ult.slotGap + ult.trailing, 0, CompanionUltimateButton:GetResizeToFitConstrains())
end

local GP_ULT_FILL_TEXTURE = "FancyActionBar+/texture/gp_ultimatefill_512.dds"

local function configureGamepadUltVisuals(frame, leftFill, rightFill, flipCard, ultFlipCardSize)
    if not flipCard then
        return
    end

    local s = ultFlipCardSize / FancyActionBar.gamepadConstants.ultFlipCardSize
    local inset, offsetY, fillWidth = zo_floor(12 * s), zo_floor(36 * s), zo_floor(70 * s)

    if frame then
        frame:ClearAnchors()
        frame:SetAnchor(TOPLEFT, flipCard, TOPLEFT, -inset, -inset)
        frame:SetAnchor(BOTTOMRIGHT, flipCard, BOTTOMRIGHT, inset, inset)
        frame:SetHidden(false)
    end

    for _, entry in ipairs({ { leftFill, zo_floor(-37 * s) }, { rightFill, zo_floor(33 * s) } }) do
        local fill, offsetX = entry[1], entry[2]
        if fill then
            fill:ClearDimensions()
            fill:SetWidth(fillWidth)
            fill:ClearAnchors()
            fill:SetAnchor(TOPLEFT, flipCard, TOPLEFT, offsetX, -offsetY)
            fill:SetAnchor(BOTTOMLEFT, flipCard, BOTTOMLEFT, offsetX, offsetY)
            fill:SetHidden(false)
        end
    end
end

local function configureFillAnimationsAndFrames(style)
    local c = FancyActionBar.constants
    local ultFlipCardSize = style.ultFlipCardSize
    local gpUltVisuals =
    {
        {
            frame = GetControl("ActionButton8Frame"),
            leftFill = GetControl("ActionButton8FillAnimationLeft"),
            rightFill = GetControl("ActionButton8FillAnimationRight"),
            flipCard = GetControl("ActionButton8FlipCard"),
        },
        {
            frame = GetControl("CompanionUltimateButtonFrame"),
            leftFill = GetControl("CompanionUltimateButtonFillAnimationLeft"),
            rightFill = GetControl("CompanionUltimateButtonFillAnimationRight"),
            flipCard = GetControl("CompanionUltimateButtonFlipCard"),
        },
    }

    if not gpUltVisuals[1].frame or not gpUltVisuals[2].frame then
        return
    end

    local showGamepadUlt = c.mode == 2 and IsSlotUsed(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, GetActiveHotbarCategory())
    for _, visual in ipairs(gpUltVisuals) do
        if showGamepadUlt then
            if visual.leftFill then
                visual.leftFill:SetTexture(GP_ULT_FILL_TEXTURE)
            end
            if visual.rightFill then
                visual.rightFill:SetTexture(GP_ULT_FILL_TEXTURE)
            end
            configureGamepadUltVisuals(visual.frame, visual.leftFill, visual.rightFill, visual.flipCard, ultFlipCardSize)
        else
            if visual.frame then
                visual.frame:SetHidden(true)
            end
            for _, fill in ipairs({ visual.leftFill, visual.rightFill }) do
                if fill then
                    fill:ClearAnchors()
                    fill:SetHidden(true)
                end
            end
        end
    end

    if showGamepadUlt then
        FancyActionBar.SetUltFrameAlpha()
    end
end

function FancyActionBar.SetUltFrameAlpha()
    GetControl("ActionButton8Frame"):SetAlpha(SV.ultFillFrameAlpha)
    GetControl("ActionButton8FillAnimationLeft"):SetAlpha(SV.ultFillBarAlpha)
    GetControl("ActionButton8FillAnimationRight"):SetAlpha(SV.ultFillBarAlpha)
    if AreCompanionSkillsInitialized() then
        GetControl("CompanionUltimateButtonFrame"):SetAlpha(SV.ultFillFrameAlpha)
        GetControl("CompanionUltimateButtonFillAnimationLeft"):SetAlpha(SV.ultFillBarAlpha)
        GetControl("CompanionUltimateButtonFillAnimationRight"):SetAlpha(SV.ultFillBarAlpha)
    end
end

local function SetupUltAndQuickslotOverlays()
    local actionbutton8 = GetControl("ActionButton8")
    local companionultimatebutton = GetControl("CompanionUltimateButton")
    local QSB = QuickslotButton

    AnchorOverlayToSlot(FancyActionBar.CreateUltOverlay(ULT_INDEX), actionbutton8)
    local backUltBtn = FancyActionBar.buttons[ULT_INDEX + SLOT_INDEX_OFFSET]
    AnchorOverlayToSlot(
        FancyActionBar.CreateUltOverlay(ULT_INDEX + SLOT_INDEX_OFFSET),
        backUltBtn and backUltBtn.slot or actionbutton8
    )
    AnchorOverlayToSlot(FancyActionBar.CreateUltOverlay(ULT_INDEX + COMPANION_INDEX_OFFSET), companionultimatebutton)

    local QO = FancyActionBar.CreateQuickSlotOverlay(QUICK_SLOT)
    AnchorOverlayToSlot(QO, QSB)
    QO.timer = QO:GetNamedChild("Duration")
    QO.timer:SetColor(unpack(FancyActionBar.constants.qs.color))

    local qsFrame = FancyActionBar.qsOverlay:GetNamedChild("Frame")
    if qsFrame then
        QO.frame = qsFrame
    end
end

local function applyButtonStyles(style)
    local ultButton = ZO_ActionBar_GetButton(ULT_INDEX)
    local ultButtonC = ZO_ActionBar_GetButton(ULT_INDEX, HOTBAR_CATEGORY_COMPANION)
    local QSButton = ZO_ActionBar_GetButton(QUICK_SLOT, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    ultButton:ApplyStyle(style.ultButtonTemplate)
    ultButtonC:ApplyStyle(style.ultButtonTemplate)
    QSButton:ApplyStyle(style.buttonTemplate)
end

local function setFlipCardDimensions(style)
    local flipCardSize = style.flipCardSize
    local ultFlipCardSize = style.ultFlipCardSize

    for i = MIN_INDEX, MAX_INDEX do
        local btn = ZO_ActionBar_GetButton(i)
        local flip = btn and (btn.flipCard or (btn.slot and btn.slot:GetNamedChild("FlipCard")))
        if flip then
            flip:ClearDimensions()
            flip:SetDimensions(flipCardSize, flipCardSize)
        end
        local back = FancyActionBar.buttons[i + SLOT_INDEX_OFFSET]
        flip = back and (back.flipCard or (back.slot and back.slot:GetNamedChild("FlipCard")))
        if flip then
            flip:ClearDimensions()
            flip:SetDimensions(flipCardSize, flipCardSize)
        end
    end

    local c8 = GetControl("ActionButton8FlipCard")
    local c9 = GetControl("ActionButton9FlipCard")
    local c38 = GetControl("CompanionUltimateButtonFlipCard")
    if c8 then
        c8:ClearDimensions()
        c8:SetDimensions(ultFlipCardSize, ultFlipCardSize)
    end
    if c9 then
        c9:ClearDimensions()
        c9:SetDimensions(flipCardSize, flipCardSize)
    end
    if c38 then
        c38:ClearDimensions()
        c38:SetDimensions(ultFlipCardSize, ultFlipCardSize)
    end
end

local function applyUltimateStyle(style)
    applyButtonStyles(style)
    setFlipCardDimensions(style)
    configureFillAnimationsAndFrames(style)
    FancyActionBar.SetUltScale()
    FancyActionBar.SetQsScale()
end

function FancyActionBar.SetUltScale()
    local childScale = GetUltChildScale()
    if ActionButton8 then
        ActionButton8:SetScale(childScale)
    end
    if CompanionUltimateButton then
        CompanionUltimateButton:SetScale(childScale)
    end
    local backUlt = FancyActionBar.buttons[ULT_INDEX + SLOT_INDEX_OFFSET]
    if backUlt and backUlt.slot then
        backUlt.slot:SetScale(childScale)
    end
end

function FancyActionBar.SetQsScale()
    local QSB = GetControl("QuickslotButton")
    if QSB then
        QSB:SetScale(GetQsChildScale())
    end
end

function FancyActionBar.ApplyQsScalingSettings()
    local c = FancyActionBar.constants
    if not c or not SV.qsScaling then
        return
    end
    local qs = SV.qsScaling[c.mode == 2 and "gp" or "kb"]
    c.qsScale.enable = qs.enable
    c.qsScale.scale = qs.scale
    FancyActionBar.SetQsScale()
    local _, locked = GetActiveWeaponPairInfo()
    FancyActionBar.AdjustQuickSlotSpacing(SV.hideLockedBar and locked)
end

function FancyActionBar.ApplyUltScalingSettings()
    local c = FancyActionBar.constants
    if not c or not SV.ultScaling then
        return
    end
    local ult = SV.ultScaling[c.mode == 2 and "gp" or "kb"]
    c.ultScale.enable = ult.enable
    c.ultScale.scale = ult.scale
    FancyActionBar.ApplyScaleToLayout(scale)
    applyUltimateStyle(c.style)
    positionUltimateSlots()
    for _, button in ipairs(
        {
            ZO_ActionBar_GetButton(ULT_INDEX),
            AreCompanionSkillsInitialized() and ZO_ActionBar_GetButton(ULT_INDEX, HOTBAR_CATEGORY_COMPANION) or nil,
        }) do
        if button and button.UpdateUltimateMeter then
            button:UpdateUltimateMeter()
        end
    end
end

--- Setup the action bar with the given style.
--- @param style table
function FancyActionBar.SetupActionBar(style)
    if not FAB_ActionBarFakeQS then
        FAB_ActionBarFakeQS = GetControl("FAB_ActionBarFakeQS")
    end
    ACTION_BAR:SetWidth(style.width)
    ACTION_BAR:GetNamedChild("KeybindBG"):SetHidden(true)

    weaponSwapControl:ClearAnchors()
    weaponSwapControl:SetAnchor(LEFT, FAB_ActionBarFakeQS, RIGHT, 0, 0)
    if SV.useDefaultWeaponSwap then
        weaponSwapControl:SetAlpha(1)
        weaponSwapControl:SetMouseEnabled(true)
    else
        weaponSwapControl:SetAlpha(0)
        weaponSwapControl:SetMouseEnabled(false)
    end
end

--- Update visibility/state for our swap arrow or default swap control
--- @param lock boolean|nil optional, current lock state (defaults to current isWeaponSwapLocked)
function FancyActionBar.UpdateWeaponSwapControlVisibility(lock)
    lock = lock or isWeaponSwapLocked
    local useDefault = SV.useDefaultWeaponSwap
    local shouldShowDefault = useDefault and (not lock) and SV.showArrow

    if weaponSwapControl then
        weaponSwapControl:SetAlpha(shouldShowDefault and 1 or 0)
        weaponSwapControl:SetMouseEnabled(shouldShowDefault)
    end

    if useDefault then
        if FAB_ActionBarArrow then FAB_ActionBarArrow:SetHidden(true) end
    else
        if FAB_ActionBarArrow then
            FAB_ActionBarArrow:SetHidden(lock or not SV.showArrow)
            if SV.arrowColor then
                FAB_ActionBarArrow:SetColor(unpack(SV.arrowColor))
            end
        end
    end
end

--- Chain active and backbar slot rows from weapon swap.
--- @param style table
function FancyActionBar.SetupButtons(style)
    local lastButton = nil
    for i = MIN_INDEX, MAX_INDEX do
        local button = ZO_ActionBar_GetButton(i)
        if lastButton then
            button:ApplyAnchor(lastButton.slot, FancyActionBar.constants.abilitySlot.offsetX)
        else
            button.slot:ClearAnchors()
            button.slot:SetAnchor(BOTTOMLEFT, weaponSwapControl, RIGHT, 0, -4)
        end
        lastButton = button
    end
    lastButton = nil
    for i = MIN_INDEX, MAX_INDEX do
        local button = FancyActionBar.buttons[i + SLOT_INDEX_OFFSET]
        if i == MIN_INDEX then
            button.slot:ClearAnchors()
            button.slot:SetAnchor(TOPLEFT, weaponSwapControl, RIGHT, 0, 0)
        else
            button:ApplyAnchor(lastButton.slot, FancyActionBar.constants.abilitySlot.offsetX)
        end
        lastButton = button
    end
end

--- Setup the button text.
--- @param button {buttonText:LabelControl}
--- @param style table
--- @param index number
function FancyActionBar.SetupButtonText(button, style, index)
    local c = FancyActionBar.constants
    local overlayOffsetX = (index - MIN_INDEX) * (style.abilitySlotWidth + c.abilitySlot.offsetX)
    local barYOffset = SV.hideLockedBar and SV.repositionActiveBar and isWeaponSwapLocked and (style.dimensions + style.buttonTextOffsetY) / 3 or
        style.buttonTextOffsetY + c.layout.bar.halfY
    button.buttonText:ClearAnchors()
    button.buttonText:SetAnchor(CENTER, weaponSwapControl, RIGHT, (overlayOffsetX + style.abilitySlotWidth / 2), barYOffset)
    button.buttonText:SetHidden(not SV.showHotkeys)
end

--- Setup the button status.
--- @param button {status:TextureControl}
function FancyActionBar.SetupButtonStatus(button)
    if highlights.regular.toggled or highlights.regular.show then
        button.status:SetTexture("FancyActionBar+/texture/blank.dds")
    else
        button.status:SetTexture("EsoUI/Art/ActionBar/ActionSlot_toggledon.dds")
    end
end

--- Create FAB_ActionBar, overlays, and style backbar buttons.
--- @param style table
function FancyActionBar.SetupOverlays(style)
    if not GetControl("FAB_ActionBar") then
        WM:CreateControlFromVirtual("FAB_ActionBar", ACTION_BAR, "FAB_ActionBar")
    end
    for i = MIN_INDEX, MAX_INDEX do
        FancyActionBar.CreateOverlay(i)
        FancyActionBar.CreateOverlay(i + SLOT_INDEX_OFFSET)
        local frontBtn = ZO_ActionBar_GetButton(i)
        if frontBtn and frontBtn.slot and FancyActionBar.overlays[i] then
            AnchorOverlayToSlot(FancyActionBar.overlays[i], frontBtn.slot)
        end
        local button = FancyActionBar.buttons[i + SLOT_INDEX_OFFSET]
        if button and button.slot and FancyActionBar.overlays[i + SLOT_INDEX_OFFSET] then
            AnchorOverlayToSlot(FancyActionBar.overlays[i + SLOT_INDEX_OFFSET], button.slot)
        end
        button:ApplyStyle(style.buttonTemplate)
        FancyActionBar.SetupBackbarDragDropHandlers(button)
        FancyActionBar.SetupButtonStatus(button)
    end
    SetupUltAndQuickslotOverlays()
end

---
--- @param active userdata
--- @param inactive userdata
--- @param firstTop boolean
--- @param locked boolean
local function ApplyBarPosition(active, inactive, firstTop, locked)
    local bar = FancyActionBar.constants.scaled.bar
    local barYOffset = bar.y
    local barXOffset = bar.x
    if locked and SV.repositionActiveBar then
        if active then
            active:SetAnchor(LEFT, weaponSwapControl, RIGHT, 0, 0, active:GetResizeToFitConstrains())
        end
        if inactive then
            inactive:SetAnchor(LEFT, weaponSwapControl, RIGHT, 0, 0, inactive:GetResizeToFitConstrains())
        end
    elseif firstTop then
        if active then
            active:SetAnchor(BOTTOMLEFT, weaponSwapControl, RIGHT, 0 - barXOffset,
                -2 - barYOffset, active:GetResizeToFitConstrains())
        end
        if inactive then
            inactive:SetAnchor(TOPLEFT, weaponSwapControl, RIGHT, 0 + barXOffset,
                2 + barYOffset, inactive:GetResizeToFitConstrains())
        end
    else
        if active then
            active:SetAnchor(TOPLEFT, weaponSwapControl, RIGHT, 0 + barXOffset,
                2 + barYOffset, active:GetResizeToFitConstrains())
        end
        if inactive then
            inactive:SetAnchor(BOTTOMLEFT, weaponSwapControl, RIGHT, 0 - barXOffset,
                -2 - barYOffset, inactive:GetResizeToFitConstrains())
        end
    end
end

local function UpdateWeaponSwapTransformOffset()
    if weaponSwapControl and weaponSwapControl.SetTransformOffsetY then
        if (not SV.useDefaultWeaponSwap) or SV.centerDefaultWeaponSwap then
            weaponSwapControl:SetTransformOffsetY(0)
        else
            local anchorButton = ZO_ActionBar_GetButton(MIN_INDEX)
            local anchorControl = (anchorButton and anchorButton.slot) or _G["ActionButton3"] or ACTION_BAR
            local _, ay = 0, 0
            if anchorControl and anchorControl.GetCenter then
                _, ay = anchorControl:GetCenter()
            end
            local sx, sy = 0, 0
            if weaponSwapControl and weaponSwapControl.GetCenter then
                sx, sy = weaponSwapControl:GetCenter()
            end
            if ay and sy then
                weaponSwapControl:SetTransformOffsetY(ay - sy)
            else
                weaponSwapControl:SetTransformOffsetY(0)
            end
        end
    end
end

local function syncActionButton(button, hotbarCategory, overlay)
    if not button then
        return
    end
    button.hotbarSwapAnimation = nil
    button.showTimer = false
    if button.stackCountText then button.stackCountText:SetHidden(true) end
    if button.timerText then button.timerText:SetHidden(true) end
    if button.timerOverlay then button.timerOverlay:SetHidden(true) end
    button:HandleSlotChanged(hotbarCategory)
    if overlay and button.slot then
        AnchorOverlayToSlot(overlay, button.slot)
    end
    if button.buttonText then
        button.buttonText:SetHidden(not SV.showHotkeys)
    end
end

--------------------------------------------------------------------------------
-- Hotbar slot sync and presentation (dependency order: sync → paint → timers → lock)
--------------------------------------------------------------------------------

local function syncInactiveSlotButton(slotNum, hotbarCategory)
    local altbutton = ZO_ActionBar_GetButton(slotNum, hotbarCategory)
    if altbutton then
        altbutton.noUpdates = true
        altbutton.showBackRowSlot = false
        syncActionButton(altbutton, hotbarCategory)
    end
    local dataIndex = GetOverlayIndex(slotNum, hotbarCategory)
    local physicalIndex = GetPhysicalOverlayIndexForData(dataIndex, GetActiveHotbarCategory())
    if IsPhysicalBackRow(physicalIndex) then
        local fabButton = FancyActionBar.GetActionButton(physicalIndex)
        if fabButton then
            fabButton.noUpdates = true
            local overlay = slotNum == ULT_INDEX
                and FancyActionBar.ultOverlays[ULT_INDEX + SLOT_INDEX_OFFSET]
                or FancyActionBar.overlays[physicalIndex]
            syncActionButton(fabButton, hotbarCategory, overlay)
        end
    end
end

function FancyActionBar.RefreshActiveBarSlots(hotbar, cleanup)
    hotbar = hotbar or GetActiveHotbarCategory()
    for i = MIN_INDEX, MAX_INDEX do
        syncActionButton(ZO_ActionBar_GetButton(i), hotbar, FancyActionBar.overlays[i])
    end
    local ult = ZO_ActionBar_GetButton(ULT_INDEX, hotbar)
    if ult then
        ult.showTimer = false
        ult:HandleSlotChanged(hotbar)
        local ultOverlay = FancyActionBar.ultOverlays[ULT_INDEX]
        if ultOverlay and ult.slot then
            AnchorOverlayToSlot(ultOverlay, ult.slot)
        end
        if ult.buttonText then
            local isFakeGamepadMode = SV.forceGamepadStyle and not IsInGamepadPreferredMode()
            local hideUltimateButtonText = (not SV.showHotkeys) or (FancyActionBar.style ~= 1 and not isFakeGamepadMode)
            ult.buttonText:SetHidden(hideUltimateButtonText)
        end
        ult:ApplySwapAnimationStyle()
        if not cleanup and ult.hasAction then
            ult:UpdateUltimateMeter()
        end
    end
end

local function refreshBackupBarButtons()
    local hotbar = GetActiveHotbarCategory()
    if hotbar ~= HOTBAR_CATEGORY_PRIMARY and hotbar ~= HOTBAR_CATEGORY_BACKUP then
        hotbar = HOTBAR_CATEGORY_PRIMARY
    end
    local altCategory = hotbar == HOTBAR_CATEGORY_PRIMARY and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    for i = MIN_INDEX, MAX_INDEX do
        syncInactiveSlotButton(i, altCategory)
    end
    syncInactiveSlotButton(ULT_INDEX, altCategory)
end

local function syncAllHotbarSlots()
    FancyActionBar.RefreshActiveBarSlots(nil, true)
    refreshBackupBarButtons()
end

local function tickOverlayTimers(currentTime, activeHotbar)
    activeHotbar = activeHotbar or layoutHotbarCategory
    local inactiveHotbar = GetInactiveHotbarCategory(activeHotbar)
    for i = MIN_INDEX, ULT_INDEX do
        FancyActionBar.UpdateOverlay(i, currentTime, activeHotbar, inactiveHotbar)
        FancyActionBar.UpdateOverlay(i + SLOT_INDEX_OFFSET, currentTime, activeHotbar, inactiveHotbar)
    end
end

function FancyActionBar.SyncSpecialHotbarState(activeHotbarCategory, reconcileSlotEffects)
    if reconcileSlotEffects then
        FancyActionBar.SlotEffects()
        FancyActionBar.SyncEffectState("slotted")
    end
    syncAllHotbarSlots()
    FancyActionBar.RefreshHotbarPresentation(activeHotbarCategory, false)
    tickOverlayTimers(time(), (activeHotbarCategory == HOTBAR_CATEGORY_PRIMARY or activeHotbarCategory == HOTBAR_CATEGORY_BACKUP) and activeHotbarCategory or layoutHotbarCategory)
end

function FancyActionBar.RefreshHotbarPresentation(activeHotbar, syncSlots)
    activeHotbar = activeHotbar or GetActiveHotbarCategory()
    if syncSlots then
        FancyActionBar.RefreshActiveBarSlots(activeHotbar)
    end
    FancyActionBar.PaintAbilityOverlays(nil, activeHotbar)
end

function FancyActionBar.ResetActiveBarSkillStyles()
    FancyActionBar.RefreshHotbarPresentation(GetActiveHotbarCategory(), true)
end

function FancyActionBar.ClearAnchors()
    local frontSlot = GetFrontBarRootSlot()
    if frontSlot then
        frontSlot:ClearAnchors()
    end
    local backSlot = GetBackbarRootSlot()
    if backSlot then
        backSlot:ClearAnchors()
    end
end

function FancyActionBar.ApplyBarStackLayout(locked, activeHotbar)
    activeHotbar = activeHotbar or GetActiveHotbarCategory()
    local frontRoot = GetFrontBarRootSlot()
    local backRoot = GetBackbarRootSlot()
    local currentHotbarCategory = activeHotbar
    if currentHotbarCategory == HOTBAR_CATEGORY_BACKUP then
        if SV.staticBars then
            ApplyBarPosition(backRoot, frontRoot, SV.frontBarTop, locked)
        else
            ApplyBarPosition(frontRoot, backRoot, SV.activeBarTop, locked)
        end
        return
    end
    if SV.staticBars then
        ApplyBarPosition(frontRoot, backRoot, SV.frontBarTop, locked)
    else
        ApplyBarPosition(frontRoot, backRoot, SV.activeBarTop, locked)
    end
end

local function applyActiveBarButtonStyles()
    local style = FancyActionBar.constants.style
    for i = MIN_INDEX, MAX_INDEX do
        local button = ZO_ActionBar_GetButton(i)
        button:ApplyStyle(style.buttonTemplate)
        FancyActionBar.SetupButtonText(button, style, i)
        FancyActionBar.SetupButtonStatus(button)
    end
    applyUltimateStyle(style)
end

function FancyActionBar.ApplyActiveHotbarGeometry(activeHotbar, locked)
    activeHotbar = activeHotbar or GetActiveHotbarCategory()
    FancyActionBar.ClearAnchors()
    FancyActionBar.ApplyBarStackLayout(locked, activeHotbar)

    for slot = MIN_INDEX, MAX_INDEX do
        local frontOverlay = FancyActionBar.overlays[slot]
        if frontOverlay then
            frontOverlay:SetHidden(false)
        end
        applyInactiveSlotVisibility(slot, activeHotbar)
    end
    local frontUlt = FancyActionBar.ultOverlays[ULT_INDEX]
    if frontUlt then
        frontUlt:SetHidden(false)
    end
    applyInactiveSlotVisibility(ULT_INDEX, activeHotbar)

    UpdateWeaponSwapTransformOffset()
    FancyActionBar.UpdateBackbarButtonActionIds(nil, activeHotbar)
    FancyActionBar.UpdateWeaponSwapControlVisibility(locked)
    if activeHotbar ~= HOTBAR_CATEGORY_PRIMARY and activeHotbar ~= HOTBAR_CATEGORY_BACKUP then
        layoutHotbarCategory = HOTBAR_CATEGORY_PRIMARY
    else
        layoutHotbarCategory = activeHotbar
    end
end

function FancyActionBar.ApplyPosition() -- check if action bar should be moved.
    FancyActionBar.HideHotkeys(not SV.showHotkeys)
    if not SV.forceAzurahMover then
        FancyActionBar.MoveActionBar()
        if SV.forceReposition or not FancyActionBar.wasMoved then
            FancyActionBar.RepositionElements()
        end
    end
end

function FancyActionBar.RefreshBarPosition(refreshLayout)
    if refreshLayout and not FancyActionBar.IsUnlocked() then
        FancyActionBar.SetupButtons(FancyActionBar.constants.style)
        FancyActionBar.ApplyActiveHotbarGeometry(nil, isWeaponSwapLocked)
    end
    FancyActionBar:AdjustControlsPositions()
    FancyActionBar:ApplyPosition()
end

function FancyActionBar.RefreshActiveBarStyles()
    applyActiveBarButtonStyles()
    FancyActionBar.RefreshActiveBarSlots()
end

function FancyActionBar.UpdateBarSettings(locked, opts)
    opts = opts or {}
    locked = locked ~= nil and locked or isWeaponSwapLocked

    FancyActionBar.ApplyBarFoundation()

    local style = FancyActionBar.constants.style
    FancyActionBar.SetupActionBar(style)
    FancyActionBar.SetupButtons(style)
    FancyActionBar.SetupOverlays(style)
    if opts.skipSlots then
        applyActiveBarButtonStyles()
    else
        FancyActionBar.RefreshActiveBarStyles()
    end
    FancyActionBar:ApplySettings()
    FancyActionBar.RefreshBounceAnimations()
    FancyActionBar.ApplyActiveHotbarGeometry(opts.activeHotbar, locked)
    FancyActionBar.AdjustQuickSlotSpacing(locked)
    positionUltimateSlots()
    FancyActionBar:AdjustControlsPositions()
    FancyActionBar:ApplyPosition()
    if not opts.skipSlots then
        FancyActionBar.RefreshHotbarPresentation(nil, false)
    end
end

function FancyActionBar.RefreshAdjacentSlots(locked)
    locked = locked ~= nil and locked or isWeaponSwapLocked
    FancyActionBar.AdjustQuickSlotSpacing(locked)
    positionUltimateSlots()
end

local function applyWeaponLockPresentation(locked)
    if isWeaponSwapLocked == locked then
        return
    end
    isWeaponSwapLocked = locked
    FancyActionBar.ApplyActiveHotbarGeometry(nil, locked)
    FancyActionBar.RefreshAdjacentSlots(locked)
    FancyActionBar.RefreshHotbarPresentation(nil, true)
end

function FancyActionBar.OnWeaponSwapLocked(isLocked, wasLocked, userPreferenceChanged, userPreferenceState)
    if (not SV.hideLockedBar) and (not userPreferenceChanged) then
        return
    end
    local doLock
    if userPreferenceChanged then
        doLock = userPreferenceState and isLocked or false
    else
        wasLocked = wasLocked ~= nil and wasLocked or isWeaponSwapLocked
        if isLocked == wasLocked then
            return
        end
        doLock = isLocked
    end
    applyWeaponLockPresentation(doLock)
end

--- Resolve UI mode constants and scale once before structure/layout/appearance.
function FancyActionBar.ApplyBarFoundation()
    FancyActionBar.UpdateStyle()
    FancyActionBar.SetScale()
end

function FancyActionBar.RefreshSlottedAbilityConfigurations()
    local refreshedIds = {}

    for slot = MIN_INDEX, ULT_INDEX do
        local frontAbilityId = FancyActionBar.GetSlotBoundAbilityId(slot, HOTBAR_CATEGORY_PRIMARY)
        local backAbilityId = FancyActionBar.GetSlotBoundAbilityId(slot, HOTBAR_CATEGORY_BACKUP)

        if frontAbilityId and frontAbilityId ~= 0 and not refreshedIds[frontAbilityId] then
            refreshedIds[frontAbilityId] = true
            FancyActionBar.SlotCurrentAbilityConfiguration(frontAbilityId)
        end

        if backAbilityId and backAbilityId ~= 0 and not refreshedIds[backAbilityId] then
            refreshedIds[backAbilityId] = true
            FancyActionBar.SlotCurrentAbilityConfiguration(backAbilityId)
        end
    end
end

function FancyActionBar.RefreshAfterPresetApply(abilityDataApplied)
    FancyActionBar.useGamepadActionBar = IsInGamepadPreferredMode() or SV.forceGamepadStyle
    FancyActionBar.RefreshHighlightConfiguration()
    FancyActionBar.UpdateDurationLimits()
    debug = SV.debug

    if abilityDataApplied then
        FancyActionBar.BuildAbilityConfig()
        FancyActionBar.SetExternalBuffTracking()
    end

    FancyActionBar.UpdateBarSettings(isWeaponSwapLocked, { skipSlots = true })
    FancyActionBar.RefreshActiveBarSlots()
    FancyActionBar.SlotEffects()
    FancyActionBar.SyncEffectState("slotted")
    FancyActionBar.RefreshHotbarPresentation(nil, false)

    if abilityDataApplied then
        FancyActionBar.RefreshSlottedAbilityConfigurations()
        FancyActionBar.RefreshEffectWidgets()
    end
    FancyActionBar.ToggleUltimateValue()
    FancyActionBar.SetUltFrameAlpha()
    FancyActionBar.ApplyDeathStateOption()
end

function FancyActionBar.OnUIModeChanged()
    FancyActionBar.useGamepadActionBar = IsInGamepadPreferredMode() or SV.forceGamepadStyle
    FancyActionBar.UpdateBarSettings(isWeaponSwapLocked, { skipSlots = true })
    FancyActionBar.RefreshActiveBarSlots()
    FancyActionBar.SlotEffects()
    FancyActionBar.SyncEffectState("slotted")
    FancyActionBar.RefreshHotbarPresentation(nil, false)
end

--------------------------------------------------------------------------------
-------------------------------[    Hooks   ]-----------------------------------
--------------------------------------------------------------------------------
local function ApplySwapAnimationStyle(button)
    local constants = FancyActionBar.constants
    local timeline = button.hotbarSwapAnimation
    local isUltimateSlot = button.GetSlot and ZO_ActionBar_IsUltimateSlot(button:GetSlot(), button:GetHotbarCategory())
    local swapSize = isUltimateSlot and constants.style.ultFlipCardSize or constants.style.flipCardSize

    if timeline then
        local firstAnimation = timeline:GetFirstAnimation()
        local lastAnimation = timeline:GetLastAnimation()

        firstAnimation:SetStartAndEndWidth(swapSize, swapSize)
        firstAnimation:SetStartAndEndHeight(swapSize, 0)
        lastAnimation:SetStartAndEndWidth(swapSize, swapSize)
        lastAnimation:SetStartAndEndHeight(0, swapSize)
    end
end

local function FancyHideKeys(self, hide)
    if not SV.showHotkeysUltGP then
        hide = true
    end
    if self.leftKey then
        self.leftKey:SetHidden(hide)
    end
    if self.rightKey then
        self.rightKey:SetHidden(hide)
    end
end

local function FancySetShowBindingText(self, visible)
    if not SV.showHotkeys then
        visible = false
    end
    if not self.buttonText then
        return
    end
    self.buttonText:SetHidden(not visible)
end

local function FancySetUltimateMeter(self, ultimateCount, setProgressNoAnim)
    -- Seems to fix issues with basegame ult glow animation desync
    if self.UpdateCurrentUltimateMax then self:UpdateCurrentUltimateMax() end

    if self.GetUltimateCount then
        local actual = self:GetUltimateCount()
        if actual then ultimateCount = actual end
    end

    local isSlotUsed = IsSlotUsed(ULT_INDEX, self.slot.hotbarCategory)
    local barTexture = GetControl(self.slot, "UltimateBar")
    local leadingEdge = GetControl(self.slot, "LeadingEdge")
    local ultimateReadyBurstTexture = GetControl(self.slot, "ReadyBurst")
    local ultimateReadyLoopTexture = GetControl(self.slot, "ReadyLoop")
    local ultimateFillLeftTexture = GetControl(self.slot, "FillAnimationLeft")
    local ultimateFillRightTexture = GetControl(self.slot, "FillAnimationRight")
    local ultimateFillFrame = GetControl(self.slot, "Frame")

    local constants = FancyActionBar.constants
    local isGamepad = constants.mode == 2

    if isSlotUsed then
        -- Show fill bar if platform appropriate
        ultimateFillFrame:SetHidden(not isGamepad)
        ultimateFillLeftTexture:SetHidden(not isGamepad)
        ultimateFillRightTexture:SetHidden(not isGamepad)

        -- Only consider ready state when we have a positive max
        local max = self.currentUltimateMax or 0
        if max > 0 and ultimateCount >= max then
            -- hide progress bar
            barTexture:SetHidden(true)
            leadingEdge:SetHidden(true)

            -- Set fill bar to full and play ready animations
            self:PlayUltimateFillAnimation(ultimateFillLeftTexture, ultimateFillRightTexture, 1, setProgressNoAnim)
            self:PlayUltimateReadyAnimations(ultimateReadyBurstTexture, ultimateReadyLoopTexture, setProgressNoAnim)
        else
            -- stop ready animation
            ultimateReadyBurstTexture:SetHidden(true)
            ultimateReadyLoopTexture:SetHidden(true)
            self:StopUltimateReadyAnimations()

            -- show platform appropriate progress bar
            barTexture:SetHidden(isGamepad)
            leadingEdge:SetHidden(isGamepad)

            if max > 0 then
                local style = constants.style
                local slotHeight = style.ultFlipCardSize or style.ultSize or self.slot:GetHeight()
                local percentComplete = zo_clamp(ultimateCount / max, 0, 1)
                local yOffset = zo_floor(slotHeight * (0.97 - percentComplete))
                barTexture:SetHeight(yOffset)

                leadingEdge:ClearAnchors()
                leadingEdge:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, yOffset - 5)
                leadingEdge:SetAnchor(TOPRIGHT, nil, TOPRIGHT, 0, yOffset - 5)

                self:PlayUltimateFillAnimation(ultimateFillLeftTexture, ultimateFillRightTexture, percentComplete, setProgressNoAnim)
            else
                -- no valid max: hide progress visuals
                barTexture:SetHidden(true)
                leadingEdge:SetHidden(true)
                ultimateFillLeftTexture:SetHidden(true)
                ultimateFillRightTexture:SetHidden(true)
                ultimateFillFrame:SetHidden(true)
            end

            self:AnchorKeysOut()
        end

        self:UpdateUltimateNumber()
    else
        -- stop animation
        ultimateReadyBurstTexture:SetHidden(true)
        ultimateReadyLoopTexture:SetHidden(true)
        self:StopUltimateReadyAnimations()

        barTexture:SetHidden(true)
        leadingEdge:SetHidden(true)
        ultimateFillLeftTexture:SetHidden(true)
        ultimateFillRightTexture:SetHidden(true)
        ultimateFillFrame:SetHidden(true)
        self:AnchorKeysOut()
    end
end

local SHRINK_SCALE = 0.9
local ICON_SHRINK_SCALE = 0.8
local GROW_SCALE = 1.1
local FRAME_RESET_TIME_MS = 167
local ICON_RESET_TIME_MS = 100

local function SetAnimationParameters(timeline, control, shrinkScale, resetTime, isUltimateSlot)
    local style = FancyActionBar.constants.style
    local shrink = timeline:GetAnimation(1)
    local grow = timeline:GetAnimation(2)
    local reset = timeline:GetAnimation(3)
    local size = isUltimateSlot and style.ultFlipCardSize or style.flipCardSize

    shrink:SetStartAndEndWidth(size, size * shrinkScale)
    shrink:SetStartAndEndHeight(size, size * shrinkScale)

    grow:SetStartAndEndWidth(size * shrinkScale, size * GROW_SCALE)
    grow:SetStartAndEndHeight(size * shrinkScale, size * GROW_SCALE)

    reset:SetStartAndEndWidth(size * GROW_SCALE, size)
    reset:SetStartAndEndHeight(size * GROW_SCALE, size)
    reset:SetDuration(resetTime)
end

local PRESS_BOUNCE_VIRTUAL = "FAB_ActionSlotPressAnimation"
local RELEASE_BOUNCE_VIRTUAL = "FAB_ActionSlotReleaseAnimation"
local pressBounceByButton = {}

local function IsKeyboardPressBounceEnabled()
    return SV.keyboardBounceAnimation and not SV.forceGamepadStyle and not IsInGamepadPreferredMode()
end

local function GetBounceControls(button)
    return button.flipCard or button.slot:GetNamedChild("FlipCard"),
        button.icon or button.slot:GetNamedChild("Icon")
end

local function GetBounceConfiguredSize(button)
    local style = FancyActionBar.constants.style
    local isUltimateSlot = button.GetSlot and ZO_ActionBar_IsUltimateSlot(button:GetSlot(), button:GetHotbarCategory())
    return isUltimateSlot and style.ultFlipCardSize or style.flipCardSize
end

local function SetPressReleaseBounceParams(pressTimeline, releaseTimeline, size, shrinkScale, resetTime)
    local shrink = pressTimeline:GetAnimation(1)
    shrink:SetStartAndEndWidth(size, size * shrinkScale)
    shrink:SetStartAndEndHeight(size, size * shrinkScale)
    local grow = releaseTimeline:GetAnimation(1)
    local reset = releaseTimeline:GetAnimation(2)
    grow:SetStartAndEndWidth(size * shrinkScale, size * GROW_SCALE)
    grow:SetStartAndEndHeight(size * shrinkScale, size * GROW_SCALE)
    reset:SetStartAndEndWidth(size * GROW_SCALE, size)
    reset:SetStartAndEndHeight(size * GROW_SCALE, size)
    reset:SetDuration(resetTime)
end

local function BounceSize(button, data)
    return (data and data.restSize) or GetBounceConfiguredSize(button)
end

local function ResetBounceControls(flipCard, icon, size)
    if flipCard then
        flipCard:SetDimensions(size, size)
    end
    if icon then
        icon:ClearDimensions()
    end
end

local function InvalidatePressBounceData(button)
    local data = pressBounceByButton[button]
    if not data then
        return
    end
    data.framePress:Stop()
    data.frameRelease:Stop()
    ResetBounceControls(data.flipCard, data.icon, BounceSize(button, data))
    pressBounceByButton[button] = nil
end

local function EnsurePressBounceData(button)
    local flipCard, icon = GetBounceControls(button)
    local data = pressBounceByButton[button]
    if data and (data.flipCard ~= flipCard or data.icon ~= icon) then
        InvalidatePressBounceData(button)
        data = nil
    end
    if not data then
        data =
        {
            flipCard = flipCard,
            icon = icon,
            framePress = ANIMATION_MANAGER:CreateTimelineFromVirtual(PRESS_BOUNCE_VIRTUAL, flipCard),
            frameRelease = ANIMATION_MANAGER:CreateTimelineFromVirtual(RELEASE_BOUNCE_VIRTUAL, flipCard),
        }
        pressBounceByButton[button] = data
    end
    SetPressReleaseBounceParams(data.framePress, data.frameRelease, BounceSize(button, data), SHRINK_SCALE, FRAME_RESET_TIME_MS)
    return data
end

function FancyActionBar.ClearPressBounceAnimations()
    for button in pairs(pressBounceByButton) do
        InvalidatePressBounceData(button)
    end
end

local function PlayPressBounce(button)
    if not IsKeyboardPressBounceEnabled() or button:GetSlot() < MIN_INDEX or button:GetSlot() > MAX_INDEX then
        return
    end
    local data = EnsurePressBounceData(button)
    data.framePress:Stop()
    data.frameRelease:Stop()
    data.restSize = GetBounceConfiguredSize(button)
    ResetBounceControls(data.flipCard, data.icon, data.restSize)
    SetPressReleaseBounceParams(data.framePress, data.frameRelease, data.restSize, SHRINK_SCALE, FRAME_RESET_TIME_MS)
    data.framePress:PlayFromStart()
end

local function PlayReleaseBounce(button)
    if not IsKeyboardPressBounceEnabled() or button:GetSlot() < MIN_INDEX or button:GetSlot() > MAX_INDEX then
        return
    end
    local data = pressBounceByButton[button]
    if not data then
        return
    end
    data.frameRelease:Stop()
    SetPressReleaseBounceParams(data.framePress, data.frameRelease, BounceSize(button, data), SHRINK_SCALE, FRAME_RESET_TIME_MS)
    if data.framePress:IsPlaying() then
        data.framePress:PlayInstantlyToEnd(true)
    end
    data.frameRelease:PlayFromStart()
end

local function OnActionButtonPress(slotNum, hotbarCategory, release)
    if not IsKeyboardPressBounceEnabled() or slotNum < MIN_INDEX or slotNum > MAX_INDEX then
        return
    end
    local button = ZO_ActionBar_GetButton(slotNum, hotbarCategory)
    if button then
        if release then
            PlayReleaseBounce(button)
        else
            PlayPressBounce(button)
        end
    end
end

local actionButtonHooksInstalled = false
local function InstallActionButtonHooks()
    if actionButtonHooksInstalled then
        return
    end
    actionButtonHooksInstalled = true

    ActionButton["HideKeys"] = FancyHideKeys
    ActionButton["SetShowBindingText"] = FancySetShowBindingText
    ActionButton["SetUltimateMeter"] = FancySetUltimateMeter

    SecurePostHook(ActionButton, "ApplyStyle", function (self)
        local style = FancyActionBar.constants.style
        ApplyTemplateToControl(self.slot, self.ultimateReadyBurstTimeline and style.ultButtonTemplate or style.buttonTemplate)
        InvalidatePressBounceData(self)
        local slot = GetActiveBarButtonContext(self)
        if slot and slot >= MIN_INDEX and slot <= MAX_INDEX then
            FancyActionBar.SetupButtonText(self, style, slot)
        end
        if self:GetHotbarCategory() == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
            FancyActionBar.ApplyQuickSlotFont()
        end
    end)

    ZO_PreHook(ActionButton, "UpdateState", function (self)
        if GetActiveBarButtonContext(self) and self.slot then
            self.slot.hotbarCategory = GetActiveHotbarCategory()
        end
    end)
    ZO_PreHook(ActionButton, "UpdateUsable", function (self)
        if not GetActiveBarButtonContext(self) then
            return
        end
        if self.UpdateUseFailure then
            self:UpdateUseFailure()
        end
    end)
    SecurePostHook(ActionButton, "UpdateUsable", OnActiveActionButtonVisualUpdate)

    ZO_PostHook("ZO_ActionBar_OnActionButtonDown", function (slotNum, hotbarCategory)
        OnActionButtonPress(slotNum, hotbarCategory, false)
    end)
    ZO_PostHook("ZO_ActionBar_OnActionButtonUp", function (slotNum, hotbarCategory)
        OnActionButtonPress(slotNum, hotbarCategory, true)
    end)
end

local origSetBounceAnimationParameters = ActionButton["SetBounceAnimationParameters"]
local function FancySetBounceAnimationParameters(self, cooldownTime)
    local isUltimateSlot = ZO_ActionBar_IsUltimateSlot(self:GetSlot(), self:GetHotbarCategory())
    SetAnimationParameters(self.bounceAnimation, self.flipCard, SHRINK_SCALE, FRAME_RESET_TIME_MS, isUltimateSlot)
    SetAnimationParameters(self.iconBounceAnimation, self.icon, ICON_SHRINK_SCALE, ICON_RESET_TIME_MS, isUltimateSlot)
end

function FancyActionBar.RefreshBounceAnimations()
    if IsKeyboardPressBounceEnabled() then
        for i = MIN_INDEX, MAX_INDEX do
            EnsurePressBounceData(ZO_ActionBar_GetButton(i))
        end
        return
    end

    FancyActionBar.ClearPressBounceAnimations()

    if not SV.forceGamepadStyle and FancyActionBar.constants.mode == 1 then
        return
    end

    for i = MIN_INDEX, MAX_INDEX do
        local button = ZO_ActionBar_GetButton(i)
        button:SetupBounceAnimation()
        button:SetBounceAnimationParameters()
    end

    for i = MIN_INDEX + SLOT_INDEX_OFFSET, MAX_INDEX + SLOT_INDEX_OFFSET do
        local button = FancyActionBar.buttons[i]
        button:SetupBounceAnimation()
        button:SetBounceAnimationParameters()
    end
end

function FancyActionBar.GetUIMode()
    if ADCUI then
        if ADCUI:originalIsInGamepadPreferredMode() or SV.forceGamepadStyle then
            if ADCUI:shouldUseGamepadUI() or SV.forceGamepadStyle then
                return 2
            end
            return ADCUI:shouldUseGamepadActionBar() or SV.forceGamepadStyle and 2 or 1
        end
        return 1
    end

    return (IsInGamepadPreferredMode() or SV.forceGamepadStyle) and 2 or 1
end

function FancyActionBar.UpdateStyle()
    local mode = FancyActionBar.GetUIMode()
    local style = mode == 1 and FancyActionBar.keyboardConstants or FancyActionBar.gamepadConstants

    FancyActionBar.style = mode
    FancyActionBar.constants = FancyActionBar.UpdateConstants(mode, SV, style)
    hideUltimateNumberIfNeeded()
    scale = GetEffectiveBarScale()
    FancyActionBar.ApplyScaleToLayout(scale)

    FAB_Default_Bar_Position:ClearAnchors()
    FAB_Default_Bar_Position:SetAnchor(BOTTOM, GuiRoot, BOTTOM, FancyActionBar.constants.move.x, FancyActionBar.constants.move.y)

    ActionButton.ApplySwapAnimationStyle = ApplySwapAnimationStyle
    ActionButton.SetBounceAnimationParameters = SV.forceGamepadStyle and FancySetBounceAnimationParameters or origSetBounceAnimationParameters
    ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1):ApplySwapAnimationStyle()
end

-------------------------------------------------------------------------------
-----------------------------[  Helper & Debugging  ]--------------------------
-------------------------------------------------------------------------------
function FancyActionBar.IdentifyIndex(number, bar) -- public data-index API; internal callers use GetOverlayIndex
    return GetOverlayIndex(number, bar)
end

function FancyActionBar.IdCheck(_index, id)
    local cfg = abilityConfig[id]
    if cfg == false then
        return false
    end

    local craftedId = GetAbilityCraftedAbilityId(id)
    if craftedId ~= 0 and type(cfg) == "table" then
        local scripts = { GetCraftedAbilityActiveScriptIds(craftedId) }
        local scriptKey = (scripts[1] or 0) .. "_" .. (scripts[2] or 0) .. "_" .. (scripts[3] or 0)
        local scriptCfg = cfg[2] and cfg[2][scriptKey]
        if scriptCfg and scriptCfg[1] == false then
            return false
        end
    end

    return true
end

function FancyActionBar.PostAllChanges(e, change, eSlot, eName, tag, gain, fade, stacks, icon, bType, eType, aType, seType, uName, unitId, aId, sType, timestamp)
    if FancyActionBar.ignore[aId] then
        return
    end
    -- if GetAbilityBuffType(aId) and GetAbilityBuffType(aId) ~= BUFF_TYPE_NONE then return end
    -- if aType == 0 then return end -- passives (annoying when bar swapping)

    if FancyActionBar.IsGroupUnit(tag) then
        if AreUnitsEqual("player", tag) then
            return
        end -- filter doubles from 'player' and players 'group' tags.
    end

    local types =
    {
        [EFFECT_RESULT_GAINED] = "Gained",
        [EFFECT_RESULT_FADED] = "Faded",
        [EFFECT_RESULT_UPDATED] = "Updated",
        [EFFECT_RESULT_FULL_REFRESH] = "Refreshed",
        [EFFECT_RESULT_TRANSFER] = "Transfered",
    }
    local ts = tostring
    local type = types[change] or "?"
    local dur, s
    local timestampStr = timestamp and strformat("%0.3f", timestamp) or "nil"


    if (fade and gain)
    then
        dur = strformat(" %0.1f", fade - gain) .. "s"
    else
        dur = 0
    end

    if stacks and stacks ~= 0
    then
        s = " x" .. ts(stacks) .. "."
    else
        s = "."
    end

    if not SV.debugVerbose then
        if change == EFFECT_RESULT_FADED then
            FancyActionBar.AddSystemMessage("[" .. timestampStr .. "] [" .. ts(aId) .. "] " .. ts(eName) .. ": " .. ts(type) .. " --> " .. ts(uName))
        else
            FancyActionBar.AddSystemMessage("[" .. timestampStr .. "] [" .. ts(aId) .. "] " .. ts(eName) .. ": " .. ts(type) .. " --> " .. ts(uName) .. ts(dur) .. ts(s))
        end
    else
        FancyActionBar.AddSystemMessage("[" .. timestampStr .. "] " .. ts(eName) .. " (" .. ts(aId) .. ")" .. "\nchange: " .. types[change] .. " || stacks: " .. ts(stacks) .. " || duration: " .. ts(dur) .. " || slot: " .. ts(eSlot) .. " || tag: " .. ts(tag) .. " || unit: " .. ts(uName) .. " || unitId: " .. ts(unitId) .. " || buffType: " .. ts(bType) .. " || effectType: " .. ts(eType) .. " || abilityType: " .. ts(aType) .. " || statusEffectType: " .. ts(seType) .. "\n===================")
    end
end

function FancyActionBar.ShouldTrackAsDebuff(id, tag)
    if not SV.advancedDebuff then
        return false
    end
    if id == 38791 then
        return false
    end -- ZoS seem to think that Stampede is a debuff and not a ground effect :S
    if tag then
        if AreUnitsEqual("player", tag) or FancyActionBar.IsGroupUnit(tag) or FancyActionBar.IsPlayerPet(tag) then
            return false
        end
    end
    return true
end

function FancyActionBar.HandleSpecialEffect(id, change, updateTime, beginTime, endTime, unitTag, stackCount, abilityType, unitId, effectSlot)
    local specialEffect = ZO_DeepTableCopy(FancyActionBar.specialEffects[id])
    if specialEffect.handler then
        if specialEffect.handler == "device" then
            FancyActionBar.HandleDevice(id, specialEffect, change, updateTime, beginTime, endTime)
        end
        return
    end

    local effect = FancyActionBar.effects[specialEffect.id]
        or FancyActionBar.GetEffect(specialEffect.id)
    FancyActionBar.UpdateSpecialEffect(effect, specialEffect, change, updateTime, beginTime, endTime, unitTag, stackCount, abilityType, unitId, effectSlot)
end

function FancyActionBar.UpdateSpecialEffect(effect, specialEffect, change, updateTime, beginTime, endTime, unitTag, stackCount, abilityType, unitId, effectSlot)
    if change == EFFECT_RESULT_FADED then
        FancyActionBar.HandleEffectFade(effect, specialEffect, updateTime, beginTime, endTime, unitTag, stackCount, abilityType, unitId, effectSlot)
        return
    end
    if change ~= EFFECT_RESULT_GAINED and change ~= EFFECT_RESULT_UPDATED then
        return
    end

    local duration = 0
    effect.beginTime = updateTime
    if specialEffect.altDuration and not SV.useSplitShalksTimers then
        duration = specialEffect.altDuration
    else
        duration = specialEffect.duration
    end

    effect.endTime = (specialEffect.setTime and (duration + updateTime)) or endTime

    for k, v in pairs(specialEffect) do
        if k ~= "stackId" and k ~= "stackSources" then
            effect[k] = v
        end
    end
    local stackSources = GetConfiguredStackSources(specialEffect)
    if #stackSources > 0 then
        effect.stackSources = stackSources
    elseif not effect.stackSources then
        effect.stackSources = FancyActionBar.emptyStackList
    end
    effect.stackOwnerId = FancyActionBar.GetStackOwnerId(effect.id)

    if specialEffect.stacks then
        FancyActionBar.SetStacks(effect.id, specialEffect.stacks, true)
    elseif #stackSources > 0 and stackCount then
        local sourceId = stackSources[1]
        if sourceId then
            FancyActionBar.SetStacks(effect.id, stackCount, true)
        end
    end

    if effect.hasActiveCast and not FancyActionBar.GetUnits(effect.id, "targets") then
        effect.beginTime = updateTime
    end

    if abilityType ~= ABILITY_TYPE_AREAEFFECT then
        local isMultiTargetValid = specialEffect.isMultiTarget and not SV.multiTargetBlacklist[effect.id] and GetAbilityTargetDescription(effect.id, nil, unitTag) ~= "Self" and not FancyActionBar.IsPlayerPet(unitTag)

        local isActiveCastValid = effect.hasActiveCast and unitId and unitId > 0
        if isMultiTargetValid or isActiveCastValid then
            local unitKey = FancyActionBar.ResolveUnitKey("targets", unitTag, unitId, effectSlot)
            FancyActionBar.RecordUnit(effect.id, effect, unitKey, updateTime, effect.beginTime, effect.endTime, "targets")
        end
    end
end

function FancyActionBar.HandleEffectFade(effect, specialEffect, updateTime, beginTime, endTime, unitTag, stackCount, abilityType, unitId, effectSlot)
    if effect.beginTime and (updateTime - effect.beginTime < 0.3) then
        return
    end

    -- Handle multi-target effects
    if specialEffect.isMultiTarget and FancyActionBar.GetUnits(effect.id, "targets") then
        local targetCount = FancyActionBar.HandleMultiTargetFade(effect.id, unitTag, unitId, effectSlot, updateTime)
        if targetCount >= 1 then
            return
        end
    end

    -- Check proc state compatibility
    if effect.hasProced and specialEffect.hasProced and effect.hasProced ~= specialEffect.hasProced then
        return
    end

    -- Handle special effect procs
    if FancyActionBar.specialEffectProcs[effect.id] then
        local success = FancyActionBar.UpdateEffectProcs(effect, specialEffect, EFFECT_RESULT_FADED, stackCount)
        if not success then
            -- If proc update fails, just update the end time
            effect.endTime = endTime
            return
        end
    end

    if effect.dontFade and effect.endTime and effect.endTime > updateTime then
        return
    end

    -- Update effect end time and trigger update
    effect.endTime = endTime
end

-- function to handle multi-target fade
function FancyActionBar.HandleMultiTargetFade(effectId, unitTag, unitId, effectSlot, currentTime)
    local targetData = FancyActionBar.GetUnits(effectId, "targets")
    if not targetData then return 0 end

    local unitKey = FancyActionBar.ResolveUnitKey("targets", unitTag, unitId, effectSlot)
    local activeTargets = FancyActionBar.RemoveUnit(effectId, unitKey, currentTime, "targets")

    return activeTargets
end

-- function to update effect procs
function FancyActionBar.UpdateEffectProcs(effect, specialEffect, change, stackCount)
    local procUpdates = FancyActionBar.specialEffectProcs[effect.id]
    if not procUpdates then return false end

    local procValues = procUpdates[effect.procs]
    if not procValues then return false end

    -- Update effect values from proc
    for key, value in pairs(procValues) do
        if key ~= "id" then
            effect[key] = value
        end
    end

    -- Handle stacks
    local stackSources = effect.stackSources
    if stackSources and #stackSources > 0 then
        local stackSourceId = stackSources[1]
        if effect.stacks then
            FancyActionBar.SetStacks(stackSourceId, effect.stacks, true)
        elseif stackCount then
            local nextStacks = stackCount
            if change == EFFECT_RESULT_FADED then
                nextStacks = zo_max((FancyActionBar.GetStacks(stackSourceId) or 0) - stackCount, 0)
            end
            FancyActionBar.SetStacks(stackSourceId, nextStacks, true)
        end
    end

    return true
end

function FancyActionBar.HandleDevice(id, specialEffect, change, updateTime, beginTime, endTime)
    local parentId = specialEffect.id
    local allowMulti = specialEffect.allowMulti
    local duration = specialEffect.duration or -1

    -- Ensure parent effect entry
    local parentEffect = FancyActionBar.effects[parentId]
    if not parentEffect then
        parentEffect = { id = parentId, instances = {} }
        FancyActionBar.effects[parentId] = parentEffect
    end
    parentEffect.instances = parentEffect.instances or {}
    local instances = parentEffect.instances

    if change == EFFECT_RESULT_GAINED then
        if not allowMulti and id ~= parentId then
            local existing = FancyActionBar.effects[id]
            if existing and existing.beginTime and (updateTime - existing.beginTime < 0.3) then
                return
            end
        end

        local instance =
        {
            id = id,
            beginTime = beginTime,
            endTime = endTime,
            isDevice = not allowMulti,
        }

        if allowMulti then
            tableInsert(instances, instance)
        else
            FancyActionBar.effects[id] = instance
            instances[id] = instance
        end
    elseif change == EFFECT_RESULT_FADED then
        if not allowMulti then
            local inst = FancyActionBar.effects[id]
            if inst and inst.beginTime and (updateTime - inst.beginTime < 0.3) then
                return -- skip recast fade
            end
            FancyActionBar.effects[id] = nil
            instances[id] = nil
        else
            -- Remove the instance matching this id
            local removeIndex = nil
            for i, inst in ipairs(instances) do
                if inst.id == id then
                    removeIndex = i
                    break
                end
            end
            if removeIndex then
                tableRemove(instances, removeIndex)
            end
        end

        -- If the fade is for the parent ability, wipe all devices
        if not allowMulti and id == parentId then
            for instId, instData in pairs(instances) do
                FancyActionBar.effects[instId] = nil
            end
            parentEffect.instances = {}
        end
    end

    -- Aggregate timing info
    local stackCount, latestBegin, soonestEnd, latestEnd = 0, 0, nil, nil
    for _, inst in pairs(instances) do
        if inst.endTime > updateTime then
            stackCount = stackCount + 1
            if inst.beginTime > latestBegin then latestBegin = inst.beginTime end
            if not soonestEnd or inst.endTime < soonestEnd then soonestEnd = inst.endTime end
            if not latestEnd or inst.endTime > latestEnd then latestEnd = inst.endTime end
        end
    end

    -- Compute effective end time
    local effectiveEndTime = 0
    if stackCount > 0 then
        if SV.showSoonestExpire then
            effectiveEndTime = soonestEnd
        else
            effectiveEndTime = latestEnd
            local extended = latestBegin + duration + 0.5
            if extended > updateTime and extended > effectiveEndTime then
                effectiveEndTime = extended
            end
        end
    end

    parentEffect.endTime = effectiveEndTime
    FancyActionBar.SetStacks(parentId, stackCount, true)
end

-------------------------------------------------------------------------------
-----------------------------[      Initialize      ]--------------------------
-------------------------------------------------------------------------------
local function SetAbilityBarTimersEnabled()
    if tonumber(GetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_TIMERS)) == 0 then
        SetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_TIMERS, "true")
    end
end

function FancyActionBar.SetupBackbarDragDropHandlers(button)
    local buttonControl = button and button.button
    if not buttonControl then
        return
    end

    local function getActionBarSlotAndCategory()
        local slotNum = button.slot and button.slot.slotNum or 0
        return slotNum - SLOT_INDEX_OFFSET, GetInactiveHotbarCategory(GetActiveHotbarCategory())
    end

    buttonControl:SetHandler("OnReceiveDrag", function ()
        if GetCursorContentType() == MOUSE_CONTENT_EMPTY then
            return
        end

        local slotNum, hotbarCategory = getActionBarSlotAndCategory()
        AttemptPlacement(slotNum, hotbarCategory)
    end)

    buttonControl:SetHandler("OnDragStart", function ()
        if GetCursorContentType() ~= MOUSE_CONTENT_EMPTY or ZO_ActionBar_AreActionBarsLocked() then
            return false
        end

        local slotNum, hotbarCategory = getActionBarSlotAndCategory()
        if not IsSlotUsed(slotNum, hotbarCategory) then
            return false
        end

        AttemptPickup(slotNum, hotbarCategory)
        return true
    end)

    buttonControl:SetHandler("OnClicked", function (_, mouseButton)
        if mouseButton ~= MOUSE_BUTTON_INDEX_LEFT or GetCursorContentType() == MOUSE_CONTENT_EMPTY then
            return
        end

        local slotNum, hotbarCategory = getActionBarSlotAndCategory()
        AttemptPlacement(slotNum, hotbarCategory)
    end)

    buttonControl:SetHandler("OnMouseEnter", function ()
        if IsInGamepadPreferredMode() then
            return
        end

        local slotNum, hotbarCategory = getActionBarSlotAndCategory()
        if GetSlotType(slotNum, hotbarCategory) == ACTION_TYPE_NOTHING then
            return
        end

        InitializeTooltip(AbilityTooltip, buttonControl, BOTTOM, 0, -5, TOP)
        AbilityTooltip:SetAbilityId(FancyActionBar.GetSlotBoundAbilityId(slotNum, hotbarCategory))
    end)

    buttonControl:SetHandler("OnMouseExit", function ()
        ClearTooltip(AbilityTooltip)
    end)
end

-- Update actionId for backbar buttons
function FancyActionBar.UpdateBackbarButtonActionIds(slotNum, activeHotbar)
    activeHotbar = activeHotbar or GetActiveHotbarCategory()
    local inactiveHotbarCategory = GetInactiveHotbarCategory(activeHotbar)
    if slotNum then
        local index = slotNum + SLOT_INDEX_OFFSET
        local button = FancyActionBar.buttons[index]
        if button and button.button then
            button.button.actionId = FancyActionBar.GetSlotBoundAbilityId(slotNum, inactiveHotbarCategory)
            button.button.hotbarCategory = inactiveHotbarCategory
        end
        return
    end
    for i = MIN_INDEX + SLOT_INDEX_OFFSET, MAX_INDEX + SLOT_INDEX_OFFSET do
        local button = FancyActionBar.buttons[i]
        if button and button.button then
            button.button.actionId = FancyActionBar.GetSlotBoundAbilityId(i - SLOT_INDEX_OFFSET, inactiveHotbarCategory)
            button.button.hotbarCategory = inactiveHotbarCategory
        end
    end
end

-- Call this function after slot changes or bar swap
local function OnSlotChanged(_, slotNum, hotbarCategory)
    if slotNum < MIN_INDEX or slotNum > ULT_INDEX then return end
    local currentHotbarCategory = GetActiveHotbarCategory()
    local slotIndex = GetOverlayIndex(slotNum, hotbarCategory)
    local boundId = FancyActionBar.GetSlotBoundAbilityId(slotNum, hotbarCategory)
    local prevEffectId, prevAbilityId = FancyActionBar.GetSlottedEffect(slotIndex)
    local bindingChanged = prevAbilityId ~= boundId

    if hotbarCategory == currentHotbarCategory and slotNum ~= ULT_INDEX then
        local btn = FancyActionBar.GetActionButton(slotNum)
        if btn then
            syncActionButton(btn, hotbarCategory)
        end
    elseif slotNum <= MAX_INDEX or slotNum == ULT_INDEX then
        PaintDataOverlay(slotIndex)
    end

    FancyActionBar.SlotEffect(slotIndex, boundId)

    local inactiveHotbar = GetInactiveHotbarCategory(currentHotbarCategory)
    FancyActionBar.UpdateOverlay(slotIndex, time(), currentHotbarCategory, inactiveHotbar)

    if bindingChanged then
        if (slotIndex == ULT_INDEX or slotIndex == ULT_INDEX + SLOT_INDEX_OFFSET) then
            FancyActionBar.UpdateUltimateCost()
        end
        FancyActionBar.UpdateSlottedSkillsDecriptions()
    end
    FancyActionBar.UpdateBackbarButtonActionIds(slotNum <= MAX_INDEX and slotNum or nil)

    if hotbarCategory == HOTBAR_CATEGORY_COMPANION and slotNum == ULT_INDEX then
        FancyActionBar.HandleCompanionUltimate()
    end
end

local groundTargetMode = { active = false, pending = {} }

-- Button (usable) state changed.
local function OnHotbarSlotStateUpdated(_, slot, hotbar)
    if groundTargetMode.active then
        tableInsert(groundTargetMode.pending, { slot, hotbar })
        return
    end

    local effect = channeledAbility.id and FancyActionBar.effects[channeledAbility.id] or nil
    UpdateChanneledAbilityCastState(effect, time())

    if hotbar ~= GetActiveHotbarCategory() then
        return
    end
    local btn = ZO_ActionBar_GetButton(slot, hotbar)
    if btn and channeledAbility.pending and channeledAbility.id then
        local index = GetOverlayIndex(slot, hotbar)
        local barSlot = slots[index]
        if barSlot and barSlot.effectId == channeledAbility.id then
            local currentTime = time()
            local latencyAdjust = zo_max(GetLatency(), 150) + 200
            effect = FancyActionBar.effects[channeledAbility.id]
            if not effect then
                FancyActionBar.ChanneledAbilityEnd(channeledAbility.id)
                return
            end
            if not effect.isChanneled then
                return
            end
            if effect.castEndTime and (effect.castEndTime > (currentTime + latencyAdjust)) then
                effect.castEndTime = 0
                FancyActionBar.ChanneledAbilityEnd(channeledAbility.id)
                return
            end
            local adjustFatecarver = (effect.id == 183122 or effect.id == 193397)
            local adjust = adjustFatecarver and ((FancyActionBar.GetStacks(184220) or 0) * 0.338) or 0
            local castDuration = effect.castDuration or channeledAbility.castDuration
            effect.castEndTime = castDuration and (castDuration + adjust + time()) or 0
            FancyActionBar.ChanneledAbilityBegin(channeledAbility.id, effect.castEndTime)
        end
    end
end

local function OnGroundTargetModeEvent(eventCode)
    if eventCode == EVENT_ENTER_GROUND_TARGET_MODE then
        groundTargetMode.pending = {}
        groundTargetMode.active = true
        return
    end

    groundTargetMode.active = false
    local pending = groundTargetMode.pending
    groundTargetMode.pending = {}
    for i = 1, #pending do
        local update = pending[i]
        OnHotbarSlotStateUpdated(nil, update[1], update[2])
    end
end

local function OnActiveHotbarUpdated(_, didActiveHotbarChange, shouldUpdateAbilityAssignments, activeHotbarCategory)
    if FancyActionBar.specialHotbar[activeHotbarCategory] then
        specialHotbarActive = true
        if SV.hideLockedBar then
            applyWeaponLockPresentation(specialHotbarActive)
        else
            FancyActionBar.ApplyActiveHotbarGeometry(nil, isWeaponSwapLocked)
        end
        FancyActionBar.SyncSpecialHotbarState(activeHotbarCategory, shouldUpdateAbilityAssignments ~= false)
    elseif didActiveHotbarChange and specialHotbarActive and not FancyActionBar.specialHotbar[activeHotbarCategory] then
        specialHotbarActive = false
        if not SV.hideLockedBar then
            isWeaponSwapLocked = false
        end
        if SV.hideLockedBar then
            applyWeaponLockPresentation(specialHotbarActive)
        else
            FancyActionBar.ApplyActiveHotbarGeometry(nil, isWeaponSwapLocked)
            FancyActionBar.RefreshAdjacentSlots(isWeaponSwapLocked)
        end
        FancyActionBar.SyncSpecialHotbarState(activeHotbarCategory, true)
    elseif didActiveHotbarChange
        and (activeHotbarCategory == HOTBAR_CATEGORY_PRIMARY or activeHotbarCategory == HOTBAR_CATEGORY_BACKUP) then
        if layoutHotbarCategory ~= activeHotbarCategory then
            FancyActionBar.ApplyActiveHotbarGeometry(activeHotbarCategory, isWeaponSwapLocked)
            FancyActionBar.RefreshHotbarPresentation(activeHotbarCategory, true)
        end
        refreshBackupBarButtons()
        FancyActionBar.PaintAbilityOverlays(nil, activeHotbarCategory)
        tickOverlayTimers(time(), activeHotbarCategory)
        FancyActionBar.UpdateUltimateCost()
    elseif didActiveHotbarChange then
        if layoutHotbarCategory ~= HOTBAR_CATEGORY_PRIMARY then
            FancyActionBar.ApplyActiveHotbarGeometry(HOTBAR_CATEGORY_PRIMARY, isWeaponSwapLocked)
        end
        FancyActionBar.RefreshActiveBarSlots(activeHotbarCategory)
        refreshBackupBarButtons()
        FancyActionBar.PaintAbilityOverlays(nil, activeHotbarCategory)
        tickOverlayTimers(time(), layoutHotbarCategory)
        FancyActionBar.UpdateUltimateCost()
    end
end

local function SyncWeaponTypes()
    FancyActionBar.weaponFront = GetItemLinkWeaponType(GetItemLink(BAG_WORN, EQUIP_SLOT_MAIN_HAND, LINK_STYLE_DEFAULT))
    FancyActionBar.weaponBack = GetItemLinkWeaponType(GetItemLink(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN, LINK_STYLE_DEFAULT))
end

local function PrepareWeaponLockState()
    FancyActionBar.oakensoulEquipped = (GetItemInfo(BAG_WORN, EQUIP_SLOT_RING1) == FancyActionBar.oakensoul)
        or (GetItemInfo(BAG_WORN, EQUIP_SLOT_RING2) == FancyActionBar.oakensoul)
    FancyActionBar.isWerewolf = IsPlayerInWerewolfForm()
    if SV.hideLockedBar then
        isWeaponSwapLocked = FancyActionBar.oakensoulEquipped or FancyActionBar.isWerewolf
    end
end

local function OnAllHotbarsUpdated()
    local activeHotbar = GetActiveHotbarCategory()
    local layoutHotbar = activeHotbar
    if layoutHotbar ~= HOTBAR_CATEGORY_PRIMARY and layoutHotbar ~= HOTBAR_CATEGORY_BACKUP then
        layoutHotbar = HOTBAR_CATEGORY_PRIMARY
    end
    local layoutCurrent = layoutHotbarCategory == layoutHotbar

    FancyActionBar.SlotEffects()

    if not layoutCurrent then
        FancyActionBar.ApplyActiveHotbarGeometry(nil, isWeaponSwapLocked)
        FancyActionBar.RefreshAdjacentSlots(isWeaponSwapLocked)
        syncAllHotbarSlots()
        FancyActionBar.RefreshHotbarPresentation(nil, false)
    else
        refreshBackupBarButtons()
        FancyActionBar.PaintAbilityOverlays(nil, activeHotbar)
    end
    tickOverlayTimers(time(), layoutHotbar)
    FancyActionBar.RefreshEffectWidgets()
    FancyActionBar.UpdateSlottedSkillsDecriptions()
    HideAllAbilityActionButtonDropCallouts()
end

local function OnArmory()
    SyncWeaponTypes()
    local wasOakensoulEquipped = FancyActionBar.oakensoulEquipped
    local isOakensoulEquipped = (GetItemInfo(BAG_WORN, EQUIP_SLOT_RING1) == FancyActionBar.oakensoul)
        or (GetItemInfo(BAG_WORN, EQUIP_SLOT_RING2) == FancyActionBar.oakensoul)
    FancyActionBar.oakensoulEquipped = isOakensoulEquipped
    if SV.hideLockedBar and (isOakensoulEquipped or wasOakensoulEquipped) then
        isWeaponSwapLocked = FancyActionBar.oakensoulEquipped or FancyActionBar.isWerewolf
    end
    FancyActionBar.SlotEffects()
    FancyActionBar.SyncEffectState("slotted")
    OnAllHotbarsUpdated()
end

local function OnActiveWeaponPairChanged(eventCode, activeWeaponPair)
    if activeWeaponPair ~= currentWeaponPair then
        FancyActionBar.ChanneledAbilityEnd()
        currentWeaponPair = activeWeaponPair
    end
end

-- IsAbilityUltimate(*integer* _abilityId_)
local function OnAbilityUsed(_, n)
    if n < MIN_INDEX or n > ULT_INDEX then return end
    local currentHotbarCategory = GetActiveHotbarCategory()
    local id = FancyActionBar.GetSlotBoundAbilityId(n, currentHotbarCategory)
    local index = GetOverlayIndex(n, currentHotbarCategory)
    local name = GetAbilityName(id)
    local t = time()
    local slotStateSpecialEffect = FancyActionBar.specialEffects[id]
    if slotStateSpecialEffect and slotStateSpecialEffect.useSlotStateChange then
        return
    end
    local slot = slots[index]
    local i = slot and slot.effectId
    local effect = i and FancyActionBar.effects[i]
    local idCheck = FancyActionBar.IdCheck(index, id)

    if n ~= ULT_INDEX and SV.forceGamepadStyle then
        local btn = ZO_ActionBar_GetButton(n)
        if btn then
            btn:PlayAbilityUsedBounce()
            btn:PlayGlow()
        end
    end

    if i and not FancyActionBar.ignore[id] and idCheck then
        local eff = FancyActionBar.effects and FancyActionBar.effects[i]
        if eff then
            eff.hasActiveCast = true
            eff.castTime = t
        end
    end

    if not idCheck then
        local E = FancyActionBar.effects[i]
        if E then
            if E.hasActiveCast then
                E.castTime = t
            end
            local D = E.toggled and "-1" or tostring((FancyActionBar.GetAbilityDuration(i) or -1) / 1000)
            FancyActionBar.AddSystemMessage("4 [ActionButton%d]<%s> #%d: " .. D, index, name, E.id)
        end
    end

    if effect and FancyActionBar.toggled[effect.id] then
        local isToggled = FancyActionBar.toggles[FancyActionBar.bannerBearer[effect.id] and "banner" or effect.id]
        local O = (not isToggled) and "On" or "Off"
        FancyActionBar.AddSystemMessage("3 [ActionButton%d]<%s> #%d: " .. O .. ".", index, name, effect.id)
    end

    if SV.showCastDuration and slot and slot.abilityId == id and slot.effectId then
        effect = effect or FancyActionBar.effects[slot.effectId] or FancyActionBar.SlotEffect(index, id)
        if effect then
            channeledAbility.wasBlockActive = IsBlockActive()
            local isChannel, castTimeMs, channelTimeMs = GetAbilityCastInfo(slot.effectId, nil, "player")
            local durationMs = (castTimeMs and castTimeMs > 0) and castTimeMs or channelTimeMs
            local castDuration = durationMs and durationMs > 1000 and (durationMs / 1000) or nil
            if castDuration then
                effect.castDuration = castDuration
                if effect.isChanneled or isChannel then
                else
                    FancyActionBar.ChanneledAbilityBegin(effect.id, time() + castDuration)
                end
            elseif not channeledAbility.id
                or effect.id == channeledAbility.id
                or (not channeledAbility.active and not channeledAbility.pending) then
                effect.castDuration = nil
                FancyActionBar.ChanneledAbilityEnd()
            end
        end
    end

    if not effect then
        if FancyActionBar.effects[i] then
            FancyActionBar.AddSystemMessage("? [ActionButton%d]<%s> #%d: %0.1fs", index, name, FancyActionBar.effects[i].id, (FancyActionBar.GetAbilityDuration(FancyActionBar.effects[i].id) or -1) / 1000)
        else
            FancyActionBar.AddSystemMessage("[ActionButton%d] #%d: %0.1fs", index, id, FancyActionBar.GetAbilityDuration(id))
        end
        return
    end

    local specialEffect = FancyActionBar.specialEffects[id]
    if specialEffect and specialEffect.onAbilityUsed then
        if FancyActionBar.traps[id] and SV.ignoreTrapPlacement then return end
        specialEffect = ZO_DeepTableCopy(specialEffect)
        local duration = (specialEffect.setTime and specialEffect.duration) or effect.duration or specialEffect.duration or -1
        for k, v in pairs(specialEffect) do
            if k ~= "stackId" and k ~= "stackSources" then
                if type(v) == "table" then
                    effect[k] = ZO_DeepTableCopy(v)
                else
                    effect[k] = v
                end
            end
        end
        effect.endTime = duration > 0 and (duration + t) or -1
        if slot then
            slot.parentEndTime = nil
        end
        if specialEffect.stacks then
            local sourceId = GetConfiguredStackSources(specialEffect)[1] or specialEffect.id
            if sourceId then FancyActionBar.SetStacks(sourceId, specialEffect.stacks, true) end
        end
        FancyActionBar.AddSystemMessage("0 [ActionButton%d]<%s> #%d: %0.1fs", index, name, effect.id, (FancyActionBar.GetAbilityDuration(effect.id) or -1) / 1000)
        return
    end

    if effect.id ~= id then
        local e = FancyActionBar.effects[i]
        if e then
            FancyActionBar.AddSystemMessage("2 [ActionButton%d]<%s> #%d: %0.1fs", index, name, i, e.toggled and -1 or (FancyActionBar.GetAbilityDuration(e.id) or -1) / 1000)
        end
        return
    end

    -- effect.id == id
    if effect.duration and slot and not IsAbilityConfigured(slot.abilityId) then
        FancyActionBar.AddSystemMessage("1 [ActionButton%d]<%s> #%d: %0.1fs", index, name, effect.id, (FancyActionBar.GetAbilityDuration(effect.id) or -1) / 1000)
    end
end

local function OnActionSlotEffectUpdated(_, hotbarCategory, actionSlotIndex)
    local t = time()
    local abilityId = FancyActionBar.GetSlotBoundAbilityId(actionSlotIndex, hotbarCategory)
    local index = GetOverlayIndex(actionSlotIndex, hotbarCategory)
    local slot = slots[index]
    local slotStateEffect = FancyActionBar.slotStateSpecialEffects[index]
    local specialEffect = FancyActionBar.specialEffects[abilityId]

    if specialEffect and specialEffect.useSlotStateChange then
        local effectId, slottedAbilityId = FancyActionBar.GetSlottedEffect(index)
        local effect = (effectId and effectId ~= 0 and FancyActionBar.effects[effectId]) or FancyActionBar.effects[specialEffect.id]
        local stackSourceId = GetConfiguredStackSources(specialEffect)[1] or specialEffect.id

        if not effect then
            return
        end

        local duration = (GetActionSlotEffectDuration(actionSlotIndex, hotbarCategory) or -1) / 1000
        local remain = (GetActionSlotEffectTimeRemaining(actionSlotIndex, hotbarCategory) or 0) / 1000
        duration = duration > FancyActionBar.durationMin and duration < FancyActionBar.durationMax and duration or -1
        if duration <= 0 or remain <= 0 then
            return
        end

        local beginTime = t - (duration - remain)
        local endTime = t + remain
        local isSameEffectId = effect.id == specialEffect.id
        local isNewSlotStateEffect = (not slotStateEffect) or slotStateEffect.specialAbilityId ~= abilityId or slotStateEffect.effectId ~= effect.id
        local nextStacks = specialEffect.stacks

        if slotStateEffect and slotStateEffect.stackSourceId and slotStateEffect.stackSourceId ~= stackSourceId then
            FancyActionBar.SetStacks(slotStateEffect.stackSourceId, 0, true)
        end

        if not isNewSlotStateEffect then
            local currentStacks = slotStateEffect.stacks
            if currentStacks == nil then
                currentStacks = FancyActionBar.GetStacks(stackSourceId) or specialEffect.stacks or 0
            end
            nextStacks = zo_max(currentStacks - 1, 0)
        end

        if isSameEffectId then
            effect.beginTime = beginTime
            effect.endTime = endTime
        else
            if not effect.origDontFade then
                effect.origDontFade = effect.dontFade
            end
            if not effect.origForceExpireStacks then
                effect.origForceExpireStacks = effect.forceExpireStacks
            end
            if specialEffect.dontFade then
                effect.dontFade = specialEffect.dontFade
            end
            if specialEffect.forceExpireStacks then
                effect.forceExpireStacks = specialEffect.forceExpireStacks
            end
            if not effect.origStackSources then
                effect.origStackSources = effect.stackSources
            end
            local newSources = GetConfiguredStackSources(specialEffect)
            if #newSources == 0 then
                newSources = FancyActionBar.GetStackMap(stackSourceId).sources
            else
                newSources = ZO_DeepTableCopy(newSources)
            end
            if effect.stackSources ~= newSources then
                effect.stackSources = newSources
                effect.stackOwnerId = FancyActionBar.GetStackOwnerId(effect.id)
            end
            effect.slotStateBeginTime = beginTime
            effect.slotStateEndTime = endTime
            effect.slotStateAbilityId = abilityId
        end

        if nextStacks then
            FancyActionBar.SetStacks(stackSourceId, nextStacks, true)
        end

        FancyActionBar.slotStateSpecialEffects[index] =
        {
            effectId = effect.id,
            specialAbilityId = abilityId,
            sourceAbilityId = slottedAbilityId,
            specialEffectId = specialEffect.id,
            stackSourceId = stackSourceId,
            stacks = nextStacks,
        }

        return
    end

    if slotStateEffect then
        local trackedEffect = FancyActionBar.effects[slotStateEffect.effectId]
        local stackSourceId = slotStateEffect.stackSourceId or slotStateEffect.specialEffectId or slotStateEffect.effectId
        if trackedEffect then
            FancyActionBar.SetStacks(stackSourceId, 0, true)
            if trackedEffect.origStackSources then
                trackedEffect.stackSources = trackedEffect.origStackSources
                trackedEffect.origStackSources = nil
                trackedEffect.stackOwnerId = FancyActionBar.GetStackOwnerId(trackedEffect.id)
            end
        end
        FancyActionBar.slotStateSpecialEffects[index] = nil
    end

    if specialEffect or SV.parentTimeBlacklist[abilityId] then
        return
    end

    local effectId = (slot and slot.effectId) or FancyActionBar.GetTrackedEffectId(abilityId)
    if effectId == 0 then
        return
    end
    local effect = FancyActionBar.effects[effectId]
    if not effect then
        if slot and slot.abilityId == abilityId then
            effect = FancyActionBar.SlotEffect(index, abilityId)
            effectId = slot.effectId
        else
            effect = FancyActionBar.GetEffect(effectId, { abilityId = abilityId })
        end
    end
    local usesConfiguredTracking = IsAbilityConfigured(abilityId) and effectId ~= abilityId
    local allowSlotTimerUpdate = (not IsAbilityConfigured(abilityId)) or SV.allowParentTime

    if not allowSlotTimerUpdate then
        return
    end

    local duration = (GetActionSlotEffectDuration(actionSlotIndex, hotbarCategory) or -1) / 1000
    duration = duration > FancyActionBar.durationMin and duration < FancyActionBar.durationMax and duration or -1

    local remain = GetActionSlotEffectTimeRemaining(actionSlotIndex, hotbarCategory) / 1000
    local hasValidSlotEffect = duration > 0 and remain > 0

    if not hasValidSlotEffect then
        if slot and (hotbarCategory == GetActiveHotbarCategory() or not (slot.parentEndTime and slot.parentEndTime > t)) then
            slot.parentEndTime = nil
        end
        if not effect then
            FancyActionBar.UpdateOverlay(index)
            return
        end
        if FancyActionBar.IsChanneledAbilityActive(effect, t) then
            return
        end
        if effect.isChanneled then
            effect.castEndTime = 0
        end
        FancyActionBar.ChanneledAbilityEnd(effect.id)
        FancyActionBar.UpdateOverlay(index)
        return
    end

    if (usesConfiguredTracking or not effect) and SV.allowParentTime then
        if slot then
            slot.parentEndTime = t + remain
        end
        return
    end

    if not effect then
        return
    end

    if slot then
        slot.parentEndTime = nil
    end
    if effect.isChanneled then
        effect.castEndTime = t + remain
        FancyActionBar.ChanneledAbilityBegin(effect.id, effect.castEndTime)
    else
        if SV.potlfix and remain > 6 and effect.id == 21763 then
            remain = 6
        end
        if effect.dontFade and remain < FancyActionBar.durationMin then
            return
        end
        effect.beginTime = t - (duration - remain)
        effect.endTime = t + remain
        effect.duration = duration
    end
    local stackableBuff = FancyActionBar.stackableBuff[abilityId]
    if stackableBuff then
        FancyActionBar.SetStacks(stackableBuff)
    end
end

local lastCW = 0 -- track when last crystal weapon debuff was applied
local function OnEffectChanged(eventCode, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    local t = time()
    local isGain = (change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED)
    local isFade = (change == EFFECT_RESULT_FADED)
    local isTargetPlayer = AreUnitsEqual("player", unitTag)

    if SV.debugAll then
        FancyActionBar.PostAllChanges(eventCode, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType, t)
    end

    if channeledAbility.active and abilityId == 29721 and change == EFFECT_RESULT_UPDATED then FancyActionBar.ChanneledAbilityEnd() end

    local spec = FancyActionBar.specialEffects[abilityId]
    local useSpecialDebuff = SV.advancedDebuff and spec and spec.isSpecialDebuff

    if spec and spec.useSlotStateChange then return end
    if spec and not useSpecialDebuff then
        if FancyActionBar.traps[abilityId] and SV.ignoreTrapPlacement then return end
        FancyActionBar.HandleSpecialEffect(abilityId, change, t, beginTime, endTime, unitTag, stackCount, abilityType, unitId, effectSlot)
        return
    end

    if abilityId == 143808 and isGain then
        if FancyActionBar.effects[46331] and (t - lastCW > 0.5) then
            lastCW = t
            local cwStacks = FancyActionBar.GetStacks(46331) or 0
            if cwStacks > 0 then
                FancyActionBar.SetStacks(46331, cwStacks - 1, true)
            end
            return
        end
    end

    if not ShouldTrackEffectChange(abilityId) then
        return
    end

    local hasFixedStacks = FancyActionBar.fixedStacks[abilityId] ~= nil
    local targetUnitKey = FancyActionBar.ResolveUnitKey("targets", unitTag, unitId, effectSlot)
    local stackEntry = FancyActionBar.GetStackMap(abilityId)
    local sourceId = stackEntry.sourceId
    local ownerId = stackEntry.ownerId
    local ownsStackStorage = not sourceId or sourceId == abilityId

    local effectId = abilityId
    if not ownsStackStorage then
        local trackedId = FancyActionBar.GetTrackedEffectId(abilityId)
        if trackedId ~= 0 and trackedId ~= abilityId and trackedId ~= ownerId then
            return
        end
        effectId = trackedId ~= 0 and trackedId or ownerId
    end
    local effect = FancyActionBar.effects[effectId]
    if not effect then
        effect = FancyActionBar.GetEffect(effectId, { abilityId = abilityId })
    end

    if FancyActionBar.bannerBearer[abilityId] and sourceType == COMBAT_UNIT_TYPE_PLAYER and isTargetPlayer then
        if isGain then
            local resolvedBegin = (beginTime ~= 0) and beginTime or t
            for k in pairs(FancyActionBar.bannerBearer) do
                local slottedId = sourceAbilities[k]
                local slottedEffect = slottedId and FancyActionBar.effects[slottedId]
                if slottedEffect then
                    slottedEffect.beginTime = resolvedBegin
                end
            end
        end
        FancyActionBar.UpdateToggledAbility(abilityId, isGain)
    elseif effect.toggled then
        effect.beginTime = (beginTime ~= 0) and beginTime or t
        FancyActionBar.UpdateToggledAbility(effect.id, not isFade)
    end

    if (effectType == BUFF_EFFECT_TYPE_DEBUFF or useSpecialDebuff) then
        if FancyActionBar.ShouldTrackAsDebuff(abilityId, unitTag or "") or useSpecialDebuff then
            effect.isDebuff = true
            FancyActionBar.OnDebuffChanged(effect, t, eventCode, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
            return
        end
    end

    if SV.ignoreUngroupedAliies and IsUnitGrouped("player") then
        if abilityType ~= ABILITY_TYPE_AREAEFFECT and not (FancyActionBar.IsLocalPlayerOrEnemy(unitTag) or ZO_Group_IsGroupUnitTag(unitTag) or FancyActionBar.IsPlayerPet(unitTag) or IsGroupCompanionUnitTag(unitTag) or unitTag == "companion") then
            return
        end
    end

    if isGain then
        local isSelf = GetAbilityTargetDescription(effect.id, nil, unitTag) == "Self"
        local isPlayerPet = FancyActionBar.IsPlayerPet(unitTag)
        local willRecord = (not SV.multiTargetBlacklist[effect.id]) and (abilityType ~= ABILITY_TYPE_AREAEFFECT) and not isSelf and not isPlayerPet

        if effect.hasActiveCast then
            local targetData = FancyActionBar.GetUnits(effect.id, "targets")
            if not targetData or not next(targetData.times or {}) then
                effect.beginTime = beginTime
            end
            if unitId and unitId > 0 and abilityType ~= ABILITY_TYPE_AREAEFFECT and not isPlayerPet then
                willRecord = true
            end
        end

        if willRecord then
            if targetUnitKey and targetUnitKey > 0 then
                local activeTargets, soonest, maxEnd = FancyActionBar.RecordUnit(effect.id, effect, targetUnitKey, t, beginTime, endTime, "targets")
                if activeTargets >= 1 and maxEnd and maxEnd > 0 then
                    effect.endTime = maxEnd
                else
                    effect.endTime = t
                end
            end
        end

        local sourceCount
        if isTargetPlayer then
            local sbId = FancyActionBar.stackableBuff[abilityId]
            if sbId and beginTime ~= endTime and endTime > t then
                sourceCount = select(1, FancyActionBar.RecordUnit(sbId, nil, effectSlot, t, beginTime, endTime, "sources", { castByPlayer = (sourceType == COMBAT_UNIT_TYPE_PLAYER) }))
            end
        end

        if endTime ~= beginTime and effect.passive then FancyActionBar.UpdatePassiveEffect(effect.id, false) end

        if isTargetPlayer and FancyActionBar.stackableBuff[abilityId] then
            FancyActionBar.SetStacks(FancyActionBar.stackableBuff[abilityId], sourceCount, sourceCount ~= nil)
        elseif hasFixedStacks or ownsStackStorage or sourceId then
            FancyActionBar.UpdateStacksFromEvent(abilityId, stackCount, false)
        end

        if (endTime > t + FancyActionBar.durationMin and endTime < t + FancyActionBar.durationMax) then
            effect.duration = (beginTime and endTime and (endTime - beginTime) > 0) and (endTime - beginTime) or effect.duration
            effect.endTime = endTime
            if abilityType == ABILITY_TYPE_AREAEFFECT then
                lastAreaTargets[abilityId] = unitId
                if abilityId == 117805 then
                    effect.endTime = t + 10
                    return
                end
            end
        end
    elseif isFade then
        if isTargetPlayer then
            local sbId = FancyActionBar.stackableBuff[abilityId]
            if sbId then
                local sourceCount = select(1, FancyActionBar.RemoveUnit(sbId, effectSlot, t, "sources"))
                FancyActionBar.SetStacks(sbId, sourceCount, true)
            end
        end

        local td = FancyActionBar.GetUnits(effect.id, "targets")
        local hasActiveTargets = false
        if td and td.times then
            if targetUnitKey and td.times[targetUnitKey] then
                local activeTargets, soonest, maxEnd = FancyActionBar.RemoveUnit(effect.id, targetUnitKey, t, "targets")
                if activeTargets >= 1 and maxEnd and maxEnd > 0 then
                    effect.endTime = maxEnd
                elseif not effect.dontFade and not (effect.endTime and effect.endTime > t) then
                    effect.endTime = t
                end
                hasActiveTargets = (activeTargets >= 1)
            end
        end

        if FancyActionBar.IsGroupUnit(unitTag) then return end

        if hasActiveTargets then return end
        if hasFixedStacks or ownsStackStorage or sourceId then
            FancyActionBar.UpdateStacksFromEvent(abilityId, stackCount, true)
        end

        if isTargetPlayer and effect.dontFade then
            if not SV.externalBuffs and effect.endTime > t then return end
            if (not SV.externalBuffs) or SV.externalBlackList[effect.id] then
                if FancyActionBar.RecomputeUnits(effect.id, t, "sources") > 0 then return end
            end
        end

        if effect.instantFade or FancyActionBar.removeInstantly[effect.id] then
            effect.endTime = t
            return
        end

        if effect.endTime and effect.endTime > t then
            return
        end

        if effectType == BUFF_EFFECT_TYPE_DEBUFF or abilityId == 38791 then return end

        if effect.hasActiveCast then
            if abilityType == ABILITY_TYPE_AREAEFFECT and lastAreaTargets[abilityId] then
                if lastAreaTargets[abilityId] ~= unitId then return end
                lastAreaTargets[abilityId] = nil
            end

            local validEnd = effect.beginTime and (effect.beginTime < (t - 0.7))
            if not validEnd then
                if unitId and td and td.times then
                    if targetUnitKey then
                        local times = td.times[targetUnitKey]
                        if times and times.endTime and times.endTime > t then return end
                    end
                end
                if isTargetPlayer then
                    local active = FancyActionBar.RecomputeUnits(effect.id, t, "sources")
                    local wasPlayer = WasEffectCastByPlayer(effect)
                    if active > 0 and (wasPlayer or SV.externalBuffs) then return end
                end
                return
            end

            local noTargets = true
            if td and td.times then
                for _, times in pairs(td.times) do
                    if times.endTime and times.endTime > t then
                        noTargets = false
                        break
                    end
                end
            end

            if noTargets and not effect.dontFade then
                effect.endTime = t
                if effect.passive then FancyActionBar.UpdateToggledAbility(effect.id, false) end
            end
        end
    end
end

local function SyncFadedEffect(effect)
    effect.endTime = -1
    effect.slotStateEndTime = nil
    if effect.isChanneled then
        FancyActionBar.ChanneledAbilityEnd(effect.id)
        effect.castEndTime = -1
    end
    for _, slot in pairs(slots) do
        if slot.effectId == effect.id then
            slot.parentEndTime = nil
        end
    end
    if effect.toggled then
        FancyActionBar.UpdateToggledAbility(effect.id, false)
    end
    if effect.passive then
        FancyActionBar.UpdatePassiveEffect(effect.id, false)
    end
end

-- Drop a cached effect entry when it has no widget, active timer, or specialEffect active and is not a debuff
function FancyActionBar.ReleaseEffect(id, fade)
    if not id or id == 0 then
        return
    end
    local effect = FancyActionBar.effects[id]
    if not effect then
        return
    end
    if effect.isDebuff or FancyActionBar.specialEffects[effect.id] then
        return
    end
    if FancyActionBar.IsEffectWidgetTracked(id) then
        return
    end
    if slottedEffectIds[id] then
        return
    end
    for _, slot in pairs(slots) do
        if slot.effectId == id then
            return
        end
        if slot.abilityId and slot.abilityId ~= 0 then
            local configured = FancyActionBar.GetStackMap(slot.abilityId).sources
            for i = 1, #configured do
                if configured[i] == id then
                    return
                end
            end
        end
    end

    if fade then
        OnEffectChanged(
            nil,
            EFFECT_RESULT_FADED,
            nil, nil, "player",
            effect.beginTime or -1, effect.endTime or -1, effect.stacks, nil, nil, nil, nil, nil, nil, nil,
            id,
            COMBAT_UNIT_TYPE_PLAYER
        )
    end
    for abilityId, trackedId in pairs(sourceAbilities) do
        if trackedId == id then
            sourceAbilities[abilityId] = nil
        end
    end
    FancyActionBar.effects[id] = nil
end

-- Full effect reconcile: buff scan plus release of stale entries via ReleaseEffect.
function FancyActionBar.SyncEffectState(scope)
    local slottedOnly = scope == "slotted"
    local reconcileFilter = nil
    if slottedOnly then
        reconcileFilter = {}
        for _, slot in pairs(slots) do
            if slot.effectId and slot.effectId ~= 0 then
                reconcileFilter[slot.effectId] = true
            end
            if slot.abilityId and slot.abilityId ~= 0 then
                local members = FancyActionBar.GetStackMap(slot.abilityId).sources
                for i = 1, #members do
                    reconcileFilter[members[i]] = true
                end
            end
        end
    end

    local activeAbility = {}
    local scannedSourceSlots = {}
    local currentTime = time()
    local externalBuffs = SV.externalBuffs
    local stackableBuff = FancyActionBar.stackableBuff
    local specialEffects = FancyActionBar.specialEffects
    local bannerActive = false

    for id in pairs(FancyActionBar.toggles) do
        FancyActionBar.toggles[id] = false
    end

    for i = 1, GetNumBuffs("player") do
        local _, beginTime, endTime, buffSlot, stackCount, _, _, _, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo("player", i)
        if castByPlayer or externalBuffs or FancyActionBar.IsStackableBuff(abilityId) then
            activeAbility[abilityId] = stackCount
            local trackedId = sourceAbilities[abilityId] or abilityId
            activeAbility[trackedId] = stackCount
            local sbId = stackableBuff[abilityId]
            if sbId and beginTime ~= endTime and endTime > currentTime then
                FancyActionBar.RecordUnit(sbId, nil, buffSlot, currentTime, beginTime, endTime, "sources", { castByPlayer = castByPlayer })
                scannedSourceSlots[sbId] = scannedSourceSlots[sbId] or {}
                scannedSourceSlots[sbId][buffSlot] = true
            end
            if FancyActionBar.bannerBearer[abilityId] and (castByPlayer or externalBuffs) then
                bannerActive = true
                local resolvedBegin = (beginTime ~= 0) and beginTime or currentTime
                for k in pairs(FancyActionBar.bannerBearer) do
                    local slottedId = sourceAbilities[k]
                    local slottedEffect = slottedId and FancyActionBar.effects[slottedId]
                    if slottedEffect then
                        slottedEffect.beginTime = resolvedBegin
                    end
                end
            elseif FancyActionBar.toggled[abilityId] or FancyActionBar.toggled[trackedId] then
                FancyActionBar.toggles[FancyActionBar.bannerBearer[trackedId] and "banner" or trackedId] = true
                local toggleEffect = FancyActionBar.effects[trackedId]
                if toggleEffect then
                    toggleEffect.beginTime = (beginTime ~= 0) and beginTime or currentTime
                end
            end
        end
    end

    FancyActionBar.toggles["banner"] = bannerActive

    if not slottedOnly then
        for abilityId, spec in pairs(specialEffects) do
            if activeAbility[abilityId] ~= nil then
                activeAbility[spec.id] = activeAbility[abilityId]
            end
        end
    end

    for id, effect in pairs(FancyActionBar.effects) do
        if (not reconcileFilter or reconcileFilter[id]) and not effect.isDebuff and not specialEffects[effect.id] then
            local stackEntry = FancyActionBar.GetStackMap(id)
            local configuredSourceIds = stackEntry.sources
            local ownerId = stackEntry.ownerId
            local isStackable = FancyActionBar.IsStackableBuff(effect.id)
            local canonicalId = isStackable and ((stackableBuff and stackableBuff[effect.id]) or effect.id) or effect.id
            local buffStacks = nil
            for i = 1, #configuredSourceIds do
                local count = activeAbility[configuredSourceIds[i]]
                if count ~= nil and (buffStacks == nil or count > buffStacks) then
                    buffStacks = count
                end
            end
            if isStackable then
                local sourceSlots = scannedSourceSlots[canonicalId]
                local stackEff = FancyActionBar.effects[canonicalId]
                local sources = stackEff and stackEff.sources and stackEff.sources.times
                if sources then
                    for slotKey in pairs(sources) do
                        if not sourceSlots or not sourceSlots[slotKey] then
                            FancyActionBar.RemoveUnit(canonicalId, slotKey, currentTime, "sources")
                        end
                    end
                end
                local sourceCount = FancyActionBar.RecomputeUnits(canonicalId, currentTime, "sources") or 0
                if sourceCount > 0 then
                    FancyActionBar.SetStacks(canonicalId)
                elseif buffStacks ~= nil then
                    FancyActionBar.SetStacks(canonicalId, buffStacks, true)
                else
                    FancyActionBar.SetStacks(canonicalId, 0, true)
                end
            elseif id == ownerId then
                if buffStacks ~= nil then
                    FancyActionBar.SetStacks(ownerId, FancyActionBar.fixedStacks[ownerId] or buffStacks, true)
                else
                    FancyActionBar.SetStacks(ownerId, 0, true)
                end
            end

            local stacks = (isStackable and FancyActionBar.effects[canonicalId] and FancyActionBar.effects[canonicalId].stacks) or effect.stacks or 0
            local isToggleActive = FancyActionBar.toggles[FancyActionBar.bannerBearer[effect.id] and "banner" or effect.id]
            local stillActive = buffStacks ~= nil or (isStackable and stacks > 0) or isToggleActive
            if slottedOnly then
                stillActive = stillActive or (FancyActionBar.RecomputeUnits(effect.id, currentTime, "targets") or 0) > 0
            end

            if not stillActive then
                if not slottedOnly then
                    local targets = effect.targets
                    if targets and targets.times then
                        for unitKey in pairs(targets.times) do
                            targets.times[unitKey] = nil
                        end
                        targets.unitCount = 0
                        targets.maxEndTime = 0
                    end
                end
                SyncFadedEffect(effect)
                FancyActionBar.ReleaseEffect(id, false)
            end
        end
    end
end

-- Update overlays.
local function Update()
    local currentTime = time()
    tickOverlayTimers(currentTime)
    if hasEnabledEffectWidgets then
        FancyActionBar.UpdateEffectWidgets(currentTime)
    end
    if companionOverlayActive then
        FancyActionBar.UpdateOverlay(ULT_INDEX + COMPANION_INDEX_OFFSET, currentTime)
    end
end

local function OnPlayerActivated(_eventId, _initial)
    FancyActionBar.SetMarker()
    FancyActionBar.UpdateDebuffTracking()
    FancyActionBar.RegisterClassEffects()
    SyncWeaponTypes()
    PrepareWeaponLockState()

    local firstZone = not doneInitialHotbarSetup
    if firstZone then
        if not ZO_IsConsoleOrGameCoreUI() then
            SetAbilityBarTimersEnabled()
        end
        FancyActionBar.InitializeScreenResizeHandler()
        FancyActionBar.UpdateBarSettings(isWeaponSwapLocked, { skipSlots = true })
        FancyActionBar.RefreshActiveBarSlots()
        FancyActionBar.SlotEffects()
        refreshBackupBarButtons()
        FancyActionBar.ToggleUltimateValue()
        FancyActionBar.SetUltFrameAlpha()
        EM:UnregisterForUpdate(NAME .. "Update")
        EM:RegisterForUpdate(NAME .. "Update", updateRate, Update)
        doneInitialHotbarSetup = true
    elseif not FancyActionBar.wasStopped and not ACTION_BAR:IsHidden() then
        FancyActionBar.RefreshBarPosition(true)
    end

    FancyActionBar.SyncEffectState()
    OnAllHotbarsUpdated()
    if not firstZone then
        FancyActionBar.HandleCompanionUltimate()
    end
end


--- @param eventId integer
--- @param bagId Bag
--- @param slotIndex integer
--- @param isNewItem boolean
--- @param itemSoundCategory ItemUISoundCategory
--- @param inventoryUpdateReason integer
--- @param stackCountChange integer
--- @param triggeredByCharacterName string
--- @param triggeredByDisplayName string
--- @param isLastUpdateForMessage boolean
--- @param bonusDropSource BonusDropSource
local function OnEquippedGearChanged(eventId, bagId, slotIndex, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange, triggeredByCharacterName, triggeredByDisplayName, isLastUpdateForMessage, bonusDropSource)
    -- Only process worn equipment changes
    if bagId ~= BAG_WORN then
        return
    end

    -- Handle weapon slot changes
    if slotIndex == EQUIP_SLOT_MAIN_HAND or slotIndex == EQUIP_SLOT_BACKUP_MAIN then
        local prevFront, prevBack = FancyActionBar.weaponFront, FancyActionBar.weaponBack
        SyncWeaponTypes()
        if FancyActionBar.weaponFront ~= prevFront or FancyActionBar.weaponBack ~= prevBack then
            FancyActionBar.RefreshHotbarPresentation(nil, false)
        end
    end

    -- Handle ring slot changes for Oakensoul
    if slotIndex == EQUIP_SLOT_RING1 or slotIndex == EQUIP_SLOT_RING2 then
        local wasOakensoulEquipped = FancyActionBar.oakensoulEquipped
        local isOakensoulEquipped = (GetItemInfo(BAG_WORN, EQUIP_SLOT_RING1) == FancyActionBar.oakensoul) or (GetItemInfo(BAG_WORN, EQUIP_SLOT_RING2) == FancyActionBar.oakensoul)
        FancyActionBar.oakensoulEquipped = isOakensoulEquipped

        if SV.hideLockedBar and (isOakensoulEquipped or wasOakensoulEquipped) then
            applyWeaponLockPresentation(isOakensoulEquipped or FancyActionBar.isWerewolf)
        elseif isOakensoulEquipped ~= wasOakensoulEquipped then
            FancyActionBar.RefreshHotbarPresentation(nil, true)
        end
    end
end

--- @param eventId integer
--- @param unitTag string
--- @param isDead boolean
local function OnDeath(eventId, unitTag, isDead)
    -- Only process if player is dead
    if not isDead or not AreUnitsEqual("player", unitTag) then
        return
    end

    -- Reset channeling states
    FancyActionBar.ChanneledAbilityEnd()

    -- Update effects and tracking
    FancyActionBar.SyncEffectState()
    FancyActionBar.UpdateDebuffTracking()
end

-- function to handle combat events
--- @param eventId integer
--- @param result ActionResult
--- @param isError boolean
--- @param abilityName string
--- @param abilityGraphic integer
--- @param abilityActionSlotType ActionSlotType
--- @param sourceName string
--- @param sourceType CombatUnitType
--- @param targetName string
--- @param targetType CombatUnitType
--- @param hitValue integer
--- @param powerType CombatMechanicFlags
--- @param damageType DamageType
--- @param log boolean
--- @param sourceUnitId integer
--- @param targetUnitId integer
--- @param abilityId integer
--- @param overflow integer
local function OnCombatEvent(eventId, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    local effect
    local currentTime = time()

    -- Debug logging
    if SV.debugAll then
        local ts = tostring
        FancyActionBar.AddSystemMessage("===================")
        FancyActionBar.AddSystemMessage(abilityName .. " (" .. ts(abilityId) .. ") || result: " .. ts(result) .. " || hit: " .. ts(hitValue))
        FancyActionBar.AddSystemMessage("===================")
    end

    -- Handle special effects
    local specialEffect = FancyActionBar.specialEffects[abilityId] and ZO_DeepTableCopy(FancyActionBar.specialEffects[abilityId])
    local useSpecialDebuffTracking = SV.advancedDebuff and specialEffect and specialEffect.isSpecialDebuff

    if specialEffect and not useSpecialDebuffTracking then
        FancyActionBar.HandleSpecialEffect(abilityId, result, currentTime, currentTime, currentTime + FancyActionBar.GetAbilityDuration(abilityId), nil, nil, nil, targetUnitId, nil)
        return
    end

    -- Handle needed combat events
    if FancyActionBar.needCombatEvent[abilityId] and result == FancyActionBar.needCombatEvent[abilityId].result then
        local effectId = FancyActionBar.GetTrackedEffectId(abilityId)
        effect = FancyActionBar.effects[effectId]
        if effect then
            effect.endTime = currentTime + FancyActionBar.needCombatEvent[abilityId].duration
            return
        end
    end

    -- Handle Grave Lord Sacrifice
    if abilityId == FancyActionBar.graveLordSacrifice.eventId then
        effect = FancyActionBar.effects[FancyActionBar.graveLordSacrifice.id]
        if effect then
            effect.endTime = currentTime + FancyActionBar.graveLordSacrifice.duration
        end
    end
end

--- @param eventId integer
--- @param result ActionResult
--- @param isError boolean
--- @param abilityName string
--- @param abilityGraphic integer
--- @param abilityActionSlotType ActionSlotType
--- @param sourceName string
--- @param sourceType CombatUnitType
--- @param targetName string
--- @param targetType CombatUnitType
--- @param hitValue integer
--- @param powerType CombatMechanicFlags
--- @param damageType DamageType
--- @param log boolean
--- @param sourceUnitId integer
--- @param targetUnitId integer
--- @param abilityId integer
--- @param overflow integer
local function OnReflect(eventId, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    -- Only process if target is player
    if (targetType ~= COMBAT_UNIT_TYPE_PLAYER) then
        return
    end

    local currentTime = time()
    -- Debug logging
    if SV.debugAll then
        local ts = tostring
        FancyActionBar.AddSystemMessage("===================")
        FancyActionBar.AddSystemMessage(abilityName .. " (" .. ts(abilityId) .. ") || result: " .. ts(result) .. " || hit: " .. ts(hitValue))
        FancyActionBar.AddSystemMessage("===================")
    end

    local specialEffect = FancyActionBar.specialEffects[abilityId]
    local reflectSourceId = GetConfiguredStackSources(specialEffect)[1] or specialEffect.id
    local effect = FancyActionBar.effects[specialEffect.id]

    -- Prevent rapid updates
    if effect.beginTime and (currentTime - effect.beginTime < 0.3) then
        return
    end

    -- Handle effect gain
    if result == ACTION_RESULT_BEGIN or result == ACTION_RESULT_EFFECT_GAINED or result == ACTION_RESULT_EFFECT_GAINED_DURATION then
        FancyActionBar.SetStacks(reflectSourceId, specialEffect.stacks, true)
    end

    -- Handle damage shield
    if result == ACTION_RESULT_DAMAGE_SHIELDED then
        local cur = FancyActionBar.GetStacks(reflectSourceId) or 0
        if cur and cur > 0 then
            FancyActionBar.SetStacks(reflectSourceId, cur - 1, true)
        end
    end

    -- Handle effect fade
    if (result == ACTION_RESULT_EFFECT_FADED) then
        FancyActionBar.SetStacks(reflectSourceId, 0, true)
    end
end

function FancyActionBar.RegisterClassEffects(newSkillLineId)
    local skillData = SKILLS_DATA_MANAGER
    local skillLineIds = {}

    if newSkillLineId then
        if registeredSkillLines[newSkillLineId] then return end
        skillLineIds = { newSkillLineId }
    elseif SKILLS_DATA_MANAGER:IsDataReady() then
        for i = 1, 3 do
            local skillLine = SKILLS_DATA_MANAGER:GetActiveClassSkillLine(i)
            if skillLine and skillLine.id and not registeredSkillLines[skillLine.id] then
                tableInsert(skillLineIds, skillLine.id)
            end
        end
    else
        -- Fallback to the skill line info table if data is not ready to to ensure all skill line effects are set up
        for k, v in pairs(FancyActionBar.skillLineInfo) do
            for i, skillLineId in pairs(v) do
                tableInsert(skillLineIds, skillLineId)
            end
        end
    end

    if not skillLineIds or #skillLineIds == 0 then return end

    for i = 1, #skillLineIds do
        local skillLineId = skillLineIds[i]
        if not registeredSkillLines[skillLineId] then
            if FancyActionBar.specialClassEffects[skillLineId] then
                for j, x in pairs(FancyActionBar.specialClassEffects[skillLineId]) do
                    FancyActionBar.specialEffects[j] = ZO_DeepTableCopy(x)
                    if x.needCombatEvent then
                        EM:RegisterForEvent(NAME .. j, EVENT_COMBAT_EVENT, OnCombatEvent)
                        EM:AddFilterForEvent(NAME .. j, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, j, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
                    elseif x.handler and (x.handler == "reflect") then
                        EM:RegisterForEvent(NAME .. "Reflect" .. j, EVENT_COMBAT_EVENT, OnReflect)
                        EM:AddFilterForEvent(NAME .. "Reflect" .. j, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, j)
                    end
                end
            end

            if FancyActionBar.specialClassEffectProcs[skillLineId] then
                for j, x in pairs(FancyActionBar.specialClassEffectProcs[skillLineId]) do
                    FancyActionBar.specialEffectProcs[j] = x
                end
            end

            for id in pairs(FancyActionBar.needCombatEvent) do
                if FancyActionBar.needCombatEvent[id].skillLine == skillLineId then
                    EM:RegisterForEvent(NAME .. id, EVENT_COMBAT_EVENT, OnCombatEvent)
                    EM:AddFilterForEvent(NAME .. id, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
                end
            end

            if FancyActionBar.graveLordSacrifice and FancyActionBar.graveLordSacrifice.skillLine == skillLineId then
                EM:RegisterForEvent(NAME .. "GraveLordSacrifice", EVENT_COMBAT_EVENT, OnCombatEvent)
                EM:AddFilterForEvent(NAME .. "GraveLordSacrifice", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, FancyActionBar.graveLordSacrifice.eventId, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER_PET)
            end

            registeredSkillLines[skillLineId] = true
        end
    end
end

--- @param eventCode number
--- @param skillType SkillType
--- @param skillLineIndex luaindex
--- @param advised boolean
function FancyActionBar.OnSkillLineAdded(eventCode, skillType, skillLineIndex, advised)
    if skillType ~= SKILL_TYPE_CLASS then return end

    local skillLineId = GetSkillLineId(skillType, skillLineIndex)
    if not skillLineId or registeredSkillLines[skillLineId] then return end

    FancyActionBar.RegisterClassEffects(skillLineId)
end

function FancyActionBar.Initialize()
    SV = ZO_SavedVars:NewAccountWide("FancyActionBarSV", FancyActionBar.variableVersion, nil, defaultSettings, GetWorldName())
    CV = ZO_SavedVars:NewCharacterIdSettings("FancyActionBarSV", FancyActionBar.variableVersion, nil, FancyActionBar.defaultCharacter, GetWorldName())
    -- Initialize saved variables
    if SV.abMove == nil then
        SV.abMove = {}
    end

    if SV.abMove.kb == nil then
        SV.abMove.kb = { enable = false, x = 0, y = -22, prevX = 0, prevY = -22 }
    end

    if SV.abMove.gp == nil then
        SV.abMove.gp = { enable = false, x = 0, y = -75, prevX = 0, prevY = -75 }
    end
    if type(SV.effectWidgets) ~= "table" then
        SV.effectWidgets = {}
    end
    if type(CV.effectWidgets) ~= "table" then
        CV.effectWidgets = {}
    end

    if SV.qsScaling == nil then
        SV.qsScaling = defaultSettings.qsScaling
    end

    FancyActionBar.ValidateVariables()
    FancyActionBar.BuildStackMapLookups()

    FancyActionBar.useGamepadActionBar = IsInGamepadPreferredMode() or SV.forceGamepadStyle
    FancyActionBar.ApplyBarFoundation()
    FancyActionBar.constants.update = FancyActionBar.RefreshUpdateConfiguration()
    FancyActionBar.RefreshHighlightConfiguration()
    InstallActionButtonHooks()

    FancyActionBar.UpdateTextures()

    SLASH_COMMANDS[slashCommand] = FancyActionBar.SlashCommand

    FancyActionBar.UpdateDurationLimits()
    FancyActionBar:InitializeDebuffs(NAME, SV)
    FancyActionBar.BuildMenu(SV, CV, defaultSettings)
    FancyActionBar.BuildAbilityConfig()
    FancyActionBar.RefreshEffectWidgets()
    FancyActionBar.SetupGCD()
    FancyActionBar.ApplyDeathStateOption()
    debug = SV.debug

    FancyActionBar.player.name = zo_strformat("<<!aC:1>>", GetUnitName("player"))

    local function LockSkillsOnTrade()
        if TRADE_WINDOW.state == 3 then
            return false
        end
        if SM.currentScene:GetName() == "antiquityDigging" then
            return false
        end
        return true
    end

    local useSlotsOverride = true
    if PerfectWeave and SV.perfectWeave then
        useSlotsOverride = false
    end

    if useSlotsOverride then
        SecurePostHook("ZO_ActionBar_CanUseActionSlots", function ()
            if SV.lockInTrade then
                return LockSkillsOnTrade()
            end
        end)
    end

    EM:UnregisterForEvent("ZO_ActionBar", EVENT_ACTIVE_COMPANION_STATE_CHANGED)
    EM:RegisterForEvent(NAME, EVENT_ACTIVE_COMPANION_STATE_CHANGED, FancyActionBar.HandleCompanionUltimate)
    EM:RegisterForEvent(NAME, EVENT_ACTION_SLOT_ABILITY_USED, OnAbilityUsed)
    EM:RegisterForEvent(NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnActiveWeaponPairChanged)
    EM:RegisterForEvent(NAME, EVENT_HOTBAR_SLOT_UPDATED, OnSlotChanged)
    EM:RegisterForEvent(NAME, EVENT_HOTBAR_SLOT_STATE_UPDATED, OnHotbarSlotStateUpdated)
    EM:RegisterForEvent(NAME .. "GroundTargetEnter", EVENT_ENTER_GROUND_TARGET_MODE, OnGroundTargetModeEvent)
    EM:RegisterForEvent(NAME .. "GroundTargetCancel", EVENT_CANCEL_GROUND_TARGET_MODE, OnGroundTargetModeEvent)
    EM:RegisterForEvent(NAME, EVENT_ACTION_SLOT_EFFECT_UPDATE, OnActionSlotEffectUpdated)
    EM:RegisterForEvent(NAME, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, OnActiveHotbarUpdated)
    EM:RegisterForEvent(NAME, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnAllHotbarsUpdated)
    EM:RegisterForEvent(NAME, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, OnArmory)
    EM:RegisterForEvent(NAME .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, OnDeath)
    EM:AddFilterForEvent(NAME .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    EM:RegisterForEvent(NAME, EVENT_GAME_CAMERA_UI_MODE_CHANGED, function ()
        FancyActionBar.ChanneledAbilityEnd()
    end)
    EM:RegisterForEvent(NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, FancyActionBar.OnUIModeChanged)

    EM:RegisterForEvent(NAME, EVENT_WEREWOLF_STATE_CHANGED, function (_, value)
        FancyActionBar.isWerewolf = value
        if SV.hideLockedBar then
            applyWeaponLockPresentation(FancyActionBar.oakensoulEquipped or value)
        end
        FancyActionBar.SlotEffects(value and HOTBAR_CATEGORY_WEREWOLF or nil)
        FancyActionBar.SyncEffectState("slotted")
    end)

    EM:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EM:RegisterForEvent(NAME, EVENT_COLLECTIBLE_UPDATED, FancyActionBar.SkillStyleCollectibleUpdated)
    EM:RegisterForEvent(NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:AddFilterForEvent(NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    FancyActionBar.SetExternalBuffTracking()

    EM:RegisterForEvent(NAME, EVENT_ULTIMATE_ABILITY_COST_CHANGED, function ()
        FancyActionBar.UpdateUltimateCost()
        FancyActionBar.HandleCompanionUltimate()
    end)
    EM:RegisterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnEquippedGearChanged)
    EM:AddFilterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    EM:RegisterForEvent(NAME .. "CursorPickup", EVENT_CURSOR_PICKUP, function (_, cursorType, actionType, _, actionValue)
        if cursorType == MOUSE_CONTENT_ACTION and FancyActionBar.dropCalloutValidityByActionType[actionType] then
            ShowAppropriateAbilityActionButtonDropCallouts(actionType, actionValue)
        end
    end)
    EM:RegisterForEvent(NAME .. "CursorDropped", EVENT_CURSOR_DROPPED, function (_, cursorType)
        if cursorType == MOUSE_CONTENT_ACTION then
            HideAllAbilityActionButtonDropCallouts()
        end
    end)

    ZO_PreHookHandler(ACTION_BAR, "OnHide", function ()
        if not FancyActionBar.wasStopped then
            EM:UnregisterForUpdate(NAME .. "Update")
            FancyActionBar.wasStopped = true
        end
    end)

    ZO_PreHookHandler(ACTION_BAR, "OnShow", function ()
        if FancyActionBar.IsUnlocked() then
            return
        end

        FancyActionBar.RefreshBarPosition(FancyActionBar.wasStopped)

        if FancyActionBar.wasStopped then
            Update()
            EM:RegisterForUpdate(NAME .. "Update", updateRate, Update)
            FancyActionBar.wasStopped = false
        end
    end)

    ZO_PreHookHandler(CompanionUltimateButton, "OnShow", function ()
        if CompanionUltimateButton and (SV.hideCompanionUlt or (not ZO_ActionBar_GetButton(ULT_INDEX, HOTBAR_CATEGORY_COMPANION).hasAction or not DoesUnitExist("companion") or not HasActiveCompanion())) then
            CompanionUltimateButton:SetHidden(true)
        end
    end)

    -- Unregister some default stuff from action buttons.
    EM:UnregisterForEvent("ZO_ActionBar", EVENT_ACTION_SLOT_EFFECT_UPDATE)
    for i = MIN_INDEX, ULT_INDEX do
        EM:UnregisterForEvent("ActionButton" .. i, EVENT_INTERFACE_SETTING_CHANGED)
        EM:UnregisterForEvent("ActionBarTimer" .. i, EVENT_INTERFACE_SETTING_CHANGED)
    end

    for id in pairs(FancyActionBar.needCombatEvent) do
        if (not FancyActionBar.needCombatEvent[id].skillLine) then
            EM:RegisterForEvent(NAME .. id, EVENT_COMBAT_EVENT, OnCombatEvent)
            EM:AddFilterForEvent(NAME .. id, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end
    end

    for id, effect in pairs(FancyActionBar.specialEffects) do
        if effect.needCombatEvent then
            EM:RegisterForEvent(NAME .. id, EVENT_COMBAT_EVENT, OnCombatEvent)
            EM:AddFilterForEvent(NAME .. id, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end
    end

    for id, effect in pairs(FancyActionBar.specialEffects) do
        if effect.handler and (effect.handler == "reflect") then
            EM:RegisterForEvent(NAME .. "Reflect" .. id, EVENT_COMBAT_EVENT, OnReflect)
            EM:AddFilterForEvent(NAME .. "Reflect" .. id, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id)
        end
    end

    FancyActionBar.RegisterClassEffects()
    EM:RegisterForEvent(NAME, EVENT_SKILL_LINE_ADDED, FancyActionBar.OnSkillLineAdded)
    -- EM:RegisterForEvent(NAME, EVENT_ABILITY_LIST_CHANGED, FancyActionBar.RegisterClassEffects)

    -- ZO_PreHook('ZO_ActionBar_OnActionButtonDown', function(slotNum)
    --   FancyActionBar.AddSystemMessage('ActionButton' .. slotNum .. ' pressed.')
    --   return false
    -- end)
    if not ZO_IsConsoleOrGameCoreUI() then
        SetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_BACK_ROW, "false")
        SetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_TIMERS, "false")
    end
end

function FancyActionBar.OnAddOnLoaded(event, addonName)
    if addonName == NAME then
        EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
        FancyActionBar.Initialize()
    end
end

local function ValidateSavedVariables(d)
    local sv = SV
    d = d or defaultSettings

    local settings =
    {
        "dynamicAbilityConfig",
        "effectWidgets",
        "showDecimal",
        "alphaInactive",
        "desaturationInactive",
        "tintInactive",
        "applyActiveBarAlpha",
        "applyActiveBarDesaturation",
        "applyActiveBarTint",
        "alphaUsable",
        "alphaUnusable",
        "desatUsable",
        "desatUnusable",
        "tintUsable",
        "tintUnusable",
        "overlayFrameAlphaActive",
        "overlayBgAlphaActive",
        "overlayFrameAlphaInactive",
        "overlayBgAlphaInactive",
        "showDecimalStart",
        "showExpire",
        "showExpireStart",
        "expireColor",
        "showTickExpire",
        "showTickStart",
        "tickColor",
        "allowParentTime",
        "forceGamepadStyle",
        "keyboardBounceAnimation",
        "useThinFrames",
        "showFrames",
        "frameColor",
        "showMarker",
        "markerSize",
        "showHighlight",
        "highlightColor",
        "highlightExpire",
        "highlightExpireColor",
        "toggledHighlight",
        "toggledColor",
        "showArrow",
        "arrowColor",
        "moveQS",
        "moveHealthBar",
        "moveResourceBars",
        "moveBuffs",
        "moveSynergy",
        "forceReposition",
        "showStackCount",
        "showOvertauntStacks",
        "showTargetCount",
        "showSingleTargetInstance",
        "applyActionBarSkillStyles",
        "showCastDuration",
        "showToggleTicks",
        "ignoreTrapPlacement",
        "useSplitShalksTimers",
        "showSoonestExpire",
        "ignoreUngroupedAliies",
        "hideLockedBar",
        "repositionActiveBar",
        "hideCompanionUlt",
        "debug",
        "showToggle",
        "toggleColor",
        "hideInactiveSlots"
    }

    for _, setting in ipairs(settings) do
        if sv[setting] == nil then
            sv[setting] = d[setting]
        end
    end

    FancyActionBar.EnsureUserUIPresetsStored(sv)

    local ultHighlightDefaults =
    {
        showUltHighlight = "showHighlight",
        ultHighlightColor = "highlightColor",
        ultHighlightExpire = "highlightExpire",
        ultHighlightExpireColor = "highlightExpireColor",
        ultToggledHighlight = "toggledHighlight",
        ultToggledColor = "toggledColor",
    }

    for ultKey, sourceKey in pairs(ultHighlightDefaults) do
        if sv[ultKey] == nil then
            sv[ultKey] = sv[sourceKey] ~= nil and sv[sourceKey] or d[sourceKey]
        end
    end

    -- External blacklist validation
    if not sv.externalBlackListRun then
        -- just add all resto staff skills by default and player can take it from there.
        sv.externalBlackList =
        {
            [28385] = true,  -- "Grand Healing"
            [40058] = true,  -- "Illustrious Healing"
            [40060] = true,  -- "Healing Springs"
            [28536] = true,  -- "Regeneration"
            [40076] = true,  -- "Rapid Regeneration"
            [40079] = true,  -- "Radiating Regeneration"
            [29224] = true,  -- "Igneous Shield"
            [31531] = true,  -- "Force Siphon"
            [37232] = true,  -- "Steadfast Ward"
            [38552] = true,  -- "Panacea"
            [40109] = true,  -- "Siphon Spirit"
            [40116] = true,  -- "Quick Siphon"
            [40126] = true,  -- "Healing Ward"
            [40130] = true,  -- "Ward Ally"
            [61504] = true,  -- "Vigor"
            [61506] = true,  -- "Echoing Vigor"
            [61665] = true,  -- "Major Brutality"
            [61687] = true,  -- "Major Sorcery"
            [61693] = true,  -- "Minor Resolve"
            [61694] = true,  -- "Major Resolve"
            [61697] = true,  -- "Minor Fortitude"
            [61704] = true,  -- "Minor Endurance"
            [61706] = true,  -- "Minor Intellect"
            [61721] = true,  -- "Minor Protection"
            [76518] = true,  -- "Major Brutality"
            [83850] = true,  -- "Life Giver"
            [85132] = true,  -- "Lights Champion"
            [88758] = true,  -- "Major Resolve"
            [92503] = true,  -- "Major Sorcery"
            [176991] = true, -- "Minor Resolve"
            [186493] = true, -- "Minor Protection"
        }
        sv.externalBlackListRun = true
    end
    -- Update external blacklist with new abilities from config
    for abilityId, value in pairs(FancyActionBar.externalBlacklistUpdates) do
        if not sv.externalBlackList[abilityId] and value then
            sv.externalBlackList[abilityId] = GetAbilityName(abilityId)
        elseif sv.externalBlackList[abilityId] and not value then
            sv.externalBlackList[abilityId] = nil
        end
    end

    -- Multi-target blacklist validation
    if not sv.multiTargetBlackListRun then
        sv.multiTargetBlacklist =
        {
            [18746] = true, -- "Mages' Fury"
            [19118] = true, -- "Endless Fury"
            [19125] = true, -- "Mages' Wrath"
            [24326] = true, -- "Daedric Curse"
            [24328] = true, -- "Daedric Prey"
            [24330] = true, -- "Haunting Curse"
            [40229] = true, -- "Siege Weapon Shield"
            [51392] = true, -- "Bolt Escape Fatigue"
        }
        sv.multiTargetBlackListRun = true
    end
    -- Update multi-target blacklist with new abilities from config
    for abilityId, value in pairs(FancyActionBar.multiTargetBlacklistUpdates) do
        if not sv.multiTargetBlacklist[abilityId] and value then
            sv.multiTargetBlacklist[abilityId] = GetAbilityName(abilityId)
        elseif sv.multiTargetBlacklist[abilityId] and not value then
            sv.multiTargetBlacklist[abilityId] = nil
        end
    end

    -- Parent/Fallback time blacklist validation
    if not sv.parentTimeBlackListRun then
        sv.parentTimeBlacklist =
        {
            [39089] = true,  -- ele sus
            [117805] = true, -- boneyard
            [39192] = true,  -- elude
            [183648] = true, -- fatewoven armor
            [185908] = true, -- cruxweaver armor
            [186477] = true, -- unbreakable fate
            [238256] = true, -- vengeance fatewoven armor
            [118680] = true, -- skeletal arcanist
            [28858] = true,  -- wall of elements
            [39052] = true,  -- unstable wall of elements
            [39011] = true,  -- elemental blockade
            [28807] = true,  -- wall of elements (fire)
            [28854] = true,  -- wall of elements (lightning)
            [28849] = true,  -- wall of elements (frost)
            [39053] = true,  -- unstable wall of elements (fire)
            [39073] = true,  -- unstable wall of elements (lightning)
            [39067] = true,  -- unstable wall of elements (frost)
            [39012] = true,  -- elemental blockade (fire)
            [39018] = true,  -- elemental blockade (lightning)
            [39028] = true,  -- elemental blockade (frost)
            [31888] = true,  -- molten armaments
            [86050] = true,  -- betty netch
            [86054] = true,  -- blue betty
            [86058] = true,  -- bull netch
            [24326] = true,  -- Daedric Curse
            [24328] = true,  -- Daedric Prey
        }
        sv.parentTimeBlackListRun = true
    end
    -- Update Parent/Fallback with new abilities from config
    for abilityId, value in pairs(FancyActionBar.parentTimeBlacklistUpdates) do
        if not sv.parentTimeBlacklist[abilityId] and value then
            sv.parentTimeBlacklist[abilityId] = GetAbilityName(abilityId)
        elseif sv.parentTimeBlacklist[abilityId] and not value then
            sv.parentTimeBlacklist[abilityId] = nil
        end
    end

    if IsInGamepadPreferredMode() or sv.forceGamepadStyle then
        local oldToNewMappings =
        {
            fontName = "fontNameGP",
            fontSize = "fontSizeGP",
            fontType = "fontTypeGP",
            timerY = "timerYGP",
            ultimateSlotCustomXOffset = "ultimateSlotCustomXOffsetGP",
            ultimateSlotCustomYOffset = "ultimateSlotCustomYOffsetGP",
            quickSlotCustomXOffset = "quickSlotCustomXOffsetGP",
            quickSlotCustomYOffset = "quickSlotCustomYOffsetGP"
        }

        for old, new in pairs(oldToNewMappings) do
            if sv[old] then
                sv[new] = sv[old]
                sv[old] = nil
            end
        end

        -- Set default values if nil
        d =
        {
            fontNameGP = d.fontNameGP,
            fontSizeGP = d.fontSizeGP,
            fontTypeGP = d.fontTypeGP,
            timeYGP = d.timeYGP,
            fontNameStackGP = d.fontNameStackGP,
            fontSizeStackGP = d.fontSizeStackGP,
            fontTypeStackGP = d.fontTypeStackGP,
            stackXGP = d.stackXGP,
            stackYGP = d.stackYGP,
            fontNameTargetGP = d.fontNameTargetGP,
            fontSizeTargetGP = d.fontSizeTargetGP,
            fontTypeTargetGP = d.fontTypeTargetGP,
            targetXGP = d.targetXGP,
            targetYGP = d.targetYGP,
            abilitySlotOffsetXGP = d.abilitySlotOffsetXGP,
            barXOffsetGP = d.barXOffsetGP,
            barYOffsetGP = d.barYOffsetGP,
            ultimateSlotCustomXOffsetGP = d.ultimateSlotCustomXOffsetGP,
            ultimateSlotCustomYOffsetGP = d.ultimateSlotCustomYOffsetGP,
            quickSlotCustomXOffsetGP = d.quickSlotCustomXOffsetGP,
            quickSlotCustomYOffsetGP = d.quickSlotCustomYOffsetGP,
            ultValueThresholdGP = d.ultValueThresholdGP,
            ultUsableThresholdColorGP = d.ultUsableThresholdColorGP,
            ultUsableValueColorGP = d.ultUsableValueColorGP,
            ultMaxValueColorGP = d.ultMaxValueColorGP
        }

        for setting, default in pairs(d) do
            if sv[setting] == nil then
                sv[setting] = default
            end
        end
    end

    if not (IsInGamepadPreferredMode() or sv.forceGamepadStyle) then
        -- Migrate old settings
        local oldToNewMappings =
        {
            fontName = "fontNameKB",
            fontSize = "fontSizeKB",
            fontType = "fontTypeKB",
            timerY = "timerYKB",
            ultimateSlotCustomXOffset = "ultimateSlotCustomXOffsetKB",
            ultimateSlotCustomYOffset = "ultimateSlotCustomYOffsetKB",
            quickSlotCustomXOffset = "quickSlotCustomXOffsetKB",
            quickSlotCustomYOffset = "quickSlotCustomYOffsetKB"
        }

        for old, new in pairs(oldToNewMappings) do
            if sv[old] then
                sv[new] = sv[old]
                sv[old] = nil
            end
        end

        -- Set default values if nil
        d =
        {
            fontNameKB = d.fontNameKB,
            fontSizeKB = d.fontSizeKB,
            fontTypeKB = d.fontTypeKB,
            timeYKB = d.timeYKB,
            fontNameStackKB = d.fontNameStackKB,
            fontSizeStackKB = d.fontSizeStackKB,
            fontTypeStackKB = d.fontTypeStackKB,
            stackXKB = d.stackXKB,
            stackYKB = d.stackYKB,
            fontNameTargetKB = d.fontNameTargetKB,
            fontSizeTargetKB = d.fontSizeTargetKB,
            fontTypeTargetKB = d.fontTypeTargetKB,
            targetXKB = d.targetXKB,
            targetYKB = d.targetYKB,
            abilitySlotOffsetXKB = d.abilitySlotOffsetXKB,
            barXOffsetKB = d.barXOffsetKB,
            barYOffsetKB = d.barYOffsetKB,
            ultimateSlotCustomXOffsetKB = d.ultimateSlotCustomXOffsetKB,
            ultimateSlotCustomYOffsetKB = d.ultimateSlotCustomYOffsetKB,
            quickSlotCustomXOffsetKB = d.quickSlotCustomXOffsetKB,
            quickSlotCustomYOffsetKB = d.quickSlotCustomYOffsetKB,
            ultValueThresholdKB = d.ultValueThresholdKB,
            ultUsableThresholdColorKB = d.ultUsableThresholdColorKB,
            ultUsableValueColorKB = d.ultUsableValueColorKB,
            ultMaxValueColorKB = d.ultMaxValueColorKB
        }

        for setting, default in pairs(d) do
            if sv[setting] == nil then
                sv[setting] = default
            end
        end
    end

    if sv.abScaling == nil then
        sv.abScaling = d.abScaling
    end

    if sv.ultScaling == nil then
        sv.ultScaling = d.ultScaling
    end

    if sv.qsScaling == nil then
        sv.qsScaling = d.qsScaling
    end

    -- Migrate old scaling settings
    if SV.scaleEnable then
        sv.abScaling.kb.enable = sv.scaleEnable
        sv.abScaling.gp.enable = sv.scaleEnable
        sv.scaleEnable = nil
    end

    if sv.abScale then
        sv.abScaling.kb.scale = sv.abScale
        sv.abScaling.gp.scale = sv.abScale
        sv.abScale = nil
    end
end

function FancyActionBar.ValidateVariables() -- all about safety checks these days..
    local d = defaultSettings
    local sv = SV

    -- Validate SV settings
    if SV.dynamicAbilityConfig == false then
        if SV.abilityConfig then
            SV.abilityConfig = nil
        end
        SV.dynamicAbilityConfig = true
    end

    -- Validate CV settings
    if CV.dynamicAbilityConfig == false then
        if CV.abilityConfig then
            CV.abilityConfig = nil
        end
        CV.dynamicAbilityConfig = true
    end

    EnsureAbilityConfigProfiles(SV)
    EnsureAbilityConfigProfiles(CV)

    -- Main validation flow
    if sv.variablesValidated == false or sv.addonVersion ~= FancyActionBar.GetVersion() then
        ValidateSavedVariables(d)

        -- Update validation status
        sv.variablesValidated = true
        sv.addonVersion = FancyActionBar.GetVersion()
    end
end

EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, FancyActionBar.OnAddOnLoaded)

