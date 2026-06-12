// Boeing 777X Class — Full System Architecture (SysML v2)
// Reference aircraft: Boeing 777-9X wide-body twin-engine transport
// Certification basis: EASA CS-25 / FAA 14 CFR Part 25, ARP 4754A, DO-178C, DO-254
// All performance data from public Boeing commercial marketing specifications
// and FAA type certificate data sheets.
//
// 777-9X key figures:
//   Passengers (3-class):  426 (typical) / 524 (max)
//   Range:                 7,295 nmi (13,500 km)
//   MTOW:                  352,400 kg  (776,750 lb)
//   MLW:                   273,000 kg  (601,800 lb)
//   OEW:                   167,800 kg  (370,100 lb)
//   Length:                76.72 m  (251 ft 9 in)
//   Wingspan:              71.75 m  (235 ft 5 in) — folded: 64.82 m
//   Cruise speed:          Mach 0.85  (up to Mach 0.89 MMO)
//   Engines:               GE9X-105B1A — 105,000 lbf (467 kN) each
//   Service life:          100,000 flight hours / 40,000 flight cycles
//
// Structure of this model:
//   - Functional decomposition (top-down, 4 levels deep)
//   - Physical components (all major aircraft systems)
//   - Interface ports (electrical, hydraulic, pneumatic, databus, mechanical)
//   - Requirements (functional, safety, performance, environmental)
//   - Allocation (requirements → functions → components)
//   - Verification constraints on critical safety thresholds

package Boeing777X {

    private import ScalarValues::*;

    // ═════════════════════════════════════════════════════════════════════════
    // TOP-LEVEL SYSTEM
    // ═════════════════════════════════════════════════════════════════════════

    part def Aircraft {
        doc /* Boeing 777-9X wide-body, long-range twin-engine transport.
               Composite folding wing, GE9X engines, full fly-by-wire primary flight control.
               ETOPS 330 capability. Crew: 2 pilots + 14 cabin crew. */

        attribute designRange_nmi          : Real = 7295.0;
        attribute maxPassengersTypical     : Integer = 426;
        attribute maxPassengersHighDensity : Integer = 524;
        attribute maxTakeoffWeight_kg      : Real = 352400.0;
        attribute maxLandingWeight_kg      : Real = 273000.0;
        attribute maxZeroFuelWeight_kg     : Real = 260000.0;
        attribute operatingEmptyWeight_kg  : Real = 167800.0;
        attribute certificationBasis       : String = "CS25_FAR25_ARP4754A_DO178C";
        attribute crewFlight               : Integer = 2;
        attribute fuselageLength_m         : Real = 76.72;
        attribute wingspan_m               : Real = 71.75;       // unfolded
        attribute wingspanFolded_m         : Real = 64.82;       // gate-compatible
        attribute serviceLife_fh           : Real = 100000.0;
        attribute serviceLife_fc           : Real = 40000.0;
        attribute cruiseMach               : Real = 0.85;
        attribute mmo                      : Real = 0.89;
        attribute maxCruiseAltitude_ft     : Real = 43100.0;
        attribute etopsRating_min          : Real = 330.0;
        attribute compositeStructurePct    : Real = 52.0;  // % by weight

        // ── Major subsystem instances ──────────────────────────────────────
        part propulsion    : PropulsionSystem;
        part airframe      : Airframe;
        part fcs            : FlightControlSystem;
        part avionics       : AvionicsSuite;
        part landingGear    : LandingGearSystem;
        part ecs            : EnvironmentalControlSystem;
        part hydraulics     : HydraulicSystem;
        part electrical     : ElectricalPowerSystem;
        part fuel           : FuelSystem;
        part comms          : CommunicationsSystem;
        part cabin          : CabinSystem;
        part healthMgmt     : HealthMonitoringSystem;

        // ── Aircraft-level ports ───────────────────────────────────────────
        port runway         : GroundContactPort;
        port atmosphere     : AtmosphericPort;
        port atcDatalink    : DataLinkPort;
        port gatePower      : GroundPowerPort;
        port fuelUplink     : FuelServicePort;

        // ── Aircraft-level interfaces ──────────────────────────────────────
        interface engToFuel    connect propulsion.fuelInlet       to fuel.engineFeedPort;
        interface engToElec    connect propulsion.generatorPower   to electrical.acBusInput;
        interface engToBleed   connect propulsion.bleedAirSupply   to ecs.bleedAirInlet;
        interface hydToFCS     connect hydraulics.primaryFCSSupply to fcs.hydraulicActuation;
        interface elecToHyd    connect electrical.dcBus28V         to hydraulics.pumpControl;
        interface avToFCS      connect avionics.fcsBusOut          to fcs.commandBus;
        interface avToEng      connect avionics.throttleCommands   to propulsion.thrustCommand;
        interface cabinToECS   connect cabin.freshAirDemand        to ecs.cabinSupplyDuct;
        interface hmsToAv      connect healthMgmt.systemAlerts     to avionics.maintenanceBus;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // FUNCTIONAL DECOMPOSITION — LEVEL 1 FUNCTIONS
    // ═════════════════════════════════════════════════════════════════════════

    action def AircraftFunction {
        doc /* Abstract base for all aircraft-level functions. */
        attribute functionId   : String;
        attribute safetyLevel  : String;   // DAL-A through DAL-E (ARP 4754A)
    }

    // F-01: Provide Lift and Drag Control
    action def ProvideLiftDragControl :> AircraftFunction {
        doc /* Aerodynamic generation and regulation over the full flight envelope. */
        attribute :>> functionId  = "F-01";
        attribute :>> safetyLevel = "DAL-A";

        part manageWingLift              : ManageWingLift;
        part manageSpeedbrakesDragDevices : ManageDragDevices;
        part manageHighLift              : ManageHighLiftDevices;
        part controlDirectionalStab      : ControlDirectionalStability;
        part manageFoldingWingTip        : ManageFoldingWingTip;
    }

    // F-02: Provide Thrust
    action def ProvideThrust :> AircraftFunction {
        doc /* Generate, regulate, and reverse thrust for all flight and ground phases. */
        attribute :>> functionId  = "F-02";
        attribute :>> safetyLevel = "DAL-A";

        part generateThrust       : GenerateThrust;
        part regulateThrust       : RegulateThrust;
        part manageFuelSupply     : ManageFuelSupplyFunction;
        part monitorEngineHealth  : MonitorEngineHealth;
        part reverseThrustOnGnd   : ReverseThrust;
    }

    // F-03: Navigate and Guide
    action def NavigateAndGuide :> AircraftFunction {
        doc /* Determine position, plan route, issue guidance for long-range ETOPS operations. */
        attribute :>> functionId  = "F-03";
        attribute :>> safetyLevel = "DAL-B";

        part determinePosition    : DeterminePosition;
        part planRoute            : PlanRoute;
        part issueGuidance        : IssueGuidanceCommands;
        part manageFlightEnvelope : ManageFlightEnvelope;
        part managePBNNavigation  : ManagePerformanceBasedNav;
    }

    // F-04: Control Aircraft Attitude and Flight Path
    action def ControlAttitudeFlightPath :> AircraftFunction {
        doc /* Receive pilot/autopilot commands and actuate FBW primary flight control surfaces. */
        attribute :>> functionId  = "F-04";
        attribute :>> safetyLevel = "DAL-A";

        part receivePilotInput    : ReceivePilotInput;
        part computeControlLaws   : ComputeControlLaws;
        part actuateSurfaces      : ActuatePrimaryFlightSurfaces;
        part manageProtection     : ManageEnvelopeProtection;
    }

    // F-05: Manage Power Generation and Distribution
    action def ManagePowerGenDist :> AircraftFunction {
        doc /* Generate and distribute electrical, hydraulic, and pneumatic power. */
        attribute :>> functionId  = "F-05";
        attribute :>> safetyLevel = "DAL-B";

        part generateAcPower      : GenerateACPower;
        part distributeAcPower    : DistributeACPower;
        part generateHydPower     : GenerateHydraulicPower;
        part distributeHydPower   : DistributeHydraulicPower;
        part manageEmergencyPwr   : ManageEmergencyPower;
    }

    // F-06: Manage Environmental Control
    action def ManageEnvControl :> AircraftFunction {
        doc /* Pressurize wide-body cabin, manage temperature zones, supply oxygen. */
        attribute :>> functionId  = "F-06";
        attribute :>> safetyLevel = "DAL-B";

        part pressurizeCabin      : PressurizeCabin;
        part controlTemperature   : ControlCabinTemperature;
        part manageOxygen         : ManageOxygenSupply;
        part monitorAirQuality    : MonitorAirQuality;
    }

    // F-07: Manage Landing and Ground Operations
    action def ManageLandingGround :> AircraftFunction {
        doc /* Landing gear operation, braking, nose wheel steering, and wing-fold sequencing. */
        attribute :>> functionId  = "F-07";
        attribute :>> safetyLevel = "DAL-A";

        part extendRetractGear    : ExtendRetractGear;
        part applyBraking         : ApplyBraking;
        part steerOnGround        : SteerOnGround;
        part manageWOW            : ManageWeightOnWheels;
        part sequenceWingFold     : SequenceWingFoldOnGround;
    }

    // F-08: Communicate and Datalink
    action def CommunicateDatalink :> AircraftFunction {
        doc /* VHF/HF/SATCOM voice and data; ACARS, ADS-B Out, oceanic communications. */
        attribute :>> functionId  = "F-08";
        attribute :>> safetyLevel = "DAL-C";

        part voiceCommsATC        : VoiceCommsATC;
        part acarsDatalink        : AcarsDatalink;
        part crewIntercomm        : CrewIntercomm;
        part emergencyComms       : EmergencyComms;
        part passengerConnectivity : PassengerConnectivity;
    }

    // F-09: Monitor and Report System Health
    action def MonitorSystemHealth :> AircraftFunction {
        doc /* Detect faults, log ACARS maintenance reports, predict failures, alert crew. */
        attribute :>> functionId  = "F-09";
        attribute :>> safetyLevel = "DAL-C";

        part detectFaults         : DetectFaults;
        part logMaintData         : LogMaintenanceData;
        part alertCrew            : AlertCrewAbnormalities;
        part predictFailures      : PredictFailures;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // FUNCTIONAL DECOMPOSITION — LEVEL 2 FUNCTIONS
    // ═════════════════════════════════════════════════════════════════════════

    action def ManageWingLift :> AircraftFunction {
        attribute :>> functionId = "F-01-01";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Regulate aileron and spoiler panel deflection for roll authority and lift distribution. */
    }

    action def ManageDragDevices :> AircraftFunction {
        attribute :>> functionId = "F-01-02";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Deploy flight spoiler / speedbrake panels for deceleration and descent. */
    }

    action def ManageHighLiftDevices :> AircraftFunction {
        attribute :>> functionId = "F-01-03";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Schedule leading-edge slats and trailing-edge Fowler flap extension for T/O and landing. */
    }

    action def ControlDirectionalStability :> AircraftFunction {
        attribute :>> functionId = "F-01-04";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Maintain yaw control via rudder; coordinate turns; support crosswind takeoff/landing. */
    }

    action def ManageFoldingWingTip :> AircraftFunction {
        attribute :>> functionId = "F-01-05";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Sequence wing-tip fold/unfold on ground; lock verification before T/O. 777X unique function. */
    }

    action def GenerateThrust :> AircraftFunction {
        attribute :>> functionId = "F-02-01";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Combust Jet-A in GE9X turbofan cores to produce net forward thrust. */
    }

    action def RegulateThrust :> AircraftFunction {
        attribute :>> functionId = "F-02-02";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Modulate fuel flow via FADEC to achieve commanded N1/thrust target. */
    }

    action def ManageFuelSupplyFunction :> AircraftFunction {
        attribute :>> functionId = "F-02-03";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Transfer fuel from main, center, and reserve tanks; manage CG within certified limits. */
    }

    action def MonitorEngineHealth :> AircraftFunction {
        attribute :>> functionId = "F-02-04";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Monitor EGT, N1/N2/N3, oil pressure, vibration; detect exceedances and trend changes. */
    }

    action def ReverseThrust :> AircraftFunction {
        attribute :>> functionId = "F-02-05";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Deploy and stow cascade-type thrust reversers on landing rollout; OEI inhibit logic. */
    }

    action def DeterminePosition :> AircraftFunction {
        attribute :>> functionId = "F-03-01";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Compute 3D position and velocity from GPS/GNSS, IRS (triple), and RNP sensor fusion. */
    }

    action def PlanRoute :> AircraftFunction {
        attribute :>> functionId = "F-03-02";
        attribute :>> safetyLevel = "DAL-C";
        doc /* Load and optimize 4D flight plan; manage ETOPS waypoints and en-route alternates. */
    }

    action def IssueGuidanceCommands :> AircraftFunction {
        attribute :>> functionId = "F-03-03";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Compute lateral/vertical guidance for autopilot and autothrottle. */
    }

    action def ManageFlightEnvelope :> AircraftFunction {
        attribute :>> functionId = "F-03-04";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Monitor speed, altitude, and attitude against VMO/MMO, stall, and structural limits. */
    }

    action def ManagePerformanceBasedNav :> AircraftFunction {
        attribute :>> functionId = "F-03-05";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Compute and monitor Required Navigation Performance (RNP AR) accuracy for curved approaches. */
    }

    action def ReceivePilotInput :> AircraftFunction {
        attribute :>> functionId = "F-04-01";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Acquire control column, rudder pedal, and throttle quadrant lever inputs. */
    }

    action def ComputeControlLaws :> AircraftFunction {
        attribute :>> functionId = "F-04-02";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Apply normal, secondary, and direct flight control laws (777 architecture). */
    }

    action def ActuatePrimaryFlightSurfaces :> AircraftFunction {
        attribute :>> functionId = "F-04-03";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Drive ailerons, elevators, and rudder via electro-hydraulic actuators. */
    }

    action def ManageEnvelopeProtection :> AircraftFunction {
        attribute :>> functionId = "F-04-04";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Prevent structural exceedance; stall, overspeed, bank angle protection. */
    }

    action def GenerateACPower :> AircraftFunction {
        attribute :>> functionId = "F-05-01";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Produce 115V AC 400 Hz from variable-frequency generators on each GE9X HP shaft. */
    }

    action def DistributeACPower :> AircraftFunction {
        attribute :>> functionId = "F-05-02";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Route AC power via main bus bars and ground service buses. */
    }

    action def GenerateHydraulicPower :> AircraftFunction {
        attribute :>> functionId = "F-05-03";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Pressurize three 3,000 psi hydraulic circuits from engine-driven and electric pumps. */
    }

    action def DistributeHydraulicPower :> AircraftFunction {
        attribute :>> functionId = "F-05-04";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Route hydraulic power to flight control actuators, brakes, landing gear, and steering. */
    }

    action def ManageEmergencyPower :> AircraftFunction {
        attribute :>> functionId = "F-05-05";
        attribute :>> safetyLevel = "DAL-A";
        doc /* RAT deployment and battery backup to maintain essential bus during dual-generator failure. */
    }

    action def PressurizeCabin :> AircraftFunction {
        attribute :>> functionId = "F-06-01";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Maintain 7,000 ft cabin equivalent altitude at MMO/Mach 0.85 / 43,100 ft cruise. */
    }

    action def ControlCabinTemperature :> AircraftFunction {
        attribute :>> functionId = "F-06-02";
        attribute :>> safetyLevel = "DAL-C";
        doc /* Regulate multi-zone cabin temperatures (forward/mid/aft) between 18–27 °C. */
    }

    action def ManageOxygenSupply :> AircraftFunction {
        attribute :>> functionId = "F-06-03";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Deploy passenger O₂ masks on decompression; sustain crew gaseous O₂ for 20 min descent. */
    }

    action def MonitorAirQuality :> AircraftFunction {
        attribute :>> functionId = "F-06-04";
        attribute :>> safetyLevel = "DAL-C";
        doc /* Monitor CO₂, ozone, VOC, temperature, and humidity in recirculated cabin air. */
    }

    action def ExtendRetractGear :> AircraftFunction {
        attribute :>> functionId = "F-07-01";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Extend and retract 3-strut bogie gear (nose + two 6-wheel main bogies); verify locks. */
    }

    action def ApplyBraking :> AircraftFunction {
        attribute :>> functionId = "F-07-02";
        attribute :>> safetyLevel = "DAL-A";
        doc /* Apply brake-by-wire antiskid braking including RTO autobrake at maximum energy. */
    }

    action def SteerOnGround :> AircraftFunction {
        attribute :>> functionId = "F-07-03";
        attribute :>> safetyLevel = "DAL-C";
        doc /* Steer nose gear ±70° via tiller; main gear rear axle steering for tight turns. */
    }

    action def ManageWeightOnWheels :> AircraftFunction {
        attribute :>> functionId = "F-07-04";
        attribute :>> safetyLevel = "DAL-A";
        doc /* WOW logic arms/inhibits thrust reversers, speedbrakes, and autobrake. */
    }

    action def SequenceWingFoldOnGround :> AircraftFunction {
        attribute :>> functionId = "F-07-05";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Command wing-tip fold at gate; interlock with WOW and hydraulic power availability. */
    }

    action def VoiceCommsATC :> AircraftFunction {
        attribute :>> functionId = "F-08-01";
        attribute :>> safetyLevel = "DAL-C";
        doc /* VHF/HF voice and SELCAL across continental and oceanic routes. */
    }

    action def AcarsDatalink :> AircraftFunction {
        attribute :>> functionId = "F-08-02";
        attribute :>> safetyLevel = "DAL-D";
        doc /* ACARS over VHF/HF/SATCOM for position reporting, clearances, weather. */
    }

    action def CrewIntercomm :> AircraftFunction {
        attribute :>> functionId = "F-08-03";
        attribute :>> safetyLevel = "DAL-D";
        doc /* Flight deck and cabin interphone; passenger address system. */
    }

    action def EmergencyComms :> AircraftFunction {
        attribute :>> functionId = "F-08-04";
        attribute :>> safetyLevel = "DAL-B";
        doc /* ELT, emergency squawk 7700, Cospas-Sarsat beacon. */
    }

    action def PassengerConnectivity :> AircraftFunction {
        attribute :>> functionId = "F-08-05";
        attribute :>> safetyLevel = "DAL-E";
        doc /* Ku/Ka-band in-flight internet for passenger Wi-Fi and IFE streaming. */
    }

    action def DetectFaults :> AircraftFunction {
        attribute :>> functionId = "F-09-01";
        attribute :>> safetyLevel = "DAL-C";
        doc /* BITE and ACMS health monitoring; fault isolation to LRU level. */
    }

    action def LogMaintenanceData :> AircraftFunction {
        attribute :>> functionId = "F-09-02";
        attribute :>> safetyLevel = "DAL-D";
        doc /* Record FDR parameters, QAR snapshots, and CMC dispatch messages. */
    }

    action def AlertCrewAbnormalities :> AircraftFunction {
        attribute :>> functionId = "F-09-03";
        attribute :>> safetyLevel = "DAL-B";
        doc /* Drive EICAS/ECAM master caution/warning; display context-sensitive checklists. */
    }

    action def PredictFailures :> AircraftFunction {
        attribute :>> functionId = "F-09-04";
        attribute :>> safetyLevel = "DAL-D";
        doc /* Trend analysis on engine and structural parameters for predictive maintenance. */
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PHYSICAL COMPONENTS — LEVEL 1
    // ═════════════════════════════════════════════════════════════════════════

    // ─── 1. PROPULSION SYSTEM ────────────────────────────────────────────────

    part def PropulsionSystem {
        doc /* Twin GE9X-105B1A high-bypass turbofan engines — 105,000 lbf each.
               Highest-thrust commercial engine at entry into service (2020).
               BPR 10:1, OPR 60:1, CMC hot section, ceramic fan blades. */

        attribute engineCount         : Integer = 2;
        attribute engineType          : String = "GE9X-105B1A";
        attribute engineMount         : String = "UnderWingPylon_777X";
        attribute takeOffThrust_N     : Real = 467052.0;  // 105,000 lbf per engine
        attribute maxContinuousThrust_N : Real = 420000.0;
        attribute bypassRatio         : Real = 10.0;
        attribute overallPressureRatio : Real = 60.0;
        attribute certificationBasis  : String = "FAR33_EASA_CSE_ETOPS330";

        part engine_L  : GE9XEngineAssembly;
        part engine_R  : GE9XEngineAssembly;
        part pylon_L   : EnginePylon;
        part pylon_R   : EnginePylon;
        part nacelle_L : EngineNacelle;
        part nacelle_R : EngineNacelle;
        part reverser_L : ThrustReverserAssembly;
        part reverser_R : ThrustReverserAssembly;

        port fuelInlet         : FuelFlowPort;
        port bleedAirSupply    : BleedAirPort;
        port generatorPower    : ElectricalBusPort;
        port thrustCommand     : ThrustCommandPort;
        port engineDataBus     : ARINC429Port;
    }

    part def GE9XEngineAssembly {
        doc /* GE9X-105B1A — 3-spool turbofan, CMC turbine blades, LEAP-heritage TAPS II combustor.
               World's first commercial engine with ceramic matrix composite rotating parts. */

        attribute engineDesignation   : String = "GE9X_105B1A";
        attribute dryMass_kg          : Real = 8955.0;   // approx
        attribute length_m            : Real = 6.6;
        attribute fanDiameter_m       : Real = 3.40;     // 134 in — 777X-specific large fan
        attribute sfc_cruise          : Real = 0.478;    // lb/lbf·hr at cruise conditions (est.)
        attribute cmcComponents       : String = "HPTShroud_CombustorLiner_HPTNozzle";

        part fan              : GE9XFanAssembly;
        part lpc              : LPCompressorModule;
        part ipc              : IPCompressorModule;
        part hpc              : HPCompressorModule;
        part combustor        : TAPSII_Combustor;
        part hpt              : HighPressureTurbine;
        part ipt              : IntermediatePressureTurbine;
        part lpt              : LowPressureTurbine;
        part fadec            : FADECUnit;
        part acg              : AccessoryGearbox;
        part idg              : IntegratedDriveGenerator;

        port airInlet         : AirflowPort;
        port thrustNozzle     : ThrustPort;
        port fuelIn           : FuelFlowPort;
        port bleedOut         : BleedAirPort;
        port electricalOut    : ElectricalBusPort;
        port arinc429         : ARINC429Port;
    }

    part def GE9XFanAssembly {
        doc /* 16 carbon-fiber composite fan blades — first on any GE commercial engine. */
        attribute fanDiameter_m           : Real = 3.40;
        attribute fanBladeCount           : Integer = 16;
        attribute bladeMaterial           : String = "CFRP_CompositeFanBlade";
        attribute bypassRatio             : Real = 10.0;
        attribute fanPressureRatio        : Real = 1.72;
        attribute massFlowTotal_kgPerSec  : Real = 1390.0;
    }

    part def LPCompressorModule {
        attribute stages             : Integer = 3;
        attribute pressureRatio      : Real = 2.8;
    }

    part def IPCompressorModule {
        doc /* 777X GE9X uses 3-spool architecture (vs. 2-spool CFM/P&W). */
        attribute stages             : Integer = 7;
        attribute pressureRatio      : Real = 8.5;
    }

    part def HPCompressorModule {
        attribute stages             : Integer = 11;
        attribute pressureRatio      : Real = 2.5;
        attribute rearMaterial       : String = "IN718_René88DT";
    }

    part def TAPSII_Combustor {
        doc /* Twin Annular Pre-Swirl II combustor — ICAO CAEP/8 NOx compliance. */
        attribute combustorType       : String = "TAPS_II_TwinAnnularPreSwirl";
        attribute maxTIT_K            : Real = 1880.0;
        attribute noxMarginVsCAEP8_pct : Real = 25.0;
        attribute fuelSpec            : String = "JetA_100pctSAF_capable";
    }

    part def HighPressureTurbine {
        doc /* 2-stage HPT with CMC nozzles and blades — enables higher TIT. */
        attribute stages             : Integer = 2;
        attribute bladeMaterial      : String = "CMC_SiCSiC_SingleCrystal";
        attribute shroudMaterial     : String = "CMC_SiCSiC";
        attribute turbineInletTemp_K : Real = 1880.0;
    }

    part def IntermediatePressureTurbine {
        attribute stages             : Integer = 2;
        attribute bladeMaterial      : String = "CMSX4_SingleCrystal_TBC";
    }

    part def LowPressureTurbine {
        attribute stages             : Integer = 7;
        attribute bladeMaterial      : String = "IN792_LPT";
    }

    part def FADECUnit {
        doc /* Dual-channel FADEC — controls all engine functions. DO-178C Level A. */
        attribute channels            : Integer = 2;
        attribute softwareLevel       : String = "DO178C_LevelA";
        attribute hardwareLevel       : String = "DO254_LevelA";
        attribute updateRateHz        : Real = 80.0;
        attribute failureRatePerFH    : Real = 1.0e-9;
        attribute thrustRatingModes   : Integer = 6;  // TOGA, MCT, CON, CLB, CRZ, GA
    }

    part def AccessoryGearbox {
        attribute drives              : String = "IDG_HydPump_StarterMotor_FuelPump_OilPump";
    }

    part def IntegratedDriveGenerator {
        doc /* Variable-frequency generator (no IDG needed on 777X — direct VFG). */
        attribute type                : String = "VFG_VariableFrequencyGenerator";
        attribute ratedPower_kVA      : Real = 120.0;
        attribute outputVoltage_V     : Real = 115.0;
        attribute frequencyRange_Hz   : String = "360_to_800";
        attribute coolantType         : String = "OilCooled";
    }

    part def EnginePylon {
        attribute material            : String = "Ti_CFRP_Composite";
        attribute attachType          : String = "UnderWingBox_FusePin_777X";
        attribute failSafe            : Boolean = true;
    }

    part def EngineNacelle {
        attribute nacelleMaterial     : String = "CFRP_CarbonFibre";
        attribute acousticLiner       : String = "HoneycombFoamInlet_Transliner";
        attribute fireSuppression     : Boolean = true;
    }

    part def ThrustReverserAssembly {
        doc /* 777X cascade-type reverser with blocker doors. OEI inhibited. */
        attribute reverserType        : String = "CascadeBlockerDoor";
        attribute maxReverseThrust_pct : Real = 50.0;
        attribute deployTime_sec      : Real = 1.0;
        attribute grndOnlyEnable      : Boolean = true;
    }

    // ─── 2. AIRFRAME ─────────────────────────────────────────────────────────

    part def Airframe {
        doc /* 52% composite structure by weight — CFRP composite wing and empennage.
               Aluminium-lithium fuselage with CFRP frames in critical areas.
               Folding wing tips for gate compatibility (ICAO Code E gates). */

        attribute designLimitLoadFactor  : Real = 2.5;   // g positive CS-25.337
        attribute ultimateLoadFactor     : Real = 3.75;
        attribute negativeLimitFactor    : Real = -1.0;
        attribute compositeFraction_pct  : Real = 52.0;
        attribute serviceLife_fh         : Real = 100000.0;
        attribute serviceLife_fc         : Real = 40000.0;

        part fuselage        : FuselageAssembly;
        part wing            : WingAssembly;
        part hStabilizer     : HorizontalStabilizerAssembly;
        part vStabilizer     : VerticalStabilizerAssembly;
        part primarySurfaces : PrimaryFlightSurfaceGroup;
        part highLiftDevices : HighLiftDeviceGroup;
        part wingTipFolding  : FoldingWingTipAssembly;

        port wingFuelAccess  : FuelInterfacePort;
        port systemsRouting  : SystemsDuctPort;
    }

    part def FuselageAssembly {
        doc /* Semi-monocoque wide-body fuselage. Twin-aisle cabin. Al-Li primary structure. */
        attribute length_m               : Real = 76.72;
        attribute maxCabinWidth_m        : Real = 6.19;
        attribute maxCabinHeight_m       : Real = 2.44;
        attribute maxExternalWidth_m     : Real = 6.98;
        attribute pressureDiff_psi       : Real = 9.4;    // max differential
        attribute aisles                 : Integer = 2;
        attribute frameMaterial          : String = "AlLi2050_AlLi2099_CFRP";
        attribute skinMaterial           : String = "Al2024_AlLi_CompositePatches";
        attribute stationsTotal          : Integer = 340;
    }

    part def WingAssembly {
        doc /* Carbon-fibre composite wing box and skin — first composite wing on a Boeing widebody.
               Folding wing tips add 3.5 m each side to optimise cruise aerodynamics. */
        attribute spanTotal_m            : Real = 71.75;    // unfolded
        attribute spanFolded_m           : Real = 64.82;    // folded tips
        attribute sweepAngle_deg         : Real = 31.6;
        attribute grossArea_m2           : Real = 466.8;
        attribute aspectRatio            : Real = 11.0;
        attribute fuelCapacity_L         : Real = 195285.0;  // 777-9X usable
        attribute primaryMaterial        : String = "CFRP_Toray_T800_Composite";
        attribute wingBoxSpars           : Integer = 3;

        part wingBox         : WingBoxStructure;
        part leadingEdge     : WingLeadingEdgeGroup;
        part trailingEdge    : WingTrailingEdgeGroup;
        part foldingTip      : FoldingWingTipAssembly;
        part engineHardpoints : PylonAttachHardpoint[2];
    }

    part def WingBoxStructure {
        attribute spars                  : Integer = 3;
        attribute ribCount               : Integer = 47;
        attribute coverMaterial          : String = "CFRP_Toughened_IM7_T800";
    }

    part def WingLeadingEdgeGroup {
        doc /* Variable-camber krueger flaps (inner) + slats (outer). Bleed-air anti-icing. */
        attribute innerFlapsType         : String = "KruegerFlap_VariableCamber";
        attribute outerSlatsCount        : Integer = 6;
        attribute antiIcingType          : String = "PneumaticBleedPiccoloTube";
    }

    part def WingTrailingEdgeGroup {
        doc /* Triple-slotted Fowler flaps + ailerons + high-speed ailerons + flight spoilers. */
        attribute flapType               : String = "FowlerTripleSlotted";
        attribute flapPanelCount         : Integer = 8;   // 4 per wing
        attribute aileronCount           : Integer = 4;   // 2 per wing (low-speed + high-speed)
        attribute spoilerPanelCount      : Integer = 14;  // 7 per wing
        attribute spoilerMaterial        : String = "CFRP_Graphite";
    }

    part def FoldingWingTipAssembly {
        doc /* Hydraulic/electric wing-tip fold — 777X unique feature. Folds 3.47 m per side. */
        attribute foldLength_m           : Real = 3.47;   // per tip
        attribute foldAngle_deg          : Real = 90.0;
        attribute actuatorType           : String = "HydraulicElectric";
        attribute lockPinCount           : Integer = 4;
        attribute interlockWOW           : Boolean = true;
        attribute interlockHydPressure   : Boolean = true;
    }

    part def HorizontalStabilizerAssembly {
        doc /* All-moving trimmable horizontal stabilizer (THS) + elevators. CFRP composite. */
        attribute span_m                 : Real = 21.0;
        attribute area_m2                : Real = 100.0;
        attribute sweepAngle_deg         : Real = 35.0;
        attribute material               : String = "CFRP_Composite";
        attribute trimRange_deg          : Real = 15.0;
    }

    part def VerticalStabilizerAssembly {
        doc /* Single composite vertical fin + rudder. */
        attribute height_m               : Real = 11.9;
        attribute area_m2                : Real = 58.0;
        attribute sweepAngle_deg         : Real = 48.0;
        attribute material               : String = "CFRP_Composite_AlLeadingEdge";
    }

    part def PrimaryFlightSurfaceGroup {
        part ailerons         : Aileron[4];   // 2 low-speed + 2 high-speed per wing
        part elevators        : Elevator[2];
        part rudder           : Rudder;
    }

    part def Aileron {
        attribute maxDeflection_deg      : Real = 30.0;
        attribute material               : String = "CFRP_Graphite";
        attribute actuatorType           : String = "HydroelectricServo_FBW";
    }

    part def Elevator {
        attribute maxDeflection_deg      : Real = 20.0;
        attribute material               : String = "CFRP_Graphite";
        attribute actuatorType           : String = "HydroelectricServo_FBW";
    }

    part def Rudder {
        attribute maxDeflection_deg      : Real = 30.0;
        attribute material               : String = "CFRP_Composite";
        attribute actuatorType           : String = "TandemHydraulic_FBW";
        attribute travelLimiter          : String = "SpeedDependent_RTL";
    }

    part def HighLiftDeviceGroup {
        part slats  : Slat[12];   // 6 per wing
        part flaps  : Flap[8];    // 4 per wing

        attribute maxFlapDeflection_deg  : Real = 40.0;
        attribute maxSlatDeflection_deg  : Real = 30.0;
        attribute driveSystem            : String = "HydraulicPDU_AsymmetryDetect";
    }

    part def Slat {
        attribute material               : String = "Al_CFRP_Hybrid";
        attribute positionCount          : Integer = 5;
    }

    part def Flap {
        attribute type                   : String = "FowlerTripleSlotted";
        attribute material               : String = "CFRP_Composite";
        attribute positionCount          : Integer = 5;   // 0, 5, 15, 25, 30, 40 deg
    }

    part def PylonAttachHardpoint {
        attribute failSafe               : Boolean = true;
        attribute fusePinCount           : Integer = 4;
        attribute certifiedToCS25        : Boolean = true;
    }

    // ─── 3. FLIGHT CONTROL SYSTEM ────────────────────────────────────────────

    part def FlightControlSystem {
        doc /* 777X primary FBW with triply-redundant ACE/PFC architecture.
               Normal law provides full envelope protection.
               Integrated wing-tip fold actuation. */

        attribute architecture           : String = "FBW_777X_ACE_PFC";
        attribute pfcCount               : Integer = 3;   // Primary Flight Computers
        attribute aceCount               : Integer = 4;   // Actuator Control Electronics
        attribute softwareLevel          : String = "DO178C_LevelA";
        attribute failureRatePerFH       : Real = 1.0e-9;

        part pfc_1    : PrimaryFlightComputer;
        part pfc_2    : PrimaryFlightComputer;
        part pfc_3    : PrimaryFlightComputer;
        part ace_1    : ActuatorControlElectronics;
        part ace_2    : ActuatorControlElectronics;
        part ace_3    : ActuatorControlElectronics;
        part ace_4    : ActuatorControlElectronics;
        part actuatorSet : FlightControlActuatorSet;
        part pilotCtrls  : PilotControlInterface;
        part stabilTrim  : StabilizerTrimActuation;

        port hydraulicActuation : HydraulicPort;
        port commandBus         : ARINC629Port;
        port pilotInputPort     : MechanicalInputPort;
        port actuatorFeedback   : DiscreteDataPort;
    }

    part def PrimaryFlightComputer {
        doc /* PFC — normal/secondary/direct flight control laws. DO-178C Level A. */
        attribute processorType          : String = "COTS_MIPS_Triply_Redundant";
        attribute softwareLevel          : String = "DO178C_LevelA";
        attribute hardwareLevel          : String = "DO254_LevelA";
        attribute updateRateHz           : Real = 80.0;
        attribute controlLaws            : String = "Normal_Secondary_Direct_777";
        attribute envelopeProtection     : Boolean = true;
    }

    part def ActuatorControlElectronics {
        doc /* ACE — translates PFC commands to hydraulic valve current. */
        attribute softwareLevel          : String = "DO178C_LevelB";
        attribute monitorsServoValves    : Boolean = true;
    }

    part def FlightControlActuatorSet {
        part aileronActuators  : HydraulicActuator[8];    // 2 per aileron panel
        part elevatorActuators : HydraulicActuator[4];
        part rudderActuators   : HydraulicActuator[3];    // triple tandem
        part spoilerActuators  : HydraulicActuator[14];
        part flapDriveUnits    : PowerDriveUnit[2];
        part slatDriveUnits    : PowerDriveUnit[2];
    }

    part def HydraulicActuator {
        attribute operatingPressure_psi  : Real = 3000.0;
        attribute type                   : String = "ServoValveHydraulic_EHA";
        attribute lvdtSensors            : Integer = 2;
    }

    part def PowerDriveUnit {
        attribute type                   : String = "HydraulicPDU_WithBrake";
        attribute asymmetryDetection     : Boolean = true;
    }

    part def PilotControlInterface {
        doc /* Conventional yoke + rudder pedals — 777X retains column (not sidestick). */
        attribute type                   : String = "ConventionalColumn_FBW";
        attribute dualControls           : Boolean = true;
        attribute forceFeel              : String = "ArtificialFeel_ColFeel";
    }

    part def StabilizerTrimActuation {
        attribute trimMotors             : Integer = 3;   // triple independent
        attribute trimRate_degPerSec     : Real = 0.25;
        attribute powerSource            : String = "ElectricalHydraulic_Dual";
    }

    // ─── 4. AVIONICS SUITE ───────────────────────────────────────────────────

    part def AvionicsSuite {
        doc /* Boeing Common Core System (CCS) — ARINC 629/664 databus architecture.
               Honeywell/Rockwell Collins IMA-based avionics. */

        part fms      : FlightManagementComputer;
        part adirs    : AirDataInertialRefSystem;
        part afcs     : AutopilotFlightDirectorSystem;
        part displays : DisplaySystem;
        part tcas     : TCAS;
        part taws     : TAWSSystem;
        part wxRadar  : WeatherRadar;
        part hud      : HeadsUpDisplay;
        part rnav     : RNAVSystem;

        port fcsBusOut          : ARINC629Port;
        port throttleCommands   : ThrustCommandPort;
        port maintenanceBus     : ARINC429Port;
        port displayBusOut      : ARINC664Port;
    }

    part def FlightManagementComputer {
        doc /* FMC — triple redundant; Honeywell NZ-2000 class. */
        attribute units                  : Integer = 3;
        attribute navDatabase            : String = "ARINC424_28day";
        attribute performanceModel       : String = "BADA_Boeing_Own";
        attribute predictorHorizon_nmi   : Real = 5000.0;
        attribute softwareLevel          : String = "DO178C_LevelB";
        attribute rnpCapable             : Boolean = true;
        attribute sadtCapable            : Boolean = true;  // step-altitude descent
    }

    part def AirDataInertialRefSystem {
        doc /* Triple ADIRU — IRS + air data + AOA. Laser ring gyros. */
        attribute units                  : Integer = 3;
        attribute gyroType               : String = "LaserRingGyro";
        attribute alignTime_min          : Real = 10.0;
        attribute positionAccuracy_nm_hr : Real = 1.5;
        attribute aoaSensorCount         : Integer = 4;
    }

    part def AutopilotFlightDirectorSystem {
        doc /* Dual AFCS — autoland CAT IIIb / RNP AR 0.1. */
        attribute channels               : Integer = 2;
        attribute catIIIb_capable        : Boolean = true;
        attribute rnpAR_minima           : Real = 0.1;     // nmi
        attribute minDecisionHeight_ft   : Real = 15.0;
        attribute rvr_m                  : Real = 75.0;
        attribute softwareLevel          : String = "DO178C_LevelA";
    }

    part def DisplaySystem {
        doc /* Boeing Large Format Displays (LFDs) — 15.1 in × 4 primary + 2 MFDs. */
        attribute screenCount            : Integer = 6;
        attribute screenSize_in          : Real = 15.1;
        attribute technology             : String = "AMLCD_LED_Backlit";
        attribute graphicsStandard       : String = "OpenGL_DO178C_B";
    }

    part def TCAS {
        attribute version                : String = "TCAS_II_v7.1";
        attribute adsbIntegration        : Boolean = true;
        attribute softwareLevel          : String = "DO178C_LevelB";
    }

    part def TAWSSystem {
        attribute standard               : String = "TAWS_Class_A_TSO-C151c";
        attribute terrainDatabase        : String = "SRTM_30m_Global";
        attribute lookAhead_sec          : Real = 60.0;
    }

    part def WeatherRadar {
        attribute frequency_GHz          : Real = 9.3;
        attribute range_nmi              : Real = 320.0;
        attribute turbulenceDetect       : Boolean = true;
        attribute windshearAlert         : Boolean = true;
    }

    part def HeadsUpDisplay {
        attribute pilots                 : String = "CaptainAndFirstOfficer";
        attribute symbologyStandard      : String = "ARINC739A";
        attribute svsCapable             : Boolean = true;
    }

    part def RNAVSystem {
        doc /* Required Navigation Performance — RNP AR 0.1 approaches. */
        attribute rnpArMinima_nmi        : Real = 0.1;
        attribute gnssTypes              : String = "GPS_Galileo_GLONASS_SBAS";
        attribute fmaDisplayed           : Boolean = true;
    }

    // ─── 5. LANDING GEAR SYSTEM ──────────────────────────────────────────────

    part def LandingGearSystem {
        doc /* 777-9X: 3-strut configuration — nose gear + 2 six-wheel main bogies.
               Hydraulic operation, electric backup, brake-by-wire, rear axle steering. */

        part noseGear       : NoseGearAssembly;
        part mainGear_L     : MainGearAssembly;
        part mainGear_R     : MainGearAssembly;
        part brakeSystem    : WheelBrakeSystem;
        part gearWarning    : GearWarningLogic;
        part rearAxleSteering : RearAxleSteeringSystem;

        port hydraulicSupply : HydraulicPort;
        port electricalBus   : ElectricalBusPort;
        port groundContact   : GroundContactPort;
    }

    part def NoseGearAssembly {
        doc /* Dual-wheel nose gear; hydraulic/tiller steering ±70°. */
        attribute steeringRange_deg      : Real = 70.0;
        attribute steeringType           : String = "HydraulicTiller_PedalSteering";
        attribute tireSize               : String = "40x15.5R19_Ply20";
        attribute extendRetractTime_sec  : Real = 12.0;
        attribute shimmy_damper          : Boolean = true;
    }

    part def MainGearAssembly {
        doc /* Six-wheel bogie main gear with rear-axle steering for tight turns. */
        attribute configuration          : String = "SixWheelBogie";
        attribute tireSize               : String = "H54x21.0R23_Ply30";
        attribute oleoPressure_psi       : Real = 250.0;
        attribute extendRetractTime_sec  : Real = 12.0;
    }

    part def WheelBrakeSystem {
        doc /* Brake-by-wire antiskid — no conventional hydraulic brake pedal linkage. */
        attribute brakeType              : String = "CarbonMultiDisc_12_per_axle";
        attribute brakeByWire            : Boolean = true;
        attribute autobrakeSettings      : String = "DISARM_MIN_MED_MAX_RTO";
        attribute antiSkid               : Boolean = true;
        attribute rtoArmedSpeed_kts      : Real = 90.0;
        attribute bscuSoftwareLevel      : String = "DO178C_LevelA";
        attribute maxBrakeEnergy_MJ      : Real = 1700.0;  // per stop
    }

    part def RearAxleSteeringSystem {
        doc /* Rear-axle steering enables tight 180° turns on standard runways. */
        attribute steeringRange_deg      : Real = 12.0;
        attribute actuatorType           : String = "ElectricalHydraulic";
        attribute interlockGroundSpeed   : Boolean = true;
    }

    part def GearWarningLogic {
        attribute configWarning          : Boolean = true;
        attribute unsafeIndicators       : Boolean = true;
    }

    // ─── 6. ENVIRONMENTAL CONTROL SYSTEM ─────────────────────────────────────

    part def EnvironmentalControlSystem {
        doc /* Three-pack bleed air ECS with four-zone cabin temperature control.
               Recirculation fans and HEPA filtration. 777-9X 7,000 ft cabin altitude at cruise. */

        part pack_L        : AirConditioningPack;
        part pack_C        : AirConditioningPack;
        part pack_R        : AirConditioningPack;
        part pressCtrl     : PressureController;
        part oxygenSys     : OxygenSystem;
        part avionicsVent  : AvionicsCoolingUnit;
        part hepaFilter    : HEPAFiltrationUnit;

        port bleedAirInlet    : BleedAirPort;
        port cabinSupplyDuct  : CabinDuctPort;
        port outflowValve     : OutflowValvePort;
    }

    part def AirConditioningPack {
        attribute type                   : String = "BootstrapAirCycle_HighFlow";
        attribute coolingCapacity_kW     : Real = 90.0;
        attribute inletTempMax_degC      : Real = 260.0;
        attribute outletTemp_degC        : Real = 8.0;
    }

    part def PressureController {
        attribute maxDiffPressure_psi    : Real = 9.4;
        attribute cabinEquivAlt_ft       : Real = 7000.0;  // at MMO / 43,100 ft
        attribute channelCount           : Integer = 2;
        attribute outflowValves          : Integer = 4;
        attribute safetyReliefValves     : Integer = 2;
        attribute softwareLevel          : String = "DO178C_LevelB";
    }

    part def OxygenSystem {
        attribute passengerType          : String = "ChemicalGenerator_SodiumChlorite";
        attribute crewType               : String = "GaseousCylinder_HighPressure";
        attribute autoDeployAlt_ft       : Real = 14000.0;
        attribute deployTime_sec         : Real = 2.0;
        attribute crewMask               : String = "DilutionDemand_QuickDon15sec";
    }

    part def AvionicsCoolingUnit {
        attribute coolFlow_kgPerSec      : Real = 0.7;
        attribute coolantType            : String = "RamAirAndGroundBlower";
    }

    part def HEPAFiltrationUnit {
        doc /* HEPA filters on recirculation — 99.97% filtration efficiency. */
        attribute efficiency_pct         : Real = 99.97;
        attribute exchangeRatePerHr      : Real = 20.0;  // complete air changes per hour
    }

    // ─── 7. HYDRAULIC SYSTEM ─────────────────────────────────────────────────

    part def HydraulicSystem {
        doc /* 777-9X: Three independent 3,000 psi systems — Left, Center, Right.
               Each system fed by engine-driven pump + electric backup pump.
               Center system also drives wing-tip fold. */

        part systemLeft    : HydraulicCircuit;
        part systemCenter  : HydraulicCircuit;
        part systemRight   : HydraulicCircuit;
        part rat           : RamAirTurbine;
        part ptu           : PowerTransferUnit;

        port primaryFCSSupply : HydraulicPort;
        port pumpControl      : ElectricalBusPort;
        port wingFoldSupply   : HydraulicPort;
    }

    part def HydraulicCircuit {
        attribute operatingPressure_psi  : Real = 3000.0;
        attribute capacity_L             : Real = 56.0;    // 777-9X larger reservoir
        attribute fluidSpec              : String = "Skydrol_LD4_PhosphateEster";

        part enginePump  : EngineDrivenHydPump;
        part electricPump : ElectricMotorPump;
        part groundPump  : ACElectricMotorPump;
        part filterUnit  : HydFilter;
    }

    part def EngineDrivenHydPump {
        attribute flowRate_LPerMin       : Real = 95.0;
        attribute speedRange_RPM         : String = "1300_to_5200";
    }

    part def ElectricMotorPump {
        attribute flowRate_LPerMin       : Real = 57.0;
        attribute motorPower_kW          : Real = 15.0;
        attribute motorVoltage_V         : Real = 115.0;
    }

    part def ACElectricMotorPump {
        doc /* Ground service pump for hydraulic operations on the ground without engines. */
        attribute flowRate_LPerMin       : Real = 57.0;
        attribute motorVoltage_V         : Real = 115.0;
    }

    part def HydFilter {
        attribute filtrationRating_micron : Real = 3.0;
        attribute bypassIndicator         : Boolean = true;
    }

    part def RamAirTurbine {
        doc /* Emergency RAT — deploys in 2 seconds; drives hydraulic pump + small AC generator. */
        attribute deployTime_sec         : Real = 2.0;
        attribute minAirspeed_kts        : Real = 130.0;
        attribute hydraulicOutput_LPerMin : Real = 45.0;
        attribute electricOutput_kVA     : Real = 7.5;
    }

    part def PowerTransferUnit {
        doc /* PTU — shares hydraulic power between Left and Right circuits. */
        attribute type                   : String = "BidirectionalHydrostaticPTU";
    }

    // ─── 8. ELECTRICAL POWER SYSTEM ─────────────────────────────────────────

    part def ElectricalPowerSystem {
        doc /* 777-9X uses variable-frequency generators (VFG) directly from GE9X shafts.
               No Constant Speed Drive required. Dual 120 kVA VFG per engine + APU. */

        part vfg_L       : IntegratedDriveGenerator;   // VFG Left engine
        part vfg_R       : IntegratedDriveGenerator;   // VFG Right engine
        part apuGen      : APUGenerator;
        part battery     : AircraftBattery[2];
        part busTieRly   : BusTieContactor[4];
        part tru         : TransformerRectifierUnit[4];

        port acBusInput    : ElectricalBusPort;
        port dcBus28V      : ElectricalBusPort;
        port emergencyBus  : ElectricalBusPort;
    }

    part def APUGenerator {
        attribute type                   : String = "APS5000_APU_Generator";
        attribute ratedPower_kVA         : Real = 120.0;
        attribute outputVoltage_V        : Real = 115.0;
        attribute outputFreq_Hz          : String = "360_to_800";  // VF output
    }

    part def AircraftBattery {
        attribute chemistry              : String = "Li_NiCad_Main_APUStart";
        attribute capacity_Ah            : Real = 60.0;
        attribute voltage_V              : Real = 24.0;
        attribute emergencyDuration_min  : Real = 30.0;
    }

    part def BusTieContactor {
        attribute rating_kVA             : Real = 120.0;
        attribute arcFaultProtection     : Boolean = true;
    }

    part def TransformerRectifierUnit {
        attribute acInput_V              : Real = 115.0;
        attribute dcOutput_V             : Real = 28.0;
        attribute ratedCurrent_A         : Real = 250.0;
    }

    // ─── 9. FUEL SYSTEM ──────────────────────────────────────────────────────

    part def FuelSystem {
        doc /* 777-9X total fuel capacity: 195,285 litres / 61,530 US gal.
               Main tanks in composite wing box + center tank. FQMS with CG management.
               SAF-capable per Boeing commitment. */

        part mainTank_L    : FuelTank;
        part mainTank_R    : FuelTank;
        part centerTank    : FuelTank;
        part boostPump_L1  : BoostPump;
        part boostPump_L2  : BoostPump;
        part boostPump_R1  : BoostPump;
        part boostPump_R2  : BoostPump;
        part boostPump_C1  : BoostPump;
        part boostPump_C2  : BoostPump;
        part crossfeedValve : CrossfeedValve;
        part sumpValves    : SumpDrainValve[6];
        part fqms          : FuelQtyMgmtSystem;
        part refuelManifold : DefuelRefuelManifold;

        port engineFeedPort  : FuelFlowPort;
        port apuFeedPort     : FuelFlowPort;
        port refuelPort      : FuelServicePort;
    }

    part def FuelTank {
        attribute usableCapacity_L       : Real = 65000.0;   // each main wing tank ~65,000 L
        attribute fuelSpec               : String = "JetA_JetA1_100pctSAF_capable";
        attribute integralWingTank       : Boolean = true;
        attribute lightningProtection    : Boolean = true;
        attribute inerting               : String = "OBIGGS_NitrogenInertingSystem";
    }

    part def BoostPump {
        attribute flowRate_LPerMin       : Real = 570.0;
        attribute motorPower_kW          : Real = 4.0;
        attribute submergedType          : Boolean = true;
    }

    part def CrossfeedValve {
        attribute normallyOpen           : Boolean = false;
        attribute failsafePosition       : String = "As_Last_Commanded";
    }

    part def SumpDrainValve {
        attribute type                   : String = "QuickDrainSump";
    }

    part def FuelQtyMgmtSystem {
        attribute accuracy_pct           : Real = 0.3;
        attribute probeCount             : Integer = 28;
        attribute cgCalculation          : Boolean = true;
        attribute jettison               : Boolean = false;   // 777-9X has no jettison
        attribute softwareLevel          : String = "DO178C_LevelC";
    }

    part def DefuelRefuelManifold {
        attribute maxRefuelRate_LPerMin  : Real = 2400.0;
        attribute underwingPoints        : Integer = 2;
        attribute singlePointDefuel      : Boolean = true;
    }

    // ─── 10. COMMUNICATIONS SYSTEM ───────────────────────────────────────────

    part def CommunicationsSystem {
        doc /* VHF × 3, HF × 2, SATCOM (Inmarsat + Iridium), ACARS, CVR/FDR, ADS-B, ELT. */

        part vhf_1    : VHFRadio;
        part vhf_2    : VHFRadio;
        part vhf_3    : VHFRadio;
        part hf_1     : HFRadio;
        part hf_2     : HFRadio;
        part satcom   : SATCOMSystem;
        part acars    : ACARSUnit;
        part cvr      : CockpitVoiceRecorder;
        part fdr      : FlightDataRecorder;
        part elt      : EmergencyLocatorTransmitter;
        part adsb     : ADS_B_Out;

        port atcDataLink : DataLinkPort;
    }

    part def VHFRadio {
        attribute freqRange_MHz          : String = "118.0_to_137.0";
        attribute channelSpacing_kHz     : Real = 8.33;
        attribute outputPower_W          : Real = 25.0;
        attribute tsoStandard            : String = "TSO-C169a";
    }

    part def HFRadio {
        attribute freqRange_MHz          : String = "2.0_to_30.0";
        attribute outputPower_W          : Real = 400.0;
        attribute ssbSelcal              : Boolean = true;
    }

    part def SATCOMSystem {
        attribute constellations         : String = "Inmarsat_Iridium_NEXT";
        attribute services               : String = "ClassicAero_SwiftBroadband_L3";
        attribute dataRate_kbps          : Real = 700.0;
    }

    part def ACARSUnit {
        attribute standard               : String = "ARINC618_620_622_631";
        attribute vhfDatalink            : Boolean = true;
        attribute hfdl                   : Boolean = true;
        attribute satcomDatalink         : Boolean = true;
    }

    part def CockpitVoiceRecorder {
        attribute standard               : String = "EUROCAE_ED193";  // 2-hr solid state
        attribute recordingTime_min      : Real = 120.0;
        attribute channels               : Integer = 4;
        attribute crashSurvivable        : Boolean = true;
        attribute underwaterLocatorBeacon : Boolean = true;
    }

    part def FlightDataRecorder {
        attribute standard               : String = "EUROCAE_ED112A_25hr";
        attribute parameters             : Integer = 3000;
        attribute recordingTime_h        : Real = 25.0;
        attribute crashSurvivable        : Boolean = true;
    }

    part def EmergencyLocatorTransmitter {
        attribute type                   : String = "406MHz_Cospas_Sarsat";
        attribute activationType         : String = "Automatic_Manual_Water";
    }

    part def ADS_B_Out {
        attribute standard               : String = "DO260B_1090ES_GHz";
        attribute maxRange_nmi           : Real = 250.0;
        attribute nuc                    : String = "NUCp_8_or_better";
    }

    // ─── 11. CABIN SYSTEM ────────────────────────────────────────────────────

    part def CabinSystem {
        doc /* 777-9X wide-body twin-aisle — 426 typical 3-class / 524 max single class.
               9-abreast economy (3-3-3) standard. Boeing Sky Interior. */

        part cabinSeats      : PassengerSeat[426];
        part emergEquip      : EmergencyEquipmentGroup;
        part ife             : IFESystem;
        part galley          : GalleySystem;
        part lavatory        : LavSystem[8];
        part stowBins        : OverheadBinSystem;
        part crewRest        : CrewRestArea;

        port freshAirDemand  : CabinDuctPort;
        port cabinDataNet    : CabinDataNetPort;
    }

    part def PassengerSeat {
        attribute certLoad_g             : Real = 16.0;    // CS-25.562
        attribute seatPitch_in           : Real = 32.0;    // economy
        attribute fireResistance         : String = "CS25_853_App_F";
    }

    part def EmergencyEquipmentGroup {
        part lifevests   : LifeVest[440];
        part slides      : EmergencySlide[12];   // 6 doors × 2 exits each
        part fireExt     : FireExtinguisher[8];
        part emgLighting : EmergencyLightingSystem;
        part axes        : EmergencyAxe[2];
    }

    part def EmergencySlide {
        attribute deployTime_sec         : Real = 6.0;     // CS-25.809
        attribute certCapacity           : Integer = 70;   // large aircraft
    }

    part def FireExtinguisher {
        attribute agent                  : String = "HFC227ea_Halon_Replacement";
    }

    part def EmergencyLightingSystem {
        attribute batteryBackup_min      : Real = 10.0;
        attribute floorPathLighting      : Boolean = true;
        attribute exitRowMarking         : Boolean = true;
    }

    part def EmergencyAxe { attribute material : String = "TitaniumHandle"; }

    part def IFESystem {
        attribute seatbackScreens        : Boolean = true;
        attribute screenSize_in          : Real = 13.3;
        attribute wifiType               : String = "KaBand_SATCOM_V_Band";
        attribute streamingCapacity_Mbps : Real = 100.0;
        attribute classCapability        : String = "Economy_Business_First";
    }

    part def GalleySystem {
        attribute locations              : String = "FWD_MID_AFT_777Layout";
        attribute ovens                  : Integer = 12;
        attribute convectionOvens        : Integer = 6;
    }

    part def LavSystem {
        attribute waterCapacity_L        : Real = 30.0;
        attribute vacuumToilet           : Boolean = true;
        attribute handwashStation        : Boolean = true;
    }

    part def OverheadBinSystem {
        attribute type                   : String = "SkyBin_777X_Enlarged";
        attribute capacityPerRow_bags    : Integer = 6;
    }

    part def CrewRestArea {
        doc /* Flight crew rest bunks above main deck (typical 777 long-range crew rest). */
        attribute type                   : String = "BunkTypeAboveDeck";
        attribute bunkCount              : Integer = 4;
    }

    // ─── 12. HEALTH MONITORING SYSTEM ────────────────────────────────────────

    part def HealthMonitoringSystem {
        doc /* Boeing AHM (Aircraft Health Management), ACMS, CMS.
               AI-enabled prognostic monitoring for engines, structures, and systems. */

        part ahm         : AircraftHealthMgmtSystem;
        part acms        : AircraftConditionMonitor;
        part cmc         : CentralMaintenanceComputer;
        part vibMon      : EngineVibrationMonitor;
        part structMon   : StructuralHealthMonitor;

        port systemAlerts    : ARINC429Port;
        port maintDataPort   : MaintenanceDataPort;
    }

    part def AircraftHealthMgmtSystem {
        doc /* Boeing AHM — real-time remote monitoring via ACARS. */
        attribute paramCount             : Integer = 4000;
        attribute aiPrognostics          : Boolean = true;
        attribute remoteMonitoring       : Boolean = true;
        attribute acarsReporting         : Boolean = true;
    }

    part def AircraftConditionMonitor {
        attribute sampleRateHz           : Real = 8.0;
        attribute storageGB              : Real = 2048.0;
    }

    part def CentralMaintenanceComputer {
        attribute lruIsolation           : Boolean = true;
        attribute builtInTest            : Boolean = true;
        attribute softwareLevel          : String = "DO178C_LevelC";
    }

    part def EngineVibrationMonitor {
        attribute sensorsPerEngine       : Integer = 10;
        attribute alarmThreshold_g       : Real = 2.5;
    }

    part def StructuralHealthMonitor {
        doc /* Eddy-current and strain gauge monitoring on composite wing box. */
        attribute gaugeCount             : Integer = 120;
        attribute monitoredZones         : String = "WingBox_LandingGearAttach_FuselageJoints";
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PORT DEFINITIONS
    // ═════════════════════════════════════════════════════════════════════════

    port def AirflowPort {
        attribute massFlow_kgPerSec      : Real;
        attribute pressure_kPa           : Real;
        attribute temperature_K          : Real;
    }

    port def BleedAirPort {
        attribute pressure_kPa           : Real;
        attribute temperature_K          : Real;
        attribute massFlow_kgPerSec      : Real;
    }

    port def FuelFlowPort {
        attribute massFlow_kgPerSec      : Real;
        attribute pressure_kPa           : Real;
        attribute fuelSpec               : String;
    }

    port def ElectricalBusPort {
        attribute voltage_V              : Real;
        attribute frequencyHz            : Real;
        attribute power_kVA              : Real;
    }

    port def HydraulicPort {
        attribute pressure_psi           : Real;
        attribute flow_LPerMin           : Real;
        attribute fluidType              : String;
    }

    port def ARINC429Port {
        attribute dataRate_bps           : Integer = 100000;
    }

    port def ARINC629Port {
        attribute dataRate_Mbps          : Real = 2.0;
    }

    port def ARINC664Port {
        attribute dataRate_Mbps          : Real = 100.0;
    }

    port def ThrustCommandPort {
        attribute throttlePos_pct        : Real;
        attribute targetThrust_N         : Real;
    }

    port def ThrustPort {
        attribute thrust_N               : Real;
    }

    port def MechanicalInputPort {
        attribute force_N                : Real;
        attribute displacement_mm        : Real;
    }

    port def DataLinkPort {
        attribute protocol               : String;
        attribute dataRate_kbps          : Real;
    }

    port def GroundContactPort {
        attribute normalLoad_kN          : Real;
        attribute lateralLoad_kN         : Real;
    }

    port def AtmosphericPort {
        attribute ambientPressure_kPa    : Real;
        attribute ambientTemp_K          : Real;
        attribute densityAlt_ft          : Real;
    }

    port def GroundPowerPort {
        attribute voltage_V              : Real = 115.0;
        attribute frequency_Hz           : Real = 400.0;
    }

    port def FuelServicePort {
        attribute flowRate_LPerMin       : Real;
        attribute fuelSpec               : String;
    }

    port def CabinDuctPort {
        attribute massFlow_kgPerSec      : Real;
        attribute supplyTemp_degC        : Real;
    }

    port def OutflowValvePort {
        attribute position_pct           : Real;
        attribute diffPressure_psi       : Real;
    }

    port def DiscreteDataPort {
        attribute signalCount            : Integer;
    }

    port def MaintenanceDataPort {
        attribute protocol               : String = "ARINC615A_Wireless";
    }

    port def CabinDataNetPort {
        attribute standard               : String = "ARINC763_IP_GbE";
    }

    port def FuelInterfacePort {
        attribute capacity_L             : Real;
    }

    port def SystemsDuctPort {
        attribute bundleType             : String;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // REQUIREMENTS
    // ═════════════════════════════════════════════════════════════════════════

    // ── Performance Requirements ──────────────────────────────────────────────

    requirement def REQ_PERF_001_Range {
        doc /* REQ-PERF-001: The aircraft SHALL achieve a minimum design range of 7,295 nmi
               carrying 426 passengers in 3-class configuration with standard reserves (FAR international). */
        subject aircraft : Aircraft;
        attribute minRange_nmi            : Real = 7295.0;
        attribute paxLoad                 : Integer = 426;
    }

    requirement def REQ_PERF_002_CruiseSpeed {
        doc /* REQ-PERF-002: The aircraft SHALL achieve a minimum cruise speed of Mach 0.85
               at FL390 at max cruise weight, ISA+0. */
        subject aircraft : Aircraft;
        attribute minCruiseMach           : Real = 0.85;
        attribute altitude_ft             : Real = 39000.0;
    }

    requirement def REQ_PERF_003_TakeoffFieldLength {
        doc /* REQ-PERF-003: Balanced field length SHALL not exceed 3,050 m at MTOW / ISA SL / dry runway.
               [CS-25.113] */
        subject aircraft : Aircraft;
        attribute maxBFL_m                : Real = 3050.0;
    }

    requirement def REQ_PERF_004_LandingDistance {
        doc /* REQ-PERF-004: Landing distance at MLW SHALL not exceed 2,000 m on a dry runway
               at ISA SL, with autobrake MAX. [CS-25.125] */
        subject aircraft : Aircraft;
        attribute maxLandingDist_m        : Real = 2000.0;
    }

    requirement def REQ_PERF_005_InitialCruiseAltitude {
        doc /* REQ-PERF-005: At MTOW / ISA+10, the aircraft SHALL reach FL350 within 30 minutes
               of brake release. */
        subject aircraft : Aircraft;
        attribute targetAlt_ft            : Real = 35000.0;
        attribute maxClimbTime_min        : Real = 30.0;
    }

    requirement def REQ_PERF_006_VMO_MMO {
        doc /* REQ-PERF-006: Maximum operating speed SHALL be 330 KIAS below FL310 and Mach 0.89
               above FL310. [CS-25.1505] */
        subject aircraft : Aircraft;
        attribute vmo_kias                : Real = 330.0;
        attribute mmo                     : Real = 0.89;
    }

    requirement def REQ_PERF_007_OEI_ClimbGrad {
        doc /* REQ-PERF-007: With one engine inoperative at V2, the aircraft SHALL achieve
               a minimum second-segment climb gradient of 2.4% at sea level ISA. [CS-25.121] */
        subject propulsion : PropulsionSystem;
        attribute minClimbGrad_pct        : Real = 2.4;
    }

    requirement def REQ_PERF_008_FuelEfficiency {
        doc /* REQ-PERF-008: Aircraft SHALL achieve minimum 20% fuel burn improvement versus
               Boeing 777-300ER at equivalent payload/range. */
        subject aircraft : Aircraft;
        attribute fuelBurnImprovement_pct : Real = 20.0;
        attribute referenceAircraft       : String = "Boeing_777_300ER";
    }

    // ── Structural Requirements ───────────────────────────────────────────────

    requirement def REQ_STRUCT_001_LimitLoad {
        doc /* REQ-STRUCT-001: The airframe SHALL withstand +2.5g positive and -1.0g negative
               limit load factors without permanent deformation. [CS-25.337] */
        subject airframe : Airframe;
        attribute posLimitG               : Real = 2.5;
        attribute negLimitG               : Real = -1.0;
    }

    requirement def REQ_STRUCT_002_UltimateLoad {
        doc /* REQ-STRUCT-002: The airframe SHALL sustain 1.5 × limit load for 3 seconds
               without failure. [CS-25.305] */
        subject airframe : Airframe;
        attribute ultimateLoadFactor      : Real = 3.75;
    }

    requirement def REQ_STRUCT_003_Pressurization {
        doc /* REQ-STRUCT-003: The fuselage SHALL sustain 9.4 psi differential pressure
               throughout the certified service life without crack propagation. [CS-25.365] */
        subject fuselage : FuselageAssembly;
        attribute maxDiffPressure_psi     : Real = 9.4;
    }

    requirement def REQ_STRUCT_004_FailSafe {
        doc /* REQ-STRUCT-004: Primary structure SHALL be fail-safe. Any single primary structural
               element failure SHALL be arrested and detectable before next heavy check. [CS-25.571] */
        subject airframe : Airframe;
        attribute failSafe                : Boolean = true;
        attribute damageTolerant          : Boolean = true;
    }

    requirement def REQ_STRUCT_005_CompositeWingIntegrity {
        doc /* REQ-STRUCT-005: The composite wing SHALL demonstrate equivalent structural
               integrity to metallic wings including lightning strike and impact tolerance.
               Compliance per AC 20-107B. */
        subject wing : WingAssembly;
        attribute lightningStrikeCompliance : String = "AC20_107B";
    }

    requirement def REQ_STRUCT_006_WingTipFoldLockout {
        doc /* REQ-STRUCT-006: The folding wing tip lock mechanism SHALL sustain design limit
               load with any single lock pin failed. Minimum 4 active lock pins required. */
        subject wingTip : FoldingWingTipAssembly;
        attribute minLockPins             : Integer = 4;
        attribute singlePinFailSafe       : Boolean = true;
    }

    // ── Safety Requirements ───────────────────────────────────────────────────

    requirement def REQ_SAFE_001_Catastrophic {
        doc /* REQ-SAFE-001: No single failure or combination of failures not shown extremely
               improbable SHALL result in a catastrophic condition.
               Catastrophic probability SHALL be < 1×10⁻⁹ per FH. [CS-25.1309, ARP 4754A] */
        subject aircraft : Aircraft;
        attribute maxCatProb_perFH        : Real = 1.0e-9;
    }

    requirement def REQ_SAFE_002_Hazardous {
        doc /* REQ-SAFE-002: Hazardous failure condition probability SHALL be < 1×10⁻⁷ per FH.
               [CS-25.1309] */
        subject aircraft : Aircraft;
        attribute maxHazProb_perFH        : Real = 1.0e-7;
    }

    requirement def REQ_SAFE_003_FADEC_DAL {
        doc /* REQ-SAFE-003: FADEC software SHALL comply with DO-178C Level A.
               FADEC hardware SHALL comply with DO-254 Level A. Dual channel minimum. */
        subject fadec : FADECUnit;
        attribute softwareDAL             : String = "DO178C_LevelA";
        attribute hardwareDAL             : String = "DO254_LevelA";
    }

    requirement def REQ_SAFE_004_FCS_DAL {
        doc /* REQ-SAFE-004: PFC software SHALL comply with DO-178C Level A.
               No single PFC failure SHALL prevent continued safe flight and landing. */
        subject pfc : PrimaryFlightComputer;
        attribute softwareDAL             : String = "DO178C_LevelA";
        attribute minPFCRedundancy        : Integer = 3;
    }

    requirement def REQ_SAFE_005_AutolandCATIII {
        doc /* REQ-SAFE-005: Autoland system SHALL support CAT IIIb with DH 15 ft and RVR 75 m.
               Unsafe go-around probability SHALL be < 5×10⁻⁶ per approach. [CS-AWO 321] */
        subject afcs : AutopilotFlightDirectorSystem;
        attribute minDH_ft                : Real = 15.0;
        attribute minRVR_m                : Real = 75.0;
    }

    requirement def REQ_SAFE_006_HydRedundancy {
        doc /* REQ-SAFE-006: Loss of any single hydraulic circuit SHALL not prevent continued
               safe flight. At least two circuits SHALL independently service primary controls. */
        subject hydraulics : HydraulicSystem;
        attribute independentCircuits     : Integer = 3;
    }

    requirement def REQ_SAFE_007_EmergencyPower {
        doc /* REQ-SAFE-007: Following dual-generator failure, aircraft SHALL have sufficient
               emergency power to maneuver for ≥ 30 minutes. RAT SHALL deploy within 2 seconds. */
        subject electrical : ElectricalPowerSystem;
        attribute emergEndurance_min      : Real = 30.0;
        attribute ratDeployTime_sec       : Real = 2.0;
    }

    requirement def REQ_SAFE_008_WingFoldInterlock {
        doc /* REQ-SAFE-008: The wing-tip fold SHALL be interlocked to prevent in-flight actuation.
               The system SHALL verify wing-tip locked before permitting throttle advance. [CS-25.671] */
        subject wingTip : FoldingWingTipAssembly;
        attribute interlockWOW            : Boolean = true;
        attribute preflightVerification   : Boolean = true;
    }

    requirement def REQ_SAFE_009_ETOPS330 {
        doc /* REQ-SAFE-009: The aircraft / engine combination SHALL be approved for ETOPS 330 min.
               Engine IFSD rate SHALL not exceed 0.005 per 1,000 engine flight hours. */
        subject aircraft : Aircraft;
        attribute etopsRating_min         : Real = 330.0;
        attribute maxIFSD_per1000EFH      : Real = 0.005;
    }

    requirement def REQ_SAFE_010_OxygenDeployTime {
        doc /* REQ-SAFE-010: Passenger O₂ masks SHALL deploy automatically within 2 seconds
               of cabin altitude exceeding 14,000 ft. [CS-25.1447] */
        subject oxy : OxygenSystem;
        attribute maxDeployTime_sec       : Real = 2.0;
        attribute triggerAltitude_ft      : Real = 14000.0;
    }

    requirement def REQ_SAFE_011_EngineContainment {
        doc /* REQ-SAFE-011: Engine rotor burst event SHALL be contained within the nacelle
               or result in no unsafe aircraft condition. [CS-25.903(d)] */
        subject engine : GE9XEngineAssembly;
        attribute rotorBurstContained     : Boolean = true;
    }

    // ── Environmental Requirements ────────────────────────────────────────────

    requirement def REQ_ENV_001_Noise {
        doc /* REQ-ENV-001: Aircraft SHALL comply with ICAO Annex 16 Chapter 14 noise limits
               at flyover, lateral, and approach measuring points. */
        subject aircraft : Aircraft;
        attribute noiseStandard           : String = "ICAO_Annex16_Chapter14";
    }

    requirement def REQ_ENV_002_NOx {
        doc /* REQ-ENV-002: GE9X engine NOx emissions SHALL comply with ICAO CAEP/8 standard
               with minimum 25% margin across the LTO cycle. */
        subject engine : GE9XEngineAssembly;
        attribute noxStandard             : String = "ICAO_CAEP8";
        attribute marginPct               : Real = 25.0;
    }

    requirement def REQ_ENV_003_SAFCapability {
        doc /* REQ-ENV-003: Aircraft fuel system and engines SHALL be certified for up to 100%
               Sustainable Aviation Fuel (SAF) blend. */
        subject aircraft : Aircraft;
        attribute maxSAFBlend_pct         : Real = 100.0;
    }

    requirement def REQ_ENV_004_CO2 {
        doc /* REQ-ENV-004: Aircraft SHALL meet ICAO CORSIA baseline CO₂ standard and
               ICAO Annex 16 Vol. III CO₂ metric value requirements. */
        subject aircraft : Aircraft;
        attribute co2Standard             : String = "ICAO_CORSIA_Annex16_Vol3";
    }

    // ── Maintenance & Operational Requirements ────────────────────────────────

    requirement def REQ_OPS_001_ServiceLife {
        doc /* REQ-OPS-001: Structural design life SHALL be not less than 100,000 flight hours
               or 40,000 flight cycles, whichever occurs first. */
        subject airframe : Airframe;
        attribute designLife_fh           : Real = 100000.0;
        attribute designLife_fc           : Real = 40000.0;
    }

    requirement def REQ_OPS_002_TurnaroundTime {
        doc /* REQ-OPS-002: Ground turnaround (deplaning / cleaning / fuel / catering / boarding)
               SHALL complete within 90 minutes at gates with standard widebody ground equipment. */
        subject aircraft : Aircraft;
        attribute maxTurnaround_min       : Real = 90.0;
    }

    requirement def REQ_OPS_003_GateCompatibility {
        doc /* REQ-OPS-003: Aircraft with wing tips folded SHALL fit ICAO Aerodrome Reference
               Code E (65 m wingspan) gate restrictions. */
        subject aircraft : Aircraft;
        attribute maxFoldedSpan_m         : Real = 64.82;
        attribute icaoCode                : String = "ICAO_Code_E_65m";
    }

    requirement def REQ_OPS_004_Dispatch_MTTR {
        doc /* REQ-OPS-004: Aircraft dispatch reliability SHALL exceed 99.0%.
               No-go LRU mean-time-to-repair SHALL not exceed 4 hours with two technicians. */
        subject aircraft : Aircraft;
        attribute minDispatchReliability_pct : Real = 99.0;
        attribute maxMTTR_hr              : Real = 4.0;
    }

    // ── Interface Requirements ────────────────────────────────────────────────

    requirement def REQ_IFR_001_ARINC629 {
        doc /* REQ-IFR-001: Flight-critical avionics systems SHALL communicate via ARINC 629
               multiplex databus per ARINC 629 Part 1-7 specification. */
        subject avionics : AvionicsSuite;
        attribute dataBusStandard         : String = "ARINC629_Part1_7";
    }

    requirement def REQ_IFR_002_ADS_B_Out {
        doc /* REQ-IFR-002: Aircraft SHALL broadcast ADS-B Out per DO-260B / 1090 MHz ES
               with NUCp ≥ 8. ICAO Doc 9684 Section 3.6 compliant. */
        subject avionics : AvionicsSuite;
        attribute adsbStandard            : String = "DO260B_1090ES";
        attribute minNUCp                 : Integer = 8;
    }

    requirement def REQ_IFR_003_FuelPressure {
        doc /* REQ-IFR-003: Engine fuel inlet pressure SHALL be maintained between 8 and 55 psi
               at all flight phases and altitudes to prevent starvation. */
        subject fuelSys : FuelSystem;
        attribute minInletPressure_psi    : Real = 8.0;
        attribute maxInletPressure_psi    : Real = 55.0;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // FUNCTION → COMPONENT ALLOCATION (ARP 4754A functional allocation)
    // Each aircraft-level function is allocated to its primary implementing
    // physical subsystem. Derived from the 777X PSSA/SSA allocation matrix.
    // ═════════════════════════════════════════════════════════════════════════

    // F-01: Lift and drag control → FCS + Airframe
    allocate ProvideLiftDragControl         to FlightControlSystem;
    allocate ManageWingLift                 to FlightControlSystem;
    allocate ManageDragDevices              to FlightControlSystem;
    allocate ManageHighLiftDevices          to FlightControlSystem;
    allocate ControlDirectionalStability    to FlightControlSystem;
    allocate ManageFoldingWingTip           to FoldingWingTipAssembly;

    // F-02: Thrust → Propulsion
    allocate ProvideThrust                  to PropulsionSystem;
    allocate GenerateThrust                 to GE9XEngineAssembly;
    allocate RegulateThrust                 to FADECUnit;
    allocate ManageFuelSupplyFunction       to FuelSystem;
    allocate MonitorEngineHealth            to HealthMonitoringSystem;
    allocate ReverseThrust                  to ThrustReverserAssembly;

    // F-03: Navigation and guidance → Avionics
    allocate NavigateAndGuide               to AvionicsSuite;
    allocate DeterminePosition              to AvionicsSuite;
    allocate PlanRoute                      to AvionicsSuite;
    allocate IssueGuidanceCommands          to AutopilotFlightDirectorSystem;
    allocate ManageFlightEnvelope           to PrimaryFlightComputer;
    allocate ManagePerformanceBasedNav      to AvionicsSuite;

    // F-04: Attitude and flight path → FCS
    allocate ControlAttitudeFlightPath      to FlightControlSystem;
    allocate ReceivePilotInput              to PrimaryFlightComputer;
    allocate ComputeControlLaws             to PrimaryFlightComputer;
    allocate ActuatePrimaryFlightSurfaces   to FlightControlSystem;
    allocate ManageEnvelopeProtection       to PrimaryFlightComputer;

    // F-05: Power generation → Electrical + Hydraulic
    allocate ManagePowerGenDist             to ElectricalPowerSystem;
    allocate GenerateACPower                to ElectricalPowerSystem;
    allocate DistributeACPower              to ElectricalPowerSystem;
    allocate GenerateHydraulicPower         to HydraulicSystem;
    allocate DistributeHydraulicPower       to HydraulicSystem;
    allocate ManageEmergencyPower           to ElectricalPowerSystem;

    // F-06: Environmental control → ECS
    allocate ManageEnvControl               to EnvironmentalControlSystem;
    allocate PressurizeCabin                to EnvironmentalControlSystem;
    allocate ControlCabinTemperature        to EnvironmentalControlSystem;
    allocate ManageOxygenSupply             to OxygenSystem;
    allocate MonitorAirQuality              to EnvironmentalControlSystem;

    // F-07: Landing and ground ops → Landing gear
    allocate ManageLandingGround            to LandingGearSystem;
    allocate ExtendRetractGear              to LandingGearSystem;
    allocate ApplyBraking                   to LandingGearSystem;
    allocate SteerOnGround                  to LandingGearSystem;
    allocate ManageWeightOnWheels           to LandingGearSystem;
    allocate SequenceWingFoldOnGround       to FoldingWingTipAssembly;

    // F-08: Communications and datalink → Comms
    allocate CommunicateDatalink            to CommunicationsSystem;
    allocate VoiceCommsATC                  to CommunicationsSystem;
    allocate AcarsDatalink                  to CommunicationsSystem;
    allocate CrewIntercomm                  to CommunicationsSystem;
    allocate EmergencyComms                 to CommunicationsSystem;
    allocate PassengerConnectivity          to CabinSystem;

    // F-09: Health monitoring → AHM
    allocate MonitorSystemHealth            to HealthMonitoringSystem;
    allocate DetectFaults                   to HealthMonitoringSystem;
    allocate LogMaintenanceData             to HealthMonitoringSystem;
    allocate AlertCrewAbnormalities         to AvionicsSuite;
    allocate PredictFailures                to HealthMonitoringSystem;

    // ═════════════════════════════════════════════════════════════════════════
    // REQUIREMENTS SATISFACTION — Components satisfy requirements
    // ═════════════════════════════════════════════════════════════════════════

    // Performance
    satisfy REQ_PERF_001_Range by propulsion_i;
    satisfy REQ_PERF_002_CruiseSpeed by provideThrust_f;
    satisfy REQ_PERF_003_TakeoffFieldLength by provideThrust_f;
    satisfy REQ_PERF_004_LandingDistance by applyBraking_f;
    satisfy REQ_PERF_007_OEI_ClimbGrad by propulsion_i;
    satisfy REQ_PERF_008_FuelEfficiency by propulsion_i;

    // Structural
    satisfy REQ_STRUCT_001_LimitLoad by airframe_i;
    satisfy REQ_STRUCT_002_UltimateLoad by airframe_i;
    satisfy REQ_STRUCT_003_Pressurization by fuselage_i;
    satisfy REQ_STRUCT_004_FailSafe by airframe_i;
    satisfy REQ_STRUCT_005_CompositeWingIntegrity by wing_i;
    satisfy REQ_STRUCT_006_WingTipFoldLockout by foldingTip_i;

    // Safety
    satisfy REQ_SAFE_001_Catastrophic by aircraft_i;
    satisfy REQ_SAFE_002_Hazardous by aircraft_i;
    satisfy REQ_SAFE_003_FADEC_DAL by fadec_i;
    satisfy REQ_SAFE_004_FCS_DAL by pfc_i;
    satisfy REQ_SAFE_005_AutolandCATIII by afcs_i;
    satisfy REQ_SAFE_006_HydRedundancy by hydraulics_i;
    satisfy REQ_SAFE_007_EmergencyPower by electrical_i;
    satisfy REQ_SAFE_008_WingFoldInterlock by foldingTip_i;
    satisfy REQ_SAFE_009_ETOPS330 by propulsion_i;
    satisfy REQ_SAFE_010_OxygenDeployTime by oxygen_i;

    // Environmental
    satisfy REQ_ENV_001_Noise by propulsion_i;
    satisfy REQ_ENV_002_NOx by engine_i;
    satisfy REQ_ENV_003_SAFCapability by engine_i;
    satisfy REQ_ENV_004_CO2 by propulsion_i;

    // Operational
    satisfy REQ_OPS_001_ServiceLife by airframe_i;
    satisfy REQ_OPS_003_GateCompatibility by aircraft_i;

    // Interface
    satisfy REQ_IFR_001_ARINC629 by avionics_i;
    satisfy REQ_IFR_002_ADS_B_Out by avionics_i;
    satisfy REQ_IFR_003_FuelPressure by fuel_i;

    // ── Instance references ────────────────────────────────────────────────
    part aircraft_i    : Aircraft;
    part propulsion_i  : PropulsionSystem;
    part airframe_i    : Airframe;
    part fuselage_i    : FuselageAssembly;
    part wing_i        : WingAssembly;
    part foldingTip_i  : FoldingWingTipAssembly;
    part engine_i      : GE9XEngineAssembly;
    part fadec_i       : FADECUnit;
    part pfc_i         : PrimaryFlightComputer;
    part afcs_i        : AutopilotFlightDirectorSystem;
    part hydraulics_i  : HydraulicSystem;
    part electrical_i  : ElectricalPowerSystem;
    part fuel_i        : FuelSystem;
    part oxygen_i      : OxygenSystem;
    part avionics_i    : AvionicsSuite;

    // Functional instance references
    action provideThrust_f   : ProvideThrust;
    action manageFuel_f      : ManageFuelSupplyFunction;
    action manageHighLift_f  : ManageHighLiftDevices;
    action applyBraking_f    : ApplyBraking;
    action navigateGuide_f   : NavigateAndGuide;

    // ═════════════════════════════════════════════════════════════════════════
    // VERIFICATION CONSTRAINTS
    // ═════════════════════════════════════════════════════════════════════════

    constraint def C_FADEC_FailureRate {
        doc /* FADEC catastrophic failure rate constraint — ≤ 1×10⁻⁹ /FH. */
        subject f : FADECUnit;
        assert constraint : f.failureRatePerFH <= 1.0e-9;
    }

    constraint def C_CruiseMachMin {
        doc /* Cruise Mach must meet REQ-PERF-002 minimum. */
        subject a : Aircraft;
        assert constraint : a.cruiseMach >= 0.85;
    }

    constraint def C_MMO_Ceiling {
        doc /* Maximum operating Mach shall not be set above certified MMO. */
        subject a : Aircraft;
        assert constraint : a.mmo <= 0.89;
    }

    constraint def C_MTOW_Limit {
        doc /* Aircraft takeoff weight must not exceed certified MTOW structural limit. */
        subject a : Aircraft;
        assert constraint : a.maxTakeoffWeight_kg <= 352400.0;
    }

    constraint def C_FuselagePressure {
        doc /* Fuselage differential pressure shall not exceed structural limit. */
        subject f : FuselageAssembly;
        assert constraint : f.pressureDiff_psi <= 9.4;
    }

    constraint def C_WingFoldLockPins {
        doc /* Wing tip fold lock pin count must meet fail-safe minimum. */
        subject wt : FoldingWingTipAssembly;
        assert constraint : wt.lockPinCount >= 4;
    }

    constraint def C_RangeRequirement {
        doc /* Design range meets minimum 7,295 nmi threshold. */
        subject a : Aircraft;
        assert constraint : a.designRange_nmi >= 7295.0;
    }

    constraint def C_CompositeStructure {
        doc /* Composite fraction must meet or exceed the 52% design target. */
        subject a : Aircraft;
        assert constraint : a.compositeStructurePct >= 52.0;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // FULL SysML RELATION DEMONSTRATION
    // All seven SysML relation categories demonstrated for model completeness.
    // ═════════════════════════════════════════════════════════════════════════

    // ── VERIFICATION: Requirements verified by analysis / test ────────────────
    verify REQ_PERF_001_Range by provideThrust_f;
    verify REQ_PERF_002_CruiseSpeed by provideThrust_f;
    verify REQ_SAFE_001_Catastrophic by aircraft_i;
    verify REQ_SAFE_003_FADEC_DAL by fadec_i;
    verify REQ_SAFE_004_FCS_DAL by pfc_i;
    verify REQ_AVION_001_CMC_Integrity by avionics_i;
    verify REQ_STRUCT_003_Pressurization by fuselage_i;
    verify REQ_ENVIRON_002_NoiseCertification by propulsion_i;

    // ── DERIVATION: Lower-level requirements derived from higher-level ones ───
    derive REQ_PERF_002_CruiseSpeed from REQ_PERF_001_Range;
    derive REQ_PERF_003_TakeoffFieldLength from REQ_PERF_001_Range;
    derive REQ_SAFE_003_FADEC_DAL from REQ_SAFE_001_Catastrophic;
    derive REQ_SAFE_004_FCS_DAL from REQ_SAFE_001_Catastrophic;
    derive REQ_AVION_001_CMC_Integrity from REQ_SAFE_001_Catastrophic;

    // ── REFINEMENT: Requirements refined to more specific detail ─────────────
    refine REQ_PERF_007_OEI_ClimbGrad from REQ_PERF_001_Range;
    refine REQ_STRUCT_004_FailSafe from REQ_SAFE_002_Hazardous;
    refine REQ_SAFE_006_HydRedundancy from REQ_SAFE_002_Hazardous;

    // ── TRACEABILITY: Requirements traced to system-level architecture ────────
    trace REQ_PERF_001_Range to aircraft_i;
    trace REQ_SAFE_001_Catastrophic to aircraft_i;
    trace REQ_AVION_001_CMC_Integrity to avionics_i;
    trace REQ_STRUCT_001_LimitLoad to airframe_i;

    // ── DEPENDENCIES: Subsystem operational dependencies ─────────────────────
    depend AvionicsSuite on ElectricalPowerSystem;
    depend FlightControlSystem on AvionicsSuite;
    depend FlightControlSystem on HydraulicSystem;
    depend PropulsionSystem on FuelSystem;
    depend EnvironmentalControlSystem on ElectricalPowerSystem;
    depend LandingGearSystem on HydraulicSystem;
    depend CommunicationsSystem on ElectricalPowerSystem;
    depend HealthMonitoringSystem on AvionicsSuite;

    // ── REALIZATION: Subsystems realize architectural requirements ────────────
    realize FlightControlSystem to REQ_SAFE_004_FCS_DAL;
    realize FADECUnit to REQ_SAFE_003_FADEC_DAL;
    realize AvionicsSuite to REQ_AVION_001_CMC_Integrity;
    realize ElectricalPowerSystem to REQ_SAFE_007_EmergencyPower;
    realize HydraulicSystem to REQ_SAFE_006_HydRedundancy;

    // ── BEHAVIORAL CONTROL: Functions that control subsystems ─────────────────
    control PropulsionSystem by RegulateThrust;
    control FlightControlSystem by ControlAttitudeFlightPath;
    control FlightControlSystem by ComputeControlLaws;
    control LandingGearSystem by DeployAndRetractGear;
    control EnvironmentalControlSystem by ManageEnvControl;
    control ThrustReverserAssembly by ControlThrustReverser;

    // ── BEHAVIORAL MONITORING: Functions that monitor subsystems ─────────────
    monitor PropulsionSystem by MonitorEngineHealth;
    monitor ElectricalPowerSystem by MonitorSystemHealth;
    monitor HydraulicSystem by MonitorSystemHealth;
    monitor FlightControlSystem by MonitorSystemHealth;
    monitor FuelSystem by ManageFuelSupplyFunction;

    // ── ASSOCIATIONS: Peer-level relationships between subsystems ────────────
    associate AvionicsSuite with FlightControlSystem;
    associate AvionicsSuite with CommunicationsSystem;
    associate HealthMonitoringSystem with AvionicsSuite;
    associate PropulsionSystem with FuelSystem;
    associate ElectricalPowerSystem with HydraulicSystem;
    associate LandingGearSystem with FlightControlSystem;

}
