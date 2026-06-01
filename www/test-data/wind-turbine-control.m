% =============================================================================
% OFFSHORE WIND TURBINE CONTROL SYSTEM
% System: Variable-Speed Variable-Pitch (VSVP) Controller
% Platform: 15 MW Offshore HAWT (IEA-15-240-RWT reference turbine)
% Standards: IEC 61400-1 Ed.4, IEC 61400-3, DNV-ST-0438, GL 2012
% =============================================================================
%
% REQ-WTC-001: Rated power tracking within ±2% above rated wind speed
% REQ-WTC-002: Blade pitch actuator response bandwidth >= 1.0 rad/s
% REQ-WTC-003: DEL (fatigue damage equivalent load) reduction >= 15% via IPC
% REQ-WTC-004: Tower-fore-aft damping: add >= 5 dB at 1P frequency
% REQ-WTC-005: Emergency stop: rotor speed to standstill in <= 60 s

%% Turbine Aerodynamic Parameters
P_rated        = 15.0e6;   % [W]    Rated electrical power
D_rotor        = 240.0;    % [m]    Rotor diameter
R_rotor        = D_rotor/2;% [m]    Rotor radius
H_hub          = 150.0;    % [m]    Hub height
N_blades       = 3;
A_swept        = pi * R_rotor^2;  % [m²] Swept area ~45,239 m²

rho_air        = 1.225;    % [kg/m³] Air density (sea level)
Cp_max         = 0.489;    % Max power coefficient
lambda_opt     = 9.0;      % Optimal tip-speed ratio
pitch_opt_deg  = 0.0;      % [deg] Optimal pitch at below-rated

%% Wind Speed Operating Regions
v_cut_in   = 3.0;    % [m/s] Cut-in wind speed
v_rated    = 10.59;  % [m/s] Rated wind speed (IEA-15MW)
v_cut_out  = 25.0;   % [m/s] Cut-out wind speed
v_survival = 70.0;   % [m/s] Extreme wind speed (EWM50)

%% Rotor/Drive Train
omega_rated  = 7.56 * pi/30;  % [rad/s] Rated rotor speed (7.56 RPM)
omega_min    = 5.00 * pi/30;  % [rad/s] Min rotor speed (5 RPM)
omega_max    = 7.56 * pi/30;  % [rad/s] Max rotor speed
I_rotor      = 3.5e8;         % [kg·m²] Rotor + hub inertia
I_gen_ref    = 2.8e5;         % [kg·m²] Generator inertia (LSS equiv)
J_total      = I_rotor + I_gen_ref; % Direct drive, no gearbox
eta_gen      = 0.965;         % Generator efficiency
eta_conv     = 0.980;         % Power converter efficiency

%% Region 2: Below-Rated - MPPT Torque Controller
% Optimal torque: T_gen = K_opt * omega^2
K_opt = 0.5 * rho_air * A_swept * Cp_max * R_rotor^3 / lambda_opt^3;
% At rated: T_rated ~ P_rated / omega_rated
T_rated = P_rated / (omega_rated * eta_gen * eta_conv);

%% Region 3: Above-Rated - Pitch PID Controller
% Pitch controller linearized at rated operating point
Kp_pitch = 0.006275; % [rad/(rad/s)]  Pitch gain
Ki_pitch = 0.000889; % [rad/(rad/s·s)]
Kd_pitch = 0.0;      % Derivative (often filtered)
pitch_rate_max  =  8.0; % [deg/s] Max pitch rate (hydraulic actuator)
pitch_rate_min  = -8.0; % [deg/s] Min pitch rate
pitch_limit_min = -2.0; % [deg] Fine pitch stop
pitch_limit_max = 90.0; % [deg] Feather position

% Gain scheduling (Soren Heier model): linearization at theta_0
pitch_schedule_theta = [0, 5, 10, 15, 20, 25, 30]; % [deg]
gain_corr_factor     = [1.0, 0.73, 0.54, 0.41, 0.32, 0.25, 0.20];
% Linear interp: K_eff = Kp_pitch / gain_corr at operating pitch

%% Individual Pitch Control (IPC) - Fatigue Load Reduction
% Coleman (MBC3) transform for 1P load alleviation
IPC_enabled    = true;
omega_1P       = omega_rated;            % 1P frequency [rad/s]
IPC_Kp         = 3.5e-9;  % [rad/(N·m)] IPC proportional gain
IPC_Ki         = 1.2e-9;  % [rad/(N·m·s)]
M_tilt_limit   = 80e6;    % [N·m] Tilt moment alarm threshold
M_yaw_limit    = 80e6;    % [N·m] Yaw moment alarm threshold
% MBC3 transform angles
MBC_angles = (0:N_blades-1) * 2*pi/N_blades; % [0, 2pi/3, 4pi/3]

%% Tower Fore-Aft Damping (FATD)
FATD_enabled      = true;
omega_tower_FA    = 0.198 * 2*pi; % [rad/s] Tower 1st FA natural freq ~0.198 Hz
zeta_tower_target = 0.05;         % Target damping ratio (from ~1%)
K_FATD            = 2.8e5;        % [N·m/(m/s)] Tower FA velocity feedback gain
tower_acc_filter_fc = 0.20;       % [Hz] Accelerometer high-pass filter

%% Emergency Stop Sequence
runup_rate   = 1.5;    % [deg/s] Normal start pitch-in rate
feather_rate = 8.0;    % [deg/s] Emergency feather rate
brake_torque_Nm = 18e6; % [N·m] Mechanical brake torque (parking)

%% Power Cp-lambda-pitch Table (lookup)
lambda_vec = 2:0.5:15;
pitch_vec  = 0:2:30;   % [deg]
% Cp peak at lambda=9, pitch=0 => 0.489
Cp_peak_check = Cp_max;
TSR_at_v = @(omega, v) omega * R_rotor ./ v;

%% Simulation Initialization
dt_ctrl    = 0.01;  % [s] Control loop sample time (100 Hz)
t_sim      = 600;   % [s] Simulation length
omega_0    = omega_rated * 0.95;
pitch_0    = 0.0;   % [deg]
P_gen_0    = 0.0;

fprintf('Wind Turbine Control System Initialized\n');
fprintf('Turbine: %.0f MW, D=%.0f m, H=%.0f m\n', P_rated/1e6, D_rotor, H_hub);
fprintf('Rated: v=%.2f m/s, omega=%.3f rad/s, T=%.2f MN·m\n', ...
        v_rated, omega_rated, T_rated/1e6);
fprintf('Kopt=%.4e | Kp_pitch=%.6f rad/(rad/s)\n', K_opt, Kp_pitch);
fprintf('IPC: %s | FATD: %s\n', mat2str(IPC_enabled), mat2str(FATD_enabled));
