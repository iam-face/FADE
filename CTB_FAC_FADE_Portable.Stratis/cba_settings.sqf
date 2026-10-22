// Mission-level CBA/ACE overrides
// ACE Medical AI: require treatment items (and auto-replace vanilla gear for AI).
// 0=Disabled, 1=Enabled, 2=Enabled + auto-replace (see ace_medical_ai initSettings.inc.sqf).
force ace_medical_ai_requireItems = 2;
// Disable ACE hearing penalties/ringing for this mission.
force ace_hearing_enableCombatDeafness = false;
force ace_hearing_disableEarRinging = true;
// ACE Pylons: max search distance when not using curator mode (e.g. no ace_zeus). Default 15m closes the dialog
// immediately if opened from the vehicle board while the aircraft is farther away. 50m = slider max.
force ace_pylons_searchDistance = 50;
