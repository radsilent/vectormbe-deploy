package 'AutonomousVehicleSystem' {
    doc /* SAE Level 4 autonomous vehicle system model.
         Passenger-car form factor; designed for structured urban/suburban ODD.
         ISO 21448 SOTIF, ISO 26262 ASIL-D for safety-critical functions. */

    // ── Sensor suite ─────────────────────────────────────────────────────────
    part def LidarSubsystem {
        doc /* Solid-state LiDAR array; 360° horizontal, ±15° vertical */
        attribute units                : Integer = 5;   // 1 roof + 4 corner
        attribute range_m              : Real = 200.0;  // @10% reflectivity
        attribute angularResolution_deg: Real = 0.1;
        attribute pointRate_MHz        : Real = 4.8;
        attribute updateRate_Hz        : Real = 20.0;
        attribute operatingTemp_C_min  : Real = -40.0;
        attribute operatingTemp_C_max  : Real = 85.0;

        part roofUnit    : SolidStateLidar;
        part cornerUnit  : SolidStateLidar[4];
    }

    part def RadarSubsystem {
        doc /* 77 GHz FMCW radar; front long-range + perimeter short-range */
        attribute frontRange_m         : Real = 250.0;  // long-range
        attribute shortRange_m         : Real = 70.0;   // corner SRR
        attribute velocityResolution   : Real = 0.1;    // m/s
        attribute azimuthFOV_deg_lr    : Real = 20.0;   // long-range
        attribute azimuthFOV_deg_sr    : Real = 150.0;  // short-range

        part frontLongRange  : LongRangeRadar;
        part cornerRadar     : ShortRangeRadar[4];
        part rearLongRange   : LongRangeRadar;
    }

    part def CameraSubsystem {
        doc /* Surround camera ring + stereo pair; 1920×1080, 30 fps */
        attribute surroundUnits        : Integer = 8;
        attribute stereoBaseline_mm    : Real = 400.0;
        attribute resolution           : String = '1920x1080';
        attribute frameRate_fps        : Real = 30.0;
        attribute dynamicRange_dB      : Real = 120.0;   // HDR

        part surroundCamera  : MonocularCamera[8];
        part stereoPair      : StereoCameraModule;
        part imuSynced       : SynchronizationUnit;
    }

    part def GNSSIMUUnit {
        doc /* Dual-antenna RTK GNSS + tactical-grade IMU; fusion nav */
        attribute positionAccuracy_m   : Real = 0.02;   // CEP, RTK fix
        attribute headingAccuracy_deg  : Real = 0.1;
        attribute imuUpdateRate_Hz     : Real = 200.0;
        attribute gnssUpdateRate_Hz    : Real = 10.0;
        attribute degradedModeAccuracy : Real = 1.5;    // m, GNSS outage 30 s

        part rtkGNSS     : DualAntennaRTK;
        part tacticalIMU : TacticalIMU;
        part fusionFilter: KalmanFusionFilter;
    }

    // ── Perception ───────────────────────────────────────────────────────────
    part def PerceptionSystem {
        doc /* Sensor fusion, object detection/tracking, free-space estimation */
        attribute detectionLatency_ms  : Real = 50.0;   // sensor to tracked object
        attribute classificationAcc    : Real = 0.995;  // @ recall 0.99
        attribute trackCapacity        : Integer = 512;
        attribute minObjectSize_m      : Real = 0.3;    // e.g. pedestrian torso

        part objectDetector  : DeepLearningDetector;
        part fusionEngine    : MultiModalFusionEngine;
        part tracker         : MultiObjectTracker;
        part freespaceEst    : FreeSpaceEstimator;
        part semanticSeg     : SemanticSegmentationModule;
    }

    // ── Planning ─────────────────────────────────────────────────────────────
    part def PlanningSystem {
        doc /* Route, behaviour, motion planning stack */
        attribute planningHorizon_s    : Real = 8.0;    // seconds look-ahead
        attribute replannRate_Hz       : Real = 10.0;
        attribute trajectoryResolution : Real = 0.1;    // m

        part routePlanner    : GlobalRoutePlanner;
        part behaviourPlanner: BehaviouralPlanner;
        part motionPlanner   : MotionPlanner;
        part predictionMod   : AgentPredictionModule;
        part mapManager      : HDMapManager;
    }

    // ── Vehicle control ──────────────────────────────────────────────────────
    part def VehicleControlSystem {
        doc /* Longitudinal + lateral control; by-wire interface */
        attribute controlLoopRate_Hz   : Real = 100.0;
        attribute latControlAccuracy_m : Real = 0.05;   // cross-track error
        attribute steeringRange_deg    : Real = 540.0;
        attribute brakeResponseTime_ms : Real = 50.0;

        part lateralController  : LateralController;
        part longitudinalCtrl   : LongitudinalController;
        part steerByWire        : SteerByWireActuator;
        part brakeByWire        : BrakeByWireActuator;
        part throttleCtrl       : ThrottleController;
    }

    // ── Safety monitor ───────────────────────────────────────────────────────
    part def SafetyMonitor {
        doc /* ASIL-D safety monitor; min-risk condition arbitration */
        attribute asilLevel            : String = 'ASIL-D';
        attribute watchdogPeriod_ms    : Real = 10.0;
        attribute minRiskCondSpeed_ms  : Real = 0.0;    // full stop MRC
        attribute faultResponseTime_ms : Real = 100.0;

        part systemHealthMon : SystemHealthMonitor;
        part faultArbiter    : FaultArbiter;
        part mrcPlanner      : MinRiskConditionPlanner;
        part watchdog        : HardwareWatchdog;
        part driverAlertMod  : DriverAlertModule;
    }

    // ── Top-level vehicle ────────────────────────────────────────────────────
    part def Level4AutonomousVehicle {
        part lidar         : LidarSubsystem;
        part radar         : RadarSubsystem;
        part cameras       : CameraSubsystem;
        part gnssImu       : GNSSIMUUnit;
        part perception    : PerceptionSystem;
        part planning      : PlanningSystem;
        part control       : VehicleControlSystem;
        part safetyMonitor : SafetyMonitor;
    }

    // ── Requirements ─────────────────────────────────────────────────────────
    requirement def ObjectDetectionRangeReq {
        attribute reqId : String = 'REQ-AV-001';
        attribute text  : String = 'The perception system shall detect a 1.8 m × 0.5 m pedestrian target at a range of not less than 100 m under clear-weather, daylight conditions with probability of detection ≥ 0.999.';
        subject : PerceptionSystem;
    }

    requirement def PerceptionLatencyReq {
        attribute reqId : String = 'REQ-AV-002';
        attribute text  : String = 'End-to-end latency from sensor data acquisition to tracked-object state update in the planning system shall not exceed 100 ms at 95th percentile under maximum scene complexity.';
        subject : PerceptionSystem;
    }

    requirement def SOTIFReq {
        attribute reqId : String = 'REQ-AV-003';
        attribute text  : String = 'The perception and planning system shall comply with ISO 21448 SOTIF: residual risk due to performance limitations and triggering conditions shall be demonstrated as acceptable through systematic hazard analysis and validation testing covering the defined ODD.';
        subject : Level4AutonomousVehicle;
    }

    requirement def SafetyMonitorAsilReq {
        attribute reqId : String = 'REQ-AV-004';
        attribute text  : String = 'The safety monitor shall be developed to ASIL-D per ISO 26262. In the event of a perception or planning system failure, the safety monitor shall initiate a minimum-risk condition within 100 ms of fault detection.';
        subject : SafetyMonitor;
    }

    requirement def ControlAccuracyReq {
        attribute reqId : String = 'REQ-AV-005';
        attribute text  : String = 'Under normal operating conditions, the vehicle control system shall maintain lateral deviation from the planned trajectory of less than 0.1 m RMS and longitudinal speed error of less than 0.5 km/h RMS.';
        subject : VehicleControlSystem;
    }

    requirement def LocalizationReq {
        attribute reqId : String = 'REQ-AV-006';
        attribute text  : String = 'The GNSS/IMU fusion system shall provide absolute vehicle position with CEP ≤ 0.05 m during RTK-fix operation and maintain position error below 1.5 m for at least 30 seconds following total GNSS signal loss.';
        subject : GNSSIMUUnit;
    }
}
