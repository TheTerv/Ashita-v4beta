require('common');

local settings = T{ };
settings["Monitored"] = T{ };
settings["PacketSearchDelay"] = 1.5;
settings["AllowPacketSearch"] = false;
settings["IdentifierType"] = "Index (Hex)";
settings["DefaultColor"] = 4278255488;
settings["Sound"] = "Alert.wav";

return settings;
