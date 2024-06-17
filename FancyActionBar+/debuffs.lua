---@class (partial) FancyActionBar
local FancyActionBar = FancyActionBar;

local EM = GetEventManager();
local WM = GetWindowManager();
local SM = SCENE_MANAGER;
local NAME;
local SV;
local time = GetFrameTimeSeconds;
local currentTarget = { name = ""; id = 0 };
local targetDebuffs = {};
local activeDebuffs = {};
local debuffTargets = {};
local enemyDebuffs = {};

---@param msg string
---@param ... any
local function Chat(msg, ...)
  FancyActionBar.Chat(msg, ...);
end;


local groupUnit = {
  ["group1"] = true;
  ["group2"] = true;
  ["group3"] = true;
  ["group4"] = true;
  ["group5"] = true;
  ["group6"] = true;
  ["group7"] = true;
  ["group8"] = true;
  ["group9"] = true;
  ["group10"] = true;
  ["group11"] = true;
  ["group12"] = true;
  ["group13"] = true;
  ["group14"] = true;
  ["group15"] = true;
  ["group16"] = true;
  ["group17"] = true;
  ["group18"] = true;
  ["group19"] = true;
  ["group20"] = true;
  ["group21"] = true;
  ["group22"] = true;
  ["group23"] = true;
  ["group24"] = true;
};
---------------------------------
-- Debug
---------------------------------
local function OnNewTarget()
  local tag = "reticleover";

  local name = zo_strformat("<<t:1>>", GetUnitName(tag));
  Chat(name .. " -> " .. GetUnitType(tag) .. " -> " .. GetUnitNameHighlightedByReticle());
end;

-- /script zo_callLater(function() Chat(tostring(GetUnitType('reticleover'))) end, 2000)
local function PostReticleTargetInfo(uName, eName, gain, fade, eSlot, stacks, icon, bType, eType, aType, seType, aId, canClickOff, castByPlayer)
  -- if aType == 0 then return end -- passives (annoying when bar swapping)

  local ts = tostring;
  local dur, s;
  if (fade ~= nil and gain ~= nil) then
    dur = string.format(" %0.1f", fade - gain) .. "s";
  else
    dur = 0;
  end;

  if (stacks and stacks > 0)
  then
    s = " x" .. ts(stacks) .. ".";
  else
    s = ".";
  end;

  Chat(eName .. " (" .. ts(aId) .. ")" .. " || stacks: " .. ts(stacks) .. " || duration: " .. ts(dur) .. " || slot: " .. ts(eSlot) .. " || unit: " .. ts(uName) .. " || effectType: " .. ts(eType) .. " || abilityType: " .. ts(aType) .. " || statusEffectType: " .. ts(seType) .. "\n===================");
end;
---------------------------------
-- Checking
---------------------------------
function FancyActionBar.IsAbilityActiveOnCurrentTarget(id)
  if not FancyActionBar.HasEnemyTarget() then return false; end;

  local isActive = false;
  local nBuffs = GetNumBuffs("reticleover");
  local data = { endTime = 0; stacks = 0 };

  if nBuffs > 0 then
    for i = 1, nBuffs do
      local _, _, endTime, _, stacks, _, _, _, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo("reticleover", i);
      if abilityId == id and (castByPlayer or stacks) then
        isActive = true;
        data.endTime = endTime;
        data.stacks = stacks or 0;
        break;
      end;
    end;
  end;

  if isActive
  then
    return true, data;
  else
    return false;
  end;
end;

-- function FancyActionBar.IsToggled(id)
--   return toggled[id] and true or false
-- end

function FancyActionBar.IsGroupUnit(tag)
  if tag == nil or tag == "" then return false; end;
  if groupUnit[tag] ~= nil then return true; else return false; end;
end;

function FancyActionBar.IsPlayer(tag, name)
  if tag == nil or tag == "" then return false; end;
  if AreUnitsEqual("player", tag) then return true; end;
  return false;
end;

function FancyActionBar.IsEnemy(tag, id)
  if FancyActionBar.IsGroupUnit(tag) then return false; end;

  local isEnemy = false;

  if tag ~= nil and tag ~= "" then
    if GetUnitType(tag) == 12 then
      isEnemy = true; -- target dummy
    else
      local reaction = GetUnitReaction(tag);
      if (reaction == 1) then isEnemy = true; end;
    end;
  end;
  return isEnemy;
end;

function FancyActionBar.IsLocalPlayerOrEnemy(tag, name, id)
  if FancyActionBar.IsEnemy(tag) then return true; end;
  if FancyActionBar.IsPlayer(tag) then return true; end;
  return false;
end;

function FancyActionBar.HasEnemyTarget()
  local tag = "reticleover";

  if (DoesUnitExist(tag) and not IsUnitDead(tag)) then
    if FancyActionBar.IsEnemy(tag, nil) then return true; end;
  end;
  return false;

  -- return (currentTarget.name == '') and false or true
end;

---------------------------------
-- Tracking
---------------------------------

local function ClearTargetEffects()
  for debuffId, debuff in pairs(FancyActionBar.debuffs) do
    local doStackUpdate = false;
    if FancyActionBar.stacks[debuff.id] then
      FancyActionBar.stacks[debuff.id] = 0;
      doStackUpdate = true;
    end;

    for effectId, effect in pairs(FancyActionBar.effects) do
      if debuff.id == effect.id then
        effect.endTime = time();
      end;
      FancyActionBar.UpdateEffect(effect);
      if doStackUpdate then
        FancyActionBar.HandleStackUpdate(debuff.id);
      end;
    end;
  end;
end;

local function ClearDebuffsIfNotOnTarget()
  for id, debuff in pairs(FancyActionBar.debuffs) do
    debuff.activeOnTarget = false;
    debuff.endTime = 0;
    local doStackUpdate = false;
    if FancyActionBar.stacks[debuff.id] then
      doStackUpdate = true;
      FancyActionBar.stacks[debuff.id] = 0;
    end;
    for id, effect in pairs(FancyActionBar.effects) do
      if debuff.id == effect.id then
        for i, x in pairs(debuff) do effect[i] = x; end;
        effect.endTime = time();
      end;
      FancyActionBar.UpdateEffect(effect);
      if doStackUpdate then
        FancyActionBar.HandleStackUpdate(effect.id);
      end;
    end;
  end;
end;

local function ClearAllDebuffs()
  ClearTargetEffects();
  activeDebuffs = {};
  FancyActionBar.debuffs = {};
  debuffTargets = {};
  enemyDebuffs = {};
end;

-- local function GetActiveDebuff(abilityId, unitId)
--   local debuff = activeDebuffs[abilityId]
--
--   if debuff == nil then return nil end
--
--   local debuffKey = ZO_CachedStrFormat('<<1>>,<<2>>', abilityId, unitId)
--
--   local target = debuff[debuffKey]
--   if target ~= nil then
--     return target
--   end
--   return nil
-- end

-- local function TrackDebuff(effect, abilityId, endTime, stacks, name, id)
--   if not effect then return end
--
--   if not activeDebuffs[abilityId] then
--     local db  = { id = effect.id, targets = {} }
--     activeDebuffs[abilityId] = db
--   end
--
--   local debuff = activeDebuffs[abilityId]
--
--   if id == nil then id = 0 end
--
--   local debuffKey = ZO_CachedStrFormat('<<1>>,<<2>>', abilityId, id)
--
--   if not debuff.targets[debuffKey] then
--     local e = { endTime = 0, stacks = 0, id = 0, name = '' }
--     debuff.targets[debuffKey] = e
--   end
--
--   local target    = debuff.targets[debuffKey]
--
--   target.endTime  = endTime
--   target.stacks   = stacks
--   target.id       = id or 0
--   target.name     = name
-- end

-- local function CancelDebuff(abilityId, name, id)
--   local debuff = activeDebuffs[abilityId]
--
--   if debuff then
--     local debuffKey = ZO_CachedStrFormat('<<1>>,<<2>>', abilityId, id)
--     if debuff[debuffKey] then
--       debuff[debuffKey] = nil
--     end
--   end
-- end

-- local function IsTargetDebuff(abilityId, t, endTime, name, id)
--   local isTarget = false
--   local debuff = activeDebuffs[abilityId]
--   if debuff then
--     local debuffKey = ZO_CachedStrFormat('<<1>>,<<2>>', abilityId, id)
--     local target = debuff[debuffKey]
--     if target then
--       if target.endTime == endTime then
--         isTarget = true
--       else
--         if target.endTime <= t then
--           debuff[debuffKey] = nil
--         end
--       end
--     end
--   end
--   return isTarget
-- end

local numEffects = 0;
---@return table, number
local function GetTargetEffects()
  local tag = "reticleover";

  numEffects = GetNumBuffs(tag);

  local debuffs = {};
  local debuffNum = 0;

  if numEffects <= 0 then
    return nil, 0;
  else
    for i = 1, numEffects do
      local abilityName, startTime, endTime, buffSlot, stacks, icon, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo(tag, i);

      if castByPlayer or (FancyActionBar.specialEffects[abilityId] and FancyActionBar.specialEffects[abilityId].forceShow) then
        -- PostReticleTargetInfo(name, abilityName, startTime, endTime, buffSlot, stacks, icon, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer)

        debuffNum = debuffNum + 1;
        local db = {
          id = abilityId;
          startTime = startTime or 0;
          endTime = endTime or 0;
          stacks = stacks or 0;
        };
        table.insert(debuffs, db);
      end;
    end;
  end;
  return debuffs, debuffNum;
end;

local function UpdateDebuff(debuff, t, stacks, unitId, isTarget)
  if not debuff then return; end;
  local doStackUpdate = false;
  local idsToUpdate = {};
  debuff.endTime = t;

  if debuff.id == debuff.stackId then
    debuff.stacks = stacks;
    FancyActionBar.stacks[debuff.stackId] = stacks;
    doStackUpdate = true;
  end;

  for id, effect in pairs(FancyActionBar.effects) do
    if effect.id == debuff.id then
      for eId, effects in pairs(debuff) do effect[eId] = effects; end;
      FancyActionBar.effects[id] = effect;
      FancyActionBar.UpdateEffect(effect);
      idsToUpdate[id] = true;
    end;
  end;
  if doStackUpdate then
    for id in pairs(idsToUpdate) do
      FancyActionBar.HandleStackUpdate(id);
    end;
  end;
end;

local function OnReticleTargetChanged()
  local tag = "reticleover";

  if (DoesUnitExist(tag) and not IsUnitDead(tag)) then
    if not FancyActionBar.IsEnemy(tag) then return; end; -- GetUnitType(tag), GetUnitNameHighlightedByReticle()

    local name = zo_strformat("<<t:1>>", GetUnitName(tag));
    local tId = 0;
    local keep = {};

    currentTarget.name = name;

    local debuffs, debuffNum = GetTargetEffects();

    if debuffNum > 0 then
      for i = 1, debuffNum do
        local debuff = debuffs[i];

        for stackSourceId, targetIds in pairs(FancyActionBar.stackMap) do
          for t = 1, #targetIds do
            if targetIds[t] == debuff.id then
              debuff.stackId = stackSourceId;
            end;
          end;
        end;

        local specialEffect = FancyActionBar.specialEffects[debuff.id];

        if specialEffect then
          keep[debuff.id] = true; -- make sure we're keeping the debuff in case the specialEffect changes the id
          for sId, effects in pairs(specialEffect) do debuff[sId] = effects; end;
          if specialEffect.fixedTime and debuff.startTime ~= 0 then
            debuff.endTime = debuff.startTime + specialEffect.fixedTime;
          end;
        end;

        if debuff.id == debuff.stackId then
          FancyActionBar.stacks[debuff.id] = debuff.stacks;
        else
          debuff.stacks = FancyActionBar.stacks[debuff.stackId] or debuff.stacks;
        end;

        keep[debuff.id] = true;

        -- update durations for active effects on the target.
        if FancyActionBar.debuffs[debuff.id] or specialEffect then
          FancyActionBar.debuffs[debuff.id] = debuff;
          FancyActionBar.debuffs[debuff.id].activeOnTarget = true;
          FancyActionBar.debuffs[debuff.id].endTime = debuff.endTime;
          UpdateDebuff(FancyActionBar.debuffs[debuff.id], debuff.endTime, debuff.stacks, tId, true);
        end;
      end;
    end;

    for id, debuff in pairs(FancyActionBar.debuffs) do
      if FancyActionBar.traps[id] then return; end;
      if keep[id] == nil then -- update debuffs that are not active on the target according to settings.
        debuff.activeOnTarget = false;
        debuff.endTime = 0;
        UpdateDebuff(FancyActionBar.debuffs[id], debuff.endTime, 0, tId, false);
      end;
    end;
    -- OnNewTarget()
  else
    currentTarget = { name = ""; id = 0 };
    if SV.keepLastTarget == false then
      ClearDebuffsIfNotOnTarget();
    end;
  end;
end;

function FancyActionBar.OnDebuffChanged(debuff, t, eventCode, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
  local tag = "";
  if unitTag ~= nil and unitTag ~= "" then tag = unitTag; end;

  -- if ((effect.activeOnTarget and tag ~= 'reticleover') or (not effect.activeOnTarget and effect.hideOnNoTarget)) then
  --   FancyActionBar:dbg(1, '<<1>> duration <<2>>s ignored on: <<3>>.', effectName, string.format(' %0.1f', endTime - t), tag )
  --   return
  -- end

  if tag ~= "reticleover" then return; end;

  local specialEffect = FancyActionBar.specialEffects[abilityId];

  debuff.stacks = stackCount;
  debuff.endTime = endTime;

  for stackSourceId, targetIds in pairs(FancyActionBar.stackMap) do
    for i = 1, #targetIds do
      if targetIds[i] == abilityId then
        debuff.stackId = stackSourceId;
      end;
    end;
  end;

  if change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
    if specialEffect then
      for i, x in pairs(specialEffect) do debuff[i] = x; end;
      if specialEffect.fixedTime then
        endTime = t + specialEffect.fixedTime;
        debuff.endTime = endTime;
      end;
    end;

    if debuff.id == debuff.stackId then
      FancyActionBar.stacks[debuff.id] = debuff.stacks;
    end;

    debuff.stacks = FancyActionBar.stacks[debuff.stackId] or debuff.stacks;

    FancyActionBar.debuffs[debuff.id] = debuff;
    if FancyActionBar.activeCasts[debuff.id] then FancyActionBar.activeCasts[debuff.id].begin = beginTime; end;

    if (endTime > t + FancyActionBar.durationMin and endTime < t + FancyActionBar.durationMax) or (debuff.duration > FancyActionBar.durationMin) then
      UpdateDebuff(debuff, debuff.endTime, debuff.stacks, unitId, true);
    else
      FancyActionBar:dbg(1, "<<1>> duration <<2>>s ignored.", effectName, string.format(" %0.1f", endTime - t));
    end;
  elseif (change == EFFECT_RESULT_FADED) then
    if (debuff and debuff.hasProced) and specialEffect then
      if debuff.hasProced > specialEffect.hasProced then
        return; -- we don't need to worry about this effect anymore because it has already proced
      elseif FancyActionBar.specialEffectProcs[abilityId] then
        -- Get the debuff data for the parent ability if we're handing a seconday proc, and the necessicary updates
        debuff = FancyActionBar.debuffs[specialEffect.id];
        local procUpddates = FancyActionBar.specialEffectProcs[abilityId];
        local procValues = procUpddates[debuff.procs];
        for i, x in pairs(procValues) do debuff[i] = x; end;
        if debuff.stacks then
          FancyActionBar.stacks[debuff.stackId] = debuff.stacks;
        end;
      end;
    end;

    if (FancyActionBar.activeCasts[debuff.id] and FancyActionBar.activeCasts[debuff.id].begin < (t - 0.7)) then
      if debuff.instantFade
      then
        debuff.endTime = 0;
      else
        debuff.endTime = t;
      end;
    end;
    UpdateDebuff(debuff, debuff.endTime, debuff.stacks, unitId, false);
  end;
end;

-- function FancyActionBar.OnDebuffTargetDeath( eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId )
--
--   if targetUnitId == nil or targetUnitId == 0 then return end
--
--   if result ~= ACTION_RESULT_DIED and result ~= ACTION_RESULT_DIED_XP then return end
--
-- end

local function ClearDebuffsOnCombatEnd()
  local t = time();
  if not IsUnitInCombat("player") then
    for i, x in pairs(FancyActionBar.debuffs) do
      local debuff = FancyActionBar.debuffs[i];
      if debuff then
        if debuff.endTime > t then
          if FancyActionBar.specialEffects[debuff.id] then
            if FancyActionBar.specialEffects[debuff.id].fixedTime then
            else
              debuff.endTime = t;
              UpdateDebuff(debuff, t, 0, 0, false);
            end;
          end;
          debuff.endTime = t;
          UpdateDebuff(debuff, t, 0, 0, false);
        end;
      end;
    end;
    ClearAllDebuffs();
  end;
end;

function FancyActionBar:UpdateDebuffTracking()
  ClearAllDebuffs();


  -- EVENT_TARGET_CHANGED (number eventCode, string unitTag)
  -- EVENT_RETICLE_TARGET_CHANGED (number eventCode)
  -- EVENT_RETICLE_TARGET_PLAYER_CHANGED (number eventCode)
  EM:UnregisterForEvent(NAME .. "ReticleTaget", EVENT_RETICLE_TARGET_CHANGED);
  EM:UnregisterForEvent(NAME .. "DebuffCombat", EVENT_PLAYER_COMBAT_STATE);
  -- EM:UnregisterForEvent(NAME .. "EnemyDeath_1", EVENT_COMBAT_EVENT)
  -- EM:UnregisterForEvent(NAME .. "EnemyDeath_2", EVENT_COMBAT_EVENT)

  if SV.advancedDebuff then
    EM:RegisterForEvent(NAME .. "DebuffCombat", EVENT_PLAYER_COMBAT_STATE, ClearDebuffsOnCombatEnd);
    EM:RegisterForEvent(NAME .. "ReticleTaget", EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged);

    -- EM:RegisterForEvent(  NAME .. "EnemyDeath_1", EVENT_COMBAT_EVENT, FancyActionBar.OnDebuffTargetDeath )
    -- EM:AddFilterForEvent( NAME .. "EnemyDeath_1", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DIED,    REGISTER_FILTER_IS_ERROR, false )
    --
    -- EM:RegisterForEvent(  NAME .. "EnemyDeath_2", EVENT_COMBAT_EVENT, FancyActionBar.OnDebuffTargetDeath )
    -- EM:AddFilterForEvent( NAME .. "EnemyDeath_2", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DIED_XP, REGISTER_FILTER_IS_ERROR, false )
  end;
end;

function FancyActionBar:InitializeDebuffs(name, sv)
  NAME = name;
  SV = sv;
  FancyActionBar:UpdateDebuffTracking();
end;
