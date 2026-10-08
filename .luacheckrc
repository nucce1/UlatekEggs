-- luacheck-konfiguration för WoW-addonmiljön (UlatekEggs)
std = "lua51"
max_line_length = false

read_globals = {
    "CreateFrame", "UIParent", "GetTime", "GetCursorPosition", "C_AddOns", "C_Timer",
    "CopyTable", "strtrim", "UnitName", "VMRT", "NSAPI", "GameFontHighlightSmall",
    "IsInRaid", "IsInGroup", "GetNumGroupMembers", "PlaySound", "SOUNDKIT", "Settings", "SettingsPanel", "HideUIPanel",
}

globals = {
    "UlatekEggsDB", "SLASH_ULATEKEGGS1", "SLASH_ULATEKEGGS2", "SlashCmdList",
}
