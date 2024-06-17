---@class (partial) FancyActionBar
local FancyActionBar = FancyActionBar;

---@param summonShade integer
---@return integer
local function GetSummonShade(summonShade)
  summonShade = 38517;
  local raceId = GetUnitRaceId("player");
  if raceId == 9 then
    summonShade = 88662; -- khajiit
  elseif raceId == 6 then
    summonShade = 88663; -- argonian
  end;
  return summonShade;
end;

local summonShade;

---@param shadowImage integer
---@return integer
local function GetShadowImage(shadowImage)
  shadowImage = 38528;
  local raceId = GetUnitRaceId("player");
  if raceId == 9 then
    shadowImage = 88696; -- khajiit
  elseif raceId == 6 then
    shadowImage = 88697; -- argonian
  end;
  return shadowImage;
end;

local shadowImage;

---@param darkShade integer
---@return integer
local function GetDarkShade(darkShade)
  darkShade = 35438;
  local raceId = GetUnitRaceId("player");
  if raceId == 9 then
    darkShade = 88677; -- khajiit
  elseif raceId == 6 then
    darkShade = 88678; -- argonian
  end;
  return darkShade;
end;

local darkShade;

FancyActionBar.abilityConfig = {
  --[[  [slot_id] = config:
    - { effect_id } = timer will start when the effect is fired
    - false = ignore this slot
    ]]

  -- Two Handed
  [38814] = { 131562 }; -- dizzying swing (off-balance)
  [38807] = { 61745 };  -- wrecking blow (major berserk)
  [38788] = { 38791 };  -- stampede
  [38745] = { 38747 };  -- carve bleed
  [28297] = {};         -- momentum
  [38794] = {};         -- forward momentum
  [38802] = { 38802 };  -- rally
  [83216] = { 83217 };  -- berserker strike
  [83229] = { 83230 };  -- onslaught
  [83238] = { 83239 };  -- berserker rage
  [217180] = { 38254 }; -- goading smash (Scribing?) (taunt)
  [219972] = { 38254 }; -- goading smash (scribing) (taunt)

  -- Shield
  [28306] = { 38254 };  -- puncture (taunt)
  [38250] = { 38254 };  -- pierce armor (taunt)
  [38256] = { 38254 };  -- ransack (taunt)
  [222966] = { 38254 }; -- goading throw (scribing) (taunt)
  [28304] = { 61723 };  -- low slash (minor maim)
  [38268] = { 61723 };  -- deep slash (minor maim)
  [38264] = { 61708 };  -- heroic slash (minor heroism)
  [28727] = {};         -- defensive posture
  [38312] = {};         -- defensive stance
  [38317] = {};         -- absorb missile
  [28719] = { 28720 };  -- shield charge (stun)
  [38401] = { 38404 };  -- shielded assault (shield)
  [38405] = { 38407 };  -- invasion (stun)
  [38452] = { 80625 };  -- power slam (resentment)
  [83272] = { 83272 };  -- shield wall
  [83292] = { 83292 };  -- spell wall
  [83310] = { 83310 };  -- shield discipline

  -- Dual Wield
  [28607] = { 99806 };  -- flurry (maelstrom buff)
  [38857] = { 99806 };  -- rapid strikes (maelstrom buff)
  [38846] = { 99806 };  -- bloodthirst (maelstrom buff)
  [28379] = { 29293 };  -- twin slashes
  [38839] = { 38841 };  -- rending slashes
  [38845] = { 38848 };  -- blood craze
  [28591] = { 100474 }; -- whirlwind (asylum buff)
  [38891] = { 100474 }; -- whirling blades (asylum buff)
  [38861] = { 100474 }; -- steel tornado (asylum buff)
  [28613] = { 28613 };  -- blade cloak
  [38901] = { 38901 };  -- quick cloak
  [38906] = { 38906 };  -- deadly cloak
  [21157] = { 61665 };  -- hidden blade (major brutality)
  [38914] = { 61665 };  -- shrouded daggers (major brutality)
  [38910] = { 126667 }; -- flying blade first cast
  [126659] = false;     -- flying blade jump (ignore major brutality)
  [83600] = { 85156 };  -- lacerate
  [85187] = { 85192 };  -- rend
  [85179] = { 85182 };  -- thrive in chaos

  -- Bow
  [38687] = false;      -- focused aim (minor fracture)
  [38685] = false;      -- lethal arrow
  [28876] = { 28876 };  -- volley
  [38689] = { 38689 };  -- endless hail
  [38695] = { 38695 };  -- arrow barrage
  [28879] = { 113627 }; -- scatter shot (BRP bow)
  [38672] = { 113627 }; -- magnum shot (BRP bow)
  [38669] = { 113627 }; -- draining shot (BRP bow)
  [38705] = { 38707 };  -- bombard (immobilized)
  [38701] = { 38703 };  -- acid spray
  [28869] = { 44540 };  -- poison arrow
  [38645] = { 44545 };  -- venom arrow
  [38660] = { 44549 };  -- poison injection
  [83465] = { 55131 };  -- rapid fire (cc immunity)
  [85257] = { 55131 };  -- toxic barrage (cc immunity)
  [85451] = { 85458 };  -- ballista
  [216674] = { 38254 }; -- goading valult (scribing) (taunt)

  -- Destruction Staff
  [46340] = { 100306 }; -- force shock (vAS destro)
  [46348] = { 100306 }; -- crushing shock (vAS destro)
  [46356] = { 100306 }; -- force pulse (vAS destro)

  [28807] = { 28807 };  -- wall of fire
  [28854] = { 28854 };  -- wall of shock
  [28849] = { 28849 };  -- wall of ice
  [39053] = { 39053 };  -- unstable wall of fire
  [39073] = { 39073 };  -- unstable wall of storms
  [39067] = { 39067 };  -- unstable wall of frost
  [39012] = { 39012 };  -- blockade of fire
  [39018] = { 39018 };  -- blockade of shock
  [39028] = { 39028 };  -- blockade of ice
  [29073] = { 62648 };  -- flame touch
  [29089] = { 62722 };  -- shock touch
  [29078] = { 62692 };  -- frost touch
  [38985] = { 140334 }; -- flame clench (master destro)
  [38993] = { 140334 }; -- shock clench (master destro)
  [38989] = { 38254 };  -- frost clench (taunt)
  [38944] = { 62682 };  -- flame reach
  [38978] = { 62745 };  -- shock reach
  [38970] = { 62712 };  -- frost reach
  [29173] = { 61743 };  -- weaknees to elements
  [39089] = { 39089 };  -- elemental susceptibility
  [39095] = { 61743 };  -- elemental drain (minor magickasteal)
  [28794] = { 115003 }; -- fire impulse (BRP destro)
  [28799] = { 115003 }; -- shock impulse (BRP destro)
  [28798] = { 115003 }; -- frost impulse (BRP destro)
  [39145] = { 115003 }; -- fire ring (BRP destro)
  [39147] = { 115003 }; -- shock ring (BRP destro)
  [39146] = { 115003 }; -- frost ring (BRP destro)
  [39162] = { 115003 }; -- flame pulsar (BRP destro)
  [39167] = { 115003 }; -- shock pulsar (BRP destro)
  [39163] = { 115003 }; -- frost pulsar (BRP destro)
  [83625] = { 83625 };  -- fire storm
  [83630] = { 83630 };  -- thunder storm
  [83628] = { 83628 };  -- icy storm
  [83682] = { 83682 };  -- fiery eye of the storm
  [83686] = { 83686 };  -- shock
  [83684] = { 83684 };  -- ice
  [85126] = { 85126 };  -- fiery rage
  [85130] = { 85130 };  -- thunderous rage
  [85128] = { 85128 };  -- icy rage

  -- Restoration Staff
  [28385] = { 28385 }; -- grand healing
  [40058] = { 40058 }; -- illustrious healing
  [40060] = { 40060 }; -- healing springs
  [28536] = { 28536 }; -- regeneration
  [40076] = { 40076 }; -- rapid regeneration
  [40079] = { 40079 }; -- radiating regneration
  [37243] = { 61693 }; -- blessing of protection (minor resolve)
  [40094] = { 61744 }; -- combat prayer (minor berserk)
  [40103] = { 61693 }; -- blessing of restoration (minor resolve)
  [37232] = { 37232 }; -- steadfast ward
  [40126] = { 40126 }; -- healing ward
  [40130] = { 40130 }; -- ward ally
  [31531] = { 86304 }; -- force siphon
  [40109] = { 86304 }; -- siphon spirit
  [40116] = { 86304 }; -- quick siphon
  [83552] = { 83552 }; -- panacea
  [83850] = { 83850 }; -- life giver
  [85132] = { 85132 }; -- light's champion (5s HoT) / 61747: major force gained from heal

  -- Armor
  [29338] = { 29338 }; -- annulment
  [39186] = { 39186 }; -- dampen magic
  [39182] = { 39182 }; -- harness magicka
  [29556] = { 61716 }; -- evasion
  [39195] = { 61716 }; -- shuffle
  [39192] = { 61716 }; -- elude
  [29552] = { 61694 }; -- unstoppable (major resolve)
  [39205] = { 61694 }; -- unstoppable brute (major resolve)
  [39197] = { 61694 }; -- immovable (major resolve)

  -- Werewolf
  [32632] = { 137156 };  -- punce (carnage bleed)
  [137156] = { 137156 }; -- carnage (bleed)
  [39105] = { 137184 };  -- brutal pounce (brutal carnage bleed)
  [137184] = { 137184 }; -- brutal carnage (bleed)
  [39104] = { 137164 };  -- feral pounce (brutal carnage bleed)
  [137164] = { 137164 }; -- feral carnage (bleed)
  [58317] = { 61745 };   -- hircine's rage (major berserk)
  [58325] = { 61704 };   -- hircine's fortitude (minor fortitude)
  [32633] = { 137257 };  -- roar (off-balance)
  [39113] = { 45834 };   -- ferocious roar (off-balance); 137287 is heavy attack speed buff
  [39114] = { 61743 };   -- deafening roar major breach; 137312 is off-balance
  [58855] = { 58856 };   -- infectious claws
  [58864] = { 58865 };   -- claws of anguish
  [58879] = { 58880 };   -- claws of life
  [32455] = { 32455 };   -- werewolf transformation
  [39075] = { 32455 };   -- pack leader
  [39076] = { 32455 };   -- werewolf berserker

  -- Vampire
  [32986] = { 106208 };  -- mist form
  [38963] = { 106209 };  -- elusive mist
  [38965] = { 49268 };   -- blood mist
  [132141] = { 172418 }; -- blood frenzy
  [134160] = { 134166 }; -- simmering frenzy
  [135841] = { 172648 }; -- sated fury
  [32624] = { 32624 };   -- blood scion
  [38932] = { 38932 };   -- swarming scion
  [38938] = { 38938 };   -- perfect scion

  -- Soul Magic
  [26768] = { 126890 }; -- soul trap
  [40328] = { 126895 }; -- soul splitting trap
  [40317] = { 126898 }; -- consuming trap

  -- Fighters Guild
  [40336] = { 40340 };  -- silver leash
  [35737] = { 35737 };  -- circle of protection
  [40181] = { 40181 };  -- turn evil
  [40169] = { 40169 };  -- ring of preservation
  [35750] = {};         -- trap beast dot
  [40372] = {};         -- lightweight beast trap
  [40382] = {};         -- barbed trap dot
  [40194] = { 40194 };  -- evil hunter
  [40195] = { 61744 };  -- camouflaged hunter (minor berserk)
  [35713] = { 62305 };  -- dawnbreaker
  [40158] = { 62314 };  -- dawnbreaker of smiting
  [40161] = { 126312 }; -- flawless dawnbreaker

  -- Mages Guild
  [28567] = { 126370 }; -- entropy
  [40452] = { 126371 }; -- structured entropy
  [40457] = { 126374 }; -- degeneration
  [31632] = {};         -- fire rune
  [40470] = {};         -- volcanic rune
  [40465] = {};         -- {  40468 }; -- scalding rune (dot)
  [31642] = { 48131 };  -- equilibrium (healing debuff)
  [40445] = { 48136 };  -- spell symmetry (healing debuff)
  [40441] = { 61694 };  -- balance (major resolve)
  [16536] = {};         -- meteor
  [40489] = {};         -- ice comet
  [40493] = {};         -- shooting star

  -- Psijic Order
  [103488] = { 104050 }; -- time stop
  [104059] = { 104078 }; -- borrowed time
  [104079] = { 104079 }; -- time freeze
  [103483] = { 103879 }; -- imbue weapon
  [103571] = { 103879 }; -- elemental weapon
  [103623] = { 103879 }; -- crushing weapon
  [103503] = { 61746 };  -- accelerate (minor force)
  [103706] = { 61746 };  -- channeled acceleration
  [103710] = { 61746 };  -- race against time
  [103543] = { 103543 }; -- mend wounds
  [103747] = { 103747 }; -- mend spirit
  [103755] = { 103755 }; -- symbiosis
  [103492] = { 103492 }; -- meditate
  [103652] = { 103652 }; -- deep thoughts
  [103665] = { 103665 }; -- introspection

  -- Undaunted
  [39489] = { 39489 }; -- blood altar
  [41967] = { 41967 }; -- sanguine altar
  [41958] = { 41958 }; -- overflowing altar
  [39425] = { 39425 }; -- trapping webs
  [41990] = { 41990 }; -- shadow silk
  [42012] = { 42012 }; -- tangling webs
  [39475] = { 38254 }; -- inner fire (taunt)
  [42056] = { 38254 }; -- inner rage (taunt)
  [42060] = { 42062 }; -- inner beast
  [39369] = { 39369 }; -- bone shield
  [42138] = { 42138 }; -- spiked bone shield
  [42176] = { 42176 }; -- bone surge
  [39298] = { 39298 }; -- necrotic orb
  [42028] = { 42028 }; -- mystic orb
  [42038] = { 42038 }; -- energy orb

  -- Alliance War
  -- Assault
  [61503] = { 61504 }; -- vigor
  [61505] = { 61506 }; -- echoing vigor
  [61507] = { 61693 }; -- resolving vigor
  [38566] = { 61736 }; -- rapid maneuver
  [40211] = { 61736 }; -- retreating maneuver
  [40215] = { 61736 }; -- charging maneuver
  [33376] = { 38549 }; -- caltrops
  [40242] = { 40251 }; -- razor caltrops
  [40255] = { 40265 }; -- anti-cavalry caltrops
  [61487] = { 61487 }; -- magicka detonation
  [61491] = { 61491 }; -- inevitable detonation
  [61500] = { 61500 }; -- proximity detonation
  [38563] = { 38564 }; -- war horn
  [40220] = { 40221 }; -- sturdy war horn
  [40223] = { 40224 }; -- aggressive warhorn (30 sec); 61747: 10 sec major force
  -- Support
  [38570] = { 38570 }; -- siege shield
  [40226] = { 40226 }; -- propelling shield
  [40229] = { 40229 }; -- siege weapon shield
  [61511] = {};        -- guard  -- [80923] = { 61511 }; -- guard
  [61529] = {};        -- stalwart guard  -- [80983] = { 81420 }; -- stalwart guard gain
  [61536] = {};        -- mystic guard -- [80947] = { 61536 }; -- mystic guard
  [81420] = { 61529 }; -- guard slot id while link is acitve
  [61489] = { 61498 }; -- revealing flare
  [61519] = { 61522 }; -- lingering flare
  [61524] = { 61526 }; -- blinding flare
  [38573] = { 38573 }; -- barrier
  [40237] = { 40237 }; -- reviving barrier (40238: 15s HoT)
  [40239] = { 40239 }; -- replenishing barrier

  -- Dragonknight
  [20805] = { 122658 }; -- show seething fury on the molten whip icon
  [20657] = { 44363 };  -- searing strike
  [20668] = { 44369 };  -- venomous claw
  [20660] = { 44373 };  -- burning embers
  [20917] = { 31102 };  -- fiery breath
  [20930] = { 31104 };  -- engulfing flames
  [20944] = { 31103 };  -- noxious breath
  [20492] = { 61736 };  -- fiery grip (major expedition)
  [20496] = { 61736 };  -- unrelenting grip (major expedition)
  [20499] = { 61737 };  -- empowering chains (empower)
  [28967] = { 28967 };  -- inferno
  [32853] = { 32853 };  -- flames of oblivion
  [32881] = { 32881 };  -- cauterize
  [28988] = { 28988 };  -- dragonknight standard
  [32958] = { 32958 };  -- shifting standard
  [32947] = { 32947 };  -- standard of might
  [20319] = { 20319 };  -- spiked armor
  [20328] = { 20328 };  -- hardened armor
  [20323] = { 20323 };  -- volatile armor
  [20245] = { 20527 };  -- dark talons
  [20251] = { 61723 };  -- choking talons (minor maim)
  [20252] = { 31898 };  -- burning talons
  [29004] = { 61698 };  -- dragon blood (major fortitude)
  [32722] = { 61698 };  -- coagulating blood (major fortitude)
  [32744] = { 61549 };  -- green dragon blood (minor vitality)
  [21007] = { 21007 };  -- protective scale
  [21014] = { 21014 };  -- protective plate
  [21017] = { 21017 };  -- dragon fire scale
  [31837] = { 31841 };  -- inhale
  [32785] = { 32788 };  -- draw essence
  [32792] = { 32796 };  -- deep breath
  [32715] = { 61814 };  -- ferocious leap
  -- [31816] = false; -- ignore stone giant
  [29032] = { 29032 };  -- { 133027 }; -- track stagger
  [31816] = { 31816 };  -- { 133027 }; -- track stagger
  [133027] = { 31816 }; -- track stone giant
  -- [29032] = false; -- don't track stonefist
  -- [31816] = { 134336 }; -- track stagger instead
  -- [133027] = { 134336 }; -- track stagger
  [29071] = { 29071 }; -- obsidian shield
  [29224] = { 29224 }; -- igneous shield
  [32673] = { 61711 }; -- fragmented shield
  [29043] = { 61665 }; -- molten weapons
  [31874] = { 61665 }; -- igneous weapons
  [31888] = { 61665 }; -- molten armaments
  [29037] = {};        -- petrify
  [32678] = {};        -- shattering rocks
  [32685] = {};        -- fossilize
  [29059] = { 29059 }; -- ash cloud
  [20779] = { 20779 }; -- cinder storm
  [32710] = { 32710 }; -- eruption
  [15957] = { 15957 }; -- magma armor
  [17874] = { 17874 }; -- magma shell
  [17878] = { 17878 }; -- corrosive armor

  -- Sorcerer
  [43714] = false;       -- crystal shard
  [46324] = { 46327 };   -- crystal fragment proc
  [114716] = { 46327 };  -- crystal fragment proc
  [46331] = {};          -- crystal weapon
  [28025] = { 28025 };   -- encase
  [28308] = { 28308 };   -- shattering prison
  [28311] = { 28311 };   -- restraining prison
  [24371] = { 24559 };   -- rune prison
  [24578] = { 24581 };   -- shattering prison
  [24574] = { 24574 };   -- defensive rune
  [24584] = { 114903 };  -- Dark Exchange
  [24589] = { 114909 };  -- dark conversion
  [24595] = { 114908 };  -- dark deal
  [24842] = { 24844 };   -- daedric tomb (first mine) 24846; 24847
  [27706] = { 27706 };   -- Negate Magic
  [28341] = { 28341 };   -- Suppression Field
  [28348] = { 28348 };   -- Absorption Field
  [77182] = { 77187 };   -- volatile pulse
  [23316] = { 77187 };   -- summon volatile familiar
  [77140] = { 77354 };   -- twilight tormentor enrage
  [24636] = { 77354 };   -- summon twilight tormentor
  [108840] = { 108842 }; -- summon unstable familiar
  [23304] = { 108844 };  -- unstable pulse
  [24326] = { 24326 };   -- Daedric Curse
  [24330] = {};          -- haunting curse - 89491 is second proc
  [24328] = { 24328 };   -- Daedric Prey
  [28418] = { 28418 };   -- Conjured Ward
  [29489] = { 29489 };   -- Hardened Ward
  [29482] = { 29482 };   -- Empowered Ward
  [24158] = { 24158 };   -- Bound Armor
  [24165] = { 24165 };   -- bound armaments
  [130291] = { 24165 };  --  false  ; -- track Bound Armaments duration instead of its proc
  [24163] = { 24163 };   -- Bound Aegis
  [23634] = { 80459 };   -- Summon Storm Atronach
  [23492] = { 80463 };   -- greater storm atronarch
  [23495] = { 23668 };   -- Summon Charged Atronach
  [18718] = false;       -- mages' fury
  [19109] = false;       -- endless fury
  [19123] = false;       -- mages' wrath
  [23210] = { 23210 };   -- Lightning Form
  [23213] = { 23213 };   -- Boundless Storm
  [23231] = { 23231 };   -- hurricane
  [23182] = { 157462 };  -- lightning splash
  [23205] = { 157537 };  -- lightning flood
  [23200] = { 157535 };  -- liquid lightning
  [23670] = { 23670 };   -- Surge
  [23678] = { 23678 };   -- Critical Surge
  [23674] = { 23674 };   -- Power Surge
  [23234] = { 51392 };   -- bolt escape fatigue
  [23236] = { 51392 };   -- streak fatigue
  [23277] = { 51392 };   -- ball of lightning fatigue
  [24785] = { 24785 };   -- overload
  [24806] = { 24806 };   -- power overlaod
  [24804] = { 24804 };   -- energy overload

  -- Templar
  [26188] = { 95933 }; -- spear shards
  [26858] = { 95957 }; -- luminous shards
  [26869] = { 26880 }; -- blazing spear
  [22178] = { 22179 }; -- sun shield
  [22180] = { 49091 }; -- blazing shield
  [22182] = { 22183 }; -- radiant ward
  [22138] = { 62593 }; -- radial sweep
  [22139] = { 62607 }; -- crescent sweep
  [22144] = { 62599 }; -- empowering sweep
  [21726] = { 21728 }; -- sun fire
  [21732] = { 21734 }; -- reflective light
  [21729] = { 21731 }; -- vampire's bane
  [22057] = { 61737 }; -- solar flare (empower)
  [22110] = { 61737 }; -- dark flare (empower)
  [22095] = { 22095 }; -- solar barrage
  [21761] = { 21761 }; -- backlash
  [21765] = { 21765 }; -- purifying light
  [21763] = { 21763 }; -- PotL / 61742 (minor breach)
  [21776] = { 21776 }; -- eclipse
  [22006] = { 22006 }; -- living dark
  [22004] = { 22004 }; -- unstable core
  [63029] = false;     -- radiant destruction
  [63044] = false;     -- radiant glory
  [63046] = false;     -- radiant oppression
  [21752] = { 21576 }; -- nova
  [21755] = { 22003 }; -- solar prison
  [21758] = { 22001 }; -- solar disturbance
  [22253] = { 35632 }; -- honor the dead
  [22314] = { 61735 }; -- hasty prayer (minor expedition)
  [26209] = { 61704 }; -- radiant aura minor endurance
  [26807] = { 61704 }; -- radiant aura minor endurance
  [22265] = {};        -- cleansing ritual
  [22259] = {};        -- ritual of retribution
  [22262] = {};        -- extended ritual
  [22234] = { 22234 }; -- rune focus
  [22240] = { 22240 }; -- channeled focus
  [22237] = { 22237 }; -- restoring focus
  [22223] = { 22223 }; -- rite of passage
  [22226] = { 22226 }; -- practiced incantation
  [22229] = { 22229 }; -- remembrance

  -- Warden
  [85995] = { 130129 }; -- dive (off-balance)
  [85999] = { 130140 }; -- cutting dive (bleed)
  [86003] = { 178330 }; -- screaming cliff racer (off-balance wd)
  [86009] = {};         -- scorch
  [86015] = {};         -- deep fissure
  [86019] = {};         -- subterranean assault
  [86023] = { 101703 }; -- swarm
  [86027] = { 101904 }; -- fetcher infection
  [86031] = { 101944 }; -- growing swarm
  [86050] = { 86050 };  -- betty netch
  [86054] = { 86054 };  -- blue betty
  [86058] = { 86058 };  -- bull netch
  [86037] = { 177288 }; -- falcon's swiftness
  [86041] = { 177289 }; -- deceptive predator
  [86045] = { 177290 }; -- bird of prey
  [85862] = { 61704 };  -- enchanted growth (minor endurance)
  [85578] = { 85578 };  -- healing seed
  [85840] = { 85840 };  -- budding seeds
  [85845] = { 85845 };  -- corrupting pollen
  [85552] = { 85552 };  -- living vines
  [85850] = { 85850 };  -- leeching vines
  [85851] = { 85851 };  -- living trellis
  [85539] = { 85539 };  -- lotus flower
  [85854] = { 85854 };  -- green lotus
  [85855] = { 85855 };  -- lotus blossom
  [85564] = { 90266 };  -- nature's grasp healing
  [85858] = { 88726 };  -- nature's embrace healing
  [85532] = { 85532 };  -- secluded grove
  [85804] = { 85804 };  -- enchanted forest
  [85807] = { 85807 };  -- healing thicket
  [86122] = { 61694 };  -- frost cloak
  [86126] = { 61694 };  -- expansive frost cloak
  [86130] = { 61694 };  -- ice fortress
  [86161] = { 86161 };  -- impaling shards
  [86165] = { 86165 };  -- gripping shards
  [86169] = { 86169 };  -- winter's revenge
  [86148] = { 90833 };  -- arctic wind
  [86156] = { 90834 };  -- arctic blast
  [86152] = { 90835 };  -- polar wind
  [86135] = {};         -- crystallized shield
  [86139] = {};         -- crystallized slab
  [86143] = {};         -- shimmering shield
  [86175] = {};         -- frozen gate
  [86179] = {};         -- frozen device
  [86183] = {};         -- frozen retreat
  [86109] = { 86109 };  -- sleet storm
  [86113] = { 132429 }; -- northern storm
  [86117] = { 86117 };  -- permafrost

  -- Nightblade
  [33386] = false;                           -- assassin's blade
  [34843] = false;                           -- killer's blade
  [34851] = false;                           -- impale
  [25484] = { 79717 };                       -- ambush (minor vulnerability)
  [18342] = { 79717 };                       -- teleport strike (minor vulnerability)
  [25493] = { 79717 };                       -- lotus fan (minor vulnerability)
  [33375] = { 61716 };                       -- blur (major evasion)
  [35414] = { 61716 };                       -- mirage (major evasion)
  [35419] = { 61716 };                       -- phantasmal escape (125314 = 2.5 sec snare immune)
  [33357] = { 33357 };                       -- mark target
  [36967] = { 36967 };                       -- reapers mark
  [36968] = { 36968 };                       -- piercing mark
  [61902] = {};                              -- grim focus (ingame timer is bugged)
  [61907] = { 61902 };                       --  false  ; -- grim focus proc
  [61919] = {};                              -- merciless resolve (ingame timer is bugged)
  [61930] = { 61919 };                       -- false  ; -- merciless resolve proc
  [61927] = {};                              -- relentless focus (ingame timer is bugged)
  [61932] = { 61927 };                       -- false  ; -- relentless focus proc
  [33398] = { 61389 };                       -- death stroke
  [36508] = { 61393 };                       -- incap (70 ult)
  [113105] = { 113107 };                     -- incap (120 ult)
  [36514] = { 61400 };                       -- soul harvest
  [25255] = { 25256 };                       -- veiled strike (off-balance)
  [25267] = { 34739 };                       -- concealed weapon
  [25260] = { 34733 };                       -- surprise attack (off-balance)
  [25375] = { 25376 };                       -- shadow cloak
  [25377] = { 25377 };                       -- dark cloak
  [25380] = { 25381 };                       -- shadowy disguise
  [33195] = { 33195 };                       -- path of darkness
  [36028] = { 36028 };                       -- refreshing path
  [36049] = { 36049 };                       -- twisting path
  [25352] = { 147643 };                      -- aspect of terror
  [37470] = { 147643 };                      -- mass hysteria
  [37475] = {};                              -- manifestation of terror
  [33211] = { GetSummonShade(summonShade) }; -- summon shade
  [35434] = { GetDarkShade(darkShade) };     -- dark shade
  [35441] = { GetShadowImage(shadowImage) }; -- shadow image
  [35445] = false;                           -- shadow image proc
  [25411] = { 25411 };                       -- consuming darkness
  [36485] = { 36485 };                       -- veil of blades
  [36493] = { 36493 };                       -- bolstering darkness
  [33291] = { 33292 };                       -- strife heal
  [34838] = { 34841 };                       -- funnel health heal
  [34835] = { 34836 };                       -- swallow soul heal
  [33308] = { 108925 };                      -- melevolent offering
  [34721] = { 108927 };                      -- shrewd offering
  [34727] = { 108932 };                      -- healthy offering
  [33326] = { 33333 };                       -- cripple
  [36943] = { 36947 };                       -- debilitate
  [36957] = { 36960 };                       -- crippling grasp
  [33319] = { 33319 };                       -- siphoning strikes
  [36908] = { 36908 };                       -- leeching strikes
  [36935] = { 36935 };                       -- siphoning attacks
  [33316] = { 61665 };                       -- drain power
  [36901] = { 61665 };                       -- power extraction
  [36891] = { 61665 };                       -- sap essence
  [25091] = { 25093 };                       -- soul shred
  [35508] = { 35508 };                       -- soul siphon
  [35460] = { 35462 };                       -- soul tether

  -- Necromancer
  [117637] = { 117638 }; -- ricochet skull: base (0 stacks)
  [123718] = { 117638 }; -- 1 stack
  [123719] = { 117638 }; -- 2 stacks
  [117624] = { 117625 }; -- venom skull: base (0 stacks)
  [123699] = { 117625 }; -- 1 stack
  [123704] = { 117625 }; -- 2 stacks
  [114860] = { 114863 }; -- blastbones
  [117330] = { 114863 }; -- blastbones
  [117690] = { 117691 }; -- blighted blastbones
  [117693] = { 117691 }; -- blighted blastbones
  [117749] = {};         -- grave lord's sacrifice
  [115252] = { 115252 }; -- boneyard
  [117805] = { 117805 }; -- unnerving boneyard
  [117850] = { 117850 }; -- avid boneyard
  [118726] = { 118726 }; -- skeletal mage
  [118680] = { 118680 }; -- skeletal archer
  [118736] = { 118736 }; -- skeletal arcanist
  [115924] = { 116445 }; -- shocking siphon
  [118763] = { 118764 }; -- detonating siphon
  [118008] = { 118009 }; -- mystic siphon
  [122174] = { 106754 }; -- frozen colossus (major vuln)
  [122388] = { 106754 }; -- glacial colossus (major vuln)
  [122391] = { 106754 }; -- pestilent colossus (major vuln)
  [118223] = { 122625 }; -- hungry scythe (healing over time)
  [118226] = { 125750 }; -- ruinous scythe (off-balance)
  [115206] = { 115206 }; -- bone armor
  [118237] = { 118237 }; -- beckoning armor
  [118224] = { 118224 }; -- summoners armor
  [115240] = { 115240 }; -- bitter harvest
  [124165] = { 124165 }; -- deaden pain
  [124193] = { 124193 }; -- necrotic potency
  [115093] = { 115093 }; -- bone totem
  [118380] = { 118380 }; -- remote totem
  [118404] = { 118404 }; -- agony totem
  [115177] = { 61723 };  -- grave grasp (minor maim)
  [118308] = { 61723 };  -- ghostly embrace (minor maim)
  [118352] = { 61737 };  -- empowering grasp (empower)
  [115001] = { 115001 }; -- bone goliath transformation
  [118664] = { 118664 }; -- pummeling clown
  [118279] = { 118279 }; -- ravenous clown
  [114196] = { 61726 };  -- render flesh (minor defile)
  [117883] = { 117886 }; -- resistant flesh
  [117888] = false;      -- blood sacrifice
  [115307] = false;      -- expunge
  [117940] = false;      -- expunge and modify
  [117919] = false;      -- hexproof
  [115315] = { 115326 }; -- life amid death
  [118017] = { 118022 }; -- renewing undeath
  [118809] = { 118814 }; -- enduring undeath
  [115710] = { 115710 }; -- spirit mender
  [118840] = { 118840 }; -- intensive mender
  [118912] = { 118912 }; -- spirit guardian
  [115926] = { 116450 }; -- restoring tether
  [118070] = { 118071 }; -- braided teher
  [118122] = { 118123 }; -- mortal coil
  [115410] = false;      -- reanimate
  [118367] = false;      -- renewing animation
  [118379] = false;      -- animate blastbones

  -- Arcanist
  [185794] = { 184220 }; -- runeblades
  [188658] = { 184220 }; -- runeblades
  [185803] = { 184220 }; -- writhing runeblades
  [188787] = { 184220 }; -- writhing runeblades
  [182977] = { 184220 }; -- escalating runeblades
  [188780] = { 184220 }; -- escalating runeblades
  [185805] = { 184220 }; -- fatecarver
  [193331] = { 184220 }; -- fatecarver
  [183122] = { 184220 }; -- exhausting fatecarver
  [193397] = { 184220 }; -- exhausting fatecarver
  [186366] = { 184220 }; -- pragmatic fatecarver
  [193398] = { 184220 }; -- pragmatic fatecarver
  [185817] = { 185818 }; -- abyssal impact
  [183006] = { 183008 }; -- cephaliarch's flail
  [185823] = { 185825 }; -- tentacular dread
  [186452] = { 186452 }; -- tome-bearer's inspiration
  [185842] = { 185842 }; -- inspired scholarship
  [183047] = { 183047 }; -- recuperative treatise
  [185836] = { 185838 }; -- the imperfect ring
  [185839] = { 185840 }; -- rune of displacement
  [182988] = { 182989 }; -- fulminating rune
  [189791] = { 189792 }; -- the unblinking eye
  [189837] = { 191367 }; -- the tide king's gaze
  [189867] = { 189868 }; -- the languid eye
  [183165] = { 38254 };  -- runic jolt (taunt)
  [183430] = { 187742 }; -- runic sunder (armor steal)
  [186531] = { 38254 };  -- runic embrace (taunt)
  [185894] = { 185894 }; -- runespite ward
  [185901] = { 185901 }; -- spiteward of the lucid mind
  [183241] = { 184362 }; -- impervious runeward
  [183648] = { 183648 }; -- fatewoven armor
  [185908] = { 185908 }; -- cruxweaver armor
  [186477] = { 186477 }; -- unbreakable fate
  [185912] = { 194637 }; -- runic defense
  [183401] = { 194646 }; -- runeguard of still waters
  [186489] = { 61721 };  -- runeguard of freedom
  [185918] = { 79717 };  -- rune of eldritch horror
  [185921] = { 79717 };  -- rune of uncanny adoration
  [183267] = { 145975 }; -- rune of the colorless pool
  [183676] = { 183676 }; -- gibbering shield
  [192372] = { 192372 }; -- sancum of the abyssal sea
  [192380] = { 192380 }; -- gibbering shelter
  [183261] = { 184220 }; -- runemend
  [198282] = { 184220 }; -- runemend
  [186189] = { 184220 }; -- evolving runemend
  [198288] = { 184220 }; -- evolving runemend
  [186191] = { 184220 }; -- audacious runemend
  [198292] = { 184220 }; -- audacious runemend
  [183537] = { 184220 }; -- remedy cascade
  [198309] = { 184220 }; -- remedy cascade
  [186193] = { 184220 }; -- cascading fortune
  [198330] = { 184220 }; -- cascading fortune
  [186200] = { 184220 }; -- curative surge
  [198537] = { 184220 }; -- curative surge
  [183447] = { 184220 }; -- chakram shields
  [198563] = { 184220 }; -- chakram shields
  [186207] = { 184220 }; -- chakram of destiny
  [198564] = { 184220 }; -- chakram of destiny
  [186209] = { 184220 }; -- tidal chakram
  [198567] = { 184220 }; -- tidal chakram
  [183555] = { 183555 }; -- arcanist's domain
  [186229] = { 186229 }; -- zenas empowering disc
  [186234] = { 186234 }; -- reconstructive domain
  [183542] = { 195167 }; -- apocryphal gate
  [186211] = { 195190 }; -- fleet-footed gate
  [186220] = { 195204 }; -- passage between worlds
  [183709] = { 183712 }; -- vitalizing glyphic
  [193794] = { 193797 }; -- glyphic of the tides
  [193558] = { 193559 }; -- resonating glyphic
};

FancyActionBar.stackMap = {
  -- [stackId] = {stackId, abilityId_1, abilityId_2, ...}

  [38747] = { 38747 }; -- Carve (2H)
  [38802] = { 38802 }; -- rally

  -- Spell Orb
  [103879] = {
    103879; -- spell orb
    103483; -- imbue weapon
    103571; -- elemental weapon
    103623; -- crushing weapon
    103503; -- accelerate
    103706; -- channeled acceleration
    103710; -- race against time
  };

  [106208] = { 106208 }; -- mist form fatigue
  [106209] = { 106209 }; -- elusive mist fatigue
  [49247] = { 49247 };   -- blood mist fatigue
  [172418] = { 172418 }; -- blood frenzy stacks
  [134166] = { 134166 }; -- simmering frenzy stacks
  [172648] = { 172648 }; -- sated fury stacks

  [100306] = { 100306 }; -- force pulse (vAS destro)
  [100474] = { 100474 }; -- chaotic whirlwind (vAS dw)

  [122585] = { 61902 };  -- Grim Focus
  [122586] = { 61919 };  -- Merciless Resolve
  [122587] = { 61927 };  -- Relentless Focus

  [203447] = { 24165 };  -- Bound Armaments

  [51392] = { 51392 };   -- Streak Fatigue

  [29032] = { 29032 };   -- Stone Fist (stacks on self)
  [31816] = { 31816 };   -- Stone Giant (stacks on self)
  -- [134336] = 134336;  -- Stone Giant (stacks on target)
  [122658] = { 122658 }; -- Seething Fury

  [117638] = { 117638 }; -- Ricochet Skull
  [117625] = { 117625 }; -- venom skull
  [125749] = { 125750 }; -- ruinous scythe

  [184220] = { 184220 }; -- crux

  -- Taunt Counter
  [52790] = {
    52790;  -- taunt counter
    38254;  -- taunt
    39475;  -- inner fire
    42056;  -- inner rage
    42062;  -- inner beast
    38989;  -- frost clench
    28306;  -- puncture (taunt)
    38250;  -- pierce armor (taunt)
    38256;  -- ransack (taunt)
    183165; -- runic jolt
    183430; -- runic sunder
    186531; -- runic embrace
    222966; -- goading throw (scribing) (taunt)
    216674; -- goading valult (scribing) (taunt)
    217180; -- goading smash (Scribing?) (taunt)
    219972; -- goading smash (scribing) (taunt)
  };

  -- -- Haunting Curse
  -- [24330] = {
  --   24330; -- first proc, haunting curse
  --   89491; -- second proc, haunting curse
  -- }
};

-- Abilities here also have to be present in stackMap
-- FancyActionBar.fixedStacks = {
--   -- stackSourceId = targetId
--   -- [52790] = {52790, false}; -- taunt counter, taunt
--   [24330] = 2; -- first proc, haunting curse
--   [89491] = 1; -- second proc, haunting curse
-- }

FancyActionBar.debuffIds = {
  -- Two Handed
  [38814] = { 131562 }; -- dizzying swing (off-balance)
  [38745] = { 38747 };  -- carve bleed
  [83216] = { 83217 };  -- berserker strike
  [83229] = { 83230 };  -- onslaught
  [83238] = { 83239 };  -- berserker rage
  [83223] = { 83224 };  -- reverse slash
  [217180] = { 38254 }; -- goading smash (Scribing?) (taunt)
  [219972] = { 38254 }; -- goading smash (scribing) (taunt)

  -- Shield
  [28306] = { 38254 };  -- puncture (taunt)
  [38250] = { 38254 };  -- pierce armor (taunt)
  [38256] = { 38254 };  -- ransack (taunt)
  [222966] = { 38254 }; -- goading throw (scribing) (taunt)
  [28304] = { 61723 };  -- low slash (minor maim)
  [38268] = { 61723 };  -- deep slash (minor maim)
  [28719] = { 28720 };  -- shield charge (stun)
  [38405] = { 38407 };  -- invasion (stun)

  -- Dual Wield
  [28379] = { 29293 }; -- twin slashes
  [38839] = { 38841 }; -- rending slashes
  [38845] = { 38848 }; -- blood craze
  [83600] = { 85156 }; -- lacerate
  [85187] = { 85192 }; -- rend
  [85179] = { 85182 }; -- thrive in chaos

  -- Bow
  [216674] = { 38254 }; -- goading vault (scribing) (taunt)
  [28879] = { 113627 }; -- scatter shot (BRP bow)
  [38672] = { 113627 }; -- magnum shot (BRP bow)
  [38669] = { 113627 }; -- draining shot (BRP bow)
  [38705] = { 38707 };  -- bombard (immobilized)
  [38701] = { 38703 };  -- acid spray
  [28869] = { 44540 };  -- poison arrow
  [38645] = { 44545 };  -- venom arrow
  [38660] = { 44549 };  -- poison injection

  -- Destruction Staff
  [29073] = { 62648 };  -- flame touch
  [29089] = { 62722 };  -- shock touch
  [29078] = { 62692 };  -- frost touch
  [38985] = { 140334 }; -- flame clench (master destro)
  [38993] = { 140334 }; -- shock clench (master destro)
  [38989] = { 38254 };  -- frost clench (taunt)
  [38944] = { 62682 };  -- flame reach
  [38978] = { 62745 };  -- shock reach
  [38970] = { 62712 };  -- frost reach
  [29173] = { 61743 };  -- weaknees to elements
  [39089] = { 39089 };  -- elemental susceptibility
  [39095] = { 61743 };  -- elemental drain (minor magickasteal)
  [28794] = { 115003 }; -- fire impulse (BRP destro)
  [28799] = { 115003 }; -- shock impulse (BRP destro)
  [28798] = { 115003 }; -- frost impulse (BRP destro)
  [39145] = { 115003 }; -- fire ring (BRP destro)
  [39147] = { 115003 }; -- shock ring (BRP destro)
  [39146] = { 115003 }; -- frost ring (BRP destro)
  [39162] = { 115003 }; -- flame pulsar (BRP destro)
  [39167] = { 115003 }; -- shock pulsar (BRP destro)
  [39163] = { 115003 }; -- frost pulsar (BRP destro)

  -- Restoration Staff
  [31531] = { 86304 }; -- force siphon
  [40109] = { 86304 }; -- siphon spirit
  [40116] = { 86304 }; -- quick siphon

  -- Werewolf
  [32632] = { 137156 };  -- punce (carnage bleed)
  [137156] = { 137156 }; -- carnage (bleed)
  [39105] = { 137184 };  -- brutal pounce (brutal carnage bleed)
  [137184] = { 137184 }; -- brutal carnage (bleed)
  [39104] = { 137164 };  -- feral pounce (brutal carnage bleed)
  [137164] = { 137164 }; -- feral carnage (bleed)
  [32633] = { 137257 };  -- roar (off-balance)
  [39113] = { 45834 };   -- ferocious roar (off-balance); 137287 is heavy attack speed buff
  [39114] = { 61743 };   -- deafening roar major breach; 137312 is off-balance
  [58855] = { 58856 };   -- infectious claws
  [58864] = { 58865 };   -- claws of anguish
  [58879] = { 58880 };   -- claws of life

  -- Soul Magic
  [26768] = { 126890 }; -- soul trap
  [40328] = { 126895 }; -- soul splitting trap
  [40317] = { 126898 }; -- consuming trap

  -- Fighters Guild
  [40336] = { 40340 }; -- silver leash
  [35750] = { 35756 }; -- trap beast dot
  [40372] = { 40375 }; -- lightweight beast trap dot
  [40382] = { 40385 }; -- barbed trap dot
  [35713] = { 62305 }; -- dawnbreaker
  [40158] = { 62314 }; -- dawnbreaker of smiting

  -- Mages Guild
  [28567] = { 126370 }; -- entropy
  [40452] = { 126371 }; -- structured entropy
  [40457] = { 126374 }; -- degeneration
  [40465] = { 40468 };  -- scalding rune (dot)

  -- Psijic Order
  [104059] = { 104078 }; -- borrowed time shield absorb

  -- Undaunted
  [42060] = { 42062 }; -- inner beast
  [39475] = { 38254 }; -- inner fire (taunt)
  [42056] = { 38254 }; -- inner rage (taunt)

  -- Alliance War
  -- Assault
  [61487] = { 61487 }; -- magicka detonation
  [61491] = { 61491 }; -- inevitable detonation

  -- Dragonknight
  [20657] = { 44363 }; -- searing strike
  [20668] = { 44369 }; -- venomous claw
  [20660] = { 44373 }; -- burning embers
  [20917] = { 31102 }; -- fiery breath
  [20930] = { 31104 }; -- engulfing flames
  [20944] = { 31103 }; -- noxious breath
  [20245] = { 20527 }; -- dark talons
  [20251] = { 61723 }; -- choking talons (minor maim)
  [20252] = { 31898 }; -- burning talons
  -- [133027] = {  31816 }; -- track stone giant
  -- [31816] = { 133027 }; -- track stagger
  [29032] = false;       -- don't track stonefist
  [31816] = { 134336 };  -- track stagger instead
  [133027] = { 134336 }; -- track stagger
  [29037] = {};          -- pretrify
  [32678] = {};          -- shattering rocks
  [32685] = {};          -- fossilize

  -- Sorcerer
  [28025] = {}; -- encase
  [28308] = {}; -- shattering prison
  [28311] = {}; -- restraining prison
  [24326] = {}; -- Daedric Curse
  [24330] = {}; -- haunting curse
  [24328] = {}; -- Daedric Prey

  -- Templar
  [21726] = { 21728 }; -- sun fire
  [21732] = { 21734 }; -- reflective light
  [21729] = { 21731 }; -- vampire's bane
  [21761] = { 21761 }; -- backlash
  [21765] = { 21765 }; -- purifying light
  [21763] = { 21763 }; -- PotL / 61742 (minor breach)
  [21776] = { 21776 }; -- eclipse
  [22004] = { 22004 }; -- unstable core

  -- Warden
  [85999] = { 130140 }; -- cutting dive bleed
  [86023] = { 101703 }; -- swarm
  [86027] = { 101904 }; -- fetcher infection
  [86031] = { 101944 }; -- growing swarm

  -- Nightblade
  [25484] = { 79717 };   -- ambush (minor vulnerability)
  [18342] = { 79717 };   -- teleport strike
  [25493] = { 79717 };   -- lotus fan
  [33357] = { 33357 };   -- mark target
  [36967] = { 36967 };   -- reapers mark
  [36968] = { 36968 };   -- piercing mark
  [33398] = { 61389 };   -- death stroke
  [36508] = { 61393 };   -- incap (70 ult)
  [113105] = { 113107 }; -- incap (120 ult)
  [36514] = { 61400 };   -- soul harvest
  [25255] = { 25256 };   -- veiled strike (off-balance)
  [25260] = { 34733 };   -- surprise attack (off-balance)
  [25352] = { 147643 };  -- aspect of terror
  [37470] = { 147643 };  -- mass hysteria
  [37475] = {};          -- manifestation of terror
  [33326] = { 33333 };   -- cripple
  [36943] = { 36947 };   -- debilitate
  [36957] = { 36960 };   -- crippling grasp
  [25091] = { 25093 };   -- soul shred
  [35460] = { 35462 };   -- soul tether

  -- Necromancer
  [122174] = { 106754 }; -- frozen colossus (major vuln)
  [122388] = { 106754 }; -- glacial colossus (major vuln)
  [122391] = { 106754 }; -- pestilent colossus (major vuln)
  [118226] = { 125750 }; -- ruinous scythe (off-balance)
  [115177] = { 61723 };  -- grave grasp (minor maim)
  [118308] = { 61723 };  -- ghostly embrace (minor maim)

  -- Arcanist
  [185817] = { 185818 }; -- abyssal impact (abyssal ink)
  [183006] = { 183008 }; -- cephaliarch's flail (abyssal ink)
  [185823] = { 185825 }; -- tentacular dread (abyssal ink)
  [185836] = { 185838 }; -- the imperfect ring (the imperfect ring)
  [185839] = { 185840 }; -- rune of displacement (rune of displacement)
  [182988] = { 182989 }; -- fulminating rune (fulminating rune)
  [183165] = { 38254 };  -- runic jolt (taunt)
  [183430] = { 187742 }; -- runic sunder (armor steal)
  [186531] = { 38254 };  -- runic embrace (taunt)
  [185918] = { 79717 };  -- rune of eldritch horror (minor vuln)
  [185921] = { 79717 };  -- rune of uncanny adoration (minor vuln)
  [183267] = { 145975 }; -- rune of the colorless pool (minor brittle)
};
FancyActionBar.specialIds = {
  -- abilities that require a separate function to update correctly.
  [35750] = true;  -- trap beast placed
  [35756] = true;  -- trap beast dot
  [40372] = true;  -- lightweight trap placed
  [40375] = true;  -- lightweight trap dot
  [40382] = true;  -- barbed trap placed
  [40385] = true;  -- barbed trap dot
  [40465] = true;  -- scalding rune placed
  [40468] = true;  -- scalding rune dot
  [16536] = true;  -- meteor called
  [63430] = true;  -- meteor aoe
  [40489] = true;  -- ice comet called
  [63456] = true;  -- ice comet aoe
  [40493] = true;  -- shooting star called
  [63473] = true;  -- shooting star aoe
  [86009] = true;  -- scorch
  [178020] = true; -- scorch second proc
  [86015] = true;  -- deep fissure
  [178028] = true; -- deep fissure second proc
  [86019] = true;  -- sub assault
  [146919] = true; -- sub assault second proc
  [86175] = true;  -- frozen gate
  [86179] = true;  -- frozen device
  [86183] = true;  -- frozen retreat
  [37475] = true;  -- manifestation of terror placed
  [76634] = true;  -- manifestation of terror triggered
  [46331] = true;  -- crystal weapon (to add stacks if tracking duration on self)
};

-- skill list based on this GetSlotBoundId(hotbarSlot; HOTBAR_CATEGORY_PRIMARY)
FancyActionBar.tauntSkills = {
  [38989] = "Frost Clench";     -- Frost Clench Ice Staff
  [20496] = "Unrelenting Grip"; -- Unrelenting Dragonknight

  [28306] = "Puncture";         -- Puncture S&B
  [38256] = "Ransack";          -- Ransack S&B
  [38250] = "Pierce Armor";     -- Pierce Armor S&B

  [39475] = "Inner Fire";       -- Inner Fire Undaunted
  [42056] = "Inner Rage";       -- Inner Rage Undaunted
  [42060] = "Inner Beast";      -- Inner Fire Undaunted

  [183430] = "Runic Sunder";    -- Runic Sunder Arcanist
  [186531] = "Runic Embrace";   -- Runic Embrace Arcanist
  [183165] = "Runic Jolt";      -- Runic Jolt Arcanist

  [40336] = "Silver Leash";     -- Silver Leash Fighters Guild

  [222966] = "Goading Throw";   -- Shield Throw Grimoire; Taunt focus (Scribing)
  [217180] = "Goading Smash";   -- Smash Grimoire; Taunt focus (Scribing)?
  [219972] = "Goading Smash";   -- Smash Grimoire; Taunt focus (Scribing)
  [216674] = "Goading Vault";   -- Vault Grimoire; Taunt focus (Scribing)

};

function FancyActionBar.IsAbilityTaunt(abilityId)
  if FancyActionBar.tauntSkills[abilityId] ~= nil then
    return false;
  else
    return true;
  end;
end;

FancyActionBar.fakeClassEffects = {
  --[[
  scuffed way of updating certain abilities; but updates as intended without much work.
  abilities that can't be tracked in EVENT_EFFECT_CHANGED alone.
  filter so only abilities from the current class is being tracked.
  when the game registers that you press the button for the ability;
  it allows EVENT_COMBAT_EVENT to update the timer on the first encounter or the id.
  needs to be given specific duration to update correctly.
]]
  -- Dragonknight
  [1] = {
    [31841] = { duration = 2.5; id = 31841 }; -- inhale
    [32788] = { duration = 2.5; id = 32788 }; -- draw essence
    [32796] = { duration = 2.5; id = 32796 }; -- deep breath
  };

  -- Sorcerer
  -- [2] = {};

  -- Nightblade
  --[3] = {
  --[33211] = { duration = GetAbilityDuration(33211) / 1000; id = 33211 }; -- Summon Shade
  --[35434] = { duration = GetAbilityDuration(35438) / 1000; id = 35438 }; -- Dark Shade
  --[35441] = { duration = GetAbilityDuration(35441) / 1000; id = 35441 }  -- Shadow Image
  --};

  -- Warden
  --[4] = {};

  -- Necromancer
  [5] = {
    [115924] = { duration = 20; id = 116445 }; -- Shocking Siphon
    [118008] = { duration = 20; id = 118009 }; -- Mystic Siphon
    [118763] = { duration = 20; id = 118764 }; -- Detonating Siphon
    [115926] = { duration = 12; id = 116450 }; -- Restoring Tether
    [118122] = { duration = 12; id = 118123 }; -- Mortal Coil
    [118070] = { duration = 12; id = 118071 }; -- Braided Tether
  };

  -- Templar
  [6] = {
    [22265] = { duration = GetAbilityDuration(22265) / 1000; id = 22265 }; -- Cleansing Ritual
    [22259] = { duration = GetAbilityDuration(22259) / 1000; id = 22259 }; -- Ritual of Retribution
    [22262] = { duration = GetAbilityDuration(22262) / 1000; id = 22262 }; -- Extended Ritual

    [22223] = { duration = GetAbilityDuration(22223) / 1000; id = 22223 }; -- rite of passage
    [22226] = { duration = GetAbilityDuration(22226) / 1000; id = 22226 }; -- practiced incantation
    [22229] = { duration = GetAbilityDuration(22229) / 1000; id = 22229 }; -- remembrance
  };

  -- Arcanist
  --[117] = {};
};

FancyActionBar.specialEffects = {
  [52790] = { id = 52790; stackId = 52790; isDebuff = true; forceShow = true } -- Debuff Effect for the Taunt Counter
};
FancyActionBar.specialEffectProcs = {};

-- The values must always be stored under the effectid tied to the action bar slot, in the case of haunting curse: 24330
FancyActionBar.specialClassEffects = {
  --- effects tracked through the HandleSpecial function
  -- Sorcerer
  [2] = {
    [24330] = { id = 24330; stackId = 24330; fixedTime = 3.5; stacks = 2; procs = 1; hasProced = 0; isDebuff = true }; -- Haunting Curse, first proc
    [89491] = { id = 24330; stackId = 24330; fixedTime = 8.5; stacks = 1; procs = 1; hasProced = 1; isDebuff = true }; -- Haunting Curse, second proc
  };
  -- Warden
  [4] = {
    [86015] = { id = 86015; stackId = 86015; fixedTime = 3; stacks = 2; procs = 1; hasProced = 0; isDebuff = false };  -- Deep Fissure, first proc
    [178028] = { id = 86015; stackId = 86015; fixedTime = 6; stacks = 1; procs = 1; hasProced = 1; isDebuff = false }; -- Deep Fissure, second proc
  }
};

FancyActionBar.specialClassEffectProcs = {
  --- Effect updates for ability completion conditions keyed by abilityId then procs number
  -- Sorcerer
  [2] = {
    [24330] = { [1] = { id = 24330; stacks = 0; procs = 1; hasProced = 0 }; };
    [89491] = { [1] = { id = 24330; stacks = 0; procs = 1; hasProced = 0 }; };
  };
  -- Warden
  [4] = {
    [86015] = { [1] = { id = 86015; stacks = 0; procs = 1; hasProced = 1 }; };
    [178028] = { [1] = { id = 178028; stacks = 0; procs = 1; hasProced = 1 } };
  };
};

FancyActionBar.fakeSharedEffects = {
  -- tracked along with fakeClassEffects.
  [35750] = { duration = GetAbilityDuration(35750) / 1000; id = 35750 }; -- trap beast
  [40372] = { duration = GetAbilityDuration(40382) / 1000; id = 40372 }; -- lightweight trap
  [40382] = { duration = GetAbilityDuration(40382) / 1000; id = 40382 }; -- barbed trap
  --[35756] = { duration = GetAbilityDuration(35756) / 1000; id = 35756 }; -- trap beast
  --[40375] = { duration = GetAbilityDuration(40375) / 1000; id = 40375 }; -- lightweight trap
  --[40385] = { duration = GetAbilityDuration(40385) / 1000; id = 40385 }; -- barbed trap
  [40468] = { duration = GetAbilityDuration(40468) / 1000; id = 40468 }; -- scalding rune

};

FancyActionBar.needCombatEvent = {
  [28297] = { duration = GetAbilityDuration(28297) / 1000; result = ACTION_RESULT_EFFECT_GAINED_DURATION }; -- momentum
  [38794] = { duration = GetAbilityDuration(38794) / 1000; result = ACTION_RESULT_EFFECT_GAINED_DURATION }; -- forward momentum
  --[38802] = { duration = GetAbilityDuration(38802) / 1000; result = ACTION_RESULT_EFFECT_GAINED_DURATION }; -- rally
};
--FancyActionBar.stackingDebuffs  = {
-- (debuffs on enemy targets)
-- currently not in use; but will eventually update timers and stacks when a target dies.
--[38745] = true; -- carve
--[134336] = true; -- stagger
--}
FancyActionBar.toggled = {
  -- effects with no duration are discarded for tracking.
  -- add exceptions for toggles here.
  -- Werewolf
  [32455] = true; -- Werewolf Transformation
  [39075] = true; -- Pack Leader
  [39076] = true; -- Werewolf Berserker

  -- Vampire
  [132141] = true; -- Blood Frenzy
  [134160] = true; -- Simmering Frenzy
  [135841] = true; -- Sated Fury

  -- Psijic Order
  [103543] = true; -- Mend Wounds
  [103747] = true; -- Mend Spirit
  [103755] = true; -- Symbiosis
  [103492] = true; -- Meditate
  [103652] = true; -- Deep Thoughts
  [103665] = true; -- Introspection

  -- Support
  [61511] = true; -- guard (on target)
  [61536] = true; -- mystic guard (on target)
  [61529] = true; -- stalwart guard (on target)

  -- [80923] = true; -- guard (on self)
  -- [80947] = true; -- mystic guard (on self)
  -- [80983] = true; -- stalwart guard (on self) 80984 = minor force on target. 80986 = minor force on self

  -- [78338] = true; -- guard (inactive)
  [81420] = true; -- Link active

  -- Sorcerer
  -- [24785] = true; -- Overload
  -- [24806] = true; -- Energy Overload
  -- [24804] = true; -- Power Overload
};
FancyActionBar.traps = {
  -- to update the effect when trap is triggered
  [35756] = 35750; --trap beast
  [40375] = 40372; --lightweight trap
  [40385] = 40382; --barbed trap
  [40468] = 40465; --scalding rune
  [61785] = 32685; -- fossilize
};
FancyActionBar.graveLordSacrifice = {
  id = 117749;
  eventId = 117757;
  duration = 20;
};
FancyActionBar.guard = {
  -- to help identify and update overlays as the slotted id changes depending on link state.
  link = 81420;
  slot1 = nil;
  slot2 = nil;
  ids = {
    [61511] = true; -- guard
    [61529] = true; -- stalwart guard
    [61536] = true; -- mystic guard
  };
};
FancyActionBar.sCorch = {
  id1 = 86009;
  id2 = 178020;
};
-- FancyActionBar.deepFissure = {
--   id1 = 86015;
--   id2 = 178028;
-- };
FancyActionBar.subAssault = {
  id1 = 86019;
  id2 = 146919;
};
FancyActionBar.soulTrap = {
  -- to check which effect to register once slotted.
  --slot id = { mag id; stam id}
  [26768] = { 126890; 126891 }; -- soul trap
  [40328] = { 126895; 126894 }; -- soul splitting trap
  [40317] = { 126897; 126898 }; -- consuming trap
};
FancyActionBar.meteor = {
  -- same as traps; maybe combine both eventually.
  [63430] = 16536; -- meteor
  [63456] = 40489; -- ice comet
  [63473] = 40493; -- shooting star
};
FancyActionBar.frozen = {
  -- for tracking active portals.
  [86175] = true; -- frozen gate
  [86179] = true; -- frozen device
  [86183] = true; -- frozen retreat
};
FancyActionBar.iceShield = {
  -- for tracking if able to absord projectiles.
  [86135] = true, -- crystallized shield
  [86139] = true, -- crystallized slab
  --[92168] = true; -- crystallized slab
  [86143] = true, -- shimmering shield
};
FancyActionBar.reflects = {
  -- to track the reflect / absorb charges.
  -- abilities entered here will be updated with EVENT_COMBAT_EVENT 'OnReflect'.
  [126604] = 28727, -- defensive posture
  [126608] = 38312, -- defensive stance
  [38324] = 38317,  -- absorb missile
  [86135] = 86135,  -- crystallized shield
  [86139] = 86139,  -- crystallized slab
  [86143] = 86143,  -- shimmering shield
};
FancyActionBar.dontFade = {
  -- filter for debugging.
  [63601] = true;  -- ESO Plus
  [160197] = true; -- ward master
  [103966] = true; -- concentrated barrier
  [61744] = true;  -- minor berserk
  [114716] = true; -- crystal frags
};
FancyActionBar.dontFade = {
  -- don't reset duration when effect fades until function to update corretly is in place.
  -- buffs
  [61665] = true;  -- major brutality
  [76518] = true;  -- major brutality
  [61687] = true;  -- major sorcery
  [92503] = true;  -- major sorcery
  [61694] = true;  -- major resolve
  [88758] = true;  -- major resolve
  [106754] = true; -- major vuln
  [61743] = true;  -- major breach
  [61704] = true;  -- minor endurance
  [61706] = true;  -- minor intellect
  [61697] = true;  -- minor fortitude
  [61723] = true;  -- minor maim
  [61742] = true;  -- minor breach
  [86304] = true;  -- minor lifesteal
  [61693] = true;  -- minor resolve
  [176991] = true; -- minor resolve
  [145975] = true; -- minor brittle
  [61504] = true;  -- vigor
  [61506] = true;  -- echoing vigor
  [61737] = true;  -- empower
  [34733] = true;  -- off-balance
  [25256] = true;  -- off-balance
  [45834] = true;  -- off-balance
  [125750] = true; -- off-balance
  [131562] = true; -- off-balance
  [137257] = true; -- off-balance
  [137312] = true; -- off-balance
  [130129] = true; -- off-balance

  -- Two Handed
  [38747] = true; -- carve
  [83217] = true; -- berserker strike
  [83230] = true; -- onslaught
  [83239] = true; -- berserker rage

  -- Dual Wield
  [29293] = true; -- twin slashes
  [38841] = true; -- rending slashes
  [38848] = true; -- blood craze
  [85156] = true; -- lacerate
  [85192] = true; -- rend
  [85182] = true; -- thrive in chaos

  -- Bow
  [113627] = true; -- magnum shot (BRP bow)
  [38707] = true;  -- bombard
  [38703] = true;  -- acid spray
  [44540] = true;  -- poison arrow
  [44545] = true;  -- venom arrow
  [44549] = true;  -- poison injection

  -- Destruction Staff
  [62648] = true;  -- flame touch
  [62692] = true;  -- frost touch
  [62722] = true;  -- shock touch
  [62682] = true;  -- flame reach
  [62712] = true;  -- frost reach
  [62745] = true;  -- shock reach
  [115003] = true; -- BRP destro

  -- Soul Magic
  [126890] = true; -- soul trap
  [126895] = true; -- soul splitting trap
  [126898] = true; -- consuming trap

  -- Fighters Guild
  [35756] = true; -- trap beast
  [40375] = true; -- lightweight trap
  [40385] = true; -- barbed trap

  -- Mages Guild
  [40468] = true;  -- scalding rune
  [126370] = true; -- entropy
  [126371] = true; -- structured entropy
  [126374] = true; -- degeneration
  [16536] = true;  -- meteor

  -- Undaunted
  [38254] = true; -- taunt
  [42062] = true; -- inner beast

  -- Dragonknight
  [44363] = true; -- searing strike
  [44369] = true; -- venomous claw
  [44373] = true; -- burning embers
  [31102] = true; -- fiery breath
  [31103] = true; -- noxious breath
  [31104] = true; -- engulfing flames
  [31898] = true; -- burning talons
  [32685] = true; -- fossilize

  -- Sorcerer
  [24844] = true; -- daedric tomb
  [24326] = true; -- Daedric Curse
  [24330] = true; -- haunting curse
  [24328] = true; -- Daedric Prey

  -- Templar
  [21728] = true; -- sun fire
  [21734] = true; -- reflective light
  [21731] = true; -- vampire's bane
  [21763] = true; -- PotL
  [21765] = true; -- purifying light

  -- Warden
  [130140] = true; -- cutting dive bleed
  [86019] = true;  -- sub assault
  -- [86023] = true; -- swarm
  -- [86027] = true; -- fetcher infection
  -- [86031] = true; -- growing swarm
  [101703] = true; -- swarm
  [101904] = true; -- fetcher infection
  [101944] = true; -- growing swarm
  [85840] = true;  -- growing swarm

  -- Nightblade
  [33357] = true;  -- mark target
  [36967] = true;  -- reapers mark
  [36968] = true;  -- piercing mark
  [61389] = true;  -- death stroke
  [61393] = true;  -- incap (70 ult)
  [113107] = true; -- incap (120 ult)
  [61400] = true;  -- soul harvest
  [33333] = true;  -- cripple
  [36947] = true;  -- debilitate
  [36960] = true;  -- crippling grasp
  [25093] = true;  -- soul shred
  [35462] = true;  -- soul tether

  -- Necromancer
  [61726] = true; -- render flesh (minor defile)


  -- Arcanist
  [185818] = true; -- abyssal impact (abyssal ink)
  [183008] = true; -- cephaliarch's flail (abyssal ink)
  [185825] = true; -- tentacular dread (abyssal ink)
  [187742] = true; -- runic sunder (armor steal)
  [185838] = true; -- the imperfect ring (the imperfect ring)
  [185840] = true; -- rune of displacement (rune of displacement)
  [182989] = true; -- fulminating rune (fulminating rune)
};
FancyActionBar.removeInstantly = {
  -- 'proc' effects seem to clutter more when '0.0' is being displayed after use.
  -- few other effects gave same impression. will add options.
  --[35756] = true; -- trap best
  --[40375] = true; -- lightweight trap
  [40385] = true; -- barbed trap
  [40468] = true; -- scalding rune
  --[31632] = true; -- fire rune
  --[40470] = true; -- volcanic rune
  [24785] = true;  -- overload
  [24806] = true;  -- power overload
  [24804] = true;  -- energy overload
  [61721] = true;  -- minor protection
  [29224] = true;  -- igneous shield (shield)
  [38254] = true;  -- taunt
  [46327] = true;  -- crystal frags
  [86009] = true;  -- scorch
  [86015] = true;  -- deep fissure
  [86019] = true;  -- subterranean assault
  [103879] = true; -- spell orb
  [114863] = true; -- blastbones
  [117691] = true; -- blighted blastbones
  [117750] = true; -- stalking blastbones
  [117638] = true; -- ricochet skull
  [117625] = true; -- venom skull
  [184220] = true; -- crux
  [52790] = true;  -- taunt counter
};
FancyActionBar.allowedChanneled = {
  -- all channeled abilities are set to be untracked; unless added here.
  [103492] = true; -- Meditate
  [103652] = true; -- Deep Thoughts
  [103665] = true; -- Introspection

  [26792] = true;  -- Biting Jabs
  [22223] = true;  -- rite of passage
  [22226] = true;  -- practiced incantation
  [22229] = true;  -- remembrance

  [185805] = true; -- fatecarver
  [193331] = true; -- fatecarver
  [183122] = true; -- exhausting fatecarver
  [193397] = true; -- exhausting fatecarver
  [186366] = true; -- pragmatic fatecarver
  [193398] = true; -- pragmatic fatecarver
  [183537] = true; -- remedy cascade
  [198309] = true; -- remedy cascade
  [186193] = true; -- cascading fortune
  [198330] = true; -- cascading fortune
  [186200] = true; -- curative surge
  [198537] = true; -- curative surge
};
FancyActionBar.soloTarget = {
  -- abilities that are removed from target when cast before it expires.
  [28025] = true; -- encase
  [28308] = true; -- shattering prison
  [28311] = true; -- restraining prison
  [24326] = true; -- Daedric Curse
  [24330] = true; -- haunting curse
  [24328] = true; -- Daedric Prey
};

local WEAPONTYPE_NONE = WEAPONTYPE_NONE;
local WEAPONTYPE_FIRE_STAFF = WEAPONTYPE_FIRE_STAFF;
local WEAPONTYPE_FROST_STAFF = WEAPONTYPE_FROST_STAFF;
local WEAPONTYPE_LIGHTNING_STAFF = WEAPONTYPE_LIGHTNING_STAFF;
FancyActionBar.destroSkills = {
  [28858] = { type = 1; morph = 1 }; -- wall of elements
  [28807] = { type = 1; morph = 1 }; -- fire
  [28849] = { type = 1; morph = 1 }; -- ice
  [28854] = { type = 1; morph = 1 }; -- shock

  [39011] = { type = 1; morph = 2 }; -- elemental blockade
  [39012] = { type = 1; morph = 2 }; -- fire
  [39028] = { type = 1; morph = 2 }; -- ice
  [39018] = { type = 1; morph = 2 }; -- shock

  [39052] = { type = 1; morph = 3 }; -- unstable wall of elements
  [39053] = { type = 1; morph = 3 }; -- fire
  [39067] = { type = 1; morph = 3 }; -- ice
  [39073] = { type = 1; morph = 3 }; -- shock

  [29091] = { type = 2; morph = 1 }; -- destructive touch
  [29073] = { type = 2; morph = 1 }; -- fire
  [29078] = { type = 2; morph = 1 }; -- ice
  [29089] = { type = 2; morph = 1 }; -- shock

  [38937] = { type = 2; morph = 2 }; -- destructive reach
  [38944] = { type = 2; morph = 2 }; -- fire
  [38970] = { type = 2; morph = 2 }; -- ice
  [38978] = { type = 2; morph = 2 }; -- shock

  [38984] = { type = 2; morph = 3 }; -- destructive clench
  [38985] = { type = 2; morph = 3 }; -- fire
  [38989] = { type = 2; morph = 3 }; -- ice
  [38993] = { type = 2; morph = 3 }; -- shock

  [28800] = { type = 3; morph = 1 }; -- impulse
  [28794] = { type = 3; morph = 1 }; -- fire
  [28798] = { type = 3; morph = 1 }; -- ice
  [28799] = { type = 3; morph = 1 }; -- shock

  [39143] = { type = 3; morph = 2 }; -- elemental ring
  [39145] = { type = 3; morph = 2 }; -- fire
  [39146] = { type = 3; morph = 2 }; -- ice
  [39147] = { type = 3; morph = 2 }; -- shock

  [39161] = { type = 3; morph = 3 }; -- pulsar
  [39162] = { type = 3; morph = 3 }; -- fire
  [39163] = { type = 3; morph = 3 }; -- ice
  [39167] = { type = 3; morph = 3 }; -- shock

  [83619] = { type = 4; morph = 1 }; -- elemental storm
  [83625] = { type = 4; morph = 1 }; -- fire
  [83628] = { type = 4; morph = 1 }; -- ice
  [83630] = { type = 4; morph = 1 }; -- shock

  [83642] = { type = 4; morph = 2 }; -- eye of the storm
  [83682] = { type = 4; morph = 2 }; -- fire
  [83684] = { type = 4; morph = 2 }; -- ice
  [83686] = { type = 4; morph = 2 }; -- shock

  [84434] = { type = 4; morph = 3 }; -- elemental rage
  [85126] = { type = 4; morph = 3 }; -- fire
  [85128] = { type = 4; morph = 3 }; -- ice
  [85130] = { type = 4; morph = 3 }; -- shock
};
FancyActionBar.idsForStaff = {
  [1] = {   -- wall morphs
    [1] = { -- wall of elements
      [WEAPONTYPE_NONE] = 28858;
      [WEAPONTYPE_FIRE_STAFF] = 28807;
      [WEAPONTYPE_FROST_STAFF] = 28849;
      [WEAPONTYPE_LIGHTNING_STAFF] = 28854;
    };
    [2] = { -- elemental blockade
      [WEAPONTYPE_NONE] = 39011;
      [WEAPONTYPE_FIRE_STAFF] = 39012;
      [WEAPONTYPE_FROST_STAFF] = 39028;
      [WEAPONTYPE_LIGHTNING_STAFF] = 39018;
    };
    [3] = { -- unstable wall of elements
      [WEAPONTYPE_NONE] = 39052;
      [WEAPONTYPE_FIRE_STAFF] = 39053;
      [WEAPONTYPE_FROST_STAFF] = 39067;
      [WEAPONTYPE_LIGHTNING_STAFF] = 39073;
    };
  };
  [2] = { -- touch / reach / clench
    [1] = {
      [WEAPONTYPE_NONE] = 29091;
      [WEAPONTYPE_FIRE_STAFF] = 29073;
      [WEAPONTYPE_FROST_STAFF] = 29078;
      [WEAPONTYPE_LIGHTNING_STAFF] = 29089;
    };
    [2] = {
      [WEAPONTYPE_NONE] = 38937;
      [WEAPONTYPE_FIRE_STAFF] = 38944;
      [WEAPONTYPE_FROST_STAFF] = 38970;
      [WEAPONTYPE_LIGHTNING_STAFF] = 38978;
    };
    [3] = {
      [WEAPONTYPE_NONE] = 38984;
      [WEAPONTYPE_FIRE_STAFF] = 38985;
      [WEAPONTYPE_FROST_STAFF] = 38989;
      [WEAPONTYPE_LIGHTNING_STAFF] = 38993;
    };
  };
  [3] = { -- impulse / ring / pulsar
    [1] = {
      [WEAPONTYPE_NONE] = 28800;
      [WEAPONTYPE_FIRE_STAFF] = 28794;
      [WEAPONTYPE_FROST_STAFF] = 28798;
      [WEAPONTYPE_LIGHTNING_STAFF] = 28799;
    };
    [2] = {
      [WEAPONTYPE_NONE] = 39143;
      [WEAPONTYPE_FIRE_STAFF] = 39145;
      [WEAPONTYPE_FROST_STAFF] = 39146;
      [WEAPONTYPE_LIGHTNING_STAFF] = 39147;
    };
    [3] = {
      [WEAPONTYPE_NONE] = 39161;
      [WEAPONTYPE_FIRE_STAFF] = 39162;
      [WEAPONTYPE_FROST_STAFF] = 39163;
      [WEAPONTYPE_LIGHTNING_STAFF] = 39167;
    };
  };
  [4] = { -- storm / eye / rage
    [1] = {
      [WEAPONTYPE_NONE] = 83619;
      [WEAPONTYPE_FIRE_STAFF] = 83625;
      [WEAPONTYPE_FROST_STAFF] = 83628;
      [WEAPONTYPE_LIGHTNING_STAFF] = 85130;
    };
    [2] = {
      [WEAPONTYPE_NONE] = 83642;
      [WEAPONTYPE_FIRE_STAFF] = 83682;
      [WEAPONTYPE_FROST_STAFF] = 83684;
      [WEAPONTYPE_LIGHTNING_STAFF] = 83686;
    };
    [3] = {
      [WEAPONTYPE_NONE] = 84434;
      [WEAPONTYPE_FIRE_STAFF] = 85126;
      [WEAPONTYPE_FROST_STAFF] = 85128;
      [WEAPONTYPE_LIGHTNING_STAFF] = 85130;
    };
  };
};
