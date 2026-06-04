% =============================================================================
% COMMERCIAL AIRCRAFT FLIGHT CONTROL SYSTEM
% System: Full-Authority Digital Flight Control (FBW + AFCS)
% Platform: Narrow-body commercial transport (A320 / B737 class)
% Standards: DO-178C (DAL A), ARP 4754A, CS-25, FAR Part 25
% =============================================================================
%
% REQ-FCS-001: Pitch rate response bandwidth >= 2.5 rad/s (phugoid damped)
% REQ-FCS-002: Roll rate response bandwidth >= 3.5 rad/s
% REQ-FCS-003: Control surface actuator rate limit  >= 40 deg/s (elevator)
% REQ-FCS-004: AFCS engaged altitude hold error <= ±50 ft (1-sigma)
% REQ-FCS-005: Runway tracking accuracy (ILS CAT III) <= 0.2 m lateral (1-sigma)
% REQ-FCS-006: Control law computation latency <= 10 ms (hard real-time)
% REQ-FCS-007: Fault detection and isolation (FDI) reaction time <= 50 ms
% REQ-FCS-008: Load factor limiting 2.5 g to -1 g (normal category envelope)

%% Aircraft Aerodynamic Parameters  (narrow-body twin-jet, MTOW 79,000 kg)
m           = 79000;            % [kg]   Maximum take-off weight
W           = m * 9.80665;     % [N]    Weight at MTOW
b           = 34.1;            % [m]    Wing span
S_ref       = 122.6;           % [m²]  Wing reference area
c_bar       = 4.20;            % [m]    Mean aerodynamic chord
AR          = b^2 / S_ref;     % [-]    Aspect ratio
e           = 0.82;            % [-]    Oswald efficiency
I_xx        = 2.98e6;          % [kg·m²] Roll moment of inertia
I_yy        = 4.37e6;          % [kg·m²] Pitch moment of inertia
I_zz        = 7.10e6;          % [kg·m²] Yaw moment of inertia
I_xz        = 1.80e5;          % [kg·m²] Product of inertia (roll-yaw)

%% Atmospheric / Flight Condition (cruise at FL370, ISA)
h_cruise_ft = 37000;            % [ft]   Cruise altitude
h_cruise    = h_cruise_ft * 0.3048;  % [m]
T_isa       = 216.65;           % [K]   ISA temperature at FL370
rho         = 0.3639;           % [kg/m³] Air density at FL370 ISA
a_sound     = sqrt(1.4 * 287 * T_isa);  % [m/s] Speed of sound
M_cruise    = 0.78;             % [-]   Design cruise Mach
V_TAS       = M_cruise * a_sound;       % [m/s] True airspeed
V_EAS       = V_TAS * sqrt(rho / 1.225); % [m/s] Equivalent airspeed
q_bar       = 0.5 * rho * V_TAS^2;     % [Pa]  Dynamic pressure

%% Lift / Drag Polars (clean configuration)
CL_alpha    = 5.62;             % [/rad]  Lift curve slope (3D)
CL_0        = 0.22;             % [-]     Zero-alpha lift coefficient
CL_cruise   = W / (q_bar * S_ref);  % [-]  Required cruise lift coefficient
alpha_cruise = (CL_cruise - CL_0) / CL_alpha;  % [rad]  Trim angle of attack
alpha_cruise_deg = alpha_cruise * 180/pi;

CD_0        = 0.0175;           % [-]   Zero-lift drag (clean)
k           = 1 / (pi * AR * e);% [-]   Induced drag factor
CD_cruise   = CD_0 + k * CL_cruise^2;  % [-]
LD_cruise   = CL_cruise / CD_cruise;    % [-]  Lift-to-drag ratio

%% Engine Model  (2× CFM56-class, 120 kN SL thrust each)
T_sl_each   = 120e3;            % [N]   Sea-level thrust per engine
T_sl_total  = 2 * T_sl_each;   % [N]   Total sea-level thrust
BPR         = 6.5;              % [-]   Bypass ratio
sfc_cruise  = 15.5e-6;         % [kg/(N·s)]  TSFC at cruise (Eurojet data)
T_cruise    = W / LD_cruise;    % [N]   Required cruise thrust
fuel_burn_kgs = sfc_cruise * T_cruise;  % [kg/s]  Cruise fuel flow (total)
fuel_burn_kgh = fuel_burn_kgs * 3600;   % [kg/h]

fprintf('--- Cruise Trim ---\n');
fprintf('  V_TAS       = %.1f m/s  (M = %.3f)\n', V_TAS, M_cruise);
fprintf('  alpha_trim  = %.3f deg\n', alpha_cruise_deg);
fprintf('  CL_cruise   = %.4f\n', CL_cruise);
fprintf('  L/D         = %.2f\n', LD_cruise);
fprintf('  Fuel flow   = %.1f kg/h\n', fuel_burn_kgh);

%% Longitudinal Stability Derivatives  (cruise, Mach 0.78, CG = 28%% MAC)
% Dimensioned with dynamic pressure, reference chord/span, total velocity
Cmu         = -1.32;            % [/rad]  Pitching moment vs AoA (static stability)
Cm_alpha    = Cmu;
Cm_q        = -18.5;            % [-]     Pitch damping
Cm_alpha_dot= -7.2;             % [-]     Pitch rate derivative
Cm_de       = -1.58;            % [/rad]  Elevator effectiveness
Cz_alpha    = -CL_alpha;        % [/rad]  Normal force vs AoA (sign conv.)
Cz_q        = -2 * CL_alpha * 0.5;   % [-]
Cz_de       = -0.42;            % [/rad]  Elevator contribution to normal force
Cx_alpha    = 0.12;             % [/rad]  Axial force vs AoA

%% Lateral-Directional Derivatives
Cl_beta     = -0.098;           % [/rad]  Dihedral effect (roll due to sideslip)
Cl_p        = -0.485;           % [-]     Roll damping
Cl_r        = 0.098;            % [-]     Roll due to yaw rate
Cl_da       = 0.228;            % [/rad]  Aileron roll authority
Cl_dr       = 0.012;            % [/rad]  Rudder roll coupling
Cn_beta     = 0.072;            % [/rad]  Weathercock stability
Cn_p        = -0.026;           % [-]     Yaw due to roll rate
Cn_r        = -0.086;           % [-]     Yaw damping
Cn_da       = 0.006;            % [/rad]  Adverse yaw from ailerons
Cn_dr       = -0.088;           % [/rad]  Rudder yaw authority
CY_beta     = -0.88;            % [/rad]  Side force due to sideslip

%% Pitch-Axis Linearised State-Space Model (short-period approximation)
% States: [alpha (rad), q (rad/s)]
% Input:  elevator deflection delta_e (rad)
% Operating point: cruise, W = 79,000 kg

q_ref   = q_bar;
Mw_ref  = q_ref * S_ref * c_bar / (2 * V_TAS * I_yy) * Cm_alpha;
Mq_ref  = q_ref * S_ref * c_bar^2 / (2 * V_TAS * I_yy) * Cm_q;
Zw_ref  = q_ref * S_ref / (m * V_TAS) * Cz_alpha;
Zdot    = q_ref * S_ref * c_bar / (2 * V_TAS^2 * I_yy) * Cm_alpha_dot;
Me_ref  = q_ref * S_ref * c_bar / I_yy * Cm_de;
Ze_ref  = q_ref * S_ref / m * Cz_de;

A_long = [Zw_ref,          1;
          Mw_ref + Zdot*Mq_ref,  Mq_ref];
B_long = [Ze_ref;
          Me_ref + Zdot*Ze_ref];
C_long = eye(2);
D_long = zeros(2,1);

sys_long = ss(A_long, B_long, C_long, D_long);
eig_long = eig(A_long);
fprintf('\n--- Short-Period Eigenvalues ---\n');
fprintf('  SP λ1 = %.4f + %.4fi\n', real(eig_long(1)), imag(eig_long(1)));
fprintf('  SP λ2 = %.4f + %.4fi\n', real(eig_long(2)), imag(eig_long(2)));

% Short-period natural frequency and damping
omega_sp   = abs(eig_long(1));         % [rad/s]
zeta_sp    = -real(eig_long(1)) / omega_sp;
fprintf('  ω_sp = %.3f rad/s   ζ_sp = %.3f\n', omega_sp, zeta_sp);

%% Lateral-Directional State-Space Model
% States: [beta (rad), p (rad/s), r (rad/s), phi (rad)]
% Inputs: [delta_a (rad), delta_r (rad)]

g   = 9.80665;
V   = V_TAS;

Yb  = q_bar * S_ref / m * CY_beta;
Yp  = 0;
Yr  = 0;
Lb  = q_bar * S_ref * b / I_xx * Cl_beta;
Lp  = q_bar * S_ref * b^2 / (2*V*I_xx) * Cl_p;
Lr  = q_bar * S_ref * b^2 / (2*V*I_xx) * Cl_r;
Nb  = q_bar * S_ref * b / I_zz * Cn_beta;
Np  = q_bar * S_ref * b^2 / (2*V*I_zz) * Cn_p;
Nr  = q_bar * S_ref * b^2 / (2*V*I_zz) * Cn_r;

La  = q_bar * S_ref * b / I_xx * Cl_da;
Lr2 = q_bar * S_ref * b / I_xx * Cl_dr;
Na  = q_bar * S_ref * b / I_zz * Cn_da;
Nr2 = q_bar * S_ref * b / I_zz * Cn_dr;
Ya  = 0;
Yr2 = q_bar * S_ref / m * 0.18;

A_lat = [Yb/V,   Yp/V,  (Yr/V - 1),  g*cos(0)/V;
         Lb,     Lp,    Lr,            0;
         Nb,     Np,    Nr,            0;
         0,      1,     tan(0),        0];
B_lat = [Ya/V,   Yr2/V;
         La,     Lr2;
         Na,     Nr2;
         0,      0];

eig_lat = eig(A_lat);
fprintf('\n--- Lateral-Directional Eigenvalues ---\n');
for k = 1:length(eig_lat)
    fprintf('  λ%d = %.4f + %.4fi\n', k, real(eig_lat(k)), imag(eig_lat(k)));
end

%% Fly-by-Wire Control Laws  (Normal Law — pitch axis)
% Pitch rate command with C* criterion blending
% C* = nz + (V_cross / g) * q   where V_cross = 95 m/s (~ 185 KEAS)
V_cross = 95;                   % [m/s]  C* crossover speed
Kq      = 1.0;                  % Pitch rate feedback gain
Knz     = 1.0;                  % Load factor feedback gain

% PID pitch rate controller (inner loop, 50 Hz)
Kp_q    = 0.065;                % Proportional gain
Ki_q    = 0.018;                % Integral gain
Kd_q    = 0.004;                % Derivative gain (filtered, τ = 0.05 s)
de_max  = 25 * pi/180;          % [rad]  Elevator max deflection ±25°
de_rate = 40 * pi/180;          % [rad/s] Elevator max rate ±40°/s

% Load factor protection limits
nz_max  =  2.5;                 % [g]   Max positive load factor
nz_min  = -1.0;                 % [g]   Min negative load factor
phi_bank_max = 67 * pi/180;     % [rad] Max bank angle (normal law)

%% Roll Control Law  (lateral axis, 50 Hz)
Kp_roll  = 0.55;                % Roll rate proportional gain
Ki_roll  = 0.08;                % Roll rate integral gain
Kff_roll = 0.30;                % Roll angle feedforward
da_max   = 25 * pi/180;         % [rad]  Aileron max ±25°
da_rate  = 50 * pi/180;         % [rad/s] Aileron rate ±50°/s

%% Yaw Damper  (Dutch-roll suppression, 80 Hz)
Kyd      = 0.18;                % Yaw rate to rudder gain
omega_n_yd = 4.0;              % [rad/s] Yaw damper filter bandwidth
zeta_yd  = 0.70;               % [-]    Yaw damper filter damping
dr_yd_max = 8 * pi/180;        % [rad]  Yaw damper rudder authority ±8°

%% Autopilot Modes

% ── Altitude Hold ──────────────────────────────────────────────────────────
Kp_alt   = 0.012;               % [m/s per m error]  Altitude error → VS demand
Ki_alt   = 0.0015;
VS_max   = 4.0;                 % [m/s] Maximum VS demand from alt hold
VS_min   = -3.0;                % [m/s]

% ── Vertical Speed Hold ────────────────────────────────────────────────────
Kp_vs    = 0.030;               % [°pitch per m/s VS error]
Ki_vs    = 0.004;
theta_vs_max = 12 * pi/180;    % [rad]  Max pitch demand ±12°

% ── Indicated Airspeed Hold (autothrottle) ────────────────────────────────
Kp_ias   = 0.045;               % [N per kt error]
Ki_ias   = 0.008;
Kd_ias   = 0.002;
N1_max   = 99.0;               % [%%]   Max N1 command
N1_idle  = 25.0;               % [%%]   Ground idle N1

% ── Heading Select ─────────────────────────────────────────────────────────
Kp_hdg   = 0.018;              % [rad/s roll rate per degree heading error]
phi_hdg_max = 25 * pi/180;    % [rad]  Max bank in heading select

% ── ILS CAT III Autoland ───────────────────────────────────────────────────
% Localiser track (100 Hz update from ILS receiver)
Kp_loc   = 0.040;              % [m/s lateral demand per dot deflection]
Ki_loc   = 0.006;
Kd_loc   = 0.002;
loc_capt_range = 18e3;         % [m]   LOC capture range

% Glideslope track
Kp_gs    = 0.055;              % [m/s VS demand per dot deflection]
Ki_gs    = 0.008;
gs_capt_alt  = 1200 * 0.3048; % [m]   GS capture altitude (~1200 ft AGL)

% Flare / Rollout
h_flare  = 50 * 0.3048;       % [m]   Flare initiation height
tau_flare= 6.0;               % [s]   Flare time constant (exponential)
theta_touchdown = -2.5 * pi/180; % [rad] Target pitch at main gear touchdown

%% Actuator Models  (second-order with rate and position limits)
% Elevator actuator
omega_act_e = 30;               % [rad/s] Actuator bandwidth
zeta_act_e  = 0.71;             % Actuator damping ratio
s           = tf('s');
G_act_e     = omega_act_e^2 / (s^2 + 2*zeta_act_e*omega_act_e*s + omega_act_e^2);

% Aileron actuator
omega_act_a = 35;
zeta_act_a  = 0.70;
G_act_a     = omega_act_a^2 / (s^2 + 2*zeta_act_a*omega_act_a*s + omega_act_a^2);

% Rudder actuator
omega_act_r = 25;
zeta_act_r  = 0.72;
G_act_r     = omega_act_r^2 / (s^2 + 2*zeta_act_r*omega_act_r*s + omega_act_r^2);

%% Sensor Models
% Air data (pitot-static): 50 Hz, 1-sigma errors
sigma_V_eas   = 0.5;            % [kt]  Airspeed error (IAS)
sigma_alt     = 15;             % [ft]  Altitude error (encoder)
sigma_V_mach  = 0.002;          % [-]   Mach error

% Inertial Reference System (IRS): 200 Hz
sigma_phi     = 0.1 * pi/180;  % [rad]  Roll angle error
sigma_theta   = 0.05 * pi/180; % [rad]  Pitch angle error
sigma_psi     = 0.2 * pi/180;  % [rad]  Heading error
sigma_p       = 0.01 * pi/180; % [rad/s] Roll rate error
sigma_q       = 0.01 * pi/180; % [rad/s] Pitch rate error
sigma_r       = 0.01 * pi/180; % [rad/s] Yaw rate error
sigma_nz      = 0.005;          % [g]    Load factor error (accelerometer)

% GPS (SBAS augmented): 10 Hz
sigma_pos_h   = 1.5;            % [m]   Horizontal position (95%%)
sigma_pos_v   = 2.0;            % [m]   Vertical position (95%%)

%% Fault Detection and Isolation (FDI) — Triple-Channel Voting
n_channels    = 3;              % Triplex architecture (pitch + roll primary)
threshold_3V2 = 0.5 * pi/180;  % [rad]  3V2 voter threshold (hard)
threshold_mon = 0.3 * pi/180;  % [rad]  Monitor disagreement limit
tau_fdi       = 0.050;          % [s]    FDI reaction time (REQ-FCS-007)
disagree_latch_cycles = ceil(tau_fdi * 1000);  % Latching counter at 1 kHz

%% Simulation Parameters
dt          = 0.01;             % [s]   Base simulation time step (100 Hz)
t_end       = 120;              % [s]   Simulation duration
t           = 0:dt:t_end;
N_samples   = length(t);

%% Step Response Analysis — Pitch Axis
fprintf('\n--- Pitch-axis Step Response (1° pitch rate demand) ---\n');
q_cmd_step = 1 * pi/180;        % [rad/s] Step pitch rate command

% Closed-loop pitch axis (simplified PID around short-period plant)
G_plant_q = tf([B_long(2)], [1, -A_long(2,2)]);   % q/de transfer function
G_pid_q   = pid(Kp_q, Ki_q, Kd_q, 0.05);           % PID with derivative filter τ=0.05
G_cl_q    = feedback(G_pid_q * G_act_e * G_plant_q, 1);
[y_q, t_q] = step(G_cl_q * q_cmd_step, t_end);

% Rise time, settling time, overshoot
y_q_norm = y_q / max(abs(y_q));
idx_90   = find(y_q_norm >= 0.90, 1, 'first');
idx_10   = find(y_q_norm >= 0.10, 1, 'first');
t_rise   = t_q(idx_90) - t_q(idx_10);
overshoot_pct = max(0, (max(y_q_norm) - 1) * 100);
fprintf('  Rise time     = %.3f s\n', t_rise);
fprintf('  Overshoot     = %.1f %%\n', overshoot_pct);

%% Gain / Phase Margin  (open-loop Bode)
L_q   = G_pid_q * G_act_e * G_plant_q;
[gm_q, pm_q, wpc_q, wgc_q] = margin(L_q);
fprintf('\n--- Pitch Loop Gain & Phase Margin ---\n');
fprintf('  Gain margin   = %.2f dB  (at %.3f rad/s)\n', 20*log10(gm_q), wpc_q);
fprintf('  Phase margin  = %.1f deg (at %.3f rad/s)\n', pm_q, wgc_q);

%% Dutch Roll Mode Analysis
eig_lat_sorted = sort(eig_lat, 'imag');
dr_idx = find(imag(eig_lat_sorted) > 0.1, 1, 'first');
if ~isempty(dr_idx)
    omega_dr = abs(eig_lat_sorted(dr_idx));
    zeta_dr  = -real(eig_lat_sorted(dr_idx)) / omega_dr;
    fprintf('\n--- Dutch Roll Mode ---\n');
    fprintf('  ω_dr = %.3f rad/s   ζ_dr = %.3f', omega_dr, zeta_dr);
    if zeta_dr >= 0.08
        fprintf('  [PASS CS-25.181]\n');
    else
        fprintf('  [FAIL CS-25.181 — ζ_dr min 0.08]\n');
    end
end

%% Breguet Range Equation
fuel_mass_kg = 20500;           % [kg]  Max usable fuel (narrow-body)
R_breguet = (V_TAS / (g * sfc_cruise)) * LD_cruise * log(1 + fuel_mass_kg / (m - fuel_mass_kg));
R_breguet_nm = R_breguet / 1852;
fprintf('\n--- Breguet Range Estimate ---\n');
fprintf('  Range = %.0f nm  (%.0f km)\n', R_breguet_nm, R_breguet/1000);

fprintf('\n--- Simulation complete ---\n');
