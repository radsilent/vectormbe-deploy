package 'NuclearPowerPlant' {
    doc /* Pressurized Water Reactor nuclear power plant system model.
         Rated thermal output 3411 MWth, electrical output 1150 MWe.
         Westinghouse AP1000 reference design. */

    // ── Value types ──────────────────────────────────────────────────────────
    attribute def MWth { doc /* Megawatts thermal */ }
    attribute def MWe  { doc /* Megawatts electric */ }
    attribute def MPa  { doc /* Megapascals pressure */ }
    attribute def DegC { doc /* Degrees Celsius */ }

    // ── Part definitions ─────────────────────────────────────────────────────
    part def ReactorCore {
        doc /* 193-assembly PWR core; UO2 fuel, 4.95 w/o enrichment */
        attribute thermalPower      : Real = 3411.0;   // MWth rated
        attribute fuelAssemblies    : Integer = 193;
        attribute activeLength_mm   : Real = 4267.0;
        attribute coreInletTemp     : Real = 280.7;    // °C
        attribute coreOutletTemp    : Real = 321.1;    // °C
        attribute operatingPressure : Real = 15.51;    // MPa

        part controlRodDrive : ControlRodDriveSystem;
        part inCoreMon       : InCoreMonitoringSystem;
        part fuelAssemblySet : FuelAssembly[193];
    }

    part def ControlRodDriveSystem {
        doc /* Magnetic-jack CRDM; 69 full-length control rod assemblies */
        attribute rodAssemblies     : Integer = 69;
        attribute withdrawalSpeed   : Real = 18.9;     // steps/min
        attribute dropTime_s        : Real = 2.2;      // s to fully inserted
    }

    part def PrimaryCoolantLoop {
        doc /* Two-loop RCS; each loop contains one SG and one RCP */
        attribute designPressure    : Real = 17.24;    // MPa
        attribute designTemp        : Real = 343.3;    // °C
        attribute flowRate_kg_s     : Real = 4713.0;   // kg/s per loop

        part steamGenerator   : SteamGenerator;
        part reactorCoolantPump : ReactorCoolantPump;
        part hotLeg           : CoolantPiping;
        part coldLeg          : CoolantPiping;
    }

    part def SteamGenerator {
        doc /* Vertical U-tube SG; Alloy 690TT tubes */
        attribute thermalDuty_MWth  : Real = 1705.5;
        attribute tubeCount         : Integer = 10025;
        attribute primaryPressure   : Real = 15.51;    // MPa
        attribute secondaryPressure : Real = 6.89;     // MPa
        attribute steamFlowRate_kg_s: Real = 900.0;
    }

    part def ReactorCoolantPump {
        doc /* Single-speed canned motor pump */
        attribute flowRate_m3_s  : Real = 5.17;
        attribute designHead_m   : Real = 91.4;
        attribute motorPower_MWe : Real = 6.7;
    }

    part def SecondaryCoolantLoop {
        doc /* Rankine cycle; turbine-generator, feedwater, condensate */
        attribute steamPressure     : Real = 6.89;     // MPa
        attribute grossOutput_MWe   : Real = 1150.0;
        attribute thermalEfficiency : Real = 0.337;    // 33.7%

        part steamTurbine    : SteamTurbine;
        part mainCondenser   : Condenser;
        part feedwaterHeaters: FeedwaterHeater[7];
        part mainFeedPumps   : FeedwaterPump[2];
    }

    part def EmergencyCoreCS {
        doc /* ECCS: passive core injection, accumulators, IRWST */
        attribute injectionFlowRate_m3_s : Real = 0.63;
        attribute accumulatorPressure    : Real = 4.83;    // MPa
        attribute irwstVolume_m3         : Real = 2092.0;

        part coreInjection : CoreMakeupTank[2];
        part accumulators  : Accumulator[4];
        part irwst         : IRWST;
        part residualHeatRemoval : RHRSystem;
    }

    part def ContainmentStructure {
        doc /* Steel containment vessel inside concrete shield building */
        attribute designPressure_MPa  : Real = 0.41;
        attribute designTemp_C        : Real = 148.9;
        attribute freeVolume_m3       : Real = 58980.0;
        attribute diameter_m          : Real = 39.6;
        attribute wallThickness_mm    : Real = 44.5;      // steel shell
    }

    part def InstrumentationControl {
        doc /* Distributed digital I&C; Westinghouse Common Q platform */
        attribute redundancyLevel     : Integer = 4;      // divisions
        attribute responseTime_ms     : Real = 100.0;

        part reactorProtection   : ReactorProtectionSystem;
        part esfActuation        : ESFActuationSystem;
        part processControl      : ProcessControlSystem;
        part postAccidentMon     : PostAccidentMonitoring;
    }

    // ── Top-level system ─────────────────────────────────────────────────────
    part def NuclearPowerPlantSystem {
        part reactor     : ReactorCore;
        part primaryLoop : PrimaryCoolantLoop[2];
        part secondary   : SecondaryCoolantLoop;
        part eccs        : EmergencyCoreCS;
        part containment : ContainmentStructure;
        part iandc       : InstrumentationControl;
    }

    // ── Requirements ─────────────────────────────────────────────────────────
    requirement def ThermalOutputReq {
        doc /* Reactor shall achieve rated thermal output */
        attribute reqId : String = 'REQ-NUC-001';
        attribute text  : String = 'The reactor core shall achieve 3411 MWth rated thermal power at 100% power level under normal operating conditions.';
        subject : ReactorCore;
    }

    requirement def SafetyMarginReq {
        doc /* DNBR margin shall be maintained above 1.3 */
        attribute reqId : String = 'REQ-NUC-002';
        attribute text  : String = 'The minimum departure from nucleate boiling ratio (MDNBR) shall not fall below 1.30 during any Condition II event.';
        subject : ReactorCore;
    }

    requirement def ScramResponseReq {
        doc /* Reactor trip shall be complete within 2.2 s */
        attribute reqId : String = 'REQ-NUC-003';
        attribute text  : String = 'All control rods shall be fully inserted within 2.2 seconds of a reactor trip signal, assuming the highest-worth rod is stuck fully withdrawn.';
        subject : ControlRodDriveSystem;
    }

    requirement def ECCSInjectionReq {
        doc /* ECCS shall maintain peak cladding temperature below 1204 degC */
        attribute reqId : String = 'REQ-NUC-004';
        attribute text  : String = 'Following a design-basis LOCA, the ECCS shall limit peak cladding temperature to no more than 1204 degC (2200 degF) per 10 CFR 50.46.';
        subject : EmergencyCoreCS;
    }

    requirement def RedundancyReq {
        doc /* I&C shall be quad-redundant with physical separation */
        attribute reqId : String = 'REQ-NUC-005';
        attribute text  : String = 'The reactor protection and ESFAS shall be implemented in four independent, physically separated divisions. Any single division failure shall not prevent a protective function.';
        subject : InstrumentationControl;
    }

    requirement def ContainmentIntegrityReq {
        doc /* Containment leak rate shall not exceed 0.1% per day */
        attribute reqId : String = 'REQ-NUC-006';
        attribute text  : String = 'Containment leakage shall not exceed 0.1% of contained air mass per day at peak accident pressure (Pa = 0.41 MPa).';
        subject : ContainmentStructure;
    }
}
