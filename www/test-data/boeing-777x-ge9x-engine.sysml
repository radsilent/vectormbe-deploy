// Boeing 777X — GE9X-105B1A Engine Detailed System Architecture (SysML v2)
// Reference: GE Aviation public data, FAA Type Certificate E00078NE (GE9X)
// Engine: GE9X-105B1A — 3-spool turbofan, 105,000 lbf (467 kN) takeoff thrust
// Certification basis: FAR 33 / EASA CS-E, ETOPS 330, DO-178C, DO-254
//
// GE9X design highlights:
//   Fan diameter:         134 in (3.40 m) — 16 CFRP blades (world-first on GE commercial)
//   Bypass ratio:         10:1
//   Overall pressure ratio: 60:1
//   Turbine inlet temp:   ~1880 K (CMC rotating parts enable higher TIT)
//   SFC improvement:      ~10% vs GE90-115B (at cruise)
//   CMC components:       HPT nozzles, HPT shroud, combustor liner
//   NOx margin vs CAEP/8: 25%
//   SAF certification:    100% SAF capable
//
// This model covers:
//   - Full 3-spool gas path (fan + LPC + IPC + HPC + combustor + HPT + IPT + LPT)
//   - FADEC dual-channel (DO-178C Level A)
//   - Oil, fuel, and accessory systems
//   - Nacelle and thrust reverser
//   - Engine-level requirements and verification constraints
//   - Allocation of DO-178C/DO-254 DAL levels

package GE9X_105B1A {

    private import ScalarValues::*;

    // ═════════════════════════════════════════════════════════════════════════
    // TOP-LEVEL ENGINE
    // ═════════════════════════════════════════════════════════════════════════

    part def Engine_GE9X_105B1A {
        doc /* GE9X-105B1A turbofan — 3-spool, high-bypass, CMC hot section.
               World's most powerful engine at 777X entry into service (2024).
               First commercial engine with CMC rotating fan blades and HPT shroud. */

        attribute designation          : String  = "GE9X_105B1A";
        attribute certificationBasis   : String  = "FAR33_EASA_CSE_ETOPS330";
        attribute takeOffThrust_N      : Real    = 467052.0;   // 105,000 lbf
        attribute maxContinuousThrust_N: Real    = 420000.0;
        attribute bypassRatio          : Real    = 10.0;
        attribute overallPressureRatio : Real    = 60.0;
        attribute fanDiameter_m        : Real    = 3.40;       // 134 in
        attribute dryMass_kg           : Real    = 8955.0;
        attribute length_m             : Real    = 6.6;
        attribute sfcCruise_lbPerLbfHr : Real    = 0.478;
        attribute turbineInletTemp_K   : Real    = 1880.0;
        attribute noxMarginVsCAEP8_pct : Real    = 25.0;
        attribute etopsRating_min      : Real    = 330.0;
        attribute safCapable           : Boolean = true;
        attribute cmcHotSection        : Boolean = true;

        // ── Major sub-system instances ────────────────────────────────────
        part fanModule      : FanModule;
        part lpcModule      : LPCompressorModule;
        part ipcModule      : IPCompressorModule;
        part hpcModule      : HPCompressorModule;
        part combustor      : TAPSII_CombustorModule;
        part hptModule      : HPTurbineModule;
        part iptModule      : IPTurbineModule;
        part lptModule      : LPTurbineModule;
        part exhaustSys     : ExhaustNozzleSystem;
        part fadec          : FADECSystem;
        part fuelSys        : EngineFuelSystem;
        part oilSys         : EngineOilSystem;
        part acg            : AccessoryGearboxSystem;
        part ignition       : IgnitionSystem;
        part nacelle        : NacelleSystem;
        part reverser       : ThrustReverserSystem;
        part starting       : EngineStartingSystem;
        part healthMon      : EngineHealthMonitor;

        // ── Engine-level ports ────────────────────────────────────────────
        port airInlet          : AirInletPort;
        port fuelSupply        : EngineFuelPort;
        port thrustNozzle      : ThrustOutputPort;
        port bleedAirOut       : BleedAirPort;
        port electricalOut     : GeneratorPort;
        port fadecDataBus      : ARINC429DataPort;
        port vibrationSensors  : VibrSensorPort;
        port oilFill           : OilServicePort;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // GAS PATH — FAN MODULE
    // ═════════════════════════════════════════════════════════════════════════

    part def FanModule {
        doc /* 16-blade CFRP composite fan — first on any GE commercial engine.
               3.40m diameter; fan pressure ratio 1.72; bypass ratio 10:1.
               CFRP fan blades replace titanium blades used on GE90/GEnx. */

        attribute fanDiameter_m            : Real    = 3.40;
        attribute fanBladeCount            : Integer = 16;
        attribute bladeMaterial            : String  = "CFRP_Composite_GE_SecondGen";
        attribute bypassRatio              : Real    = 10.0;
        attribute fanPressureRatio         : Real    = 1.72;
        attribute massFlowTotal_kgPerSec   : Real    = 1390.0;
        attribute tipSpeed_mPerSec         : Real    = 480.0;
        attribute bladeDesign              : String  = "LargeChord_WideBlade_Sweep";
        attribute birdStrikeCert           : String  = "FAR33.76_8lb_RegulatoryCompliant";

        part fanBlades        : FanBlade[16];
        part fanFrameFwd      : FanFrameForward;
        part fanFrameAft      : FanFrameAft;
        part lfnCaseSeal      : LowPressureCompressorCase;
        part bypassDuct       : BypassDuctAssembly;

        port airIn            : AirInletPort;
        port bypassAirOut     : BypassAirPort;
        port coreAirOut       : CoreAirPort;
        port fanShaft         : LPShaftPort;
    }

    part def FanBlade {
        doc /* CFRP woven composite fan blade — impact-tolerant, lighter than Ti-6Al-4V.
               Each blade ~180kg lighter per engine vs. titanium equivalent. */
        attribute material                 : String  = "CFRP_Woven_TorayT800_3DWeave";
        attribute chord_m                  : Real    = 0.82;
        attribute span_m                   : Real    = 1.40;
        attribute mass_kg                  : Real    = 12.5;
        attribute airfoilProfile           : String  = "3D_Aero_Swept_LargeChord";
        attribute coatingType              : String  = "PTFE_ErosionCoat";
    }

    part def BypassDuctAssembly {
        attribute ductArea_m2              : Real    = 7.2;
        attribute material                 : String  = "CFRP_TitaniumFrames";
        attribute acousticLiner            : Boolean = true;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // GAS PATH — COMPRESSOR STAGES
    // ═════════════════════════════════════════════════════════════════════════

    part def LPCompressorModule {
        doc /* 3-stage LPC — directly driven by LPT shaft at LP spool speed.
               Ti-6Al-4V blisks; variable inlet guide vanes (VIGV). */
        attribute stages                   : Integer = 3;
        attribute pressureRatio            : Real    = 2.8;
        attribute rotorMaterial            : String  = "Ti_6Al_4V_Blisk";
        attribute variableVanes            : Boolean = true;   // VIGV
        attribute inletFlowArea_m2         : Real    = 0.95;

        part lpcRotor     : CompressorRotorStage[3];
        part lpcStator    : CompressorStatorStage[3];
        part vigv         : VariableInletGuideVane;

        port airIn        : CoreAirPort;
        port airOut       : CoreAirPort;
        port shaftIn      : LPShaftPort;
        port bleedPort    : BleedAirPort;   // P2.5 bleed for ECS
    }

    part def IPCompressorModule {
        doc /* 7-stage IPC — 3-spool architecture unique to GE9X (GE90 was 2-spool).
               IP spool provides intermediate pressure stage; BLISK construction stages 1-4. */
        attribute stages                   : Integer = 7;
        attribute pressureRatio            : Real    = 8.5;
        attribute rotorMaterial_front      : String  = "Ti_6Al_4V_Blisk_Stages1_4";
        attribute rotorMaterial_aft        : String  = "Rene88DT_PM_Stages5_7";
        attribute variableVanes            : Boolean = true;

        part ipcRotor     : CompressorRotorStage[7];
        part ipcStator    : CompressorStatorStage[7];
        part vgvStages    : VariableGeometryVane[4];

        port airIn        : CoreAirPort;
        port airOut       : CoreAirPort;
        port shaftIn      : IPShaftPort;
        port bleedPort    : BleedAirPort;   // P3 bleed for wing anti-ice
    }

    part def HPCompressorModule {
        doc /* 11-stage HPC — highest OPR in service; last 3 stages Rene88DT PM disc/blade.
               Rear stages ceramic thermal barrier coating; single-piece welded HPC rotor. */
        attribute stages                   : Integer = 11;
        attribute pressureRatio            : Real    = 2.5;   // HPC contribution to OPR 60:1
        attribute rotorMaterial_front      : String  = "Ti_6Al_4V_Blisk_Stages1_4";
        attribute rotorMaterial_mid        : String  = "Rene88DT_PM_Stages5_9";
        attribute rotorMaterial_aft        : String  = "IN718_Rene88DT_Stages10_11";
        attribute statorMaterial_aft       : String  = "Rene41_TBCoated";
        attribute compressionRatioExit     : Real    = 55.0;  // P3/P0 at takeoff
        attribute exitTotalTemp_K          : Real    = 950.0; // T3 at takeoff

        part hpcRotorStages : CompressorRotorStage[11];
        part hpcStators     : CompressorStatorStage[11];
        part hpcCaseSeal    : HPCCasingHoningSystem;

        port airIn          : CoreAirPort;
        port airOut         : CoreAirPort;
        port shaftIn        : HPShaftPort;
        port bleedPort_P3   : BleedAirPort;
        port coolingBleed   : HPTCoolingPort;   // HPT blade cooling air
    }

    // ═════════════════════════════════════════════════════════════════════════
    // GAS PATH — COMBUSTION
    // ═════════════════════════════════════════════════════════════════════════

    part def TAPSII_CombustorModule {
        doc /* Twin Annular Pre-Swirl II (TAPS II) combustor — ICAO CAEP/8 NOx compliance.
               25% margin below CAEP/8 limit across LTO cycle.
               CMC combustor liner — enables higher TIT and reduced cooling air.
               SAF-ready: certified for 100% SAF blend without hardware change. */

        attribute combustorType            : String  = "TAPS_II_TwinAnnularPreSwirl";
        attribute maxTIT_K                 : Real    = 1880.0;
        attribute designatedOAR            : Real    = 0.32;   // Overall Air Ratio at LTO
        attribute noxEINOx_gPerKg          : Real    = 38.0;   // at takeoff — 25% below CAEP/8
        attribute noxMarginVsCAEP8_pct     : Real    = 25.0;
        attribute safCertified_pct         : Integer = 100;
        attribute fuelSpec                 : String  = "JetA_JetA1_100pctSAF_ASTMD7566";
        attribute linearCoolingMethod      : String  = "Effusion_CMC_Liner";
        attribute cmcLiner                 : Boolean = true;

        part innerLinear      : CMC_CombustorLiner;
        part outerLiner       : CMC_CombustorLiner;
        part fuelNozzles      : TAPS_FuelNozzle[24];
        part igniters         : CombustorIgniter[2];
        part diffuser         : CombustorDiffuser;

        port fuelIn           : EngineFuelPort;
        port airIn_pilot      : CoreAirPort;
        port airIn_main       : CoreAirPort;
        port exhaustOut       : HotGasPort;
    }

    part def CMC_CombustorLiner {
        doc /* Ceramic Matrix Composite liner — SiC/SiC; 300°C cooler than metal liner;
               significantly reduces cooling air extraction; first production CMC liner on 777X/GE9X. */
        attribute material                 : String  = "CMC_SiCSiC_Oxide_Slurry";
        attribute operatingTemp_K          : Real    = 1600.0;
        attribute densityRatio             : Real    = 0.33;   // vs. metallic liner
        attribute coolingAirReduction_pct  : Real    = 40.0;
        attribute thermalBarrierCoat       : Boolean = false;  // CMC eliminates TBC need
    }

    part def TAPS_FuelNozzle {
        doc /* TAPS II dual-annular pre-swirl fuel injector — pilot + main stage. */
        attribute pilotFlowFraction_pct    : Real    = 20.0;   // idle/approach
        attribute mainFlowFraction_pct     : Real    = 80.0;   // takeoff/climb
        attribute stagingSwitchMachNo      : Real    = 0.35;
        attribute materialClass            : String  = "Hastelloy_X_PtRh_Coated";
    }

    // ═════════════════════════════════════════════════════════════════════════
    // GAS PATH — TURBINE STAGES
    // ═════════════════════════════════════════════════════════════════════════

    part def HPTurbineModule {
        doc /* 2-stage HPT — world's first production CMC rotating blades and CMC shroud.
               CMC components enable 100°C higher TIT than metallic blades with less cooling.
               First GE engine with CMC HPT nozzles (stage 1 and stage 2). */

        attribute stages                   : Integer = 2;
        attribute stage1_bladeMaterial     : String  = "CMC_SiCSiC_Melt_Infiltrated";
        attribute stage2_bladeMaterial     : String  = "CMC_SiCSiC_SingleCrystal_Hybrid";
        attribute shroudMaterial           : String  = "CMC_SiCSiC_Abradable_Shroud";
        attribute nozzleMaterial_S1        : String  = "CMC_SiCSiC_Nozzle_BOAS";
        attribute turbineInletTemp_K       : Real    = 1880.0;
        attribute presRatioHPT             : Real    = 5.2;
        attribute coolingAirFraction_pct   : Real    = 12.0;   // reduced vs. metallic
        attribute discreetCoolingChannels  : Boolean = true;

        part hptStage1Blade  : CMC_TurbineBlade[54];
        part hptStage2Blade  : CMC_TurbineBlade[66];
        part hptStage1Nozzle : CMC_TurbineNozzle;
        part hptStage2Nozzle : CMC_TurbineNozzle;
        part hptShroud       : CMC_TurbineShroud;
        part hptDisk_S1      : HPTDisk;
        part hptDisk_S2      : HPTDisk;

        port hotGasIn        : HotGasPort;
        port hotGasOut       : HotGasPort;
        port shaftOut        : HPShaftPort;
        port coolingAirIn    : HPTCoolingPort;
    }

    part def CMC_TurbineBlade {
        doc /* CMC SiC/SiC turbine blade — melt-infiltrated process. Weight savings ~30% vs Ni SC.
               Enables 100°C higher TIT without additional cooling flow. DO-178C/DO-254 N/A (hardware). */
        attribute material                 : String  = "CMC_SiCSiC_MI_Oxide";
        attribute densityRatio             : Real    = 0.29;   // vs Ni superalloy
        attribute maxOperatingTemp_K       : Real    = 1700.0;
        attribute thermalBarrierCoating    : String  = "YSZ_EB_PVD_Thin";
        attribute coolingScheme            : String  = "Transpiration_Laser_Drilled";
    }

    part def CMC_TurbineNozzle {
        attribute material                 : String  = "CMC_SiCSiC_Oxide_MI";
        attribute maxTemp_K                : Real    = 1680.0;
        attribute cooling                  : String  = "TargetedFilm_MinimalAir";
    }

    part def CMC_TurbineShroud {
        attribute material                 : String  = "CMC_SiCSiC_Abradable_TopCoat";
        attribute tipClearance_mm          : Real    = 0.5;
        attribute abradableCoating         : Boolean = true;
    }

    part def HPTDisk {
        attribute material                 : String  = "Rene104_PM_PM1_disc";
        attribute maxRim_rpm               : Real    = 11500.0;
        attribute certBurst                : String  = "FAR33.27_1.21x_maxSpeed";
        attribute coolingBores             : Boolean = true;
    }

    part def IPTurbineModule {
        doc /* 2-stage IPT — drives IP compressor; nickel superalloy blades; lower TIT than HPT. */
        attribute stages                   : Integer = 2;
        attribute bladeMaterial            : String  = "CMSX4_SingleCrystal_TBC";
        attribute diskMaterial             : String  = "Rene88DT_PM";
        attribute exitTotalTemp_K          : Real    = 1200.0;
        attribute presRatioIPT             : Real    = 3.5;

        part iptBlade_S1   : NiSuperalloyBlade[80];
        part iptBlade_S2   : NiSuperalloyBlade[90];
        part iptDisk_S1    : IPTDisk;
        part iptDisk_S2    : IPTDisk;

        port hotGasIn      : HotGasPort;
        port hotGasOut     : HotGasPort;
        port shaftOut      : IPShaftPort;
    }

    part def LPTurbineModule {
        doc /* 7-stage LPT — drives fan and LPC; low pressure ratio; long blades; highest efficiency. */
        attribute stages                   : Integer = 7;
        attribute bladeMaterial            : String  = "IN792_DS_TBC_Stages1_4";
        attribute bladeMaterial_aft        : String  = "Ti_6242_LightweightStages5_7";
        attribute diskMaterial             : String  = "Ti_6Al_4V_IN718_Mixed";
        attribute exitTotalTemp_K          : Real    = 900.0;
        attribute presRatioLPT             : Real    = 8.0;
        attribute efficiencyPeak_pct       : Real    = 93.5;
        attribute bladeAspectRatio         : Real    = 5.8;   // long slender blades

        part lptBlade      : LPTBlade[7];   // per stage set
        part lptDisk       : LPTDisk[7];

        port hotGasIn      : HotGasPort;
        port exhaustOut    : ExhaustPort;
        port shaftOut      : LPShaftPort;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // FADEC — ENGINE CONTROL
    // ═════════════════════════════════════════════════════════════════════════

    part def FADECSystem {
        doc /* Dual-channel FADEC for GE9X — controls all engine functions, thrust rating,
               start sequencing, fault detection. DO-178C Level A. DO-254 Level A.
               Update rate 80 Hz; 6 thrust rating modes. */

        attribute channels                 : Integer = 2;
        attribute softwareLevel            : String  = "DO178C_LevelA";
        attribute hardwareLevel            : String  = "DO254_LevelA";
        attribute updateRateHz             : Real    = 80.0;
        attribute failureRatePerFH         : Real    = 1.0e-9;
        attribute thrustRatingModes        : Integer = 6;  // TOGA, MCT, CON, CLB, CRZ, GA
        attribute egtLimitationActive      : Boolean = true;
        attribute n1LimitationActive       : Boolean = true;
        attribute overspeedProtection      : Boolean = true;
        attribute nL_maxRPM                : Real    = 2630.0;
        attribute nH_maxRPM                : Real    = 11500.0;

        part fadecA       : FADECChannel;   // Channel A — primary
        part fadecB       : FADECChannel;   // Channel B — standby
        part eecPower     : FADECPowerSupply;
        part lvdtPack     : LVDTSensorPack;
        part throttleResv : ThrottleResolverAssembly;

        port aircraftPower    : ElectricalBusInput;
        port arinc429Out      : ARINC429DataPort;
        port thrustLeverAngle : ThrustLeverPort;
        port paramSensors     : EngineSensorBus;
        port fuelMeteringOut  : FuelMeteringValvePort;
        port vsvActuation     : VGVActuationPort;
        port vibSensors       : VibrSensorPort;
    }

    part def FADECChannel {
        doc /* Single FADEC channel — RISC processor triplex vote for safety-critical outputs. */
        attribute processor                : String  = "RISC_PowerPC_DO254_LevelA";
        attribute memory_KB                : Integer = 2048;
        attribute nvramBackup              : Boolean = true;
        attribute channelCrossCheck        : Boolean = true;
        attribute analogInputs             : Integer = 64;
        attribute discreteInputs           : Integer = 128;
        attribute discreteOutputs          : Integer = 96;
        attribute pwmOutputs               : Integer = 32;
    }

    part def FADECPowerSupply {
        doc /* FADEC permanent-magnet alternator — independent of aircraft bus for dual-generator failure. */
        attribute type                     : String  = "PM_AlternatorSelfContained";
        attribute minSpeed_rpm             : Real    = 2000.0;  // self-sustaining above this
        attribute outputVoltage_Vdc        : Real    = 28.0;
        attribute backupBattery            : Boolean = true;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ENGINE FUEL SYSTEM
    // ═════════════════════════════════════════════════════════════════════════

    part def EngineFuelSystem {
        doc /* Engine-mounted fuel system: high-pressure pump, flow divider,
               fuel-oil heat exchanger, filter, metering valve, and manifold. */

        attribute fuelSpec                 : String  = "JetA_JetA1_100pctSAF";
        attribute pumpType                 : String  = "Centrifugal_GearPump_HP";
        attribute maxFuelFlow_kgPerSec     : Real    = 12.5;   // at TOGA
        attribute filterMicron             : Real    = 25.0;

        part hpFuelPump      : HPFuelPump;
        part fuelFilter      : FuelFilter;
        part fuelMeterValve  : FuelMeteringValve;
        part fuelManifold    : FuelManifoldAssembly;
        part foheXchanger    : FuelOilHeatExchanger;
        part flowDivider     : FuelFlowDivider;

        port fuelIn          : EngineFuelPort;
        port fuelToNozzles   : EngineFuelPort;
        port oilHeatLink     : OilCoolingPort;
    }

    part def HPFuelPump {
        attribute type                     : String  = "GearPump_DualElement";
        attribute maxPressure_kPa          : Real    = 8300.0; // ~1200 psi outlet
        attribute flowAtTOGA_kgPerSec      : Real    = 12.5;
        attribute driveSource              : String  = "AccessoryGearbox_GE9X";
    }

    part def FuelMeteringValve {
        doc /* FADEC-controlled metering valve — primary N1/EGT modulation. */
        attribute type                     : String  = "TorqueMotor_SteepServoValve";
        attribute positionFeedback         : String  = "DualLVDT";
        attribute responseTime_ms          : Real    = 50.0;
        attribute failPosition             : String  = "Shut";
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ENGINE OIL SYSTEM
    // ═════════════════════════════════════════════════════════════════════════

    part def EngineOilSystem {
        doc /* Full-flow pressure oil system — bearings, ACG, IDG lubrication.
               Chip detectors on main gearbox + bearing sumps; ACARS oil consumption monitoring. */

        attribute oilSpec                  : String  = "MIL_PRF_23699_Grade5";
        attribute tankCapacity_L           : Real    = 22.5;
        attribute oilPressure_kPa          : Real    = 380.0;  // bearing feed pressure
        attribute oilTemp_maxCont_degC     : Real    = 175.0;
        attribute acarsOilMonitor          : Boolean = true;

        part oilTank         : OilTank;
        part oilPump         : OilPump;
        part oilFilter       : OilFilter;
        part scavengeSystem  : ScavengeOilPump;
        part chipDetectors   : ChipDetector[4];
        part oilCooler       : OilCooler;

        port oilReturn       : OilCoolingPort;
        port chipWarning     : DiscreteSignalPort;
    }

    part def OilTank {
        attribute usableCapacity_L         : Real    = 22.5;
        attribute lowLevelAlert_L          : Real    = 8.0;
        attribute material                 : String  = "AluminiumAlloy_MIL_A_8625";
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ACCESSORY GEARBOX
    // ═════════════════════════════════════════════════════════════════════════

    part def AccessoryGearboxSystem {
        doc /* ACG driven by HP spool via towershaft.
               Drives: IDG (120 kVA VFG), hydraulic pump, fuel pump, oil pump, starter motor. */

        attribute driveSource              : String  = "HP_Spool_TowerShaft";
        attribute driveRatio               : Real    = 1.0;   // via compound geartrain
        attribute ratedPower_kW            : Real    = 180.0;

        part idg             : IntegratedDriveGenerator;
        part hydraulicPump   : EngineHydPump;
        part starterGen      : AirTurbineStarter;
        part oilPump_acg     : ACGOilPump;
        part fuelPump_acg    : LPFuelPump;

        port hpShaftIn       : HPShaftPort;
        port electricalOut   : GeneratorPort;
        port hydraulicOut    : HydraulicPort;
    }

    part def IntegratedDriveGenerator {
        doc /* Variable-frequency generator — 120 kVA, 115V AC, 360-800 Hz.
               777X uses VFG directly (no constant-speed drive — simpler than older IDG). */
        attribute type                     : String  = "VFG_VariableFrequencyGenerator";
        attribute ratedPower_kVA           : Real    = 120.0;
        attribute outputVoltage_V          : Real    = 115.0;
        attribute frequencyRange_Hz        : String  = "360_to_800";
        attribute coolantType              : String  = "OilCooled";
        attribute efficiency_pct           : Real    = 96.5;
    }

    part def EngineHydPump {
        attribute flowRate_LPerMin         : Real    = 95.0;
        attribute operatingPressure_psi    : Real    = 3000.0;
        attribute driveType                : String  = "ConstantDisplacementPiston";
    }

    // ═════════════════════════════════════════════════════════════════════════
    // NACELLE AND THRUST REVERSER
    // ═════════════════════════════════════════════════════════════════════════

    part def NacelleSystem {
        doc /* CFRP composite nacelle optimised for 777X 3.40m fan diameter.
               Acoustic liners (inlet + aft) for Chapter 14 compliance.
               Cowl doors allow single-technician access to ACG/IDG. */

        attribute material                 : String  = "CFRP_CarbonFibre";
        attribute inletDiameter_m          : Real    = 3.56;   // D+fan-nacelle clearance
        attribute nacelleLength_m          : Real    = 5.8;
        attribute fanCowlHinged            : Boolean = true;

        part inletCowl      : InletCowlAssembly;
        part fanCowl        : FanCowlDoors;
        part thrustReverser : ThrustReverserSystem;
        part aftNacelle     : AftNacelleAssembly;
        part coreCowl       : CoreCowlDoors;
        part fireDetect     : NacelleFireDetection;
        part fireSuppress   : NacelleFireSuppression;
    }

    part def InletCowlAssembly {
        doc /* Acoustic inlet cowl — honeycomb liner + foam acoustics layer.
               Anti-icing: hot bleed air piccolo tube. */
        attribute acousticLiner            : String  = "HoneycombFoamInlet_Transliner";
        attribute antiIcingType            : String  = "BleedAirPiccoloTube";
        attribute liEPNdB_reduction        : Real    = 4.5;   // vs unlined inlet
        attribute material                 : String  = "CFRP_CompositeInlet";
    }

    part def ThrustReverserSystem {
        doc /* Cascade-type thrust reverser with blocker doors.
               OEI inhibited. Ground only. Deploy < 1 sec after WOW + throttle retard.
               Max reverse = 50% takeoff thrust. */

        attribute reverserType             : String  = "CascadeBlockerDoor_777X";
        attribute maxReverseThrust_pct     : Real    = 50.0;
        attribute deployTime_sec           : Real    = 1.0;
        attribute stowTime_sec             : Real    = 4.0;
        attribute groundOnlyEnable         : Boolean = true;
        attribute oeiInhibited             : Boolean = true;
        attribute actuatorType             : String  = "HydraulicPneumaticCombined";

        part cascadeVanes    : CascadeVaneArray;
        part blockerDoors    : BlockerDoor[4];
        part translSleeve    : TranslationSleeveAssembly;
        part actuators       : HydraulicActuator[8];
        part lockMechanism   : ReverserLockPins;

        port hydraulicIn     : HydraulicPort;
        port commandSignal   : DiscreteSignalPort;
        port positionFeedback: DiscreteSignalPort;
    }

    part def NacelleFireDetection {
        attribute sensorType               : String  = "ContinuousLoopOverheat_FAR25";
        attribute zones                    : String  = "ACG_Zone_CoreZone_FanZone";
        attribute suppressionAutoTrigger   : Boolean = true;
    }

    part def NacelleFireSuppression {
        attribute agent                    : String  = "HFC_236fa_HalonReplacement";
        attribute twoShotCapable           : Boolean = true;   // 1 primary + 1 reserve
        attribute bottleCount              : Integer = 2;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ENGINE HEALTH MONITORING
    // ═════════════════════════════════════════════════════════════════════════

    part def EngineHealthMonitor {
        doc /* ACMS-integrated real-time engine health monitoring.
               10 vibration sensors; EGT spread monitoring; oil chip + pressure telemetry.
               Trend data transmitted via ACARS for Boeing AHM predictive maintenance. */

        attribute paramCount               : Integer = 200;
        attribute vibSensorsPerEngine      : Integer = 10;
        attribute egtSpreadMonitor         : Boolean = true;
        attribute oilChipDetection         : Boolean = true;
        attribute acarsReporting           : Boolean = true;
        attribute aiPrognostics            : Boolean = true;

        part vibMonitor      : VibrationMonitorUnit;
        part egtSystem       : EGT_MonitorSystem;
        part oilMonitor      : OilDegradationMonitor;
        part fadecHmu        : FADECHealthMgmtModule;

        port toACMS          : ARINC429DataPort;
    }

    part def VibrationMonitorUnit {
        attribute accelSensors             : Integer = 10;   // fan/LP + HP shaft planes
        attribute alarmThreshold_g         : Real    = 2.5;
        attribute adaptiveFilter           : Boolean = true;
        attribute broadbandSpectrum        : Boolean = true;
    }

    part def EGT_MonitorSystem {
        doc /* EGT measured by 12 Chromel/Alumel thermocouples at LPT exit.
               Average + spread limit monitoring. */
        attribute thermocoupleCount        : Integer = 12;
        attribute redlineTOGA_degC         : Real    = 1030.0;
        attribute redlineMCT_degC          : Real    = 1010.0;
        attribute spreadLimit_degC         : Real    = 80.0;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PORT DEFINITIONS
    // ═════════════════════════════════════════════════════════════════════════

    port def AirInletPort {
        attribute massFlow_kgPerSec        : Real;
        attribute totalPressure_kPa        : Real;
        attribute totalTemp_K              : Real;
        attribute mach                     : Real;
    }

    port def CoreAirPort {
        attribute massFlow_kgPerSec        : Real;
        attribute totalPressure_kPa        : Real;
        attribute totalTemp_K              : Real;
    }

    port def BypassAirPort {
        attribute massFlow_kgPerSec        : Real;
        attribute pressure_kPa             : Real;
    }

    port def HotGasPort {
        attribute massFlow_kgPerSec        : Real;
        attribute totalTemp_K              : Real;
        attribute totalPressure_kPa        : Real;
    }

    port def ExhaustPort {
        attribute massFlow_kgPerSec        : Real;
        attribute exitTemp_K               : Real;
        attribute exitPressure_kPa         : Real;
        attribute velocity_mPerSec         : Real;
    }

    port def ThrustOutputPort {
        attribute netThrust_N              : Real;
        attribute specificThrust_N_kgPerSec: Real;
    }

    port def BleedAirPort {
        attribute pressure_kPa             : Real;
        attribute temp_K                   : Real;
        attribute massFlow_kgPerSec        : Real;
        attribute bleedStage               : String;   // "P2.5_LPC" | "P3_HPC"
    }

    port def EngineFuelPort {
        attribute massFlow_kgPerSec        : Real;
        attribute pressure_kPa             : Real;
        attribute fuelTemp_degC            : Real;
    }

    port def GeneratorPort {
        attribute voltage_V                : Real;
        attribute frequency_Hz             : Real;
        attribute power_kVA                : Real;
    }

    port def ARINC429DataPort {
        attribute dataRate_bps             : Integer = 100000;
        attribute wordCount                : Integer;
    }

    port def HydraulicPort {
        attribute pressure_psi             : Real;
        attribute flow_LPerMin             : Real;
    }

    port def OilCoolingPort {
        attribute heatLoad_kW              : Real;
        attribute oilTemp_in_degC          : Real;
        attribute oilTemp_out_degC         : Real;
    }

    port def DiscreteSignalPort {
        attribute signalCount              : Integer;
        attribute voltage_V                : Real = 28.0;
    }

    port def EngineSensorBus {
        attribute sensorCount              : Integer;
        attribute protocol                 : String = "ARINC429";
    }

    port def FuelMeteringValvePort {
        attribute valvePosition_pct        : Real;
        attribute commandSource            : String;
    }

    port def VGVActuationPort {
        attribute statorAngle_deg          : Real;
        attribute actuatorCount            : Integer;
    }

    port def VibSensorPort {
        attribute sensorCount              : Integer;
        attribute bandwidth_Hz             : Real;
    }

    port def LPShaftPort { attribute rpm : Real; }
    port def IPShaftPort { attribute rpm : Real; }
    port def HPShaftPort { attribute rpm : Real; }
    port def HPTCoolingPort { attribute coolingFlow_pct : Real; }
    port def ThrustLeverPort { attribute tlaAngle_deg : Real; }
    port def ElectricalBusInput { attribute voltage_V : Real; }
    port def OilServicePort { attribute oilLevel_L : Real; }

    // ═════════════════════════════════════════════════════════════════════════
    // REQUIREMENTS
    // ═════════════════════════════════════════════════════════════════════════

    requirement def ENG_REQ_001_TakeoffThrust {
        doc /* ENG-001: Engine SHALL produce minimum 105,000 lbf (467 kN) net thrust at
               TOGA rating, SL ISA+15, at start of takeoff roll. [FAR 33 / CS-E] */
        subject eng : Engine_GE9X_105B1A;
        attribute minThrust_N              : Real = 467052.0;
    }

    requirement def ENG_REQ_002_SFC {
        doc /* ENG-002: Engine SFC at cruise SHALL not exceed 0.485 lb/lbf·hr at
               Mach 0.85 / FL390 / ISA on standard day. */
        subject eng : Engine_GE9X_105B1A;
        attribute maxSFC_cruise            : Real = 0.485;
    }

    requirement def ENG_REQ_003_FADEC_DAL {
        doc /* ENG-003: FADEC software SHALL comply with DO-178C Level A.
               Hardware SHALL comply with DO-254 Level A. Dual channel mandatory. */
        subject fadec : FADECSystem;
        attribute softwareDAL              : String = "DO178C_LevelA";
        attribute hardwareDAL              : String = "DO254_LevelA";
        attribute minChannels              : Integer = 2;
    }

    requirement def ENG_REQ_004_FADEC_Integrity {
        doc /* ENG-004: FADEC catastrophic failure rate SHALL be < 1×10⁻⁹ per FH.
               [ARP 4754A / FAR 33.28] */
        subject fadec : FADECSystem;
        attribute maxFailureRate_perFH     : Real = 1.0e-9;
    }

    requirement def ENG_REQ_005_NOx {
        doc /* ENG-005: GE9X LTO NOx SHALL comply with ICAO CAEP/8 standard
               with minimum 25% margin across the full LTO cycle. */
        subject comb : TAPSII_CombustorModule;
        attribute noxStandard              : String = "ICAO_CAEP8";
        attribute minMargin_pct            : Real = 25.0;
    }

    requirement def ENG_REQ_006_SAF {
        doc /* ENG-006: Engine SHALL be certified for operation on 100% Sustainable
               Aviation Fuel (SAF) per ASTM D7566 / D1655 Annex A. */
        subject eng : Engine_GE9X_105B1A;
        attribute maxSAFBlend_pct          : Integer = 100;
    }

    requirement def ENG_REQ_007_ETOPS {
        doc /* ENG-007: Engine IFSD rate SHALL not exceed 0.005 per 1,000 EFH
               to support ETOPS 330 min certification. [FAA ETOPS advisory] */
        subject eng : Engine_GE9X_105B1A;
        attribute maxIFSD_per1000EFH       : Real = 0.005;
        attribute etopsRating_min          : Real = 330.0;
    }

    requirement def ENG_REQ_008_ThrustReverserIntegrity {
        doc /* ENG-008: Thrust reverser SHALL not deploy in flight under any single
               fault. Ground-only enable interlock SHALL be hardware-latched. [FAR 25.933] */
        subject rev : ThrustReverserSystem;
        attribute inFlightDeployForbidden  : Boolean = true;
        attribute hardwareLatch            : Boolean = true;
    }

    requirement def ENG_REQ_009_CMC_Containment {
        doc /* ENG-009: All CMC turbine blade fragments from a worst-case blade failure
               SHALL be contained within the engine nacelle. [FAR 33.94] */
        subject nacelle : NacelleSystem;
        attribute fragmentContainment      : Boolean = true;
    }

    requirement def ENG_REQ_010_FireProtection {
        doc /* ENG-010: Engine fire in ACG zone or core zone SHALL be detected within
               1 second and suppression SHALL extinguish fire within 30 seconds. [CS-25.1195] */
        subject nacelle : NacelleSystem;
        attribute detectionTime_sec        : Real = 1.0;
        attribute suppressionTime_sec      : Real = 30.0;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ALLOCATION
    // ═════════════════════════════════════════════════════════════════════════

    satisfy ENG_REQ_001_TakeoffThrust     by eng_i;
    satisfy ENG_REQ_002_SFC               by eng_i, fan_i, hpc_i, comb_i, hpt_i;
    satisfy ENG_REQ_003_FADEC_DAL         by fadec_i;
    satisfy ENG_REQ_004_FADEC_Integrity   by fadec_i;
    satisfy ENG_REQ_005_NOx               by comb_i;
    satisfy ENG_REQ_006_SAF               by eng_i, comb_i;
    satisfy ENG_REQ_007_ETOPS             by eng_i, fadec_i, oilsys_i;
    satisfy ENG_REQ_008_ThrustReverserIntegrity by rev_i;
    satisfy ENG_REQ_009_CMC_Containment   by nacelle_i;
    satisfy ENG_REQ_010_FireProtection    by nacelle_i;

    part eng_i     : Engine_GE9X_105B1A;
    part fan_i     : FanModule;
    part hpc_i     : HPCompressorModule;
    part comb_i    : TAPSII_CombustorModule;
    part hpt_i     : HPTurbineModule;
    part fadec_i   : FADECSystem;
    part rev_i     : ThrustReverserSystem;
    part nacelle_i : NacelleSystem;
    part oilsys_i  : EngineOilSystem;

    // ═════════════════════════════════════════════════════════════════════════
    // VERIFICATION CONSTRAINTS
    // ═════════════════════════════════════════════════════════════════════════

    constraint def C_Thrust_Min {
        subject e : Engine_GE9X_105B1A;
        assert constraint : e.takeOffThrust_N >= 467052.0;
    }

    constraint def C_SFC_Max {
        subject e : Engine_GE9X_105B1A;
        assert constraint : e.sfcCruise_lbPerLbfHr <= 0.485;
    }

    constraint def C_FADEC_FailRate {
        subject f : FADECSystem;
        assert constraint : f.failureRatePerFH <= 1.0e-9;
    }

    constraint def C_NOx_Margin {
        subject c : TAPSII_CombustorModule;
        assert constraint : c.noxMarginVsCAEP8_pct >= 25.0;
    }

    constraint def C_ETOPS_IFSD {
        subject e : Engine_GE9X_105B1A;
        assert constraint : e.etopsRating_min >= 330.0;
    }

    constraint def C_CMC_LinerEnabled {
        subject c : TAPSII_CombustorModule;
        assert constraint : c.cmcLiner == true;
    }

    constraint def C_ReverserGroundOnly {
        subject r : ThrustReverserSystem;
        assert constraint : r.groundOnlyEnable == true && r.oeiInhibited == true;
    }

}
