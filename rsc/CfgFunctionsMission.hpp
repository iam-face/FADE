// Optional: add to description.ext after `respawnOnStart = 0;`:
//   #include "rsc\CfgFunctionsMission.hpp"
// That runs this preInit before object/module init; init.sqf also calls fn_bisCpPreInit.sqf as fallback.
class CfgFunctions {
    class FADE_Mission {
        class bisCpPreInit {
            preInit = 1;
            file = "rsc\fn_bisCpPreInit.sqf";
        };
    };
};
