// =============================================================================
// PresetLoadouts.sqf - preset loadouts (ACE / getUnitLoadout arrays for setUnitLoadout)
// =============================================================================
// missionNamespace FAC_presetLoadouts  -  compiled when player selects preset tab in Loadout GUI.
//
// Shape:
// [
//   [eraKey, eraDisplayName, [
//     [roleDisplayName, loadoutArray],
//     ...
//   ]],
//   ...
// ]
// - eraKey: no ":" (used in synthetic keys).
// - loadoutArray: getUnitLoadout / ACE export shape; must parse as valid SQF.
//   Must be exactly 10 array elements (0-9). Many ACE/ACEAX exports add an 11th slot
//   (e.g. aceax_textureOptions)  -  LoadoutGui truncates on apply; trim manually for clarity.
// =============================================================================

missionNamespace setVariable [
    "FAC_presetLoadouts",
    [
        [
            "modern",
            "2020s ADF RAR by MB",
            [
                [
                    "Platoon Commander",
                    [[["arifle_rho_ef88_cam4_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],["ACWP_HP_ba","","","",["ACWP_13Rnd_9x21_Mag_HP_blk",13],[],""],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",1,30]]],["rho_rar_vest_pl",[["ACE_IR_Strobe_Item",1],["ACRE_PRC343",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["ACE_bodyBag",2],["ACRE_PRC152",1],["ItemAndroid",1],["HandGrenade",3,1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["ACWP_13Rnd_9x21_Mag_HP_blk",2,13],["rho_rar_ef88_30Rnd_556x45_B_AUG",6,30]]],["ranger_pack_1",[["kat_IFAK",1],["ItemMicroDAGR",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1],["ACWP_13Rnd_9x21_Mag_HP_blk",3,13],["SmokeShellRed",1,1],["SmokeShellBlue",1,1],["SmokeShellYellow",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",5,30]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia",""],["aceax_textureOptions",[]]]]
                ],
                [
                    "Sect Comd",
                    [[["arifle_rho_ef88_cam5_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],["ACWP_HP_ba","","","",["ACWP_13Rnd_9x21_Mag_HP_blk",13],[],""],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",1,30]]],["rho_rar_vest_secco",[["ACE_IR_Strobe_Item",1],["ACRE_PRC343",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["ACE_bodyBag",2],["ACRE_PRC152",1],["HandGrenade",3,1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["ACWP_13Rnd_9x21_Mag_HP_blk",2,13],["rho_rar_ef88_30Rnd_556x45_B_AUG",6,30]]],["ranger_pack_1",[["kat_IFAK",1],["ItemMicroDAGR",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1],["ACWP_13Rnd_9x21_Mag_HP_blk",3,13],["SmokeShellRed",1,1],["SmokeShellBlue",1,1],["SmokeShellYellow",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",5,30]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia",""],["aceax_textureOptions",[]]]]
                ],
                [
                    "Sect 2IC",
                    [[["arifle_rho_ef88_cam2_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["rho_rar_vest_section2ic",[["ACE_IR_Strobe_Item",1],["ACRE_PRC343",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["ACE_bodyBag",2],["ACRE_PRC152",1],["HandGrenade",3,1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",7,30]]],["ranger_pack_1",[["kat_IFAK",1],["ItemMicroDAGR",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",5,30]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia",""],["aceax_textureOptions",[]]]]
                ],
                [
                    "SF",
                    [[["ACWP_M4A5_145_troy_Tango_DON","acwp_rc1_don","CUP_acc_ANPEQ_15_Flashlight_Black_L","acwp_eotech_don_g33_down",["ACWP_30rnd_556x45_EPR_PMAG_don",30],[],""],[],["75th_Ranger_G19","","75th_Ranger_x300u_1","75th_glock_rmr",["rhsusf_mag_17Rnd_9x19_JHP",17],[],""],["Rho_RAR_Combat_shirt_Tucked_Bloused_Rolled_Coy_Gloves",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["TFB_AVS_Assaulter_2_152A",[["ACE_IR_Strobe_Item",1],["ACRE_PRC343",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["ACRE_PRC152",1],["ACE_epinephrine",2],["ACE_morphine",2],["kat_atropine",2],["HandGrenade",3,1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["rhsusf_mag_17Rnd_9x19_JHP",3,17],["ACWP_30rnd_556x45_EPR_PMAG_don",7,30]]],["ranger_pack_1",[["kat_IFAK",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1]]],"rho_rar_airframe_ir_bat_comtac_mc","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia",""],["aceax_textureOptions",[]]]]
                ],
                [
                    "Medic",
                    [[["arifle_rho_ef88_cam7_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["rho_rar_vest_medic",[["ACE_IR_Strobe_Item",1],["ACRE_PRC343",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["HandGrenade",3,1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",7,30]]],["ranger_pack_3",[["ACE_Canteen",3],["ACE_MRE_LambCurry",1],["ACE_MRE_SteakVegetables",1],["kat_IFAK",1],["ACE_tourniquet",4],["ACE_salineIV",5],["ACE_splint",2],["kat_TXA",3],["kat_naloxone",4],["ACE_morphine",4],["kat_larynx",2],["kat_guedel",3],["kat_fentanyl",2],["kat_EACA",3],["kat_chestSeal",4],["ACE_bodyBag",4],["kat_accuvac",1],["kat_basicDiagnostic",1],["kat_AED",1],["kat_MFAK",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1],["kat_Penthrox",3,10],["ACE_painkillers",4,10],["rho_rar_ef88_30Rnd_556x45_B_AUG",5,30]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia",""],["aceax_textureOptions",[]]]]
                ],
                [
                    "Engineer",
                    [[["arifle_rho_ef88_cam4_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],["121_serbu_breacher","","","",["121_2Rnd_Slug",2],[],""],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["ACE_MapTools",1],["ACE_splint",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",2,1]]],["rho_rar_vest_engi",[["ACE_IR_Strobe_Item",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ACRE_PRC343",1],["tsp_breach_shock",3],["ItemcTabHCam",1],["HandGrenade",3,1],["Chemlight_green",6,1],["Chemlight_red",6,1],["Chemlight_yellow",6,1],["Chemlight_blue",3,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",5,30]]],["ranger_pack_5",[["ACE_DefusalKit",1],["ACE_wirecutter",1],["kat_IFAK",1],["ACE_EntrenchingTool",1],["MineDetector",1],["tsp_breach_block_mag",3,1],["tsp_breach_silhouette_mag",1,1],["tsp_breach_stick_mag",4,1],["tsp_breach_linear_mag",3,1],["tsp_breach_popper_mag",3,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",2,30]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia","_alt"],["aceax_textureOptions",[]]]]
                ],
                [
                    "JTAC",
                    [[["arifle_rho_ef88_cam9_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["ACE_artilleryTable",1],["ItemMicroDAGR",1],["ACE_ATragMX",1],["ACE_RangeCard",1],["ACE_PlottingBoard",1],["USP_PVS31_WP_MID_BLK",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["rho_rar_vest_fo",[["ACE_IR_Strobe_Item",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["ACRE_PRC343",1],["ACRE_PRC152",1],["HandGrenade",3,1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",7,30],["SmokeShellBlue",1,1],["SmokeShellGreen",1,1],["SmokeShellPurple",1,1],["SmokeShellRed",1,1],["SmokeShellYellow",1,1]]],["TFB_275_117G3",[["ACRE_PRC117F",1],["SmokeShellGreen",6,1],["SmokeShellRed",8,1],["SmokeShellPurple",6,1]]],"rho_rar_boonie_04","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch",""]],[["ace_arsenal_insignia","_alt"],["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman",
                    [[["arifle_rho_ef88_cam10_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["rho_rar_vest_rifle",[["ACE_IR_Strobe_Item",1],["ACRE_PRC343",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["HandGrenade",3,1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",7,30]]],["ranger_pack_1",[["kat_IFAK",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",5,30]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia","_alt"],["aceax_textureOptions",[]]]]
                ],
                [
                    "Grenadier",
                    [[["arifle_rho_ef88_GL_cam9_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],["1Rnd_HE_Grenade_shell",1],""],[],[],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["rho_rar_vest_grenadier",[["ACE_IR_Strobe_Item",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["ACRE_PRC343",1],["HandGrenade",1,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",7,30],["1Rnd_HE_Grenade_shell",7,1],["rhs_mag_m714_White",3,1],["rhs_mag_m716_yellow",1,1],["rhs_mag_m713_Red",1,1]]],["ranger_pack_1",[["kat_IFAK",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",5,30],["1Rnd_HE_Grenade_shell",5,1],["1Rnd_Smoke_Grenade_shell",3,1]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia","_alt"],["aceax_textureOptions",[]]]]
                ],
                [
                    "Marksman",
                    [[["CUP_arifle_HK417_20_Wood","","","CUP_optic_ACOG_TA648_308_RDS_od",["CUP_20Rnd_762x51_HK417_Camo_Wood",20],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["rho_rar_vest_rifle",[["ACE_IR_Strobe_Item",1],["ACRE_PRC343",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["HandGrenade",3,1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["CUP_20Rnd_762x51_HK417_Camo_Wood",5,20]]],["ranger_pack_1",[["ACE_Canteen",3],["kat_IFAK",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia","_alt"],["aceax_textureOptions",[]]]]
                ],
                [
                    "Minimi Gunner",
                    [[["rhs_weap_m249_pip","","","TFB_elcan_su230",["rhsusf_100Rnd_556x45_M855_soft_pouch_coyote",100],[],"rhsusf_acc_saw_bipod"],[],[],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["rho_rar_vest_lmg",[["ACE_IR_Strobe_Item",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["ACRE_PRC343",1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["200Rnd_556x45_Box_F",1,200],["rhsusf_100Rnd_556x45_M855_mixed_soft_pouch_coyote",2,100]]],["ranger_pack_1",[["ACE_Canteen",3],["kat_IFAK",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1],["rhsusf_100Rnd_556x45_M855_mixed_soft_pouch_coyote",4,100]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia","_alt"],["aceax_textureOptions",[]]]]
                ],
                [
                    "Mag58 Gunner",
                    [[["rhs_weap_fnmag","","","TFB_elcan_su230",["rhsusf_100Rnd_762x51",100],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["rho_rar_vest_mg",[["ACE_IR_Strobe_Item",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["ACRE_PRC343",1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["rhsusf_100Rnd_762x51",4,100]]],["ranger_pack_1",[["ACE_Canteen",3],["kat_IFAK",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1],["rhsusf_100Rnd_762x51",4,100]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia","_alt"],["aceax_textureOptions",[]]]]
                ],
                [
                    "Asst Machinegunner",
                    [[["arifle_rho_ef88_cam7_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["rho_rar_vest_rifle2",[["ACE_IR_Strobe_Item",1],["ACRE_PRC343",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["HandGrenade",3,1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",7,30]]],["ranger_pack_1",[["ACE_Canteen",3],["kat_IFAK",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1],["rhsusf_100Rnd_556x45_M855_soft_pouch_coyote",5,100],["rho_rar_ef88_30Rnd_556x45_B_AUG",5,30]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia","_alt"],["aceax_textureOptions",[]]]]
                ],
                [
                    "Sniper",
                    [[["ACWP_blaser_r93_don","muzzle_snds_338_black","","TFB_ATACR",["ACWP_5rnd_338LM_base",5],[],"bipod_01_F_blk"],[],["ACWP_HP_ba","","","",["ACWP_13Rnd_9x21_Mag_HP_blk",13],[],""],["UK3CB_ANA_B_U_CombatUniform_Ghillie_GCAM",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1],["ACWP_5rnd_338LM_base",2,5]]],["TFB_AVS_Light_2_152A",[["ACE_IR_Strobe_Item",1],["ACRE_PRC343",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["ACRE_PRC152",1],["ACE_ATragMX",1],["ACE_Kestrel4500",1],["ItemMicroDAGR",1],["HandGrenade",3,1],["vn_m18_white_mag",2,1],["Chemlight_green",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["acex_intelitems_notepad",1,1],["ACWP_5rnd_338LM_APDS",5,5],["ACWP_13Rnd_9x21_Mag_HP_blk",2,13],["ACWP_5rnd_338LM_base",4,5]]],["ranger_pack_1",[["kat_IFAK",1],["Chemlight_green",3,1],["Chemlight_blue",3,1],["Chemlight_red",3,1],["Chemlight_yellow",3,1],["vn_m18_white_mag",2,1],["HandGrenade",2,1],["ACWP_5rnd_338LM_base",1,5]]],"","",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch",""]],[["ace_arsenal_insignia","_alt"],["aceax_textureOptions",[]]]]
                ],
                [
                    "Pilot",
                    [[["arifle_rho_ef88_C_blk_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],["ACWP_HP_ba","","","",["ACWP_13Rnd_9x21_Mag_HP_blk",13],[],""],["SOAR_Flight_3_uniform",[["ACE_fieldDressing",1],["ACE_quikclot",1],["ACE_tourniquet",1],["grad_paceCountBeads_functions_paceCountBeads",1],["kat_Painkiller",2,4],["acex_intelitems_notepad",1,1]]],["rho_rar_vest_pl",[["ACE_IR_Strobe_Item",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["kat_IFAK",1],["ACE_tourniquet",2],["kat_guedel",2],["kat_chestSeal",3],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_CableTie",4],["ItemcTabHCam",1],["ACE_splint",1],["ItemAndroid",1],["ACRE_PRC152",1],["vn_m18_white_mag",2,1],["acex_intelitems_notepad",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",7,30],["SmokeShellBlue",1,1],["SmokeShellRed",1,1]]],[],"rhsusf_hgu56p_visor_mask","rho_reconwrap_03_glasses_blacklens",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_MID_BLK"]],[["ace_arsenal_insignia",""],["aceax_textureOptions",[]]]]
                ]
            ]
        ],
        [
            "2000sUSMC",
            "2000s USMC by Crusty",
            [
                [
                    "Medic",
                    [[["simc_m4a0_erla","","","simc_optic_m2_low_lens",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],[],["U_simc_DCU_03_knee_nomex_trop",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_Flashlight_XL50",1],["ACE_MapTools",1]]],["V_Simc_IBA_M81_lbv_mk2_2",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],["B_simc_US_Molle_Medic_m81",[["kat_MFAK",1],["ACE_surgicalKit",1],["kat_accuvac",1]]],"H_Simc_pasgt_DCU_TASC_b_nvo_strap_X800","G_simc_peltor",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Demolition",
                    [[["simc_m4a0_erla","","","simc_optic_m2_low",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],[],["U_simc_DCU_03_gas_knee_nomex_trop",[["kat_IFAK",1],["ACE_EarPlugs",1],["iedd_item_notebook",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1]]],["V_Simc_IBA_M81_1",[["ACE_M26_Clacker",1],["ACE_DefusalKit",1],["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],["B_simc_US_Molle_patrol_m81",[["rhsusf_m112x4_mag",1,1],["rhsusf_m112_mag",2,1],["SatchelCharge_Remote_Mag",1,1]]],"H_Simc_pasgt_DCU_b_nvo_ESS","G_simc_peltor",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Machine Gunner",
                    [[["UK3CB_M60","","","",["UK3CB_M60_100rnd_762x51_GM",100],[],""],[],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["U_simc_DCU_03_eto_gas_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_Flashlight_XL50",1],["ACE_MapTools",1]]],["V_Simc_IBA_M81_erla_MG_2",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhsusf_mag_15Rnd_9x19_JHP",2,15],["UK3CB_M60_100rnd_762x51_GM",4,100]]],[],"H_Simc_pasgt_DCU_nvo_X800","G_simc_peltor",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Machine Gun Assistant",
                    [[["UK3CB_M60","","","",["UK3CB_M60_100rnd_762x51_GM",100],[],""],[],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["U_simc_DCU_03_eto_gas_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_Flashlight_XL50",1],["ACE_MapTools",1]]],["V_Simc_IBA_M81_erla_MG_2",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhsusf_mag_15Rnd_9x19_JHP",2,15],["UK3CB_M60_100rnd_762x51_GM",4,100]]],[],"H_Simc_pasgt_DCU_nvo_X800","G_simc_peltor",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman",
                    [[["simc_m4a0_erla","","","simc_optic_m2_low",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1]]],["V_Simc_IBA_M81_1",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],[],"H_Simc_pasgt_dcu_SWDG_nvo_b_low","",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman M136",
                    [[["simc_m4a0_erla","","","simc_optic_m2_low",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],["rhs_weap_M136","","rhs_acc_at4_handler","",[],[],""],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1]]],["V_Simc_IBA_M81_1",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],[],"H_Simc_pasgt_dcu_SWDG_nvo_b_low","",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman SMAW",
                    [[["simc_m4a0_erla","","","simc_optic_m2_low",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],["rhs_weap_smaw_green","","","",["rhs_mag_smaw_HEAA",1],[],""],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1]]],["V_Simc_IBA_M81_1",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],[],"H_Simc_pasgt_dcu_SWDG_nvo_b_low","",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman SMAW Assistant",
                    [[["simc_m4a0_erla","","","simc_optic_m2_low",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1]]],["V_Simc_IBA_M81_1",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],["B_simc_pack_alice_M81_frame_1",[]],"H_Simc_pasgt_dcu_SWDG_nvo_b_low","",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Grenadier",
                    [[["simc_m4a0_LMT_gl","","","simc_optic_m2_low_rear_lens",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],["1Rnd_HE_Grenade_shell",1],""],[],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_Flashlight_XL50",1],["ACE_MapTools",1]]],["V_Simc_IBA_M81_flc_erla_4cm_2",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30],["1Rnd_HE_Grenade_shell",10,1]]],[],"H_Simc_pasgt_dcu_TASC_nvo","G_LEN_TG1_weiss",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Squad Leader",
                    [[["simc_m4a0_ras_LMT_VFG","","","simc_optic_m2_low",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACRE_PRC343",1],["ACE_Flashlight_XL50",1],["ACE_MapTools",1],["acex_intelitems_notepad",1,1]]],["V_Simc_IBA_M81_45_1",[["ACRE_PRC148",1],["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhsusf_mag_15Rnd_9x19_JHP",2,15],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],[],"H_Simc_pasgt_DCU_nvo_strap_X800","",["Binocular","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Light Machine Gunner",
                    [[["rhs_weap_m249_pip","","","",["rhsusf_200rnd_556x45_mixed_box",200],[],"rhsusf_acc_saw_bipod"],[],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["U_simc_DCU_03_eto_gas_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_Flashlight_XL50",1],["ACE_MapTools",1]]],["V_Simc_IBA_M81_erla_MG_2",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhsusf_mag_15Rnd_9x19_JHP",2,15],["rhsusf_200rnd_556x45_mixed_box",3,200]]],[],"H_Simc_pasgt_DCU_nvo_X800","G_simc_peltor",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "JFO",
                    [[["simc_m4a0_LMT_gl","","","simc_optic_m2_low_rear_lens",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],["1Rnd_HE_Grenade_shell",1],""],[],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_Flashlight_XL50",1],["ACE_MapTools",1],["ACRE_PRC148",1]]],["V_Simc_IBA_M81_flc_erla_4cm_2",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30],["1Rnd_HE_Grenade_shell",4,1],["1Rnd_SmokeRed_Grenade_shell",6,1],["SmokeShellBlue",2,1],["SmokeShellGreen",2,1],["SmokeShellRed",2,1]]],["B_simc_US_Molle_Patrol_m81_RTO_wasser",[["ACRE_PRC117F",1]]],"H_Simc_pasgt_dcu_TASC_nvo","G_LEN_TG1_weiss",["rhsusf_bino_lrf_Vector21","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Crewman",
                    [[["simc_m4a0_erla","","","",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1]]],["V_Simc_IBA_M81_1",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],[],"cvc_g","",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman Javelin",
                    [[["simc_m4a0_erla","","","simc_optic_m2_low",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],["rhs_weap_fgm148","","","",["rhs_fgm148_magazine_AT",1],[],""],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1]]],["V_Simc_IBA_M81_1",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],[],"H_Simc_pasgt_dcu_SWDG_nvo_b_low","",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman Javelin Assistant",
                    [[["simc_m4a0_erla","","","simc_optic_m2_low",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1]]],["V_Simc_IBA_M81_1",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],["UK3CB_B_Alice_pack_01",[]],"H_Simc_pasgt_dcu_b_nvo_swdg","",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Breacher",
                    [[["simc_m4a0_erla","","","simc_optic_m2_low",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1]]],["V_Simc_IBA_M81_1",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],["B_simc_US_Molle_sturm_m81_etool",[["tsp_breach_linear_mag",3,1],["tsp_breach_silhouette_mag",1,1],["tsp_breach_package_mag",1,1]]],"H_Simc_pasgt_dcu_b_nvo_strap","UK3CB_G_Ballistic_Shemagh_Tan_Gloves_Tan",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Marksman",
                    [[["rhs_weap_m14_rail","rhsusf_acc_m14_flashsuppresor","","rhsusf_acc_LEUPOLDMK4",["20Rnd_762x51_Mag",20],[],""],[],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["rhsusf_20Rnd_762x51_m80_Mag",1,20]]],["V_Simc_IBA_M81_1",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhsusf_mag_15Rnd_9x19_JHP",2,15],["rhsusf_20Rnd_762x51_m80_Mag",6,20]]],[],"H_Simc_pasgt_dcu_b_nvo_strap_swdg","UK3CB_G_Ballistic_Shemagh_White_Tactical_Gloves_Green",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Sniper",
                    [[["rhs_weap_m40a5","","","rhsusf_acc_LEUPOLDMK4",["rhsusf_5Rnd_762x51_AICS_m118_special_Mag",5],[],"rhsusf_acc_harris_swivel"],[],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["U_simc_DCU_03_alt_gas_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACE_RangeCard",1],["ACE_EntrenchingTool",1],["ACRE_PRC148",1]]],["V_Simc_IBA_M81_4",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhsusf_mag_15Rnd_9x19_JHP",6,15],["rhsusf_5Rnd_762x51_AICS_m118_special_Mag",14,5]]],[],"H_Simc_pasgt_dcu_b_nvo_strap_swdg","UK3CB_G_Tactical_Clear_Shemagh_Tan_Gloves_Green",[],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Spotter",
                    [[["simc_m4a0_erla","","","rhsusf_acc_ACOG_3d",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],[],["U_simc_DCU_03_alt_knee",[["kat_IFAK",1],["ACE_EarPlugs",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACE_RangeCard",1],["acex_intelitems_notepad",1,1]]],["V_Simc_IBA_M81_1",[["rhs_mag_m67",2,1],["SmokeShell",2,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",8,30]]],["B_simc_US_Molle_sturm_m81",[["ACE_SpottingScope",1],["ACE_Tripod",1],["ACE_EntrenchingTool",1]]],"H_Simc_pasgt_dcu_TASC_nvo_strap","",["Binocular","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ]
            ]
        ],
        [
            "jtacJoon",
            "JTAC by Joon",
            [
                [
                    "Modern",
                    [[["rhs_weap_m4a1_blockII_d","","","Tier1_Shortdot_Geissele_Docter_Desert",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["rhs_weap_M320","","","",["rhs_mag_M441_HE",1],[],""],["U_tweed_acu_summer_ocp_blench_crye_knee",[["ACE_fieldDressing",8],["ACE_epinephrine",1],["ACE_morphine",2],["ACE_tourniquet",2],["ACE_packingBandage",2],["ACE_elasticBandage",2],["ACE_IR_Strobe_Item",1]]],["tfa_v_mmac_teamleader_belt_coy",[["ACRE_PRC152",1],["ACRE_PRC343",1],["rhs_mag_m18_green",3,1],["rhs_mag_m18_purple",3,1],["SmokeShellRed",3,1],["SmokeShellOrange",2,1],["rhs_mag_30Rnd_556x45_M855_Stanag_Pull_Tracer_Red",5,30]]],["CUP_B_USPack_Coyote",[["ACRE_PRC152",1],["ACRE_PRC343",1],["kat_IFAK",1],["ACRE_PRC117F",1],["SmokeShellGreen",7,1],["SmokeShellOrange",3,1],["SmokeShellRed",6,1],["SmokeShellPurple",5,1],["SmokeShellBlue",4,1],["SmokeShellYellow",2,1]]],"SOTG_Helmets_8","G_Bandanna_khk",["Laserdesignator","","","",["Laserbatteries",1],[],""],["ItemMap","ItemGPS","","ItemCompass","ItemWatch",""]],[]]
                ],
                [
                    "Night Fighting",
                    [[["rhs_weap_m4a1_blockII_M203_d","","","rhsusf_acc_su230_mrds_c",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],["1Rnd_SmokeRed_Grenade_shell",1],""],[],["rhs_weap_M320","","","",["rhs_mag_M441_HE",1],[],""],["U_tweed_acu_summer_ocp_blench_crye_knee",[["ACE_fieldDressing",8],["ACE_epinephrine",1],["ACE_morphine",2],["ACE_tourniquet",2],["ACE_packingBandage",4],["ACE_elasticBandage",2]]],["tfa_v_mmac_teamleader_belt_coy",[["ACRE_PRC152",1],["ACRE_PRC343",1],["ACE_IR_Strobe_Item",4],["rhs_mag_m18_green",3,1],["rhs_mag_30Rnd_556x45_M855_Stanag_Pull_Tracer_Red",5,30],["1Rnd_SmokeBlue_Grenade_shell",3,1],["CUP_FlareYellow_M203",3,1],["UGL_FlareCIR_F",6,1],["ACE_40mm_Flare_red",8,1],["ACE_40mm_Flare_ir",4,1]]],["CUP_B_USPack_Coyote",[["ACRE_PRC117F",1],["ACRE_PRC343",1],["ACRE_PRC152",1],["1Rnd_SmokeRed_Grenade_shell",3,1],["CUP_1Rnd_HE_M203",3,1],["CUP_FlareRed_M203",4,1],["1Rnd_SmokeBlue_Grenade_shell",3,1]]],"SOTG_Helmets_8","G_Bandanna_khk",["Laserdesignator","","","",["Laserbatteries",1],[],""],["ItemMap","ItemGPS","","ItemCompass","ItemWatch","USP_PVS31_BLK"]],[]]
                ],
                [
                    "Mid-Tech",
                    [[["CUP_arifle_L85A2_G","","","",["CUP_30Rnd_556x45_Stanag_L85",30],[],""],[],[],["QAC_CS95_DPM_DDPM_Rolled",[["kat_IFAK",1]]],["QAC_ECBA_PLCE_O_DDPM_DPM",[["ACRE_PRC343",1],["CUP_30Rnd_556x45_Stanag_L85_Tracer_Green",5,30],["vn_m18_red_mag",8,1]]],["A2BAFV2_bhawk_backpack_03_01",[["ACRE_PRC343",1],["ACRE_PRC152",1],["CUP_30Rnd_556x45_Stanag_L85_Tracer_Green",1,30],["vn_m18_green_mag",3,1],["vn_m18_red_mag",3,1]]],"A2BAF_V2_Helmet_06_DDPM","",["vn_mk21_binocs","","","",[],[],""],["ItemMap","","","vn_b_item_compass","vn_b_item_watch",""]],[]]
                ],
                [
                    "Vietnam",
                    [[["vn_m16_xm148","","","",["vn_m16_20_t_mag",18],["vn_40mm_m662_flare_r_mag",1],""],[],[],["vn_b_uniform_macv_05_01",[["vn_m18_green_mag",1,1],["vn_m16_20_t_mag",7,18]]],["vn_b_vest_usarmy_05",[["vn_m18_purple_mag",2,1],["vn_m18_yellow_mag",2,1],["vn_m18_green_mag",1,1]]],["vn_b_pack_lw_06",[["ACRE_PRC77",1],["kat_IFAK",1],["vn_40mm_m682_smoke_r_mag",5,1],["vn_m18_green_mag",1,1],["vn_m18_purple_mag",2,1],["vn_m18_red_mag",1,1]]],"vn_b_boonie_02_02","",["vn_m19_binocs_grn","","","",[],[],""],["vn_b_item_map","","","vn_b_item_compass","vn_b_item_watch",""]],[]]
                ],
                [
                    "WW2",
                    [[["SPE_M1A1_Thompson","","","",["SPE_30Rnd_Thompson_45ACP",30],[],""],[],["rhs_weap_rsp30_red","","","",["rhs_mag_rsp30_red",1],[],""],["U_SPE_US_CC_HBT_EM_roll",[["ACE_fieldDressing",4],["ACE_tourniquet",1],["ACE_morphine",1],["ACE_packingBandage",3],["SPE_30Rnd_Thompson_45ACP_t",2,30]]],["V_SPE_US_Vest_AB_early_2",[["kat_IFAK",1],["SPE_30Rnd_Thompson_45ACP_t",4,30],["SPE_US_M18_Violet",1,1],["SPE_US_M18_Yellow",2,1]]],["B_SPE_US_Radio_alt",[["SPE_US_M15",2,1],["SPE_US_M18_Red",4,1],["SPE_US_M18_Green",3,1],["SPE_US_M18_Violet",2,1]]],"H_SPE_US_Helmet_29ID_Scrim_os","",["SPE_Binocular_US","","","",[],[],""],["ItemMap","","","SPE_US_ItemCompass","SPE_US_ItemWatch",""]],[]]
                ]
            ]
        ],
        [
            "dividedHouse",
            "Divided House BLUFOR (RHO)",
            [
                [
                    "PLT Leader",
                    [[["simc_mk18_ras_kac","rhsusf_acc_nt4_black","simc_acc_pointer_PEQ2_top","Tier1_Eotech553_Black",["rhs_mag_30Rnd_556x45_M855_Stanag",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["U_B_RBU_M81_IR",[["kat_IFAK",1]]],["V_Simc_pracs_od7_2",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["ACE_microDAGR",1],["ACE_CableTie",2],["rhs_mag_m67",2,1],["rhsusf_mag_15Rnd_9x19_FMJ",2,15],["rhs_mag_an_m8hc",1,1],["rhs_mag_30Rnd_556x45_M855_Stanag",6,30],["tsp_flashbang_cts2",2,1],["MCC_USGI_556_556_30_M995",7,30]]],["B_simc_panel_base",[["FirstAidKit",2],["tsp_flashbang_cts2",2,1],["rhs_mag_m67",2,1]]],"H_Simc_mich_2002_anvis_bare_TASC_b_X800","rhs_googles_clear",["Binocular","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "PLT Medic",
                    [[["simc_m4a1_ras_kac_VFG","rhsusf_acc_nt4_black","CUP_acc_ANPEQ_2_Flashlight_Black_L","Tier1_Eotech553_Black",["rhs_mag_30Rnd_556x45_M855_Stanag",30],[],""],[],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_simc_bdu_03_raid_knee_trop",[["kat_IFAK",1],["ACE_Flashlight_XL50",1]]],["V_Simc_pracs_od7_45_3",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["rhs_mag_m67",1,1],["rhs_mag_an_m8hc",2,1],["rhs_mag_30Rnd_556x45_M855_Stanag",7,30],["tsp_flashbang_cts2",2,1],["MCC_USGI_556_556_30_M995",8,30]]],["B_simc_pack_alice_M81_2",[["kat_MFAK",1],["ACE_salineIV",2],["ACE_salineIV_500",2],["ACE_bodyBag",4],["rhs_mag_an_m8hc",2,1]]],"H_Simc_mich_anvis_zwart_TASC_b_ESS","G_oak_2",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "PLT Sergeant",
                    [[["simc_mk18_ras_kac","rhsusf_acc_nt4_black","simc_acc_pointer_PEQ2_top","Tier1_Eotech553_Black",["rhs_mag_30Rnd_556x45_M855_Stanag",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["U_simc_bdu_03_raid_knee_alt_trop",[["kat_IFAK",1]]],["V_Simc_pracs_od7_4",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["ACE_microDAGR",1],["rhs_mag_m67",2,1],["rhsusf_mag_15Rnd_9x19_FMJ",2,15],["rhs_mag_an_m8hc",1,1],["rhs_mag_30Rnd_556x45_M855_Stanag",6,30],["tsp_flashbang_cts2",2,1],["MCC_USGI_556_556_30_M995",7,30]]],["B_simc_panel_od7_1",[["FirstAidKit",2],["ACE_CableTie",2],["tsp_flashbang_cts2",2,1],["rhs_mag_m67",2,1]]],"H_Simc_mich_2002_anvis_bare_TASC_b","rhs_googles_clear",["Binocular","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "JTAC",
                    [[["simc_m4a1_kac_gl","rhsusf_acc_nt4_black","simc_acc_pointer_PEQ2","CUP_optic_CompM2_low",["rhs_mag_30Rnd_556x45_M855_Stanag",30],["1Rnd_HE_Grenade_shell",1],""],[],["Worm_IZLIDB","","","",[],[],""],["U_B_RBU_M81_IR",[["kat_IFAK",1],["ACE_Flashlight_XL50",1],["ACE_CableTie",2]]],["V_Simc_pracs_od7_4cm_2",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["rhs_mag_m67",2,1],["rhs_mag_an_m8hc",1,1],["tsp_flashbang_cts2",4,1],["rhs_mag_30Rnd_556x45_M855_Stanag",6,30],["UGL_FlareCIR_F",2,1],["MCC_USGI_556_556_30_M995",8,30]]],["USMC_Backpack_Radio_JPC",[["ACE_bodyBag",1],["ACRE_PRC117F",1],["VS17_Large_Panel_Item",4],["rhs_mag_30Rnd_556x45_M855_Stanag",4,30],["1Rnd_SmokeRed_Grenade_shell",14,1],["1Rnd_SmokePurple_Grenade_shell",2,1],["SmokeShellOrange",2,1],["SmokeShellBlue",2,1],["SmokeShellPurple",2,1],["SmokeShellYellow",2,1],["1Rnd_HE_Grenade_shell",9,1]]],"H_Simc_mich_2002_anvis_bare_b_X800","G_Simc_tacticool_weiss_peltor",["rhsusf_bino_m24_ARD","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Section Leader",
                    [[["simc_mk18_ras_kac_VFG","rhsusf_acc_nt4_black","CUP_acc_ANPEQ_2_Flashlight_Black_L","rhsusf_acc_ACOG",["rhs_mag_30Rnd_556x45_M855_Stanag",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["U_simc_bdu_03_raid_knee_nomex",[["kat_IFAK",1],["ACE_CableTie",2]]],["V_Simc_pracs_od7_3",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["ACE_microDAGR",1],["rhs_mag_m67",2,1],["rhsusf_mag_15Rnd_9x19_FMJ",2,15],["rhs_mag_an_m8hc",1,1],["tsp_flashbang_cts2",2,1],["rhs_mag_30Rnd_556x45_M855_Stanag",6,30],["MCC_USGI_556_556_30_M995",7,30]]],["B_simc_panel_od7_1",[["FirstAidKit",2],["tsp_flashbang_cts2",2,1],["rhs_mag_m67",2,1]]],"H_Simc_mich_2002_anvis_zwart_TASC","rhs_googles_clear",["Binocular","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "2IC - Grenadier",
                    [[["simc_m4a1_kac_gl","rhsusf_acc_nt4_black","simc_acc_pointer_PEQ2","Tier1_Eotech553_Black",["rhs_mag_30Rnd_556x45_M855_Stanag",30],["1Rnd_HE_Grenade_shell",1],""],["rhs_weap_m72a7","","","",[],[],""],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_Simc_bdu_PCU_nomex",[["kat_IFAK",1],["ACE_Flashlight_XL50",1],["ACE_CableTie",2]]],["V_Simc_pracs_od7_4cm_1",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["rhs_mag_m67",2,1],["rhs_mag_an_m8hc",1,1],["rhs_mag_30Rnd_556x45_M855_Stanag",6,30],["tsp_flashbang_cts2",4,1],["1Rnd_HE_Grenade_shell",2,1],["MCC_USGI_556_556_30_M995",8,30]]],["B_simc_panel_od7_4cm",[["ACE_bodyBag",1],["1Rnd_HE_Grenade_shell",19,1],["UGL_FlareCIR_F",4,1],["1Rnd_Smoke_Grenade_shell",4,1],["rhsusf_mag_7x45acp_MHP",2,7],["rhs_mag_30Rnd_556x45_M855_Stanag",3,30]]],"H_Simc_mich_2002_anvis_bare_TASC_b","G_oak_2",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Auto Rifleman (M249)",
                    [[["rhs_weap_minimi_para_railed","rhsusf_acc_nt4_black","simc_acc_pointer_PEQ2","CUP_optic_Eotech553_Black",["rhsusf_200rnd_556x45_M855_mixed_box",200],[],""],[],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_Simc_bdu_PCU_knee_nomex_trop",[["kat_IFAK",1],["ACE_Flashlight_XL50",1]]],["V_Simc_pracs_od7_MG_1",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["ACE_CableTie",2],["rhs_mag_m67",2,1],["rhs_mag_an_m8hc",1,1],["tsp_flashbang_cts2",4,1],["rhsusf_mag_7x45acp_MHP",3,7],["rhsusf_100Rnd_556x45_M855_mixed_soft_pouch",2,100],["rhsusf_100Rnd_556x45_M995_soft_pouch",1,100]]],["B_simc_panel_od7_sturm",[["ACE_bodyBag",1],["rhsusf_100Rnd_556x45_M855_mixed_soft_pouch",3,100],["rhsusf_100Rnd_556x45_M995_soft_pouch",2,100]]],"H_Simc_mich_anvis_bare_TASC_b_strobe","G_LEN_TG4_weiss",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman (M136)",
                    [[["simc_m4a1_ras_kac_VFG","rhsusf_acc_nt4_black","CUP_acc_ANPEQ_2_Flashlight_Black_L","CUP_optic_CompM2_low",["rhs_mag_30Rnd_556x45_M855_Stanag",30],[],""],["rhs_weap_M136","","","",[],[],""],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_simc_bdu_03_raid_knee_nomex_trop",[["kat_IFAK",1],["ACE_Flashlight_XL50",1]]],["V_Simc_pracs_od7_45_4",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["ACE_CableTie",2],["rhs_mag_m67",2,1],["rhs_mag_30Rnd_556x45_M855_Stanag",8,30],["tsp_flashbang_cts2",4,1],["MCC_USGI_556_556_30_M995",7,30]]],["B_simc_panel_od7_wasser",[["ACE_bodyBag",1],["rhs_mag_30Rnd_556x45_M855_Stanag",12,30],["tsp_flashbang_cts2",8,1],["rhs_mag_m67",2,1]]],"H_Simc_mich_2002_anvis_zwart_TASC_b_strobe_ESS","G_oak_2",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman CFA",
                    [[["simc_m4a1_ras_kac_VFG","rhsusf_acc_nt4_black","CUP_acc_ANPEQ_2_Flashlight_Black_L","Tier1_Eotech553_Black",["rhs_mag_30Rnd_556x45_M855_Stanag",30],[],""],[],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_simc_bdu_03_raid_knee_trop",[["kat_IFAK",1],["ACE_Flashlight_XL50",1]]],["V_Simc_pracs_od7_45_3",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["ACE_CableTie",2],["rhs_mag_m67",1,1],["rhs_mag_an_m8hc",2,1],["rhs_mag_30Rnd_556x45_M855_Stanag",7,30],["tsp_flashbang_cts2",2,1],["MCC_USGI_556_556_30_M995",8,30]]],["B_simc_pack_alice_M81_2",[["kat_MFAK",1],["ACE_salineIV",2],["ACE_salineIV_500",2],["ACE_bodyBag",4],["rhs_mag_an_m8hc",2,1]]],"H_Simc_mich_anvis_zwart_TASC_b_ESS","G_oak_2",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Breacher",
                    [[["simc_mk18_ras_kac","rhsusf_acc_nt4_black","CUP_acc_ANPEQ_2_Flashlight_Black_L","CUP_optic_CompM2_low",["rhs_mag_30Rnd_556x45_M855_Stanag",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["121_serbu_breacher","","","",["121_2Rnd_Slug",2],[],""],["U_simc_bdu_03_raid_knee_nomex_trop",[["kat_IFAK",1],["ACE_Flashlight_XL50",1]]],["V_Simc_pracs_od7_SG_1",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["ACE_CableTie",2],["rhs_mag_m67",2,1],["tsp_flashbang_cts2",4,1],["rhs_mag_30Rnd_556x45_M855_Stanag",8,30],["MCC_USGI_556_556_30_M995",5,30]]],["B_simc_panel_od7_sg",[["ACE_bodyBag",1],["ACE_DefusalKit",1],["tsp_breach_shock",1],["tsp_breach_linear_mag",4,1],["tsp_breach_popper_auto_mag",2,1],["tsp_breach_stick_mag",2,1],["tsp_breach_package_mag",1,1],["DemoCharge_Remote_Mag",2,1],["tsp_flashbang_cts",2,1],["tsp_flashbang_cts2",6,1],["121_2Rnd_Slug",4,2]]],"H_Simc_mich_2002_anvis_zwart_TASC_b_X800","G_oak_2",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Pilot",
                    [[["CUP_smg_MP5A5","","","",["CUP_30Rnd_9x19_MP5",30],[],""],[],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["nomex_Olive",[["kat_IFAK",1]]],["V_Simc_pracs_pmc_od9_45_2",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["ACE_microDAGR",1],["ACE_Chemlight_IR",1],["rhs_mag_m67",1,1],["rhsusf_mag_15Rnd_9x19_FMJ",2,15],["rhs_mag_an_m8hc",1,1],["B_IR_Grenade",1,1],["SmokeShellOrange",2,1],["SmokeShellPurple",2,1],["SmokeShellBlue",2,1],["CUP_30Rnd_9x19_MP5",5,30]]],[],"rhsusf_hgu56p_mask_black","G_LEN_TG1_weiss",["Binocular","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Recon - 2IC - Grenadier",
                    [[["simc_m4a1_kac_gl","rhsusf_acc_nt4_black","simc_acc_pointer_PEQ2","Tier1_Eotech553_Black",["rhs_mag_30Rnd_556x45_M855_Stanag",30],["1Rnd_HE_Grenade_shell",1],""],["rhs_weap_m72a7","","","",[],[],""],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_simc_bdu_03_raid_blench",[["kat_IFAK",1],["ACE_Flashlight_XL50",1]]],["V_Simc_LEN_FOX_AWS_OD7_LC2_1",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["rhs_mag_m67",2,1],["rhs_mag_an_m8hc",1,1],["rhs_mag_30Rnd_556x45_M855_Stanag",10,30],["tsp_flashbang_cts2",4,1],["1Rnd_HE_Grenade_shell",2,1]]],["B_simc_pack_alice_M81_1",[["ACE_bodyBag",1],["1Rnd_HE_Grenade_shell",19,1],["UGL_FlareCIR_F",4,1],["1Rnd_Smoke_Grenade_shell",4,1],["rhsusf_mag_7x45acp_MHP",2,7],["rhs_mag_30Rnd_556x45_M855_Stanag",3,30]]],"H_Simc_mich_2002_anvis_bare_TASC_b","G_oak_2",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Recon - Auto Rifleman (M249)",
                    [[["rhs_weap_minimi_para_railed","rhsusf_acc_nt4_black","simc_acc_pointer_PEQ2","CUP_optic_Eotech553_Black",["rhsusf_200rnd_556x45_M855_mixed_box",200],[],""],[],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_simc_bdu_03_raid_blench",[["kat_IFAK",1],["ACE_Flashlight_XL50",1]]],["V_Simc_flc_m81_MG_2",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["rhs_mag_m67",2,1],["rhs_mag_an_m8hc",1,1],["tsp_flashbang_cts2",4,1],["rhsusf_mag_7x45acp_MHP",3,7],["rhsusf_100Rnd_556x45_M855_mixed_soft_pouch",3,100]]],["B_simc_US_Molle_Patrol_m81_etool",[["ACE_bodyBag",1],["rhsusf_100Rnd_556x45_M855_mixed_soft_pouch",6,100]]],"H_Simc_mich_2002_bare_TASC_b_licht","G_LEN_TG4_weiss",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Recon - Marksman",
                    [[["rhs_weap_sr25_wd","rhsusf_acc_SR25S_wd","simc_acc_pointer_PEQ2","rhsusf_acc_premier_anpvs27",["rhsusf_20Rnd_762x51_SR25_m993_Mag",20],[],""],["rhs_weap_m72a7","","","",[],[],""],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_simc_bdu_03_raid_blench",[["kat_IFAK",1],["ACE_Flashlight_XL50",1]]],["V_Simc_LEN_FOX_AWS_OD7_LC2_2",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["rhs_mag_m67",2,1],["rhs_mag_an_m8hc",1,1],["rhsusf_mag_7x45acp_MHP",4,7],["rhsusf_20Rnd_762x51_SR25_m993_Mag",5,20]]],["B_simc_US_Molle_sturm_m81_RTO",[["ACE_bodyBag",1],["ACE_ATragMX",1],["ACE_microDAGR",1],["ACE_RangeCard",1],["121_tripod_item",1],["rhsusf_20Rnd_762x51_SR25_m993_Mag",10,20]]],"H_Simc_mich_2002_anvis_bare_TASC_b_strobe","G_oak_2",["121_spotting_scope_handheld","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Recon - Medic",
                    [[["simc_m4a1_ras_kac_VFG","rhsusf_acc_nt4_black","CUP_acc_ANPEQ_2_Flashlight_Black_L","Tier1_Eotech553_Black",["rhs_mag_30Rnd_556x45_M855_Stanag",30],[],""],[],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_simc_bdu_03_raid_blench_knee_nomex_trop",[["kat_IFAK",1],["ACE_Flashlight_XL50",1]]],["V_Simc_LEN_FOX_AWS_m81",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["rhs_mag_m67",1,1],["rhs_mag_an_m8hc",2,1],["rhs_mag_30Rnd_556x45_M855_Stanag",11,30],["tsp_flashbang_cts2",2,1]]],["B_simc_pack_alice_M81_2",[["kat_MFAK",1],["ACE_salineIV",2],["ACE_salineIV_500",2],["ACE_bodyBag",4],["rhs_mag_an_m8hc",2,1]]],"H_Simc_mich_2002_anvis_bare_b_tapes","G_oak_2",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Recon - Rifleman (M136)",
                    [[["simc_m4a1_ras_kac_VFG","rhsusf_acc_nt4_black","CUP_acc_ANPEQ_2_Flashlight_Black_L","CUP_optic_CompM2_low",["rhs_mag_30Rnd_556x45_M855_Stanag",30],[],""],["rhs_weap_M136","","","",[],[],""],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_simc_bdu_03_raid_blench_knee_nomex_trop",[["kat_IFAK",1],["ACE_Flashlight_XL50",1]]],["V_Simc_LEN_FOX_AWS_m81",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["rhs_mag_m67",2,1],["rhs_mag_30Rnd_556x45_M855_Stanag",12,30],["tsp_flashbang_cts2",4,1]]],["B_simc_US_Molle_patrol_m81",[["ACE_bodyBag",1],["rhs_mag_30Rnd_556x45_M855_Stanag",12,30],["tsp_flashbang_cts2",8,1],["rhs_mag_m67",2,1]]],"H_Simc_mich_anvis_bare","G_LEN_TG2_weiss",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Recon - Section Leader",
                    [[["simc_mk18_ras_kac_VFG","rhsusf_acc_nt4_black","CUP_acc_ANPEQ_2_Flashlight_Black_L","rhsusf_acc_ACOG",["rhs_mag_30Rnd_556x45_M855_Stanag",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["rhsusf_weap_m9","","","",["rhsusf_mag_15Rnd_9x19_JHP",15],[],""],["U_simc_bdu_03_raid_blench_trop_alt",[["kat_IFAK",1]]],["V_Simc_LEN_FOX_AWS_m81_LC2_1",[["ACE_Flashlight_XL50",1],["ACRE_PRC148",1],["ACE_microDAGR",1],["rhs_mag_m67",2,1],["rhsusf_mag_15Rnd_9x19_FMJ",1,15],["rhs_mag_an_m8hc",2,1],["rhs_mag_30Rnd_556x45_M855_Stanag",10,30]]],["B_simc_US_Molle_sturm_m81_sturm",[["FirstAidKit",2],["tsp_flashbang_cts2",1,1],["rhs_mag_m67",2,1]]],"H_Simc_mich_anvis_bare_TASC_b_strobe","rhs_googles_clear",["Binocular","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis_green"]],[["aceax_textureOptions",[]]]]
                ]
            ]
        ],
        [
            "ctbRhoBrokenWings",
            "Broken Wings (RHO)",
            [
                [
                    "Platoon Leader",
                    [[["ACWP_M4A5_145_troy_KAG_BLK_NET","acwp_rc1_net","WMLX_L_PEQ_T_IR_camo_tan","acwp_t2_net_g33_down",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["TFB_AVS_Comms_1_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["Karma_MosesPoleItem",1],["ACE_WaterBottle",2],["ItemAndroid",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["rhs_mag_an_m8hc",2,1],["ACE_M84",2,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["acex_intelitems_notepad",1,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",10,30],["rho_rar_handgrenade_f1",2,1]]],["ranger_pack_5",[]],"rho_rar_airframe_ir_bat_comtac_amcu","G_oak_2_cut",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_BLK2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Platoon Medic",
                    [[["ACWP_M4A5_105_troy_ROE_BLK_DON","acwp_rc1_tan_don","","acwp_eotech_don_g33_down",["ACWP_30rnd_556x45_EPR_PMAG_don",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["TFB_JPC_Assaulter_13_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ItemAndroid",1],["rhs_mag_an_m8hc",4,1],["ACE_M84",2,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_PMAG",10,30],["rho_rar_handgrenade_f1",2,1]]],["ranger_pack_5",[["ACE_salineIV",4],["ACE_salineIV_500",6],["ACE_splint",8],["ACE_suture",1],["kat_MFAK",1],["ACE_bodyBag",6],["KJW_MedicalExpansion_IV",1],["KJW_MedicalExpansion_SampleKit",4],["ACE_adenosine",2],["ACE_surgicalKit",1],["ACE_personalAidKit",1]]],"rho_rar_tw_exfil2025_comtac_ir_bat_scrim1","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_MID_TAN"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "JTAC",
                    [[["ACWP_M4A5_145_7rail_GL_grip_don","acwp_rc1_don","M300_R_PEQ_T_IR_camo_don","rhsusf_acc_su230_mrds_c",["ACWP_30rnd_556x45_EPR_PMAG_don",30],["UGL_FlareCIR_F",1],""],[],["Worm_IZLIDB","","","",[],[],""],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["TFB_AVS_Comms_3_MPU5",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemcTab",1],["rhs_mag_an_m8hc",1,1],["ACE_M84",2,1],["Laserbatteries",2,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",10,30],["rho_rar_handgrenade_f1",2,1],["rhs_mag_M433_HEDP",10,1],["UGL_FlareCIR_F",3,1],["rhs_mag_m713_Red",2,1]]],["TFB_275_117G3",[["ACE_WaterBottle",1],["ACE_Flashlight_XL50",1],["ACRE_PRC117F",1],["acex_intelitems_notepad",1,1],["rhs_mag_m713_Red",8,1],["rhs_mag_m715_Green",4,1],["1Rnd_SmokeGreen_Grenade_shell",4,1],["1Rnd_SmokeBlue_Grenade_shell",4,1]]],"rho_rar_airframe_ir_bat_comtac_arc_amcu","rho_reconwrap_03_glasses_tan",["Laserdesignator_01_khk_F","","","",[],[],""],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch","USP_PVS31_WP_LOW_TAN"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Drone Operator",
                    [[[],[],[],["U_tweed_acu_summer_ocp_g",[["kat_IFAK",1],["ACRE_PRC152",1],["white_monster",18]]],[],[],"H_tweed_Hat_Patrol_ocp","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Platoon Sergeant",
                    [[["ACWP_M4A5_105_troy_AFG_BLK_TAN","acwp_rc1_tanp","WMLX_L_PEQ_T_IR_camo_tan","TOTT_t2_unity_blk",["ACWP_30rnd_556x45_EPR_PMAG_tan",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["TFB_AVS_Assaulter_15_MPU5",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["Karma_MosesPoleItem",1],["ACE_WaterBottle",2],["ItemAndroid",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["rhs_mag_an_m8hc",2,1],["ACE_M84",4,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["acex_intelitems_notepad",1,1],["ACWP_30rnd_556x45_EPR_PMAG_tan",10,30],["rho_rar_handgrenade_f1",4,1]]],[],"rho_rar_tw_exfil2025_comtac_ir_bat","G_oak_1_cut",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_HIGH_BLK2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Section Commander",
                    [[["ACWP_M4A5_105_troy_AFG_BLK_TAN","acwp_rc1_tanp","M620_R_PEQ_T_IR_camo_tan","TOTT_t2_unity_G33",["ACWP_30rnd_556x45_EPR_PMAG_tan",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked_Rolled_MC_Gloves",[["kat_IFAK",1]]],["TFB_AVS_Comms_7_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["Karma_MosesPoleItem",1],["ACE_WaterBottle",2],["ItemAndroid",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["rhs_mag_an_m8hc",2,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["acex_intelitems_notepad",1,1],["ACWP_30rnd_556x45_EPR_PMAG_tan",10,30],["rho_rar_handgrenade_f1",4,1],["tsp_flashbang_cts2",4,1]]],[],"rho_rar_airframe_ir_bat_comtac_arc_mc","rho_reconwrap_01_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_HIGH_BLK2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman CFA",
                    [[["ACWP_M4A5_145_ris_MOD3_don","acwp_rc1_cover_amcu","WMLX_L_PEQ_T_IR_camo_don","acwp_t2_don",["ACWP_30rnd_556x45_EPR_PMAG_don",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["TFB_JPC_Assaulter_2_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["rhs_mag_an_m8hc",4,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["ACWP_30rnd_556x45_EPR_PMAG_don",10,30],["rho_rar_handgrenade_f1",3,1],["tsp_flashbang_cts2",4,1]]],["USMC_Backpack_TT_JPC",[["kat_MFAK",1]]],"rho_rar_airframe_ir_bat_amcu","G_Bandanna_oli",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_TAN2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "3: Rifleman (AT)",
                    [[["ACWP_M4A5_105_troy_ROE_BLK_DON","acwp_rc1_cover_amcu","WMLX_L_PEQ_T_IR_camo_don","rhsusf_acc_su230_mrds_c",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["TFB_JPC_Assaulter_13_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["rhs_mag_an_m8hc",1,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_PMAG",14,30],["rho_rar_handgrenade_f1",4,1],["tsp_flashbang_cts2",6,1]]],["TFB_275_JPCPACK1",[]],"rho_rar_airframe_ir_bat_comtac_mc","rho_reconwrap_mc_07_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_MID_BLK"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "4: Autorifleman",
                    [[["Tier1_M249_light_S_Desert","acwp_rc1_tan","Tier1_M249_LA5_M600V","rhsusf_acc_su230_mrds_c",["rhsusf_200Rnd_556x45_mixed_soft_pouch_coyote",200],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["TFB_AVS_Weapons_5_152",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["rhs_mag_an_m8hc",1,1],["rhs_mag_m67",2,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhsusf_200Rnd_556x45_mixed_soft_pouch_coyote",4,200],["tsp_flashbang_cts2",2,1]]],[],"rho_rar_airframe_ir_bat_comtac_amcu","rho_reconwrap_04_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_MID_BLK"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "5: Grenadier",
                    [[["ACWP_M4A5_145_7rail_GL_grip_net","acwp_rc1_cover_mc","Tier1_M4BII_NGAL_M600V","rhsusf_acc_su230_mrds_c",["ACWP_30rnd_556x45_EPR_PMAG_net",30],["rhs_mag_M433_HEDP",1],""],[],["ACWP_USP_TAN","","","",["ACWP_20Rnd_9x21_Mag_USP_TAN",20],[],""],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["TFB_AVS_Assaulter_2_152A",[["Tier1_30Rnd_556x45_M855A1_EMag",10,30],["ACWP_20Rnd_9x21_Mag_USP_TAN",2,20],["tsp_flashbang_cts2",4,1],["rho_rar_handgrenade_f1",2,1],["rhs_mag_M433_HEDP",16,1],["ACE_40mm_Flare_ir",4,1],["rhs_mag_m714_White",2,1]]],["TFB_275_AVS_Backpack",[]],"rho_rar_airframe_ir_bat_mc","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_MID_BLK2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Breacher",
                    [[["ACWP_M4A5_145_troy_base_BLK_TAN","acwp_rc1_tanp","M620_L_PEQ_T_IR_camo_tan","tfb_unity_fast",["ACWP_30rnd_556x45_EPR_PMAG_tan",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["TFB_AVS_Assaulter_4_148",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_M26_Clacker",1],["ACE_Flashlight_XL50",1],["ACE_DefusalKit",1],["tsp_breach_shock",1],["rhs_mag_an_m8hc",1,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rho_rar_handgrenade_f1",4,1],["tsp_flashbang_cts2",4,1],["ACE_CTS9",2,1],["ACWP_30rnd_556x45_EPR_PMAG_tan",12,30]]],["ranger_pack_5",[["tsp_breach_shock",1],["DemoCharge_Remote_Mag",4,1],["tsp_breach_linear_mag",4,1],["tsp_breach_package_mag",2,1],["tsp_breach_stick_mag",2,1],["tsp_breach_popper_auto_mag",6,1],["tsp_breach_silhouette_mag",1,1]]],"rho_rar_tw_exfil2025_comtac_ir_bat_scrim3","rho_reconwrap_07_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_LOW_TAN"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Ammo Bearer (mk48)",
                    [[["ACWP_M4A5_105_troy_AFG_BLK_DON","acwp_rc1_cover_amcu","WMLX_L_PEQ_T_IR_camo_don","rhsusf_acc_su230_mrds_c",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["TFB_JPC_Assaulter_2_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["rhs_mag_an_m8hc",1,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rho_rar_handgrenade_f1",4,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",14,30],["tsp_flashbang_cts2",6,1]]],["TFB_275_JPC_Backpack",[["ranger_100rnd_762_EPR",6,100]]],"rho_rar_airframe_ir_bat_mc","G_comba_2",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_MID_BLK"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Machine Gunner (mk48)",
                    [[["75th_ranger_mk48","","75th_Ranger_sideMK48_LASER","75th_Eotech_EXPS3_up",["ranger_100rnd_762_EPR",100],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["TFB_AVS_Weapons_2_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["rhs_mag_an_m8hc",1,1],["rhs_mag_m67",2,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["ACE_SpareBarrel",1,1],["ranger_100rnd_762_EPR",5,100],["tsp_flashbang_cts2",2,1]]],[],"rho_rar_tw_exfil2025_comtac_ir_bat_scrim1","rho_reconwrap_01_glasses_tan",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_MID_BLK"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Ammo Bearer (240)",
                    [[["ACWP_M4A5_105_troy_ROE_BLK_TAN","acwp_rc1_cover_amcu","WMLX_L_PEQ_T_IR_tan_camo_tan","rhsusf_acc_su230_mrds_c",["ACWP_30rnd_556x45_EPR_PMAG_tan",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["TFB_JPC_Assaulter_13_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["rhs_mag_an_m8hc",1,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rho_rar_handgrenade_f1",4,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",14,30],["tsp_flashbang_cts2",6,1]]],["TFB_275_JPC_Backpack",[["Tier1_100Rnd_762x51_Belt_M80A1_EPR",6,100]]],"rho_rar_airframe_ir_bat_comtac_amcu","rho_reconwrap_07_glasses_tan",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_MID_BLK"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Machine Gunner (240)",
                    [[["75th_Ranger_m240L","","75th_Ranger_sideM240L_LASER","75th_SU230B",["Tier1_250Rnd_762x51_Belt_M80A1_EPR",250],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["TFB_AVS_Comms_6_MPU5",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["rhs_mag_an_m8hc",1,1],["ACE_M84",2,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["ACE_SpareBarrel",1,1],["Tier1_250Rnd_762x51_Belt_M80A1_EPR",2,250],["Tier1_100Rnd_762x51_Belt_M80A1_EPR",1,100]]],[],"rho_rar_airframe_ir_bat_comtac_amcu","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_MID_BLK"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Sniper A",
                    [[["121_Geissele_MRGG_Paint","121_NIGHTOWL_PAINT","121_USASOC_STORM_SLX_Paint_Laser","121_USASOC_RVPS_ANPVS30_PAINT",["121_pmag_paint_65_Creedmoor_20rnd",20],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["TFB_AVS_Light_2_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["rhs_mag_an_m8hc",1,1],["ACE_M84",6,1],["ACWP_19Rnd_9x21_Mag_glock",4,19],["rho_rar_handgrenade_f1",4,1],["121_pmag_paint_65_Creedmoor_20rnd",10,20]]],["TFB_275_JPCPACK1",[["121_pmag_paint_65_Creedmoor_20rnd",4,20]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_01_glasses_tan",["ACE_MX2A","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_MID_BLK"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Sniper B",
                    [[["121_Geissele_MRGG_Paint","121_NIGHTOWL_PAINT","121_USASOC_Raptar_Paint_Laser","121_USASOC_RVPS_ANPVS30_PAINT",["121_pmag_paint_65_Creedmoor_20rnd",20],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["TFB_AVS_Assaulter_4_148",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_M26_Clacker",1],["ACE_Flashlight_XL50",1],["ACE_DefusalKit",1],["tsp_breach_shock",1],["rhs_mag_an_m8hc",1,1],["ACE_M84",2,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rho_rar_handgrenade_f1",2,1],["tsp_flashbang_cts2",2,1],["ACE_CTS9",2,1],["121_pmag_paint_65_Creedmoor_20rnd",12,20]]],["ranger_pack_5",[["121_tripod_item",1],["DemoCharge_Remote_Mag",4,1],["tsp_breach_linear_mag",4,1],["tsp_breach_package_mag",2,1],["tsp_breach_stick_mag",2,1],["tsp_breach_popper_auto_mag",6,1],["121_pmag_paint_65_Creedmoor_20rnd",4,20]]],"rho_rar_tw_exfil2025_comtac_ir_bat_scrim3","rho_reconwrap_07_glasses",["121_spotting_scope_handheld","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USP_PVS31_WP_TAR_LOW_TAN"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Pilot",
                    [[["rhs_weap_mk18_urgi_kac","rhsusf_acc_SF3P556_hidden","Tier1_Mk18_NGAL_M300C","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["SOAR_Flight_4_uniform",[["kat_IFAK",1]]],["AVS_Flight_5_Water",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_Stanag",4,30],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",1,1]]],[],"rhsusf_hgu56p_mask","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Co-Pilot",
                    [[["rhs_weap_mk18_urgi_kac","rhsusf_acc_SF3P556_hidden","Tier1_Mk18_NGAL_M600V_Black_FL","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["SOAR_Flight_4_uniform",[["kat_IFAK",1]]],["AVS_Flight_7_Water",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_Stanag",4,30],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",1,1]]],[],"rhsusf_hgu56p","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Crew Chief",
                    [[["rhs_weap_mk18_urgi_kac","rhsusf_acc_SF3P556_hidden","Tier1_Mk18_NGAL_M300C_Black","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["SOAR_Flight_9_uniform",[["kat_IFAK",1]]],["AVS_Flight_6_Water",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_Stanag",6,30],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",1,1]]],[],"rhsusf_hgu56p_mask_mo","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Crew",
                    [[["rhs_weap_mk18_urgi_kac","rhsusf_acc_SF3P556_hidden","Tier1_Mk18_NGAL_M300C","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["SOAR_Flight_4_uniform",[["kat_IFAK",1]]],["AVS_Flight_4_Water",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_Stanag",4,30],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",2,1]]],[],"rhsusf_hgu56p_mask","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis"]],[["aceax_textureOptions",[]]]]
                ]
            ]
        ],
        [
            "ctbRhoGildedTrident",
            "Gilded Trident (RHO)",
            [
                [
                    "Platoon Leader",
                    [[["rhs_weap_m4_urgi_kac","acwp_rc1_tanp","Tier1_M4BII_NGAL_M300C_Black","tfb_eotech",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_mc_3",[["kat_IFAK",1]]],["TFB_AVS_Comms_1_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["Karma_MosesPoleItem",1],["ACE_WaterBottle",2],["ItemAndroid",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["slr_slingload_CargoSling",4],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",2,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",10,30],["ACWP_19Rnd_9x21_Mag_glock",2,19],["acex_intelitems_notepad",1,1]]],[],"Maritime_Cover_ComtacIII_Arc15","",["rhsusf_bino_lrf_Vector21","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Platoon Medic",
                    [[["rhs_weap_mk18_urgi_kac","acwp_rc1","Tier1_M4BII_NGAL_M600V_Black_FL","tfb_unity_fast",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_mc_3",[["kat_IFAK",1]]],["TFB_JPC_Assaulter_13_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ItemAndroid",1],["rhs_mag_an_m8hc",6,1],["rhs_mag_m67",4,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_PMAG",10,30]]],["ranger_pack_5",[["ACE_suture",1],["ACE_surgicalKit",1],["ACE_bodyBag",8],["kat_MFAK",1],["kat_ketamine",2],["ACE_salineIV_500",6],["ACE_salineIV",4]]],"Maritime_Cover_AMP15","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "JTAC",
                    [[["rhs_weap_mk18_m320","acwp_rc1_tanp","Tier1_M4BII_NGAL_M300C_Black","rhsusf_acc_su230_mrds_c",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],["rhs_mag_M433_HEDP",1],""],[],["Worm_IZLIDB","","","",[],[],""],["ranger_patagonia_tab_r_jtac_mc_3",[["kat_IFAK",1]]],["TFB_AVS_Comms_3_MPU5",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["rhs_mag_an_m8hc",1,1],["rhs_mag_m67",2,1],["ACE_M84",2,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",8,30],["Laserbatteries",2,1],["1Rnd_SmokeRed_Grenade_shell",14,1],["1Rnd_SmokePurple_Grenade_shell",4,1],["1Rnd_SmokeBlue_Grenade_shell",4,1],["ACE_40mm_Flare_ir",2,1]]],["TFB_275_117G3",[["ACRE_PRC117F",1],["ACE_WaterBottle",1],["ACE_Flashlight_XL50",1],["rhs_mag_M433_HEDP",7,1],["acex_intelitems_notepad",1,1]]],"275_BLACKOUT_HEADGEAR_LA11A","G_tweed_tacticool_weiss",["Laserdesignator_01_khk_F","","","",[],[],""],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Platoon Sergeant",
                    [[["rhs_weap_m4_urgi_kac","acwp_rc1_tan","Tier1_M4BII_NGAL_M600V","tfb_unity_fast",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_r_mc_3",[["kat_IFAK",1]]],["TFB_AVS_Assaulter_12_MPU5",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["ItemAndroid",1],["ACRE_PRC152",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",14,30],["ACWP_19Rnd_9x21_Mag_glock",2,19],["tsp_flashbang_cts2",2,1]]],["ranger_panel1",[]],"275_BLACKOUT_HEADGEAR_LA17_2","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Section Leader",
                    [[["rhs_weap_m4_urgi_kac","acwp_rc1_tanp","Tier1_M4BII_NGAL_M300C_Black","tfb_vortex_razor5",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_mc_3",[["kat_IFAK",1]]],["TFB_AVS_Comms_7_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["Karma_MosesPoleItem",1],["ACE_WaterBottle",2],["ItemAndroid",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",12,30],["ACWP_19Rnd_9x21_Mag_glock",2,19],["acex_intelitems_notepad",1,1],["tsp_flashbang_cts2",2,1]]],[],"275_BLACKOUT_HEADGEAR_AMP","G_tweed_tacticool_weiss",["rhsusf_bino_lrf_Vector21","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman CFA",
                    [[["rhs_weap_mk18_urgi_kac","acwp_rc1","Tier1_M4BII_NGAL_M600V_Black_FL","tfb_unity_fast",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_mc_3",[["kat_IFAK",1]]],["TFB_JPC_Assaulter_13_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ItemAndroid",1],["rhs_mag_an_m8hc",6,1],["rhs_mag_m67",2,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_PMAG",10,30]]],["ranger_pack_5",[["ACE_suture",1],["ACE_surgicalKit",1],["ACE_bodyBag",6],["kat_MFAK",1],["kat_ketamine",2]]],"Maritime_Cover_AMP15","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman (AT)",
                    [[["rhs_weap_m4_urgi_kac","acwp_rc1_tan","Tier1_M4BII_NGAL_M600V","tfb_unity_fast",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],["rhs_weap_M136","","","",[],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_r_mc_2",[["kat_IFAK",1]]],["TFB_AVS_Assaulter_10_148",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["ItemAndroid",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",14,30],["ACWP_19Rnd_9x21_Mag_glock",2,19],["tsp_flashbang_cts2",2,1]]],["ranger_panel1",[["rhsusf_200Rnd_556x45_M855_mixed_soft_pouch_coyote",1,200]]],"275_BLACKOUT_HEADGEAR_LA17_2","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Autorifleman",
                    [[["Tier1_M249_light_S_Desert","acwp_rc1_tan","Tier1_M249_LA5_M600V","rhsusf_acc_su230_mrds_c",["rhsusf_200Rnd_556x45_mixed_soft_pouch_coyote",200],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_mc_3",[["kat_IFAK",1]]],["TFB_AVS_Weapons_5_152",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["ItemAndroid",1],["rhs_mag_an_m8hc",1,1],["rhs_mag_m67",2,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhsusf_200Rnd_556x45_mixed_soft_pouch_coyote",4,200]]],[],"275_BLACKOUT_HEADGEAR_LA12","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Grenadier",
                    [[["rhs_weap_m4_urgi_kac","acwp_rc1","Tier1_M4BII_NGAL_M600V","rhsusf_acc_su230_mrds_c",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["rhs_weap_M320","","","",["rhs_mag_M433_HEDP",1],[],""],["ranger_acu2_tab_item",[["kat_IFAK",1]]],["TFB_JPC_Assaulter_13_152A",[["ItemAndroid",1],["Tier1_30Rnd_556x45_M855A1_EMag",12,30],["rhs_mag_M433_HEDP",10,1],["ACE_40mm_Flare_ir",4,1],["tsp_flashbang_cts2",2,1],["rhs_mag_m67",4,1],["rhs_mag_an_m8hc",2,1]]],["ranger_panel3",[["rhs_mag_M433_HEDP",16,1],["rhs_mag_m714_White",2,1]]],"275_BLACKOUT_HEADGEAR_LA17","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Breacher",
                    [[["rhs_weap_mk18_urgi","acwp_rc1_tanp","Tier1_M4BII_NGAL_M300C_Black","tfb_unity_fast",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_r_eod_mc",[["kat_IFAK",1]]],["TFB_AVS_Assaulter_4_148",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_M26_Clacker",1],["ACE_Flashlight_XL50",1],["ACE_DefusalKit",1],["ItemAndroid",1],["rhs_mag_an_m8hc",4,1],["rhs_mag_m67",4,1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_PMAG",10,30],["tsp_flashbang_cts2",2,1]]],["ranger_pack_5",[["tsp_breach_shock",1],["ACE_Clacker",1],["DemoCharge_Remote_Mag",4,1],["tsp_breach_dip_auto_mag",2,1],["tsp_breach_linear_mag",4,1],["tsp_breach_package_mag",2,1],["tsp_breach_silhouette_mag",1,1],["tsp_breach_stick_mag",2,1]]],"275_BLACKOUT_HEADGEAR_LA14_2","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Ammo Bearer",
                    [[["rhs_weap_m4_urgi_kac","acwp_rc1_tanp","Tier1_M4BII_NGAL_M300C_Black","rhsusf_acc_su230_mrds_c",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_mc_3",[["kat_IFAK",1]]],["TFB_JPC_Assaulter_13_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ItemAndroid",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",12,30],["ACWP_19Rnd_9x21_Mag_glock",2,19]]],["TFB_275_JPC_Backpack",[["ACE_WaterBottle",2],["ACE_SpareBarrel",1,1],["Tier1_100Rnd_762x51_Belt_M80A1_EPR",6,100]]],"75th_opscore_b3","G_tweed_tacticool_weiss",["rhsusf_bino_lrf_Vector21","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Machine Gunner",
                    [[["26th_USMC_M240L","","26th_USMC_M240L_DEVICE_1_LASER","rhsusf_acc_ACOG_MDO",["Tier1_250Rnd_762x51_Belt_M80A1_EPR",250],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_acu2_tab_item",[["kat_IFAK",1]]],["TFB_AVS_Weapons_2_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["ItemAndroid",1],["rhs_mag_an_m8hc",1,1],["rhs_mag_m67",2,1],["ACWP_19Rnd_9x21_Mag_glock",4,19],["ACE_SpareBarrel",1,1],["Tier1_250Rnd_762x51_Belt_M80A1_EPR",2,250]]],["ranger_panel1",[["ACE_Canteen",2],["ACE_SpareBarrel",1,1],["Tier1_250Rnd_762x51_Belt_M80A1_EPR",1,250]]],"275_BLACKOUT_HEADGEAR_LA14D_2","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "AT Gunner",
                    [[["rhs_weap_m4_urgi_kac","acwp_rc1_tanp","Tier1_M4BII_NGAL_M300C_Black","rhsusf_acc_su230_mrds_c",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],["launch_MRAWS_green_F","","rhsusf_acc_anpeq16a","",["rhs_mag_maaws_HEDP",1],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_mc_3",[]],["TFB_AVS_Assaulter_2_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_WaterBottle",2],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",2,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",12,30],["ACWP_19Rnd_9x21_Mag_glock",2,19]]],["TFB_275_AVS_Backpack",[["BB_RHS_MAAWS_HE_AB",2,1],["MAA_MAAWS_HEDP502",2,1],["MAA_MAAWS_SMOKE469",2,1]]],"Maritime_Cover_ComtacIII_Arc15","G_tweed_tacticool_weiss",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Asst. AT Gunner",
                    [[["rhs_weap_m4_urgi_kac","acwp_rc1_tanp","Tier1_M4BII_NGAL_M300C_Black","rhsusf_acc_su230_mrds_c",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["ranger_patagonia_tab_r_mc",[["kat_IFAK",1]]],["TFB_JPC_Assaulter_11_152A",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1],["rhs_mag_30Rnd_556x45_M855A1_PMAG",12,30],["ACWP_19Rnd_9x21_Mag_glock",2,19]]],["TFB_275_JPC_Backpack",[["MAA_MAAWS_SMOKE469",2,1],["MAA_MAAWS_HEDP502",2,1],["BB_RHS_MAAWS_HE_AB",2,1]]],"275_BLACKOUT_HEADGEAR_LA14D","G_tweed_tacticool_weiss",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch","ranger_nvg2"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Pilot",
                    [[["rhs_weap_mk18_urgi_kac","rhsusf_acc_SF3P556_hidden","Tier1_Mk18_NGAL_M300C","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["SOAR_Flight_4_uniform",[["kat_IFAK",1]]],["AVS_Flight_5_Water",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_Stanag",4,30],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",1,1]]],[],"rhsusf_hgu56p_mask","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Co-Pilot",
                    [[["rhs_weap_mk18_urgi_kac","rhsusf_acc_SF3P556_hidden","Tier1_Mk18_NGAL_M600V_Black_FL","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["SOAR_Flight_4_uniform",[["kat_IFAK",1]]],["AVS_Flight_7_Water",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_Stanag",4,30],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",1,1]]],[],"rhsusf_hgu56p","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Crew Chief",
                    [[["rhs_weap_mk18_urgi_kac","rhsusf_acc_SF3P556_hidden","Tier1_Mk18_NGAL_M300C_Black","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["SOAR_Flight_9_uniform",[["kat_IFAK",1]]],["AVS_Flight_6_Water",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_Stanag",6,30],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",1,1]]],[],"rhsusf_hgu56p_mask_mo","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Crew",
                    [[["rhs_weap_mk18_urgi_kac","rhsusf_acc_SF3P556_hidden","Tier1_Mk18_NGAL_M300C","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["SOAR_Flight_4_uniform",[["kat_IFAK",1]]],["AVS_Flight_4_Water",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["rhs_mag_30Rnd_556x45_M855A1_Stanag",4,30],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",2,1]]],[],"rhsusf_hgu56p_mask","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ]
            ]
        ],
        [
            "ctbRhoOpSilver",
            "Silver Lance (RHO)",
            [
                [
                    "Platoon Leader",
                    [[["vn_m16","","","",["vn_m16_20_mag",18],[],""],[],["vn_m1911","","","",["vn_m1911_mag",7],[],""],["U_Simc_OG107_mk3_tuck",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_M43_45_ass",[["vn_m16_20_mag",11,18],["vn_m61_grenade_mag",1,1],["vn_m1911_mag",2,7]]],[],"H_Simc_M1C_bitch_op","",["Binocular","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "PL Medic",
                    [[["vn_m16","","","",["vn_m16_20_mag",18],[],""],[],["vn_m1911","","","",["vn_m1911_mag",7],[],""],["U_Simc_OG107_mk3_tuck",[["ACE_fieldDressing",10],["ACE_quikclot",2],["ACE_packingBandage",2],["ACE_elasticBandage",2],["ACE_morphine",2],["ACE_splint",1],["ACE_tourniquet",2],["ACE_Flashlight_MX991",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_med",[["vn_m16_20_mag",14,18],["vn_m61_grenade_mag",2,1],["vn_m1911_mag",2,7],["vn_m18_white_mag",2,1]]],["B_simc_pack_frem_med5",[["kat_MFAK",1],["ACE_salineIV",4],["ACE_salineIV_500",6],["ACE_salineIV_250",8]]],"H_Simc_M1_bitch_Cl","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Radio Operator",
                    [[["vn_m16","","","",["vn_m16_20_mag",18],[],""],[],[],["U_Simc_TCU_mk1_trop",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_frag_alt",[["vn_m16_20_mag",15,18],["vn_m61_grenade_mag",2,1]]],["B_simc_rajio_M43_1",[["ACRE_PRC77",1],["SmokeShellOrange",2,1],["SmokeShellPurple",2,1],["SmokeShellYellow",2,1],["SmokeShellBlue",2,1],["vn_m16_20_mag",2,18]]],"H_Simc_M1_bitch_op","",["Binocular","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Joint Fires Observer",
                    [[["vn_m16","","","",["vn_m16_20_mag",18],[],""],[],["vn_m79_p","","","",["vn_40mm_m381_he_mag",1],[],""],["U_Simc_OG107_mk3_trop",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56",[["vn_m16_20_mag",13,18],["vn_m61_grenade_mag",1,1]]],["B_simc_rajio_Frem_2",[["ACRE_PRC77",1],["vn_m18_red_mag",4,1],["vn_40mm_m682_smoke_r_mag",10,1],["vn_40mm_m716_smoke_y_mag",5,1],["vn_40mm_m717_smoke_p_mag",5,1],["vn_40mm_m715_smoke_g_mag",1,1]]],"H_Simc_M1C_bitch_b6","",["vn_m19_binocs_grn","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Squad Leader",
                    [[["vn_m16","","","",["vn_m16_20_mag",18],[],""],[],[],["U_Simc_TCU_mk2_roll",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_bandoleer",[["grad_paceCountBeads_functions_paceCountBeads",1],["vn_m16_20_mag",14,18],["vn_m61_grenade_mag",4,1],["vn_m18_white_mag",2,1]]],["B_simc_US_asspack_full",[["vn_m16_20_t_mag",2,18],["vn_m16_20_mag",12,18]]],"H_Simc_M1_bitch_low_op","G_simc_US_Bandoleer_556",["Binocular","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Scout",
                    [[["vn_m16","","vn_b_m16","",["vn_m16_40_mag",36],[],""],[],["vn_mx991_m1911","","","",["vn_m1911_mag",7],[],""],["U_Simc_TCU_mk1_trop",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_claymore_band",[["vn_m61_grenade_mag",2,1],["vn_mine_m18_mag",1,1],["vn_mine_m18_range_mag",2,1],["vn_m16_40_t_mag",4,36],["vn_m16_40_mag",3,36]]],["B_simc_US_asspack_61_roll",[["grad_paceCountBeads_functions_paceCountBeads",1],["vn_m16_20_mag",13,18],["vn_m61_grenade_mag",1,1]]],"H_Simc_M1_bitch_low_op","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman",
                    [[["vn_m16","","","",["vn_m16_20_mag",18],[],""],[],["vn_mx991_m1911","","","",["vn_m1911_mag",7],[],""],["U_Simc_TCU_mk1_trop",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_M43_frags",[["vn_b_m16",1],["vn_m61_grenade_mag",2,1],["vn_mine_m18_mag",1,1],["vn_mine_m18_range_mag",2,1],["vn_m16_20_mag",10,18]]],["B_simc_US_asspack_56_botol",[["grad_paceCountBeads_functions_paceCountBeads",1],["ACE_Flashlight_MX991",1],["vn_m16_20_mag",13,18]]],"H_Simc_M1_bitch_op","G_simc_US_Bandoleer_556_low",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman 2IC",
                    [[["vn_m16","","","",["vn_m16_20_mag",18],[],""],[],["vn_mx991_m1911","","","",["vn_m1911_mag",7],[],""],["U_Simc_TCU_mk1_trop",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_M43_frags",[["vn_b_m16",1],["vn_m61_grenade_mag",2,1],["vn_mine_m18_mag",1,1],["vn_mine_m18_range_mag",2,1],["vn_m16_20_mag",10,18]]],["B_simc_US_asspack_56_botol",[["grad_paceCountBeads_functions_paceCountBeads",1],["ACE_Flashlight_MX991",1],["vn_m16_20_mag",13,18]]],"H_Simc_M1_bitch_op","G_simc_US_Bandoleer_556_low",["Binocular","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Machine Gunner",
                    [[["vn_m60","","","",["vn_m60_100_mag",100],[],""],[],["vn_m1911","","","",["vn_m1911_mag",7],[],""],["U_Simc_TCU_mk2_roll",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_60_doppel_ligt",[["vn_m61_grenade_mag",2,1],["vn_m1911_mag",2,7],["vn_m60_100_mag",4,100]]],["B_simc_pack_frem_6_alt",[["ACE_Canteen",1],["vn_m1911_mag",4,7],["vn_m60_100_mag",6,100],["ACE_SpareBarrel",1,1]]],"H_Simc_M1_bitch_b","G_simc_US_Bandoleer_60",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Machine Gunner Assistant",
                    [[["vn_m16","","","",["vn_m16_20_mag",18],[],""],[],[],["U_Simc_OG107_mk3_nomex_tuck",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_M43",[["vn_m16_20_mag",14,18]]],["B_simc_pack_frem_7",[["ACE_Canteen",2],["vn_m16_20_mag",8,18],["vn_m16_20_t_mag",1,18],["vn_m60_100_mag",5,100],["ACE_SpareBarrel",1,1],["vn_m61_grenade_mag",2,1]]],"H_Simc_M1_bitch_b2_alt","G_Anduk_1",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Machine Gunner Assistant 2IC",
                    [[["vn_m16","","","",["vn_m16_20_mag",18],[],""],[],[],["U_Simc_OG107_mk3_nomex_tuck",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_M43",[["vn_m16_20_mag",14,18]]],["B_simc_pack_frem_7",[["ACE_Canteen",2],["vn_m16_20_mag",8,18],["vn_m16_20_t_mag",1,18],["vn_m60_100_mag",5,100],["ACE_SpareBarrel",1,1],["vn_m61_grenade_mag",2,1]]],"H_Simc_M1_bitch_b2_alt","G_Anduk_1",["vn_m19_binocs_grey","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Grenadier (M79)",
                    [[["vn_m79","","","",["rhs_mag_M441_HE",1],["vn_40mm_m576_buck_mag",1],""],[],["rhsusf_weap_m1911a1","","","",["rhsusf_mag_7x45acp_MHP",7],[],""],["U_Simc_TCU_mk1_trop",[["ACE_fieldDressing",10],["ACE_quikclot",2],["ACE_packingBandage",2],["ACE_elasticBandage",2],["ACE_morphine",2],["ACE_splint",1],["ACE_tourniquet",2],["ACE_Flashlight_MX991",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_4cm",[["vn_m61_grenade_mag",2,1],["vn_mine_m18_mag",1,1],["vn_mine_m18_range_mag",2,1],["vn_40mm_m406_he_mag",17,1],["rhsusf_mag_7x45acp_MHP",1,7]]],["B_simc_pack_frem_4",[["grad_paceCountBeads_functions_paceCountBeads",1],["rhsusf_mag_7x45acp_MHP",4,7],["vn_40mm_m406_he_mag",20,1],["vn_40mm_m576_buck_mag",8,1],["vn_40mm_m583_flare_w_mag",10,1],["vn_40mm_m682_smoke_r_mag",10,1],["vn_40mm_m397_ab_mag",14,1]]],"H_Simc_M1_bitch_low_op","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Pilot",
                    [[[],[],["vn_m1911","","","",["vn_m1911_mag",7],[],""],["U_Simc_OG107_mk3_nomex_tuck_trop",[["kat_IFAK",1]]],["vn_b_vest_aircrew_05",[["vn_m18_purple_mag",4,1],["vn_m1911_mag",4,7]]],["vn_b_pack_prc77_01",[["ACRE_PRC77",1],["vn_m18_yellow_mag",2,1],["vn_m18_purple_mag",2,1],["vn_m18_green_mag",2,1]]],"vn_b_helmet_svh4_01_01","vn_b_aviator",[],["vn_b_item_map","","","vn_b_item_compass","vn_b_item_watch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Crew chief",
                    [[["vn_m1897","","","",["vn_m1897_fl_mag",6],[],""],[],[],["U_Simc_OG107_mk3_nomex_tuck_trop",[["kat_IFAK",1]]],["vn_b_vest_aircrew_01",[["vn_m18_purple_mag",1,1],["vn_m1897_fl_mag",3,6],["vn_m1897_buck_mag",2,6]]],["vn_b_pack_prc77_01",[["ACRE_PRC77",1],["vn_m1897_fl_mag",6,6]]],"vn_b_helmet_svh4_01_01","vn_b_aviator",[],["vn_b_item_map","","","vn_b_item_compass","vn_b_item_watch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Mortarman",
                    [[["vn_m16","","","",["vn_m16_20_mag",18],[],""],[],["vn_mx991_m1911","","","",["vn_m1911_mag",7],[],""],["U_Simc_TCU_mk1_trop",[["ACE_Flashlight_MX991",1],["kat_IFAK",1],["vn_m18_white_mag",1,1],["vn_m61_grenade_mag",1,1]]],["V_Simc_56_M43_frags",[["vn_b_m16",1],["vn_m61_grenade_mag",2,1],["vn_mine_m18_mag",1,1],["vn_mine_m18_range_mag",2,1],["vn_m16_20_mag",10,18]]],["B_simc_MC_packboard_3",[["grad_paceCountBeads_functions_paceCountBeads",1],["ACE_Flashlight_MX991",1],["ace_compat_sog_81mm_he",2,1],["vn_m16_20_mag",8,18]]],"H_Simc_M1_bitch_op","G_simc_US_Bandoleer_556_low",["Binocular","","","",[],[],""],["ItemMap","","ItemRadio","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ]
            ]
        ],
        [
            "ctbRhoResurgentDawn",
            "USMC M27 Raider (RHO)",
            [
                [
                    "Platoon Leader",
                    [[["26th_USMC_M27_IAR_AFG","","26th_USMC_416_DEVICE_3_LASER","USMC_optic_VCOG",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Cargo_G3_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_6_ATAK",[["ItemAndroid",1],["ACRE_PRC152",1],["ACRE_PRC343",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",3,1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30],["ACWP_19Rnd_9x21_Mag_glock",2,19]]],["USMC_Backpack_FILBE_JPC",[]],"USMC_Opscore_FTHS_1_MPD","rho_reconwrap_mc_07_glasses_blacklens",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Platoon Medic",
                    [[["rhs_weap_m4a1_carryhandle","","26th_USMC_M38_DEVICE_1_LASER","rhsusf_acc_ACOG2",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],[],["acwp_glock17_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Cargo_MCCUU_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_8_ATAK",[["ItemAndroid",1],["ACRE_PRC343",1],["MCC_PMAG_556_FDE_556_30_M855A1",12,30],["rhs_mag_an_m8hc",4,1]]],["USMC_Backpack_FILBE_JPC",[["ACE_salineIV",4],["ACE_salineIV_500",6],["ACE_splint",8],["ACE_suture",1],["kat_MFAK",1],["ACE_bodyBag",10],["KJW_MedicalExpansion_IV",1],["KJW_MedicalExpansion_SampleKit",4],["ACE_adenosine",2],["ACE_surgicalKit",1],["ACE_personalAidKit",1],["white_monster",1]]],"USMC_Opscore_FTHS_3_MPW","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "FO",
                    [[["ACWP_M4A5_145_7rail_GL_grip","","26th_USMC_M38_DEVICE_1_LASER","rhsusf_acc_ACOG2",["MCC_PMAG_556_FDE_556_30_M855A1",30],["UGL_FlareCIR_F",1],""],[],["Worm_IZLIDB","","","",[],[],""],["USMC_G3_MPW_1",[["kat_IFAK",1]]],["USMC_JPC_6_ATAK",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemcTab",1],["rhs_mag_an_m8hc",1,1],["Laserbatteries",2,1],["rhs_mag_m67",2,1],["rhs_mag_M433_HEDP",6,1],["MCC_PMAG_556_FDE_556_30_M855A1",12,30],["1Rnd_SmokeRed_Grenade_shell",6,1]]],["USMC_Backpack_Radio_JPC",[["ACE_WaterBottle",1],["ACE_Flashlight_XL50",1],["ACRE_PRC117F",1],["acex_intelitems_notepad",1,1],["rhs_mag_m713_Red",8,1],["rhs_mag_m715_Green",4,1],["1Rnd_SmokeGreen_Grenade_shell",4,1],["1Rnd_SmokeBlue_Grenade_shell",4,1],["1Rnd_SmokeRed_Grenade_shell",10,1],["rhs_mag_M433_HEDP",4,1],["SmokeShellRed",2,1],["SmokeShellPurple",2,1],["SmokeShellOrange",2,1],["SmokeShellGreen",2,1],["SmokeShellBlue",2,1]]],"USMC_Opscore_FTHS_1_MPW_COVER_LOOSE","rho_reconwrap_mc_07_glasses_tan",["Laserdesignator_01_khk_F","","","",[],[],""],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Platoon Sergeant",
                    [[["26th_USMC_M27_IAR_AFG","26th_USMC_RC_WRAPPED_TAN","26th_USMC_M38_DEVICE_1_LASER","USMC_optic_VCOG",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],[],["USMC_M45","","","",["11Rnd_M45_45ACP",11],[],""],["USMC_Cargo_MCCUU_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_7_NB",[["ItemAndroid",1],["ACRE_PRC152",1],["ACRE_PRC343",1],["rhs_mag_an_m8hc",1,1],["rhs_mag_m67",4,1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30]]],["USMC_Fannypack",[]],"USMC_Opscore_FTHS_3_MPW_COVER","",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Section Commander",
                    [[["26th_USMC_M27_IAR_VFG","","26th_USMC_416_DEVICE_3_LASER","rhsusf_acc_ACOG3",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_G3_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_2_ATAK",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30]]],["USMC_Backpack_Assault_JPC",[]],"USMC_Opscore_FTHS_3_MPW_COVER","rho_reconwrap_mc_07_glasses_blacklens",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman CFA",
                    [[["rhs_weap_m4a1_carryhandle","","26th_USMC_M38_DEVICE_1_LASER","rhsusf_acc_ACOG2",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],[],["acwp_glock17_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Cargo_MCCUU_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_8",[["ACRE_PRC343",1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30],["rhs_mag_an_m8hc",6,1],["ACWP_19Rnd_9x21_Mag_glock",2,19]]],["USMC_Backpack_FILBE_JPC",[["ACE_salineIV",4],["ACE_salineIV_500",6],["ACE_splint",8],["ACE_suture",1],["kat_MFAK",1],["ACE_bodyBag",6],["KJW_MedicalExpansion_IV",1],["KJW_MedicalExpansion_SampleKit",4],["ACE_adenosine",2],["ACE_surgicalKit",1],["ACE_personalAidKit",1]]],"USMC_Opscore_FTHS_3_MPW","G_tweed_tacticool_weiss",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman (AT)",
                    [[["26th_USMC_M27_IAR_AFG","","26th_USMC_416_DEVICE_3_LASER","rhsusf_acc_ACOG2",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Cargo_G3_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_3",[["ACRE_PRC343",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30],["ACWP_19Rnd_9x21_Mag_glock",2,19]]],["USMC_Backpack_Assault_JPC",[["MCC_PMAG_556_FDE_556_30_M855A1",20,30]]],"USMC_Opscore_FTHS_3_MPW","rho_reconwrap_mc_07_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Autorifleman",
                    [[["26th_USMC_M27_IAR_VFG","","26th_USMC_M38_DEVICE_1_LASER","rhsusf_acc_ACOG3_USMC",["26th_USMC_PMAG_TAN_556x45_M855A1",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Cargo_G3_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_1",[["ACRE_PRC343",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30],["ACWP_19Rnd_9x21_Mag_glock",2,19]]],["USMC_Backpack_Assault_JPC",[["MCC_PMAG_556_FDE_556_30_M855A1",16,30]]],"USMC_Opscore_FTHS_3_MPW_COVER","rho_reconwrap_04_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Grenadier",
                    [[["26th_USMC_M27_IAR_AFG","","26th_USMC_M38_DEVICE_1_LASER","USMC_optic_VCOG",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],[],["rhs_weap_M320","","","",["rhs_mag_M433_HEDP",1],[],""],["USMC_Cargo_G3_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_4_NB",[["ACRE_PRC343",1],["MCC_PMAG_556_FDE_556_30_M855A1",13,30],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",2,1]]],["USMC_M320_Belt_JPC",[["rhs_mag_M433_HEDP",20,1],["1Rnd_Smoke_Grenade_shell",6,1],["1Rnd_RC40_shell_RF",2,1],["1Rnd_RC40_HE_shell_RF",2,1]]],"USMC_Opscore_FTHS_2_MPW","rho_reconwrap_mc_07_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Engineer",
                    [[["26th_USMC_M27_IAR_VFG","","26th_USMC_416_DEVICE_3_LASER","rhsusf_acc_ACOG2_USMC",["ACWP_30rnd_556x45_EPR_PMAG_tan",30],[],""],[],["USMC_M18","","","",["18Rnd_M18_9x19_FMJ",18],[],""],["USMC_Cargo_G3_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_4",[["ACRE_PRC343",1],["rhs_mag_an_m8hc",4,1],["rhs_mag_m67",4,1],["MCC_PMAG_556_FDE_556_30_M855A1",12,30],["18Rnd_M18_9x19_JHP",2,18]]],["USMC_Backpack_FILBE_JPC",[["tsp_breach_shock",1],["ace_flags_blue",8],["ace_marker_flags_purple",10],["ACE_Clacker",1],["ACE_wirecutter",1],["DemoCharge_Remote_Mag",6,1],["tsp_breach_linear_mag",2,1],["tsp_breach_popper_auto_mag",2,1],["OBS_Personal_Mag",1,1],["rhs_mag_an_m8hc",6,1]]],"USMC_Opscore_FTHS_1_MPW_COVER","rho_reconwrap_mc_05_glasses_blacklens",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Assist Gunner",
                    [[["rhs_weap_m4a1_carryhandle","","26th_USMC_416_DEVICE_3_LASER","rhsusf_acc_ACOG2",["rhs_mag_30Rnd_556x45_M855A1_PMAG",30],[],""],["rhs_weap_m72a7","","","",[],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Cargo_G3_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_2",[["ACRE_PRC343",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30],["ACWP_19Rnd_9x21_Mag_glock",2,19]]],["USMC_Backpack_FILBE_JPC",[["ACE_Canteen",2],["Tier1_250Rnd_762x51_Belt_M80A1_EPR",2,250],["Tier1_100Rnd_762x51_Belt_M80A1_EPR",4,100],["ACE_SpareBarrel",1,1]]],"USMC_Opscore_FTHS_2_MPW","G_comba_2",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Machine Gunner",
                    [[["26th_USMC_M240L","","26th_USMC_M240L_DEVICE_1_LASER","USMC_SU230B",["Tier1_250Rnd_762x51_Belt_M80A1_EPR",250],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_G3_MCCUU_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_5",[["ACRE_PRC343",1],["white_monster",6],["Tier1_100Rnd_762x51_Belt_M80A1_EPR",1,100],["Tier1_250Rnd_762x51_Belt_M80A1_EPR",2,250],["rhs_mag_an_m8hc",1,1]]],["USMC_Backpanel_Mini",[["ACE_Canteen",2],["Tier1_250Rnd_762x51_Belt_M80A1_EPR",1,250],["ACE_SpareBarrel",1,1],["Tier1_100Rnd_762x51_Belt_M80A1_EPR",1,100]]],"USMC_Opscore_FTHS_1_MPW","rho_reconwrap_mc_07_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "MAAWS Gunner",
                    [[["26th_USMC_M27_IAR_AFG","","26th_USMC_416_DEVICE_3_LASER","rhsusf_acc_ACOG2",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],["launch_MRAWS_green_F","","26th_USMC_M38_DEVICE_1_LASER","",["MRAWS_HEAT55_F",1],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Cargo_G3_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_2_ATAK",[["ItemAndroid",1],["ACRE_PRC343",1],["ACRE_PRC152",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30],["ACWP_19Rnd_9x21_Mag_glock",2,19]]],["USMC_Backpack_Assault_JPC",[["MCC_PMAG_556_FDE_556_30_M855A1",10,30],["MRAWS_HEAT55_F",1,1],["BB_MAAWS_HE_AB",1,1],["MAA_MAAWS_SMOKE469",1,1]]],"USMC_Opscore_FTHS_3_MPW","rho_reconwrap_mc_07_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Assistant MAAWs",
                    [[["26th_USMC_M27_IAR_AFG","","26th_USMC_M38_DEVICE_1_LASER","USMC_optic_VCOG",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],[],["USMC_M18","","","",["18Rnd_M18_9x19_FMJ",18],[],""],["USMC_Cargo_G3_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_7",[["ACRE_PRC343",1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30],["18Rnd_M18_9x19_JHP",2,18],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",4,1]]],["USMC_Backpack_FILBE_JPC",[["MAA_MAAWS_SMOKE469",3,1],["BB_MAAWS_HE_AB",3,1],["MRAWS_HEAT55_F",3,1]]],"USMC_Opscore_FTHS_2_MPW","rho_reconwrap_mc_07_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Mortarman TL",
                    [[["26th_USMC_M27_IAR_AFG","","26th_USMC_416_DEVICE_3_LASER","rhsusf_acc_ACOG2",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],["ace_compat_sog_mortar_m2_carry","","","",[],[],""],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Cargo_MCCUU_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_2_ATAK",[["ItemAndroid",1],["ACRE_PRC152",1],["ACRE_PRC343",1],["ACE_artilleryTable",1],["ACE_MapTools",1],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",2,1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30]]],["USMC_Backpack_SATL_JPC",[["MCC_PMAG_556_FDE_556_30_M855A1",10,30],["ace_compat_sog_60mm_he",20,1],["ace_compat_sog_60mm_wp",4,1]]],"USMC_Opscore_FTHS_3_MPW","rho_reconwrap_mc_07_glasses",["ACE_VectorDay","","","",[],[],""],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Mortarman",
                    [[["26th_USMC_M27_IAR_AFG","","26th_USMC_M38_DEVICE_1_LASER","USMC_optic_VCOG",["MCC_PMAG_556_FDE_556_30_M855A1",30],[],""],["ace_csw_carryMortarBaseplate","","","",[],[],""],["USMC_M18","","","",["18Rnd_M18_9x19_FMJ",18],[],""],["USMC_Cargo_MCCUU_MPW_1",[["kat_IFAK",1]]],["USMC_PCG3_1",[["ACRE_PRC343",1],["MCC_PMAG_556_FDE_556_30_M855A1",14,30],["rhs_mag_an_m8hc",2,1],["rhs_mag_m67",2,1]]],["USMC_Backpack_SATL_JPC",[["ace_compat_sog_60mm_wp",7,1],["ace_compat_sog_60mm_he",20,1]]],"USMC_Opscore_FTHS_2_MPW","rho_reconwrap_mc_07_glasses",[],["ItemMap","","","ItemCompass","ItemWatch","USMC_PVS31_COVER_WIDE_STOW"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Pilot",
                    [[["rhs_weap_m4a1_carryhandle","rhsusf_acc_SF3P556_hidden","rhsusf_acc_anpeq16a","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Coverall_CB_1",[["kat_IFAK",1]]],["USMC_Airlite_2",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",1,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",4,30]]],[],"MAW_HGU_2","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Co-Pilot",
                    [[["rhs_weap_m4a1_carryhandle","rhsusf_acc_SF3P556_hidden","rhsusf_acc_anpeq16a","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Coverall_OD_1",[["kat_IFAK",1]]],["USMC_Airlite_3",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",1,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",4,30]]],[],"MAW_HGU_2","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Crew Chief",
                    [[["rhs_weap_m4a1_carryhandle","rhsusf_acc_SF3P556_hidden","rhsusf_acc_anpeq16a","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Coverall_OD_1",[["kat_IFAK",1]]],["USMC_Airlite_4",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",1,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",4,30]]],[],"MAW_HGU_2","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis"]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Gunner",
                    [[["rhs_weap_m4a1_carryhandle","rhsusf_acc_SF3P556_hidden","rhsusf_acc_anpeq16a","TOTT_XPS3",["rhs_mag_30Rnd_556x45_M855A1_Stanag",30],[],""],[],["acwp_glock19_black","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["USMC_Coverall_CB_1",[["kat_IFAK",1]]],["USMC_Airlite_3",[["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["ACE_Chemlight_IR",2],["ACE_Chemlight_HiBlue",1],["ACE_Chemlight_HiGreen",1],["ACE_WaterBottle",1],["ACE_MapTools",1],["ACE_Flashlight_XL50",1],["ACWP_19Rnd_9x21_Mag_glock",2,19],["SmokeShellOrange",1,1],["SmokeShellBlue",1,1],["SmokeShellPurple",1,1],["SmokeShellGreen",1,1],["rhs_mag_m67",1,1],["rhs_mag_30Rnd_556x45_M855A1_Stanag",4,30]]],[],"MAW_HGU_1","",[],["ItemMap","","ItemRadio","ItemCompass","ItemWatch","USMC_Anvis"]],[["aceax_textureOptions",[]]]]
                ]
            ]
        ],
        [
            "ctbRhoSilentstrikeTheassault",
            "Silent Strike - The Assault (RHO)",
            [
                [
                    "Tanker - VC",
                    [[["SPE_M3_GreaseGun","","","",["SPE_30Rnd_M3_GreaseGun_45ACP",30],[],""],[],[],["U_SPE_US_Tank_Crew2",[["kat_IFAK",1],["SPE_30Rnd_M3_GreaseGun_45ACP",2,30],["SPE_US_M18",1,1]]],["V_SPE_US_Vest_45",[]],[],"H_SPE_US_Helmet_Tank_polar_tapes","G_SPE_Binoculars",["SPE_Binocular_US","","","",[],[],""],["ItemMap","","ItemRadio","SPE_US_ItemCompass","SPE_US_ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Tanker - Gunner",
                    [[["SPE_M3_GreaseGun","","","",["SPE_30Rnd_M3_GreaseGun_45ACP",30],[],""],[],[],["U_SPE_US_Tank_Coverall_Trop",[["kat_IFAK",1],["SPE_30Rnd_M3_GreaseGun_45ACP",2,30]]],[],[],"H_SPE_US_Helmet_Tank_NG","",["SPE_Binocular_US","","","",[],[],""],["ItemMap","","ItemRadio","SPE_US_ItemCompass","SPE_US_ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Tanker - Driver",
                    [[["SPE_M3_GreaseGun","","","",["SPE_30Rnd_M3_GreaseGun_45ACP",30],[],""],[],[],["U_SPE_US_Tank_Crew",[["kat_IFAK",1],["SPE_30Rnd_M3_GreaseGun_45ACP",2,30],["SPE_US_M18",1,1]]],[],[],"H_SPE_US_Helmet_Tank_NG","",["SPE_Binocular_US","","","",[],[],""],["ItemMap","","ItemRadio","SPE_US_ItemCompass","SPE_US_ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Tanker - Radio Op",
                    [[["SPE_M3_GreaseGun","","","",["SPE_30Rnd_M3_GreaseGun_45ACP",30],[],""],[],[],["U_SPE_US_Tank_Coverall",[["kat_IFAK",1],["SPE_30Rnd_M3_GreaseGun_45ACP",2,30]]],[],[],"H_SPE_US_Helmet_Tank_NG","",["SPE_Binocular_US","","","",[],[],""],["ItemMap","","ItemRadio","SPE_US_ItemCompass","SPE_US_ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ]
            ]
        ],
        [
            "ctbRhoOpSouthern",
            "Southern Reach (RHO)",
            [
                [
                    "Platoon Leader",
                    [[["arifle_rho_ef88_C_cam2_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],["ACWP_HP_ba","","","",["ACWP_13Rnd_9x21_Mag_HP_blk",13],[],""],["Rho_RAR_Combat_shirt_Tucked_MC_Gloves",[["kat_IFAK",1]]],["rho_rar_vest_pl",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["rhs_mag_an_m8hc",2,1],["rho_rar_handgrenade_f1",2,1],["ACWP_13Rnd_9x21_Mag_HP_blk",2,13],["rho_rar_ef88_30Rnd_556x45_B_AUG",10,30]]],[],"rho_rar_tw_exfil2025_comtac_ir_bat_scrim1","G_tweed_tacticool_weiss",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Platoon Medic",
                    [[["arifle_rho_ef88_cam4_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["rho_rar_vest_pl_medic",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["rhs_mag_an_m8hc",6,1],["rho_rar_handgrenade_f1",2,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",10,30]]],["ranger_pack_5",[["ACE_personalAidKit",1],["kat_MFAK",1],["ACE_salineIV_500",4],["ACE_salineIV",2],["ACE_salineIV_250",6],["rhs_mag_an_m8hc",2,1]]],"rho_rar_tw_exfil2025_comtac_ir_bat_scrim3","rho_reconwrap_07_glasses",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Platoon Sergeant",
                    [[["arifle_rho_ef88_C_cam5_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["rho_rar_vest_section2ic",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["rhs_mag_an_m8hc",1,1],["rho_rar_handgrenade_f1",4,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",9,30]]],[],"rho_rar_tw_exfil2025_bat","",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "FO",
                    [[["arifle_rho_ef88_cam10_F","","rho_rar_peq16b_wml_ir_camo","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked_Rolled_Coy_Gloves",[["kat_IFAK",1]]],["rho_rar_vest_fo",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["rhs_mag_an_m8hc",1,1],["rho_rar_handgrenade_f1",2,1],["SmokeShellRed",2,1],["SmokeShellPurple",2,1],["SmokeShellBlue",2,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",10,30]]],["UK3CB_ION_I_B_RadioBag_OLI",[["ACRE_PRC117F",1]]],"rho_rar_tw_exfil2025_comtac_ir_bat_scrim3","",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Section Leader",
                    [[["arifle_rho_ef88_C_cam3_F","","rho_rar_l3srf_wml_ir_camo","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],["ACWP_HP_ba","","","",["ACWP_13Rnd_9x21_Mag_HP",13],[],""],["Rho_RAR_Combat_shirt_Tucked",[["ACE_fieldDressing",10],["ACE_elasticBandage",2],["ACE_packingBandage",2],["ACE_quikclot",2],["ACE_morphine",2],["ACE_tourniquet",2],["kat_IFAK",1]]],["rho_rar_vest_secco",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["rhs_mag_an_m8hc",2,1],["rho_rar_handgrenade_f1",2,1],["ACWP_13Rnd_9x21_Mag_HP_blk",2,13],["rho_rar_ef88_30Rnd_556x45_B_AUG",10,30]]],["TFB_275_AVS_Backpack",[["rho_rar_ef88_camo_30Rnd_556x45_B_AUG",4,30],["rhs_mag_an_m8hc",4,1],["rho_rar_handgrenade_f1",4,1],["SmokeShellRed",4,1],["SmokeShellGreen",4,1],["SmokeShellBlue",4,1]]],"rho_rar_tw_exfil2025_comtac_ir_bat_scrim2","rho_reconwrap_03_glasses_blacklens",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Rifleman - CFA",
                    [[["arifle_rho_ef88_cam6_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["rho_rar_vest_medic",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_personalAidKit",1],["ACE_bloodIV_500",1],["rhs_mag_an_m8hc",2,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",9,30]]],["ranger_pack_4",[["kat_AFAK",1]]],"rho_rar_tw_exfil2025_comtac_ir_bat_mul","G_tweed_tacticool_blauw",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Section 2IC (M72)",
                    [[["arifle_rho_ef88_cam9_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],["rhs_weap_m72a7","","","",[],[],""],[],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["rho_rar_vest_section2ic",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["ItemAndroid",1],["rhs_mag_an_m8hc",2,1],["rho_rar_handgrenade_f1",4,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",10,30]]],[],"rho_rar_tw_exfil2025_comtac_ir_bat_shaggy3","G_tweed_tacticool_weiss",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Autorifleman",
                    [[["rhs_weap_minimi_para_railed","","PEQ_R_black","rhsusf_acc_su230",["CUP_200Rnd_TE4_Red_Tracer_556x45_M249_Pouch",200],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked_Rolled_MC_Gloves",[["kat_IFAK",1]]],["rho_rar_vest_lmg",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["rhs_mag_an_m8hc",1,1],["CUP_200Rnd_TE4_Red_Tracer_556x45_M249_Pouch",3,200],["rho_rar_handgrenade_f1",4,1]]],[],"rho_rar_tw_exfil2025_ir_bat_scrim3","rho_reconwrap_08_glasses",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Grenadier",
                    [[["arifle_rho_ef88_GL_cam10_F","","rho_rar_peq16b_top_ir_camo","rhsusf_acc_su230",["rho_rar_ef88_camo_30Rnd_556x45_B_AUG",30],["rhs_mag_M433_HEDP",1],""],[],[],["Rho_RAR_Combat_shirt_Tucked_Rolled_Coy_Gloves",[["kat_IFAK",1]]],["rho_rar_vest_grenadier",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["rho_rar_handgrenade_f1",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",10,30],["rhs_mag_M433_HEDP",5,1],["rhs_mag_M397_HET",8,1]]],["B_Kitbag_rgr",[["rhsusf_200Rnd_556x45_mixed_soft_pouch_coyote",3,200],["rho_rar_ef88_camo_30Rnd_556x45_B_AUG",6,30],["rhs_mag_M433_HEDP",14,1]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_06_glasses_blacklens",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Combat Engineer",
                    [[["arifle_rho_ef88_cam5_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],["ACE_VMH3","","","",[],[],""],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["rho_rar_vest_engi",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACE_DefusalKit",1],["ACE_Clacker",1],["rhs_mag_an_m8hc",1,1],["DemoCharge_Remote_Mag",2,1],["rho_rar_handgrenade_f1",3,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",9,30]]],["B_Kitbag_rgr",[["ACE_DefusalKit",1],["ACE_Clacker",1],["ACE_wirecutter",1],["SmokeShell",6,1],["CTB_OBS_Personal_Mag",1,1]]],"rho_rar_tw_exfil2025_comtac_ir_bat_scrim3","G_tweed_tacticool_blauw",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Section 2IC - 58 Ammo",
                    [[["arifle_rho_ef88_cam7_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],["rhs_weap_m72a7","","","",[],[],""],[],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["rho_rar_vest_section2ic",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["rhs_mag_an_m8hc",2,1],["Tier1_100Rnd_762x51_Belt_M80A1_EPR",1,100],["rho_rar_handgrenade_f1",2,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",10,30]]],["ranger_pack_4",[["ACE_Canteen",2],["ACE_SpareBarrel",1,1],["Tier1_250Rnd_762x51_Belt_M80A1_EPR",4,250]]],"rho_rar_tw_exfil2025_ir_bat_scrim2","G_tweed_tacticool_comba",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Machine Gunner",
                    [[["75th_Ranger_m240L","","75th_Ranger_sideM240L_2_LASER","75th_Eotech_EXPS3",["Tier1_250Rnd_762x51_Belt_M80A1_EPR",250],[],""],[],["ACWP_HP_ba","","","",["ACWP_13Rnd_9x21_Mag_HP_blk",13],[],""],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["rho_rar_vest_mg",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["rhs_mag_an_m8hc",1,1],["rho_rar_handgrenade_f1",2,1],["ACWP_13Rnd_9x21_Mag_HP_blk",2,13],["Tier1_250Rnd_762x51_Belt_M80",2,250]]],["rho_rar_sap_empty",[["ACE_Canteen",1],["ACE_SpareBarrel",1,1]]],"rho_rar_tw_exfil2025_comtac_ir_bat_scrim3","rho_reconwrap_mc_06",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Ammo Bearer",
                    [[["arifle_rho_ef88_C_cam2_F","","rho_rar_peq16b_wml_ir_camo","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],[],[],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["rho_rar_vest_rifle2",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["rhs_mag_an_m8hc",2,1],["Tier1_100Rnd_762x51_Belt_M80A1_EPR",2,100],["rho_rar_handgrenade_f1",2,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",8,30]]],["ranger_pack_5",[["ACE_Canteen",2],["ACE_SpareBarrel",1,1],["Tier1_250Rnd_762x51_Belt_M80A1_EPR",4,250],["rho_rar_ef88_30Rnd_556x45_B_AUG",2,30]]],"rho_rar_tw_exfil2025_comtac_ir_bat","",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "60mm Gunner TL",
                    [[["arifle_rho_ef88_cam9_F","","rho_rar_peq16b_wml_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],[],""],["ISA_ELBITSYSTEMS_M224_BAG","","","",[],[],""],[],["Rho_RAR_Combat_shirt_Tucked",[["kat_IFAK",1]]],["rho_rar_vest_section2ic",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["rhs_mag_an_m8hc",1,1],["rho_rar_handgrenade_f1",2,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",10,30]]],["ranger_pack_5",[["ISA_MAGAZINE_SHELL_HE_CH0",20,1],["ISA_MAGAZINE_SHELL_SMOKE_CH0",10,1]]],"rho_rar_tw_exfil2025_comtac_ir_bat","rho_reconwrap_06_glasses_blacklens",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Assist 60mm",
                    [[["arifle_rho_ef88_GL_cam10_F","","rho_rar_peq16b_top_ir","rhsusf_acc_su230",["rho_rar_ef88_30Rnd_556x45_B_AUG",30],["rhs_mag_M433_HEDP",1],""],[],[],["Rho_RAR_Combat_shirt_Tucked_Rolled",[["kat_IFAK",1]]],["rho_rar_vest_grenadier",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["rho_rar_handgrenade_f1",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",10,30],["rhs_mag_M433_HEDP",5,1],["rhs_mag_M397_HET",8,1]]],["ranger_pack_4",[["ISA_MAGAZINE_SHELL_HE_CH0",20,1],["ISA_MAGAZINE_SHELL_SMOKE_CH0",10,1]]],"rho_rar_tw_exfil2025_comtac_ir_bat_shaggy3","rho_reconwrap_03_glasses",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Sniper A TL",
                    [[["Tier1_SR25_EC_tan","121_NIGHTOWL_PAINT","Tier1_SR25_LA5_Side","121_USASOC_RVPS",["Tier1_20Rnd_762x51_M80A1_EPR_SR25_Mag",20],[],""],["rhs_weap_m72a7","","rhsusf_acc_anpeq15side","",[],[],""],["acwp_glock19_hlmnd","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked_Bloused_Hood",[["grad_paceCountBeads_functions_paceCountBeads",1],["kat_IFAK",1],["ACE_RangeCard",1],["ACE_microDAGR",1],["ACE_ATragMX",1],["ACE_Kestrel4500",1],["ACE_MapTools",1],["VS17_Small_Panel_Item",1]]],["rho_rar_vest_grenadier",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ItemAndroid",1],["ACRE_PRC152",1],["rho_rar_handgrenade_f1",1,1],["Tier1_20Rnd_762x51_M80A1_EPR_SR25_Mag",9,20],["ACWP_19Rnd_9x21_Mag_glock",3,19]]],["ctb_recon_pack",[["rhs_mag_maaws_HEDP",1,1],["Tier1_20Rnd_762x51_M80A1_EPR_SR25_Mag",2,20]]],"rho_rar_boonie_04","rho_reconwrap_05_glasses_tan",["ACE_Vector","","","",[],[],""],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Sniper B",
                    [[["Tier1_SR25_EC_tan","121_NIGHTOWL_PAINT","Tier1_SR25_LA5_Side","121_USASOC_RVPS",["Tier1_20Rnd_762x51_M80A1_EPR_SR25_Mag",20],[],""],["rhs_weap_m72a7","","rhsusf_acc_anpeq15side","",[],[],""],["acwp_glock19_hlmnd","","","",["ACWP_19Rnd_9x21_Mag_glock",19],[],""],["Rho_RAR_Combat_shirt_Tucked_Bloused_Hood",[["grad_paceCountBeads_functions_paceCountBeads",1],["kat_IFAK",1],["ACE_RangeCard",1],["ACE_microDAGR",1],["ACE_ATragMX",1],["ACE_Kestrel4500",1],["ACE_MapTools",1],["VS17_Small_Panel_Item",1]]],["rho_rar_vest_section2ic",[["ACE_IR_Strobe_Item",1],["ACRE_PRC343",1],["ItemAndroid",1],["ACRE_PRC152",1],["rho_rar_handgrenade_f1",1,1],["Tier1_20Rnd_762x51_M80A1_EPR_SR25_Mag",9,20],["ACWP_19Rnd_9x21_Mag_glock",2,19]]],["ctb_recon_pack",[["121_tripod_item",1],["rhs_mag_maaws_HEDP",1,1],["Tier1_20Rnd_762x51_M80A1_EPR_SR25_Mag",1,20]]],"rho_rar_boonie_03","rho_reconwrap_05_glasses_tan",["121_spotting_scope_handheld","","","",[],[],""],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "MAAWS Gunner TL",
                    [[["arifle_rho_ef88_cam9_F","","rho_rar_peq16b_wml_ir_camo","rhsusf_acc_su230",["rho_rar_ef88_camo_30Rnd_556x45_B_AUG",30],[],""],["rhs_weap_maaws","","","rhs_optic_maaws",["rhs_mag_maaws_HEAT",1],[],""],[],["Rho_RAR_Combat_shirt_Tucked_Bloused_Hood",[["kat_IFAK",1]]],["rho_rar_vest_section2ic",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["ACRE_PRC152",1],["rhs_mag_an_m8hc",1,1],["ACE_M84",2,1],["rho_rar_handgrenade_f1",2,1],["rho_rar_ef88_camo_30Rnd_556x45_B_AUG",13,30]]],["rho_rar_sap_maaws",[["BB_RHS_MAAWS_HE_AB",2,1],["MAA_MAAWS_HEDP502",1,1]]],"rho_rar_tw_exfil2025_ir_bat","rho_reconwrap_03_glasses",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ],
                [
                    "Assist MAAWS",
                    [[["arifle_rho_ef88_GL_cam10_F","","rho_rar_peq16b_top_ir_camo","rhsusf_acc_su230",["rho_rar_ef88_camo_30Rnd_556x45_B_AUG",30],["rhs_mag_M433_HEDP",1],""],[],[],["Rho_RAR_Combat_shirt_Tucked_Bloused_Hood",[["kat_IFAK",1]]],["rho_rar_vest_grenadier",[["ACE_IR_Strobe_Item",1],["ACE_CableTie",2],["ACRE_PRC343",1],["rho_rar_handgrenade_f1",1,1],["rho_rar_ef88_30Rnd_556x45_B_AUG",10,30],["rhs_mag_M433_HEDP",5,1],["rhs_mag_M397_HET",8,1]]],["ctb_recon_pack",[["rhs_mag_maaws_HEDP",1,1]]],"rho_rar_tw_exfil2025_bat","rho_reconwrap_05_glasses",[],["ItemMap","B_UavTerminal","","ItemCompass","ItemWatch",""]],[["aceax_textureOptions",[]]]]
                ]
            ]
        ]
    ]
];
