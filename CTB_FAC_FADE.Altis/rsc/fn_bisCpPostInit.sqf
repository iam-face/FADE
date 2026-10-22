// After all mission object inits; BIS functions may have compiled by then - re-apply stub.
call compile preprocessFileLineNumbers "rsc\fn_bisCpStubApply.sqf";
// Base NPC (S Wordsman): server spawns at Eden BaseNPCPos logic; clients add scroll action.
if (isNil "FADE_baseNpc_postInitBootstrap") then {
    call compile preprocessFileLineNumbers "rsc\BaseNpcTalk.sqf";
};
[] call FADE_baseNpc_postInitBootstrap;
