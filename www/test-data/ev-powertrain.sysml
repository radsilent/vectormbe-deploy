// EV Powertrain — Battery Electric Vehicle Architecture
// Based on public-domain specifications for 100 kWh class BEV platforms
// (Tesla Model S Long Range, Rivian R1T, and Lucid Air engineering references)
//
// Covers: battery pack, traction motor, power electronics, thermal management,
//         charging system, BMS, regenerative braking, and vehicle integration.

package EVPowertrain {

    // ── Quantity imports ─────────────────────────────────────────────────────
    private import ScalarValues::*;

    // ═════════════════════════════════════════════════════════════════════════
    // PART DEFINITIONS
    // ═════════════════════════════════════════════════════════════════════════

    // ── Battery System ───────────────────────────────────────────────────────

    part def BatteryPack {
        doc /* 100 kWh lithium-ion battery pack, 400 V nominal architecture.
               Cell chemistry: NMC-811 / Si-graphite anode.
               Thermal management: liquid-cooled serpentine channels. */

        attribute nominalVoltage : Real = 400.0;          // V
        attribute peakVoltage : Real = 420.0;             // V fully charged
        attribute cutoffVoltage : Real = 280.0;           // V fully discharged
        attribute capacity : Real = 100.0;                // kWh usable
        attribute grossCapacity : Real = 107.0;           // kWh total
        attribute cellCount : Integer = 7104;             // cells (8 modules × 888 cells)
        attribute moduleCount : Integer = 8;
        attribute nominalCellVoltage : Real = 3.7;        // V (NMC-811)
        attribute maxContinuousCurrent : Real = 300.0;    // A discharge
        attribute peakPulseCurrent : Real = 1500.0;       // A (10 s pulse, regen)
        attribute maxChargeCurrent : Real = 200.0;        // A DC fast charge
        attribute internalResistance : Real = 0.060;      // Ω pack-level
        attribute operatingTempMin : Real = -30.0;        // °C
        attribute operatingTempMax : Real = 60.0;         // °C
        attribute optimalTempMin : Real = 15.0;           // °C
        attribute optimalTempMax : Real = 35.0;           // °C
        attribute mass : Real = 544.0;                    // kg
        attribute cycleLifeAt80pct : Integer = 1500;      // cycles to 80% SoH
        attribute cellChemistry : String = "NMC-811-SiC"; // NMC811 / Si-C anode

        part modules : BatteryModule[8];
        part bms : BatteryManagementSystem;
        part thermalPlate : CoolingPlate;
        part packEnclosure : BatteryEnclosure;

        port hvPositive : HVBusPort;
        port hvNegative : HVBusPort;
        port lowVoltageComms : CANBusPort;
        port coolingInlet : CoolantPort;
        port coolingOutlet : CoolantPort;
    }

    part def BatteryModule {
        doc /* 48V nominal sub-module. 888 cells in 74s12p configuration.
               Pouch or cylindrical form factor (21700). */

        attribute nominalVoltage : Real = 44.4;   // V (74s × 0.6V)
        attribute cellsInSeries : Integer = 74;
        attribute cellsInParallel : Integer = 12;
        attribute totalCells : Integer = 888;
        attribute mass : Real = 68.0;             // kg
        attribute capacityAh : Real = 26.0;       // Ah (at 1C rate)

        part cells : BatteryCell[888];
        part moduleController : ModuleBMC;
        port modulePositive : HVBusPort;
        port moduleNegative : HVBusPort;
    }

    part def BatteryCell {
        doc /* 21700-format cylindrical Li-ion cell. NMC-811 cathode, Si-graphite anode. */
        attribute nominalVoltage : Real = 3.7;    // V
        attribute capacity : Real = 5.0;          // Ah (5000 mAh)
        attribute internalResistance : Real = 20; // mΩ at 25°C
        attribute peakCurrent : Real = 20.0;      // A continuous (4C)
        attribute diameter : Real = 21.0;         // mm
        attribute height : Real = 70.0;           // mm
        attribute mass : Real = 68.0;             // g
    }

    part def BatteryManagementSystem {
        doc /* Main BMS — supervises full pack.
               Functions: SOC estimation (EKF), SOH tracking, cell balancing,
               thermal runaway detection, contactor control, isolation monitoring. */

        attribute socEstimationAlgorithm : String = "ExtendedKalmanFilter";
        attribute balancingType : String = "ActivePassiveHybrid";
        attribute balancingCurrentMax : Real = 200.0;    // mA passive bleed
        attribute isolationMonitorMin : Real = 500.0;    // kΩ trip threshold
        attribute updateRateHz : Real = 100.0;
        attribute canBaudRate : Integer = 500000;        // 500 kbaud

        port canBus : CANBusPort;
        port hvInterlock : InterlockPort;
        port thermalSensors : SensorArrayPort;
        port contactorControl : ContactorControlPort;
    }

    part def ModuleBMC {
        doc /* Per-module Battery Monitoring Controller — reports cell voltages and temps to main BMS. */
        attribute cellVoltageResolution : Real = 0.1;   // mV LSB
        attribute tempSensorCount : Integer = 4;
    }

    part def CoolingPlate {
        doc /* Serpentine-channel aluminium cooling plate bonded beneath cell array. */
        attribute material : String = "AluminumAlloy6061";
        attribute channelWidth : Real = 6.0;      // mm
        attribute flowRate : Real = 8.0;          // L/min nominal
        attribute deltaT : Real = 5.0;            // °C max ΔT inlet–outlet
    }

    part def BatteryEnclosure {
        doc /* IP67-rated steel/aluminium enclosure with crash-protection structure. */
        attribute ipRating : String = "IP67";
        attribute material : String = "BoronSteelAluminumComposite";
        attribute mass : Real = 85.0;             // kg structural
    }

    // ── Traction Motor ───────────────────────────────────────────────────────

    part def TractionMotor {
        doc /* Permanent Magnet Synchronous Motor (PMSM) — rear axle primary drive.
               Hairpin winding, 8-pole, oil-spray cooled.
               Reference: comparable to Tesla Plaid rear unit / Lucid AMP drive unit. */

        attribute motorType : String = "PMSM";         // Permanent Magnet Synchronous
        attribute peakPower : Real = 350.0;            // kW
        attribute continuousPower : Real = 220.0;      // kW
        attribute peakTorque : Real = 900.0;           // N·m
        attribute continuousTorque : Real = 420.0;     // N·m
        attribute maxSpeedRpm : Real = 20000.0;        // rpm
        attribute ratedSpeedRpm : Real = 15000.0;      // rpm base speed
        attribute nominalVoltage : Real = 400.0;       // V DC bus
        attribute peakCurrentPhase : Real = 800.0;     // A peak (3-phase)
        attribute polePairs : Integer = 4;             // 8-pole → 4 pole pairs
        attribute efficiency : Real = 0.968;           // peak efficiency at rated point
        attribute massMotor : Real = 70.0;             // kg
        attribute coolingType : String = "OilSpray";
        attribute windingType : String = "Hairpin";
        attribute insulationClass : String = "H";      // 180°C max winding temp

        part rotor : MotorRotor;
        part stator : MotorStator;
        part resolver : AngleResolver;
        part coolingJacket : OilCoolingJacket;

        port phaseU : MotorPhasePort;
        port phaseV : MotorPhasePort;
        port phaseW : MotorPhasePort;
        port driveShaft : MechanicalShaftPort;
        port coolantPort : OilCoolantPort;
        port resolverPort : SensorPort;
    }

    part def MotorRotor {
        doc /* IPM (Interior Permanent Magnet) rotor with NdFeB grade N45SH magnets. */
        attribute magnetMaterial : String = "NdFeBN45SH";
        attribute magnetTemperatureCoeff : Real = -0.10; // %/°C Br degradation
        attribute rotorInertia : Real = 0.018;           // kg·m²
    }

    part def MotorStator {
        doc /* Hairpin-wound copper stator. Laminated silicon steel core. */
        attribute windingType : String = "Hairpin";
        attribute phaseCount : Integer = 3;
        attribute coilResistance : Real = 0.012;         // Ω per phase at 20°C
        attribute coilInductanceDAxis : Real = 0.18;     // mH d-axis
        attribute coilInductanceQAxis : Real = 0.22;     // mH q-axis
    }

    part def AngleResolver {
        doc /* Brushless variable-reluctance resolver for rotor position sensing. */
        attribute resolution : Integer = 4096;          // counts per revolution
        attribute accuracy : Real = 0.05;               // degrees electrical
    }

    part def OilCoolingJacket {
        attribute coolingFluid : String = "ATF_Type4";
        attribute maxFlowRate : Real = 10.0;            // L/min
    }

    // ── Power Electronics (Inverter) ─────────────────────────────────────────

    part def TractionInverter {
        doc /* 3-phase SiC MOSFET inverter. Controls motor via Field-Oriented Control (FOC).
               Silicon Carbide switches enable higher switching frequency and efficiency
               vs. IGBT baseline. Rated for 400V bus, 800A peak phase current. */

        attribute switchingTechnology : String = "SiC-MOSFET";  // Silicon Carbide
        attribute dcBusVoltageNominal : Real = 400.0;    // V
        attribute dcBusVoltageMax : Real = 450.0;        // V
        attribute peakPhaseCurrent : Real = 800.0;       // A
        attribute continuousPhaseCurrent : Real = 450.0; // A
        attribute switchingFrequency : Real = 20000.0;   // Hz (20 kHz)
        attribute efficiency : Real = 0.990;             // peak at rated point
        attribute mass : Real = 12.0;                    // kg
        attribute coolingType : String = "WaterGlycol";
        attribute controlAlgorithm : String = "FieldOrientedControl";  // FOC / MTPA
        attribute deadTime : Real = 0.5;                 // µs switch dead-time

        part powerModule : SiCPowerModule;
        part gateDriver : GateDriverBoard;
        part dcLinkCapacitor : DCLinkCapacitor;
        part controlBoard : InverterControlBoard;
        part currentSensors : CurrentSensorSet;

        port dcBusPositive : HVBusPort;
        port dcBusNegative : HVBusPort;
        port phaseU : MotorPhasePort;
        port phaseV : MotorPhasePort;
        port phaseW : MotorPhasePort;
        port coolantIn : CoolantPort;
        port coolantOut : CoolantPort;
        port canInterface : CANBusPort;
    }

    part def SiCPowerModule {
        doc /* Half-bridge SiC MOSFET module — 1200 V / 450 A per switch. */
        attribute voltageRating : Real = 1200.0;   // V
        attribute currentRating : Real = 450.0;    // A
        attribute rdsOn : Real = 3.5;              // mΩ on-state resistance
        attribute thermalResistance : Real = 0.08; // °C/W junction-to-case
    }

    part def DCLinkCapacitor {
        doc /* Film capacitor bank for DC link voltage ripple filtering. */
        attribute capacitance : Real = 750.0;      // µF
        attribute voltageRating : Real = 500.0;    // V
        attribute esr : Real = 1.5;                // mΩ equivalent series resistance
    }

    part def InverterControlBoard {
        doc /* DSP-based control board running FOC at 20 kHz interrupt rate. */
        attribute processor : String = "TMS320F28388D";
        attribute controlLoopRateHz : Real = 20000.0;
        attribute pwmResolution : Integer = 12;            // bits
    }

    part def GateDriverBoard {
        attribute isolationType : String = "Optocoupler";
        attribute propagationDelay : Real = 100.0;  // ns
    }

    part def CurrentSensorSet {
        attribute sensorType : String = "HallEffect";
        attribute bandwidth : Real = 100000.0;     // Hz
        attribute accuracy : Real = 0.5;           // %
    }

    // ── Onboard Charger (OBC) ────────────────────────────────────────────────

    part def OnboardCharger {
        doc /* 11.5 kW bidirectional AC-DC onboard charger (Level 2 / V2G capable).
               PFC front-end + LLC resonant converter topology. */

        attribute inputVoltage : Real = 240.0;       // V AC single-phase
        attribute inputFrequency : Real = 60.0;      // Hz
        attribute maxPowerAC : Real = 11500.0;       // W (11.5 kW)
        attribute efficiency : Real = 0.944;         // at full load
        attribute powerFactor : Real = 0.99;         // at rated power
        attribute v2gCapable : Boolean = true;       // Vehicle-to-Grid support
        attribute outputVoltageRange : Real = 250.0; // V to 430 V
        attribute maxOutputCurrent : Real = 30.0;    // A DC
        attribute topology : String = "PFC_LLC_Resonant";
        attribute mass : Real = 6.5;                 // kg

        port acInput : ACPowerPort;
        port dcOutput : HVBusPort;
        port pilotSignal : J1772PilotPort;
        port canInterface : CANBusPort;
    }

    part def DCFastChargePort {
        doc /* CCS Combo 2 (Combined Charging System) DC fast charge port.
               Supports up to 250 kW peak at 920 V / 500 A. */

        attribute standard : String = "CCS_Combo2";
        attribute maxPower : Real = 250000.0;        // W (250 kW)
        attribute maxVoltage : Real = 920.0;         // V
        attribute maxCurrent : Real = 500.0;         // A
        attribute communicationProtocol : String = "ISO15118_2";  // PLC

        port hvPositive : HVBusPort;
        port hvNegative : HVBusPort;
        port plcComms : PLCPort;
    }

    // ── High-Voltage Distribution Unit ───────────────────────────────────────

    part def HVDistributionUnit {
        doc /* Junction box distributing HV bus to all HV consumers.
               Contains pre-charge relay, main contactors, HV fuses, shunt resistor. */

        attribute mainContactorCurrent : Real = 500.0;  // A rating
        attribute preChargeResistor : Real = 100.0;     // Ω pre-charge
        attribute mainFuseRating : Real = 400.0;        // A HRC fuse

        part mainPositiveContactor : HVContactor;
        part mainNegativeContactor : HVContactor;
        part preChargeContactor : HVContactor;
        part hvFuse : HVFuse;
        part currentShunt : CurrentShunt;

        port batteryPos : HVBusPort;
        port batteryNeg : HVBusPort;
        port inverterOut : HVBusPort;
        port chargerOut : HVBusPort;
        port dcfcOut : HVBusPort;
        port hvacOut : HVBusPort;
    }

    part def HVContactor {
        attribute coilVoltage : Real = 12.0;            // V operating coil
        attribute continuousCurrentRating : Real = 500.0; // A
        attribute closingTime : Real = 10.0;            // ms
    }

    part def HVFuse {
        attribute rating : Real = 400.0;   // A
        attribute breakCapacity : Real = 50000.0; // A (50 kA)
    }

    part def CurrentShunt {
        attribute resistance : Real = 0.1;  // mΩ
        attribute accuracy : Real = 0.1;    // %
    }

    // ── Thermal Management System ────────────────────────────────────────────

    part def ThermalManagementSystem {
        doc /* Integrated thermal management for battery, motor, and power electronics.
               Uses 50/50 water-glycol coolant. Chiller loop for battery pre-conditioning
               and fast-charge thermal control. */

        attribute coolantType : String = "WaterGlycol50_50";
        attribute systemFlowRate : Real = 20.0;   // L/min
        attribute maxCoolantTemp : Real = 65.0;   // °C

        part hvacCompressor : ElectricCompressor;
        part chillerHeatExchanger : ChillerHX;
        part radiator : LowTempRadiator;
        part coolantPump : ElectricCoolantPump;
        part thermostatValves : ThermostatValveSet;

        port batteryLoop : CoolantPort;
        port motorLoop : CoolantPort;
        port inverterLoop : CoolantPort;
    }

    part def ElectricCompressor {
        doc /* Electric scroll compressor for cabin HVAC and battery chilling. */
        attribute powerConsumption : Real = 5000.0;  // W at max cooling
        attribute refrigerant : String = "R134a";
        attribute coolingCapacity : Real = 6000.0;   // W
    }

    part def ChillerHX {
        attribute heatTransferCoeff : Real = 800.0;  // W/(m²·K)
    }

    part def LowTempRadiator {
        attribute coolingCapacity : Real = 25000.0; // W at 100 km/h airflow
    }

    part def ElectricCoolantPump {
        attribute maxFlowRate : Real = 25.0;         // L/min
        attribute powerConsumption : Real = 300.0;   // W
    }

    part def ThermostatValveSet {
        attribute actuationType : String = "ElectricStepper";
    }

    // ── Reduction Gearbox ────────────────────────────────────────────────────

    part def SingleSpeedGearbox {
        doc /* Single-speed reduction gear — no traditional transmission needed.
               Helical gears, oil-lubricated, integrated with motor housing. */

        attribute gearRatio : Real = 9.73;           // typical BEV reduction
        attribute peakInputTorque : Real = 900.0;    // N·m
        attribute peakOutputTorque : Real = 8760.0;  // N·m (900 × 9.73)
        attribute efficiency : Real = 0.972;
        attribute lubricationType : String = "ForceCirculation_ATF";
        attribute mass : Real = 28.0;                // kg

        port inputShaft : MechanicalShaftPort;
        port outputShaft : MechanicalShaftPort;
        port oilFill : OilFillPort;
    }

    // ── Vehicle Integration ──────────────────────────────────────────────────

    part def EVDriveUnit {
        doc /* Integrated rear drive unit: motor + inverter + single-speed gearbox.
               Structural housing carries all three sub-assemblies. */

        attribute peakSystemPower : Real = 350.0;    // kW
        attribute peakSystemTorque : Real = 8760.0;  // N·m at wheel (pre-CV-joint)
        attribute systemMass : Real = 110.0;         // kg complete unit
        attribute wheelbaseOffset : Real = 0.0;      // mm (centerline mounted)

        part motor : TractionMotor;
        part inverter : TractionInverter;
        part gearbox : SingleSpeedGearbox;

        interface motorToGearbox connect motor.driveShaft to gearbox.inputShaft;

        port hvdc : HVBusPort;
        port driveAxle : AxlePort;
        port coolantIn : CoolantPort;
        port coolantOut : CoolantPort;
        port canBus : CANBusPort;
    }

    part def BEVehicle {
        doc /* Complete battery-electric vehicle top-level integration.
               Dual-motor AWD layout: front + rear drive units. */

        attribute grossVehicleMassRating : Real = 2800.0;  // kg GVWR
        attribute curbMass : Real = 2240.0;                // kg
        attribute peakSystemPower : Real = 670.0;          // kW (dual motor)
        attribute peakSystemTorque : Real = 17520.0;       // N·m at wheels (combined)
        attribute topSpeedKmh : Real = 250.0;
        attribute rangeKm : Real = 560.0;                  // WLTP combined
        attribute dragCoefficient : Real = 0.21;           // Cd
        attribute frontalArea : Real = 2.35;               // m²

        part batteryPack : BatteryPack;
        part rearDriveUnit : EVDriveUnit;
        part frontDriveUnit : EVDriveUnit;
        part hvdu : HVDistributionUnit;
        part obCharger : OnboardCharger;
        part dcfcPort : DCFastChargePort;
        part thermalSystem : ThermalManagementSystem;
        part vehicleController : VehicleControlUnit;

        interface batteryToHVDU connect batteryPack.hvPositive to hvdu.batteryPos;
        interface hvduToRearDrive connect hvdu.inverterOut to rearDriveUnit.hvdc;
        interface hvduToFrontDrive connect hvdu.inverterOut to frontDriveUnit.hvdc;
        interface obcToHVDU connect obCharger.dcOutput to hvdu.chargerOut;
        interface dcfcToHVDU connect dcfcPort.hvPositive to hvdu.dcfcOut;
    }

    part def VehicleControlUnit {
        doc /* Top-level vehicle ECU — arbitrates torque requests, regen, and mode selection. */
        attribute processorType : String = "NXP_S32G3";
        attribute canNetworks : Integer = 4;
        attribute autosarCompliant : Boolean = true;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PORT DEFINITIONS
    // ═════════════════════════════════════════════════════════════════════════

    port def HVBusPort {
        attribute voltage : Real;
        attribute current : Real;
    }

    port def CANBusPort {
        attribute baudRate : Integer;
    }

    port def CoolantPort {
        attribute flowRate : Real;
        attribute temperature : Real;
    }

    port def MotorPhasePort {
        attribute phaseVoltage : Real;
        attribute phaseCurrent : Real;
    }

    port def MechanicalShaftPort {
        attribute torque : Real;
        attribute speed : Real;
    }

    port def ACPowerPort {
        attribute voltage : Real;
        attribute frequency : Real;
        attribute current : Real;
    }

    port def SensorPort { }
    port def InterlockPort { }
    port def ContactorControlPort { }
    port def SensorArrayPort { }
    port def J1772PilotPort { }
    port def PLCPort { }
    port def OilCoolantPort { }
    port def AxlePort { }
    port def OilFillPort { }

    // ═════════════════════════════════════════════════════════════════════════
    // REQUIREMENTS
    // ═════════════════════════════════════════════════════════════════════════

    requirement def BatteryPackSafetyReq {
        doc /* REQ-BAT-001: Battery pack shall withstand SAE J2929 / UN38.3 thermal runaway containment. */
        subject : BatteryPack;
    }

    requirement def MotorEfficiencyReq {
        doc /* REQ-MTR-001: Traction motor peak efficiency shall exceed 96.0% at rated operating point. */
        subject : TractionMotor;
    }

    requirement def SystemRangeReq {
        doc /* REQ-VEH-001: Vehicle shall achieve ≥ 560 km WLTP combined range with 100 kWh usable pack. */
        subject : BEVehicle;
    }

    requirement def ChargingTimeReq {
        doc /* REQ-CHG-001: DC fast charge (10% → 80% SoC) shall complete in ≤ 25 minutes at 250 kW peak. */
        subject : DCFastChargePort;
    }
}
