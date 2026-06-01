% =============================================================================
% HIGH-SPEED RAIL TRACTION AND BRAKING CONTROL SYSTEM
% System: EMU Traction Control Unit (TCU)
% Platform: HSR EMU 350 km/h (Shinkansen N700S class)
% Standards: EN 50126, EN 50128, IEC 61375, UIC 544-1
% =============================================================================
%
% REQ-TCU-001: Acceleration 0->300 km/h in <= 360 s with full passenger load
% REQ-TCU-002: Emergency braking deceleration >= 1.06 m/s² (UIC 544-1 Cat B)
% REQ-TCU-003: Wheel slip/slide control response time <= 50 ms
% REQ-TCU-004: Regenerative braking energy recovery >= 30% on commuter cycle
% REQ-TCU-005: Speed hold accuracy ±0.5 km/h in ATO mode

%% Train Consist Parameters
M_train       = 708000;   % [kg]  Total train mass (16-car, AW3)
M_rotating    = 42000;    % [kg]  Equivalent rotating mass
M_eff         = M_train + M_rotating;
L_train       = 405.0;    % [m]   Train length
N_motor_cars  = 14;       % Number of motored cars
N_axles_total = 64;       % Total axles
N_motor_axles = 56;       % Motored axles
v_max         = 360/3.6;  % [m/s] Max operating speed
v_max_design  = 400/3.6;  % [m/s] Design speed

%% Traction Motor Parameters (PMSM per axle)
P_motor_cont  = 305e3;    % [W]   Continuous motor power per axle
P_motor_peak  = 380e3;    % [W]   Peak motor power (90s rating)
T_motor_max   = 2050;     % [N·m] Peak motor torque
omega_base    = 157;      % [rad/s] Base speed (field weakening onset ~1500 rpm)
omega_max     = 785;      % [rad/s] Max electrical speed
I_motor_rated = 480;      % [A]   Rated motor current (RMS)
gear_ratio    = 2.719;    % Gearbox ratio
wheel_dia     = 0.860;    % [m]   Nominal wheel diameter (new)
wheel_dia_worn= 0.790;    % [m]   Worn wheel diameter
R_wheel       = wheel_dia / 2;

P_total_cont  = P_motor_cont * N_motor_axles; % ~17.1 MW total continuous

%% Traction Force Curve vs Speed [km/h -> N]
v_curve_kmh   = [0,   50,  100, 150, 200, 250, 300, 350, 360];
F_traction_kN = [420, 420, 380, 285, 214, 171, 143, 122, 116]; % [kN] total train

%% Davis Equation Coefficients (running resistance)
% R = A + B*v + C*v^2 [N], v in m/s
A_davis = 6850;     % [N]   Rolling resistance (constant)
B_davis = 180;      % [N/(m/s)] Speed-proportional term
C_davis = 6.40;     % [N/(m/s)^2] Aerodynamic drag coefficient
% At 350 km/h: R ≈ 6850 + 180*97.2 + 6.40*97.2^2 ≈ 83 kN

%% Slip/Slide Control (SSC/WSP)
mu_max_dry     = 0.30;  % Max adhesion coefficient (dry rail)
mu_max_wet     = 0.16;  % Max adhesion coefficient (wet rail)
mu_max_leaf    = 0.05;  % Contaminated (leaves on rail)
slip_threshold = 0.10;  % Relative slip threshold for intervention (10%)
ramp_down_rate = 50e3;  % [N/s] Force ramp-down rate on slip detection
ramp_up_rate   = 20e3;  % [N/s] Force ramp-up rate (re-adhesion)
SSC_period_ms  = 20;    % [ms] SSC control loop period

%% Regenerative Braking
% Blending curve: regen priority, friction brake supplement
v_regen_max    = 350/3.6; % [m/s] Regen available up to 350 km/h
v_regen_min    = 5/3.6;   % [m/s] Regen cut-off speed
F_regen_max_kN = 280;     % [kN] Max regenerative braking force (total train)
eta_regen      = 0.88;    % Regeneration efficiency (motor + inverter)
E_regen_ratio  = 0.32;    % Energy recuperation fraction (UIC cycle)

%% Braking Rates
a_service_max = 1.10;   % [m/s²] Max service deceleration
a_emergency   = 1.29;   % [m/s²] Emergency braking rate (UIC Cat B+ 360 km/h)
a_regen_only  = 0.55;   % [m/s²] Regen-only braking contribution

%% Speed Profile - Reference ATO Run
% Station spacing 50 km, 350 km/h cruise
t_accel     = 360;      % [s] Acceleration phase 0->350 km/h
t_coast     = 180;      % [s] Coasting phase
t_brake     = 120;      % [s] Braking phase 350->0 km/h
v_cruise    = 350/3.6;  % [m/s]

%% PID Speed Controller (ATO mode)
Kp_ato =  2800;  % [N/(m/s)] Speed error proportional gain
Ki_ato =   150;  % [N/(m/s·s)]
Kd_ato =   800;  % [N·s/(m/s)]
anti_windup_limit = F_traction_kN(1) * 1e3; % Anti-windup clamp [N]

%% Energy Model
E_consumed_kWh   = P_total_cont * t_accel / 3.6e6; % Approx accel energy
E_recovered_kWh  = E_consumed_kWh * E_regen_ratio * eta_regen;

fprintf('Traction Control System Initialized\n');
fprintf('Train: %.0f t, %d motored axles, %.0f kW continuous\n', ...
        M_train/1e3, N_motor_axles, P_total_cont/1e3);
fprintf('Vmax: %.0f km/h | F_trac peak: %.0f kN\n', v_max*3.6, F_traction_kN(1));
fprintf('Regen efficiency: %.0f%% | Recovery fraction: %.0f%%\n', ...
        eta_regen*100, E_regen_ratio*100);
