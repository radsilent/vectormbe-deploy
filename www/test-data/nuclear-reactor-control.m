% =============================================================================
% NUCLEAR REACTOR POWER CONTROLLER
% System: PWR Reactor Control System (RCS)
% Subsystem: Rod Control and Monitoring System (RCMS)
% Standard: IEEE Std 7-4.3.2, IEEE Std 603, 10 CFR 50 Appendix A
% =============================================================================
%
% REQ-RCS-001: Reactor power shall be maintained within ±2% of setpoint
% REQ-RCS-002: Control rod insertion time < 2.2 s (scram) per GDC-17
% REQ-RCS-003: Steady-state coolant temperature deviation < 1.5 °C
% REQ-RCS-004: Xenon override capability up to 5% delta-k/k
% REQ-RCS-005: Auto-load follow 100%->50%->100% rated power in 30 min

%% System Parameters - Primary Loop
P_rated       = 3411e6;   % [W]   Rated thermal power (Westinghouse AP1000)
T_coolant_in  = 280.7;    % [°C]  Cold leg temperature
T_coolant_out = 325.5;    % [°C]  Hot leg temperature
P_primary     = 15.51e6;  % [Pa]  Primary system pressure
m_dot_primary = 4.6e3;    % [kg/s] Primary coolant mass flow rate
cp_water      = 5.2e3;    % [J/(kg·K)] Specific heat at operating conditions
T_fuel_cl     = 1483;     % [°C]  Peak fuel centerline temperature limit
T_clad_surf   = 343;      % [°C]  Max cladding surface temperature

%% PID Controller Gains - Power Controller
Kp_power =  0.85;   % Proportional gain [%rod/%power_error]
Ki_power =  0.12;   % Integral gain     [%rod/(%power_error·s)]
Kd_power =  0.04;   % Derivative gain   [%rod·s/%power_error]
power_setpoint = 100.0;  % [%] Rated power setpoint

%% PID Controller Gains - Temperature Controller (secondary)
Kp_temp =  1.20;
Ki_temp =  0.08;
Kd_temp =  0.10;
T_avg_setpoint = 303.1;  % [°C] Average coolant temperature setpoint

%% Xenon Reactivity Model (Iodine-Xenon dynamics)
sigma_Xe   = 2.65e-18; % [cm²] Xe-135 absorption cross section
gamma_I    = 0.061;    % Iodine fission yield
gamma_Xe   = 0.003;    % Direct Xenon fission yield
lambda_I   = 2.87e-5;  % [1/s] I-135 decay constant
lambda_Xe  = 2.09e-5;  % [1/s] Xe-135 decay constant
phi_0      = 3.2e13;   % [n/cm²/s] Nominal flux
rho_xe_max = -0.028;   % [delta-k/k] Peak xenon worth (poison)

% Xenon transient ODE (simplified two-equation model)
% dI/dt  = gamma_I * Sigma_f * phi - lambda_I * I
% dXe/dt = gamma_Xe * Sigma_f * phi + lambda_I * I - (lambda_Xe + sigma_Xe*phi)*Xe

%% Control Rod Worth Curves (4-bank CEA model)
% Bank D (regulating bank): 0-228 steps, worth curve [steps, %delta-k/k]
rod_steps   = [0, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 228];
rod_worth_D = [0, 0.08, 0.22, 0.42, 0.72, 1.10, 1.48, 1.78, 1.98, 2.10, 2.16, 2.20];
rod_worth_A = 2.85;   % [%dk/k] Bank A total integral worth
rod_worth_B = 3.10;   % [%dk/k] Bank B total integral worth
rod_worth_C = 2.60;   % [%dk/k] Bank C total integral worth
rod_speed_normal = 8; % [steps/min] Normal rod motion speed
rod_speed_fast   = 72;% [steps/min] Boration / fast insertion

%% Thermal-Hydraulic Safety Setpoints
DNBR_limit     = 1.30;   % Minimum departure from nucleate boiling ratio
P_high_trip    = 17.0e6; % [Pa]  High pressure trip setpoint
P_low_trip     = 13.8e6; % [Pa]  Low pressure trip setpoint
T_hot_trip     = 343.3;  % [°C]  High Tavg trip
overpower_trip = 118;    % [%]   Overpower delta-T trip
flux_rate_trip = 5.0;    % [%/s] High flux rate trip

%% Point Kinetics Model - Six Delayed Neutron Groups (U-235)
beta_i      = [0.000215, 0.001424, 0.001274, 0.002568, 0.000748, 0.000273];
lambda_dn_i = [0.0124,   0.0305,   0.111,    0.301,    1.14,     3.01];  % [1/s]
beta_eff    = sum(beta_i);   % ~0.00650 (650 pcm)
Lambda_prompt = 2.1e-5;      % [s] Prompt neutron lifetime

%% Simulation Setup
dt   = 0.05;      % [s]  Integration time step
t_end= 600;       % [s]  Simulation duration (10 min transient)
t    = 0:dt:t_end;
n    = length(t);

power     = zeros(1,n); power(1) = power_setpoint;
rho       = zeros(1,n);
rod_pos   = zeros(1,n); rod_pos(1) = 180; % initial bank D position [steps]
T_avg     = zeros(1,n); T_avg(1)   = T_avg_setpoint;

% Step load demand at t=60s: 100% -> 75%
load_demand = power_setpoint * ones(1,n);
load_demand(t >= 60) = 75.0;

fprintf('Nuclear Reactor Control Simulation initialized.\n');
fprintf('Rated Power: %.0f MWth | Coolant Tin/Tout: %.1f/%.1f C\n', ...
        P_rated/1e6, T_coolant_in, T_coolant_out);
fprintf('PID (Kp/Ki/Kd): %.2f / %.2f / %.2f\n', Kp_power, Ki_power, Kd_power);
fprintf('Beta_eff: %.0f pcm | Prompt lifetime: %.1e s\n', beta_eff*1e5, Lambda_prompt);
