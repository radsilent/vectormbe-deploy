package 'HighSpeedRailSystem' {
    doc /* High-speed rail trainset system model.
         Alstom Avelia Horizon / Velaro E reference; 16-car formation,
         maximum operating speed 320 km/h, 1000 passengers, 25 kV 50 Hz AC. */

    // ── Value types ──────────────────────────────────────────────────────────
    attribute def KmPerHour { doc /* Speed in km/h */ }
    attribute def Metres    { doc /* Distance in metres */ }
    attribute def Kilonewton { doc /* Force in kN */ }

    // ── Traction system ──────────────────────────────────────────────────────
    part def TractionSystem {
        doc /* Distributed traction; IGBT-based converter per power car */
        attribute installedPower_kW   : Real = 9280.0;   // per power car
        attribute tractionMotors      : Integer = 4;     // per bogie
        attribute motorPower_kW       : Real = 1160.0;   // each
        attribute supplyVoltage_kV    : Real = 25.0;     // 50 Hz AC catenary
        attribute intermediateVoltage : Real = 1500.0;   // DC link V
        attribute maxSpeed_kmh        : Real = 320.0;
        attribute maxAccel_ms2        : Real = 0.52;

        part pantograph     : Pantograph[2];
        part mainTransformer: MainTransformer;
        part tractionConv   : TractionConverter[8];
        part tractionMotor  : TractionMotor[32];
        part auxConverter   : AuxiliaryConverter[4];
    }

    part def BrakingSystem {
        doc /* Blended regenerative + electrodynamic + hydraulic disc brakes */
        attribute emergencyDecel_ms2  : Real = 1.10;     // m/s2 at 320 km/h
        attribute serviceDecel_ms2    : Real = 0.50;
        attribute brakeForce_kN       : Real = 640.0;    // total trainset
        attribute stoppingDist_m      : Real = 6000.0;   // from 320 km/h, emergency
        attribute blendedRatio        : Real = 0.70;     // regen fraction in service

        part discBrakes     : DiscBrakeCaliper[128];     // 2 per axle x 64 axles
        part eddyCurrentBrake: EddyCurrent[16];
        part regenBrakeCtrl : RegenerativeBrakeController;
        part brakeMgmtUnit  : BrakeManagementUnit;
        part wsp             : WheelSlideProtection;
    }

    part def ETCSOnboard {
        doc /* ETCS Level 2 on-board unit; ERTMS Baseline 3 */
        attribute etcsLevel           : Integer = 2;
        attribute baseline            : String = 'BL3-R2';
        attribute maxMonitoredSpeed   : Real = 350.0;   // km/h
        attribute brakeModelAccuracy  : Real = 0.98;    // fraction

        part euRBC         : RadioBlockController;
        part odometer      : TachoOdometer[2];          // redundant
        part juridicalRec  : JuridicalRecorder;
        part dmi           : DriverMachineInterface;
        part antenna       : GSMRAntennaUnit[2];
    }

    part def PassengerSystems {
        doc /* Climate, information, accessibility, catering zones */
        attribute passengerCapacity   : Integer = 1000;
        attribute seatingClasses      : Integer = 2;    // first/standard
        attribute wifiBandwidth_Mbps  : Real = 300.0;   // per car aggregate
        attribute hvacCapacity_kW     : Real = 40.0;    // per car

        part hvac           : HVACUnit[16];
        part passengerInfo  : PassengerInfoDisplay[64]; // per-seat + overhead
        part wifiAP         : WiFiAccessPoint[32];
        part powerOutlets   : SeatPowerOutlet[1000];
        part pis            : PublicAddressSystem;
    }

    part def Crashworthiness {
        doc /* EN 15227 category C-I crashworthiness; anti-climbing, crush zones */
        attribute designSpeed_kmh     : Real = 36.0;    // collision scenario
        attribute deformationZone_mm  : Real = 900.0;   // per end
        attribute peakDecel_g         : Real = 5.0;     // occupant deceleration
        attribute antiClimberForce_kN : Real = 1500.0;

        part crushZone   : CrushZoneStructure[2];       // each end
        part antiClimber : AntiClimberDevice[2];
        part occupantProt: OccupantProtectionSystem;
        part endWall     : ReinforcedEndWall[2];
    }

    part def TrainManagementSystem {
        doc /* Distributed TMS; diagnostics, traction/brake coordination */
        attribute networkBus          : String = 'WTB/MVB';
        attribute diagnosticItems     : Integer = 4800;
        attribute mtbf_hours          : Real = 150000.0;

        part centralUnit    : TMSCentralUnit;
        part vehicleUnit    : TMSVehicleUnit[16];
        part wtbGateway     : WTBGateway[2];
        part eventRecorder  : EventDataRecorder;
    }

    // ── Top-level trainset ───────────────────────────────────────────────────
    part def HighSpeedTrainset {
        part traction       : TractionSystem;
        part braking        : BrakingSystem;
        part etcs           : ETCSOnboard;
        part passenger      : PassengerSystems;
        part crashworthiness: Crashworthiness;
        part tms            : TrainManagementSystem;
    }

    // ── Requirements ─────────────────────────────────────────────────────────
    requirement def MaxSpeedReq {
        attribute reqId : String = 'REQ-HSR-001';
        attribute text  : String = 'The trainset shall achieve a maximum operating speed of 320 km/h on level, straight track with 25 kV 50 Hz catenary supply.';
        subject : TractionSystem;
    }

    requirement def StoppingDistanceReq {
        attribute reqId : String = 'REQ-HSR-002';
        attribute text  : String = 'In emergency braking from 320 km/h on dry, level track, the trainset shall come to a complete stop within 6000 m.';
        subject : BrakingSystem;
    }

    requirement def ETCSInteropReq {
        attribute reqId : String = 'REQ-HSR-003';
        attribute text  : String = 'The ETCS on-board unit shall comply with ERTMS/ETCS Baseline 3 Release 2 and shall be interoperable on all ERA-compliant corridors.';
        subject : ETCSOnboard;
    }

    requirement def AvailabilityReq {
        attribute reqId : String = 'REQ-HSR-004';
        attribute text  : String = 'The trainset shall achieve a commercial availability of not less than 98.5%, calculated as percentage of scheduled revenue kilometres operated without cancellation due to trainset failure, averaged over 12 months.';
        subject : HighSpeedTrainset;
    }

    requirement def CrashworthinessReq {
        attribute reqId : String = 'REQ-HSR-005';
        attribute text  : String = 'The trainset structure shall meet EN 15227 category C-I: withstand a 36 km/h collision against an identical unit with energy absorption not less than 5 MJ and peak mean deceleration not exceeding 5 g in the occupied zone.';
        subject : Crashworthiness;
    }

    requirement def PassengerComfortReq {
        attribute reqId : String = 'REQ-HSR-006';
        attribute text  : String = 'In-vehicle pressure variations due to tunnel entry shall not exceed 1 kPa/s, and interior noise shall not exceed 67 dB(A) at 300 km/h.';
        subject : PassengerSystems;
    }
}
