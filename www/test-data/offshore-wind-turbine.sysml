package 'OffshoreWindTurbine' {
    doc /* Offshore horizontal-axis wind turbine system model.
         15 MW reference turbine (IEA 15 MW RWT basis); monopile foundation,
         rotor diameter 240 m, hub height 150 m, Class IEC S. */

    // ── Value types ──────────────────────────────────────────────────────────
    attribute def MWe        { doc /* Megawatts electric output */ }
    attribute def RPM        { doc /* Revolutions per minute */ }
    attribute def Meganewton { doc /* Force in MN */ }

    // ── Rotor and hub ────────────────────────────────────────────────────────
    part def RotorSystem {
        doc /* Three-bladed upwind rotor; carbon-glass hybrid blades */
        attribute ratedPower_MW        : Real = 15.0;
        attribute rotorDiameter_m      : Real = 240.0;
        attribute bladeCount           : Integer = 3;
        attribute bladeLength_m        : Real = 117.0;
        attribute ratedRotorSpeed_rpm  : Real = 7.56;
        attribute cutInWindSpeed_ms    : Real = 3.0;
        attribute ratedWindSpeed_ms    : Real = 10.59;
        attribute cutOutWindSpeed_ms   : Real = 25.0;
        attribute maxTipSpeed_ms       : Real = 95.0;   // m/s

        part blade        : WindTurbineBlade[3];
        part hub          : RotorHub;
        part spinner      : NoseConeSpinner;
        part pitchBearing : PitchBearing[3];
    }

    part def WindTurbineBlade {
        doc /* NREL-5MW scaled geometry; flatback root, max chord 6.2 m */
        attribute length_m             : Real = 117.0;
        attribute maxChord_m           : Real = 6.2;
        attribute designLifetime_yr    : Real = 25.0;
        attribute flapwiseMoment_MNm   : Real = 60.0;   // rated, flapwise
        attribute material             : String = 'Carbon-glass hybrid epoxy';
    }

    // ── Drivetrain ───────────────────────────────────────────────────────────
    part def Drivetrain {
        doc /* Medium-speed, two-stage gearbox + PMSG */
        attribute gearRatio            : Real = 50.0;
        attribute generatorSpeed_rpm   : Real = 378.0;  // rated
        attribute peakTorque_MNm       : Real = 19.0;   // low-speed shaft
        attribute drivetrainEfficiency : Real = 0.965;

        part mainShaft      : MainShaft;
        part mainBearing    : MainBearing[2];
        part gearbox        : TwoStageGearbox;
        part hssShaft       : HighSpeedShaft;
        part hssBrake       : MechanicalBrake;
        part generator      : PMSGenerator;
        part coupling       : FlexibleCoupling;
    }

    // ── Power conversion ─────────────────────────────────────────────────────
    part def PowerConversionSystem {
        doc /* Full-power back-to-back voltage source converter; 66 kV export */
        attribute ratedPower_MW        : Real = 15.0;
        attribute converterVoltage_kV  : Real = 0.690;  // generator-side
        attribute gridVoltage_kV       : Real = 66.0;   // offshore grid
        attribute powerFactor          : Real = 1.0;    // unity at rated
        attribute converterEfficiency  : Real = 0.985;

        part generatorSideConv  : GeneratorSideConverter;
        part gridSideConv       : GridSideConverter;
        part transformer        : StepUpTransformer;
        part filterInductor     : LCLFilter;
        part crowbarProtect     : CrowbarCircuit;
        part pitchDriveUPS      : PitchDriveUPS;
    }

    // ── SCADA and control ────────────────────────────────────────────────────
    part def SCADASystem {
        doc /* Turbine controller, SCADA gateway, condition monitoring */
        attribute controlCycleTime_ms  : Real = 5.0;
        attribute dataScanRate_Hz      : Real = 50.0;
        attribute telemetryProtocol    : String = 'IEC 61400-25 / OPC-UA';
        attribute availabilityTarget   : Real = 0.97;   // 97% gross

        part turbineController  : TurbineController;
        part pitchController    : PitchController[3];
        part yawController      : YawController;
        part scadaGateway       : SCADAGateway;
        part conditionMonitor   : CMSUnit;
        part safetyPLC          : SafetyPLC;
        part meteorologicalMast : MetMast;
    }

    part def TurbineController {
        doc /* Main PLC; torque/speed regulation, curtailment, alarms */
        attribute cpuRedundancy        : Integer = 2;   // hot standby
        attribute controlModes         : String = 'MPPT, rated, curtailed, storm';
        attribute watchdogTimeout_ms   : Real = 500.0;
    }

    part def PitchController {
        doc /* Individual blade pitch; electrohydraulic; backup battery */
        attribute pitchRate_deg_s      : Real = 8.0;    // max pitch rate
        attribute pitchRange_deg_min   : Real = -5.0;
        attribute pitchRange_deg_max   : Real = 95.0;   // feather
        attribute emergencyPitchTime_s : Real = 5.0;    // full feather from rated
        attribute batteryBackup_min    : Real = 20.0;   // UPS hold-up
    }

    // ── Foundation ───────────────────────────────────────────────────────────
    part def MonopileFoundation {
        doc /* Steel monopile; water depth 30–50 m; grouted transition piece */
        attribute waterDepth_m         : Real = 40.0;
        attribute pilingDiameter_m     : Real = 10.0;
        attribute wallThickness_mm     : Real = 100.0;
        attribute pileLength_m         : Real = 80.0;
        attribute designLifetime_yr    : Real = 25.0;
        attribute fatigueSafetyFactor  : Real = 1.25;   // IEC 61400-3-1

        part monopile    : SteelMonopile;
        part transitionPiece: TransitionPiece;
        part scourProtect: ScourProtection;
        part j_tubes     : CableJTube[3];
    }

    // ── Top-level turbine ────────────────────────────────────────────────────
    part def OffshoreWindTurbineSystem {
        part rotor       : RotorSystem;
        part drivetrain  : Drivetrain;
        part powerConv   : PowerConversionSystem;
        part scada       : SCADASystem;
        part foundation  : MonopileFoundation;
        part nacelle     : NacelleStructure;
        part tower       : TowerSection[5];
    }

    // ── Requirements ─────────────────────────────────────────────────────────
    requirement def RatedPowerReq {
        attribute reqId : String = 'REQ-WND-001';
        attribute text  : String = 'The turbine shall deliver a rated net electrical output of 15.0 MW at hub-height wind speed of 10.59 m/s and shall maintain rated output for all wind speeds between 10.59 m/s and 25.0 m/s.';
        subject : PowerConversionSystem;
    }

    requirement def AvailabilityReq {
        attribute reqId : String = 'REQ-WND-002';
        attribute text  : String = 'Each turbine shall achieve a technical availability of not less than 97% calculated over any rolling 12-month operational period, excluding force-majeure outages and planned maintenance windows.';
        subject : SCADASystem;
    }

    requirement def FatigueLifeReq {
        attribute reqId : String = 'REQ-WND-003';
        attribute text  : String = 'All structural components including blades, main shaft, drivetrain, and foundation shall be designed for a minimum 25-year service life at the site wind and wave climate, with safety factors not less than those required by IEC 61400-3-1 GL Offshore 2012.';
        subject : MonopileFoundation;
    }

    requirement def PitchEmergencyReq {
        attribute reqId : String = 'REQ-WND-004';
        attribute text  : String = 'Each blade pitch system shall independently feather the blade from rated pitch angle to full feather (90°) within 5 seconds using battery backup power, without reliance on grid or turbine auxiliary supply.';
        subject : SCADASystem;
    }

    requirement def GridCodeReq {
        attribute reqId : String = 'REQ-WND-005';
        attribute text  : String = 'The power conversion system shall comply with the applicable offshore grid code: low-voltage ride-through to 0 V for 150 ms, reactive current injection of 100% of rated current during voltage dip, and power factor controllable from 0.95 leading to 0.95 lagging.';
        subject : PowerConversionSystem;
    }

    requirement def RotorStructuralReq {
        attribute reqId : String = 'REQ-WND-006';
        attribute text  : String = 'Rotor blades shall withstand the extreme turbulent wind model (ETM) load case per IEC 61400-1 Ed.4 with a structural safety factor of 1.1 on characteristic loads, and no single blade failure shall cause uncontrolled hub rotation exceeding 120% of rated speed.';
        subject : RotorSystem;
    }
}
