// After all mission object inits; BIS functions may have compiled by then - re-apply stub.
call compile preprocessFileLineNumbers "rsc\fn_bisCpStubApply.sqf";
