-- UlatekEggs av Tjocksmock, For Science.
-- Visar i fas 2 på Ula'tek (Mythic) en kartbit över din sida
-- med äggen som röda prickar och DITT ägg som grön prick. Två fönster på
-- 30 s: område 1 (övre hörnet) och område 2 (nedre hörnet).
--
-- Allt styrs från raidnoten (Northern Sky-reminder, delad eller personlig,
-- annars MRT-noten) i ett block mellan ulaStart och ulaEnd:
--   ulaStart
--   tid 3:28 3:54
--   Veraizh V1 Tjocksmock V2/V9 Cyrkdragon V3/V10 ... Bizer V
--   ulaEnd
-- tid = när fönster 1 och 2 öppnar (från pull, "3:28" eller "3.28"), valfritt
-- tredje tal = längd i sekunder. H/V = höger/vänster (R/L går också), siffran = äggets nummer på
-- sidan, "/9" = ägget i område 2. Kartan visas i strid BARA för den som har
-- ett ägg i det aktuella området; bara sida ("Bizer V") eller ingen rad ger
-- aldrig någon karta. Utan not: /ute set H3/H9 och /ute tid 3:28 3:54.
--
-- /ute öppnar inställningspanelen (ljud, tider från noten, skala, provkörning,
-- rosterkontroll, flytta, redigera). /ute test låtsaspullar så alla kan se
-- sitt ägg före pull. /ute check jämför noten med raidrostern.
--
-- Äggens positioner: /ute edit visar hela kartan; klick på vänster halva ger
-- en V-prick, på höger halva en H-prick (dra = flytta, högerklick = ta bort).
-- /ute export ger en sträng att dela/baka in.
-- Tiderna räknas från pull (ENCOUNTER_START); fas 2 går på fast timer.

local ADDON = ...
local VERSION = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
local ENCOUNTER_ID, MYTHIC = 3492, 16
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local ASPECT = 2000 / 1125 -- originalkartans proportion (map.png är omskalad till 2048x1024)
local DOT = 18 -- minsta prickstorlek; växer med kartbredden (bredd/60)
local WIDTH = 170 -- stridskartans bredd i px (skalas med skalan)
local EDIT_FRACTION = 0.75 -- redigeringskartans andel av skärmen
local TEST_LEAD = 3 -- /ute test: sekunder tills fönster 1 öppnar

-- Beskärning av kartan per sida+område: {vänster, höger, topp, botten} i 0..1.
-- Smal, hög remsa längs den diagonala väggen: från hörnet (Big Egg) ned till
-- porten i mitten, så man ser var i korridoren ägget ligger.
local CROPS = {
	H1 = { 0.65, 0.81, 0, 0.36 }, H2 = { 0.65, 0.81, 0.64, 1 },
	V1 = { 0.19, 0.35, 0, 0.36 }, V2 = { 0.19, 0.35, 0.64, 1 },
	FULL = { 0, 1, 0, 1 },
}
local SIDE_NAME = { H = "höger", V = "vänster" }
local AREA_NAME = { "övre hörnet", "nedre hörnet" } -- område 1 och 2
local SOURCE_TEXT = { ["NS-not"] = "från Northern Sky-noten", ["NS-not (personlig)"] = "från din personliga Northern Sky-not",
	["MRT-not"] = "från MRT-noten", manuellt = "inställt med /ute set" }

-- Inbyggd ägg-layout per sida ({x, y} i 0..1 av hela kartan). Numreringen är
-- ordningen här = upplockningsordningen utifrån och in: område 1 (övre
-- hörnet) 1..8/9 där sista är Big Egg i hörnet, sedan område 2 (nedre hörnet)
-- med Big Egg sist. Placerad in-game av maz 2026-10-07 (/ute export).
local EGGS = {
	H = { { 0.767, 0.171 }, { 0.753, 0.145 }, { 0.717, 0.133 }, { 0.725, 0.100 }, { 0.695, 0.126 }, { 0.703, 0.096 }, { 0.682, 0.100 }, { 0.686, 0.070 }, { 0.669, 0.030 }, { 0.691, 0.902 }, { 0.709, 0.921 }, { 0.671, 0.972 } },
	V = { { 0.225, 0.175 }, { 0.283, 0.132 }, { 0.278, 0.102 }, { 0.300, 0.133 }, { 0.296, 0.098 }, { 0.317, 0.096 }, { 0.295, 0.055 }, { 0.327, 0.031 }, { 0.306, 0.897 }, { 0.290, 0.917 }, { 0.337, 0.977 } },
}

local DEFAULTS = {
	starts = { 208, 234 }, -- fönster 1 och 2 öppnar (sek från pull): 3:28, 3:54
	duration = 30,         -- fönsterlängd i sekunder
	sound = false,         -- ljud när kartan dyker upp (opt-in)
	noteTimes = true,      -- tid-raden i noten går före de lokala tiderna
	noteChat = false,      -- skriv ditt ägg i chatten när noten kommer (NS skickar om vid ready check/pulltimer, därför av)
	scale = 1, point = { "CENTER", 0, 150 },
}

local DB
local pullAt, ticker, testing, fightTimes, lastArea, lastWindow
local editing, dragging -- dragging = { side, index }
local panelOpen, previewLine -- inställningspanelen är öppen; dess "Visar:"-rad

------------------------------------------------------------
-- Hjälpare
------------------------------------------------------------
local function say(msg, ...)
	print("|cff80ff80UlatekEggs|r " .. msg:format(...))
end

local function mmss(s)
	return ("%d:%02d"):format(math.floor(s / 60), math.floor(s % 60))
end

local function parseTime(str) -- "3:28" eller "3.28" (eller rena sekunder)
	local m, s = tostring(str):match("^(%d+)[:.](%d%d?)$")
	if m then return m * 60 + s end
	return tonumber(str)
end

local function eggsFor(side)
	return DB.eggs and DB.eggs[side] or EGGS[side]
end

-- nil om äggnumren finns i sidans layout, annars det felaktiga numret och antalet ägg
local function badEgg(side, a, b)
	local n = #eggsFor(side)
	for _, x in ipairs({ a, b }) do
		if x < 1 or x > n then return x, n end
	end
end

-- "H3/H9" -> "H", 3, 9 (R/L accepteras, siffror får utelämnas: "H", "H3", "H/9").
-- Vanliga ord som "right"/"Veraiz" ska INTE tolkas som sida.
local function parseToken(tok)
	tok = tok:upper():gsub("R", "H"):gsub("L", "V")
	local side, a, b = tok:match("^([HV])(%d*)/?[HV]?(%d*)%p*$")
	if not side then return end
	return side, tonumber(a), tonumber(b)
end

local function stripCodes(s)
	return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function shortName(name)
	return (name:gsub("%-.*$", ""))
end

------------------------------------------------------------
-- Noten
------------------------------------------------------------
-- Notkällor i prioritetsordning: Northern Sky delad, Northern Sky personlig, MRT.
local function noteSources()
	local personal, shared
	if NSAPI and NSAPI.GetReminderString then personal, shared = NSAPI:GetReminderString(ENCOUNTER_ID) end
	return {
		{ "NS-not", shared }, { "NS-not (personlig)", personal },
		{ "MRT-not", VMRT and VMRT.Note and VMRT.Note.Text1 },
	}
end

-- Blocket mellan ulaStart och ulaEnd -> { starts = {s1, s2}, duration = n,
-- assign = { [namn i gemener] = { side, a, b, name = Namn } } } eller nil.
local function parseBlock(note)
	local clean = stripCodes(note)
	local low = clean:lower()
	local _, e1 = low:find("ulastart", 1, true)
	if not e1 then return end
	local s2 = low:find("ulaend", e1 + 1, true)
	local body = clean:sub(e1 + 1, s2 and s2 - 1 or nil)
	local block = { assign = {} }
	local words = {}
	for w in body:gmatch("%S+") do words[#words + 1] = w end
	local i = 1
	while i <= #words do
		local w = words[i]
		if w:lower() == "tid" then
			local a, b, d = parseTime(words[i + 1] or ""), parseTime(words[i + 2] or ""), tonumber(words[i + 3] or "")
			if a and b then
				block.starts, block.duration = { a, b }, d
				i = i + (d and 4 or 3)
			else
				i = i + 1
			end
		else
			local side, a, b
			if words[i + 1] then side, a, b = parseToken(words[i + 1]) end
			if side then
				block.assign[shortName(w):lower()] = { side, a, b, name = shortName(w) }
				i = i + 2
			else
				i = i + 1
			end
		end
	end
	return block
end

-- Första notkällan som har ett block
local function noteBlock()
	for _, src in ipairs(noteSources()) do
		if type(src[2]) == "string" then
			local block = parseBlock(src[2])
			if block then return block, src[1] end
		end
	end
end

local function assignment()
	local block, source = noteBlock()
	local me = block and block.assign[UnitName("player"):lower()]
	if me then return me[1], me[2], me[3], source end
	if DB.assign then
		local side, a, b = parseToken(DB.assign)
		if side then return side, a, b, "manuellt" end
	end
end

-- Fönstrens starttider och längd: noten om tillåtet och den har en tid-rad, annars lokalt
local function windowTimes()
	if DB.noteTimes then
		local block = noteBlock()
		if block and block.starts then return block.starts, block.duration or DB.duration, "noten" end
	end
	return DB.starts, DB.duration, "lokalt"
end

------------------------------------------------------------
-- Layoutsträng
------------------------------------------------------------
local function serialize()
	local parts = {}
	for _, side in ipairs({ "H", "V" }) do
		local t = {}
		for i, e in ipairs(eggsFor(side)) do t[i] = ("%.3f,%.3f"):format(e[1], e[2]) end
		parts[#parts + 1] = side .. "=" .. table.concat(t, " ")
	end
	return "UTE1;" .. table.concat(parts, ";") .. ";END" -- END avslöjar avklippta strängar
end

local function deserialize(str)
	local h, v = str:match("^%s*UTE1;H=([^;]*);V=([^;]*);END%s*$")
	if not h then return end
	local out = { H = {}, V = {} }
	for side, s in pairs({ H = h, V = v }) do
		for pair in s:gmatch("%S+") do
			local x, y = pair:match("^([%d%.]+),([%d%.]+)$")
			x, y = tonumber(x), tonumber(y)
			if not (x and y) then return end -- hellre avvisa allt än omnumrera äggen
			out[side][#out[side] + 1] = { x, y }
		end
	end
	return out
end

------------------------------------------------------------
-- Kartramen
------------------------------------------------------------
local f = CreateFrame("Frame", "UlatekEggsFrame", UIParent)
f:SetFrameStrata("HIGH")
f:SetClampedToScreen(true)
f:Hide()
f.map = f:CreateTexture(nil, "BACKGROUND")
f.map:SetAllPoints()
f.map:SetTexture(MEDIA .. "map.png")
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.title:SetPoint("TOPLEFT", 4, -4)
f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton") -- bara i redigeringsläget
f.close:SetPoint("TOPRIGHT", 2, 2)
f.close:SetScript("OnClick", function() SlashCmdList.ULATEKEGGS("done") end)
f.close:Hide()
f.dots = {}
f.dot = DOT
local LABEL_FONT = GameFontHighlightSmall:GetFont()

local function newDot(i)
	local tex = f:CreateTexture(nil, "ARTWORK")
	tex:SetTexture(MEDIA .. "dot.png")
	local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("CENTER", tex)
	f.dots[i] = { tex = tex, label = label }
	return f.dots[i]
end

-- Kartkoordinat (0..1) -> pixel i ramen, för aktuell beskärning
local function toPixel(x, y)
	local c = CROPS[f.cropKey]
	return (x - c[1]) / (c[2] - c[1]) * f:GetWidth(), (y - c[3]) / (c[4] - c[3]) * f:GetHeight()
end

local function cursorToMap()
	local cx, cy = GetCursorPosition()
	local s = f:GetEffectiveScale()
	local fx = (cx / s - f:GetLeft()) / f:GetWidth()
	local fy = (f:GetTop() - cy / s) / f:GetHeight()
	local c = CROPS[f.cropKey]
	return c[1] + fx * (c[2] - c[1]), c[3] + fy * (c[4] - c[3])
end

-- Ramstorlek och beskärning; returnerar prickstorleken
local function sizeFrame(cropKey, title)
	local c = CROPS[cropKey]
	f.cropKey = cropKey
	f.map:SetTexCoord(c[1], c[2], c[3], c[4])
	-- redigering: hela kartan i 16:9, EDIT_FRACTION av skärmen
	local w = editing and math.floor(math.min(UIParent:GetWidth(), UIParent:GetHeight() * ASPECT) * EDIT_FRACTION) or WIDTH
	f:SetSize(w, w / ASPECT * (c[4] - c[3]) / (c[2] - c[1]))
	f.title:SetText(title or "") -- bara redigeringsläget har text på kartan
	f.dot = math.max(DOT, math.floor(w / 60))
	return f.dot
end

-- items: { { x, y, label = "H3", mine = bool }, ... }; etiketter bara i redigering
local function drawDots(items, dot)
	for i, it in ipairs(items) do
		local d = f.dots[i] or newDot(i)
		d.tex:SetSize(dot, dot)
		d.label:SetFont(LABEL_FONT, math.max(10, math.floor(dot * 0.7)), "OUTLINE")
		d.label:SetText(it.label)
		local px, py = toPixel(it[1], it[2])
		local inside = px >= 0 and px <= f:GetWidth() and py >= 0 and py <= f:GetHeight()
		d.tex:ClearAllPoints()
		d.tex:SetPoint("CENTER", f, "TOPLEFT", px, -py)
		d.tex:SetVertexColor(it.mine and 0.2 or 1, it.mine and 1 or 0.15, 0.15)
		d.tex:SetShown(inside)
		d.label:SetShown(inside and editing == true)
	end
	for i = #items + 1, #f.dots do
		f.dots[i].tex:Hide()
		f.dots[i].label:Hide()
	end
	f:Show()
end

local function layout(side, cropKey, mine)
	local dot = sizeFrame(cropKey)
	local items = {}
	for i, egg in ipairs(eggsFor(side)) do
		items[i] = { egg[1], egg[2], label = i, mine = i == mine }
	end
	drawDots(items, dot)
end

-- forceSide: förhandsvisning av en viss sida (annars tilldelningens sida)
local function showArea(area, forceSide)
	local side, a, b, source = assignment()
	local shown = forceSide or side
	local mine = side == shown and ({ a, b })[area] or nil
	if not shown or (not forceSide and not mine) then return f:Hide() end
	local what = not side and "ingen tilldelning (raidnot eller /ute set)"
		or side ~= shown and ("din sida är " .. SIDE_NAME[side])
		or ("%s (%s)"):format(mine and ("ditt ägg: " .. mine) or "inget ägg här", source)
	layout(shown, shown .. area, mine)
	if forceSide then
		local msg = ("%s, %s: %s"):format(SIDE_NAME[shown], AREA_NAME[area], what)
		if previewLine then previewLine:SetText("Visar " .. msg) end
		if not panelOpen then say("%s", msg) end -- preview från chatten berättar i chatten
	end
end

------------------------------------------------------------
-- Redigeringsläge
------------------------------------------------------------
-- Hela kartan: V-prickar hör till vänster halva, H-prickar till höger
local function sideAt(x)
	return x < 0.5 and "V" or "H"
end

local function nearestEgg(mx, my)
	local px, py = toPixel(mx, my)
	for _, side in ipairs({ "V", "H" }) do
		for i, e in ipairs(DB.eggs[side]) do
			local ex, ey = toPixel(e[1], e[2])
			if (ex - px) ^ 2 + (ey - py) ^ 2 <= f.dot ^ 2 then return side, i end
		end
	end
end

local function editLayout()
	local dot = sizeFrame("FULL", "REDIGERAR: klick = ny prick (vänster halva = V, höger = H), dra = flytta, högerklick = ta bort, /ute done")
	local items = {}
	for _, side in ipairs({ "V", "H" }) do
		for i, egg in ipairs(DB.eggs[side]) do
			items[#items + 1] = { egg[1], egg[2], label = side .. i }
		end
	end
	drawDots(items, dot)
end

local function startEdit()
	DB.eggs = DB.eggs or CopyTable(EGGS)
	editing = true
	f:EnableMouse(true)
	f:RegisterForDrag()
	f:SetScale(1) -- redigeringsramen ska få plats på skärmen oavsett skala
	f:ClearAllPoints()
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- alltid mitt på skärmen
	f.close:Show()
	editLayout()
end

local function stopEdit()
	editing, dragging = nil, nil
	f:EnableMouse(false)
	f:SetScale(DB.scale)
	f.close:Hide()
	f:ClearAllPoints()
	f:SetPoint(DB.point[1], UIParent, DB.point[1], DB.point[2], DB.point[3]) -- tillbaka till stridsläget
	f:Hide()
end

f:SetScript("OnMouseDown", function(_, button)
	if not editing then return end
	local mx, my = cursorToMap()
	local side, hit = nearestEgg(mx, my)
	if button == "RightButton" then
		if hit then table.remove(DB.eggs[side], hit) end
	elseif hit then
		dragging = { side, hit }
	else
		side = sideAt(mx)
		local eggs = DB.eggs[side]
		eggs[#eggs + 1] = { mx, my }
		dragging = { side, #eggs }
	end
	editLayout()
end)
f:SetScript("OnMouseUp", function() dragging = nil end)
f:SetScript("OnUpdate", function()
	if not dragging then return end
	local mx, my = cursorToMap()
	local side = dragging[1]
	local egg = DB.eggs[side][dragging[2]]
	-- pricken stannar på sin halva
	local lo, hi = side == "V" and 0 or 0.5, side == "V" and 0.5 or 1
	egg[1], egg[2] = math.max(lo, math.min(hi, mx)), math.max(0, math.min(1, my))
	editLayout()
end)
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function()
	f:StopMovingOrSizing()
	local point, _, _, x, y = f:GetPoint()
	DB.point = { point, x, y }
end)

local function applyPosition()
	f:ClearAllPoints()
	f:SetPoint(DB.point[1], UIParent, DB.point[1], DB.point[2], DB.point[3])
	f:SetScale(editing and 1 or DB.scale)
end

-- Upplåst = dragbar. Panelen låser upp när den öppnas och låser när den
-- stängs; kartan lyfts då till DIALOG-lagret så den syns ovanpå panelen.
local unlocked
local function setUnlocked(on, quiet)
	if on and editing then return end -- redigeringsläget har egen mus
	unlocked = on
	f:EnableMouse(on)
	f:SetMovable(on)
	f:SetFrameStrata(on and "DIALOG" or "HIGH")
	if on then
		f:RegisterForDrag("LeftButton")
		if not f:IsShown() then
			local side, a, b = assignment()
			showArea((not a and b) and 2 or 1, side or "H")
		end
		if not quiet then say("dra kartan, /ute lock när du är klar") end
	else
		f:RegisterForDrag()
		f:Hide()
	end
end

------------------------------------------------------------
-- Striden (och provkörningen)
------------------------------------------------------------
-- Senare fönster vinner om de överlappar
local function currentWindow(t)
	for i = #fightTimes.starts, 1, -1 do
		local s = fightTimes.starts[i]
		if t >= s and t < s + fightTimes.duration then return i end
	end
end

local function endFight()
	if ticker then ticker:Cancel() end
	ticker, pullAt, testing, lastArea, lastWindow = nil, nil, nil, nil, nil
	f:Hide()
end

local function tick()
	local t = GetTime() - pullAt
	local area = currentWindow(t)
	if area then
		showArea(area)
	else
		f:Hide()
	end
	local visible = f:IsShown() and area or nil
	if visible and visible ~= lastArea and DB.sound then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
	lastArea = visible
	if testing and area and area ~= lastWindow then -- provkörningen berättar per hörn
		local side, a, b = assignment()
		local mine = side and ({ a, b })[area]
		say(mine and "provkörning: %s – ditt ägg %d (grön prick)" or "provkörning: %s – inget ägg här, kartan visas inte", AREA_NAME[area], mine)
	end
	lastWindow = area
	-- inget mer att visa efter sista fönstret; i riktig strid kan ENCOUNTER_END
	-- utebli för den som lämnat instansen, så stäng själv
	local last = fightTimes.starts[#fightTimes.starts] + fightTimes.duration
	if t > last + 1 then
		local wasTest = testing
		endFight()
		if wasTest then say("provkörning klar") end
	end
end

-- edit/unlock kräver att ingen strid pågår; en provkörning avbryts
local function idle()
	if testing then endFight() end
	if pullAt then say("strid pågår") return false end
	return true
end

local function startFight(test)
	if test and pullAt and not testing then return say("en riktig strid pågår") end
	if editing then stopEdit() end
	if unlocked then setUnlocked(false) end
	local starts, duration, from = windowTimes()
	fightTimes = { starts = starts, duration = duration }
	testing = test or nil
	pullAt = test and (GetTime() - (starts[1] - TEST_LEAD)) or GetTime()
	lastArea = nil
	f:Hide()
	if ticker then ticker:Cancel() end
	ticker = C_Timer.NewTicker(0.25, tick)
	local side, a, b, source = assignment()
	if not side then
		say("ingen tilldelning hittad – skriv dig i ulaStart-blocket i raidnoten (Northern Sky/MRT) eller /ute set H3/H9")
	elseif test then
		say("provkörning: %s %s/%s (%s), kartan %s och %s (%d s, %s) – övre hörnet visas om %d s",
			SIDE_NAME[side], a or "-", b or "-", source, mmss(starts[1]), mmss(starts[2]), duration, from, TEST_LEAD)
	end
	local bad, n
	if side then bad, n = badEgg(side, a, b) end
	if bad then say("ägg %s%d finns inte – %s har %d ägg, kontrollera noten", side, bad, SIDE_NAME[side], n) end
end

------------------------------------------------------------
-- Rosterkontroll: vilka i raiden saknar rad, vilka i noten är inte här
------------------------------------------------------------
local function groupUnits()
	local units = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
	else
		units[1] = "player"
		if IsInGroup() then for i = 1, 4 do units[#units + 1] = "party" .. i end end
	end
	return units
end

local function checkRoster()
	local block, source = noteBlock()
	if not block then return say("hittar inget ulaStart-block i någon not") end
	local inGroup, missing, extra = {}, {}, {}
	for _, unit in ipairs(groupUnits()) do
		local name = UnitName(unit)
		if name then
			name = shortName(name)
			inGroup[name:lower()] = true
			if not block.assign[name:lower()] then missing[#missing + 1] = name end
		end
	end
	for key, entry in pairs(block.assign) do
		local bad, n = badEgg(entry[1], entry[2], entry[3])
		if not inGroup[key] then
			extra[#extra + 1] = entry.name
		elseif bad then
			extra[#extra + 1] = ("%s (ägg %s%d finns inte, max %d)"):format(entry.name, entry[1], bad, n)
		end
	end
	table.sort(missing)
	table.sort(extra)
	say("rosterkontroll mot %s: %d i noten, tider %s", source, (function() local n = 0 for _ in pairs(block.assign) do n = n + 1 end return n end)(),
		block.starts and (mmss(block.starts[1]) .. " + " .. mmss(block.starts[2])) or "saknas (lokala används)")
	say("saknar rad i noten: %s", #missing > 0 and table.concat(missing, ", ") or "ingen")
	say("i noten men inte i gruppen, eller fel äggnummer (felstavat?): %s", #extra > 0 and table.concat(extra, ", ") or "ingen")
end

------------------------------------------------------------
-- Händelser
------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("ENCOUNTER_START")
ev:RegisterEvent("ENCOUNTER_END")

local buildPanel, statusLines -- definieras nedan

-- Northern Sky: när en ny reminder tas emot, berätta direkt vad noten ger dig
local callbackOwner, lastReminderLine = {}, nil
local function onReminderChanged()
	if not DB.noteChat or not noteBlock() then return end -- valbart; bara noter med ulaStart-block
	local line = statusLines()[1]
	if line == lastReminderLine then return end -- NS skickar om samma not vid ready check och pulltimer
	lastReminderLine = line
	say("ny raidnot – %s", line)
end

ev:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= ADDON then return end
		UlatekEggsDB = UlatekEggsDB or {}
		DB = UlatekEggsDB
		DB.windows = nil -- gammalt format (från/till) ersatt av starts + duration
		for k, v in pairs(DEFAULTS) do
			if DB[k] == nil then DB[k] = type(v) == "table" and CopyTable(v) or v end
		end
		applyPosition()
		buildPanel()
		if NSAPI and NSAPI.RegisterCallback then NSAPI.RegisterCallback(callbackOwner, "NSRT_REMINDER_CHANGED", onReminderChanged) end
		if DB.eggs then say("egen ägg-layout aktiv (höger %d, vänster %d) – /ute reset ger den inbyggda", #DB.eggs.H, #DB.eggs.V) end
		if DB.dev then say("|cffff6060UTVECKLARLÄGE|r: addonet triggar på Ula'tek oavsett svårighetsgrad – /ute dev off när du är klar") end
	elseif event == "ENCOUNTER_START" then
		local id, _, difficulty = ...
		if id == ENCOUNTER_ID and (difficulty == MYTHIC or DB.dev) then
			if difficulty ~= MYTHIC then say("|cffff6060utvecklarläge|r: kör på svårighetsgrad %s (tiderna är Mythic-tider, justera med /ute tid vid behov)", tostring(difficulty)) end
			startFight(false)
		end
	elseif event == "ENCOUNTER_END" then
		if pullAt then endFight() end
	end
end)

------------------------------------------------------------
-- Textruta (export/import – chattrutan klipper vid 255 tecken)
------------------------------------------------------------
local function importEggs(str)
	local eggs = deserialize(str)
	if not eggs then return say("ogiltig sträng") end
	DB.eggs = eggs
	say("importerade höger %d, vänster %d ägg", #eggs.H, #eggs.V)
	if editing then editLayout() end
end

local textBox
local function showTextBox(text, onEnter)
	if not textBox then
		local box = CreateFrame("EditBox", nil, UIParent, "InputBoxTemplate")
		box:SetSize(600, 32)
		box:SetPoint("CENTER", 0, 250)
		box:SetFrameStrata("DIALOG")
		box:SetAutoFocus(true)
		box:SetScript("OnEscapePressed", box.Hide)
		box:SetScript("OnEnterPressed", function(b)
			if b.onEnter then b.onEnter(b:GetText()) end
			b:Hide()
		end)
		box:SetScript("OnEditFocusGained", box.HighlightText)
		textBox = box
	end
	textBox.onEnter = onEnter
	textBox:SetText(text)
	textBox:Show()
	textBox:HighlightText()
	say(onEnter and "klistra in strängen och tryck Enter (Esc avbryter)." or "Ctrl+C kopierar strängen (Esc stänger).")
end

------------------------------------------------------------
-- Status och inställningspanel
------------------------------------------------------------
-- Statusrader i klartext; [1] färgad efter läge (grön = ägg, gul = bara sida, röd = inget)
function statusLines()
	local side, a, b, source = assignment()
	local block = noteBlock()
	local egg
	if side and (a or b) then
		local bad, n = badEgg(side, a, b)
		egg = ("|cff80ff80Ditt ägg: %s, %s|r (%s)"):format(
			a and (SIDE_NAME[side] .. " " .. a .. " i övre hörnet") or "inget i övre hörnet",
			b and (SIDE_NAME[side] .. " " .. b .. " i nedre hörnet") or "inget i nedre hörnet", SOURCE_TEXT[source] or source)
		if bad then egg = ("|cffff6060Ditt ägg: %s%d finns inte, %s har %d ägg|r – kontrollera noten"):format(side, bad, SIDE_NAME[side], n) end
	elseif side then
		egg = ("|cffffd100Ditt ägg: inget|r – noten ger dig bara sida (%s), ingen karta visas i strid"):format(SIDE_NAME[side])
	elseif block then
		egg = "|cffff6060Ditt ägg: inget|r – du står inte i raidnotens ulaStart-block"
	else
		egg = "|cffff6060Ditt ägg: inget|r – ingen raidnot med ulaStart-block hittad (Northern Sky eller MRT)"
	end
	local starts, duration, from = windowTimes()
	local fromText = from == "noten" and "tider från raidnoten" or (block and block.starts) and "egna tider, notens tid-rad används inte" or "egna tider"
	return {
		egg,
		("Kartan visas %s och %s efter pull, %d s per hörn (%s)"):format(mmss(starts[1]), mmss(starts[2]), duration, fromText),
		("Äggpositioner: %s (höger %d, vänster %d)"):format(DB.eggs and "egna" or "inbyggda", #eggsFor("H"), #eggsFor("V")),
	}
end

local function status()
	say("v%s%s", VERSION, DB.dev and " – |cffff6060UTVECKLARLÄGE|r (alla svårighetsgrader, /ute dev off)" or "")
	for _, line in ipairs(statusLines()) do say("%s", line) end
	say("/ute = panel · test · check · preview H1|H2|V1|V2 · hide · set H3/H9 · tid 3:28 3:54 [30] · scale N · unlock · lock · edit · done · export · import · reset · status")
end

local category
function buildPanel()
	local p = CreateFrame("Frame")
	p:Hide() -- dold tills Options-ytan visar den, annars kan första OnShow utebli
	p.name = "UlatekEggs"
	local widgets = {}
	local refreshing = false
	local y = -16
	local function text(template, str, x, yy, width)
		local fs = p:CreateFontString(nil, "ARTWORK", template)
		fs:SetPoint("TOPLEFT", x, yy)
		fs:SetText(str)
		if width then fs:SetWidth(width) fs:SetJustifyH("LEFT") end
		return fs
	end
	local function header(str)
		y = y - 10
		text("GameFontNormal", str, 16, y)
		y = y - 22
	end
	local function checkbox(label, key)
		local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
		cb:SetSize(26, 26)
		cb:SetPoint("TOPLEFT", 12, y + 5)
		text("GameFontHighlight", label, 42, y - 3)
		cb:SetScript("OnClick", function(self) DB[key] = self:GetChecked() and true or false end)
		cb.Refresh = function(self) self:SetChecked(DB[key] and true or false) end
		widgets[#widgets + 1] = cb
		y = y - 28
	end
	local function slider(label, key, minV, maxV, steps, fmt, onChange)
		local lbl = text("GameFontHighlight", label, 16, y - 4)
		local sl = CreateFrame("Frame", nil, p, "MinimalSliderWithSteppersTemplate")
		sl:SetWidth(180)
		sl:SetPoint("LEFT", lbl, "LEFT", 300, 0)
		sl:Init(DB[key], minV, maxV, steps, {})
		local value = text("GameFontHighlight", fmt(DB[key]), 510, y - 4)
		sl:RegisterCallback("OnValueChanged", function(_, v)
			if refreshing then return end -- SetValue i Refresh klampar till reglagets gränser
			DB[key] = v
			value:SetText(fmt(v))
			if onChange then onChange() end
		end, p)
		sl.Refresh = function(self)
			self:SetValue(DB[key])
			value:SetText(fmt(DB[key]))
		end
		widgets[#widgets + 1] = sl
		y = y - 34
	end
	local function button(label, x, yy, width, onClick)
		local bt = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
		bt:SetSize(width, 24)
		bt:SetPoint("TOPLEFT", x, yy)
		bt:SetText(label)
		bt:SetScript("OnClick", onClick)
		return bt
	end
	local run = SlashCmdList.ULATEKEGGS

	-- Rubrik
	text("GameFontNormalLarge", "UlatekEggs", 16, y)
	text("GameFontHighlightSmall", ("v%s · av |cff80ff80Tjocksmock|r, |cffffd100For Science|r"):format(VERSION), 130, y - 4)
	y = y - 24
	text("GameFontHighlightSmall", "Visar var ditt ägg ligger i fas 2 på Ula'tek (Mythic). Kartan dyker upp av sig själv i strid när det är din tur.", 16, y, 600)
	y = y - 20

	-- Ditt ägg
	header("Ditt ägg")
	local devLine = text("GameFontHighlightSmall", "", 300, -16, 300) -- bara när utvecklarläget är på
	local eggLine = text("GameFontHighlight", "", 16, y, 600)
	y = y - 18
	local timeLine = text("GameFontHighlight", "", 16, y, 600)
	y = y - 18

	-- Förhandsvisning
	header("Förhandsvisning av stridskartan")
	text("GameFontHighlightSmall", "Kartan ovanpå panelen är en förhandsvisning av hur den ser ut i strid. Dra den dit den inte skymmer något – läget sparas. Den försvinner när panelen stängs.", 16, y, 600)
	y = y - 30
	for i, key in ipairs({ "V1", "V2", "H1", "H2" }) do
		local label = SIDE_NAME[key:sub(1, 1)]:gsub("^%l", string.upper) .. " " .. AREA_NAME[tonumber(key:sub(2))]:gsub(" hörnet", "")
		button(label, 16 + (i - 1) * 130, y, 120, function() run("preview " .. key) end)
	end
	y = y - 26
	previewLine = text("GameFontHighlightSmall", "", 16, y, 600)
	y = y - 20
	slider("Kartans storlek", "scale", 0.5, 2, 15, function(v) return ("%.1f"):format(v) end, applyPosition)
	checkbox("Ljud när kartan dyker upp", "sound")

	-- Före pull
	header("Före pull")
	button("Provkör som i strid", 16, y, 170, function() run("test") end)
	text("GameFontHighlightSmall", "stänger panelen och visar båda hörnen som i strid, ca 1 minut (/ute hide avbryter)", 196, y - 6, 400)
	y = y - 30
	button("Kontrollera noten mot raiden", 16, y, 200, function() run("check") end)
	text("GameFontHighlightSmall", "för raidledaren: svaret i chatten listar vem som saknar rad och vad som inte stämmer", 226, y - 6, 380)
	y = y - 30

	-- Avancerat
	header("Avancerat (behövs normalt inte)")
	checkbox("Använd tiderna i raidnoten (raden 'tid 3:28 3:54') när den finns", "noteTimes")
	checkbox("Skriv ditt ägg i chatten när en ny not kommer (bara när tilldelningen ändrats)", "noteChat")
	slider("Visningstid per hörn när noten inte anger någon", "duration", 10, 60, 10, function(v) return ("%d s"):format(v) end)
	button("Redigera äggens positioner…", 16, y, 200, function() run("edit") end)
	local resetBtn = button("Återställ inbyggda positioner", 226, y, 200, function() run("reset") end)
	y = y - 26
	local layoutLine = text("GameFontHighlightSmall", "", 16, y, 600)
	y = y - 24
	text("GameFontHighlightSmall", "Noten (Northern Sky eller MRT): ulaStart  tid 3:28 3:54  Tjocksmock H3/H9  Veraizh V1 …  ulaEnd. H/V = höger/vänster sida, första numret = ägget i övre hörnet, andra = i nedre. Positioner delas med /ute export och /ute import.", 16, y, 600)

	local function refresh()
		local lines = statusLines()
		eggLine:SetText(lines[1])
		devLine:SetText(DB.dev and "|cffff6060UTVECKLARLÄGE: triggar på alla svårighetsgrader (/ute dev off)|r" or "")
		timeLine:SetText(lines[2])
		resetBtn:SetShown(DB.eggs ~= nil)
		layoutLine:SetText(DB.eggs and (lines[3] .. " – redigeringen stänger panelen och öppnar hela kartan") or "Inbyggda äggpositioner används. Redigeringen stänger panelen och öppnar hela kartan.")
		refreshing = true
		for _, w in ipairs(widgets) do w:Refresh() end
		refreshing = false
	end
	p:SetScript("OnShow", function()
		panelOpen = true
		refresh()
		if not pullAt then setUnlocked(true, true) end -- dragbar förhandsvisning medan panelen är öppen
		if not f:IsShown() then previewLine:SetText("Förhandsvisningen är dold – tryck en hörnknapp") end
	end)
	p:SetScript("OnHide", function()
		panelOpen = nil
		if unlocked then setUnlocked(false) end -- läget är redan sparat av OnDragStop
	end)
	p.OnRefresh = refresh -- Settings anropar den vid varje visning
	category = Settings.RegisterCanvasLayoutCategory(p, p.name)
	Settings.RegisterAddOnCategory(category)
end

SLASH_ULATEKEGGS1, SLASH_ULATEKEGGS2 = "/ute", "/ulatek"
SlashCmdList.ULATEKEGGS = function(input)
	local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	-- provkörning och redigering ska ses utan panelen i vägen (preview och
	-- upplåst karta ligger i DIALOG-lagret ovanpå panelen och klarar sig)
	if (cmd == "test" or cmd == "edit") and SettingsPanel and HideUIPanel then
		HideUIPanel(SettingsPanel)
	end
	if cmd == "" then
		Settings.OpenToCategory(category:GetID())
	elseif cmd == "status" then
		status()
	elseif cmd == "dev" then -- odokumenterat: utvecklarläge för testruns på Heroic/Normal
		if rest == "on" then DB.dev = true elseif rest == "off" then DB.dev = nil else DB.dev = not DB.dev or nil end
		say("utvecklarläge %s", DB.dev and "|cffff6060PÅ|r – Ula'tek triggar oavsett svårighetsgrad" or "av – bara Mythic")
	elseif cmd == "test" then
		startFight(true)
	elseif cmd == "check" then
		checkRoster()
	elseif cmd == "preview" then
		local key = rest:upper():gsub("R", "H"):gsub("L", "V")
		local side, area = key:match("^([HV])([12]?)$")
		if not side then return say("ange H1, H2, V1 eller V2") end
		if testing then endFight() end
		if editing then stopEdit() end
		showArea(tonumber(area) or 1, side)
		if panelOpen and not pullAt and not unlocked then setUnlocked(true, true) end -- dragbar ovanpå panelen
	elseif cmd == "hide" or cmd == "done" or cmd == "lock" then
		if testing then endFight() end
		stopEdit()
		setUnlocked(false)
	elseif cmd == "edit" then
		if not idle() then return end
		if unlocked then setUnlocked(false) end
		startEdit()
	elseif cmd == "export" then
		showTextBox(serialize())
	elseif cmd == "import" then
		if rest ~= "" then importEggs(rest) else showTextBox("", importEggs) end
	elseif cmd == "reset" then
		DB.eggs = nil
		say("egen layout borttagen, inbyggd används")
		if editing then startEdit() end
	elseif cmd == "set" then
		if rest ~= "" and not parseToken(rest) then return say("ex: /ute set H3/H9 (eller /ute set för att rensa)") end
		DB.assign = rest ~= "" and rest or nil
		status()
	elseif cmd == "tid" then
		local s1, s2, d = rest:match("^(%S+)%s+(%S+)%s*(%d*)$")
		s1, s2, d = parseTime(s1 or ""), parseTime(s2 or ""), tonumber(d or "")
		if not (s1 and s2) then return say("ex: /ute tid 3:28 3:54 (valfritt: längd i sekunder sist)") end
		DB.starts = { s1, s2 }
		if d then DB.duration = d end
		status()
	elseif cmd == "scale" then
		local n = rest == "" and 1 or tonumber(rest)
		if not n or n <= 0 or n > 10 then return say("skala 0.1–10, t.ex. /ute scale 1.2") end
		DB.scale = n
		applyPosition()
	elseif cmd == "unlock" then
		if not idle() then return end
		if editing then return say("avsluta redigeringen först (/ute done)") end
		setUnlocked(true)
	else
		status()
	end
end
