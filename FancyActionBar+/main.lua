---@class (partial) FancyActionBar
local FancyActionBar = FancyActionBar;
-------------------------------------------------------------------------------
-----------------------------[    Constants   ]--------------------------------
-------------------------------------------------------------------------------
local NAME = "FancyActionBar+";
local VERSION = "2.6.0";
local slashCommand = "/fab" or "/FAB";
local EM = GetEventManager();
local WM = GetWindowManager();
local SM = SCENE_MANAGER;
local strformat = string.format;
local time = GetFrameTimeSeconds;
local MIN_INDEX = 3;                          -- first ability index
local MAX_INDEX = 7;                          -- last ability index
local ULT_INDEX = 8;                          -- ultimate slot index
local SLOT_INDEX_OFFSET = 20;                 -- offset for backbar abilities indices
local COMPANION_INDEX_OFFSET = 30;            -- offset for companion ultimate
local SLOT_COUNT = MAX_INDEX - MIN_INDEX + 1; -- total number of slots
local ULT_SLOT = 8;                           -- ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
local QUICK_SLOT = 9;                         -- ACTION_BAR_FIRST_UTILITY_BAR_SLOT + 1
local COMPANION = HOTBAR_CATEGORY_COMPANION;
local ACTION_BAR = GetControl("ZO_ActionBar1");
local FAB_ActionBarFakeQS = GetControl("FAB_ActionBarFakeQS");
local currentWeaponPair = GetActiveWeaponPairInfo();
local currentHotbarCategory = GetActiveHotbarCategory();
local GAMEPAD_CONSTANTS = {
  dimensions = 64;
  flipCardSize = 61;
  ultFlipCardSize = 67;
  abilitySlotWidth = 64;
  abilitySlotOffsetX = 10;
  buttonTextOffsetY = 60;
  actionBarOffset = -52;
  attributesOffset = -152;
  width = 606;
  anchorOffsetY = -25;
  ultimateSlotOffsetX = 12; --65,
  ultSize = 70;
  quickslotOffsetX = 5;
  bindingTextOnUlt = false;
  showKeybindBG = false;
  buttonTemplate = "ZO_ActionButton_Gamepad_Template";
  ultButtonTemplate = "ZO_UltimateActionButton_Gamepad_Template";
  overlayTemplate = "FAB_ActionButtonOverlay_Gamepad_Template";
  ultOverlayTemplate = "FAB_UltimateButtonOverlay_Gamepad_Template";
  qsOverlayTemplate = "FAB_QuickSlotOverlay_Gamepad_Template";
};
local KEYBOARD_CONSTANTS = {
  dimensions = 50;
  flipCardSize = 47;
  ultFlipCardSize = 47;
  abilitySlotWidth = 50;
  abilitySlotOffsetX = 2;
  buttonTextOffsetY = 50;
  actionBarOffset = -22;
  attributesOffset = -112;
  width = 483;
  anchorOffsetY = 0;
  ultimateSlotOffsetX = 8; --12,
  ultSize = 50;
  quickslotOffsetX = 5;
  bindingTextOnUlt = false;
  showKeybindBG = false;
  buttonTemplate = "ZO_ActionButton_Keyboard_Template";
  ultButtonTemplate = "ZO_UltimateActionButton_Keyboard_Template";
  overlayTemplate = "FAB_ActionButtonOverlay_Keyboard_Template";
  ultOverlayTemplate = "FAB_UltimateButtonOverlay_Keyboard_Template";
  qsOverlayTemplate = "FAB_QuickSlotOverlay_Keyboard_Template";
};
local ULTIMATE_BUTTON_STYLE = { -- TODO make back bar ult button to display duration.
  type = ACTION_BUTTON_TYPE_VISIBLE;
  template = "ZO_UltimateActionButton";
  showBinds = false;
  parentBar = "";
};
local GROUND_EFFECT = ABILITY_TYPE_AREAEFFECT;
local DEBUFF = BUFF_EFFECT_TYPE_DEBUFF;
-------------------------------------------------------------------------------
-----------------------------[    Global    ]----------------------------------
-------------------------------------------------------------------------------
FancyActionBar.effects = {};     -- currently slotted abilities
FancyActionBar.stacks = {};      -- ability id => current stack count
FancyActionBar.activeCasts = {}; -- updating timers to account for delay and expiration ( mostly for debugging )
FancyActionBar.toggles = {};     -- works together with effects to update toggled abilities activation
FancyActionBar.debuffs = {};     -- effects for debuffs to update if they are active on target


FancyActionBar.fixedTimers = {}; -- to keep track of certain timers regardless of updates from the game
FancyActionBar.trapTimers = {};

-- Backbar buttons.
FancyActionBar.buttons = {}; -- Contains: abilities duration, number of stacks and visual effects.
-- FancyActionBar.abilitySlots                  = {} -- TODO enable tooltip, mouse click and drag functions
---@type table<integer, FAB_ActionButtonOverlay_Gamepad_Template|FAB_ActionButtonOverlay_Keyboard_Template>
FancyActionBar.overlays = {};                 -- normal skill button overlays
FancyActionBar.ultOverlays = {};              -- player and companion ultimate skill button overlays
FancyActionBar.style = nil;                   -- Gamepad or Keyboard UI for compatibility

FancyActionBar.qsOverlay = nil;               -- shortcut for.. reasons..

FancyActionBar.initialized = false;           -- check before running some functions that can't be run this early
FancyActionBar.initialSetup = true;           -- same as above. not sure why I added both...
FancyActionBar.wasMoved = false;              -- don't move action bar if it wasn't moved to begin with
FancyActionBar.wasStopped = false;            -- don't register updates if already registered

FancyActionBar.zone = 0;                      -- some buffs expire when traveling, and some don't. check active buffs on player
FancyActionBar.inCombat = false;              -- for GCD

FancyActionBar.weaponFront = WEAPONTYPE_NONE; -- for getting correct id's for destro staff skills on back bar
FancyActionBar.weaponBack = WEAPONTYPE_NONE;

FancyActionBar.durationMin = 4;
FancyActionBar.durationMax = 99;

FancyActionBar.player = { name = ""; id = 0 }; -- might be needed to check for some effects before updating timer

FancyActionBar.constants = {                   -- all current values for the UI and configuration to use. not sure why I called it 'constants' when they are all in fact variables.
  duration = {
    font = "Univers 67";
    size = 24;
    outline = "thick-outline";
    y = 0;
    color = { 1; 1; 1 };
  };
  stacks = {
    font = "Univers 67";
    size = 20;
    outline = "thick-outline";
    x = 37;
    color = { 1; 0.8; 0 };
  };
  ult = {
    duration = {
      show = true;
      font = "Univers 67";
      size = 24;
      outline = "thick-outline";
      x = 37;
      y = 0;
      color = { 1; 1; 1 };
    };
    value = {
      show = false;
      mode = 1;
      font = "Univers 67";
      size = 20;
      outline = "outline";
      x = -2;
      y = -5;
      color = { 1; 1; 1 };
    };
    companion = {
      show = true;
      mode = 1;
      x = 0;
      y = 0;
    };
  };
  qs = {
    show = true;
    font = "Univers 67";
    size = 24;
    outline = "outline";
    x = 0;
    y = 10;
    color = { 1; 0.5; 0.2 };
  };
  abScale = {
    enable = false;
    scale = 100;
  };
  move = {
    enable = false;
    x = 0;
    y = 0;
  };
  style = {};
};
-------------------------------------------------------------------------------
-----------------------------[    Tables    ]----------------------------------
-------------------------------------------------------------------------------
local defaultSettings;      -- default settings variables...
local abilityConfig = {};   -- parsed FancyActionBar.abilityConfig.
local specialIds = {};      -- abilities that needs to be updated individually when fired ( cause too special to be tracked by effect changed events, or if I wanna do something more with them )
local fakes = {};           -- problematic abilities from current class and shared skill lines ( mostly ground AoE's and traps )
local activeFakes = {};     -- enables OnCombatEvent to update timers with hard coded durations if the button for the effect has been pressed (:4House:)
local slottedIds = {};      -- to match skills with their tracked effect ( not in use cause I smooth brained the parts that might benefit from this )
local effectSlots = {};     -- to indentify slots that track the same effect
local debuffTargets = {};   -- not used, but might be needed when I get better at writing tracking for debuffs on enemies
local lastAreaTargets = {}; -- unit id for 'offline' target when casting ground effects always change. check if it was the same target id before fading if before 0
-------------------------------------------------------------------------------
---------------------------[   Local Variables   ]-----------------------------
-------------------------------------------------------------------------------
---@class FAB_AC_SV
local SV;                       -- saved variables (accountwide)
---@class FAB_DC_SV
local CV;                       -- saved variables (character)
local debug = false;            -- debug mode

local scale;                    -- default or custom scale of the action bar to use
local showDecimal;              -- setting for decimals from very early versions. TODO: add to constants
local showDecimalStart;         -- same as above
local updateRate = 100;         -- overlay update interval

local class = 0;                -- player class for tracking problematic abilities
local lastButton = 0;           -- for repositioning of skill buttons
local uiModeChanged = false;    -- don't change configuration if not needed
local hideCompanionUlt = false; -- variable with no settings for now (hide if companion is not currently present or if doesn't have its ultimate ability unlocked - why show empty button ZoS?? )

local guardId = 0;              -- sync active id for guard on both bars as active and inactive are different
local cost1;
local cost2;
local cost3;
local WEAPONTYPE_NONE = WEAPONTYPE_NONE; -- just to make sure the game isn't confused by its own constants. ( not sure why this would even happen, but it does.. )
local WEAPONTYPE_FIRE_STAFF = WEAPONTYPE_FIRE_STAFF;
local WEAPONTYPE_FROST_STAFF = WEAPONTYPE_FROST_STAFF;
local WEAPONTYPE_LIGHTNING_STAFF = WEAPONTYPE_LIGHTNING_STAFF;
--------------------------------------------------------------------------------
-----------------------------[ 		Utility    ]----------------------------------
--------------------------------------------------------------------------------

---comment
---@param msg string
---@param ... any
---@return nil
FancyActionBar.Chat = function (msg, ...)
  if LibChatMessage then
    ---@type LibChatMessage
    local chat = LibChatMessage("FancyActionBar+", "FAB+");
    return chat:Printf(msg, ...);
  elseif LibChatMessage == nil then
    return d(strformat(msg, ...));
  end;
end;

---@param msg string
---@param ... any
local function Chat(msg, ...)
  FancyActionBar.Chat(msg, ...);
end;

--- Debugging
---@param msg string
---@param ... any
local function dbg(msg, ...)
  if SV.debug then
    Chat(msg, ...);
  end;
end;

--- Debugging
---@param ... any
function FancyActionBar:dbg(...)
  -- if SV.debugAll then return end
  if SV.debug then
    local str = zo_strformat(...);
    Chat("[FAB+] " .. str);
  end;
end;

--- Slash command handler
---@param str string
function FancyActionBar.SlashCommand(str)
  local setting;
  local cmd = string.lower(str);
  if cmd == "dbg 0" then
    SV.debug = false;
    SV.debugAll = false;
    Chat("[FAB+] debug: Off.");
  elseif cmd == "dbg 1" then
    SV.debug = not SV.debug;
    if SV.debug then setting = "On."; else setting = "Off."; end;
    Chat("[FAB+] debug1: " .. setting);
  elseif cmd == "dbg 2" then
    SV.debugAll = not SV.debugAll;
    if SV.debugAll then setting = "On."; else setting = "Off."; end;
    Chat("[FAB+] debugAll: " .. setting);
  elseif cmd == "dbg 3" then
    SV.debugVerbose = not SV.debugVerbose;
    if SV.debugVerbose then setting = "On."; else setting = "Off."; end;
    Chat("[FAB+] Verbose debug: " .. setting);
  elseif cmd == "bar1" then
    FancyActionBar.PostSlottedSkills(1);
  elseif cmd == "bar2" then
    FancyActionBar.PostSlottedSkills(2);
  elseif cmd == "bars" then
    FancyActionBar.PostSlottedSkills(3);
  elseif cmd == "overlay" then
    FancyActionBar.PostOverlayEffects();
  elseif cmd == "track" then
    FancyActionBar.PostAbilityConfig();
  elseif cmd == "stacks" then
    for id, effect in pairs(FancyActionBar.stackMap) do
      for i = 1, #effect do
        Chat("[" .. id .. "] = " .. effect[i]);
      end;
    end;
  elseif cmd == "dbt" then
    Chat("[FAB+] Registered Debuff IDs:");
    for id in pairs(SV.debuffTable) do
      Chat(id);
    end;
  end;
end;

---@param index number
---@param bar HotBarCategory
function FancyActionBar.GetSlotTrueBoundId(index, bar)
  local id = GetSlotBoundId(index, bar);
  local actionType = GetSlotType(index, bar);
  if actionType == ACTION_TYPE_CRAFTED_ABILITY then
    id = GetAbilityIdForCraftedAbilityId(id);
  end;
  return id;
end;

---
---@param abilityId integer
function FancyActionBar.GetStackIdForAbilityId(abilityId)
  if not abilityId or abilityId == "" then return; end;
  local stackMap = FancyActionBar.stackMap;
  for stackId, abilityIds in pairs(stackMap) do
    for i = 1, #abilityIds do
      if abilityIds[i] == abilityId then
        return stackId;
      end;
    end;
  end;
end;

---
---@param index number
---@param bar HotBarCategory
---@return string
local function GetSlotInfoString(index, bar)
  local slot = index == 8 and "Ult" or tostring(index - 2);
  local string = "[" .. slot .. "] ";
  local id = FancyActionBar.GetSlotTrueBoundId(index, bar);
  if id > 0 then
    local name = GetAbilityName(id);
    string = string .. "<" .. name .. "> " .. id;
  end;
  return string;
end;

function FancyActionBar.PostAbilityConfig()
  Chat("FAB+ Ability Configuration:");

  local s = FancyActionBar.abilityConfig;

  for skill, id in pairs(s) do
    local v;

    if type(id) == "table" then
      if id == {} or id[1] == nil
      then
        v = "{}";
      else
        v = tostring(id[1]);
      end;
    elseif type(id) == "boolean" then
      v = "false";
    else
      v = tostring(id);
    end;
    Chat("[|cffffff" .. tostring(skill) .. "|r] = |cff6600" .. v .. "|r");
  end;
end;

---
---@param bar HotBarCategory
function FancyActionBar.PostSlottedSkills(bar)
  Chat("[FAB+] Current Skills:");
  if bar == 1 or bar == 3 then
    Chat("Front Bar");
    for i = 3, 8 do Chat(GetSlotInfoString(i, 0)); end;
  end;
  if bar == 2 or bar == 3 then
    Chat("Back Bar");
    for i = 3, 8 do Chat(GetSlotInfoString(i, 1)); end;
  end;
end;

function FancyActionBar.PostOverlayEffects()
  for i = 3, 7 do
    local o1 = FancyActionBar.overlays[i];
    local o2 = FancyActionBar.overlays[i + 20];
    if o1.effect and o1.effect.id and o1.effect.id > 0 then
      Chat("[" .. i .. "]: " .. o1.effect.id);
      for k, v in pairs(o1.effect) do
        Chat(" - [" .. k .. "]: " .. tostring(v));
      end;
    end;
    if o2.effect and o2.effect.id and o2.effect.id > 0 then
      Chat("[" .. i + 20 .. "]: " .. o2.effect.id);
      for k, v in pairs(o2.effect) do
        Chat(" - [" .. k .. "]: " .. tostring(v));
      end;
    end;
  end;
end;

function FancyActionBar.IsDebugMode()
  return debug;
end;

---
---@param mode boolean
function FancyActionBar.SetDebugMode(mode)
  assert(type(mode) == "boolean", "Debug mode must be boolean.");
  debug = mode;
end;

---
---@return string
function FancyActionBar.GetName()
  return NAME;
end;

---
---@return string
function FancyActionBar.GetVersion()
  return VERSION;
end;

---
---@return number
function FancyActionBar.GetScale()
  return scale;
end;

---
---@return table
function FancyActionBar.GetExternalBlacklist()
  return SV.externalBlackList;
end;

---
---@return table var
---@return table def
function FancyActionBar:GetMovableVarsForUI()
  local var = FancyActionBar.constants.move;
  local def = IsInGamepadPreferredMode() and defaultSettings.abMove.gp or defaultSettings.abMove.kb;
  return var, def;
end;

---
---@return number durationMin
---@return number durationMax
function FancyActionBar.GetAbilityDurationLimits()
  return SV.durationMin, SV.durationMax;
end;

function FancyActionBar.UpdateDurationLimits()
  FancyActionBar.durationMin, FancyActionBar.durationMax = FancyActionBar.GetAbilityDurationLimits();
end;

---
---@return table
function FancyActionBar.GetContants()
  if not FancyActionBar.initialized then
    FancyActionBar.style = IsInGamepadPreferredMode() and 2 or 1;
    local s = FancyActionBar.style == 1 and KEYBOARD_CONSTANTS or GAMEPAD_CONSTANTS;
    FancyActionBar.constants.style = s;
  end;
  return FancyActionBar.constants.style;
end;

---
---@return table
function FancyActionBar.GetAbilityConfig()
  return FancyActionBar.abilityConfig;
end;

---
---@return table
function FancyActionBar.GetAbilityConfigChanges()
  if CV.useAccountWide
  then
    return SV.configChanges;
  else
    return CV.configChanges;
  end;
end;

function FancyActionBar.GetHideOnNoTargetGlobalSetting()
  if CV.useAccountWide
  then
    return SV.hideOnNoTargetGlobal;
  else
    return CV.hideOnNoTargetGlobal;
  end;
end;

function FancyActionBar.GetHideOnNoTargetList()
  if CV.useAccountWide
  then
    return SV.hideOnNoTargetList;
  else
    return CV.hideOnNoTargetList;
  end;
end;

function FancyActionBar.GetNoTargetFade()
  if CV.useAccountWide
  then
    return SV.noTargetFade;
  else
    return CV.noTargetFade;
  end;
end;

function FancyActionBar.SetNoTargetFade(fade)
  if CV.useAccountWide
  then
    SV.noTargetFade = fade;
  else
    CV.noTargetFade = fade;
  end;
  FancyActionBar.constants.noTargetFade = fade;
end;

function FancyActionBar.GetNoTargetAlpha()
  if CV.useAccountWide
  then
    return SV.noTargetAlpha / 100;
  else
    return CV.noTargetAlpha / 100;
  end;
end;

function FancyActionBar.SetNoTargetAlpha(alpha)
  if CV.useAccountWide
  then
    SV.noTargetAlpha = alpha;
  else
    CV.noTargetAlpha = alpha;
  end;
  FancyActionBar.constants.noTargetAlpha = alpha / 100;
end;

function FancyActionBar.UpdateHideOnNoTargetForSkill(id, hide)
  local cfg = abilityConfig[id];
  local effectId = 0;

  if cfg ~= nil then
    if type(cfg) == "table" then
      cfg[5] = hide;
      effectId = cfg[1];
    end;

    if effectId > 0 then
      local effect = FancyActionBar.effects[effectId];
      if effect then
        effect.hideOnNoTarget = hide;
        FancyActionBar.UpdateEffect(effect);
      end;
    end;
  end;
end;

function FancyActionBar.OnlyUpdateEffectForUsedSkill(id)

end;

function FancyActionBar.EditCurrentAbilityConfiguration(id, cfg)
  local isToggled, noTarget = false, false;

  if FancyActionBar.toggled[id] then
    FancyActionBar.toggles[id] = false;
    isToggled = true;
  end;

  -- if FancyActionBar.constants.hideOnNoTargetList[id] then
  --   noTarget = FancyActionBar.constants.hideOnNoTargetList[id]
  -- else
  --   noTarget = FancyActionBar.GetHideOnNoTargetGlobalSetting()
  -- end

  local cI, rI = id, false;

  if type(cfg) == "table" then
    if cfg[1] then cI = cfg[1]; end;
  end;

  if FancyActionBar.removeInstantly[cI] then rI = true; end;

  if type(cfg) == "table" then
    abilityConfig[id] = { cI; true; isToggled; rI };
  elseif cfg then
    abilityConfig[id] = { id; true; isToggled; rI };
  elseif cfg == false then
    abilityConfig[id] = false;
  else
    abilityConfig[id] = nil;
  end;

  if id == 31816 then -- configure stone giant
    abilityConfig[133027] = cfg;
    if cI == 31816 then
      FancyActionBar.stackMap[31816] = { 31816; cI };
      FancyActionBar.stackMap[134336] = nil;
    elseif cI == 134336 then
      FancyActionBar.stackMap[31816] = nil;
      FancyActionBar.stackMap[134336] = { 134336; cI };
    else
      FancyActionBar.stackMap[31816] = nil;
      FancyActionBar.stackMap[134336] = nil;
    end;
  end;

  local currentSlots = {};

  for i = MIN_INDEX, MAX_INDEX + 1 do
    local I0 = FancyActionBar.GetSlotTrueBoundId(i, 0);
    local I1 = FancyActionBar.GetSlotTrueBoundId(i, 1);
    if I0 == id then currentSlots[i] = true; end;
    if I1 == id then currentSlots[i + SLOT_INDEX_OFFSET] = true; end;
  end;

  for slot in pairs(currentSlots) do
    if slot then FancyActionBar.SlotEffect(slot, id); end;
  end;
end;

function FancyActionBar.GetActionButton(index) -- get actionbutton by index.
  if index > SLOT_INDEX_OFFSET
  then
    return FancyActionBar.buttons[index];
  else
    return ZO_ActionBar_GetButton(index);
  end;
end;

function FancyActionBar.GetOverlay(index)
  if (index == ULT_SLOT) or (index == ULT_SLOT + SLOT_INDEX_OFFSET)
  then
    return FancyActionBar.ultOverlays[index];
  else
    return FancyActionBar.overlays[index];
  end;
end;

function FancyActionBar.GetEffect(id, config, custom, toggled, ignore, instantFade)
  local effect = FancyActionBar.effects[id];
  if not effect then
    if config then
      effect = {
        id = id;
        endTime = 0;
        custom = custom;
        toggled = toggled;
        ignore = ignore;
        passive = false;
        isDebuff = false;
        activeOnTarget = false;
        instantFade = instantFade;
        faded = true;
      };
      FancyActionBar.effects[id] = effect;
    end;
  end;
  return effect or nil;
end;

function FancyActionBar.GetSlottedEffect(index)
  return slottedIds[index].effect, slottedIds[index].ability;
end;

function FancyActionBar.SetSlottedEffect(index, abilityId, effectId)
  if not slottedIds[index] then
    slottedIds[index] = { ability = 0; effect = 0 };
  end;
  slottedIds[index].ability = abilityId or 0;
  slottedIds[index].effect = effectId or 0;
end;

function FancyActionBar.IsSameEffect(index, abilityId)
  -- local ts      = tostring
  local overlay = FancyActionBar.overlays[index];
  if overlay.effect then
    local e, a = FancyActionBar.GetSlottedEffect(index);
    if overlay.effect.id == e and abilityId == a then
      -- local o = e or 0
      -- Chat('overlay '..ts(index)..' effect '..ts(abilityId)..' already slotted ('..ts(o)..')')
      return true;
    end;
  end;
  -- Chat('overlay '..ts(index)..' new effect: '..ts(abilityId))
  return false;
end;

function FancyActionBar.UpdateCompanionOverlayOnChange()
  if (ZO_ActionBar_GetButton(ULT_SLOT, COMPANION).hasAction and DoesUnitExist("companion") and HasActiveCompanion()) then
    hideCompanionUlt = false;

    local current, _, _ = GetUnitPower("companion", COMBAT_MECHANIC_FLAGS_ULTIMATE);
    cost3 = GetSlotAbilityCost(ULT_INDEX, COMBAT_MECHANIC_FLAGS_ULTIMATE, COMPANION);

    CompanionUltimateButton:SetHidden(false);
    FancyActionBar.UpdateUltimateValueLabels(false, current);

    if FancyActionBar.style == 2
    then
      ZO_ActionBar_GetButton(ULT_SLOT, COMPANION).buttonText:SetHidden(true);
    else
      ZO_ActionBar_GetButton(ULT_SLOT, COMPANION).buttonText:SetHidden(not SV.showHotkeys);
    end;
  else
    hideCompanionUlt = true;
    if CompanionUltimateButton then
      CompanionUltimateButton:SetHidden(true);
      ZO_ActionBar_GetButton(ULT_SLOT, COMPANION).buttonText:SetHidden(true);
    end;
  end;
end;

function FancyActionBar.HandleCompanionStateChanged() -- prevents quick slot from being moved when a companion is summoned / unsummoned
  local c = ZO_ActionBar_GetButton(ULT_SLOT, COMPANION);
  c:HandleSlotChanged();
  c:UpdateUltimateMeter();
  zo_callLater(function () FancyActionBar.UpdateCompanionOverlayOnChange(); end, 2000);
end;

-- ZO_ActionButtons_ToggleShowGlobalCooldown()
function FancyActionBar.OnPlayerActivated() -- status update after travel.
  FancyActionBar.SetMarker();
  FancyActionBar.ToggleUltimateValue();
  FancyActionBar:UpdateDebuffTracking();

  FancyActionBar.HandleCompanionStateChanged();

  local zone = GetZoneId(GetUnitZoneIndex("player"));
  if FancyActionBar.zone ~= zone then
    FancyActionBar.zone = zone;
    FancyActionBar.RefreshEffects();
  end;
  FancyActionBar.weaponFront = GetItemLinkWeaponType(GetItemLink(BAG_WORN, EQUIP_SLOT_MAIN_HAND, LINK_STYLE_DEFAULT));
  FancyActionBar.weaponBack = GetItemLinkWeaponType(GetItemLink(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN, LINK_STYLE_DEFAULT));
end;

-------------------------------------------------------------------------------
-----------------------------[ 		UI Updates    ]------------------------------
-------------------------------------------------------------------------------
function FancyActionBar.CheckForActiveEffect(id) -- update timer on load / reload.
  local hasEffect = false;
  local duration = 0;
  local currentStacks = 0;

  for i = 1, GetNumBuffs("player") do
    local name, startTime, endTime, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo("player", i);

    if --[[not castByPlayer and]] abilityId == id then
      hasEffect = true;
      duration = endTime - time();
      currentStacks = stackCount or 0;
    end;
  end;

  return hasEffect, duration, currentStacks;
end;

function FancyActionBar.ResolveIdToTrack(type, id) -- special cases.
  local idToTrack;

  -- if eventually other skills will also need this function.
  if type == 1 then
    local sDmg = GetPlayerStat(STAT_SPELL_POWER, STAT_BONUS_OPTION_APPLY_BONUS);
    local wDmg = GetPlayerStat(STAT_POWER, STAT_BONUS_OPTION_APPLY_BONUS);
    if sDmg > wDmg
    then
      idToTrack = FancyActionBar.soulTrap[id][1]; -- mag
    else
      idToTrack = FancyActionBar.soulTrap[id][2];
    end; -- stam
  end;
  return idToTrack;
end;

function FancyActionBar.GetIdForDestroSkill(id, bar) -- cause too hard for game to figure out.
  local destroId, staffType;

  local destroStaves = {
    [WEAPONTYPE_FIRE_STAFF] = true;
    [WEAPONTYPE_FROST_STAFF] = true;
    [WEAPONTYPE_LIGHTNING_STAFF] = true;
  };

  local weaponOnBar = bar == 0 and FancyActionBar.weaponFront or FancyActionBar.weaponBack;

  if destroStaves[weaponOnBar]
  then
    staffType = weaponOnBar;
  else
    staffType = WEAPONTYPE_NONE;
  end;

  local skill1 = FancyActionBar.destroSkills[id];
  local skill2 = FancyActionBar.idsForStaff[skill1.type][skill1.morph];

  if skill2[staffType]
  then
    destroId = skill2[staffType];
  else
    destroId = id;
  end;

  return destroId;
end;

function FancyActionBar.UpdateInactiveBarIcon(index, bar) -- for bar swapping.
  local id = FancyActionBar.GetSlotTrueBoundId(index, bar);
  local iconId = 0;                                       -- GetEffectiveAbilityIdForAbilityOnHotbar(id, bar)
  local btn = FancyActionBar.buttons[index + SLOT_INDEX_OFFSET];
  local icon = "";

  if id > 0 --[[TODO: and bar == 0 or bar == 1]] then
    if FancyActionBar.destroSkills[id] then
      id = FancyActionBar.GetIdForDestroSkill(id, bar);
      icon = GetAbilityIcon(id);
    else
      icon = GetAbilityIcon(GetEffectiveAbilityIdForAbilityOnHotbar(id, bar));
    end;
    btn.icon:SetHidden(false);
    btn.icon:SetTexture(icon);
  else
    btn.icon:SetHidden(true);
  end;
end;

function FancyActionBar.SetFixedDuration(id, endTime)
  FancyActionBar.fixedTimers[id] = endTime;
end;

function FancyActionBar.GetFixedDuration(id)
  local duration = 0;
  local debuff = FancyActionBar.debuffs[id];
  if debuff then
    if debuff.activeOnTarget == true then
      if FancyActionBar.fixedTimers[id] then
        duration = FancyActionBar.fixedTimers[id];
      end;
    end;
  end;
  return duration;
end;

function FancyActionBar.SetTrapDuration(id, endTime)
  FancyActionBar.fixedTimers[id] = endTime;
end;

function FancyActionBar.GetTrapDuration(id)
  local duration = 0;
  local debuff = FancyActionBar.debuffs[id];
  if debuff then
    if debuff.activeOnTarget == true then
      if FancyActionBar.fixedTimers[id] then
        duration = FancyActionBar.fixedTimers[id];
      end;
    end;
  end;
  return duration;
end;

--------------
-- abilities
--------------
function FancyActionBar.ResetOverlayDuration(overlay)
  if overlay then
    local durationControl = overlay:GetNamedChild("Duration");
    local bgControl = overlay:GetNamedChild("BG");
    local stacksControl = overlay:GetNamedChild("Stacks");

    if durationControl then durationControl:SetText(""); end;
    if bgControl then bgControl:SetHidden(true); end;
    if stacksControl then stacksControl:SetText(""); end;

    if overlay.effect then
      if overlay.effect.stackId then
        local _, _, currentStacks = FancyActionBar.CheckForActiveEffect(overlay.effect.stackId);
        FancyActionBar.stacks[overlay.effect.stackId] = currentStacks;
        FancyActionBar.HandleStackUpdate(overlay.effect.id);
      end;
      -- else
    end;
  end;
end;

function FancyActionBar.FadeEffect(effect) -- reset effect variables and make sure overlay is cleared
  if effect == nil then return; end;

  effect.endTime = time();

  if effect.slot1 then
    FancyActionBar.ResetOverlayDuration(FancyActionBar.overlays[effect.slot1]);
    effect.slot1 = nil;
  end;
  if effect.slot2 then
    FancyActionBar.ResetOverlayDuration(FancyActionBar.overlays[effect.slot2]);
    effect.slot2 = nil;
  end;
  -- effect.faded = true

  -- Chat('Effect <' .. GetAbilityName(effect.id) .. '> (' .. effect.id .. ') faded')
end;

function FancyActionBar.UpdateTimerLabel(label, text, color)
  label:SetText(text);
  if color ~= nil then
    label:SetColor(unpack(color));
  end;

  -- local a = 1
  -- if alpha ~= nil then a = alpha end
  --
  -- label:SetAlpha(a)
end;

function FancyActionBar.GetHighlightColor(fading, effect)
  local color = nil;

  if fading then
    if SV.highlightExpire
    then
      color = SV.highlightExpireColor;
    else
      if SV.showHighlight then color = SV.highlightColor; end;
    end;
  else
    if SV.showHighlight then color = SV.highlightColor; end;
  end;
  return color;
end;

local bgHidden = {};

function FancyActionBar.UpdateBackgroundVisuals(background, color, index)
  if color ~= nil then
    background:SetHidden(false);
    background:SetColor(color[1], color[2], color[3], color[4]);
  else
    background:SetHidden(true);
  end;

  if index > 0 then
    if bgHidden[index] ~= nil then
      local wasHidden = bgHidden[index];
      if wasHidden ~= bgHidden[index] then
        local isHidden = bgHidden[index] and "hidden" or "showing";
        Chat("[" .. index .. "] " .. isHidden);
      end;
    end;
    bgHidden[index] = bgHidden[index];
  else
    Chat("Index 0 Error!");
  end;
end;

function FancyActionBar.ShouldShowExpire(duration)
  local u = FancyActionBar.constants.update;
  if not u.showDecimal then return false; end;
  if (duration > u.showDecimalStart) then return false; end;
  return true;
end;

function FancyActionBar.ResolveLabelAlphaForDebuff(debuff)
  local alpha = 1;
  if (debuff.activeOnTarget == false and debuff.hideOnNoTarget == false) then
    if (FancyActionBar.constants.noTargetFade == true) then alpha = FancyActionBar.constants.noTargetAlpha; end;
  end;
  return alpha;
end;

function FancyActionBar.FormatTextForDurationOfActiveEffect(fading, effect, duration)
  local timer, color = "", nil;

  if duration <= 0 then
    if (SV.delayFade and not effect.instantFade) then
      local delayEnd = (effect.endTime + SV.fadeDelay) - time();
      if delayEnd > 0 then
        timer = zo_max(0, zo_ceil(tonumber(duration)));
      end;
    end;

    if effect.id == FancyActionBar.sCorch.id1 then
      FancyActionBar.stacks[effect.id] = 0;
      FancyActionBar.HandleStackUpdate(effect);
    end;

    -- if effect.id == FancyActionBar.deepFissure.id1 then
    --   FancyActionBar.stacks[effect.id] = 0;
    --   FancyActionBar.HandleStackUpdate(effect);
    -- end;

    if effect.id == FancyActionBar.subAssault.id1 then
      FancyActionBar.stacks[effect.id] = 0;
      FancyActionBar.HandleStackUpdate(effect);
    end;
  else
    if FancyActionBar.ShouldShowExpire(duration)
    then
      timer = strformat("%0.1f", duration);
    else
      timer = strformat("%0.0f", duration);
    end;
  end;

  if (fading and SV.showExpire)
  then
    color = SV.expireColor;
  else
    color = FancyActionBar.constants.duration.color;
  end;

  return timer, color;
end;

function FancyActionBar.UpdateOverlay(index) -- timer label updates.
  local overlay = FancyActionBar.overlays[index];
  if overlay then
    local effect = overlay.effect;
    local durationControl = overlay:GetNamedChild("Duration");
    local bgControl = overlay:GetNamedChild("BG");
    local stacksControl = overlay:GetNamedChild("Stacks");
    local lt, lc, la = "", nil, nil;
    local bh, bc = true, nil;

    if (effect and not effect.ignore and effect.id > 0) then
      if (effect.toggled or effect.passive) then
      else
        local duration = 0; -- = effect.endTime - time()

        if FancyActionBar.fixedTimers[effect.id] then
          duration = FancyActionBar.GetFixedDuration(effect.id) - time();
        else
          duration = effect.endTime - time();
        end;

        local isFading = false;
        if (duration <= SV.showExpireStart) then isFading = SV.showExpire; end;

        -- local hasFaded = effect.faded

        lt, lc = FancyActionBar.FormatTextForDurationOfActiveEffect(isFading, effect, duration);
        if duration > 0 then
          bc = FancyActionBar.GetHighlightColor(isFading);
        else
          if effect.isDebuff then
            if effect.stacks or FancyActionBar.stacks[effect.id] then FancyActionBar.stacks[effect.id] = effect.stacks or 0; end;
          end;
        end;

        -- if duration <= 0 then
        --   if (SV.delayFade and not effect.instantFade) then
        --     local delayEnd = (effect.endTime + SV.fadeDelay) - time()
        --     if delayEnd > 0 then
        --       lt = zo_max(0, zo_ceil(duration))
        --     else
        --     end
        --   else
        --     if effect.id == FancyActionBar.subAssault.id1 then
        --       FancyActionBar.stacks[effect.id] = 0
        --       FancyActionBar.HandleStackUpdate(effect)
        --     end
        --   end
        -- else

        -- bgControl:SetHidden(not SV.showHighlight)
        --
        -- if (showDecimal and (duration <= showDecimalStart)) then
        --   lt = strformat('%0.1f', duration)
        --   durationControl:SetText(strformat('%0.1f', duration))
        -- else
        --   lt = strformat('%0.0f', duration)
        --   durationControl:SetText(strformat('%0.0f', duration))
        -- end
        --
        -- if (duration <= SV.showExpireStart) then
        --   if (SV.showExpire) then
        --     lc = SV.expireColor
        --     durationControl:SetColor(unpack(SV.expireColor))
        --   end
        --   if (SV.highlightExpire) then
        --     bc = SV.highlightExpireColor
        --     bgControl:SetColor(unpack(SV.highlightExpireColor))
        --   end
        -- else
        --   lc = timerColor
        --   bc = SV.highlightColor
        --   bgControl:SetColor(unpack(SV.highlightColor))
        --   durationControl:SetColor(unpack(FancyActionBar.constants.duration.color))
        -- end
        -- end

        FancyActionBar.UpdateTimerLabel(durationControl, lt, lc);
        FancyActionBar.UpdateBackgroundVisuals(bgControl, bc, index);

        if FancyActionBar.trapTimers[effect.id] then
          local tt = FancyActionBar.trapTimers[effect.id] - time();
          if tt > 0
          then
            stacksControl:SetText(zo_max(0, zo_ceil(tt)));
          else
            stacksControl:SetText("");
          end;
          return;
        end;
      end;
      if effect.stackId and (not FancyActionBar.stacks[effect.stackId]) or (FancyActionBar.stacks[effect.stackId] and FancyActionBar.stacks[effect.stackId] == 0) then stacksControl:SetText(""); end;
    else
      durationControl:SetText("");
      bgControl:SetHidden(true);
      stacksControl:SetText("");
      -- UpdateTimerLabel(durationControl, lt, lc)
      -- UpdateBackgroundVisuals(bgControl, bh, bc, index)
    end;
  end;
end;

function FancyActionBar.UpdateStacks(index) -- stacks label.
  local overlay = FancyActionBar.overlays[index];
  if overlay then
    local stacksControl = overlay:GetNamedChild("Stacks");
    local effect = overlay.effect;
    if effect then
      if FancyActionBar.stacks[effect.stackId] and FancyActionBar.stacks[effect.stackId] > 0 then
        stacksControl:SetText(FancyActionBar.stacks[effect.stackId]);
        stacksControl:SetColor(unpack(FancyActionBar.constants.stacks.color));
      else
        stacksControl:SetText("");
      end;
    else
      stacksControl:SetText("");
    end;
  end;
end;

function FancyActionBar.UpdateUltOverlay(index) -- update ultimate labels.
  local overlay = FancyActionBar.ultOverlays[index];
  if overlay then
    local effect = overlay.effect;
    local durationControl = overlay:GetNamedChild("Duration");
    -- local timerColor = IsInGamepadPreferredMode() and SV.ultColorGP or SV.ultColorKB
    local timerColor = FancyActionBar.constants.ult.duration.color;

    if not FancyActionBar.constants.ult.duration.show then
      durationControl:SetText("");
      return;
    end;

    if effect then
      local duration = effect.endTime - time();
      if duration > -2 then
        if duration > 0 then
          if (showDecimal and (duration <= showDecimalStart))
          then
            durationControl:SetText(strformat("%0.1f", zo_max(0, duration)));
          else
            durationControl:SetText(zo_max(0, zo_ceil(duration)));
          end;

          if (duration <= SV.showExpireStart) then
            if (SV.showExpire) then durationControl:SetColor(unpack(SV.expireColor)); end;
          else
            durationControl:SetColor(unpack(timerColor));
          end;
        else
          if (SV.delayFade and not effect.instantFade) then
            local delayEnd = (effect.endTime + SV.fadeDelay) - time();
            if delayEnd > 0
            then
              durationControl:SetText(zo_max(0, zo_ceil(duration)));
            else
              durationControl:SetText("");
            end;
          else
            durationControl:SetText("");
          end;
        end;
      else
        durationControl:SetText("");
      end;
    else
      durationControl:SetText("");
    end;
  end;
end;

function FancyActionBar.HandleStackUpdate(id) -- find overlays for a specific effect and update stacks.
  local effect = FancyActionBar.effects[id];
  if effect then
    if effect.slot1 then FancyActionBar.UpdateStacks(effect.slot1); end;
    if effect.slot2 then FancyActionBar.UpdateStacks(effect.slot2); end;
    if id == 122658 then
      if FancyActionBar.effects[id] and FancyActionBar.stacks[id] == 0 then
        FancyActionBar.effects[122658].endTime = time();
      end;
    end;
  end;
end;

function FancyActionBar.UpdateToggledAbility(id, active) -- toggled effect highligh update.
  local effect = FancyActionBar.effects[id];

  if not FancyActionBar.toggles[effect.id] then FancyActionBar.toggles[effect.id] = false; end;

  FancyActionBar.toggles[effect.id] = active;

  if effect.slot1 then FancyActionBar.UpdateHighlight(effect.slot1); end;
  if effect.slot2 then FancyActionBar.UpdateHighlight(effect.slot2); end;
end;

function FancyActionBar.UpdatePassiveEffect(id, active) -- passive effect highligh update.
  for i, overlay in pairs(FancyActionBar.overlays) do
    local effect = overlay.effect;
    if effect then
      if effect.id == id then
        effect.passive = active;
        FancyActionBar.UpdateHighlight(i);
      end;
    end;
  end;
end;

function FancyActionBar.UnslotEffect(index) -- Remove effect from overlay index.
  local overlay, effect;

  if (index == ULT_INDEX) or (index == (ULT_INDEX + SLOT_INDEX_OFFSET)) then
    overlay = FancyActionBar.ultOverlays[index];
    if index == ULT_INDEX then
      cost1 = 0;
    elseif index == (ULT_INDEX + SLOT_INDEX_OFFSET)
    then
      cost2 = 0;
    end;
  else
    overlay = FancyActionBar.overlays[index];
  end;

  if overlay then
    effect = overlay.effect;
    if effect then
      if effect.id then
        if FancyActionBar.debuffs[effect.id] then FancyActionBar.debuffs[effect.id] = nil; end;
        FancyActionBar.ResetOverlayDuration(overlay);
      end;
      overlay.effect = nil;
    end;
  end;
end;

function FancyActionBar.SlotEffect(index, abilityId, overrideRank, casterUnitTag) -- assign effect and instructions to overlay index.
  if (not abilityId or abilityId == 0) then
    FancyActionBar.UnslotEffect(index);
    return;
  end;
  if (GetAbilityCastInfo(abilityId, overrideRank, casterUnitTag) and not FancyActionBar.allowedChanneled[abilityId]) then
    FancyActionBar.UnslotEffect(index);
    return;
  end;

  local overlay = FancyActionBar.GetOverlay(index);
  if not overlay then return; end;

  local effectId, duration, custom, toggled, passive, instantFade;

  local cfg = abilityConfig[abilityId];
  local ignore = false;

  local stackId = cfg and cfg[1] and FancyActionBar.GetStackIdForAbilityId(cfg[1]) or FancyActionBar.GetStackIdForAbilityId(abilityId);

  if cfg == false and not stackId then ignore = true; end;

  if cfg ~= nil then
    if ignore then
      effectId = abilityId;
      custom = true;
      toggled = false;
      instantFade = false;
      stackId = nil;
    else
      if (FancyActionBar.soulTrap[abilityId]) then
        if (cfg[1] and cfg[1] == FancyActionBar.abilityConfig[abilityId][1]) -- check if tracked id has been altered
        then
          effectId = FancyActionBar.ResolveIdToTrack(1, abilityId);
        else
          effectId = cfg[1] or abilityId;
        end;
      elseif abilityId == 81420 then -- guard slot id while active for all morphs
        if guardId > 0 then effectId = guardId; end;
      else
        effectId = cfg[1] or abilityId;
        if FancyActionBar.guard.ids[abilityId] then guardId = abilityId; end;
      end;

      custom = true;
      toggled = cfg[3] or false;
      instantFade = cfg[4] or false;
    end;
  else
    effectId = abilityId;
    custom = false;
    toggled = FancyActionBar.toggled[effectId] or false;
    instantFade = FancyActionBar.removeInstantly[effectId] or false;
  end;

  FancyActionBar.SetSlottedEffect(index, abilityId, effectId);

  if (toggled == false and ignore == false)
  then
    duration = (GetAbilityDuration(effectId) or 0) / 1000;
  else
    duration = 0;
  end;

  local effect = FancyActionBar.GetEffect(effectId, true, custom, toggled, ignore, instantFade); -- FancyActionBar.effects[effectId]

  if stackId then
    effect.stackId = stackId;
  end;

  if not ignore then
    effect.duration = duration and duration > 0 and duration or nil;
  end;

  if (effect.id > 0 and FancyActionBar.activeCasts[effect.id] == nil) then
    FancyActionBar.activeCasts[effect.id] = { slot = index; cast = 0; begin = 0; fade = 0 };
  end;

  if not SV.advancedDebuff and effect.isDebuff then effect.isDebuff = false; end;

  if not effect.isDebuff then
    local has, dur, stacks = FancyActionBar.CheckForActiveEffect(effect.id);

    if has then effect.endTime = time() + dur; end;

    if effect.stackId and (effect.id ~= effect.stackId) then
      _, _, stacks = FancyActionBar.CheckForActiveEffect(effect.stackId);
      FancyActionBar.stacks[effect.stackId] = stacks;
    else
      FancyActionBar.stacks[effect.id] = stacks;
    end;
  end;

  local isFrontBar = index < SLOT_INDEX_OFFSET and true or false;

  if (index == ULT_INDEX or index == (ULT_INDEX + SLOT_INDEX_OFFSET)) then
    if isFrontBar then
      effect.ult1 = index;
      if abilityId == 113105 then cost1 = 70; else cost1 = GetAbilityCost(abilityId, COMBAT_MECHANIC_FLAGS_ULTIMATE, overrideRank, casterUnitTag); end;
    elseif index == (ULT_INDEX + SLOT_INDEX_OFFSET) then
      effect.ult2 = index;
      if abilityId == 113105 then cost2 = 70; else cost2 = GetAbilityCost(abilityId, COMBAT_MECHANIC_FLAGS_ULTIMATE, overrideRank, casterUnitTag); end;
    end;

    local ultOverlay = FancyActionBar.ultOverlays[index];
    if ultOverlay then ultOverlay.effect = effect; end;
    return effect;
  end;

  if isFrontBar then
    effect.slot1 = index;
    if FancyActionBar.guard.ids[effect.id] then FancyActionBar.guard.slot1 = index; end;
  else
    effect.slot2 = index;
    if FancyActionBar.guard.ids[effect.id] then FancyActionBar.guard.slot2 = index; end;
  end;
  -- Assign effect to overlay.
  if overlay then overlay.effect = effect; end;

  if FancyActionBar.stacks[effect.stackId] then
    FancyActionBar.UpdateOverlay(index);
    FancyActionBar.UpdateStacks(index);
  end;
  return effect;
end;

function FancyActionBar.SlotEffects() -- slot effects for primary and backup bars.
  if currentHotbarCategory == HOTBAR_CATEGORY_PRIMARY or currentHotbarCategory == HOTBAR_CATEGORY_BACKUP then
    for i = MIN_INDEX, MAX_INDEX do
      FancyActionBar.SlotEffect(i, FancyActionBar.GetSlotTrueBoundId(i, HOTBAR_CATEGORY_PRIMARY));
      FancyActionBar.SlotEffect(i + SLOT_INDEX_OFFSET, FancyActionBar.GetSlotTrueBoundId(i, HOTBAR_CATEGORY_BACKUP));
    end;
    FancyActionBar.SlotEffect(ULT_INDEX, FancyActionBar.GetSlotTrueBoundId(ULT_INDEX, HOTBAR_CATEGORY_PRIMARY));
    FancyActionBar.SlotEffect(ULT_INDEX + SLOT_INDEX_OFFSET, FancyActionBar.GetSlotTrueBoundId(ULT_INDEX, HOTBAR_CATEGORY_BACKUP));
  else
    -- Unslot all effects, if we are on a special bar.
    for i = MIN_INDEX, ULT_INDEX do
      FancyActionBar.UnslotEffect(i);
      FancyActionBar.UnslotEffect(i + SLOT_INDEX_OFFSET);
    end;
  end;
end;

function FancyActionBar.UpdateEffect(effect) -- update overlays linked to the effect.
  if effect then
    if effect.slot1 then FancyActionBar.UpdateOverlay(effect.slot1); end;
    if effect.slot2 then FancyActionBar.UpdateOverlay(effect.slot2); end;
  end;
end;

function FancyActionBar.EffectCheck()
  for id, effect in pairs(FancyActionBar.effects) do
    local hasEffect, duration, stacks = FancyActionBar.CheckForActiveEffect(effect.id);
    if hasEffect then
      effect.endTime = time() + duration;
      if stacks > 0 then
        FancyActionBar.stacks[effect.id] = stacks;
      end;
    end;
    if effect.stackId then
      local hasStackEffect, stackDuration, mappedStacks = FancyActionBar.CheckForActiveEffect(effect.stackId);
      FancyActionBar.stacks[effect.stackId] = mappedStacks;
    end;
    FancyActionBar.UpdateEffect(effect);
    FancyActionBar.HandleStackUpdate(effect.id);
  end;
end;

--------------
-- Quick Slot
--------------
function FancyActionBar.UpdateQuickSlotOverlay() -- from LUI. update every 500ms
  local t = FancyActionBar.qsOverlay.timer;
  local slotIndex = GetCurrentQuickslot();
  local remain, duration, global = GetSlotCooldownInfo(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL);
  if (duration > 5000) then
    t:SetHidden(false);
    if remain > 86400000 then    -- more then 1 day
      t:SetText(string.format("%d d", math.floor(remain / 86400000)));
    elseif remain > 6000000 then -- over 100 minutes - display XXh
      t:SetText(string.format("%dh", math.floor(remain / 3600000)));
    elseif remain > 600000 then  -- over 10 minutes - display XXm
      t:SetText(string.format("%dm", math.floor(remain / 60000)));
    elseif remain > 60000 then
      local m = math.floor(remain / 60000);
      local s = remain / 1000 - 60 * m;
      t:SetText(string.format("%d:%.2d", m, s));
    else
      t:SetText(string.format("%.1d", 0.001 * remain));
    end;
  else
    if not FancyActionBar.InMenu() then t:SetText(""); end;
  end;
end;

--------------
-- GCD
--------------
function FancyActionBar.UpdateGCD()
  local cooldown, duration, global, globalSlotType = GetSlotCooldownInfo(MIN_INDEX);
  local cooldown2, duration2, _, _ = GetSlotCooldownInfo(MIN_INDEX + 1);
  if (cooldown2 > cooldown) or (duration2 > duration) then
    cooldown = cooldown2;
    duration = duration2;
  end;
  if duration < 1 then duration = 1; end;
  local h = (cooldown / duration) * SV.gcd.sizeY;
  FAB_GCD.fill:SetHeight(h);
end;

--------------
-- Ultimate
--------------
function FancyActionBar.GetValueString(mode, value, cost) -- format label text
  local string = "";
  if mode == 1 then
    string = value;
  elseif mode == 3 then
    string = value .. "/" .. cost;
  else
    if value >= cost
    then
      string = value;
    else
      string = value .. "/" .. cost;
    end;
  end;
  return string;
end;

function FancyActionBar.UpdateUltimateValueLabels(player, value) -- update ultimate value displays
  local modeP = FancyActionBar.constants.ult.value.mode;
  local modeC = FancyActionBar.constants.ult.companion.mode;
  local alpha = (value < 10) and 0 or 1;

  if (player and FancyActionBar.constants.ult.value.show) then
    ActionButton8LeadingEdge:SetAlpha(alpha);
    -- ActionButton8UltimateBar:SetHidden(false)

    local o1 = FancyActionBar.ultOverlays[ULT_INDEX];
    local o2 = FancyActionBar.ultOverlays[ULT_INDEX + SLOT_INDEX_OFFSET];

    if o1 and o1.value then o1.value:SetText(FancyActionBar.GetValueString(modeP, value, cost1)); end;
    if o2 and o2.value then o2.value:SetText(FancyActionBar.GetValueString(modeP, value, cost2)); end;
  else
    local o3 = FancyActionBar.ultOverlays[ULT_INDEX + COMPANION_INDEX_OFFSET];
    CompanionUltimateButtonLeadingEdge:SetAlpha(alpha);

    if hideCompanionUlt then
      CompanionUltimateButton:SetHidden(true);
      if o3 and o3.value then o3.value:SetText(""); end;
    else
      CompanionUltimateButton:SetHidden(false);
      if o3 and o3.value then o3.value:SetText(FancyActionBar.GetValueString(modeC, value, cost3)); end;
    end;
  end;
end;

function FancyActionBar.OnUltChanged(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
  if powerType == COMBAT_MECHANIC_FLAGS_ULTIMATE then
    FancyActionBar.UpdateUltimateValueLabels(true, powerValue);
  end;
end;

function FancyActionBar.OnUltChangedCompanion(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
  if powerType == COMBAT_MECHANIC_FLAGS_ULTIMATE then
    FancyActionBar.UpdateUltimateValueLabels(false, powerValue);
  end;
end;

function FancyActionBar.UpdateUltimateCost() -- manual ultimate value update
  if not FancyActionBar.constants.ult.value.show then return; end;

  local function ResolveUltCost(id, overrideRank, casterUnitTag)
    local incap = 113105;
    local cost = 0;
    if id > 0 then
      if id == incap
      then
        cost = 70;
      else
        cost = GetAbilityCost(id, COMBAT_MECHANIC_FLAGS_ULTIMATE, overrideRank, casterUnitTag);
      end;
    end;
    return cost;
  end;

  cost1 = ResolveUltCost(FancyActionBar.GetSlotTrueBoundId(ULT_INDEX, HOTBAR_CATEGORY_PRIMARY));
  cost2 = ResolveUltCost(FancyActionBar.GetSlotTrueBoundId(ULT_INDEX, HOTBAR_CATEGORY_BACKUP));

  local current, _, _ = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE);
  FancyActionBar.UpdateUltimateValueLabels(true, current);
end;

--------------------------------------------------------------------------------
-----------------------------[ 		Configuration    ]----------------------------
--------------------------------------------------------------------------------
function FancyActionBar.RefreshUpdateConfiguration() -- set overlays refresh rate
  local update = {
    showDecimal = false;
    showDecimalStart = 0;
  };
  if (SV.showDecimal == "Never") then
    update.showDecimal = false;
    update.showDecimalStart = 0;
  elseif (SV.showDecimal == "Always") then
    update.showDecimal = true;
    update.showDecimalStart = SV.durationMax;
  elseif (SV.showDecimal == "Expire") then
    update.showDecimal = true;
    update.showDecimalStart = SV.showDecimalStart;
  end;
  return update;
end;

--  ---------------------------------
--  Load Saved Ability Configuration
--  ---------------------------------
function FancyActionBar.BuildAbilityConfig() -- Parse FancyActionBar.abilityConfig for faster access.
  local config = FancyActionBar.GetAbilityConfig();
  local customConfig = FancyActionBar.GetAbilityConfigChanges();

  -- for id, cfg in pairs(FancyActionBar.abilityConfig) do
  -- local debuffs = FancyActionBar.constants.hideOnNoTargetList

  if config[31816] then -- configure stone giant
    config[133027] = config[31816];

    if config[31816][1] == 31816 then
      FancyActionBar.stackMap[31816] = { 31816; config[31816][1] };
      FancyActionBar.stackMap[134336] = nil;
    elseif config == 134336 then
      FancyActionBar.stackMap[31816] = nil;
      FancyActionBar.stackMap[134336] = { 134336; config[31816][1] };
    else
      FancyActionBar.stackMap[31816] = nil;
      FancyActionBar.stackMap[134336] = nil;
    end;
  end;

  for id, cfg in pairs(config) do
    local toggled, hide = false, false;
    if customConfig[id] then
      cfg = customConfig[id];
    end;

    -- if debuffs[id]
    -- then hide = debuffs[id]
    -- else hide = FancyActionBar.GetHideOnNoTargetGlobalSetting() end

    if FancyActionBar.toggled[id] then
      toggled = true; FancyActionBar.toggles[id] = false;
    end;

    local cI, rI = id, false;

    if type(cfg) == "table" then
      if cfg[1] then cI = cfg[1]; end;
    end;

    if FancyActionBar.removeInstantly[cI] then rI = true; end;

    if type(cfg) == "table" then
      abilityConfig[id] = { cI; true; toggled; rI };
    elseif cfg then
      abilityConfig[id] = { cI; true; toggled; rI };
    elseif cfg == false then
      abilityConfig[id] = false;
    else
      abilityConfig[id] = nil;
    end;
  end;

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
end;

--  ---------------------------------
--  Buffs gained by player from others
--  ---------------------------------
local BUFF_EFFECT_TYPE_DEBUFF = BUFF_EFFECT_TYPE_DEBUFF;
function FancyActionBar.OnEffectGainedFromAlly(eventCode, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
  if sourceType == COMBAT_UNIT_TYPE_PLAYER then return; end;
  if not AreUnitsEqual("player", unitTag) then return; end;

  local effect = FancyActionBar.effects[abilityId];
  if effect then
    local t = time();

    if SV.externalBlackList[abilityId] then return; end;

    if (change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED and buffType ~= BUFF_EFFECT_TYPE_DEBUFF) then
      if beginTime == endTime then
        FancyActionBar.UpdatePassiveEffect(abilityId, true);
        return;
      end;

      if (endTime > t + FancyActionBar.durationMin and endTime < t + FancyActionBar.durationMax and endTime > effect.endTime) then
        effect.endTime = endTime;
        FancyActionBar.UpdateEffect(effect);
      end;
    elseif (change == EFFECT_RESULT_FADED) then
      local hasEffect, duration, currentStacks = FancyActionBar.CheckForActiveEffect(abilityId);
      if hasEffect then
        effect.endTime = t + duration;
        FancyActionBar.UpdateEffect(effect);
      else
        effect.endTime = t;
        if beginTime == endTime then
          FancyActionBar.UpdatePassiveEffect(abilityId, false);
        end;
      end;
    end;
  end;
  -- local ts = tostring
  -- Chat('['..ts(abilityId)..'] '..effectName..' '..sourceType..': '..effectType..' --> '..unitName..endTime-beginTime..' ('..stackCount..')')
end;

function FancyActionBar.SetExternalBuffTracking() -- buffs gained from others
  EM:UnregisterForEvent(NAME .. "External", EVENT_EFFECT_CHANGED);
  if SV.externalBuffs then
    EM:RegisterForEvent(NAME .. "External", EVENT_EFFECT_CHANGED, FancyActionBar.OnEffectGainedFromAlly);
    EM:AddFilterForEvent(NAME .. "External", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "player");
  end;
end;

--  ---------------------------------
--  UI Setup
--  ---------------------------------
function FancyActionBar.AdjustControlsPositions() -- resource bars and default action bar position
  if FAB_ActionBarFakeQS == nil then
    FAB_ActionBarFakeQS = GetControl("FAB_ActionBarFakeQS");
  end;
  FAB_ActionBarFakeQS:ClearAnchors();
  FAB_ActionBarFakeQS:SetAnchor(LEFT, ACTION_BAR, LEFT, 0, -5, FAB_ActionBarFakeQS:GetResizeToFitConstrains());

  local style = FancyActionBar.GetContants();
  local anchor = ZO_Anchor:New();

  if FancyActionBar.initialSetup or uiModeChanged then
    -- Move action bar and attributes up a bit.
    uiModeChanged = false;
    anchor:SetFromControlAnchor(ACTION_BAR);
    anchor:SetOffsets(nil, style.actionBarOffset);
    anchor:Set(ACTION_BAR);
  end;

  anchor:SetFromControlAnchor(ZO_PlayerAttribute);
  anchor:SetOffsets(nil, style.attributesOffset);
  anchor:Set(ZO_PlayerAttribute);
end;

function FancyActionBar.AdjustQuickSlotSpacing() -- quickslot placement and arrow visibility
  local style = FancyActionBar.GetContants();
  local weaponSwapControl = ACTION_BAR:GetNamedChild("WeaponSwap");
  local QSB = QuickslotButton;

  QSB:ClearAnchors();

  if SV.showArrow == false then
    if SV.moveQS == true then
      if not FancyActionBar.style == 1 then
        QSB:SetAnchor(RIGHT, weaponSwapControl, RIGHT, -(2 + (SLOT_COUNT * (style.abilitySlotOffsetX * scale))), -2 * scale, QSB:GetResizeToFitConstrains());
      else
        QSB:SetAnchor(RIGHT, weaponSwapControl, RIGHT, -(5 + (style.abilitySlotOffsetX * scale)), -2 * scale, QSB:GetResizeToFitConstrains());
      end;
    else
      QSB:SetAnchor(LEFT, FAB_ActionBarFakeQS, LEFT, 0, -2 * scale, QSB:GetResizeToFitConstrains());
    end;
  else
    QSB:SetAnchor(LEFT, FAB_ActionBarFakeQS, LEFT, 0, -2 * scale, QSB:GetResizeToFitConstrains());
    FAB_ActionBarArrow:SetColor(unpack(SV.arrowColor));
  end;

  -- ActionButton9:ClearAnchors()
  --
  -- if SV.showArrow == false then
  -- 	if SV.moveQS == true then
  --     if not FancyActionBar.style == 1 then
  --       ActionButton9:SetAnchor(RIGHT, weaponSwapControl, RIGHT, - (2 + (SLOT_COUNT * (style.abilitySlotOffsetX*scale))), -2 * scale)
  --     else
  --       ActionButton9:SetAnchor(RIGHT, weaponSwapControl, RIGHT, - (5 + (style.abilitySlotOffsetX*scale)), -2 * scale)
  --     end
  --   else
  --     ActionButton9:SetAnchor(LEFT, FAB_ActionBarFakeQS, LEFT, 0, -2 * scale)
  --   end
  --
  -- else
  --   ActionButton9:SetAnchor(LEFT, FAB_ActionBarFakeQS, LEFT, 0, -2 * scale)
  --   FAB_ActionBarArrow:SetColor(unpack(SV.arrowColor))
  -- end
  FAB_ActionBarArrow:SetHidden(not SV.showArrow);
end;

function FancyActionBar.AdjustUltimateSpacing() -- place the ultimate button according to variables
  if FancyActionBar.style == 1 then return; end;
  local style = FancyActionBar.GetContants();
  local weaponSwapControl = ACTION_BAR:GetNamedChild("WeaponSwap");

  ActionButton8:ClearAnchors();
  CompanionUltimateButton:ClearAnchors();

  local ultX = 10 + (10 * scale);
  local ultC = 20 + (10 * scale);
  local u = 65 * scale;
  local f1 = (style.abilitySlotWidth + style.abilitySlotOffsetX);
  local f2 = f1 * SLOT_COUNT;

  if SV.showHotkeysUltGP then
    ActionButton8:SetAnchor(LEFT, weaponSwapControl, RIGHT, f2 + u, 0, ActionButton8:GetResizeToFitConstrains());
    CompanionUltimateButton:SetAnchor(LEFT, ActionButton8, RIGHT, u + ultC, 0, CompanionUltimateButton:GetResizeToFitConstrains());
    return;
  end;

  if SV.moveQS == true then
    ActionButton8:SetAnchor(LEFT, weaponSwapControl, RIGHT, f2 + ultX, 0, ActionButton8:GetResizeToFitConstrains());
    CompanionUltimateButton:SetAnchor(LEFT, ActionButton8, RIGHT, 20 + ultX, 0, CompanionUltimateButton:GetResizeToFitConstrains());
  else
    ActionButton8:SetAnchor(LEFT, weaponSwapControl, RIGHT, f2 + u, 0, ActionButton8:GetResizeToFitConstrains());
    -- ActionButton8:SetAnchor(RIGHT, ZO_ActionBar1, RIGHT, 40 * scale, 0)
    CompanionUltimateButton:SetAnchor(LEFT, ActionButton8, RIGHT, u + ultC, 0, CompanionUltimateButton:GetResizeToFitConstrains());
  end;
end;

function FancyActionBar.ApplySettings() -- apply all UI settings for current UI mode
  FancyActionBar.AdjustQuickSlotSpacing();

  FancyActionBar.ConfigureFrames();
  FancyActionBar.ApplyTimerFont();
  FancyActionBar.AdjustTimerY();

  FancyActionBar.ApplyStackFont();
  FancyActionBar.AdjustStackX();

  FancyActionBar.AdjustUltTimer(false);
  FancyActionBar.ApplyUltFont(false);

  FancyActionBar.AdjustUltValue();
  FancyActionBar.ApplyUltValueColor();
  FancyActionBar.AdjustCompanionUltValue();
  FancyActionBar.ApplyUltValueFont();
  FancyActionBar.UpdateUltimateCost();

  FancyActionBar.AdjustQuickSlotTimer();
  FancyActionBar.ApplyQuickSlotFont();
  FancyActionBar.ToggleQuickSlotDuration();

  FancyActionBar.ToggleGCD();

  if FancyActionBar.initialSetup then
    FancyActionBar.initialSetup = false;
    FancyActionBar.ApplyPosition();
  end;
end;

function FancyActionBar.ToggleQuickSlotDuration() -- enable / disable quickslot timer
  local enable = FancyActionBar.constants.qs.show;
  EM:UnregisterForUpdate(NAME .. "UpdateQuickSlot");
  if enable
  then
    EM:RegisterForUpdate(NAME .. "UpdateQuickSlot", 500, FancyActionBar.UpdateQuickSlotOverlay);
  else
    FancyActionBar.qsOverlay:GetNamedChild("Duration"):SetText("");
  end;
end;

function FancyActionBar.ToggleUltimateValue() -- enable / disable ultimate value
  local e = FancyActionBar.constants.ult.value.show;
  local current, _;

  EM:UnregisterForEvent(NAME .. "UltValue", EVENT_POWER_UPDATE);
  EM:UnregisterForEvent(NAME .. "UltValueCompanion", EVENT_POWER_UPDATE);

  for i in pairs(FancyActionBar.ultOverlays) do
    local v = FancyActionBar.ultOverlays[i]:GetNamedChild("Value");
    if v then v:SetText(""); end;
  end;

  -- FancyActionBar.ultOverlays[ULT_INDEX]:GetNamedChild('Value'):SetText('')
  -- FancyActionBar.ultOverlays[ULT_INDEX + SLOT_INDEX_OFFSET]:GetNamedChild('Value'):SetText('')
  -- FancyActionBar.ultOverlays[ULT_INDEX + COMPANION_INDEX_OFFSET]:GetNamedChild('Value'):SetText('')

  -- cost1 = GetSlotAbilityCost(ULT_INDEX, HOTBAR_CATEGORY_PRIMARY)
  -- cost2 = GetSlotAbilityCost(ULT_INDEX, HOTBAR_CATEGORY_BACKUP)
  cost3 = GetSlotAbilityCost(ULT_INDEX, COMBAT_MECHANIC_FLAGS_ULTIMATE, COMPANION);

  if e then
    current, _, _ = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE);
    FancyActionBar.UpdateUltimateValueLabels(true, current);
    EM:RegisterForEvent(NAME .. "UltValue", EVENT_POWER_UPDATE, FancyActionBar.OnUltChanged);
    EM:AddFilterForEvent(NAME .. "UltValue", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE, REGISTER_FILTER_UNIT_TAG, "player");
  end;

  if (not DoesUnitExist("companion") or not HasActiveCompanion() or cost3 == nil or cost3 == 0) then
    CompanionUltimateButton:SetHidden(true);
    return;
  end;

  local c = FancyActionBar.constants.ult.companion.show;
  if c then
    current, _, _ = GetUnitPower("companion", COMBAT_MECHANIC_FLAGS_ULTIMATE);
    FancyActionBar.UpdateUltimateValueLabels(false, current);
    EM:RegisterForEvent(NAME .. "UltValueCompanion", EVENT_POWER_UPDATE, FancyActionBar.OnUltChangedCompanion);
    EM:AddFilterForEvent(NAME .. "UltValueCompanion", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE, REGISTER_FILTER_UNIT_TAG, "companion");
  end;
end;

--  ---------------------------------
--  UI Prep before initial
--  ---------------------------------
---
---@param control TopLevelWindow
function FancyActionBar.OnActionBarInitialized(control) -- backbar control initialized.
  ULTIMATE_BUTTON_STYLE.parentBar = control;

  -- Set active bar as a parent to make inactive bar show/hide automatically.
  control:SetParent(ACTION_BAR);

  -- Need to adjust it here instead of in ApplyStyle(), otherwise it won't properly work with Azurah.
  FancyActionBar.AdjustControlsPositions();

  -- Create inactive bar buttons.
  for i = MIN_INDEX + SLOT_INDEX_OFFSET, MAX_INDEX + SLOT_INDEX_OFFSET do
    ---@class ActionButton
    local button = ActionButton:New(i, ACTION_BUTTON_TYPE_VISIBLE, control, "ZO_ActionButton");
    button:SetShowBindingText(false);
    button.icon:SetHidden(true);
    button:SetupBounceAnimation();
    FancyActionBar.buttons[i] = button;
  end;
end;

function FancyActionBar.CreateOverlay(index) -- create normal skill button overlay.
  -- local template = ZO_GetPlatformTemplate('FAB_ActionButtonOverlay')
  local template = FancyActionBar.constants.style.overlayTemplate;
  local overlay = FancyActionBar.overlays[index];
  if overlay then
    WM:ApplyTemplateToControl(overlay, template);
    overlay:ClearAnchors();
    overlay.activeEffects = {};
  else
    overlay = WM:CreateControlFromVirtual("ActionButtonOverlay", ACTION_BAR, template, index);
    overlay.timer = overlay:GetNamedChild("Duration");
    overlay.bg = overlay:GetNamedChild("BG");
    overlay.stack = overlay:GetNamedChild("Stacks");
    FancyActionBar.overlays[index] = overlay;
  end;
  return overlay;
end;

function FancyActionBar.CreateUltOverlay(index) -- create ultimate skill button overlay.
  -- local template = ZO_GetPlatformTemplate('FAB_UltimateButtonOverlay')
  local template = FancyActionBar.constants.style.ultOverlayTemplate;
  local overlay = FancyActionBar.ultOverlays[index];
  if overlay then
    WM:ApplyTemplateToControl(overlay, template);
    overlay:ClearAnchors();
  else
    local parent;
    if index == ULT_INDEX + COMPANION_INDEX_OFFSET
    then
      parent = ZO_ActionBar_GetButton(ULT_SLOT, COMPANION);
    else
      parent = ZO_ActionBar_GetButton(ULT_SLOT);
    end;
    overlay = WM:CreateControlFromVirtual("UltimateButtonOverlay", parent.slot, template, index);
    overlay.timer = overlay:GetNamedChild("Duration");
    overlay.value = overlay:GetNamedChild("Value");
    FancyActionBar.ultOverlays[index] = overlay;
  end;
  return overlay;
end;

function FancyActionBar.CreateQuickSlotOverlay(index) -- create quickslot button overlay.
  -- local template = ZO_GetPlatformTemplate('FAB_QuickSlotOverlay')
  local template = FancyActionBar.constants.style.qsOverlayTemplate;
  local overlay = FancyActionBar.qsOverlay;
  if overlay then
    WM:ApplyTemplateToControl(overlay, template);
    overlay:ClearAnchors();
  else
    overlay = WM:CreateControlFromVirtual("QuickSlotOverlay", ACTION_BAR, template, index);
    FancyActionBar.qsOverlay = overlay;
  end;
  return overlay;
end;

function FancyActionBar.ApplyQuickSlotAndUltimateStyle() -- make sure UI is adjusted to settings
  local style = FancyActionBar.GetContants();
  local weaponSwapControl = ACTION_BAR:GetNamedChild("WeaponSwap");
  local QSB = QuickslotButton;

  ZO_ActionBar_GetButton(ULT_SLOT):ApplyStyle(style.ultButtonTemplate);
  ZO_ActionBar_GetButton(ULT_SLOT, COMPANION):ApplyStyle(style.ultButtonTemplate);
  -- ZO_ActionBar_GetButton(QUICK_SLOT):ApplyStyle(style.buttonTemplate)
  -- QSB:ApplyStyle(style.buttonTemplate)

  -- Reposition ultimate slot.
  if FancyActionBar.style == 2 then
    FancyActionBar.AdjustUltimateSpacing();
  else
    ActionButton8:ClearAnchors();
    CompanionUltimateButton:ClearAnchors();
    local u = style.ultimateSlotOffsetX * scale;
    local f1 = (style.abilitySlotWidth + style.abilitySlotOffsetX);
    local f2 = (f1 * SLOT_COUNT) - 2;
    ActionButton8:SetAnchor(LEFT, weaponSwapControl, RIGHT, f2 + u, -2 * scale, ActionButton8:GetResizeToFitConstrains());
    -- ActionButton8:SetAnchor(LEFT, weaponSwapControl, RIGHT, SLOT_COUNT * ((style.abilitySlotWidth*scale) + 2 * (style.abilitySlotOffsetX*scale)), -2 * scale)
    CompanionUltimateButton:SetAnchor(LEFT, ActionButton8, RIGHT, u, 0, CompanionUltimateButton:GetResizeToFitConstrains());
  end;

  local c8 = ActionButton8FlipCard;
  local c9 = ActionButton9FlipCard;
  local c38 = CompanionUltimateButtonFlipCard;

  if c8 then c8:SetDimensions(style.ultFlipCardSize, style.ultFlipCardSize); end;
  if c9 then c9:SetDimensions(style.flipCardSize, style.flipCardSize); end;
  if c38 then c38:SetDimensions(style.ultFlipCardSize, style.ultFlipCardSize); end;

  local hideUltNumber = FancyActionBar.constants.ult.value.show;
  if hideUltNumber then
    SetSetting(SETTING_TYPE_UI, UI_SETTING_ULTIMATE_NUMBER, "false");
  end;

  local leftFill = ActionButton8FillAnimationLeft;
  local rightFill = ActionButton8FillAnimationRight;
  local leftFillC = CompanionUltimateButtonFillAnimationLeft;
  local rightFillC = CompanionUltimateButtonFillAnimationRight;
  local gpFrame = ActionButton8Frame;
  local gpFrameC = CompanionUltimateButtonFrame;

  if FancyActionBar.style == 2 then
    -- safety check for gamepad ultimate display
    if leftFill ~= nil then
      leftFill:ClearAnchors();
      leftFill:SetAnchor(TOPRIGHT, ActionButton8Backdrop, TOP, 0, -24, leftFill:GetResizeToFitConstrains());
      leftFill:SetAnchor(BOTTOMLEFT, ActionButton8Backdrop, BOTTOMLEFT, -24, 24, leftFill:GetResizeToFitConstrains());
      leftFill:SetHidden(false);
    end;

    if rightFill ~= nil then
      rightFill:ClearAnchors();
      rightFill:SetAnchor(TOPLEFT, ActionButton8Backdrop, TOP, 0, -24, rightFill:GetResizeToFitConstrains());
      rightFill:SetAnchor(BOTTOMRIGHT, ActionButton8Backdrop, BOTTOMRIGHT, 24, 24, rightFill:GetResizeToFitConstrains());
      rightFill:SetHidden(false);
    end;

    if leftFillC ~= nil then
      leftFillC:ClearAnchors();
      leftFillC:SetAnchor(TOPRIGHT, CompanionUltimateButtonBackdrop, TOP, 0, -24, leftFillC:GetResizeToFitConstrains());
      leftFillC:SetAnchor(BOTTOMLEFT, CompanionUltimateButtonBackdrop, BOTTOMLEFT, -24, 24, leftFillC:GetResizeToFitConstrains());
      leftFillC:SetHidden(false);
    end;

    if rightFillC ~= nil then
      rightFillC:ClearAnchors();
      rightFillC:SetAnchor(TOPLEFT, CompanionUltimateButtonBackdrop, TOP, 0, -24, rightFillC:GetResizeToFitConstrains());
      rightFillC:SetAnchor(BOTTOMRIGHT, CompanionUltimateButtonBackdrop, BOTTOMRIGHT, 24, 24, rightFillC:GetResizeToFitConstrains());
      rightFillC:SetHidden(false);
    end;

    if gpFrame ~= nil then gpFrame:SetHidden(false); end;
    if gpFrameC ~= nil then gpFrameC:SetHidden(false); end;
  else
    if leftFill ~= nil then leftFill:SetHidden(true); end;
    if rightFill ~= nil then rightFill:SetHidden(true); end;
    if leftFillC ~= nil then leftFillC:SetHidden(true); end;
    if rightFillC ~= nil then rightFillC:SetHidden(true); end;
    if gpFrame ~= nil then gpFrame:SetHidden(true); end;
    if gpFrameC ~= nil then gpFrameC:SetHidden(true); end;
  end;

  -- front bar ult
  local u1 = FancyActionBar.CreateUltOverlay(ULT_INDEX);
  u1:SetAnchor(TOPLEFT, ActionButton8, TOPLEFT, 0, 0);
  u1:SetAnchor(BOTTOMRIGHT, ActionButton8, BOTTOMRIGHT, 0, 0);
  u1.value = u1:GetNamedChild("Value");

  -- back bar ult
  local u2 = FancyActionBar.CreateUltOverlay(ULT_INDEX + SLOT_INDEX_OFFSET);
  u2:SetAnchor(TOPLEFT, ActionButton8, TOPLEFT, 0, 0);
  u2:SetAnchor(BOTTOMRIGHT, ActionButton8, BOTTOMRIGHT, 0, 0);
  u2.value = u2:GetNamedChild("Value");

  -- companion ult
  local u3 = FancyActionBar.CreateUltOverlay(ULT_INDEX + COMPANION_INDEX_OFFSET);
  u3:SetAnchor(TOPLEFT, CompanionUltimateButton, TOPLEFT, 0, 0);
  u3:SetAnchor(BOTTOMRIGHT, CompanionUltimateButton, BOTTOMRIGHT, 0, 0);
  u3.value = u3:GetNamedChild("Value");

  -- quickslot
  local QO = FancyActionBar.CreateQuickSlotOverlay();
  -- QO:SetAnchor(TOPLEFT,     ActionButton9,            TOPLEFT,      0,  0)
  -- QO:SetAnchor(BOTTOMRIGHT, ActionButton9,            BOTTOMRIGHT,  0,  0)
  QO:SetAnchor(TOPLEFT, QSB, TOPLEFT, 0, 0);
  QO:SetAnchor(BOTTOMRIGHT, QSB, BOTTOMRIGHT, 0, 0);
  QO.timer = QO:GetNamedChild("Duration");
  QO.timer:SetColor(unpack(IsInGamepadPreferredMode() and SV.qsColorGP or SV.qsColorKB));

  local qsFrame = FancyActionBar.qsOverlay:GetNamedChild("Frame");
  if qsFrame then QO.frame = qsFrame; end;
end;

function FancyActionBar.ApplyStyle() -- apply style to action bars depending on keyboard/gamepad mode.
  FancyActionBar.UpdateStyle();
  currentHotbarCategory = GetActiveHotbarCategory();
  local style = FancyActionBar.GetContants();
  local weaponSwapControl = ACTION_BAR:GetNamedChild("WeaponSwap"); -- Most alignments are relative to weapon swap button.
  ---@diagnostic disable-next-line: redefined-local
  local lastButton;                                                 -- Set positions for buttons and overlays.
  local buttonTemplate = style.buttonTemplate;                      --ZO_GetPlatformTemplate('ZO_ActionButton')
  local overlayTemplate = style.overlayTemplate;                    --ZO_GetPlatformTemplate('FAB_ActionButtonOverlay')

  ACTION_BAR:SetWidth(style.width);

  ACTION_BAR:GetNamedChild("KeybindBG"):SetHidden(true); -- Hide default background.

  weaponSwapControl:ClearAnchors();                      -- Achor weapon swap to fake quick slot. Hide and disable mouse click.
  weaponSwapControl:SetAnchor(LEFT, FAB_ActionBarFakeQS, RIGHT, 0, 0);
  weaponSwapControl:SetAlpha(0);
  weaponSwapControl:SetMouseEnabled(false);

  for i = MIN_INDEX, MAX_INDEX do
    local button = ZO_ActionBar_GetButton(i);
    button:ApplyStyle(buttonTemplate);

    local anchorTarget = lastButton and lastButton.slot;
    if lastButton then
      button:ApplyAnchor(lastButton.slot, style.abilitySlotOffsetX);
    elseif i == MIN_INDEX then
      button.slot:ClearAnchors();
      button.slot:SetAnchor(BOTTOMLEFT, weaponSwapControl, RIGHT, 0, -4);
    end;
    lastButton = button;

    local overlayOffsetX = (i - MIN_INDEX) * ((style.abilitySlotWidth) + (style.abilitySlotOffsetX));
    -- Hotkey position.
    button.buttonText:ClearAnchors();
    button.buttonText:SetAnchor(TOP, weaponSwapControl, RIGHT, (overlayOffsetX + style.abilitySlotWidth / 2), style.buttonTextOffsetY);
    button.buttonText:SetHidden(not SV.showHotkeys);

    if SV.toggledHighlight or SV.showHighlight
    then
      button.status:SetTexture("FancyActionBar+/texture/blank.dds");
    else
      button.status:SetTexture("EsoUI/Art/ActionBar/ActionSlot_toggledon.dds");
    end;
  end;

  for i = MIN_INDEX, MAX_INDEX do
    -- Main button overlay.
    local overlay = FancyActionBar.CreateOverlay(i);

    if i == MIN_INDEX
    then
      overlay:SetAnchor(BOTTOMLEFT, weaponSwapControl, RIGHT, 0, -4);
    else
      overlay:SetAnchor(LEFT, FancyActionBar.overlays[i - 1], RIGHT, style.abilitySlotOffsetX, 0);
    end;

    -- Backbar button style and position.
    ---@type ActionButton
    local button = FancyActionBar.buttons[i + SLOT_INDEX_OFFSET];
    button:ApplyStyle(buttonTemplate);

    button.icon:SetDesaturation(SV.desaturationInactive / 100);
    button.icon:SetAlpha(SV.alphaInactive / 100);

    if SV.toggledHighlight or SV.showHighlight
    then
      button.status:SetTexture("FancyActionBar+/texture/blank.dds");
    else
      button.status:SetTexture("EsoUI/Art/ActionBar/ActionSlot_toggledon.dds");
    end;

    if i == MIN_INDEX
    then
      button.slot:SetAnchor(TOPLEFT, weaponSwapControl, RIGHT, 0, 0);
    else
      button:ApplyAnchor(lastButton.slot, style.abilitySlotOffsetX);
    end;
    lastButton = button;

    overlay = FancyActionBar.CreateOverlay(i + SLOT_INDEX_OFFSET); -- Back button overlay.

    if i == MIN_INDEX
    then
      overlay:SetAnchor(TOPLEFT, weaponSwapControl, RIGHT, 0, 0);
    else
      overlay:SetAnchor(LEFT, FancyActionBar.overlays[i + SLOT_INDEX_OFFSET - 1], RIGHT, style.abilitySlotOffsetX, 0);
    end;
    -- overlay.button = button
  end;

  FancyActionBar.ApplyQuickSlotAndUltimateStyle();

  FancyActionBar.ApplySettings();
end;

---
---@param active userdata
---@param inactive userdata
---@param firstTop boolean
local function ApplyBarPosition(active, inactive, firstTop)
  local weaponSwapControl = ACTION_BAR:GetNamedChild("WeaponSwap");
  if firstTop then
    active:SetAnchor(BOTTOMLEFT, weaponSwapControl, RIGHT, 0, -4, active:GetResizeToFitConstrains());
    inactive:SetAnchor(TOPLEFT, weaponSwapControl, RIGHT, 0, 0, inactive:GetResizeToFitConstrains());
  else
    active:SetAnchor(TOPLEFT, weaponSwapControl, RIGHT, 0, 0, active:GetResizeToFitConstrains());
    inactive:SetAnchor(BOTTOMLEFT, weaponSwapControl, RIGHT, 0, -4, inactive:GetResizeToFitConstrains());
  end;
end;

function FancyActionBar.SwapControls() -- refresh action bars positions.
  local style = FancyActionBar.GetContants();
  local hide;
  local bar;

  -- Set new anchors for the first buttons and ultimate buttons.
  ActionButton3:ClearAnchors();
  ActionButton23:ClearAnchors();
  ActionButtonOverlay3:ClearAnchors();
  ActionButtonOverlay23:ClearAnchors();
  if currentHotbarCategory == HOTBAR_CATEGORY_BACKUP then
    bar = 0;
    hide = true;
    if SV.staticBars then
      ApplyBarPosition(ActionButton23, ActionButton3, SV.frontBarTop);
      ApplyBarPosition(ActionButtonOverlay23, ActionButtonOverlay3, not SV.frontBarTop);
    else
      ApplyBarPosition(ActionButton3, ActionButton23, SV.activeBarTop);
      ApplyBarPosition(ActionButtonOverlay23, ActionButtonOverlay3, SV.activeBarTop);
    end;
  else
    bar = 1;
    hide = false;
    if SV.staticBars then
      ApplyBarPosition(ActionButton3, ActionButton23, SV.frontBarTop);
      ApplyBarPosition(ActionButtonOverlay23, ActionButtonOverlay3, not SV.frontBarTop);
    else
      ApplyBarPosition(ActionButton3, ActionButton23, SV.activeBarTop);
      ApplyBarPosition(ActionButtonOverlay3, ActionButtonOverlay23, SV.activeBarTop);
    end;
  end;

  FancyActionBar.ultOverlays[ULT_INDEX]:SetHidden(hide);
  FancyActionBar.ultOverlays[ULT_INDEX + SLOT_INDEX_OFFSET]:SetHidden(not hide);

  for i = MIN_INDEX, MAX_INDEX do
    -- Update icons for inactive bar.
    local index = currentHotbarCategory == HOTBAR_CATEGORY_BACKUP and i or i + SLOT_INDEX_OFFSET;
    -- local index         = (bar * SLOT_INDEX_OFFSET) + i
    -- local btnBackSlotId = slottedIds[index].ability
    local btnBack = FancyActionBar.buttons[i + SLOT_INDEX_OFFSET];
    FancyActionBar.UpdateInactiveBarIcon(i, bar);

    local btnMain = ZO_ActionBar_GetButton(i); -- Need to update main buttons manually, because by default it is done when animation ends.
    btnMain:HandleSlotChanged();
  end;

  -- Unslot effects from the main bar if it's currently a special bar.
  if currentHotbarCategory ~= HOTBAR_CATEGORY_PRIMARY and currentHotbarCategory ~= HOTBAR_CATEGORY_BACKUP then
    for i = MIN_INDEX, MAX_INDEX do
      FancyActionBar.UnslotEffect(i);
    end;
  end;
end;

function FancyActionBar.ApplyPosition() -- check if action bar should be moved.
  FancyActionBar.HideHotkeys(not SV.showHotkeys);

  FancyActionBar.MoveActionBar();
end;

function FancyActionBar.UpdateBarSettings() -- run all UI visual updates when UI mode is changed.
  FancyActionBar.UpdateStyle();
  FancyActionBar.SetScale();
  -- FancyActionBar.SetMoved(false)
  FancyActionBar.ApplyStyle();
  FancyActionBar.SwapControls();
  FancyActionBar.AdjustControlsPositions();
  FancyActionBar.ApplyPosition();
end;

function FancyActionBar.SetScale() -- resize and check for other addons with same function
  local enable = FancyActionBar.constants.abScale.enable;
  local s;

  if enable then
    local S = FancyActionBar.constants.abScale.scale;
    s = S / 100;
  else
    s = 1;
  end;

  scale = s;
  FancyActionBar.UpdateScale(s);
end;

--------------------------------------------------------------------------------
-------------------------------[    Hooks   ]-----------------------------------
--------------------------------------------------------------------------------
local origApplySwapAnimationStyle = ActionButton["ApplySwapAnimationStyle"];
local swapSize;
local function ApplySwapAnimationStyle(self, button)
  local timeline = self.button.hotbarSwapAnimation;
  if timeline then
    local width, height = self.flipCard:GetDimensions();
    local firstAnimation = timeline:GetFirstAnimation();
    local lastAnimation = timeline:GetLastAnimation();

    firstAnimation:SetStartAndEndWidth(width, width);
    firstAnimation:SetStartAndEndHeight(height, 0);
    lastAnimation:SetStartAndEndWidth(width, width);
    lastAnimation:SetStartAndEndHeight(0, height);
  end;
end;
ActionButton["ApplySwapAnimationStyle"] = ApplySwapAnimationStyle;

local origSetUltimateMeter = ActionButton["SetUltimateMeter"];
local function FancySetUltimateMeter(self, ultimateCount, setProgressNoAnim)
  local isSlotUsed = IsSlotUsed(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, self.button.hotbarCategory);
  local barTexture = GetControl(self.slot, "UltimateBar");
  local leadingEdge = GetControl(self.slot, "LeadingEdge");
  local ultimateReadyBurstTexture = GetControl(self.slot, "ReadyBurst");
  local ultimateReadyLoopTexture = GetControl(self.slot, "ReadyLoop");
  local ultimateFillLeftTexture = GetControl(self.slot, "FillAnimationLeft");
  local ultimateFillRightTexture = GetControl(self.slot, "FillAnimationRight");
  local ultimateFillFrame = GetControl(self.slot, "Frame");

  local isGamepad = false;
  if FancyActionBar.style == 2 then isGamepad = true; end;

  if isSlotUsed then
    -- Show fill bar if platform appropriate
    ultimateFillFrame:SetHidden(not isGamepad);
    ultimateFillLeftTexture:SetHidden(not isGamepad);
    ultimateFillRightTexture:SetHidden(not isGamepad);

    if ultimateCount >= self.currentUltimateMax then
      --hide progress bar
      barTexture:SetHidden(true);
      leadingEdge:SetHidden(true);

      -- Set fill bar to full
      self:PlayUltimateFillAnimation(ultimateFillLeftTexture, ultimateFillRightTexture, 1, setProgressNoAnim);
      self:PlayUltimateReadyAnimations(ultimateReadyBurstTexture, ultimateReadyLoopTexture, setProgressNoAnim);
    else
      --stop animation
      ultimateReadyBurstTexture:SetHidden(true);
      ultimateReadyLoopTexture:SetHidden(true);
      self:StopUltimateReadyAnimations();

      -- show platform appropriate progress bar
      barTexture:SetHidden(isGamepad);
      leadingEdge:SetHidden(isGamepad);

      -- update both platforms progress bars
      local slotHeight = FancyActionBar.constants.style.ultSize;       --self.slot:GetHeight()    the only change needed...
      local percentComplete = ultimateCount / self.currentUltimateMax;
      local yOffset = zo_floor(slotHeight * (0.97 - percentComplete)); -- changed from 1 cause normally the bar shows below the button when at 0 and my OCD can't handle.
      barTexture:SetHeight(yOffset);

      leadingEdge:ClearAnchors();
      leadingEdge:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, yOffset - 5);
      leadingEdge:SetAnchor(TOPRIGHT, nil, TOPRIGHT, 0, yOffset - 5);

      self:PlayUltimateFillAnimation(ultimateFillLeftTexture, ultimateFillRightTexture, percentComplete, setProgressNoAnim);
      self:AnchorKeysOut();
    end;

    self:UpdateUltimateNumber();
  else
    --stop animation
    ultimateReadyBurstTexture:SetHidden(true);
    ultimateReadyLoopTexture:SetHidden(true);
    self:StopUltimateReadyAnimations();
    self:ResetUltimateFillAnimations();

    --hide progress bar for all platforms
    barTexture:SetHidden(true);
    leadingEdge:SetHidden(true);
    ultimateFillLeftTexture:SetHidden(true);
    ultimateFillRightTexture:SetHidden(true);
    ultimateFillFrame:SetHidden(true);
    self:AnchorKeysOut();
  end;
  -- self:HideKeys(not isGamepad)
end;

ActionButton["SetUltimateMeter"] = FancySetUltimateMeter;

function FancyActionBar.UpdateStyle()
  local style = {};
  local mode;

  if FancyActionBar.initialSetup then
    mode = IsInGamepadPreferredMode() and 2 or 1;
  else
    if ADCUI then
      if ADCUI:originalIsInGamepadPreferredMode() then
        if ADCUI:shouldUseGamepadUI()
        then
          mode = 2;
        else
          mode = ADCUI:shouldUseGamepadActionBar() and 2 or 1;
        end;
      else
        mode = 1;
      end;
    else
      mode = IsInGamepadPreferredMode() and 2 or 1;
    end;
  end;

  if mode == 1 then
    style = KEYBOARD_CONSTANTS;
    swapSize = 47;
  else
    style = GAMEPAD_CONSTANTS;
    swapSize = 67;
  end;
  -- style = mode == 1 and KEYBOARD_CONSTANTS or GAMEPAD_CONSTANTS
  FancyActionBar.style = mode;

  local offsetY = FancyActionBar.style == 2 and -75 or -22;
  FAB_Default_Bar_Position:ClearAnchors();
  FAB_Default_Bar_Position:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, offsetY, FAB_Default_Bar_Position:GetResizeToFitConstrains());

  FancyActionBar.constants = FancyActionBar:UpdateContants(mode, SV, style);
  ActionButton.ApplySwapAnimationStyle = ApplySwapAnimationStyle;
  ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1):ApplySwapAnimationStyle();
end;

-------------------------------------------------------------------------------
-----------------------------[  Helper & Debugging  ]--------------------------
-------------------------------------------------------------------------------
function FancyActionBar.IdentifyIndex(number, bar)
  local index;
  if bar == HOTBAR_CATEGORY_BACKUP then
    if number == 8
    then
      index = ULT_INDEX + SLOT_INDEX_OFFSET;
    else
      index = number + SLOT_INDEX_OFFSET;
    end;
  else
    index = number;
  end;
  return index;
end;

function FancyActionBar.IdCheck(index, id)
  if abilityConfig[id] and abilityConfig[id] == false then return false; end;
  if slottedIds[index] ~= nil and slottedIds[index].ability ~= slottedIds[index].effect then
    if FancyActionBar.toggled[id] then return true; end;
    if not FancyActionBar.traps[id] then return false; end;
  end;
  return true;
end;

function FancyActionBar.PostEffectUpdate(name, id, change, duration, stacks, when)
  if id == 61744 then return; end;
  if duration == 0 then if not FancyActionBar.toggled[id] then return; end; end;
  local type;
  if change == EFFECT_RESULT_GAINED then
    type = "Gained";
  elseif change == EFFECT_RESULT_UPDATED then
    type = "Updated";
  end;
  local stack = ".";
  if (stacks ~= nil and stacks > 0) then stack = " (x" .. stacks .. ")."; end;
  FancyActionBar:dbg("[<<2>> (<<3>>)] <<1>>: <<4>><<5>>", type, name, id, strformat("%0.1fs", duration), stack);
end;

function FancyActionBar.PostEffectFade(name, id, tag)
  if tag then if string.find(tag, "companion") then return; end; end;
  local uptime = strformat("%0.3fs", FancyActionBar.activeCasts[id].fade - FancyActionBar.activeCasts[id].begin);
  local delay = ".";
  if FancyActionBar.activeCasts[id].cast > 0 then
    delay = strformat(" (%0.3fs).", FancyActionBar.activeCasts[id].fade - FancyActionBar.activeCasts[id].cast);
  end;
  FancyActionBar:dbg("[<<1>> (<<2>>)] faded after <<3>><<4>>", name, id, uptime, delay);
  FancyActionBar.activeCasts[id] = nil;
end;

function FancyActionBar.PostAllChanges(e, change, eSlot, eName, tag, gain, fade, stacks, icon, bType, eType, aType, seType, uName, unitId, aId, sType)
  if FancyActionBar.ignore[aId] then return; end;
  -- if GetAbilityBuffType(aId) and GetAbilityBuffType(aId) ~= BUFF_TYPE_NONE then return end
  -- if aType == 0 then return end -- passives (annoying when bar swapping)

  if FancyActionBar.IsGroupUnit(tag) then
    if AreUnitsEqual("player", tag) then return; end; -- filter doubles from 'player' and players 'group' tags.
  end;

  local types = {
    [EFFECT_RESULT_GAINED] = "Gained";
    [EFFECT_RESULT_FADED] = "Faded";
    [EFFECT_RESULT_UPDATED] = "Updated";
    [EFFECT_RESULT_FULL_REFRESH] = "Refreshed";
    [EFFECT_RESULT_TRANSFER] = "Transfered";
  };
  local ts = tostring;
  local type = types[change] or "?";
  local dur, s;

  if (fade ~= nil and gain ~= nil)
  then
    dur = strformat(" %0.1f", fade - gain) .. "s";
  else
    dur = 0;
  end;

  if stacks and stacks > 0
  then
    s = " x" .. ts(stacks) .. ".";
  else
    s = ".";
  end;

  if not SV.debugVerbose then
    if change == EFFECT_RESULT_FADED
    then
      Chat("[" .. ts(aId) .. "] " .. eName .. ": " .. type .. " --> " .. uName);
    else
      Chat("[" .. ts(aId) .. "] " .. eName .. ": " .. type .. " --> " .. uName .. dur .. s);
    end;
  else
    Chat(eName .. " (" .. ts(aId) .. ")" .. "\nchange: " .. types[change] .. " || stacks: " .. ts(stacks) .. " || duration: " .. ts(dur) .. " || slot: " .. ts(eSlot) .. " || tag: " .. ts(tag) .. " || unit: " .. ts(uName) .. " || unitId: " .. ts(unitId) .. " || buffType: " .. bType .. " || effectType: " .. ts(eType) .. " || abilityType: " .. ts(aType) .. " || statusEffectType: " .. ts(seType) .. "\n===================");
  end;
end;

function FancyActionBar.UnitCheck(unitTag, unitId)
  if unitId ~= nil then
    if (not AreUnitsEqual("player", unitTag)) then return true; end;
    if unitTag == "" then return true; end;
  end;
  return false;
end;

function FancyActionBar.ShouldTrackAsDebuff(id, tag)
  if not SV.advancedDebuff then return false; end;
  if id == 38791 then return false; end; -- ZoS seem to think that Stampede is a debuff and not a ground effect :S
  if tag ~= nil then
    if AreUnitsEqual("player", tag) or FancyActionBar.IsGroupUnit(tag) then return false; end;
  end;
  return true;
end;

function FancyActionBar.ShouldHideIfNotOnTarget(Id) -- a setting I didn't finish making yet.
  local hide;
  if FancyActionBar.constants.hideOnNoTargetList[Id]
  then
    hide = FancyActionBar.constants.hideOnNoTargetList[Id];
  else
    hide = FancyActionBar.constants.hideOnNoTargetGlobal;
  end;
  return hide;
end;

local fdNum = 0;
local fdStacks = {};
local lastCW = 0; -- track when last crystal weapon debuff was applied
function FancyActionBar.HandleSpecial(id, change, updateTime, beginTime, endTime, unitTag, unitId)
  -- abilities that have multiple trigger ids.
  -- individual handling for each of them below.
  local effect;        -- the ability we are updating
  local update = true; -- update the stacks display for the ability. not sure why I called it this.

  if FancyActionBar.specialEffects[id] then
    local specialEffect = FancyActionBar.specialEffects[id];
    for effectId, effect in pairs(FancyActionBar.effects) do
      if effect.id == specialEffect.id then
        if change == EFFECT_RESULT_GAINED then
          if specialEffect.fixedTime then
            endTime = updateTime + specialEffect.fixedTime;
            specialEffect.endTime = endTime;
          end;
          if specialEffect.stacks then
            FancyActionBar.stacks[specialEffect.stackId] = specialEffect.stacks;
          end;
          for i, x in pairs(specialEffect) do effect[i] = x; end;
          effect.beginTime = updateTime;
          FancyActionBar.effects[effectId] = effect;
          if FancyActionBar.activeCasts[effect.id] then FancyActionBar.activeCasts[effect.id].begin = updateTime; end;
        elseif change == EFFECT_RESULT_FADED then
          -- Ignore the Ability Fading in the Same GCD as it was cast (indicates a recast)
          if updateTime < effect.beginTime + 0.5 then return; end;
          -- Ignore the ability fading because it either already proced it's next effect
          if effect.hasProced > specialEffect.hasProced then return; end;
          -- Get the proc update data for the special effect
          if FancyActionBar.specialEffectProcs[id] then
            local procUpddates = FancyActionBar.specialEffectProcs[id];
            local procValues = procUpddates[effect.procs];
            for i, x in pairs(procValues) do effect[i] = x; end;
            if effect.stacks then
              FancyActionBar.stacks[effect.stackId] = effect.stacks;
            end;
            FancyActionBar.effects[effectId] = effect;
          end;
        end;
      end;
      FancyActionBar.UpdateEffect(effect);
      if update then
        FancyActionBar.HandleStackUpdate(effect.id);
      end;
    end;
  else
    -- The old system of special effectIds
    if (change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED) then
      if (id == 40465) then -- scalding rune placed
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[id];
        update = false;
      elseif (id == 46331) then -- crystal weapon
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[id];
        FancyActionBar.stacks[effect.id] = 2;
        update = true;
      elseif (FancyActionBar.traps[id] and endTime - beginTime > 2) then
        FancyActionBar.effects[FancyActionBar.traps[id]].stackId = FancyActionBar.traps[id];
        effect = FancyActionBar.effects[FancyActionBar.traps[id]];
        -- FancyActionBar.trapTimers[effect.id] = endTime
        -- UpdateEffect(effect)
        -- return
      elseif FancyActionBar.meteor[id] then
        FancyActionBar.effects[FancyActionBar.meteor[id]].stackId = FancyActionBar.meteor[id];
        effect = FancyActionBar.effects[FancyActionBar.meteor[id]];
      elseif FancyActionBar.frozen[id] then -- (id == 86179) then -- frozen device
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[id];
        if not FancyActionBar.stacks[id] then FancyActionBar.stacks[id] = 0; end;
        fdNum = fdNum + 1;
        fdStacks[fdNum] = beginTime;
        FancyActionBar.stacks[id] = fdNum;
      elseif (id == 37475) then -- manifestation of terror cast
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[id];
        FancyActionBar.stacks[effect.id] = 1;
        endTime = endTime - 0;
      elseif (id == 76634) then -- manifestation of terror trigger
        FancyActionBar.effects[37475].stackId = 37475;
        effect = FancyActionBar.effects[37475];
        FancyActionBar.stacks[37475] = FancyActionBar.stacks[37475] - 1;
        if FancyActionBar.stacks[37475] <= 0 then endTime = updateTime; end;
      elseif id == FancyActionBar.sCorch.id1 then
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[id];
        if not FancyActionBar.stacks[id] then FancyActionBar.stacks[id] = 0; end;
        FancyActionBar.stacks[id] = 2;
        endTime = updateTime + 9;
        -- elseif id == FancyActionBar.deepFissure.id1 then
        --   FancyActionBar.effects[id].stackId = id;
        --   effect = FancyActionBar.effects[id];
        --   if not FancyActionBar.stacks[id] then FancyActionBar.stacks[id] = 0; end;
        --   FancyActionBar.stacks[id] = 2;
        --   endTime = updateTime + 9;
      elseif id == FancyActionBar.subAssault.id1 then
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[id];
        if not FancyActionBar.stacks[id] then FancyActionBar.stacks[id] = 0; end;
        FancyActionBar.stacks[id] = 2;
        endTime = updateTime + 6;
      else
        if FancyActionBar.effects[id] then
          FancyActionBar.effects[id].stackId = id;
          effect = FancyActionBar.effects[id];
        end;
      end;
      if effect then
        -- effect.faded    = false
        effect.endTime = endTime;
        if FancyActionBar.activeCasts[effect.id] then FancyActionBar.activeCasts[effect.id].begin = updateTime; end;
      end;
    elseif (change == EFFECT_RESULT_FADED) then
      if FancyActionBar.meteor[id] then
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[FancyActionBar.meteor[id]];
        effect.endTime = endTime;
      elseif (id == 46331) then -- crystal weapon
        -- if unitTag == 'reticleover' then return end
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[id];
        FancyActionBar.stacks[effect.id] = 0;
        effect.endTime = endTime;
        update = true;
      elseif id == FancyActionBar.sCorch.id1 then
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[id];
        if FancyActionBar.stacks[id] == 2 then FancyActionBar.stacks[id] = 1; end;
      elseif id == FancyActionBar.sCorch.id2 then
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[FancyActionBar.sCorch.id1];
        if effect.endTime <= updateTime
        then
          FancyActionBar.stacks[FancyActionBar.sCorch.id1] = 0;
        else
          update = false;
        end;
        -- elseif id == FancyActionBar.deepFissure.id1 then
        --   FancyActionBar.effects[id].stackId = id;
        --   effect = FancyActionBar.effects[id];
        --   if FancyActionBar.stacks[id] == 2 then FancyActionBar.stacks[id] = 1; end;
        -- elseif id == FancyActionBar.deepFissure.id2 then
        --   FancyActionBar.effects[FancyActionBar.deepFissure.id1].stackId = id;
        --   effect = FancyActionBar.effects[FancyActionBar.deepFissure.id1];
        --   if effect.endTime <= updateTime
        --   then
        --     FancyActionBar.stacks[FancyActionBar.deepFissure.id1] = 0;
        --   else
        --     update = false;
        --   end;
      elseif id == FancyActionBar.subAssault.id1 then
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[id];
        if FancyActionBar.stacks[id] == 2 then FancyActionBar.stacks[id] = 1; end;
      elseif id == FancyActionBar.subAssault.id2 then
        FancyActionBar.effects[FancyActionBar.subAssault.id1].stackId = id;
        effect = FancyActionBar.effects[FancyActionBar.subAssault.id1];
        if effect.endTime <= updateTime
        then
          FancyActionBar.stacks[FancyActionBar.subAssault.id1] = 0;
        else
          update = false;
        end;
      elseif FancyActionBar.frozen[id] then -- (id == 86179) then -- frozen device
        FancyActionBar.effects[id].stackId = id;
        if FancyActionBar.effects[id].endTime == 0 then return; end;
        if not FancyActionBar.stacks[id] then return; end;
        local faded = 0;
        local fadeTime = 0;
        for i = 1, #fdStacks do
          if fdStacks[i] == beginTime then
            faded = i;
            fdStacks = nil;
          else
            if (fdStacks[i] > fadeTime) then fadeTime = fdStacks[i]; end;
          end;
          if (faded > 0 and i > faded) then fdStacks[i - 1] = fdStacks[i]; end;
        end;

        effect = FancyActionBar.effects[id];
        fdNum = fdNum - 1;
        if fdNum >= 1 then
          if fadeTime + 15.5 > updateTime then
            effect.endTime = fadeTime + 15.5;
            FancyActionBar.stacks[id] = fdNum;
          else
            FancyActionBar.stacks[id] = 0;
            effect.endTime = endTime;
          end;
        else
          FancyActionBar.stacks[id] = 0;
          effect.endTime = endTime;
        end;
      elseif id == 37475 then -- manifestation of terror
        FancyActionBar.effects[id].stackId = id;
        effect = FancyActionBar.effects[id];
        if effect.endTime - updateTime > 1 and FancyActionBar.stacks[id] > 0 then
          return;
        elseif effect.endTime <= updateTime + 1 then
          FancyActionBar.stacks[id] = 0;
        end;
      end;
    end;
    if effect then
      FancyActionBar.UpdateEffect(effect);
      if update then
        FancyActionBar.HandleStackUpdate(effect.id);
      end;
    else
      return;
    end;
  end;
end;

function FancyActionBar.RefreshEffects()
  FancyActionBar.activeCasts = {};

  for effect, data in pairs(FancyActionBar.effects) do data.endTime = 0; end;

  for id in pairs(FancyActionBar.stacks) do
    FancyActionBar.stacks[id] = 0;
    FancyActionBar.HandleStackUpdate(id);

    if (id == 61905 or id == 61919 or id == 61927) then
      if GFC then
        local _;
        GFC.OnEffectChanged(_, 2, _, GetAbilityName(id), "player", _, _, 1, _, _, _, _, _, _, _, id);
        GFC.UpdateStacks(0);
      end;
    end;
  end;

  local t = time();

  for i = 1, GetNumBuffs("player") do
    local name, startTime, endTime, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo("player", i);

    if not castByPlayer then
      if SV.externalBuffs then
        local effect = FancyActionBar.effects[abilityId];
        if effect then
          if startTime == endTime then
            FancyActionBar.UpdatePassiveEffect(effect.id, true);
          else
            if (not FancyActionBar.activeCasts[effect.id] --[[and effect.id ~= 61744]]) then
              local slot = nil;
              if effect.slot1 then slot = effect.slot1; elseif effect.slot2 then slot = effect.slot2; end;
              FancyActionBar.activeCasts[effect.id] = { slot = slot; cast = 0; begin = 0; fade = 0 };
            end;
            if endTime - t > 0 then
              FancyActionBar.activeCasts[effect.id].begin = startTime;
              effect.endTime = endTime;
              FancyActionBar.UpdateEffect(effect);
            end;
          end;
        end;
      end;
    else
      if FancyActionBar.stackMap[abilityId] then
        for id, effect in pairs(FancyActionBar.effects) do
          if effect.stackId and (abilityId == effect.stackId) then
            FancyActionBar.stacks[abilityId] = stackCount or 0;
            FancyActionBar.HandleStackUpdate(id);
          end;
        end;
      end;
      local id = abilityId;
      if (id == 61905 or id == 61919 or id == 61927) then
        if GFC then -- Manually update GrimFocusCounter if enabled
          local _;
          GFC.OnEffectChanged(_, 3, _, GetAbilityName(id), "player", _, _, 0, _, _, _, _, _, _, _, id);
        end;
      end;

      local effect = FancyActionBar.effects[abilityId];
      if effect then
        if FancyActionBar.toggles[abilityId] then
          FancyActionBar.UpdateToggledAbility(abilityId, true);
          return;
        end;

        if endTime - t > 0 then
          if not FancyActionBar.activeCasts[effect.id] then
            local slot = nil;
            if effect.slot1 then slot = effect.slot1; elseif effect.slot2 then slot = effect.slot2; end;
            FancyActionBar.activeCasts[effect.id] = { slot = slot; cast = 0; begin = 0; fade = 0 };
          end;

          if FancyActionBar.activeCasts[effect.id] then
            FancyActionBar.activeCasts[effect.id].begin = startTime;
            effect.endTime = endTime;
            FancyActionBar.UpdateEffect(effect);
          end;
        end;
      end;
    end;
  end;
end;

-- local groundString    = GetString(SI_ABILITY_TOOLTIP_TARGET_TYPE_GROUND)
-- local groundAbilities = {}
-- local LAST_ABILITY    = 0
-- local LAST_BUTTON     = 0
--
-- local function CheckGroundAbility(id)
-- 	local result = groundAbilities[id]
-- 	if result == nil then
-- 		result = GetAbilityTargetDescription(id) == groundString
-- 		groundAbilities[id] = result
-- 	end
-- 	return result
-- end

-------------------------------------------------------------------------------
-----------------------------[      Initialize      ]--------------------------
-------------------------------------------------------------------------------
local noget = false;
function FancyActionBar.Initialize()
  defaultSettings = FancyActionBar.defaultSettings;
  SV = ZO_SavedVars:NewAccountWide("FancyActionBarSV", FancyActionBar.variableVersion, nil, defaultSettings, GetWorldName());
  CV = ZO_SavedVars:NewCharacterIdSettings("FancyActionBarSV", FancyActionBar.variableVersion, nil, FancyActionBar.defaultCharacter, GetWorldName());

  for i = MIN_INDEX, ULT_INDEX do
    FancyActionBar.SetSlottedEffect(i, 0, 0);
    FancyActionBar.SetSlottedEffect(i + SLOT_INDEX_OFFSET, 0, 0);
  end;

  FancyActionBar.ValidateVariables();
  FancyActionBar.UpdateStyle();

  FancyActionBar.initialized = true;

  FancyActionBar.UpdateTextures();

  if GetDisplayName() == "@dack_janiels" then
    FancyActionBar.SetPersonalSettings();
    noget = true;
    if SV.debuffTable == nil then SV.debuffTable = {}; end;
  end;

  SLASH_COMMANDS[slashCommand] = FancyActionBar.SlashCommand;

  FancyActionBar.SetScale();
  FancyActionBar.RefreshUpdateConfiguration();
  FancyActionBar.UpdateDurationLimits();
  FancyActionBar:InitializeDebuffs(NAME, SV);
  FancyActionBar.BuildMenu(SV, CV, defaultSettings);
  FancyActionBar.BuildAbilityConfig();
  FancyActionBar.SetupGCD();
  FancyActionBar.ApplyDeathStateOption();
  debug = SV.debug;

  FancyActionBar.player.name = zo_strformat("<<!aC:1>>", GetUnitName("player"));

  --ANTIQUITY_DIGGING_SCENE = 'antiquityDigging'
  --LOCK_PICK_SCENE = 'lockpickKeyboard'

  local function LockSkillsOnTrade()
    if TRADE_WINDOW.state == 3 then return false; end;
    if SM.currentScene:GetName() == "antiquityDigging" then return false; end;
    return true;
  end;

  local useSlotsOverride = true;
  if PerfectWeave and SV.perfectWeave then useSlotsOverride = false; end;

  if useSlotsOverride then
    -- Can use abilities while map is open, when cursor is active, etc.
    ---
    ---@return boolean?
    ZO_ActionBar_CanUseActionSlots = function ()
      if SV.lockInTrade
      then
        return LockSkillsOnTrade();
        -- https://github.com/esoui/esoui/blob/pts7.0/esoui/ingame/actionbar/actionbar.lua
      else
        return (not (IsGameCameraActive() or IsInteractionCameraActive() or IsProgrammableCameraActive()) or SM:IsShowing("hud")) and not IsUnitDead("player");
      end;
    end;
  end;

  -- Slot ability changed, e.g. summoned a pet, procced crystal, etc.
  local function OnSlotChanged(_, n)
    local btn = ZO_ActionBar_GetButton(n);
    if btn then
      btn:HandleSlotChanged();
      if (n == ULT_INDEX or n == ULT_INDEX + SLOT_INDEX_OFFSET) then
        FancyActionBar.UpdateUltimateCost();
      end;
      FancyActionBar.UpdateSlottedSkillsDecriptions();
    end;
    -- Chat('Slot ' .. tostring(n) .. ' changed')
  end;

  -- Button (usable) state changed.
  local function OnSlotStateChanged(_, n)
    local btn = ZO_ActionBar_GetButton(n);
    if btn then btn:UpdateState(); end;
  end;

  -- Any skill swapped. Setup buttons and slot effects.
  local function OnAllHotbarsUpdated()
    for i = MIN_INDEX, MAX_INDEX do -- ULT_INDEX do
      local button = ZO_ActionBar_GetButton(i);
      if button then
        button.hotbarSwapAnimation = nil; -- delete default animation
        button.noUpdates = true;          -- disable animation updates
        button.showTimer = false;
        button.stackCountText:SetHidden(true);
        button.timerText:SetHidden(true);
        button.timerOverlay:SetHidden(true);
        button:HandleSlotChanged(); -- update slot manually
        button.buttonText:SetHidden(not SV.showHotkeys);
      end;
      if (currentHotbarCategory == HOTBAR_CATEGORY_PRIMARY or currentHotbarCategory == HOTBAR_CATEGORY_BACKUP) then
        local altbutton = ZO_ActionBar_GetButton(i, currentHotbarCategory == HOTBAR_CATEGORY_PRIMARY and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY);
        if altbutton then
          altbutton.noUpdates = true;
          altbutton.showTimer = false;
          altbutton.showBackRowSlot = false;
        end;
      end;
    end;
    FancyActionBar.SlotEffects();
    FancyActionBar.ToggleUltimateValue();
    FancyActionBar.UpdateSlottedSkillsDecriptions();
  end;

  local function OnActiveWeaponPairChanged()
    currentHotbarCategory = GetActiveHotbarCategory();
    FancyActionBar.SwapControls();
  end;

  -- IsAbilityUltimate(*integer* _abilityId_)
  local function OnAbilityUsed(_, n)
    if (n >= MIN_INDEX and n <= ULT_INDEX) then -- or n == (ULT_INDEX + SLOT_INDEX_OFFSET) then
      -- local duration = t + (GetActionSlotEffectTimeRemaining(n, currentHotbarCategory) / 1000)
      local id = FancyActionBar.GetSlotTrueBoundId(n, currentHotbarCategory);
      local index = FancyActionBar.IdentifyIndex(n, currentHotbarCategory);
      local name = GetAbilityName(id);
      local t = time();
      local effect = FancyActionBar.SlotEffect(index, id);
      -- local effect = FancyActionBar.effects[id]
      local i = FancyActionBar.GetSlottedEffect(index);


      -- lastButton = index

      if (i and FancyActionBar.activeCasts[i] == nil and not FancyActionBar.ignore[id]) then -- track when the skill was used and ignore other events for it that is lower than the GCD
        if (abilityConfig[id] and abilityConfig[id] ~= false) then
          FancyActionBar.activeCasts[i] = { slot = index; cast = t; begin = 0; fade = 0 };
        end;
      end;

      if FancyActionBar.IdCheck(index, id) == false then
        local E = FancyActionBar.effects[i];
        if E then
          if fakes[i] then activeFakes[i] = true; end;
          if FancyActionBar.activeCasts[E.id] then FancyActionBar.activeCasts[E.id].cast = t; end;
          local D = E.toggled == true and "0" or tostring((GetAbilityDuration(i) or 0) / 1000);
          dbg("4 [ActionButton%d]<%s> #%d: " .. D, index, name, E.id);
          -- return
        end;
      end;

      if effect and FancyActionBar.toggled[effect.id] then
        local o = not FancyActionBar.toggles[effect.id];
        local O = o == true and "On" or "Off";
        dbg("3 [ActionButton%d]<%s> #%d: " .. O .. ".", index, name, effect.id);
      end;

      if effect then
        if effect.id ~= id then
          local e = FancyActionBar.effects[i];
          if e then
            if fakes[i] then activeFakes[i] = true; end;
            dbg("2 [ActionButton%d]<%s> #%d: %0.1fs", index, name, i, e.toggled == true and 0 or (GetAbilityDuration(e.id) or 0) / 1000);
          end;
        else
          if not effect.custom and effect.duration then
            effect.endTime = effect.duration + t;
            local duration = effect.duration;
            dbg("1 [ActionButton%d]<%s> #%d: %0.1fs", index, name, effect.id, (GetAbilityDuration(effect.id) or 0) / 1000);
            FancyActionBar.UpdateEffect(effect);
          else
            if fakes[id] then activeFakes[id] = true; end;
            dbg("0 [ActionButton%d]<%s> #%d: %0.1fs", index, name, effect.id, (GetAbilityDuration(effect.id) or 0) / 1000);
          end;
        end;
      elseif FancyActionBar.effects[i] then
        dbg("? [ActionButton%d]<%s> #%d: %0.1fs", index, name, FancyActionBar.effects[i].id, (GetAbilityDuration(FancyActionBar.effects[i].id) or 0) / 1000);
      else
        dbg("[ActionButton%d] #%d: %0.1fs", index, id, GetAbilityDuration(id));
      end;
    end;
    -- Chat('button ' .. n .. ' used.')
  end;

  local ABILITY_TYPE_DAMAGE = ABILITY_TYPE_DAMAGE;
  local function OnEffectChanged(eventCode, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    if SV.debugAll then
      FancyActionBar.PostAllChanges(eventCode, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType);
    end;

    local t = time();

    if (FancyActionBar.specialEffects[abilityId] or FancyActionBar.specialIds[abilityId]) and not (SV.advancedDebuff and (FancyActionBar.specialEffects[abilityId] and FancyActionBar.specialEffects[abilityId].isDebuff)) then -- abilities that need to be handled differently.
      FancyActionBar.HandleSpecial(abilityId, change, t, beginTime, endTime, unitTag, unitId);
      return;
    end;

    if (FancyActionBar.traps[abilityId]) then
      if change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
        FancyActionBar.trapTimers[abilityId] = 0;
      end;
      abilityId = FancyActionBar.traps[abilityId];
    end;

    if (abilityId == 143808 and change == EFFECT_RESULT_GAINED) then -- crystal weapon. remove a stack when the debuff is applied.
      local pCW = t - lastCW;
      if (FancyActionBar.effects[46331] and pCW > 0.5) then          -- filter out double events
        lastCW = t;
        if (FancyActionBar.stacks[46331] and FancyActionBar.stacks[46331] > 0) then
          FancyActionBar.stacks[46331] = FancyActionBar.stacks[46331] - 1;
          FancyActionBar.HandleStackUpdate(46331);
        end;
        return;
      end;
    end;

    local effect = (FancyActionBar.effects[abilityId]) or ((FancyActionBar.specialEffects[abilityId]) and { id = abilityId });
    if effect then
      if effect.toggled then -- update the highlight of toggled abilities.
        if change == EFFECT_RESULT_FADED
        then
          FancyActionBar.UpdateToggledAbility(abilityId, false);
        else
          FancyActionBar.UpdateToggledAbility(abilityId, true);
        end;
        return;
      end;

      if (effectType == DEBUFF) then -- if the ability is a debuff, check settings and handle accordingly.
        local tag = unitTag or "";

        if FancyActionBar.ShouldTrackAsDebuff(abilityId, tag) then
          effect.isDebuff = true;

          if not FancyActionBar.debuffs[abilityId] then
            FancyActionBar.debuffs[abilityId] = effect;
          end;

          FancyActionBar.OnDebuffChanged(effect, t, eventCode, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType);

          if noget == true then
            if SV.debuffTable[abilityId] == nil then SV.debuffTable[abilityId] = true; end;
          end;

          return;
        end;
      end;

      if change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
        local stackMap = FancyActionBar.stackMap;
        for stackId, stackSources in pairs(stackMap) do
          for i = 1, #stackSources do
            if stackSources[i] == abilityId then
              effect.stackId = stackId;
            end;
          end;
        end;


        if FancyActionBar.activeCasts[effect.id] then FancyActionBar.activeCasts[effect.id].begin = beginTime; end;

        if endTime ~= beginTime then -- lazy fix
          if effect.passive then FancyActionBar.UpdatePassiveEffect(effect.id, false); end;
        end;

        -- Ignore abilities which will end in less than min or longer than max (seconds).
        if (endTime > t + FancyActionBar.durationMin and endTime < t + FancyActionBar.durationMax) then
          if abilityType == GROUND_EFFECT then -- make sure to only track duration of the most recent cast of the ground ability.
            lastAreaTargets[abilityId] = unitId;
            if abilityId == 117805 then        -- unnerving boneyard sometimes updates to 25s duration, not sure why..
              effect.endTime = t + 10;
              FancyActionBar.UpdateEffect(effect);
              return;
            end;
          end;

          effect.endTime = endTime;
          for id, effect in pairs(FancyActionBar.effects) do
            if effect.stackId and (abilityId == effect.stackId) then
              FancyActionBar.stacks[abilityId] = stackCount or 0;
              FancyActionBar.HandleStackUpdate(id);
            end;
          end;
        else
          effect.endTime = 0; -- duration too long or too short. don't track.
        end;
        FancyActionBar.UpdateEffect(effect);
      elseif (change == EFFECT_RESULT_FADED) then
        if FancyActionBar.IsGroupUnit(unitTag) then return; end; -- don't track anything on group members.

        if FancyActionBar.removeInstantly[abilityId] then        -- abilities we want to reset the overlay instantly for when expired.
          effect.endTime = endTime;
          FancyActionBar.UpdateEffect(effect);
          return;
        end;

        stackCount = 0;

        if abilityId == 122658 and FancyActionBar.effects[122658] then
          FancyActionBar.effects[122658].endTime = t;
          FancyActionBar.stacks[122658] = stackCount;
          FancyActionBar.HandleStackUpdate(122658);
        end;

        if (effectType == DEBUFF or abilityId == 38791) then return; end; -- (FancyActionBar.dontFade[abilityId]) then return end

        if FancyActionBar.activeCasts[effect.id] then
          if abilityType == GROUND_EFFECT then -- prevent effect from fading if event is from previous cast of the ability when reapplied before it had expired
            if lastAreaTargets[abilityId] then
              if lastAreaTargets[abilityId] ~= unitId then return; end;
              lastAreaTargets[abilityId] = nil;
            end;
          end;

          -- crystal frags
          if (abilityId == 46327 and FancyActionBar.effects[46327]) or (FancyActionBar.activeCasts[effect.id].begin < (t - 0.7)) then
            FancyActionBar.activeCasts[effect.id].fade = t;

            -- Chat('Fading ' .. effectName .. ': ' .. string.format(t - FancyActionBar.activeCasts[effect.id].begin) .. ' / ' .. tostring(effectType))

            effect.endTime = t;
            if effect.passive then FancyActionBar.UpdateToggledAbility(abilityId, false); end;
          end;
        end;
      end;

      if FancyActionBar.stackMap[abilityId] then
        if (SV.advancedDebuff and effectType == DEBUFF) then return; end; -- is handled by debuff.lua
      end;
    end;
  end;

  -- Update overlays.
  local function Update()
    FancyActionBar.UpdateUltOverlay(ULT_INDEX);
    FancyActionBar.UpdateUltOverlay(ULT_INDEX + SLOT_INDEX_OFFSET);
    FancyActionBar.UpdateUltOverlay(ULT_INDEX + COMPANION_INDEX_OFFSET);
    for i, overlay in pairs(FancyActionBar.overlays) do FancyActionBar.UpdateOverlay(i); end;
  end;

  -- Abilities stacks.
  ---@param change EffectResult
  ---@param unitTag string
  ---@param stackCount integer
  ---@param effectType BuffEffectType
  ---@param unitName string
  ---@param unitId integer
  ---@param abilityId integer
  local function OnStackChanged(_, change, _, _, unitTag, _, _, stackCount, _, _, effectType, _, _, unitName, unitId, abilityId)
    if (SV.advancedDebuff and effectType == DEBUFF) then return; end; -- is handled by debuff.lua

    local c = "";
    if change == EFFECT_RESULT_FADED then
      c = "faded";
      stackCount = 0;
    elseif change == EFFECT_RESULT_GAINED then
      c = "gained";
    elseif change == EFFECT_RESULT_UPDATED then
      c = "updated";
    end;

    if FancyActionBar.stackMap[abilityId] then
      for id, effect in pairs(FancyActionBar.effects) do
        if effect.stackId and (abilityId == effect.stackId) then
          FancyActionBar.stacks[abilityId] = (change == EFFECT_RESULT_FADED) and 0 or stackCount;
          FancyActionBar.HandleStackUpdate(id);
        end;
      end;
    end;

    if stackCount == 0 then
      -- Remove Seething Fury effect manually, otherwise it will keep counting down.
      if abilityId == 122658 and FancyActionBar.effects[122658] then FancyActionBar.effects[122658].endTime = time(); end;
    end;
    -- Chat("[" .. abilityId .. "] " .. c .. " -> tag(" .. unitTag .. ") name(" .. unitName .. ") id(" .. unitId .. ") stacks(" .. stackCount .. ")")
  end;

  for abilityId, stackAbilities in pairs(FancyActionBar.stackMap) do
    EM:RegisterForEvent(NAME .. abilityId, EVENT_EFFECT_CHANGED, OnStackChanged);
    EM:AddFilterForEvent(NAME .. abilityId, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId);
    EM:AddFilterForEvent(NAME .. abilityId, EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER);
    for i = 1, #stackAbilities do
      EM:AddFilterForEvent(NAME .. stackAbilities[i], EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, stackAbilities[i]);
      EM:AddFilterForEvent(NAME .. stackAbilities[i], EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER);
    end;
  end;

  local function OnEquippedWeaponsChanged(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
    if bagId ~= BAG_WORN then return; end;
    if slotId == EQUIP_SLOT_MAIN_HAND or slotId == EQUIP_SLOT_BACKUP_MAIN then
      FancyActionBar.weaponFront = GetItemLinkWeaponType(GetItemLink(BAG_WORN, EQUIP_SLOT_MAIN_HAND, LINK_STYLE_DEFAULT));
      FancyActionBar.weaponBack = GetItemLinkWeaponType(GetItemLink(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN, LINK_STYLE_DEFAULT));
    end;
  end;

  local function OnDeath(eventCode, unitTag, isDead)
    if not isDead or not AreUnitsEqual("player", unitTag) then return; end;

    FancyActionBar.RefreshEffects();
    FancyActionBar:UpdateDebuffTracking();
  end;

  local function OnCombatEvent(_, result, _, aName, _, _, _, _, tName, tType, hit, _, _, _, _, tId, aId)
    local effect;

    if (FancyActionBar.needCombatEvent[aId] and result == FancyActionBar.needCombatEvent[aId].result) then
      effect = FancyActionBar.effects[aId];
      if effect then
        effect.endTime = time() + FancyActionBar.needCombatEvent[aId].duration;
        -- effect.faded = false

        -- local ts = tostring
        -- Chat('===================')
        -- Chat(aName..' ('..ts(aId)..') || result: '..ts(result)..' || hit: '..ts(hit))
        -- Chat('===================')

        FancyActionBar.UpdateEffect(effect);
        return;
      end;
    end;

    if (result == ACTION_RESULT_EFFECT_GAINED and activeFakes[aId]) then
      activeFakes[aId] = false;
      effect = FancyActionBar.effects[aId];
      if effect then
        effect.endTime = time() + fakes[aId].duration;

        -- FancyActionBar.trapTimers[effect.id] = time() + fakes[aId].duration

        FancyActionBar.UpdateEffect(effect);

        -- effect.faded = false

        -- local ts = tostring
        -- Chat('===================')
        -- Chat(aName..' ('..ts(aId)..') || result: '..ts(result)..' || hit: '..ts(hit))
        -- Chat('===================')

        FancyActionBar.UpdateEffect(effect);
      end;
    end;

    if aId == FancyActionBar.graveLordSacrifice.eventId then
      effect = FancyActionBar.effects[FancyActionBar.graveLordSacrifice.id];
      if effect then
        effect.endTime = time() + FancyActionBar.graveLordSacrifice.duration;
        FancyActionBar.UpdateEffect(effect);
      end;
    end;
  end;

  local function OnReflect(_, result, _, aName, _, _, _, _, tName, tType, hit, _, _, _, _, tId, aId)
    if (tType ~= COMBAT_UNIT_TYPE_PLAYER) then return; end;

    if SV.debugAll then
      local ts = tostring;
      Chat("===================");
      Chat(aName .. " (" .. ts(aId) .. ") || result: " .. ts(result) .. " || hit: " .. ts(hit));
      Chat("===================");
    end;

    if aId then return end

    if (FancyActionBar.reflects[aId]) then
      if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
        if FancyActionBar.iceShield[aId] then
          FancyActionBar.stacks[FancyActionBar.reflects[aId]] = 3;
        else
          FancyActionBar.stacks[FancyActionBar.reflects[aId]] = 1;
        end;
      elseif (result == ACTION_RESULT_DAMAGE_SHIELDED and FancyActionBar.iceShield[aId]) then
        FancyActionBar.stacks[FancyActionBar.reflects[aId]] = FancyActionBar.stacks[FancyActionBar.reflects[aId]] - 1;
      elseif (result == ACTION_RESULT_EFFECT_FADED) then
        FancyActionBar.stacks[FancyActionBar.reflects[aId]] = 0;
      end;
      FancyActionBar.HandleStackUpdate(FancyActionBar.reflects[aId]);
    elseif (FancyActionBar.effects[aId] and result == ACTION_RESULT_EFFECT_FADED) then
      FancyActionBar.stacks[aId] = 0;
      FancyActionBar.HandleStackUpdate(aId);
    end;
  end;

  EM:UnregisterForEvent("ZO_ActionBar", EVENT_ACTIVE_COMPANION_STATE_CHANGED);

  EM:RegisterForEvent(NAME, EVENT_ACTIVE_COMPANION_STATE_CHANGED, FancyActionBar.HandleCompanionStateChanged);
  EM:RegisterForEvent(NAME, EVENT_ACTION_SLOT_UPDATED, OnSlotChanged);
  EM:RegisterForEvent(NAME, EVENT_ACTION_SLOT_STATE_UPDATED, OnSlotStateChanged);
  EM:RegisterForEvent(NAME, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnAllHotbarsUpdated);
  EM:RegisterForEvent(NAME, EVENT_ACTION_SLOT_ABILITY_USED, OnAbilityUsed);
  EM:RegisterForEvent(NAME .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, OnDeath);
  EM:AddFilterForEvent(NAME .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "player");
  EM:RegisterForEvent(NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function ()
    uiModeChanged = true;
    FancyActionBar.UpdateBarSettings();
  end);

  EM:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function ()
    currentHotbarCategory = GetActiveHotbarCategory();
    EM:RegisterForEvent(NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnActiveWeaponPairChanged);
    FancyActionBar.ApplyStyle();
    OnAllHotbarsUpdated();
    FancyActionBar.SwapControls();
    EM:UnregisterForUpdate(NAME .. "Update");
    EM:RegisterForUpdate(NAME .. "Update", updateRate, Update);
    EM:UnregisterForEvent(NAME, EVENT_PLAYER_ACTIVATED);
  end);

  local function ActionBarActivated(eventCode, initial)
    if not initial then
      -- OnAllHotbarsUpdated()
      FancyActionBar.EffectCheck();
    end;
    FancyActionBar.OnPlayerActivated();
  end;

  EM:RegisterForEvent(NAME .. "_Activated", EVENT_PLAYER_ACTIVATED, ActionBarActivated);
  EM:RegisterForEvent(NAME, EVENT_EFFECT_CHANGED, OnEffectChanged);
  EM:AddFilterForEvent(NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER);

  FancyActionBar.SetExternalBuffTracking();

  EM:RegisterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnEquippedWeaponsChanged);
  EM:AddFilterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN);

  ZO_PreHookHandler(ACTION_BAR, "OnHide", function ()
    -- if ZO_ActionBar1:IsHidden() and not wasStopped then
    if not FancyActionBar.wasStopped then
      EM:UnregisterForUpdate(NAME .. "Update");
      FancyActionBar.wasStopped = true;
    end;
  end);

  ZO_PreHookHandler(ACTION_BAR, "OnShow", function ()
    if FancyActionBar.IsUnlocked() then return; end;

    FancyActionBar.ApplyPosition();

    if FancyActionBar.wasStopped then
      Update();
      EM:RegisterForUpdate(NAME .. "Update", updateRate, Update);
    end;
  end);

  ZO_PreHookHandler(CompanionUltimateButton, "OnShow", function ()
    if (not ZO_ActionBar_GetButton(ULT_SLOT, COMPANION).hasAction or not DoesUnitExist("companion") or not HasActiveCompanion()) then
      CompanionUltimateButton:SetHidden(true);
    end;
  end);

  class = GetUnitClassId("player");
  if FancyActionBar.fakeClassEffects[class] then
    for i, x in pairs(FancyActionBar.fakeClassEffects[class]) do fakes[i] = x; end;
  end;

  if FancyActionBar.specialClassEffects[class] then
    for i, x in pairs(FancyActionBar.specialClassEffects[class]) do FancyActionBar.specialEffects[i] = x; end;
  end;

  if FancyActionBar.specialClassEffectProcs[class] then
    for i, x in pairs(FancyActionBar.specialClassEffectProcs[class]) do FancyActionBar.specialEffectProcs[i] = x; end;
  end;

  for i, x in pairs(FancyActionBar.fakeSharedEffects) do fakes[i] = x; end;

  for id in pairs(fakes) do
    EM:RegisterForEvent(NAME .. id, EVENT_COMBAT_EVENT, OnCombatEvent);
    EM:AddFilterForEvent(NAME .. id, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER);
  end;

  for i in pairs(FancyActionBar.needCombatEvent) do
    EM:RegisterForEvent(NAME .. i, EVENT_COMBAT_EVENT, OnCombatEvent);
    EM:AddFilterForEvent(NAME .. i, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, i, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER);
  end;

  if FancyActionBar.graveLordSacrifice then
    EM:RegisterForEvent(NAME .. "GraveLordSacrifice", EVENT_COMBAT_EVENT, OnCombatEvent);
    EM:AddFilterForEvent(NAME .. "GraveLordSacrifice", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, FancyActionBar.graveLordSacrifice.eventId, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER_PET);
  end;

  for i, x in pairs(FancyActionBar.reflects) do
    EM:RegisterForEvent(NAME .. "Reflect" .. i, EVENT_COMBAT_EVENT, OnReflect);
    EM:AddFilterForEvent(NAME .. "Reflect" .. i, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, i);

    EM:RegisterForEvent(NAME .. "Reflect" .. x, EVENT_COMBAT_EVENT, OnReflect);
    EM:AddFilterForEvent(NAME .. "Reflect" .. x, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, x, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_FADED);
  end;

  -- ZO_PreHook('ZO_ActionBar_OnActionButtonDown', function(slotNum)
  --   Chat('ActionButton' .. slotNum .. ' pressed.')
  --   return false
  -- end)
end;

function FancyActionBar.OnAddOnLoaded(event, addonName)
  if addonName == NAME then
    EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED);
    FancyActionBar.Initialize();
  end;
end;

function FancyActionBar.ValidateVariables() -- all about safety checks these days..
  local d = defaultSettings;

  if SV.dynamicAbilityConfig == false then
    if SV.abilityConfig then
      SV.abilityConfig = nil;
    end;
    SV.dynamicAbilityConfig = true;
  end;

  if CV.dynamicAbilityConfig == false then
    if CV.abilityConfig then
      CV.abilityConfig = nil;
    end;
    CV.dynamicAbilityConfig = true;
  end;


  if SV.externalBlackListRun == false then
    SV.externalBlackList = { -- just add all resto staff skills by default and player can take it from there.
      [61504] = "Vigor";
      [28385] = "Grand Healing";
      [40130] = "Ward Ally";
      [29224] = "Igneous Shield";
      [76518] = "Major Brutality";
      [61665] = "Major Brutality";
      [61704] = "Minor Endurance";
      [61694] = "Major Resolve";
      [83850] = "Life Giver";
      [31531] = "Force Siphon";
      [85132] = "Lights Champion";
      [40109] = "Siphon Spirit";
      [61693] = "Minor Resolve";
      [61706] = "Minor Intellect";
      [37232] = "Steadfast Ward";
      [61697] = "Minor Fortitude";
      [61506] = "Echoing Vigor";
      [92503] = "Major Sorcery";
      [40116] = "Quick Siphon";
      [28536] = "Regeneration";
      [88758] = "Major Resolve";
      [61687] = "Major Sorcery";
      [38552] = "Panacea";
      [61721] = "Minor Protection";
      [40058] = "Illustrious Healing";
      [40076] = "Rapid Regeneration";
      [40060] = "Healing Springs";
      [186493] = "Minor Protection";
      [40126] = "Healing Ward";
      [176991] = "Minor Resolve";
    };

    SV.externalBlackListRun = true;
  end;

  -- if SV.debuffConfigUpgraded == false then
  --   local debuffs = {}
  --   for skill, id in pairs(FancyActionBar.abilityConfig) do
  --     c[skill] = id
  --   end
  -- end

  if SV.variablesValidated == false then
    if SV.abScaling == nil then SV.abScaling = d.abScaling; end;
    if SV.scaleEnable ~= nil then
      SV.abScaling.kb.enable = SV.scaleEnable;
      SV.abScaling.gp.enable = SV.scaleEnable;
      SV.scaleEnable = nil;
    end;

    if SV.abScale ~= nil then
      SV.abScaling.kb.scale = SV.abScale;
      SV.abScaling.gp.scale = SV.abScale;
      SV.abScale = nil;
    end;

    if (SV.showDecimal == nil or type(SV.showDecimal) ~= "string") then SV.showDecimal = d.showDecimal; end;

    if SV.alphaInactive == nil then SV.alphaInactive = d.alphaInactive; end;
    if SV.desaturationInactive == nil then SV.desaturationInactive = d.desaturationInactive; end;
    if SV.showDecimalStart == nil then SV.showDecimalStart = d.showDecimalStart; end;
    if SV.showExpire == nil then SV.showExpire = d.showExpire; end;
    if SV.showExpireStart == nil then SV.showExpireStart = d.showExpireStart; end;
    if SV.expireColor == nil then SV.expireColor = d.expireColor; end;

    if IsInGamepadPreferredMode() then
      if SV.fontName then
        SV.fontNameGP = SV.fontName;
        SV.fontName = nil;
      end;
      if SV.fontSize then
        SV.fontSizeGP = SV.fontSize;
        SV.fontSize = nil;
      end;
      if SV.fontType then
        SV.fontTypeGP = SV.fontType;
        SV.fontType = nil;
      end;
      if SV.timerY then
        SV.timerYGP = SV.timerY;
        SV.timerY = nil;
      end;
      if SV.timerYGP then
        local y;
        if SV.timerYGP == 0 then
          y = 0;
        elseif SV.timerYGP < 0 then
          y = SV.timerYGP + (SV.timerYGP * -2);
        elseif SV.timerYGP > 0 then
          y = SV.timerYGP - (SV.timerYGP + SV.timerYGP);
        end;
        SV.timeYGP = y;
        SV.timerYGP = nil;
      end;
      if SV.fontNameGP == nil then SV.fontNameGP = d.fontNameGP; end;
      if SV.fontSizeGP == nil then SV.fontSizeGP = d.fontSizeGP; end;
      if SV.fontTypeGP == nil then SV.fontTypeGP = d.fontTypeGP; end;
      if SV.timeYGP == nil then SV.timeYGP = d.timerYGP; end;

      if SV.abMove.gp.x == nil or SV.abMove.gp.x == 0 then SV.abMove.gp.x = ACTION_BAR:GetLeft(); end;
      if SV.abMove.gp.y == nil or SV.abMove.gp.y == 0 then SV.abMove.gp.y = ACTION_BAR:GetTop(); end;
    else
      if SV.fontName then
        SV.fontNameKB = SV.fontName;
        SV.fontName = nil;
      end;
      if SV.fontSize then
        SV.fontSizeKB = SV.fontSize;
        SV.fontSize = nil;
      end;
      if SV.fontType then
        SV.fontTypeKB = SV.fontType;
        SV.fontType = nil;
      end;
      if SV.timerY then
        SV.timerYKB = SV.timerY;
        SV.timerY = nil;
      end;
      if SV.timerYKB then
        local y;
        if SV.timerYKB == 0 then
          y = 0;
        elseif SV.timerYKB < 0 then
          y = SV.timerYKB + (SV.timerYKB * -2);
        elseif SV.timerYKB > 0 then
          y = SV.timerYKB - (SV.timerYKB + SV.timerYKB);
        end;
        SV.timeYKB = y;
        SV.timerYKB = nil;
      end;
      if SV.fontNameKB == nil then SV.fontNameKB = d.fontNameKB; end;
      if SV.fontTypeKB == nil then SV.fontTypeKB = d.fontTypeKB; end;
      if SV.fontSizeKB == nil then SV.fontSizeKB = d.fontSizeKB; end;
      if SV.timeYKB == nil then SV.timeYKB = d.timeYKB; end;

      if SV.abMove.kb.x == nil or SV.abMove.kb.x == 0 then SV.abMove.kb.x = ACTION_BAR:GetLeft(); end;
      if SV.abMove.kb.y == nil or SV.abMove.kb.y == 0 then SV.abMove.kb.y = ACTION_BAR:GetTop(); end;
    end;

    if SV.fontNameStackKB == nil then SV.fontNameStackKB = d.fontNameStackKB; end;
    if SV.fontSizeStackKB == nil then SV.fontSizeStackKB = d.fontSizeStackKB; end;
    if SV.fontTypeStackKB == nil then SV.fontTypeStackKB = d.fontTypeStackKB; end;
    if SV.stackXKB == nil then SV.stackX = d.stackXKB; end;
    if SV.fontNameStackGP == nil then SV.fontNameStackGP = d.fontNameStackGP; end;
    if SV.fontSizeStackGP == nil then SV.fontSizeStackGP = d.fontSizeStackGP; end;
    if SV.fontTypeStackGP == nil then SV.fontTypeStackGP = d.fontTypeStackGP; end;
    if SV.stackGP == nil then SV.stackXGP = d.stackXGP; end;
    if SV.showHotkeys == nil then SV.showHotkeys = d.showHotkeys; end;
    if SV.showHighlight == nil then SV.showHighlight = d.showHighlight; end;
    if SV.highlightColor == nil then SV.highlightColor = d.highlightColor; end;
    if SV.showArrow == nil then SV.showArrow = d.showArrow; end;
    if SV.arrowColor == nil then SV.arrowColor = d.arrowColor; end;
    if SV.moveQS == nil then SV.moveQS = d.moveQS; end;
    if SV.showFrames == nil then SV.showFrames = d.showFrames; end;
    if SV.frameColor == nil then SV.frameColor = d.frameColor; end;
    if SV.showMarker == nil then SV.showMarker = d.showMarker; end;
    if SV.markerSize == nil then SV.markerSize = d.markerSize; end;
    if SV.abScaleEnable == nil then SV.abScaleEnable = d.abScaleEnable; end;
    if SV.abScale == nil then SV.abScale = d.abScale; end;
    if SV.debug == nil then SV.debug = d.debug; end;
    if SV.showToggle == nil then SV.showToggle = d.showToggle; end;
    if SV.toggleColor == nil then SV.toggleColor = d.toggleColor; end;

    SV.variablesValidated = true;
  end;
end;

function FancyActionBar.SetPersonalSettings() -- cause I like my UI fancy...
  local s = GetControl("ZO_SynergyTopLevel"); -- add my button frame to the syngergy button pop-up and rearrange the layout.
  local c = s:GetNamedChild("Container");
  local a = c:GetNamedChild("Action");
  local k = c:GetNamedChild("Key");
  local i = c:GetNamedChild("Icon");
  local f = i:GetNamedChild("Frame");

  i:SetDimensions(50, 50);
  f:SetHidden(true);
  local e = CreateControl("$(parent)Edge", i, CT_TEXTURE);
  e:SetDimensions(50, 50);
  e:ClearAnchors();
  e:SetAnchor(TOPLEFT, i, TOPLEFT, 0, 0);
  e:SetTexture("/FancyActionBar+/texture/abilityFrame64_up.dds");
  e:SetColor(unpack(SV.frameColor));
  e:SetDrawLayer(2);
  k:ClearAnchors();
  k:SetScale(0.85);
  k:SetAnchor(BOTTOMLEFT, i, BOTTOMRIGHT, 5, 0);
  a:ClearAnchors();
  a:SetFont("$(BOLD_FONT)|$(KB_18)|outline");
  a:SetAnchor(BOTTOMLEFT, k, TOPLEFT, 5, 5);

  local sub = GetControl("ZO_Subtitles");
  local text = sub:GetNamedChild("Text");
  text:ClearAnchors();
  text:SetAnchor(TOP, sub, TOP, 0, 0);
  text:SetVerticalAlignment(TOP);

  local function HookDestroyConfirm() -- cause typing 'CONFIRM' is too exhausting...
    zo_callLater(function ()
      if ZO_Dialog1 and ZO_Dialog1.textParams and ZO_Dialog1.textParams.mainTextParams then
        for _, v in pairs(ZO_Dialog1.textParams.mainTextParams) do
          if v == string.upper(v) then
            ZO_Dialog1EditBox:SetText(v);
            ZO_Dialog1EditBox:LoseFocus();
          end;
        end;
      end;
    end, 10);
  end;
  ZO_PreHook(_G, "ZO_Dialogs_ShowDialog", HookDestroyConfirm);
end;

EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, FancyActionBar.OnAddOnLoaded);
