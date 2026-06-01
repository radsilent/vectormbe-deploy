package 'SubmarineCombatSystem' {
    doc /* Attack submarine combat and propulsion system model.
         Virginia-class SSN reference. Displacement 7900 t submerged,
         complement 135, operating depth >240 m. */

    // ── Value types ──────────────────────────────────────────────────────────
    attribute def Kiloyards { doc /* Tactical sonar range unit */ }
    attribute def Knots     { doc /* Speed in nautical miles per hour */ }
    attribute def NautMiles { doc /* Nautical miles */ }

    // ── Sonar suite ──────────────────────────────────────────────────────────
    part def BowSonarArray {
        doc /* Large-aperture spherical array; AN/BQQ-10 derivative */
        attribute diameter_m          : Real = 4.57;
        attribute frequencyRange_kHz  : Real = 0.1;    // to 10 kHz
        attribute activeDetection_kyd : Real = 20.0;   // active mode
        attribute passiveDetection_kyd: Real = 50.0;   // passive on quiet target

        part sphericalArray  : SphericalHydrophoneArray;
        part wideApertureArr : WideApertureArray[2];   // hull-mounted flanks
    }

    part def TowedArraySystem {
        doc /* TB-29A thin-line towed array; low-frequency passive */
        attribute arrayLength_m       : Real = 240.0;
        attribute towCableLength_m    : Real = 900.0;
        attribute minFrequency_Hz     : Real = 5.0;
        attribute detectionRange_kyd  : Real = 120.0;  // favorable conditions

        part towReel   : ArrayReel;
        part depressor : HydrophoneDepressor;
        part preamp    : TowedArrayPreamp;
    }

    part def SonarProcessingSystem {
        doc /* AN/BQQ-10(V)4 acoustic rapid COTS insertion */
        attribute processingChannels  : Integer = 4096;
        attribute latency_ms          : Real = 50.0;
        attribute processingMIPS      : Real = 8000.0;

        part signalProcessor : AcousticSignalProcessor[4];
        part displayConsoles : SonarDisplayConsole[8];
        part classLib        : AcousticClassificationLibrary;
    }

    // ── Fire control ─────────────────────────────────────────────────────────
    part def FireControlSystem {
        doc /* AN/BYG-1 weapon control system */
        attribute trackCapacity       : Integer = 256;
        attribute weaponChannels      : Integer = 8;
        attribute updateRate_Hz       : Real = 10.0;

        part trackManager   : MultiTargetTracker;
        part fireControlComp: FireControlComputer[2];  // redundant
        part threatEval     : ThreatEvaluator;
        part engagementCtrl : EngagementController;
    }

    // ── Weapons management ───────────────────────────────────────────────────
    part def WeaponsManagementSystem {
        doc /* Torpedo tubes, VLS, weapon stowage */
        attribute torpedoTubes        : Integer = 4;   // 533 mm
        attribute vlsCells            : Integer = 12;  // Virginia Payload Module
        attribute torpedoLoadout      : Integer = 26;
        attribute tomahawkCapacity    : Integer = 40;

        part torpedoTubeArray : TorpedoTube[4];
        part vladPayloadMod   : VirginiaPayloadModule[2];
        part weaponStowage    : WeaponStowageSystem;
        part fireAndForget    : WeaponGuidanceInterface;
    }

    // ── Propulsion ───────────────────────────────────────────────────────────
    part def NuclearPropulsionSystem {
        doc /* S9G PWR; single-shaft; pump-jet propulsor */
        attribute reactorPower_MWth   : Real = 210.0;
        attribute shaftPower_MW       : Real = 29.8;
        attribute maxSpeed_kts        : Real = 34.0;
        attribute quietSpeed_kts      : Real = 20.0;   // below cavitation onset
        attribute endurance_days      : Real = 90.0;   // limited by stores

        part reactor        : S9GReactor;
        part steamTurbine   : PropulsionTurbine;
        part reductionGear  : GearReduction;
        part shaftSeal      : PropulsionShaftSeal;
        part pumpJet        : PumpJetPropulsor;
        part emergencyProp  : EmergencyPropulsionMotor;
    }

    // ── Communications ───────────────────────────────────────────────────────
    part def CommunicationsSystem {
        doc /* Multi-band, LF/VLF receive, EHF SATCOM, periscope-depth */
        attribute vlfReceiveDepth_m   : Real = 60.0;
        attribute satcomBand          : String = 'EHF';
        attribute dataRateSatcom_kbps : Real = 1544.0; // T1 equivalent

        part vlfReceiver    : VLFBuoyantAntenna;
        part satcomTerminal : EHFSatcomTerminal;
        part hfTransceiver  : HFTransceiver;
        part mast           : MultifunctionMast;
    }

    // ── Top-level system ─────────────────────────────────────────────────────
    part def AttackSubmarine {
        part bowSonar    : BowSonarArray;
        part towedArray  : TowedArraySystem;
        part sonarProc   : SonarProcessingSystem;
        part fireControl : FireControlSystem;
        part weapons     : WeaponsManagementSystem;
        part propulsion  : NuclearPropulsionSystem;
        part comms       : CommunicationsSystem;
    }

    // ── Requirements ─────────────────────────────────────────────────────────
    requirement def DetectionRangeReq {
        attribute reqId : String = 'REQ-SUB-001';
        attribute text  : String = 'The sonar suite shall passively detect a threat submarine at not less than 50 kiloyards range under favorable bathymetric conditions.';
        subject : BowSonarArray;
    }

    requirement def StealthReq {
        attribute reqId : String = 'REQ-SUB-002';
        attribute text  : String = 'The submarine radiated noise level shall not exceed baseline class threshold at speeds up to 20 knots, quantified as a required quieting margin over ambient noise floor.';
        subject : NuclearPropulsionSystem;
    }

    requirement def EnduranceReq {
        attribute reqId : String = 'REQ-SUB-003';
        attribute text  : String = 'The propulsion system shall sustain continuous submerged operations for no less than 90 days limited only by crew provisions and consumables, not nuclear fuel.';
        subject : NuclearPropulsionSystem;
    }

    requirement def TrackCapacityReq {
        attribute reqId : String = 'REQ-SUB-004';
        attribute text  : String = 'The fire control system shall simultaneously maintain accurate tracks on no fewer than 256 contacts with position update rate of 10 Hz per track.';
        subject : FireControlSystem;
    }

    requirement def TorpedoReactionReq {
        attribute reqId : String = 'REQ-SUB-005';
        attribute text  : String = 'Time from weapon release authorization to torpedo-in-water shall not exceed 45 seconds for any tube.';
        subject : WeaponsManagementSystem;
    }

    requirement def CommReachbackReq {
        attribute reqId : String = 'REQ-SUB-006';
        attribute text  : String = 'The communications system shall provide two-way EHF SATCOM connectivity at periscope depth with data throughput not less than 1544 kbps.';
        subject : CommunicationsSystem;
    }
}
