// =============================================================================
// Briefing.sqf  - In-game briefing and diary records (map screen)
// =============================================================================
// Runs on each client from initPlayerLocal.sqf (call compile — must finish before play adds diary records).
// Diary order: create in reverse order (last created = first displayed).
// =============================================================================

// -----------------------------------------------------------------------------
// Diary subject: Notes (for reference material)
// -----------------------------------------------------------------------------
player createDiarySubject ["FAC_Notes", "FADE Notes"];
// Player-collected HUMINT (civilian talk, etc.): dynamic entries via FADE_civTalk_clientAppendIntelDiary during play.
player createDiarySubject ["FAC_Intel", "Intel"];
player createDiaryRecord ["FAC_Intel", ["About Intel", "
<font color='#87CEEB' size='14'>INTEL LOG</font><br/><br/>
<font color='#E0E0E0'>When an <font color='#90EE90'>ambient civilian</font> gives you something actionable (e.g. OPFOR sighting, vehicle tip), or you <font color='#90EE90'>read building intel</font> / <font color='#90EE90'>secure an Asset Retrieval package</font>, a <font color='#FFD700'>timestamped entry</font> is added below — newest first.</font><br/><br/>
<font color='#AAAAAA'>Open the map → <font color='#FFD700'>Intel</font> to review past reports. Building intel still shows on-screen hints and optional map markers when applicable.</font>
"]];
private _facNotes = [];

// -----------------------------------------------------------------------------
// Note: RATEL - Radio Telephone Procedure (FAC standard)
// -----------------------------------------------------------------------------
_facNotes pushBack ["RATEL (Radio Procedure)", "
<font color='#FFD700' size='14'>RADIO TELEPHONE PROCEDURE</font><br/><br/>
All AI and player radio traffic in FADE follows FAC RATEL. Use this format so comms stay clear and consistent.<br/><br/>

<font color='#87CEEB'>STANDARD FORMAT</font><br/>
<font color='#90EE90'>Called station, this is [Your callsign]. [Message]. Over.</font> - When you expect a reply (e.g. request, question).<br/>
<font color='#90EE90'>Called station, this is [Your callsign]. [Message]. Out.</font> - End of transmission; no reply expected.<br/><br/>

<font color='#87CEEB'>EXAMPLES</font><br/>
''RZ, this is Bravo 2-1. We're at Grid 123456, awaiting pickup. Over.''<br/>
''All callsigns, this is Eagle Eye. Convoy tracking, 400 metres from end zone. Expedite intercept. Out.''<br/>
''RZ, this is Bravo 2-1. All aboard. Ready for liftoff. Over.''<br/><br/>

<font color='#87CEEB'>OVER vs OUT</font><br/>
<font color='#90EE90'>Over</font> - I have finished speaking and am waiting for your reply.<br/>
<font color='#90EE90'>Out</font> - This transmission is finished; no reply expected. Use when closing the conversation or sending a one-way update.
"];

// -----------------------------------------------------------------------------
// Note: Area of Operations and Artillery
// -----------------------------------------------------------------------------
_facNotes pushBack ["Area of Operations and Artillery", "
<font color='#FFD700' size='14'>AO MISSION AND FIRES SUPPORT</font><br/><br/>
The <font color='#90EE90'>Area of Operations</font> mission (Manage Missions, <font color='#90EE90'>[G] Global</font>) creates a 2 km x 2 km zone with three capture points. BLUFOR assault from one side; mission strength uses <font color='#90EE90'>FADE_aoStrength</font> from mission <font color='#90EE90'>Config</font> (not the Scenario GUI). Capture all three objectives to complete (30-minute timeout).<br/><br/>
<font color='#87CEEB'>Player-directed artillery</font> (fire missions requested by players, with AI gun line and FAC-style acknowledgements) is planned; when implemented it will follow the Call for Fire (CFF) and artillery procedures in these Notes.
"];

// -----------------------------------------------------------------------------
// Note: Terminology and Brevity Codes (source: FAC Joint Fires doc)
// -----------------------------------------------------------------------------
_facNotes pushBack ["Terminology and Brevity Codes", "
<font color='#FFD700' size='14'>GLOSSARY AND PROCEDURE TERMS</font><br/><br/>
Standard acronyms and commands for JFO/JTAC, GPO and pilot coordination. Source: Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>ROLES AND ABBREVIATIONS</font><br/>
JFO  - Joint Fires Observer. JTAC  - Joint Terminal Attack Controller. GPO  - Gun Position Officer. FM  - Fire Mission. GR  - Grid Reference. ALT  - Altitude. DC  - Danger Close. VT  - Variable Time (airburst). AMC  - At My Command. LZ  - Landing Zone. ISR  - Information, Surveillance, Reconnaissance. NAI  - Named/Numbered Area of Interest. IP  - Initial Point. GRIDREF  - Grid reference (XXXX YYYY, 8-figure or XXX YYY 6-figure).<br/><br/>
Round types: HE  - High Explosive. WP  - White Phosphorus. SMK  - Smoke. ILLUM  - Illumination.<br/><br/>

<font color='#87CEEB'>FIRES NET</font><br/>
Dedicated frequency for JFO/JTAC and indirect/air assets only. All other callsigns stay off this net.<br/><br/>

<font color='#87CEEB'>CONTROL COMMANDS</font><br/>
- <font color='#90EE90'>AT MY COMMAND</font>  - Fires are delivered only when JFO/JTAC gives the command.<br/>
- <font color='#90EE90'>CANCEL AT MY COMMAND</font>  - Supporting unit no longer waits for JFO/JTAC to engage; may fire when ready.<br/>
- <font color='#90EE90'>REPEAT</font>  - <font color='#FF6666'>Critical:</font> On the fires net, REPEAT means the <font color='#FF6666'>last fire mission</font> (indirect or air) is to be <font color='#FF6666'>re-engaged immediately</font> with the same method. Do NOT use REPEAT to ask someone to say their last transmission again; use ''Say again'' or ''Repeat your last.''<br/>
- <font color='#90EE90'>CHECK FIRE</font>  - Stop firing immediately.<br/>
- <font color='#90EE90'>CANCEL CHECK FIRE</font>  - Only command that allows mortar/artillery to begin firing again after check fire.<br/>
- <font color='#90EE90'>FIRE</font>  - Execute; e.g. ''Fire'' to commence.<br/>
- <font color='#90EE90'>CLEARED HOT</font>  - Airframe is cleared to engage the target passed by JFO/JTAC.<br/><br/>

<font color='#87CEEB'>OTHER</font><br/>
MSR  - Main supply route. ASR  - Alternative supply route. LASE/LASING  - Using weapon-mounted laser or Laser Target Designator to mark. REST  - Gun line may stand down briefly. CANCEL REST  - Gun line return to readiness. CONTINUOUS FIRE  - All pieces fire on current target until check fire or ammunition expended. BDA  - Battle damage assessment. Splash  - Ordnance impact (call ''Splash'' or ''Splash in 5'' for time to impact).
"];

// -----------------------------------------------------------------------------
// Note: Control Measures (source: FAC Joint Fires doc)
// -----------------------------------------------------------------------------
_facNotes pushBack ["Control Measures", "
<font color='#FFD700' size='14'>CONTROL MEASURES FOR JOINT FIRES</font><br/><br/>
Measures used to deconflict and control fires; coordinate with mission leadership and ground forces. Source: Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>ATTACK AXIS</font><br/>
Direction of attack (run-in and egress) for aircraft or direction of fire for indirect. Prevents ordnance from impacting toward friendlies. JTAC/observer specifies; pilot and gun line comply.<br/><br/>

<font color='#87CEEB'>INGRESS AND EGRESS</font><br/>
Ingress point = entry point for aircraft into the AO. Egress point = exit point. Establish before mission or at will by JFO/JTAC or pilot. Assists deconfliction of airspace around the AO.<br/><br/>

<font color='#87CEEB'>BATTLE POSITIONS (DECONFLICTION)</font><br/>
When multiple airframes support the AO, assign each to a Battle Position  - an area outside the AO where they loiter until called in. Reduces clutter over the AO and helps prioritise which asset to bring on station. Altitude at battle position is pilot's choice. If multiple aircraft must be over the AO at once, JFO/JTAC prioritises strikes and gives clear instructions on ingress, egress and altitudes. Airframes may also be asked to deconflict among themselves over internal comms.<br/><br/>

<font color='#87CEEB'>ANCHOR POINT</font><br/>
For fixed-wing: an easily identifiable terrain or infrastructure feature the pilot can hold on sensors or visually. Used as a reference to quickly talk onto a target or area of interest. After a strike from an anchor, pilots default back to the anchor for BDA unless given new instructions. If a talk-on from the anchor fails, revert to the anchor and start again.<br/><br/>

<font color='#87CEEB'>FLOT (FORWARD LINE OWN TROOPS)</font><br/>
Location of the most forward friendly troops (whether firm or moving). Report movements to JFO/JTAC so joint fires can be used with maximum effect and minimal risk to friendlies. JFO/JTAC passively maintains FLOT awareness to support the manoeuvre commander. FLOT can be multiple positions.<br/><br/>

<font color='#87CEEB'>NAI (NAMED/NUMBERED AREA OF INTEREST)</font><br/>
Designates an area of particular reference. In joint fires context, NAIs give a quick reference and talk-on point for pilots, reducing time to engage. Can be used for route planning (e.g. likely ambush, IED or choke points).<br/><br/>

<font color='#87CEEB'>RESTRICTIVE MEASURES</font><br/>
No-fire area (NFA), restrictive fire area (RFA), weapons control status. Danger close: declare when friendlies are within minimum safe distance; adjust or reduce charge per SOP. Abort criteria: conditions under which attack is aborted (e.g. friendlies in sector, loss of mark).
"];

// -----------------------------------------------------------------------------
// Note: Joint Fires Roles (source: FAC Joint Fires doc)
// -----------------------------------------------------------------------------
_facNotes pushBack ["Joint Fires Roles", "
<font color='#FFD700' size='14'>JOINT FIRES ROLES  - JFO, JTAC AND GPO</font><br/><br/>
Source: Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>JFO  - JOINT FIRES OBSERVER</font><br/>
Observes and requests indirect fires (artillery, mortars); passes target information to JTAC or qualified controller for CAS. Calls for fire and adjusts indirect when authorised. Typically does not clear CAS or control attack aircraft release; hands off to JTAC for ''cleared hot''. Role: eyes on target, accurate grid and description, adjustment of indirect; liaison with JTAC for air. Acts as advisor to the manoeuvre commander and anticipates fire missions to support ground forces.<br/><br/>

<font color='#87CEEB'>JTAC  - JOINT TERMINAL ATTACK CONTROLLER</font><br/>
Authorised to control CAS: clear aircraft to engage, designate targets, assume responsibility for ordnance release within ROE and control measures. Transmits simplified 5-line (or full CAS brief per unit SOP); coordinates attack axis, egress and abort criteria. Can coordinate or request indirect fires; often works with JFOs. Role: terminal control of airborne ordnance; integration of air and surface fires; BDA and re-attack. Maintains FLOT awareness to support command.<br/><br/>

<font color='#87CEEB'>GPO  - GUN POSITION OFFICER</font><br/>
Runs the gun line (mortars/artillery). Communicates with deployed JFO/JTAC via fires net; receives calls for fire; calculates firing solutions; issues commands to gunners for fast, accurate fires. Gunners crew the pieces; GPO does not. Chain: JFO/JTAC sends CFF -> GPO plots, calculates, orders fire -> gunners execute. Read back all CFF transmissions word for word to prevent errors (e.g. wrong grid).<br/><br/>

<font color='#87CEEB'>REQUESTING FIRES (NON-JFO/JTAC)</font><br/>
In general, section commanders request supporting fires via the platoon commander, who forwards to JFO/JTAC. This keeps the fires net clear for JFO/JTAC during complex situations. Section commanders pass enemy information to the platoon commander; suggest fire missions through the chain. Providing an 8-figure grid (or preplanned TRPs) speeds the request.
"];

// -----------------------------------------------------------------------------
// Note: Joint arms call for fires (FAC Fires doc §6.4 style — combined arms integration)
// -----------------------------------------------------------------------------
_facNotes pushBack ["Joint arms call for fires (combined arms)", "
<font color='#FFD700' size='14'>JOINT ARMS CALL FOR FIRES</font><br/><br/>
How surface fires, air and manoeuvre fit together under one plan. Aligned with FAC joint-fires training material (§6.4 style).<br/><br/>

<font color='#87CEEB'>COMMAND AND FLOW</font><br/>
The manoeuvre commander (or delegated fires coordinator) sets priorities, timing and effects. Observers (JFO/JTAC) translate that intent into specific missions on the fires net. Requests that skip the chain risk duplicating assets, fratricide or empty deconfliction. Non-qualified callers still pass target data up; they do not self-clear fires.<br/><br/>

<font color='#87CEEB'>SYNCHRONISATION</font><br/>
Plan whether effects are <font color='#90EE90'>sequential</font> (e.g. suppress, then assault) or <font color='#90EE90'>simultaneous</font> (e.g. CAS and mortars on separate aim points). State <font color='#90EE90'>time on target</font> or phase when the commander needs multiple arms on the same clock. Rehearse hand-overs: who shifts from adjustment to FFE, who calls check fire before friendly movement, and how BDA is passed before re-attack.<br/><br/>

<font color='#87CEEB'>DECONFLICTION</font><br/>
Use control measures (ACAs, fire support coordination measures, attack headings, no-fire areas) so rotary/fixed-wing and indirect are not competing for the same airspace or impact area. If in doubt, pause one asset until the observer confirms separation. Update the picture when the scheme of manoeuvre changes.<br/><br/>

<font color='#87CEEB'>TARGET HAND-OFF</font><br/>
When more than one agency can engage (arty, mortars, CAS), the controlling observer states which asset is primary, what is held in reserve, and any restrictions (danger close, AMC, weapon/shell type). Read backs stay word-for-word on grids and technical data. Changes to the target or friendly locations get re-transmitted before the next volley or pass.<br/><br/>

<font color='#87CEEB'>SUPPORT TO MANOEUVRE</font><br/>
Fires should support the main effort: suppression for crossing open ground, obscuration for breaching, precision for point targets. The observer ties each mission to an observable effect the ground commander asked for, not only to map coordinates.
"];

// -----------------------------------------------------------------------------
// Note: Manual / map gunnery — elevation and interpolation (instructor reference)
// -----------------------------------------------------------------------------
_facNotes pushBack ["Manual fires — elevation and interpolation (instructor)", "
<font color='#FFD700' size='14'>GUN ELEVATION AND INTERPOLATION (MANUAL / MAP WORK)</font><br/><br/>
Short reference for teaching manual firing solutions when tables or computers are primary; use with unit ballistics and safety SOPs. Instructor SME: Gobbit (no formal citation in-repo).<br/><br/>

<font color='#87CEEB'>ELEVATION (QUADRANT / TUBE)</font><br/>
Charge and elevation (quadrant elevation or equivalent) translate range and terrain into tube attitude. <font color='#90EE90'>Always</font> confirm charge is safe for the trajectory (clearance, crests, overhead restrictions) before sending data to the line. Corrections from fall of shot change elevation and/or charge per tables — not by guess. Record amendments read back by the gun line.<br/><br/>

<font color='#87CEEB'>INTERPOLATION</font><br/>
Tabulated data are stepped in range, charge or meteor lines. When the mission falls between entries, <font color='#90EE90'>interpolate</font> linearly between the bracketing values unless your tables specify otherwise. Double-check direction (line, attitude in mils) separately from range; mixing corrections from different charge columns causes large errors. If the solution is near a table limit, confirm with a second method or adjust position before accepting fire for effect.<br/><br/>

<font color='#87CEEB'>TEACHING POINTS</font><br/>
Have crews quote both the <font color='#90EE90'>ordered</font> and <font color='#90EE90'>applied</font> data; trace one correction from observer wording through GPO solution to gun display. In FADE, use the timed drill and map grid to practise reporting consistent grids and elevations under time pressure.
"];

// -----------------------------------------------------------------------------
// Note: Call for Fire / Artillery (source: FAC Joint Fires doc)
// -----------------------------------------------------------------------------
_facNotes pushBack ["Call for Fire (CFF) / Artillery", "
<font color='#FFD700' size='14'>INDIRECT FIRES  - CALL FOR FIRE</font><br/><br/>
Indirect fires: mortars, artillery, MLRS/HIMARS. CFF passes clear, accurate instructions to the gun line. <font color='#90EE90'>Every message must be read back word for word</font> by GPO/mortar SL to avoid errors (e.g. wrong grid). Source: Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>GPO UPDATE (PRE-MISSION)</font><br/>
Before or at mission start: radio check with GPO; confirm piece type(s) and number; rounds available; round types available. Conduct radio check before leaving the FOB.<br/><br/>

<font color='#87CEEB'>CFF STRUCTURE (4 ELEMENTS)</font><br/>
1. <font color='#90EE90'>C/S and fire mission type</font>  - Danger Close, Screening, Illumination, or Marking as applicable.<br/>
2. <font color='#90EE90'>Target grid</font>  - 8-figure (XXXX YYYY); include ALT (target altitude) in metres.<br/>
3. <font color='#90EE90'>Target description</font>  - e.g. section in the open 50x50, bunker, vehicle.<br/>
4. <font color='#90EE90'>Technical</font>  - e.g. HE in adjustment (adjust fire); SMOKE in effect; VT (Variable Time/airburst).<br/><br/>

<font color='#87CEEB'>EXAMPLE (JFO/JTAC red, GPO green readback)</font><br/>
JFO: ''Two Zero this is Warlock, Fire Mission, over.''  - GPO: ''Warlock, 20, Fire Mission, out.''<br/>
JFO: ''GRID 1234 5678. ALT 40.''  - GPO: ''GRID 1234 5678, ALT 40, out.''<br/>
JFO: ''Section in the open 50x50, over.''  - GPO: ''Section in the open 50x50, out.''<br/>
JFO: ''HE in adjustment, adjust fire, over.''  - GPO: ''HE in adjustment, adjust fire, out.''<br/>
GPO: ''Shot, time of flight 25, over.''  - JFO: ''Shot 25, out.''<br/>
GPO: ''Rounds complete, over.''  - JFO: ''Rounds complete, out.''<br/><br/>

<font color='#87CEEB'>ADJUSTING</font><br/>
Observe fall of shot; send correction in 3 parts: (1) Add or Drop + cardinal direction, (2) Distance in metres (e.g. 50 as ''FIVE ZERO''), (3) One round fire for effect, or full FFE round count and nature if confident. If several adjustments miss, end the mission, recheck grid and send a new CFF. Enemy may move; recheck target.<br/><br/>

<font color='#87CEEB'>FIRE FOR EFFECT / END OF MISSION</font><br/>
When fall of shot is good: ''Fire for effect'' + round count and ammunition type. When gun line reports ''Rounds complete'', observe effects then send ''End of Mission'' + target report (e.g. target suppressed, target neutralised, enemy withdrawing direction). This allows gun line to refresh, re-lay and resupply.<br/><br/>

<font color='#87CEEB'>TECHNICAL MISSIONS</font><br/>
<font color='#90EE90'>Screening</font>  - SMOKE or WP to screen friendly movement or enemy positions; can be between two points. <font color='#90EE90'>Linear</font>  - Target(s) in a line 200-600 m; observer sends centre grid, <font color='#90EE90'>attitude</font> (direction in mils from North) and <font color='#90EE90'>length</font> (metres). Number of tubes/guns limits max length (see unit tables). <font color='#90EE90'>Illumination</font>  - Airburst illumination over a point. Coordinated illumination as per unit SOP.<br/><br/>

<font color='#87CEEB'>ROUND TYPES</font><br/>
HE (point detonating); VT (airburst, good vs troops in open, soft-skinned); FRAG (extra fragmentation); Smoke (screening, marking); WP (screening/marking with effect); ILLUM (light); Rocket (MLRS/HIMARS, area targets).<br/><br/>

<font color='#87CEEB'>ARTILLERY CALLSIGNS (NOMENCLATURE)</font><br/>
Mortars (sub 100 mm, e.g. 82 mm): Auspost. Howitzers (105-155 mm): Fedex. MLRS/grid-square: Evergreen.<br/><br/>

<font color='#87CEEB'>SILENT MARKING</font><br/>
Anyone in the AO can silent mark: scan for enemy/friendly/civilian; mark items of interest on map with 8-figure grid and description. Report significant finds to manoeuvre commander. Data can be passed to fires units for pre-planned solutions. Use ''GROUP'' for map marks to avoid cluttering shared map; seek permission to mark for all friendlies.
"];

// -----------------------------------------------------------------------------
// Note: CCA/CAS 5-Line Call for Fire (source: FAC Joint Fires doc)
// -----------------------------------------------------------------------------
_facNotes pushBack ["CCA/CAS 5-Line Call for Fire", "
<font color='#FFD700' size='14'>SIMPLIFIED 5-LINE FOR CCA AND CAS</font><br/><br/>
Condensed from standard 9-line for CCA (rotary, close combat attack, within ~5 km) and CAS (fixed-wing). After the initial call is acknowledged, callsigns may be shortened. Source: Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>LINE 1  - FIRE MISSION</font><br/>
JFO/JTAC: ''[Pilot C/S], [JFO/JTAC C/S], Fire Mission, over.'' Pilot: ''[JFO/JTAC C/S], Fire Mission, out.''<br/><br/>

<font color='#87CEEB'>LINE 2  - FRIENDLY LOCATION</font><br/>
JFO/JTAC: ''I am located at GRID XXXX YYYY. Describe your location; state if you are the FLOT or location of FLOT.'' Enables pilot to avoid friendlies and respect attack axis.<br/><br/>

<font color='#87CEEB'>LINE 3  - TARGET LOCATION</font><br/>
''Target at GRID XXXX YYYY. Target and grid are [e.g. second floor, two-storey compound, SE corner]. Target marked by [laser/smoke/talk-on].''<br/><br/>

<font color='#87CEEB'>LINE 4  - TARGET DESCRIPTION</font><br/>
Clear description: e.g. ''HMG position with crew and half-section in defensive positions in and around the compound.''<br/><br/>

<font color='#87CEEB'>LINE 5  - REMARKS</font><br/>
Danger close; At my command; restrictions (e.g. ''Can be engaged by HMG from SE, recommend SW approach''); type of ordnance requested; final attack heading. Example: ''Request engagement with 30 mm cannon to suppress or neutralise HMG and force defenders to withdraw or remain suppressed.''<br/><br/>

<font color='#FFD700'>CCA vs CAS</font><br/>
CCA  - Rotary-wing within proximity of friendlies; quick manoeuvre; any armed rotary can be used; often in pairs (Air Weapons Team). CAS  - Fixed-wing; larger punch, longer set-up; lasing speeds coordination but talk-on is often used; fixed-wing also typically in pairs when available.
"];

// -----------------------------------------------------------------------------
// Note: Marking (Friendly and Enemy) (source: FAC Joint Fires doc)
// -----------------------------------------------------------------------------
_facNotes pushBack ["Marking (Friendly and Enemy)", "
<font color='#FFD700' size='14'>MARKING FRIENDLY AND ENEMY LOCATIONS</font><br/><br/>
Source: Joint Fires Observer / JTAC reference. Brief supporting callsigns on smoke/mark colours at mission start; state any changes as soon as practical.<br/><br/>

<font color='#87CEEB'>MARKING FRIENDLY LOCATION</font><br/>
Marker panel; strobe; IR strobe; IR marker from weapon (only when other methods unavailable); chemlight; smoke in <font color='#90EE90'>positive</font> colours (BLUE, GREEN, PURPLE); 8-figure grid; target talk-on + pilot confirmation readback.<br/><br/>

<font color='#87CEEB'>MARKING ENEMY LOCATION</font><br/>
Tracer (state colour); smoke  - thrown, 40 mm, 60 mm, 81 mm, 105 mm, 155 mm  - in <font color='#90EE90'>negative</font> colours (RED, ORANGE, YELLOW); HE mark (debris cloud); 8-figure grid; IR marker from weapon; laser designator; IR strobe; strobe; chemlight; target talk-on + pilot confirmation readback.<br/><br/>

<font color='#87CEEB'>TARGET TALK-ON</font><br/>
Used when mark or lase is not available. Go <font color='#90EE90'>large to small</font>: use terrain, infrastructure, structures or vehicles near the target, then narrow with increasing detail so the pilot builds a picture. Ask the pilot for a <font color='#90EE90'>mini talk-on</font>  - they describe something near the target so you confirm everyone is looking at the same spot. If the pilot acquires the target early, confirm by asking them to describe something adjacent; if it matches, proceed to engagement without finishing the full talk-on.
"];

// -----------------------------------------------------------------------------
// Note: Air Support Coordination (source: FAC Joint Fires doc)
// -----------------------------------------------------------------------------
_facNotes pushBack ["Air Support Coordination", "
<font color='#FFD700' size='14'>AIR SUPPORT  - RADIO CHECK, CHECK-IN, SIT UPDATE</font><br/><br/>
Source: Joint Fires Observer / JTAC reference. Ground: be patient until aircraft are on station and call. Air: wait until ~3-4 km from AO before radio check.<br/><br/>

<font color='#87CEEB'>RADIO CHECK</font><br/>
Example: Pilot: ''Warlock this is Bonesaw, radio check, over.'' JFO/JTAC: ''Bonesaw, Warlock loud and clear, over.'' Pilot: ''Warlock, Bonesaw loud and clear, out.''<br/><br/>

<font color='#87CEEB'>CHECK-IN (JFO/JTAC INITIATES)</font><br/>
Pilot provides: airframe type and number; location relative to friendlies; time on station (fuel); ordnance (weapons and quantities). Example: ''Warlock, Bonesaw 1-1 and 1-2, AWT of two AH-64 Delta, currently south tracking north to your AO. Approx 800 rounds 30 mm, 40 x 2.75'' rockets, 2 Hellfire Kilo, 2 Hellfire November. Time on station one plus 20.'' (Combined totals for the pair if AWT.)<br/><br/>

<font color='#87CEEB'>SITUATION UPDATE</font><br/>
After check-in. JFO/JTAC gives: callsign and location of friendlies; friendly vehicles; mission; how friendly position is marked. Then: ''We're in contact, engaged by [e.g. HMG position and small arms from vicinity]. Report ready for Fire Mission.''<br/><br/>

<font color='#87CEEB'>REPEAT / RE-ATTACK</font><br/>
<font color='#90EE90'>Indirect:</font> ''REPEAT'' = re-engage last fire mission with same rounds and nature (e.g. 3 rounds HE FFE). <font color='#90EE90'>CCA/CAS:</font> ''Request immediate re-attack''; same target, same or different ordnance as needed.<br/><br/>

<font color='#87CEEB'>SHOW OF FORCE</font><br/>
Request a show of force over a point to confirm pilot has correct approach and target, or to distract/scare the enemy. Specify direction and height. Also used in EW when jamming is suspected (see Electronic Warfare note).
"];

// -----------------------------------------------------------------------------
// Note: LZs, EZs and Supply Drops (source: FAC Joint Fires doc)
// -----------------------------------------------------------------------------
_facNotes pushBack ["LZs, EZs and Supply Drops", "
<font color='#FFD700' size='14'>LANDING ZONES, EXFIL ZONES AND SUPPLY DROPS</font><br/><br/>
Organise in advance where possible with the pilots who will conduct the task. JFO/JTAC can only request; pilot decides go/no-go after weighing risks. If pilot deems area too risky they can suggest an alternative. Source: Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>INFORMATION TO PROVIDE</font><br/>
8-figure grid; description of the LZ/EZ/supply point; task (pick up, drop off, supply); ingress and egress; friendlies in vicinity; enemy activity; anti-air threat; how the site will be marked (e.g. positive-colour smoke  - BLUE, GREEN, PURPLE; at night: laser or IR strobe).<br/><br/>
LZ/EZ should have clear approach and egress for the airframe and, if possible, natural or man-made cover.<br/><br/>

<font color='#87CEEB'>ALCO (QUICK REFERENCE)</font><br/>
- <font color='#90EE90'>Assess</font>  - Hostile locations and threats to the airframe.<br/>
- <font color='#90EE90'>Locate</font>  - Suitable LZ: cover, clear approach/egress, space for the airframe.<br/>
- <font color='#90EE90'>Communicate</font>  - Situation and LZ to air; threats (enemy and environmental); pilot approves or declines.<br/>
- <font color='#90EE90'>Organise</font>  - Plan so ground and air have the best chance of success; minimise delay (aircraft are vulnerable on the ground).
"];

// -----------------------------------------------------------------------------
// Note: Emergency Fire Mission (source: FAC Joint Fires doc)
// -----------------------------------------------------------------------------
_facNotes pushBack ["Emergency Fire Mission (EFM)", "
<font color='#FFD700' size='14'>EMERGENCY FIRE MISSION  - WHEN JFO/JTAC IS UNAVAILABLE</font><br/><br/>
For dire circumstances only. Normally only JFO/JTAC organises assets, triages targets and calls fires. If JFO/JTAC is killed and a section urgently needs coordinated joint fires, use the following. Source: Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>CHAIN OF SENIORITY</font><br/>
(1) JFO dies -> Platoon Commander confirms, switches to fires net, requests EFM. (2) PL dies -> PL 2IC (if present) switches to fires net. (3) No 2IC -> 3IC (nominated section commander) requests EFM.<br/><br/>

<font color='#87CEEB'>PROCEDURE</font><br/>
PL (or successor) gets 8-figure grid and target description from the section in contact; orders withdrawal or hold and seek cover as appropriate; switches to fires net; states emergency fire mission needed; sends grid and target info. GPO calculates and responds with a default (e.g. 4 rounds HE or SMOKE to screen). PL trusts GPO to deliver as fast as possible until a replacement JFO/JTAC is reinserted.<br/><br/>

<font color='#87CEEB'>ROUND COUNTS (GPO DISCRETION)</font><br/>
Typical default totals: 81 mm = 8 rounds; 105 mm = 4 rounds; 155 mm = 2 rounds. GPO may vary to preserve ammunition. Two types: <font color='#90EE90'>Destruction</font> (HE to destroy/suppress); <font color='#90EE90'>Screening</font> (smoke to obscure enemy or friendlies for movement/breaking contact).<br/><br/>

<font color='#87CEEB'>TARGET DESCRIPTION (EFM)</font><br/>
Include: rough enemy size (section, platoon, etc.); vehicles; cover; rough footprint (size on ground); distance from FLOT. EFM continues until the immediate threat is reduced; ceases when replacement JFO/JTAC is in place.<br/><br/>

<font color='#87CEEB'>EXAMPLE (DESTRUCTION)</font><br/>
1-0: ''FedEx this is 1-0, Emergency Fire Mission Destruction, over.'' FedEx: ''1-0 this is FedEx, Emergency Fire Mission send, over.'' 1-0: ''FedEx this is 1-0, GR 1234 5678, section in the open 50x50.'' FedEx: ''1-0 this is FedEx, GR 1234 5678 section in the open 50x50, preparing EFM standby for Shot, over.'' FedEx: ''1-0 this is FedEx Shot time of flight 25 over.'' 1-0: ''FedEx this is 1-0 roger Shot time of flight 25 over.'' Later: 1-0: ''FedEx this is 1-0 End of mission target neutralised/suppressed/withdraw [direction].''
"];

// -----------------------------------------------------------------------------
// Note: Electronic Warfare (source: FAC Joint Fires doc)
// -----------------------------------------------------------------------------
_facNotes pushBack ["Electronic Warfare (Jamming)", "
<font color='#FFD700' size='14'>OPERATING WHEN RADIOS ARE JAMMED</font><br/><br/>
Enemy EW can jam radio. You may not be briefed in advance. Key point: <font color='#90EE90'>EW is range-limited</font>. You on the ground may be jammed and unable to receive, but you can still <font color='#90EE90'>transmit</font>; assets outside the jamming bubble can still receive your messages. Source: Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>PROCEDURE</font><br/>
1. Conduct one or two radio checks with friendly assets to confirm comms are down.<br/>
2. Send a further transmission with a <font color='#90EE90'>situation update</font> that you believe you are being jammed.<br/>
3. If safe: ask the pilot to conduct a <font color='#90EE90'>show of force</font> or deploy flares over a position. That confirms they can hear you and that you are not receiving their replies.<br/>
4. Continue normal engagement procedures with the asset; they will not be able to speak to you. As JFO/JTAC you must know friendly and enemy positions precisely before engaging.
"];

// -----------------------------------------------------------------------------
// KAT Medical (KAM) — by topic; condensed from KAM docs for in-mission reference
// -----------------------------------------------------------------------------
_facNotes pushBack ["KAT — Airway and vomiting", "
<font color='#FFD700' size='14'>KAT AIRWAY (KAM DOCS)</font><br/><br/>
<font color='#87CEEB'>Obstruction</font>  - Airway blocked (e.g. tongue, debris). <font color='#90EE90'>Guedel tube</font> (<font color='#C0C0C0'>kat_guedel</font>) supports the airway and clears obstruction; patient must be unconscious and <font color='#FF6666'>not</font> occluded. One-time use; removed if patient wakes.<br/><br/>
<font color='#87CEEB'>Occlusion</font>  - Different from obstruction: material in the airway (e.g. after vomiting while supine). Guedel does <font color='#FF6666'>not</font> clear occlusions. Use <font color='#90EE90'>Accuvac</font> (<font color='#C0C0C0'>kat_accuvac</font>) suction from Head &gt; Airway Management; patient must be unconscious; clears occlusion reliably per KAM.<br/><br/>
<font color='#87CEEB'>Vomiting</font>  - Unconscious patients can vomit; on the back, vomit can remain and cause occlusion  - treat as occlusion (suction / appropriate KAT actions).<br/><br/>
<font color='#87CEEB'>Chest seal path</font>  - Chest seal is under Torso &gt; Airway Management for pneumothorax / tension / hemopneumothorax (see chest note).
"];

_facNotes pushBack ["KAT — Bleeding and wounds", "
<font color='#FFD700' size='14'>KAT BLEEDING / WOUNDS (KAM DOCS)</font><br/><br/>
In-game, wound severity often shows as bandage colours (rough guide): <font color='#EEEE00'>yellow</font>  - moderate bleed; <font color='#FFA500'>orange</font>  - heavy; <font color='#FF6666'>red</font>  - severe. Stop bleeding with the right tools (tourniquets on limbs, packing, etc.) per your SOP.<br/><br/>
<font color='#87CEEB'>Coagulation</font>  - If enabled, wounds can clot over time (unstable clot); clotting factors are consumed. <font color='#90EE90'>TXA</font> (IV) can help stabilise clots; IV fluid choice affects coagulation (see fluids note).<br/><br/>
<font color='#87CEEB'>Deep penetrating injury</font>  - See separate note; treated in the chest / seal workflow, not ordinary surface bandaging alone.
"];

_facNotes pushBack ["KAT — Blood volume and IV fluids", "
<font color='#FFD700' size='14'>KAT BLOOD VOLUME &amp; IV (KAM DOCS)</font><br/><br/>
Rough blood state (about <font color='#90EE90'>6 L</font> total): <font color='#90EE90'>5.9  - 5.1 L</font> lost some; <font color='#90EE90'>5.1  - 4.2 L</font> lost a lot; <font color='#90EE90'>4.2  - 3.6 L</font> lost a large amount; <font color='#90EE90'>3.6  - 3.0 L</font> lost a fatal amount. By default, below about <font color='#FF6666'>3 L</font> is lethal unless treated; severe loss leads toward <font color='#90EE90'>cardiac arrest</font>.<br/><br/>
<font color='#87CEEB'>IV / IO</font>  - Establish access: <font color='#90EE90'>16g IV</font> (limbs, minor damage, no TQ on that limb) or <font color='#90EE90'>FAST IO</font> (torso; painful). <font color='#87CEEB'>IV obstruction</font>  - After some drugs (e.g. TXA, EACA), line can block; use Inspect Catheter and <font color='#90EE90'>saline flush</font> (needs saline on line).<br/><br/>
<font color='#87CEEB'>Fluids</font>  - Saline, blood, plasma increase circulating volume; each differs in effect on coagulation and kidney pH (see KAM Nephrology if using long treatments).
"];

_facNotes pushBack ["KAT — Cardiac arrest and AED", "
<font color='#FFD700' size='14'>KAT CARDIAC ARREST (KAM DOCS)</font><br/><br/>
Arrest from critical HR/BP; patient becomes unconscious with no effective breathing/perfusion. <font color='#87CEEB'>Rhythms</font>  - <font color='#90EE90'>Shockable:</font> <font color='#90EE90'>VT</font> (ventricular tachycardia), <font color='#90EE90'>VF</font> (ventricular fibrillation). <font color='#90EE90'>Non-shockable:</font> <font color='#90EE90'>PEA</font> (pulseless electrical activity  - EKG may look organised but no pulse), <font color='#90EE90'>asystole</font> (flat/near-flat line). <font color='#FF6666'>PEA can mimic normal sinus on EKG</font>  - check pulse.<br/><br/>
<font color='#87CEEB'>AED</font> (<font color='#C0C0C0'>kat_AED</font>)  - Analyse rhythm; shock if advised (clear the patient); if no shock advised, CPR and meds per algorithm. <font color='#87CEEB'>AED-X</font> adds EKG to identify VT vs VF vs PEA vs asystole. If you only have a basic AED, KAM notes you may treat shockable rhythms similarly to V-tach.<br/><br/>
<font color='#87CEEB'>Treatment assumptions (KAM)</font>  - Docs assume major bleeding controlled, airway managed, IV access and fluids where appropriate, pads connected, and rhythm identified before advanced arrest care (epinephrine, amiodarone, lidocaine, shocks as indicated).
"];

_facNotes pushBack ["KAT — Chest deep penetrating injury", "
<font color='#FFD700' size='14'>KAT CHEST / DEEP PENETRATING (KAM DOCS)</font><br/><br/>
<font color='#90EE90'>Deep penetrating injury</font>  - A chest injury pattern in KAM tied to ballistic/thoracic trauma logic; shown in injury UI. Manage with appropriate KAT chest interventions (e.g. <font color='#90EE90'>chest seal</font> <font color='#C0C0C0'>kat_chestseal</font> for open chest wounds, pneumothorax, tension pneumothorax, hemopneumothorax per mod). Use Torso &gt; Airway Management &gt; chest seal as per training.<br/><br/>
Pair with bleeding control and respiratory assessment (breath sounds, SpO2, decompression options if your modset enables them).
"];

_facNotes pushBack ["KAT — Pharmacy quick reference", "
<font color='#FFD700' size='14'>KAT PHARMACY (KAM DOCS  - SHORT)</font><br/><br/>
<font color='#87CEEB'>IM (examples)</font>  - <font color='#90EE90'>Epinephrine</font> used in arrest algorithms and shocks; follow KAM cardiac pages for sequencing with CPR and analysis.<br/><br/>
<font color='#87CEEB'>IV (examples)</font>  - <font color='#90EE90'>Amiodarone</font>, <font color='#90EE90'>lidocaine</font> appear in shockable-rhythm treatment chains; <font color='#90EE90'>TXA</font> supports clot stabilisation; <font color='#90EE90'>EACA</font> also tied to coagulation/line care. Always confirm dose and contraindications in-game.<br/><br/>
Full tables: KAM docs under Pharmacy (IV / IM / Oral).
"];

_facNotes pushBack ["KAT — Medical training terminal (FADE)", "
<font color='#FFD700' size='14'>MEDICAL TRAINING TERMINAL</font><br/><br/>
Use the <font color='#90EE90'>Medical training</font> scroll action on <font color='#90EE90'>terminalMedical</font> (Medical Training Area). Spawn training dummies, apply <font color='#90EE90'>random or chosen presets</font> from the KAT injury pool (same framework as before). Dummies are uniform-only (no vest, backpack, NVG, or carried items) when configured that way from the terminal:<br/><br/>
<font color='#87CEEB'>Bleeding tiers</font>  - Minor: awake, few wounds, light bleed. Moderate: <font color='#90EE90'>unconscious</font>, several wounds (yellow-tier bleed rates). Massive: unconscious, many wounds (orange-tier rates). Catastrophic: unconscious, very many wounds (red-tier rates). <font color='#C0C0C0'>Uncon</font> means unconscious.<br/><br/>
<font color='#87CEEB'>Airway</font>  - Obstruction; occlusion; or vomiting pathway (occlusion / suction scenario).<br/><br/>
<font color='#87CEEB'>Blood volume</font>  - Hypovolemia from reduced circulating volume (some to severe) plus light wounds.<br/><br/>
<font color='#87CEEB'>Deep penetrating injury</font>  - KAM deep penetrating chest flag with torso trauma.<br/><br/>
<font color='#87CEEB'>Cardiac</font>  - Arrest rhythm <font color='#90EE90'>VT</font>, <font color='#90EE90'>VF</font>, <font color='#90EE90'>PEA</font>, or <font color='#90EE90'>asystole</font> (KAM types).<br/><br/>
<font color='#87CEEB'>Fractures</font>  - KAM Surgery simple, compound, or comminuted fracture on a random body part (requires KAT Surgery).<br/><br/>
Requires <font color='#90EE90'>ACE Medical + KAM (KAT)</font> (and <font color='#90EE90'>KAT Surgery</font> for fracture presets). Heal or remove dummies from the terminal when finished.
"];

// -----------------------------------------------------------------------------
// Note: Rotary Piloting 101
// -----------------------------------------------------------------------------
_facNotes pushBack ["Rotary Piloting 101", "
<font color='#FFD700' size='14'>ROTARY PILOTING 101</font><br/><br/>

This sandbox supports multiple training strands -<font color='#90EE90'>piloting</font>, joint fires, infantry and combined arms. This section focuses on <font color='#90EE90'>rotary-wing</font> standards. Use it when your training focus is aircrew; for joint fires and CAS procedures, see the <font color='#FFD700'>FADE Notes</font> tab.<br/><br/>

Rotary-wing assets are high-value enablers that carry significant responsibility. Misuse or poor discipline in the pilot role can compromise mission flow, endanger personnel and undermine the intent of the operation. The role is highly sought after; the standards and responsibilities that come with it are non-negotiable.<br/><br/>

A rotary pilot must be <font color='#90EE90'>disciplined, skilled and competent</font>. Taking the role seriously means consistent dedication and commitment: substantial out-of-mission practice so that in-mission performance is safe, predictable and aligned with ground elements. The following areas require demonstrated competency.<br/><br/>

<font color='#87CEEB'>FUNDAMENTAL FLIGHT</font><br/>
- Basic flight  - Stable hover, translational lift, autorotation awareness, and confident handling in all phases (take-off, cruise, approach, landing).<br/>
- Evasive and defensive flight  - Terrain masking, nap-of-the-earth (NOE) where appropriate, and manoeuvring to reduce exposure to threats without compromising the mission.<br/>
- Role-appropriate flight  - Logistical flight (smooth, predictable, passenger- and cargo-focused) versus air support flight (attack profiles, run-in and egress, weapon employment).<br/><br/>

<font color='#87CEEB'>THREATS AND AIRFRAME LIMITATIONS</font><br/>
- Enemy threats  - Small arms, AAA, MANPADS and other ADA; know effective ranges and countermeasures; respect threat rings and exclusion criteria.<br/>
- Environmental threats  - Weather (visibility, wind, precipitation), terrain (obstacles, wires, confined LZs), and day/night limitations of your airframe and crew.<br/>
- Know your aircraft  - Performance envelope, payload limits, single-engine or system failures where applicable, and when to abort or turn back.<br/><br/>

<font color='#87CEEB'>PRE-MISSION PLANNING</font><br/>
Coordinate with mission leadership (flight coordinator, platoon lead or lead pilot) as required:<br/>
- Flight paths  - Routes in and out of the AO; avoid known threats and restricted areas.<br/>
- Exclusion zones  - No-fly or restricted areas; altitude limits; weapons-free vs weapons-tight.<br/>
- Infil and exfil points  - Primary and alternate LZs; timing and sequencing with ground forces.<br/>
- Weapon loadouts  - Restrictions (e.g. no ordnance near friendlies); correct ordnance for the task; safe separation and egress.<br/><br/>

<font color='#87CEEB'>NAVIGATION</font><br/>
- Situational awareness  - Position relative to objective, friendlies and threats; fuel and time; when to request updated tasking or RTB.<br/>
- Map reading  - Grid references, terrain association, and ability to brief and follow routes without sole reliance on GPS or automation.<br/><br/>

<font color='#87CEEB'>COMMUNICATIONS</font><br/>
- Flight coordination  - Clear, concise comms with mission leadership and lead pilot; acknowledge tasking and report status (inbound, on station, RTB).<br/>
- Crew communications  - Coordination with crew (e.g. door gunners, crew chief) for threat call-outs and cabin/load management.<br/>
- Passenger communications  - Brief passengers on timings, LZ behaviour and emergency procedures where relevant.<br/><br/>

<font color='#87CEEB'>MISSION FLOW AND INTENT</font><br/>
Respect the mission flow and the intent of the operation. Understand your own abilities and the capability of your airframe; exercise restraint so that employment of rotary assets supports a positive and coherent experience for ground forces and other players. Do not exceed briefed limits or take unnecessary risk that could compromise the mission.
"];

// Sort by display name (case-insensitive). Diary shows newest first, so create in reverse.
private _sortedFacNotes = _facNotes apply { [toLower (_x select 0), _x] };
_sortedFacNotes sort true;
_sortedFacNotes = _sortedFacNotes apply { _x select 1 };
reverse _sortedFacNotes;
{
    player createDiaryRecord ["FAC_Notes", _x];
} forEach _sortedFacNotes;

// -----------------------------------------------------------------------------
// Diary subject: Scenario Brief (distinct from vanilla "Briefing" in map menu)
// -----------------------------------------------------------------------------
player createDiarySubject ["FAC_Briefing", "Scenario Brief"];

// -----------------------------------------------------------------------------
// Scenario Brief: How It Works
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Briefing", ["How It Works", "
<font color='#FFD700' size='14'>CONDUCT OF OPERATIONS</font><br/><br/>

<font color='#90EE90'>Face's Dynamic Environment (FADE)</font> is a multiplayer sandbox centred on <font color='#90EE90'>rotary-wing training</font> (insert, extract, CAS, sling load, night flying) with optional ground play, joint-fires practice, and combined-arms taskings. There is no scripted campaign: spawn kit and vehicles, tune the scenario, then start dynamic missions. Objective locations are generated on the map (missions stay spread apart; many types keep a minimum distance from base).<br/><br/>

<font color='#87CEEB'>INTERACTIONS AT BASE</font><br/>
- <font color='#00FF00'>Manage Vehicles</font> (vehicle board)  - Spawn or despawn aircraft at helipads and land vehicles at the vehicle points. Lists come from loaded mods (CfgVehicles). Fixed-wing is restricted from some pads; use alternate helipads as labelled. Pilots get a pylon / loadout action on spawned aircraft when supported.<br/><br/>
- <font color='#FFD700'>Manage Missions</font> and <font color='#87CEEB'>Manage Scenario</font> (scenario laptop)  - Same object, two actions. Missions: pick a type, read the in-GUI description, start or abort. Scenario: environment, factions, AI options, and limits (see below). <font color='#90EE90'>Apply</font> sends settings to the server for everyone.<br/><br/>
- <font color='#87CEEB'>CQB Training</font> (optional board)  - Configure shoothouse drills (targets or live AI, density, civilians) and start/end from the GUI.<br/><br/>
- <font color='#87CEEB'>Fast Travel</font> (teleport boards)  - Jump to listed locations: Base HQ, Sultan's CQB Killhouse, Joon's Fires Range, Juko's Locker Room, Bean's Medical Area, helipads (two groups), firing range, SDE's Pub, cargo slingload point, Specialist Area (see in-game list; Eden anchors use names like <font color='#90EE90'>teleportBase</font>).<br/><br/>
- <font color='#87CEEB'>Loadout boxes</font>  - <font color='#90EE90'>Manage My Loadout</font> (presets and faction gear), <font color='#90EE90'>Save my loadout</font> (updates what you respawn with; your mission spawn gear is captured automatically until you save), and <font color='#90EE90'>ACE Arsenal</font> when ACE3 is loaded.<br/><br/>
- <font color='#87CEEB'>Jukebox</font>  - Use jukebox radio props for 3D music at that location, or the <font color='#FFD700'>Vehicle loudspeaker...</font> scroll action while inside a vehicle (same tracks; 3D sound attached to the vehicle). Stop-all is <font color='#FFD700'>Manage Scenario</font> → Admin only.<br/><br/>
- <font color='#87CEEB'>Locker room</font> (optional <font color='#90EE90'>LOCKER_1</font>)  - Flavour interaction when placed in Eden.<br/><br/>

<font color='#87CEEB'>KEYBOARD</font><br/>
<font color='#FFD700'>Ctrl+;</font> opens <font color='#90EE90'>Manage Missions</font> from anywhere. Open the Jukebox from a radio prop or from <font color='#FFD700'>Vehicle loudspeaker...</font> when in a vehicle.<br/><br/>

<font color='#87CEEB'>MANAGE SCENARIO (SUMMARY)</font><br/>
Time of day (set by hour), weather preset (clear through storm), <font color='#90EE90'>Limit Gear to Chosen BLUFOR Faction</font>, <font color='#90EE90'>Limit to Preset Loadouts</font>, and friendly / enemy / civilian factions. Enemy side: patrols on/off, AI skill, routing, AAA level (<font color='#90EE90'>Off</font>, <font color='#90EE90'>AAA</font>, <font color='#90EE90'>AAA+MANPADS</font>), <font color='#90EE90'>OPFOR AT</font> (launcher prevalence), and OPFOR population scaling. Area of Operations difficulty is set in mission <font color='#90EE90'>Config</font> (<font color='#90EE90'>FADE_aoStrength</font>), not in this GUI. Toggle <font color='#90EE90'>Civilians enabled</font> for ambient civs and traffic in marked zones.<br/><br/>

<font color='#87CEEB'>MISSION STREAMS</font><br/>
In <font color='#FFD700'>Manage Missions</font>, types marked <font color='#90EE90'>[G] Global</font> are large, shared missions: <font color='#FF6666'>only one</font> global mission runs at a time for the whole server. Types marked <font color='#90EE90'>[S] Single</font> are smaller tasks: up to <font color='#FF6666'>three</font> may run at once, each started by a different player. You may only run <font color='#FF6666'>one</font> mission yourself at a time (global or single); finish or abort before starting another.<br/><br/>

<font color='#87CEEB'>MISSION TYPES</font><br/>
<font color='#87CEEB'>Global [G]</font><br/>
- <font color='#90EE90'>Area of Operations</font>  - 2 km square AO, three objectives; BLUFOR vs OPFOR; optional AI JTAC calls. 30-minute limit.<br/>
- <font color='#90EE90'>CAS / Fire Support</font>  - Support friendly AI at an objective; fails if all friendlies are lost.<br/>
- <font color='#90EE90'>Clear Area</font>  - Town or camp; clear about 80% of enemies within the time limit.<br/>
- <font color='#90EE90'>Hostage</font>  - Rescue hostages from urban buildings; return survivors near base; fail if too many die.<br/>
- <font color='#90EE90'>HVT</font>  - High-value target in an urban site; kill or capture and return to base.<br/>
- <font color='#90EE90'>Intercept Convoy</font>  - Destroy the convoy before it reaches its end point.<br/>
- <font color='#90EE90'>Operation</font>  - Capture several civ zones at once; each zone is captured once OPFOR in the ellipse are eliminated (stays captured until OPFOR return); evaluation every 60 s.<br/>
- <font color='#90EE90'>Search &amp; Destroy</font>  - Three garrisoned buildings in a town plus patrols; eliminate all hostiles.<br/><br/>
- <font color='#90EE90'>Asset Retrieval</font>  - Intel: secure the case at the site (scroll action), then RTB; or vehicle recovery: clear the road site, drive/tow the OPFOR vehicle to base (see task SMEAC).<br/>
- <font color='#90EE90'>CSAR</font>  - One survivor at a downed helo wreck; extract and RTB (global slot).<br/>
- <font color='#90EE90'>Escape &amp; Evasion</font>  - Starter picks evadees (must include self); they are dispersed without GPS in a hostile area; RTB all alive within 1000 m of base. No task markers. Nearby OPFOR are cleared on insert; remaining dismounts patrol the town (SAFE / limited). After an evadee has moved far enough from the hostile area, OPFOR may orbit a search helicopter over the town (not directly tasked on players).<br/><br/>
<font color='#87CEEB'>Single [S]</font><br/>
- <font color='#90EE90'>Troop Insert</font> / <font color='#90EE90'>Troop Extract</font>  - AI squad transport to or from base.<br/>
- <font color='#90EE90'>CASEVAC</font>  - Like Troop Extract, but the squad has KIA and ACE injuries before pickup.<br/>
- <font color='#90EE90'>Cargo / Resupply</font>  - Sling-load cargo from <font color='#90EE90'>CargoPoint_1</font>; fly to the spawned camp and land to complete.<br/>
- <font color='#90EE90'>Medical training</font>  - <font color='#90EE90'>terminalMedical</font> at the Medical Training Area: GUI to spawn dummies and apply KAT presets (bleeding, airway, blood volume, deep penetrating chest, cardiac rhythms, fractures). Requires ACE Medical + KAT. <font color='#C0C0C0'>Uncon</font> in notes means unconscious.<br/>
- <font color='#90EE90'>Mine Clearing</font>  - EOD on roads near civil zones: either 2–5 mines or 1–3 IEDs (one type per mission), spaced along the route; SMEAC states which.<br/><br/>

<font color='#87CEEB'>RESPAWN AND BRIEFING</font><br/>
Respawn is enabled; after death, use the respawn menu as configured. You respawn with your mission spawn loadout unless you use <font color='#90EE90'>Save my loadout</font> at a loadout box to replace it. Use the map: <font color='#FFD700'>Scenario Brief</font> for this guide; open <font color='#FFD700'>FADE Notes</font> for RATEL, 5-line CAS, CFF, joint-fires and combined-arms reference, and the <font color='#FFD700'>KAT — …</font> medical quick-reference topics (same diary subject). Open <font color='#FFD700'>Intel</font> for timestamped HUMINT, building intel, and mission intel you collect in the field.
"]];

// -----------------------------------------------------------------------------
// Scenario Brief: Overview (first thing players see)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Briefing", ["Overview", "
<font color='#FFD700' size='14'>FACE'S DYNAMIC ENVIRONMENT (FADE)  - SITUATION</font><br/><br/>

<font color='#87CEEB'>NATURE</font><br/>
This is a <font color='#90EE90'>multiplayer dynamic sandbox</font> built for broad community training, with emphasis on <font color='#B0D0FF'>helicopter operations</font> (insert, extract, CAS, resupply, formation and terrain flying). The same session can include <font color='#B0D0FF'>joint fires</font> practice (CAS talk-on, AO AI JTAC when enabled), <font color='#B0D0FF'>dismounted and urban tasks</font> (HVT, hostage, clear area, CQB drills), and <font color='#B0D0FF'>combined arms</font> (convoy intercept, large AO fights). Objectives and enemy layouts are generated per mission; scenario settings (weather, factions, AI, AAA, civilians) apply to the whole server once applied.<br/><br/>

<font color='#87CEEB'>LOCATION</font><br/>
Your base is the main FOB (<font color='#90EE90'>BASE_1</font>). Boards and laptops there open the vehicle, mission, and scenario GUIs; loadout boxes, teleport boards, optional CQB and jukebox props, and keyboard shortcuts support the same workflow without Zeus. Aircraft use marked helipads; ground vehicles use marked spawn points. <font color='#90EE90'>KAT medical drills</font> use the <font color='#90EE90'>Medical training</font> terminal at the Medical Training Area.<br/><br/>

<font color='#87CEEB'>INTENT</font><br/>
Spawn what you need, configure the theatre in <font color='#FFD700'>Manage Scenario</font>, then start missions from <font color='#FFD700'>Manage Missions</font> (or <font color='#FFD700'>Ctrl+;</font>). Global missions are one-at-a-time shared operations (AO, CAS, HVT, hostage, clear area, convoy, CSAR, and others); single missions include troop transport, cargo, and mine/IED clearance (EOD). KAT medical practice is via the <font color='#90EE90'>Medical training</font> terminal, not Manage Missions. Open <font color='#FFD700'>How It Works</font> below for the full checklist, <font color='#FFD700'>FADE Notes</font> for RATEL, 5-line CAS, CFF, joint and combined-arms fires, and marking, <font color='#FFD700'>Intel</font> for HUMINT and other intel you log, and <font color='#FFD700'>KAT — …</font> topics for KAM medical quick reference.
"]];
