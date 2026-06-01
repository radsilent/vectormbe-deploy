// Aircraft High-Bypass Turbofan Propulsion System — SysML v2 Architecture Model
// Reference engine class: CFM LEAP-1B (Boeing 737 MAX) / CFM56-7B
// All performance data from publicly available certification and type certificate documents.
//
// Engine cycle: 2-spool high-bypass turbofan
//   Bypass Ratio (BPR): 9.0 : 1
//   Overall Pressure Ratio (OPR): 40 : 1 (LEAP-1B class)
//   Thrust class: 23,000–28,000 lbf (100–125 kN) take-off thrust

package AircraftPropulsion {

    private import ScalarValues::*;

    // ═════════════════════════════════════════════════════════════════════════
    // ABSTRACT TURBOMACHINERY DEFINITIONS
    // ═════════════════════════════════════════════════════════════════════════

    abstract part def TurboMachineStage {
        doc /* Single aerodynamic stage — rotor + stator row. */
        attribute pressureRatio : Real;
        attribute adiabaticEfficiency : Real;
        attribute inletTemperature : Real;    // K
        attribute inletPressure : Real;       // kPa
    }

    abstract part def Spool {
        doc /* Mechanical shaft connecting compressor and turbine stages on same shaft. */
        attribute shaftSpeed : Real;          // RPM
        attribute shaftPower : Real;          // kW transmitted
        attribute inertia : Real;             // kg·m²
    }

    // ═════════════════════════════════════════════════════════════════════════
    // FAN MODULE
    // ═════════════════════════════════════════════════════════════════════════

    part def FanModule {
        doc /* Single-stage wide-chord swept fan.
               Carbon fiber fan blades (CFRP) with titanium leading edge.
               Fan inlet guide vanes: variable (VIGV) on LEAP class. */

        attribute fanDiameter : Real = 1.76;          // m (69.3 in, LEAP-1B)
        attribute fanBladeCount : Integer = 18;       // CFRP blades
        attribute bladeMaterial : String = "CFRP_TiLE";  // Carbon fiber / Ti leading edge
        attribute bypassRatio : Real = 9.0;
        attribute fanPressureRatio : Real = 1.60;     // FPR at take-off
        attribute fanAdiabaticEfficiency : Real = 0.926;
        attribute tipSpeedMax : Real = 487.0;         // m/s at take-off N1
        attribute massFlowTotal : Real = 650.0;       // kg/s at take-off (ISA sea level)
        attribute massFlowCore : Real = 65.0;         // kg/s core (BPR 9:1)
        attribute massFlowBypass : Real = 585.0;      // kg/s bypass stream

        part rotor : FanRotor;
        part outerDuctGuideVanes : OutletGuideVane[28];
        part fanCaseFOD : FanCaseFOD_Liner;

        port inletAirflow : AirflowPort;
        port coreExhaust : AirflowPort;     // to LPC
        port bypassExhaust : AirflowPort;   // to bypass duct / nozzle
        port shaftLP : LPSpoolPort;
    }

    part def FanRotor {
        attribute hubToTipRatio : Real = 0.295;
        attribute aspectRatio : Real = 2.4;           // blade span / chord
        attribute staggerAngleDeg : Real = 63.0;
    }

    part def OutletGuideVane {
        attribute material : String = "Aluminum_7075";
        attribute cooled : Boolean = false;
    }

    part def FanCaseFOD_Liner {
        doc /* Containment ring + abradable liner for blade-off FOD event. FAR 33.94 compliant. */
        attribute material : String = "Kevlar_Containment";
        attribute certificationStandard : String = "FAR33_94";
    }

    // ═════════════════════════════════════════════════════════════════════════
    // LOW-PRESSURE COMPRESSOR (LPC / BOOSTER)
    // ═════════════════════════════════════════════════════════════════════════

    part def LowPressureCompressor {
        doc /* 3-stage axial booster driven by LP shaft.
               Titanium blades and discs. Handles pre-compressed core air from fan. */

        attribute stageCount : Integer = 3;
        attribute overallPressureRatio : Real = 2.20;   // LPC contribution
        attribute adiabaticEfficiency : Real = 0.905;
        attribute inletTemperature : Real = 288.15;     // K (ISA SL)
        attribute outletTemperature : Real = 415.0;     // K after LPC
        attribute bladeMaterial : String = "Ti-6Al-4V";
        attribute discMaterial : String = "Ti-6Al-4V";

        part stages : TurboMachineStage[3];

        port coreInlet : AirflowPort;
        port coreOutlet : AirflowPort;
        port shaftLP : LPSpoolPort;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // HIGH-PRESSURE COMPRESSOR (HPC)
    // ═════════════════════════════════════════════════════════════════════════

    part def HighPressureCompressor {
        doc /* 9-stage axial HPC driven by HP shaft.
               Stages 1-4: titanium; Stages 5-9: nickel superalloy (IN718).
               Variable stator vanes (VSV) on stages 1-3 for operability. */

        attribute stageCount : Integer = 9;
        attribute overallPressureRatio : Real = 18.18;   // HPC pressure ratio (OPR/FPR/LPC)
        attribute adiabaticEfficiency : Real = 0.872;
        attribute inletTemperature : Real = 415.0;       // K from LPC outlet
        attribute outletTemperature : Real = 910.0;      // K (before combustor)
        attribute inletPressure : Real = 450.0;          // kPa
        attribute exitPressure : Real = 4000.0;          // kPa (OPR ≈ 40)
        attribute variableStatorStages : Integer = 3;    // VSV control range
        attribute frontStagesMaterial : String = "Ti-6Al-4V";
        attribute rearStagesMaterial : String = "IN718_Inconel";

        part stages : TurboMachineStage[9];
        part variableStatorActuators : LinearActuator[3];

        port coreInlet : AirflowPort;
        port coreOutlet : AirflowPort;
        port bleedExtraction : BleedAirPort;    // 8th-stage bleed for ECS
        port shaftHP : HPSpoolPort;
    }

    part def LinearActuator {
        attribute actuationType : String = "HydroMechanical";
        attribute strokeMm : Real = 45.0;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // COMBUSTOR
    // ═════════════════════════════════════════════════════════════════════════

    part def AnnularCombustor {
        doc /* Twin-annular premixed swirler (TAPS) combustor for NOx reduction.
               ICAO CAEP/6 NOx margin: -50% (LEAP class).
               Fuel: Jet-A / Jet-A1. SAF (Sustainable Aviation Fuel) 50% blend certified. */

        attribute combustorType : String = "TAPS_TwinAnnularPremixedSwirler";
        attribute inletTemperature : Real = 910.0;     // K
        attribute exitTemperature : Real = 1820.0;     // K turbine inlet (TIT)
        attribute temperatureRiseK : Real = 910.0;     // ΔT combustor
        attribute patternFactor : Real = 0.15;         // TIT profile uniformity
        attribute fuelType : String = "JetA_SAFBlend";
        attribute safBlendMax : Real = 50.0;           // % SAF blend certified
        attribute noxReductionVsCAEP6 : Real = 50.0;  // %
        attribute mainBurnerNozzleCount : Integer = 24;
        attribute pilotBurnerNozzleCount : Integer = 24;
        attribute fuelFlowTakeOff : Real = 1.08;       // kg/s per engine at T/O

        part mainBurnerNozzles : FuelNozzle[24];
        part pilotBurnerNozzles : FuelNozzle[24];
        part combustorLiner : CombustorLiner;
        part transitionPiece : TransitionPiece;

        port airInlet : AirflowPort;
        port fuelInlet : FuelFlowPort;
        port exhaustGas : AirflowPort;
    }

    part def FuelNozzle {
        attribute nozzleType : String = "SimplexSwirlAtomizer";
        attribute flowNumber : Real = 3.5;     // mm²·(kPa)^0.5 / (kg/s)
    }

    part def CombustorLiner {
        attribute material : String = "CMC_SiC_SiC";   // Ceramic Matrix Composite
        attribute coolingType : String = "FilmImpingement";
        attribute maxWallTemp : Real = 1260.0;           // K liner temperature
    }

    part def TransitionPiece {
        attribute material : String = "IN939_Nickel";
    }

    // ═════════════════════════════════════════════════════════════════════════
    // HIGH-PRESSURE TURBINE (HPT)
    // ═════════════════════════════════════════════════════════════════════════

    part def HighPressureTurbine {
        doc /* 2-stage cooled HPT driving the HP compressor shaft.
               Stage 1 NGV and blades: single-crystal superalloy (CMSX-4) with thermal barrier coating (TBC).
               Blade cooling: film + internal convection + impingement.
               Turbine Inlet Temperature (TIT): 1820 K at take-off. */

        attribute stageCount : Integer = 2;
        attribute turbineInletTemp : Real = 1820.0;   // K
        attribute stage1ExitTemp : Real = 1480.0;     // K
        attribute stage2ExitTemp : Real = 1180.0;     // K (HP exit)
        attribute adiabaticEfficiency : Real = 0.885;
        attribute coolingAirFraction : Real = 0.20;   // 20% of core flow used for cooling
        attribute bladeMaterial : String = "CMSX4_SingleCrystal";
        attribute coatingType : String = "TBC_YSZ_7wt";  // Yttria-Stabilized Zirconia TBC
        attribute bladeCoolingType : String = "FilmImpingementConvection";

        part nozzleGuideVanes : CooledNozzleGuideVane[2]; // 2 rows
        part rotorBlades : CooledTurbineBlade[2];          // 2 blade rows

        port gasInlet : AirflowPort;
        port gasOutlet : AirflowPort;
        port coolingAirIn : BleedAirPort;
        port shaftHP : HPSpoolPort;
    }

    part def CooledNozzleGuideVane {
        attribute material : String = "CMSX4_SingleCrystal";
        attribute coatingType : String = "TBC_YSZ_7wt";
        attribute coolingType : String = "FilmImpingement";
        attribute maxMetalTemp : Real = 1150.0;   // K metal temperature
    }

    part def CooledTurbineBlade {
        attribute material : String = "CMSX4_SingleCrystal";
        attribute coatingType : String = "TBC_YSZ_7wt";
        attribute coolingType : String = "FilmImpingementConvection";
        attribute bladeAspectRatio : Real = 1.8;
        attribute maxMetalTemp : Real = 1120.0;   // K
    }

    // ═════════════════════════════════════════════════════════════════════════
    // LOW-PRESSURE TURBINE (LPT)
    // ═════════════════════════════════════════════════════════════════════════

    part def LowPressureTurbine {
        doc /* 7-stage uncooled/lightly-cooled LPT driving fan and LPC via LP shaft.
               Nickel superalloy blades (IN792 / René 80).
               Largest turbine diameter drives LP shaft powering the fan. */

        attribute stageCount : Integer = 7;
        attribute inletTemperature : Real = 1180.0;   // K at LPT inlet
        attribute exitTemperature : Real = 720.0;     // K core exhaust
        attribute adiabaticEfficiency : Real = 0.920;
        attribute bladeMaterial : String = "IN792_Nickel";
        attribute cooled : Boolean = false;           // lightly or uncooled stages
        attribute shaftPowerExtracted : Real = 53000.0;  // kW driving fan + LPC

        part stages : TurboMachineStage[7];

        port gasInlet : AirflowPort;
        port gasOutlet : AirflowPort;
        port shaftLP : LPSpoolPort;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // FULL AUTHORITY DIGITAL ENGINE CONTROL (FADEC)
    // ═════════════════════════════════════════════════════════════════════════

    part def FADEC {
        doc /* Dual-channel Full Authority Digital Engine Control.
               DO-178C Level A software, DO-254 Level A hardware.
               Controls fuel metering, VSV scheduling, bleed valve, ignition, thrust management.
               Certified to EASA CS-E / FAA FAR Part 33. */

        attribute channels : Integer = 2;         // dual-redundant channels
        attribute activeChannel : String = "A";   // hot standby
        attribute softwareLevel : String = "DO178C_LevelA";
        attribute hardwareLevel : String = "DO254_LevelA";
        attribute processorType : String = "PowerPC_750FX";
        attribute updateRateHz : Real = 80.0;     // main control loop
        attribute thrustRatingModes : Integer = 5;  // TO, MCT, CLB, CRZ, GA

        part channelA : FADECChannel;
        part channelB : FADECChannel;
        part fuelMeteringUnit : FuelMeteringUnit;
        part engineSensorHarness : SensorHarness;

        port arinc429Bus : ARINC429Port;   // to aircraft FMS / FADEC-EICAS
        port discreteInputs : DiscreteIOPort;
        port fuelCommand : FuelFlowPort;
        port vsvActuation : ActuationPort;
    }

    part def FADECChannel {
        attribute processorClock : Real = 300.0;     // MHz
        attribute nonvolatileMemory : Real = 4.0;    // MB NOR flash
        attribute ram : Real = 64.0;                 // MB
    }

    part def FuelMeteringUnit {
        doc /* Hydro-mechanical fuel metering valve + HMU with electrohydraulic servo. */
        attribute maxFuelFlow : Real = 1.5;           // kg/s
        attribute minFuelFlow : Real = 0.02;          // kg/s idle
        attribute controlValveType : String = "ElectroHydraulicServo";
    }

    part def SensorHarness {
        attribute thermocouplePairs : Integer = 8;   // EGT thermocouples
        attribute pressureTransducers : Integer = 12;
        attribute speedSensors : Integer = 4;        // N1, N2 on both channels
    }

    // ═════════════════════════════════════════════════════════════════════════
    // FUEL SYSTEM
    // ═════════════════════════════════════════════════════════════════════════

    part def FuelDeliverySystem {
        doc /* High-pressure fuel delivery from aircraft tank to combustor.
               Dual-element fuel pump, filter, and flow-divider. */

        attribute fuelType : String = "JetA_JetA1";
        attribute maxFuelPressure : Real = 5500.0;   // kPa (800 psi) max supply
        attribute filterMicronRating : Real = 40.0;  // µm

        part fuelPumpHP : CentrifugalFuelPump;
        part fuelFilter : FuelFilter;
        part flowDivider : FlowDivider;

        port fuelInletLow : FuelFlowPort;    // from aircraft tanks (low pressure)
        port fuelOutletHigh : FuelFlowPort;  // to combustor nozzles (high pressure)
    }

    part def CentrifugalFuelPump {
        attribute maxFlowRate : Real = 2.0;    // kg/s
        attribute pressureRise : Real = 5000.0; // kPa
    }

    part def FuelFilter {
        attribute filtrationRating : Real = 40.0;  // µm absolute
        attribute bypassDeltaPressure : Real = 140.0; // kPa bypass crack
    }

    part def FlowDivider {
        attribute splitRatio : Real = 0.50;    // 50/50 pilot/main
    }

    // ═════════════════════════════════════════════════════════════════════════
    // OIL / LUBRICATION SYSTEM
    // ═════════════════════════════════════════════════════════════════════════

    part def LubricationSystem {
        doc /* Pressure-fed oil system for bearing lubrication and cooling.
               MIL-PRF-23699 oil specification. */

        attribute oilSpec : String = "MIL_PRF_23699_Ester";
        attribute oilTankCapacity : Real = 12.0;    // liters
        attribute maxOilTemp : Real = 163.0;        // °C continuous

        part oilPump : OilPump;
        part oilCooler : OilCooler;
        part oilFilter : OilFilter;
        part oilTank : OilTank;

        port bearingLubeSupply : OilPort;
        port bearingLubeReturn : OilPort;
        port heatExchangerFuel : FuelFlowPort;  // fuel-oil cooler
    }

    part def OilPump { attribute maxFlowRate : Real = 40.0; }  // L/min
    part def OilCooler { attribute heatRejection : Real = 80000.0; }  // W
    part def OilFilter { attribute filtrationRating : Real = 3.0; }   // µm
    part def OilTank { attribute capacity : Real = 12.0; }             // L

    // ═════════════════════════════════════════════════════════════════════════
    // EXHAUST AND NOZZLE
    // ═════════════════════════════════════════════════════════════════════════

    part def CoreExhaustNozzle {
        doc /* Fixed convergent core nozzle. Mixer optional on some variants. */
        attribute nozzleType : String = "FixedConvergent";
        attribute throatArea : Real = 0.212;     // m² at cruise
        attribute exitTemperature : Real = 720.0; // K
        attribute exhaustVelocityCore : Real = 380.0;  // m/s
        attribute chevronCount : Integer = 12;   // noise-reducing serrated trailing edge

        port gasInlet : AirflowPort;
        port atmosphere : AirflowPort;
    }

    part def BypassExhaustNozzle {
        doc /* Fixed convergent bypass (fan) nozzle. Short duct mixed exhaust on some variants. */
        attribute nozzleType : String = "FixedConvergentBypass";
        attribute throatArea : Real = 1.42;      // m²
        attribute exhaustVelocityBypass : Real = 285.0;  // m/s
        attribute chevronCount : Integer = 18;

        port bypassInlet : AirflowPort;
        port atmosphere : AirflowPort;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // SHAFTS / SPOOLS
    // ═════════════════════════════════════════════════════════════════════════

    part def LPSpool :> Spool {
        doc /* Low-Pressure spool: fan + LPC (front) + LPT (rear).
               Max rated N1 speed ~3500 RPM at take-off. */
        attribute maxSpeedRPM : Real = 3500.0;
        attribute idleSpeedRPM : Real = 1050.0;
        attribute :>> inertia = 4.5;   // kg·m²
        attribute shaftMaterial : String = "Ti-6Al-4V_HP_Shaft";
    }

    part def HPSpool :> Spool {
        doc /* High-Pressure spool: HPC + HPT.
               N2 max ~15,000 RPM at take-off. */
        attribute maxSpeedRPM : Real = 15000.0;
        attribute idleSpeedRPM : Real = 6300.0;
        attribute :>> inertia = 0.85;  // kg·m²
        attribute shaftMaterial : String = "IN718_Nickel_Shaft";
    }

    // ═════════════════════════════════════════════════════════════════════════
    // FULL ENGINE ASSEMBLY
    // ═════════════════════════════════════════════════════════════════════════

    part def TurbofanEngine {
        doc /* Complete 2-spool high-bypass turbofan assembly.
               Reference: CFM LEAP-1B (Boeing 737 MAX 8 certification, EASA / FAA).
               Take-off thrust: 28,000 lbf (124.5 kN) at ISA sea level.
               Specific Fuel Consumption (SFC) at cruise: 0.526 lb/lbf·hr.
               Certified to: FAR Part 33 / EASA CS-E, ETOPS 180 min. */

        attribute engineDesignation : String = "LEAP-1B_Class";
        attribute engineFamily : String = "CFM_LEAP";
        attribute applicationAircraft : String = "Boeing_737_MAX";
        attribute takeOffThrust : Real = 124500.0;    // N (28,000 lbf)
        attribute maxContinuousThrust : Real = 110000.0; // N (MCT)
        attribute thrustSFC_Cruise : Real = 0.526;    // lb/lbf·hr at 35,000ft M0.85
        attribute bypassRatio : Real = 9.0;
        attribute overallPressureRatio : Real = 40.0; // at take-off
        attribute massFlowTakeOff : Real = 650.0;     // kg/s
        attribute engineDryMass : Real = 2869.0;      // kg (dry)
        attribute engineLength : Real = 3.81;         // m
        attribute fanDiameter : Real = 1.76;          // m
        attribute certificationBasis : String = "FAR33_EASACSE_ETOPS180";

        part fan : FanModule;
        part lpc : LowPressureCompressor;
        part hpc : HighPressureCompressor;
        part combustor : AnnularCombustor;
        part hpt : HighPressureTurbine;
        part lpt : LowPressureTurbine;
        part fadec : FADEC;
        part fuelSystem : FuelDeliverySystem;
        part lubSystem : LubricationSystem;
        part coreNozzle : CoreExhaustNozzle;
        part bypassNozzle : BypassExhaustNozzle;
        part lpShaft : LPSpool;
        part hpShaft : HPSpool;

        // LP spool connections
        interface fanToLPShaft connect fan.shaftLP to lpShaft.inletShaftPort;
        interface lpcToLPShaft connect lpc.shaftLP to lpShaft.inletShaftPort;
        interface lptToLPShaft connect lpt.shaftLP to lpShaft.inletShaftPort;

        // HP spool connections
        interface hpcToHPShaft connect hpc.shaftHP to hpShaft.inletShaftPort;
        interface hptToHPShaft connect hpt.shaftHP to hpShaft.inletShaftPort;

        // Gaspath connections
        interface inletToFan connect engineInlet to fan.inletAirflow;
        interface fanCoreToLPC connect fan.coreExhaust to lpc.coreInlet;
        interface lpcToHPC connect lpc.coreOutlet to hpc.coreInlet;
        interface hpcToCombustor connect hpc.coreOutlet to combustor.airInlet;
        interface combustorToHPT connect combustor.exhaustGas to hpt.gasInlet;
        interface hptToLPT connect hpt.gasOutlet to lpt.gasInlet;
        interface lptToCoreNozzle connect lpt.gasOutlet to coreNozzle.gasInlet;
        interface fanBypassToNozzle connect fan.bypassExhaust to bypassNozzle.bypassInlet;

        // Fuel
        interface fadecFuelCmd connect fadec.fuelCommand to fuelSystem.fuelInletLow;
        interface fuelToCombusor connect fuelSystem.fuelOutletHigh to combustor.fuelInlet;

        port engineInlet : AirflowPort;
        port thrustOutput : ThrustPort;
        port bleedAirSupply : BleedAirPort;
        port arinc429 : ARINC429Port;
        port fuelSupplyAircraft : FuelFlowPort;
        port electricalPower : ElectricalBusPort;  // IDG takeoff from HP shaft
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PORT DEFINITIONS
    // ═════════════════════════════════════════════════════════════════════════

    port def AirflowPort {
        attribute massFlowKgPerSec : Real;
        attribute totalPressureKPa : Real;
        attribute totalTemperatureK : Real;
    }

    port def FuelFlowPort {
        attribute massFlowKgPerSec : Real;
        attribute fuelPressureKPa : Real;
    }

    port def LPSpoolPort {
        attribute speedRPM : Real;
        attribute torqueNm : Real;
    }

    port def HPSpoolPort {
        attribute speedRPM : Real;
        attribute torqueNm : Real;
    }

    port def BleedAirPort {
        attribute pressureKPa : Real;
        attribute temperatureK : Real;
        attribute massFlowKgPerSec : Real;
    }

    port def ARINC429Port {
        attribute dataRate : Integer = 100000;  // bps high-speed
    }

    port def DiscreteIOPort { }
    port def ActuationPort { }
    port def OilPort { }
    port def ThrustPort {
        attribute thrustN : Real;
    }
    port def ElectricalBusPort {
        attribute voltageV : Real = 115.0;    // VAC 3-phase 400 Hz aircraft bus
        attribute powerKVA : Real;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // REQUIREMENTS
    // ═════════════════════════════════════════════════════════════════════════

    requirement def TakeOffThrustReq {
        doc /* REQ-THRUST-001: Engine shall produce minimum 124,500 N take-off thrust at ISA sea level,
               standard day conditions, with no bleeds extracted. */
        subject : TurbofanEngine;
    }

    requirement def FADECSafetyReq {
        doc /* REQ-FADEC-001: FADEC shall comply with DO-178C Level A / DO-254 Level A for all
               thrust control functions. Failure rate < 1×10⁻⁹ per flight hour (catastrophic). */
        subject : FADEC;
    }

    requirement def NOxEmissionsReq {
        doc /* REQ-NOX-001: Engine NOx emissions at ICAO LTO cycle shall be ≥ 50% below ICAO CAEP/6
               limit at each power setting. */
        subject : AnnularCombustor;
    }

    requirement def ColdStartReq {
        doc /* REQ-START-001: Engine shall achieve idle self-sustaining speed within 30 seconds
               from start initiation at -40°C ISA. */
        subject : TurbofanEngine;
    }

    requirement def ETOPSReq {
        doc /* REQ-ETOPS-001: Engine in-flight shutdown rate (IFSD) shall not exceed 0.005 events
               per 1000 engine flight hours (ETOPS 180 min compliance). */
        subject : TurbofanEngine;
    }
}
