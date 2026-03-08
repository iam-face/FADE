// =============================================================================
// Briefing.sqf  - In-game briefing and diary records (map screen)
// =============================================================================
// Runs on each client from initPlayerLocal.sqf.
// Diary order: create in reverse order (last created = first displayed).
// =============================================================================

// -----------------------------------------------------------------------------
// Diary subject: Notes (for reference material)
// -----------------------------------------------------------------------------
player createDiarySubject ["FAC_Notes", "Notes"];

// -----------------------------------------------------------------------------
// Note: RATEL - Radio Telephone Procedure (CTB standard)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["RATEL (Radio Procedure)", "
<font color='#FFD700' size='14'>RADIO TELEPHONE PROCEDURE</font><br/><br/>
All AI and player radio traffic in FADE follows CTB RATEL. Use this format so comms stay clear and consistent.<br/><br/>

<font color='#87CEEB'>STANDARD FORMAT</font><br/>
<font color='#90EE90'>Called station, this is [Your callsign]. [Message]. Over.</font> — When you expect a reply (e.g. request, question).<br/>
<font color='#90EE90'>Called station, this is [Your callsign]. [Message]. Out.</font> — End of transmission; no reply expected.<br/><br/>

<font color='#87CEEB'>EXAMPLES</font><br/>
''RZ, this is Bravo 2-1. We're at Grid 123456, awaiting pickup. Over.''<br/>
''All callsigns, this is Eagle Eye. Convoy tracking, 400 metres from end zone. Expedite intercept. Out.''<br/>
''RZ, this is Bravo 2-1. All aboard. Ready for liftoff. Over.''<br/><br/>

<font color='#87CEEB'>OVER vs OUT</font><br/>
<font color='#90EE90'>Over</font> — I have finished speaking and am waiting for your reply.<br/>
<font color='#90EE90'>Out</font> — This transmission is finished; no reply expected. Use when closing the conversation or sending a one-way update.
"]];

// -----------------------------------------------------------------------------
// Note: Area of Operations and Artillery
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["Area of Operations and Artillery", "
<font color='#FFD700' size='14'>AO MISSION AND FIRES SUPPORT</font><br/><br/>
The <font color='#90EE90'>Area of Operations</font> mission (Manage Missions) creates a 2 km x 2 km zone with three capture points. BLUFOR assault from one cardinal side; a JTAC unit is on station and will call in CAS using CTB 5-line style. Secure all three objectives to complete.<br/><br/>
<font color='#87CEEB'>Player-directed artillery</font> (fire missions requested by players, with AI gun line and CTB-style acknowledgements) is planned; when implemented it will follow the Call for Fire (CFF) and artillery procedures in these Notes.
"]];

// -----------------------------------------------------------------------------
// Note: Terminology and Brevity Codes (source: CTB Joint Fires doc)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["Terminology and Brevity Codes", "
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
"]];

// -----------------------------------------------------------------------------
// Note: Control Measures (source: CTB Joint Fires doc)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["Control Measures", "
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
"]];

// -----------------------------------------------------------------------------
// Note: Joint Fires Roles (source: CTB Joint Fires doc)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["Joint Fires Roles", "
<font color='#FFD700' size='14'>JOINT FIRES ROLES  - JFO, JTAC AND GPO</font><br/><br/>
Source: Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>JFO  - JOINT FIRES OBSERVER</font><br/>
Observes and requests indirect fires (artillery, mortars); passes target information to JTAC or qualified controller for CAS. Calls for fire and adjusts indirect when authorised. Typically does not clear CAS or control attack aircraft release; hands off to JTAC for ''cleared hot''. Role: eyes on target, accurate grid and description, adjustment of indirect; liaison with JTAC for air. Acts as advisor to the manoeuvre commander and anticipates fire missions to support ground forces.<br/><br/>

<font color='#87CEEB'>JTAC  - JOINT TERMINAL ATTACK CONTROLLER</font><br/>
Authorised to control CAS: clear aircraft to engage, designate targets, assume responsibility for ordnance release within ROE and control measures. Transmits 9-line or simplified 5-line; coordinates attack axis, egress and abort criteria. Can coordinate or request indirect fires; often works with JFOs. Role: terminal control of airborne ordnance; integration of air and surface fires; BDA and re-attack. Maintains FLOT awareness to support command.<br/><br/>

<font color='#87CEEB'>GPO  - GUN POSITION OFFICER</font><br/>
Runs the gun line (mortars/artillery). Communicates with deployed JFO/JTAC via fires net; receives calls for fire; calculates firing solutions; issues commands to gunners for fast, accurate fires. Gunners crew the pieces; GPO does not. Chain: JFO/JTAC sends CFF -> GPO plots, calculates, orders fire -> gunners execute. Read back all CFF transmissions word for word to prevent errors (e.g. wrong grid).<br/><br/>

<font color='#87CEEB'>REQUESTING FIRES (NON-JFO/JTAC)</font><br/>
In general, section commanders request supporting fires via the platoon commander, who forwards to JFO/JTAC. This keeps the fires net clear for JFO/JTAC during complex situations. Section commanders pass enemy information to the platoon commander; suggest fire missions through the chain. Providing an 8-figure grid (or preplanned TRPs) speeds the request.
"]];

// -----------------------------------------------------------------------------
// Note: Call for Fire / Artillery (source: CTB Joint Fires doc)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["Call for Fire (CFF) / Artillery", "
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
"]];

// -----------------------------------------------------------------------------
// Note: CCA/CAS 5-Line Call for Fire (source: CTB Joint Fires doc)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["CCA/CAS 5-Line Call for Fire", "
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
"]];

// -----------------------------------------------------------------------------
// Note: Marking (Friendly and Enemy) (source: CTB Joint Fires doc)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["Marking (Friendly and Enemy)", "
<font color='#FFD700' size='14'>MARKING FRIENDLY AND ENEMY LOCATIONS</font><br/><br/>
Source: Joint Fires Observer / JTAC reference. Brief supporting callsigns on smoke/mark colours at mission start; state any changes as soon as practical.<br/><br/>

<font color='#87CEEB'>MARKING FRIENDLY LOCATION</font><br/>
Marker panel; strobe; IR strobe; IR marker from weapon (only when other methods unavailable); chemlight; smoke in <font color='#90EE90'>positive</font> colours (BLUE, GREEN, PURPLE); 8-figure grid; target talk-on + pilot confirmation readback.<br/><br/>

<font color='#87CEEB'>MARKING ENEMY LOCATION</font><br/>
Tracer (state colour); smoke  - thrown, 40 mm, 60 mm, 81 mm, 105 mm, 155 mm  - in <font color='#90EE90'>negative</font> colours (RED, ORANGE, YELLOW); HE mark (debris cloud); 8-figure grid; IR marker from weapon; laser designator; IR strobe; strobe; chemlight; target talk-on + pilot confirmation readback.<br/><br/>

<font color='#87CEEB'>TARGET TALK-ON</font><br/>
Used when mark or lase is not available. Go <font color='#90EE90'>large to small</font>: use terrain, infrastructure, structures or vehicles near the target, then narrow with increasing detail so the pilot builds a picture. Ask the pilot for a <font color='#90EE90'>mini talk-on</font>  - they describe something near the target so you confirm everyone is looking at the same spot. If the pilot acquires the target early, confirm by asking them to describe something adjacent; if it matches, proceed to engagement without finishing the full talk-on.
"]];

// -----------------------------------------------------------------------------
// Note: Air Support Coordination (source: CTB Joint Fires doc)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["Air Support Coordination", "
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
"]];

// -----------------------------------------------------------------------------
// Note: LZs, EZs and Supply Drops (source: CTB Joint Fires doc)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["LZs, EZs and Supply Drops", "
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
"]];

// -----------------------------------------------------------------------------
// Note: Emergency Fire Mission (source: CTB Joint Fires doc)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["Emergency Fire Mission (EFM)", "
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
"]];

// -----------------------------------------------------------------------------
// Note: Electronic Warfare (source: CTB Joint Fires doc)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["Electronic Warfare (Jamming)", "
<font color='#FFD700' size='14'>OPERATING WHEN RADIOS ARE JAMMED</font><br/><br/>
Enemy EW can jam radio. You may not be briefed in advance. Key point: <font color='#90EE90'>EW is range-limited</font>. You on the ground may be jammed and unable to receive, but you can still <font color='#90EE90'>transmit</font>; assets outside the jamming bubble can still receive your messages. Source: Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>PROCEDURE</font><br/>
1. Conduct one or two radio checks with friendly assets to confirm comms are down.<br/>
2. Send a further transmission with a <font color='#90EE90'>situation update</font> that you believe you are being jammed.<br/>
3. If safe: ask the pilot to conduct a <font color='#90EE90'>show of force</font> or deploy flares over a position. That confirms they can hear you and that you are not receiving their replies.<br/>
4. Continue normal engagement procedures with the asset; they will not be able to speak to you. As JFO/JTAC you must know friendly and enemy positions precisely before engaging.
"]];

// -----------------------------------------------------------------------------
// Note: 9-Line JTAC Call-in (full NATO standard; see also CCA/CAS 5-Line)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Notes", ["9-Line JTAC Call-in", "
<font color='#FFD700' size='14'>STANDARD 9-LINE CAS FORMAT (NATO)</font><br/><br/>
Full format for JTAC and pilot coordination. Many scenarios use a simplified 5-line (see <font color='#FFD700'>CCA/CAS 5-Line Call for Fire</font>). Transmit in order; read back as required. Aligned with Joint Fires Observer / JTAC reference.<br/><br/>

<font color='#87CEEB'>LINE 1  - INITIAL POINT (IP) / BREAK POINT (BP)</font><br/>
<font color='#90EE90'>JTAC:</font> Designate a recognisable reference (named waypoint, landmark, or grid) from which the pilot will begin the attack run.<br/>
<font color='#90EE90'>Pilot:</font> Acknowledge IP; utilise as commit point for run-in.<br/>
<font color='#C0C0C0'>Example:</font> ''IP is hill 142, grid 031 457.''<br/><br/>

<font color='#87CEEB'>LINE 2  - HEADING (BRAA from IP to target)</font><br/>
<font color='#90EE90'>JTAC:</font> Magnetic heading in degrees from IP to target.<br/>
<font color='#90EE90'>Pilot:</font> Fly assigned heading from IP to acquire target.<br/>
<font color='#C0C0C0'>Example:</font> ''Heading 085.''<br/><br/>

<font color='#87CEEB'>LINE 3  - DISTANCE</font><br/>
<font color='#90EE90'>JTAC:</font> Distance in metres from IP to target.<br/>
<font color='#90EE90'>Pilot:</font> Use for run-in timing and range; call when target visual.<br/>
<font color='#C0C0C0'>Example:</font> ''1,200 metres.''<br/><br/>

<font color='#87CEEB'>LINE 4  - TARGET ELEVATION</font><br/>
<font color='#90EE90'>JTAC:</font> Target elevation in metres (AMSL or AGL as per SOP).<br/>
<font color='#90EE90'>Pilot:</font> Apply for dive angle, weapon release and terrain clearance.<br/>
<font color='#C0C0C0'>Example:</font> ''Target elevation 420 metres AMSL.''<br/><br/>

<font color='#87CEEB'>LINE 5  - TARGET DESCRIPTION</font><br/>
<font color='#90EE90'>JTAC:</font> Clear description for target identification and ordnance selection.<br/>
<font color='#90EE90'>Pilot:</font> Enables target identification and ordnance selection.<br/>
<font color='#C0C0C0'>Example:</font> ''Two BMP-2s in the open, north side of the compound.''<br/><br/>

<font color='#87CEEB'>LINE 6  - TARGET LOCATION</font><br/>
<font color='#90EE90'>JTAC:</font> 6- or 8-digit grid, or offset from a known point.<br/>
<font color='#90EE90'>Pilot:</font> Plot on map; backup reference if mark is lost.<br/>
<font color='#C0C0C0'>Example:</font> ''Grid 032 461, 8-digit 03245 46120.''<br/><br/>

<font color='#87CEEB'>LINE 7  - MARK</font><br/>
<font color='#90EE90'>JTAC:</font> Mark type and detail for acquisition and guided ordnance.<br/>
<font color='#90EE90'>Pilot:</font> Acquire mark; laser code must match for guided ordnance.<br/>
<font color='#C0C0C0'>Example:</font> ''Laser 1688, mark on lead vehicle.'' or ''Smoke green, 50 metres west of target.''<br/><br/>

<font color='#87CEEB'>LINE 8  - FRIENDLIES</font><br/>
<font color='#90EE90'>JTAC:</font> Location and direction of friendly forces relative to target.<br/>
<font color='#90EE90'>Pilot:</font> Respect attack axis and abort criteria; do not engage toward friendlies.<br/>
<font color='#C0C0C0'>Example:</font> ''Friendlies 200 metres north, dismounted, attack axis south to north.''<br/><br/>

<font color='#87CEEB'>LINE 9  - EGRESS</font><br/>
<font color='#90EE90'>JTAC:</font> Directed egress for aircraft after weapon release.<br/>
<font color='#90EE90'>Pilot:</font> Break off in assigned direction after weapon release.<br/>
<font color='#C0C0C0'>Example:</font> ''Egress east, low altitude.''<br/><br/>

<font color='#FFD700'>PROCEDURE</font><br/>
JTAC: Transmit clearly; confirm or repeat lines on request; update if situation changes.<br/>
Pilot: Read back as required; call ''In'', ''Off'', ''Splash'' and egress; request re-attack or BDA as needed.
"]];

// -----------------------------------------------------------------------------
// Diary subject: Scenario Brief (distinct from vanilla "Briefing" in map menu)
// -----------------------------------------------------------------------------
player createDiarySubject ["FAC_Briefing", "Scenario Brief"];

// -----------------------------------------------------------------------------
// Scenario Brief: How It Works
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Briefing", ["How It Works", "
<font color='#FFD700' size='14'>CONDUCT OF OPERATIONS</font><br/><br/>

This sandbox is built for <font color='#90EE90'>general training</font>: piloting, joint fires, infantry tactics and combined arms. No fixed storyline -spawn assets, pick a mission type and execute. Objectives are generated dynamically within the AO.<br/><br/>

<font color='#87CEEB'>COMMAND BOARDS</font><br/>
At the FOB, three command boards provide tasking and support:<br/><br/>
- <font color='#00FF00'>Manage Vehicles</font>  - Request airframes (rotary- and fixed-wing) for dispatch to designated helipads, or ground vehicles to the vehicle marshalling area. Fixed-wing assets are not cleared for the primary helipads; use alternate pads. Despawn or swap assets as required.<br/><br/>
- <font color='#FFD700'>Manage Missions</font>  - Start dynamic taskings. Objective areas are generated within the AO at no less than 700 m from the FOB. Select a mission type, start the task, then execute (as pilot, ground element, or joint-fires role as appropriate). Abort from the same board if the mission is scrubbed. Mission details and completion criteria are shown when a mission is active.<br/><br/>
- <font color='#87CEEB'>Manage Scenario</font>  - Set theatre conditions: weather (clear, overcast, fog, rain, storm), time of day (dawn, day, dusk, night, midnight), and faction sets for enemy, friendly and civilian forces. Apply before spawning forces or starting missions.<br/><br/>

<font color='#87CEEB'>LOADOUT STATION</font><br/>
Report to the loadout station for kit selection (Manage Loadout). If ACE3 is loaded, full arsenal access is available at the same location.<br/><br/>

<font color='#87CEEB'>MISSION TYPES</font><br/>
- <font color='#90EE90'>Troop Insert</font>  - Pick up a squad at base, fly to the LZ and land to disembark. Trains piloting (landing, formation, terrain masking) and infantry insertion.<br/><br/>
- <font color='#90EE90'>Troop Extract</font>  - Fly to the pickup zone, land to load the squad, return to base and land. Trains landing under pressure and coordination with ground elements.<br/><br/>
- <font color='#90EE90'>CAS / Fire Support</font>  - Engage enemy forces and support friendlies at the objective. No time limit; mission fails if all friendly ground forces are eliminated. Trains attack aviation and joint fires (JTAC/JFO, 9-Line or 5-Line; see Notes).<br/><br/>
- <font color='#90EE90'>Cargo / Resupply</font>  - A cargo box spawns at the cargo point; bringing it to camp is optional. Fly to the camp and land to complete. Trains heavy-lift, sling load and LZ accuracy.<br/><br/>
- <font color='#90EE90'>HVT</font>  - High-value target in an urban building. Eliminate or capture and return to base. Building is guarded; patrols in the area. Trains infantry and small-team tactics.<br/><br/>
- <font color='#90EE90'>Hostage</font>  - Rescue civilian hostages held in urban building(s). Each is guarded inside; patrols operate outside. Return all alive hostages to base within 100 m. Mission fails if more than half the hostages die. Trains clearance and hostage recovery.<br/><br/>
- <font color='#90EE90'>Clear Area</font>  - Enemy-occupied town or camp. Destroy or neutralise at least 80% of enemy forces. Trains combined arms and area clearance.<br/><br/>
- <font color='#90EE90'>Intercept Convoy</font>  - Convoy moving between road points. Destroy all vehicles before they reach the end zone. Trains interdiction and fires coordination.<br/><br/>

<font color='#87CEEB'>RESPAWN</font><br/>
Personnel respawn at the FOB. Use the map to open this Scenario Brief and the Notes tab for joint fires and CAS reference.
"]];

// -----------------------------------------------------------------------------
// Scenario Brief: Rotary Piloting 101
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Briefing", ["Rotary Piloting 101", "
<font color='#FFD700' size='14'>ROTARY PILOTING 101</font><br/><br/>

This sandbox supports multiple training strands -<font color='#90EE90'>piloting</font>, joint fires, infantry and combined arms. This section focuses on <font color='#90EE90'>rotary-wing</font> standards. Use it when your training focus is aircrew; for joint fires and CAS procedures, see the <font color='#FFD700'>Notes</font> tab.<br/><br/>

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
"]];

// -----------------------------------------------------------------------------
// Scenario Brief: Overview (first thing players see)
// -----------------------------------------------------------------------------
player createDiaryRecord ["FAC_Briefing", ["Overview", "
<font color='#FFD700' size='14'>FACE'S DYNAMIC ENVIRONMENT  - SITUATION</font><br/><br/>

<font color='#87CEEB'>NATURE</font><br/>
This scenario is a <font color='#90EE90'>dynamic sandbox environment</font> for multiplayer <font color='#90EE90'>general training</font>. Objectives are procedurally generated across the area of operations (AO). The sandbox supports practice across multiple domains: <font color='#B0D0FF'>piloting</font> (rotary- and fixed-wing, sling load, formation); <font color='#B0D0FF'>joint fires</font> (JTAC/JFO procedures, CAS, call for fire, control measures); <font color='#B0D0FF'>infantry and ground operations</font> (dismounted movement, HVTs, hostage rescue, clear area, convoy interdiction); and <font color='#B0D0FF'>combined arms</font> coordination. Take the role that fits your training focus -pilot, observer, or ground element -and run dynamic taskings to build proficiency.<br/><br/>

<font color='#87CEEB'>LOCATION</font><br/>
Operations are centred on the main base (FOB). All tasking, vehicle dispatch, loadout and scenario settings are accessed at the FOB. Aircraft are dispatched to designated helipads; ground vehicles to the vehicle marshalling area. Mission objectives are generated at random locations within the AO.<br/><br/>

<font color='#87CEEB'>INTENT</font><br/>
Use the command boards to spawn assets, start dynamic missions, and set theatre conditions (weather, time of day, factions). Mission types include troop insert and extract, close air support (CAS), cargo/resupply, HVT, hostage rescue, clear area, and intercept convoy. Refer to <font color='#FFD700'>How It Works</font> for procedures and the <font color='#FFD700'>Notes</font> tab for joint fires and CAS reference (9-Line, 5-Line, CFF, and related notes).
"]];
