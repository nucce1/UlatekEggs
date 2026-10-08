-- Testrigg för UlatekEggs: minimalt mockat WoW-API (ramar, events, timers,
-- raidnot via Northern Sky/MRT, roster, ljud, Settings) och addonet laddat
-- som i spelet. Körs med: python test\run_lua.py
-- luacheck: ignore

local failures, checks = 0, 0
local realPrint = print
local function check(label, got, want)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    realPrint(("FAIL  %s: fick %s, väntade %s"):format(label, tostring(got), tostring(want)))
  end
end

-- ===== Mockat WoW-API ===================================================
local output = {}
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  output[#output + 1] = table.concat(parts, " ")
end
local function said(text)
  for i = #output, 1, -1 do
    if output[i]:find(text, 1, true) then return true end
  end
  return false
end
local function clearOutput() output = {} end

local now = 1000
local frames = {}
local methods = {}
local Widget = { __index = function(_, k) return methods[k] or function() end end }
local function newWidget(kind, name)
  local w = setmetatable({ kind = kind, name = name, shown = true, scripts = {}, width = 0, height = 0, text = "" }, Widget)
  if name then _G[name] = w end
  return w
end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(v) self.shown = v end
function methods:IsShown() return self.shown end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetText(t) self.text = tostring(t) end
function methods:GetText() return self.text end
function methods:SetTexCoord(...) self.coords = { ... } end
function methods:SetScript(k, fn) self.scripts[k] = fn end
function methods:SetPoint(p, rel) self.point, self.anchor = p, rel end
function methods:GetPoint() return "CENTER", nil, nil, 0, 0 end
function methods:CreateTexture() return newWidget("Texture") end
local strings = {}
function methods:CreateFontString() local w = newWidget("FontString"); strings[#strings + 1] = w; return w end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:SetVertexColor(r, g, b) self.green = g == 1 end
function methods:SetScale(s) self.scale = s end
function methods:GetScale() return self.scale or 1 end
function methods:GetLeft() return 0 end
function methods:GetTop() return self.height end
function methods:SetFont(_, size) self.fontSize = size end
function methods:SetChecked(v) self.checked = v end
function methods:GetChecked() return self.checked end
function methods:EnableMouse(v) self.mouse = v end
function methods:SetFrameStrata(v) self.strata = v end

CreateFrame = function(kind, name, parent, template) local w = newWidget(kind, name); w.template = template; frames[#frames + 1] = w; return w end
UIParent = newWidget("Frame", "UIParent"); UIParent.width, UIParent.height = 1365, 768
local EDIT_W = math.floor(math.min(1365, 768 * (2000 / 1125)) * 0.75)
GetTime = function() return now end
GetCursorPosition = function() return 0, 0 end
C_AddOns = { GetAddOnMetadata = function() return "test" end }
local ticker
C_Timer = { NewTicker = function(_, fn) ticker = { fn = fn, Cancel = function(self) self.cancelled = true end }; return ticker end }
function CopyTable(t) local c = {}; for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end; return c end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local roster = { player = "Nucce" }
local inRaid = false
UnitName = function(unit) return roster[unit] end
IsInRaid = function() return inRaid end
IsInGroup = function() return inRaid end
GetNumGroupMembers = function() local n = 0 for k in pairs(roster) do if k:find("^raid") then n = n + 1 end end return n end
local sounds = {}
PlaySound = function(id, ch) sounds[#sounds + 1] = { id = id, ch = ch } end
SOUNDKIT = { RAID_WARNING = 8959 }
local opened = 0
Settings = {
  RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, GetID = function() return 42 end } end,
  RegisterAddOnCategory = function() end,
  OpenToCategory = function(id) check("panel öppnas med rätt id", id, 42); opened = opened + 1 end,
}
SlashCmdList = {}
GameFontHighlightSmall = { GetFont = function() return "font", 10, "" end }
SettingsPanel = newWidget("Frame", "SettingsPanel")
local panelHidden = 0
HideUIPanel = function(fr) fr:Hide(); panelHidden = panelHidden + 1 end
-- MinimalSliderWithSteppersTemplate: Init sparar gränser, SetValue klampar och avfyrar callbacken (som i spelet)
function methods:Init(v, minV, maxV) self.minV, self.maxV, self.value = minV, maxV, v end
function methods:RegisterCallback(_, fn) self.callback = fn end
function methods:SetValue(v)
  self.value = math.max(self.minV, math.min(self.maxV, v))
  if self.callback then self.callback(nil, self.value) end
end

-- ===== Ladda addonet ======================================================
local chunk = assert(loadfile(ADDON_DIR .. "UlatekEggs.lua"))
chunk("UlatekEggs")
local f = UlatekEggsFrame
local ev
for _, fr in ipairs(frames) do if fr.scripts.OnEvent then ev = fr end end
local function fire(event, ...) ev.scripts.OnEvent(ev, event, ...) end
local function slash(s) SlashCmdList.ULATEKEGGS(s) end
local function tick() ticker.fn() end

UlatekEggsDB = { windows = { { 1, 2 }, { 3, 4 } }, scale = 1 } -- gammalt sparat format
fire("ADDON_LOADED", "UlatekEggs")
local DB = UlatekEggsDB
check("gammalt windows-fält rensas", DB.windows, nil)
check("default fönster 1", DB.starts[1], 208)
check("default längd 30 s", DB.duration, 30)
check("ljud av som standard", DB.sound, false)
check("tider från noten på som standard", DB.noteTimes, true)
slash("status")
check("inbyggd layout: 12 höger, 11 vänster", said("Äggpositioner: inbyggda (höger 12, vänster 11)"), true)
slash("")
check("/ute öppnar panelen", opened, 1)
slash("preview H2")
check("inbyggd: nedre högra ägg syns", f.dots[10].tex.shown and f.dots[11].tex.shown and f.dots[12].tex.shown, true)
check("inbyggd: övre ägg dolda i område 2", f.dots[1].tex.shown, false)
slash("preview V1")
check("inbyggd: V1–V8 syns", f.dots[1].tex.shown and f.dots[8].tex.shown, true)
check("inbyggd: V9 dold i område 1", f.dots[9].tex.shown, false)
slash("hide")

-- ===== Panelen ============================================================
local panel
for _, fr in ipairs(frames) do if fr.name == "UlatekEggs" and fr.scripts.OnShow then panel = fr end end
check("panelen finns", panel ~= nil, true)
local function previewLineText() -- panelens Visar-rad = senaste FontString som börjar med Visar/Förhandsvisningen
  for i = #strings, 1, -1 do
    local w = strings[i]
    if w.text:find("^Visar") or w.text:find("^Förhandsvisningen") then return { text = w.text } end
  end
  return { text = "" }
end
check("panelen är dold tills Settings visar den", panel.shown, false)
check("panelen har OnRefresh", type(panel.OnRefresh), "function")
local okShow = pcall(panel.scripts.OnShow, panel)
check("panelens OnShow kraschar inte", okShow, true)
check("panel öppen: kartan visas", f:IsShown(), true)
check("panel öppen: kartan dragbar", f.mouse, true)
check("panel öppen: kartan ovanpå panelen", f.strata, "DIALOG")
check("panel öppen: Visar-raden i panelen", previewLineText().text:find("^Visar höger, övre hörnet") ~= nil, true)
local hiddenBefore = panelHidden
clearOutput()
slash("preview V2")
check("preview stänger inte panelen", panelHidden, hiddenBefore)
check("preview under öppen panel visas", f:IsShown(), true)
check("preview under öppen panel skriver i panelen, inte chatten", said("nedre hörnet"), false)
check("Visar-raden uppdateras", previewLineText().text, "Visar vänster, nedre hörnet: ingen tilldelning (raidnot eller /ute set)")
slash("hide")
check("hide under öppen panel göms", f:IsShown(), false)
slash("preview H1")
check("hörnknapp efter hide visar igen", f:IsShown(), true)
check("hörnknapp efter hide: dragbar igen", f.mouse, true)
slash("check")
check("check stänger inte panelen", panelHidden, hiddenBefore)
panel.scripts.OnHide(panel)
check("panel stängd: kartan göms", f:IsShown(), false)
check("panel stängd: kartan låst", f.mouse, false)
check("panel stängd: tillbaka i stridslagret", f.strata, "HIGH")
slash("scale 3")
panel.scripts.OnShow(panel)
check("panelens refresh klampar inte skalan i DB", DB.scale, 3)
panel.scripts.OnHide(panel)
slash("scale 1")
local buttons = {}
for _, fr in ipairs(frames) do if fr.kind == "Button" and fr.template == "UIPanelButtonTemplate" then buttons[fr.text] = fr end end
check("ingen Flytta-knapp längre", buttons["Flytta kartan"], nil)
check("en Redigera-knapp", buttons["Redigera äggens positioner…"] ~= nil and buttons["Redigera höger"] == nil, true)
check("inga Stäng/Visa kartan-knappar", buttons["Stäng kartan"] == nil and buttons["Visa kartan"] == nil, true)
check("hörnknappar", buttons["Vänster övre"] ~= nil and buttons["Höger nedre"] ~= nil, true)
check("Återställ dold utan egen layout", buttons["Återställ inbyggda positioner"].shown, false)
local boxes = {}
for _, fr in ipairs(frames) do if fr.kind == "CheckButton" then boxes[#boxes + 1] = fr end end
check("tre kryssrutor", #boxes, 3)
check("kryssruta speglar DB (ljud av)", boxes[1].checked, false)
boxes[1].checked = true
boxes[1].scripts.OnClick(boxes[1])
check("kryssruta skriver DB", DB.sound, true)
DB.sound = false

-- ===== Import / export ====================================================
slash("import UTE1;H=0.800,0.100 0.750,0.150 0.700,0.900;V=0.300,0.100;END")
check("import H", #DB.eggs.H, 3)
check("import V", #DB.eggs.V, 1)
check("import bevarar värden", DB.eggs.H[3][2], 0.9)
fire("ADDON_LOADED", "UlatekEggs")
check("egen layout flaggas vid inloggning", said("egen ägg-layout aktiv (höger 3, vänster 1)"), true)

-- ===== Förhandsvisning utan tilldelning ==================================
slash("preview H1")
check("preview visar", f:IsShown(), true)
check("stridskarta: prick 18 px", f.dots[1].tex.width, 18)
check("preview beskär H1", f.map.coords[1], 0.65)
check("preview säger i chatten", said("höger, övre hörnet: ingen tilldelning (raidnot"), true)
check("ingen text på kartan", f.title.text, "")
check("prick 1 inom H1", f.dots[1].tex.shown, true)
check("prick 3 utanför H1", f.dots[3].tex.shown, false)
check("ingen grön prick", f.dots[1].tex.green or f.dots[2].tex.green, false)
check("inga nummer i stridsvyn", f.dots[1].label.shown, false)
check("höjd följer beskärning", math.floor(f:GetHeight() + 0.5), math.floor(170 / (2000 / 1125) * 0.36 / 0.16 + 0.5))

-- ===== MRT-not med ulaStart-block ========================================
VMRT = { Note = { Text1 = "Pull 1 ...\nulaStart\ntid 3:30 3:55\n|cffff0000Veraiz|r V1 |cff00ff00Nucce-Ravencrest|r H2/H3 Keta H1\nulaEnd\nannat" } }
slash("preview H1")
check("mitt ägg grönt (område 1)", f.dots[2].tex.green, true)
check("andra ägg röda", f.dots[1].tex.green, false)
check("chatten visar källa", said("ditt ägg: 2 (MRT-not)"), true)
slash("preview H2")
check("område 2: prick 3 inom H2", f.dots[3].tex.shown, true)
check("prick 3 grön", f.dots[3].tex.green, true)
slash("preview V1")
check("fel sida ger info", said("din sida är höger"), true)
check("fel sida ingen grön", f.dots[1].tex.green, false)
slash("hide")
check("hide", f:IsShown(), false)
slash("status")
check("tider från noten", said("Kartan visas 3:30 och 3:55 efter pull, 30 s per hörn (tider från raidnoten)"), true)
DB.noteTimes = false
slash("status")
check("tider från noten avstängt", said("Kartan visas 3:28 och 3:54 efter pull, 30 s per hörn (egna tider, notens tid-rad används inte)"), true)
DB.noteTimes = true
VMRT = { Note = { Text1 = "ulaStart tid 3:30 3:55 45 Nucce H2 ulaEnd" } }
slash("status")
check("block på en rad + längd", said("3:30 och 3:55 efter pull, 45 s per hörn (tider från raidnoten)"), true)
VMRT = { Note = { Text1 = "ulaStart Nucce H2 (inget slut)" } }
slash("status")
check("block utan ulaEnd läses till slutet", said("Ditt ägg: höger 2 i övre hörnet, inget i nedre hörnet|r (från MRT-noten)"), true)
VMRT = { Note = { Text1 = "ulatek: Nucce H2" } }
slash("status")
check("gamla formatet utan block ger inget", said("Ditt ägg: inget|r – ingen raidnot med ulaStart-block"), true)

-- ===== Northern Sky-reminder ==============================================
VMRT = nil
local NS_PERSONAL, NS_SHARED = nil, nil
NSAPI = { GetReminderString = function(_, encID) check("NS frågas med encounter-id", encID, 3492); return NS_PERSONAL, NS_SHARED end }
slash("status")
check("tom NS-not ger ingen tilldelning", said("Ditt ägg: inget"), true)
NS_SHARED = "{time:0:30} Nån reminder\nulaStart\nVeraiz V1 |cff00ff00Nucce|r H2/H3\nulaEnd\n"
slash("preview H1")
check("NS delad not läses", said("ditt ägg: 2 (NS-not)"), true)
NS_SHARED = nil
NS_PERSONAL = "ulaStart Nucce H4 ulaEnd"
slash("preview H1")
check("NS personlig not läses", said("(NS-not (personlig))"), true)
VMRT = { Note = { Text1 = "ulaStart Nucce H1 ulaEnd" } }
slash("preview H1")
check("NS går före MRT", said("ditt ägg: 4"), true)
NS_PERSONAL = nil
slash("preview H1")
check("MRT som reserv", said("ditt ägg: 1 (MRT-not)"), true)
-- Northern Sky-callback: ny reminder -> "Ditt ägg" i chatten
local nsCallback
NSAPI.RegisterCallback = function(owner, event, fn) check("callback-event", event, "NSRT_REMINDER_CHANGED"); nsCallback = fn end
fire("ADDON_LOADED", "UlatekEggs")
check("callback registreras när NS finns", nsCallback ~= nil, true)
VMRT = nil
NS_SHARED = "{time:1:00} annan boss\nreminder utan block"
clearOutput()
nsCallback("NSRT_REMINDER_CHANGED", NS_PERSONAL, NS_SHARED)
check("not utan block ger ingen chattrad", said("ny raidnot"), false)
NS_SHARED = "ulaStart Veraiz V1 Nucce H2/H3 ulaEnd"
clearOutput()
check("chattrad vid ny not är av som standard", DB.noteChat, false)
nsCallback("NSRT_REMINDER_CHANGED", NS_PERSONAL, NS_SHARED)
check("avstängt: ingen chattrad trots ny not", said("ny raidnot"), false)
DB.noteChat = true
nsCallback("NSRT_REMINDER_CHANGED", NS_PERSONAL, NS_SHARED)
check("påslaget: ny not med block ger Ditt ägg i chatten", said("ny raidnot – |cff80ff80Ditt ägg: höger 2 i övre hörnet, höger 3 i nedre hörnet|r (från Northern Sky-noten)"), true)
local n = #output
nsCallback("NSRT_REMINDER_CHANGED", NS_PERSONAL, NS_SHARED)
now = now + 600
nsCallback("NSRT_REMINDER_CHANGED", NS_PERSONAL, NS_SHARED)
check("samma not (ready check/pulltimer) tystas oavsett tid", #output, n)
NS_SHARED = "ulaStart Veraiz V1 ulaEnd"
clearOutput()
nsCallback("NSRT_REMINDER_CHANGED", NS_PERSONAL, NS_SHARED)
check("ny not där jag saknas säger det", said("ny raidnot – |cffff6060Ditt ägg: inget|r – du står inte i raidnotens ulaStart-block"), true)
DB.noteChat = false
NS_SHARED = nil
NSAPI = nil
now = 1000
slash("hide")

-- ===== Manuell tilldelning, token-format =================================
VMRT = nil
slash("set R1/5")
check("R tolkas som H + varning om nummer utanför egen layout", said("Ditt ägg: H5 finns inte, höger har 3 ägg"), true)
slash("set H/9")
slash("preview H1")
check("H/9: inget ägg i övre hörnet", said("övre hörnet: inget ägg här"), true)
check("H/9: ingen grön i område 1", f.dots[1].tex.green or f.dots[2].tex.green, false)
slash("preview H2")
check("H/9: ägg 9 i område 2", said("ditt ägg: 9"), true)
slash("set right")
check("ord avvisas som tilldelning", said("ex: /ute set H3/H9"), true)
check("ogiltig set sparas inte", DB.assign, "H/9")
slash("set")
check("set utan argument rensar", DB.assign, nil)
VMRT = { Note = { Text1 = "ulaStart Nucce right 3 ulaEnd" } }
slash("status")
check("ord i noten ger ingen sida", said("Ditt ägg: inget|r – du står inte i raidnotens ulaStart-block"), true)
VMRT = { Note = { Text1 = "|cff00ff00ulaStart|r Nucce H3/H9 |cff00ff00ulaEnd|r" } }
slash("preview H1")
check("färgade nyckelord matchas", said("ditt ägg: 3 (MRT-not)"), true)
VMRT = { Note = { Text1 = "ulaStart Nucce Lars H3 ulaEnd" } }
slash("status")
check("namn efter namn tolkas inte som sida", said("Ditt ägg: inget"), true)
slash("hide")
VMRT = { Note = { Text1 = "ulaStart\ntid 3:28 3:54\nNucce H2/H3 Keta H1\nulaEnd" } }

-- ===== Rosterkontroll =====================================================
clearOutput()
slash("check")
check("check solo: jag har rad", said("saknar rad i noten: ingen"), true)
check("check solo: Keta är inte här", said("(felstavat?): Keta"), true)
inRaid = true
roster = { player = "Nucce", raid1 = "Nucce", raid2 = "Keta-Ravencrest", raid3 = "Bizer", raid4 = "Zed" }
clearOutput()
slash("check")
check("check raid: saknade listas sorterat", said("saknar rad i noten: Bizer, Zed"), true)
check("check raid: Keta med realm matchar", said("(felstavat?): ingen"), true)
check("check raid: antal och tider", said("2 i noten, tider 3:28 + 3:54"), true)
VMRT = nil
slash("check")
check("check utan block", said("hittar inget ulaStart-block"), true)
VMRT = { Note = { Text1 = "ulaStart\ntid 3:28 3:54\nNucce H2/H3 Keta H1\nulaEnd" } }
inRaid = false
roster = { player = "Nucce" }

-- ===== Strid, ren pull-klocka, ljud ======================================
sounds = {}
DB.sound = true -- ljudtesterna kör med ljudet på
fire("ENCOUNTER_START", 3492, "Ula'tek", 15, 20)
check("heroic ignoreras", ticker, nil)
slash("dev")
check("dev-läge slås på", DB.dev, true)
fire("ENCOUNTER_START", 3492, "Ula'tek", 15, 20)
check("dev-läge: heroic startar", ticker ~= nil, true)
check("dev-läge: varnar i chatten", said("utvecklarläge|r: kör på svårighetsgrad 15"), true)
fire("ENCOUNTER_END", 3492, "Ula'tek", 15, 20, 0)
fire("ENCOUNTER_START", 3493, "Annan boss", 15, 20)
check("dev-läge: annan boss ignoreras", ticker.cancelled, true)
fire("ADDON_LOADED", "UlatekEggs")
check("dev-läge: påminnelse vid inloggning", said("UTVECKLARLÄGE|r: addonet triggar"), true)
slash("status")
check("dev-läge: syns i status", said("UTVECKLARLÄGE|r (alla svårighetsgrader"), true)
slash("dev off")
check("dev-läge av", DB.dev, nil)
fire("ENCOUNTER_START", 3492, "Ula'tek", 15, 20)
check("utan dev-läge: heroic ignoreras igen", ticker.cancelled, true)
ticker = nil
fire("ENCOUNTER_START", 3492, "Ula'tek", 16, 20)
check("mythic startar ticker", ticker ~= nil, true)
now = 1000 + 207; tick(); check("före fönster 1", f:IsShown(), false)
check("inget ljud före fönster", #sounds, 0)
now = 1000 + 208; tick(); check("fönster 1 öppnar", f:IsShown(), true)
check("fönster 1 = område 1", f.map.coords[3], 0)
check("strid: ingen text på kartan", f.title.text, "")
check("fönster 1 prick 2 grön", f.dots[2].tex.green, true)
check("ljud vid öppning", #sounds, 1)
check("ljud på Master", sounds[1].ch, "Master")
now = 1000 + 220; tick(); check("inget nytt ljud medan fönstret är öppet", #sounds, 1)
now = 1000 + 233; tick(); check("fönster 1 fortfarande öppet vid 3:53", f.map.coords[3], 0)
now = 1000 + 234; tick(); check("fönster 2 öppnar", f:IsShown(), true)
check("fönster 2 = område 2 (tar över trots att 1 överlappar)", f.map.coords[3], 0.64)
check("ljud igen vid fönster 2", #sounds, 2)
now = 1000 + 263; tick(); check("fönster 2 öppet i 30 s", f:IsShown(), true)
now = 1000 + 264; tick(); check("fönster 2 stänger", f:IsShown(), false)
fire("ENCOUNTER_END", 3492, "Ula'tek", 16, 20, 0)
check("slut döljer", f:IsShown(), false)
check("slut stoppar ticker", ticker.cancelled, true)

-- ===== Överlapp: senare fönster vinner ====================================
VMRT = { Note = { Text1 = "ulaStart tid 3:28 3:40 Nucce H2/H3 ulaEnd" } }
now = 1200
fire("ENCOUNTER_START", 3492, "Ula'tek", 16, 20)
now = 1200 + 215; tick(); check("överlapp: område 1 först", f.map.coords[3], 0)
now = 1200 + 221; tick(); check("överlapp: område 2 tar över vid 3:40", f.map.coords[3], 0.64)
now = 1200 + 249; tick(); check("överlapp: område 2 kvar till 4:10", f:IsShown(), true)
now = 1200 + 250; tick(); check("överlapp: stängt efter 4:10", f:IsShown(), false)
fire("ENCOUNTER_END", 3492, "Ula'tek", 16, 20, 0)
VMRT = { Note = { Text1 = "ulaStart\ntid 3:28 3:54\nNucce H2/H3 Keta H1\nulaEnd" } }

-- ===== Ljud av ===========================================================
DB.sound = false
sounds = {}
now = 1300
fire("ENCOUNTER_START", 3492, "Ula'tek", 16, 20)
now = 1300 + 210; tick(); check("ljud av: kartan visas ändå", f:IsShown(), true)
check("ljud av: inget ljud", #sounds, 0)
fire("ENCOUNTER_END", 3492, "Ula'tek", 16, 20, 0)
DB.sound = true

-- ===== Bara den med ägg i området ser kartan ==============================
VMRT = { Note = { Text1 = "ulaStart Nucce H2 ulaEnd" } }
now = 1500
fire("ENCOUNTER_START", 3492, "Ula'tek", 16, 20)
now = 1500 + 210; tick(); check("ägg i område 1: fönster 1 visas", f:IsShown(), true)
now = 1500 + 240; tick(); check("inget ägg i område 2: fönster 2 döljs", f:IsShown(), false)
fire("ENCOUNTER_END", 3492, "Ula'tek", 16, 20, 0)
VMRT = { Note = { Text1 = "ulaStart Nucce H/3 ulaEnd" } }
now = 1800
fire("ENCOUNTER_START", 3492, "Ula'tek", 16, 20)
now = 1800 + 210; tick(); check("bara område 2: fönster 1 döljs", f:IsShown(), false)
now = 1800 + 240; tick(); check("bara område 2: fönster 2 visas", f:IsShown(), true)
check("bara område 2: ägg 3 grönt", f.dots[3].tex.green, true)
fire("ENCOUNTER_END", 3492, "Ula'tek", 16, 20, 0)
VMRT = { Note = { Text1 = "ulaStart Nucce V ulaEnd" } }
slash("status")
check("bara sida i statusen", said("Ditt ägg: inget|r – noten ger dig bara sida (vänster)"), true)
now = 2100
sounds = {}
fire("ENCOUNTER_START", 3492, "Ula'tek", 16, 20)
check("bara sida: ingen varning om saknad tilldelning", said("ingen tilldelning hittad"), false)
now = 2100 + 210; tick(); check("bara sida: aldrig karta (1)", f:IsShown(), false)
now = 2100 + 240; tick(); check("bara sida: aldrig karta (2)", f:IsShown(), false)
check("bara sida: inget ljud", #sounds, 0)
slash("preview V1")
check("preview visar ändå", f:IsShown(), true)
slash("hide")
fire("ENCOUNTER_END", 3492, "Ula'tek", 16, 20, 0)
VMRT = { Note = { Text1 = "ulaStart\ntid 3:28 3:54\nNucce H2/H3 Keta H1\nulaEnd" } }

-- ===== Provkörning ========================================================
now = 3000
clearOutput()
slash("test")
check("test berättar", said("provkörning: höger 2/3 (MRT-not), kartan 3:28 och 3:54 (30 s, noten) – övre hörnet visas om 3 s"), true)
now = 3000 + 2; tick(); check("test: stängt före ledtiden", f:IsShown(), false)
now = 3000 + 3; tick(); check("test: fönster 1 öppnar efter 3 s", f:IsShown(), true)
check("test: område 1", f.map.coords[3], 0)
check("test: berättar övre hörnet", said("provkörning: övre hörnet – ditt ägg 2 (grön prick)"), true)
local nOut = #output
now = 3000 + 4; tick()
check("test: berättar bara en gång per hörn", #output, nOut)
now = 3000 + 3 + 26; tick(); check("test: fönster 2", f.map.coords[3], 0.64)
check("test: berättar nedre hörnet", said("provkörning: nedre hörnet – ditt ägg 3 (grön prick)"), true)
now = 3000 + 3 + 56; tick(); check("test: stängt efter fönster 2", f:IsShown(), false)
now = 3000 + 3 + 58; tick()
check("test: avslutar sig självt", said("provkörning klar"), true)
check("test: ticker stoppad", ticker.cancelled, true)
VMRT = { Note = { Text1 = "ulaStart\ntid 3:28 3:54\nNucce H2 Keta H1\nulaEnd" } }
now = 3100
slash("test")
now = 3100 + 3; tick(); check("test igen fungerar", f:IsShown(), true)
now = 3100 + 3 + 26; tick()
check("test: hörn utan ägg berättas", said("provkörning: nedre hörnet – inget ägg här, kartan visas inte"), true)
VMRT = { Note = { Text1 = "ulaStart\ntid 3:28 3:54\nNucce H2/H3 Keta H1\nulaEnd" } }
slash("hide")
check("hide avbryter provkörningen", ticker.cancelled, true)
check("hide döljer", f:IsShown(), false)
hiddenBefore = panelHidden
slash("test")
check("test gömmer panelen", panelHidden, hiddenBefore + 1)
slash("edit H")
check("edit avbryter provkörningen", ticker.cancelled, true)
check("edit efter provkörning: redigeringsläge", f:GetWidth(), EDIT_W)
slash("done")
now = 3200
fire("ENCOUNTER_START", 3492, "Ula'tek", 16, 20)
slash("test")
check("test vägras under riktig strid", said("en riktig strid pågår"), true)
slash("edit H")
check("edit vägras under riktig strid", said("strid pågår"), true)
check("edit under strid: ingen redigeringsram", f.mouse == true and f.shown, false)
slash("unlock")
check("unlock vägras under riktig strid", f.mouse ~= true, true)
clearOutput()
now = 3200 + 300; tick()
check("riktig strid självdör efter sista fönstret", ticker.cancelled, true)
check("riktig strid: ingen provkörningstext", said("provkörning klar"), false)
slash("test")
check("efter självdöd strid går test igen", said("provkörning: "), true)
slash("hide")

-- ===== Äggnummer utanför layouten ========================================
VMRT = { Note = { Text1 = "ulaStart Nucce V6/V12 Keta H13 ulaEnd" } }
slash("reset") -- inbyggd layout: 12 höger, 11 vänster
clearOutput()
slash("test")
check("test varnar för ägg som inte finns", said("ägg V12 finns inte – vänster har 11 ägg"), true)
slash("status")
check("fel nummer i statusen", said("Ditt ägg: V12 finns inte, vänster har 11 ägg"), true)
panel.scripts.OnShow(panel)
check("panel: Återställ synlig med egen layout", buttons["Återställ inbyggda positioner"].shown, DB.eggs ~= nil)
panel.scripts.OnHide(panel)
slash("hide")
clearOutput()
slash("check")
check("check flaggar fel äggnummer", said("Keta"), true)
slash("import UTE1;H=0.800,0.100 0.750,0.150 0.700,0.900;V=0.300,0.100;END")
VMRT = { Note = { Text1 = "ulaStart\ntid 3:28 3:54\nNucce H2/H3 Keta H1\nulaEnd" } }

-- ===== Redigeringsläge: tillståndsövergångar ==============================
slash("scale 1.5")
check("scale sparas", DB.scale, 1.5)
slash("scale 0")
check("scale 0 avvisas", DB.scale, 1.5)
DB.point = { "TOPLEFT", 10, -10 }
slash("edit H") -- argumentet ignoreras numera
check("edit: 75 % av skärmen", f:GetWidth(), EDIT_W)
check("edit: centrerad", f.point, "CENTER")
check("edit: X-knapp synlig", f.close.shown, true)
check("edit: X-knapp har mall", f.close.template, "UIPanelCloseButton")
check("edit: ryms på skärmen", f:GetHeight() <= 768, true)
check("edit: prickar växer med kartan", f.dots[1].tex.width, math.max(18, math.floor(EDIT_W / 60)))
check("edit: nummer visas", f.dots[1].label.shown, true)
-- egen layout just nu: 3 H + 1 V -> fyra prickar, V först
check("edit: båda sidor ritas (1 V + 3 H)", f.dots[4].tex.shown and (f.dots[5] == nil or not f.dots[5].tex.shown), true)
check("edit: etikett med sida", f.dots[1].label.text, "V1")
check("edit: H-etikett efter V", f.dots[2].label.text, "H1")
check("edit: siffror växer med prickarna", f.dots[1].label.fontSize, math.floor(math.max(18, math.floor(EDIT_W / 60)) * 0.7))
check("edit: skala 1", f:GetScale(), 1)
slash("unlock")
check("unlock vägras under edit", said("avsluta redigeringen först"), true)
panel.scripts.OnShow(panel)
check("panel under edit låser inte upp", f.mouse and f:GetWidth(), EDIT_W)
panel.scripts.OnHide(panel)
slash("preview V1")
check("preview avslutar edit", f:GetWidth(), 170)
slash("edit")
slash("reset")
check("reset under edit: inbyggd layout kopieras", DB.eggs ~= nil and #DB.eggs.H, 12)
check("reset under edit: fortsätter redigera", f:GetWidth(), EDIT_W)
local ok = pcall(f.scripts.OnMouseDown, f, "LeftButton")
check("klick efter reset kraschar inte", ok, true)
check("klick i vänster halva ger V-prick", #DB.eggs.V, 12)
check("klick i vänster halva rör inte H", #DB.eggs.H, 12)
check("ny prick hamnar där man klickade", DB.eggs.V[12][1] == 0 and DB.eggs.V[12][2] == 1, true)
f.scripts.OnUpdate(f)
check("drag håller V-pricken på vänster halva", DB.eggs.V[12][1] <= 0.5, true)
f.scripts.OnMouseUp(f)
GetCursorPosition = function() return f:GetWidth() * 0.8, f:GetHeight() * 0.5 end
f.scripts.OnMouseDown(f, "LeftButton")
check("klick i höger halva ger H-prick", #DB.eggs.H, 13)
check("H-prick på rätt plats", math.abs(DB.eggs.H[13][1] - 0.8) < 0.01 and math.abs(DB.eggs.H[13][2] - 0.5) < 0.01, true)
f.scripts.OnMouseUp(f)
f.scripts.OnMouseDown(f, "RightButton")
check("högerklick på pricken tar bort den", #DB.eggs.H, 12)
GetCursorPosition = function() return 0, 0 end
f.scripts.OnMouseDown(f, "RightButton")
check("högerklick tar bort V-pricken", #DB.eggs.V, 11)
f.close.scripts.OnClick(f.close)
check("X-knappen avslutar redigeringen", f:IsShown() or f.mouse, false)
check("X-knappen gömmer sig själv", f.close.shown, false)
check("efter redigering: tillbaka till sparat läge", f.point, "TOPLEFT")
DB.point = { "CENTER", 0, 150 }
slash("edit")
slash("lock")
check("lock avslutar edit", f:IsShown(), false)
check("lock återställer skala", f:GetScale(), 1.5)
slash("preview H1")
check("efter lock: normal bredd", f:GetWidth(), 170)
slash("unlock")
check("unlock visar kartan", f:IsShown(), true)
check("unlock aktiverar musen", f.mouse, true)
slash("edit")
check("edit under unlock låser först", f.mouse, true)
slash("done")
check("done efter edit: mus av", f.mouse, false)
slash("scale 1")
slash("import UTE1;H=0.800,0.100 0.750,0.150 0.700,0.900;V=0.300,0.100;END")

-- ===== Lokala tider =======================================================
slash("tid 3:30 3:50")
check("tid sätter start 1", DB.starts[1], 210)
check("tid sätter start 2", DB.starts[2], 230)
check("tid utan längd rör inte längden", DB.duration, 30)
slash("tid 3:30 3:50 20")
check("tid med längd", DB.duration, 20)
slash("tid 3:30")
check("ofullständig tid avvisas", said("ex: /ute tid 3:28 3:54"), true)
slash("tid 3.28 3.54")
check("punkt som avgränsare", DB.starts[1] == 208 and DB.starts[2] == 234, true)
VMRT = { Note = { Text1 = "ulaStart tid 3.30 3.55 Nucce H2 ulaEnd" } }
slash("status")
check("punkt i noten", said("3:30 och 3:55 efter pull"), true)
VMRT = { Note = { Text1 = "ulaStart\ntid 3:28 3:54\nNucce H2/H3 Keta H1\nulaEnd" } }
DB.starts, DB.duration = { 208, 234 }, 30

-- ===== Export-roundtrip ===================================================
slash("export")
local exported = frames[#frames].text
check("exportruta är EditBox", frames[#frames].kind, "EditBox")
check("exportformat", exported:sub(1, 7), "UTE1;H=")
slash("reset")
check("reset", DB.eggs, nil)
slash("import " .. exported)
check("roundtrip H", #DB.eggs.H, 3)
check("roundtrip värde", DB.eggs.H[2][1], 0.75)
check("export slutar med END", exported:sub(-4), ";END")
slash("import " .. exported:sub(1, -5))
check("avklippt sträng avvisas", said("ogiltig sträng"), true)
check("avklippt sträng rör inte layouten", #DB.eggs.H, 3)
slash("import UTE1;H=0.5.1,0.3;V=;END")
check("trasigt tal avvisas", #DB.eggs.H, 3)
slash("import")
local box = frames[#frames]
check("import utan argument öppnar ruta", box.shown and box.text == "", true)
box.text = "UTE1;H=0.100,0.100;V=;END"
box.scripts.OnEnterPressed(box)
check("Enter i rutan importerar", #DB.eggs.H, 1)

realPrint(("%d kontroller, %d fel"):format(checks, failures))
if failures > 0 then error("test misslyckades") end
