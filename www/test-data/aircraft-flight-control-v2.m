% =============================================================================
% COMMERCIAL AIRCRAFT FLIGHT CONTROL SYSTEM — Version 2
% System: Full-Authority Digital Fly-by-Wire + AFCS + Envelope Protection
% Platform: Narrow-body commercial transport (A320 / B737 MAX class)
% Standards: DO-178C (DAL A), ARP 4754A, CS-25 / FAR Part 25
% v2 adds: phugoid, LQR design, Dryden turbulence, OEI analysis,
%          flap/slat scheduling, hydraulic model, more autopilot modes,
%          envelope protection limits, structural loads, CAT IIIb autoland
% =============================================================================
%
% REQ-FCS-001: Pitch rate response bandwidth >= 2.5 rad/s (short-period, damped)
% REQ-FCS-002: Roll rate response bandwidth >= 3.5 rad/s
% REQ-FCS-003: Control surface actuator rate limit >= 40 deg/s (elevator)
% REQ-FCS-004: AFCS engaged altitude hold error <= ±50 ft (1-sigma)
% REQ-FCS-005: ILS CAT III runway tracking accuracy <= 0.2 m lateral (1-sigma)
% REQ-FCS-006: Control law computation latency <= 10 ms (hard real-time)
% REQ-FCS-007: Fault detection and isolation (FDI) reaction time <= 50 ms
% REQ-FCS-008: Load factor limiting 2.5 g to -1 g (normal category envelope)
% REQ-FCS-009: Phugoid damping ratio >= 0.04 (CS-25.181 minimum)
% REQ-FCS-010: Dutch-roll damping ratio >= 0.08 and ω_dr >= 0.4 rad/s
% REQ-FCS-011: Spiral mode time-to-double >= 20 s (divergent) or neutral/stable
% REQ-FCS-012: Gain margin >= 6 dB; phase margin >= 45 deg (all axes)
% REQ-FCS-013: TCAS RA pitch response within 5 s to ±2.5 deg/s climb rate
% REQ-FCS-014: Alpha protection engages at alpha_prot, alpha_floor at thrust lever
% REQ-FCS-015: Vmo protection: overspeed prevention via pitch-up command > Vmo+6kt
% REQ-FCS-016: OEI: automatic rudder compensation within 100 ms of engine failure
% REQ-FCS-017: Autobrake (MED) stops aircraft from 140 kt in < 1500 m (dry runway)
% REQ-FCS-018: Nosewheel steering authority ±70 deg low-speed / ±6 deg high-speed
% REQ-FCS-019: THS trim authority ±3 deg at 0.2 deg/s (electrical trim motor)
% REQ-FCS-020: CAT IIIb autoland touchdown dispersion <= ±2 ft on centreline

%% ── Aircraft Aerodynamic Parameters (narrow-body twin-jet, MTOW 79 000 kg) ────

m           = 79000;            % [kg]   MTOW
W           = m * 9.80665;     % [N]    Weight at MTOW
b           = 34.1;            % [m]    Wing span
S_ref       = 122.6;           % [m²]  Wing reference area
c_bar       = 4.20;            % [m]    Mean aerodynamic chord
AR          = b^2 / S_ref;     % [-]    Aspect ratio
e           = 0.82;            % [-]    Oswald efficiency
I_xx        = 2.98e6;          % [kg·m²] Roll moment of inertia
I_yy        = 4.37e6;          % [kg·m²] Pitch moment of inertia
I_zz        = 7.10e6;          % [kg·m²] Yaw moment of inertia
I_xz        = 1.80e5;          % [kg·m²] Product of inertia

%% ── Atmospheric / Flight Condition (cruise FL370, ISA) ─────────────────────────

h_cruise_ft = 37000;
h_cruise    = h_cruise_ft * 0.3048;
T_isa       = 216.65;           % [K]
rho         = 0.3639;           % [kg/m³]
a_sound     = sqrt(1.4 * 287 * T_isa);
M_cruise    = 0.78;
V_TAS       = M_cruise * a_sound;
V_EAS       = V_TAS * sqrt(rho / 1.225);
q_bar       = 0.5 * rho * V_TAS^2;
g           = 9.80665;

%% ── Lift / Drag Polars (clean configuration) ────────────────────────────────

CL_alpha    = 5.62;             % [/rad]  3D lift curve slope
CL_0        = 0.22;
CL_cruise   = W / (q_bar * S_ref);
alpha_cruise= (CL_cruise - CL_0) / CL_alpha;
alpha_cruise_deg = alpha_cruise * 180/pi;

CD_0        = 0.0175;
k           = 1 / (pi * AR * e);
CD_cruise   = CD_0 + k * CL_cruise^2;
LD_cruise   = CL_cruise / CD_cruise;

fprintf('--- Cruise Trim ---\n');
fprintf('  V_TAS = %.1f m/s  (M = %.3f)\n', V_TAS, M_cruise);
fprintf('  alpha_trim = %.3f deg\n', alpha_cruise_deg);
fprintf('  L/D = %.2f\n', LD_cruise);

%% ── High-Lift Configuration (Flaps/Slats) ──────────────────────────────────

% Flap settings: 0 / 1+F / 2 / 3 / FULL
flap_deg    = [0,  5, 15, 20, 35];    % Flap deflection schedule [deg]
slat_deg    = [0, 18, 22, 22, 27];    % Slat deflection schedule [deg]

% Delta-CL from high-lift devices (empirical, refs Raymer / Roskam)
dCL_flap    = [0, 0.28, 0.62, 0.80, 1.15];
dCL_slat    = [0, 0.10, 0.14, 0.14, 0.18];
dCD_flap    = [0, 0.005, 0.018, 0.030, 0.065];

% Landing CL_max (FULL flaps, slats)
CL_max_clean  = 1.60;
CL_max_land   = CL_max_clean + dCL_flap(5) + dCL_slat(5);
CL_max_to     = CL_max_clean + dCL_flap(3) + dCL_slat(3);  % Config 2

% Stall speeds (FAR 25 Vs1g definition)
Vs_land_kt  = sqrt(2*W / (rho * S_ref * CL_max_land)) / 0.5144;
Vs_to_kt    = sqrt(2*W / (rho * S_ref * CL_max_to))   / 0.5144;
fprintf('\n--- V-Speeds ---\n');
fprintf('  Vs (landing) = %.1f KIAS\n', Vs_land_kt);
fprintf('  Vs (takeoff) = %.1f KIAS\n', Vs_to_kt);
fprintf('  V2 (min)     = %.1f KIAS\n', 1.13 * Vs_to_kt);
fprintf('  Vapp (target)= %.1f KIAS\n', 1.23 * Vs_land_kt);

%% ── Engine Model (2× CFM56-class, 120 kN SL thrust each) ───────────────────

T_sl_each   = 120e3;            % [N]
T_sl_total  = 2 * T_sl_each;
BPR         = 6.5;
sfc_cruise  = 15.5e-6;         % [kg/(N·s)]
T_cruise    = W / LD_cruise;
fuel_burn_kgs = sfc_cruise * T_cruise;
fuel_burn_kgh = fuel_burn_kgs * 3600;

% Engine model: thrust vs altitude / Mach (simplified lapse rate)
altitude_ft = [0, 10000, 20000, 30000, 35000, 37000, 41000];
T_lapse     = [1.00, 0.738, 0.518, 0.337, 0.256, 0.228, 0.185];  % T/T_sl
T_at_cruise = T_sl_each * T_lapse(6);   % Max continuous at FL370

%% ── Longitudinal Stability Derivatives (cruise, M 0.78, CG 28% MAC) ────────

Cmu         = -1.32;
Cm_alpha    = Cmu;
Cm_q        = -18.5;
Cm_alpha_dot= -7.2;
Cm_de       = -1.58;
Cz_alpha    = -CL_alpha;
Cz_q        = -2 * CL_alpha * 0.5;
Cz_de       = -0.42;
Cx_alpha    = 0.12;

%% ── Lateral-Directional Derivatives ─────────────────────────────────────────

Cl_beta     = -0.098;
Cl_p        = -0.485;
Cl_r        = 0.098;
Cl_da       = 0.228;
Cl_dr       = 0.012;
Cn_beta     = 0.072;
Cn_p        = -0.026;
Cn_r        = -0.086;
Cn_da       = 0.006;
Cn_dr       = -0.088;
CY_beta     = -0.88;

%% ── Short-Period State-Space Model ──────────────────────────────────────────
% States: [alpha (rad), q (rad/s)]

q_ref   = q_bar;
Mw_ref  = q_ref * S_ref * c_bar / (2 * V_TAS * I_yy) * Cm_alpha;
Mq_ref  = q_ref * S_ref * c_bar^2 / (2 * V_TAS * I_yy) * Cm_q;
Zw_ref  = q_ref * S_ref / (m * V_TAS) * Cz_alpha;
Zdot    = q_ref * S_ref * c_bar / (2 * V_TAS^2 * I_yy) * Cm_alpha_dot;
Me_ref  = q_ref * S_ref * c_bar / I_yy * Cm_de;
Ze_ref  = q_ref * S_ref / m * Cz_de;

A_sp = [Zw_ref,              1;
        Mw_ref + Zdot*Mq_ref, Mq_ref];
B_sp = [Ze_ref;
        Me_ref + Zdot*Ze_ref];

eig_sp  = eig(A_sp);
omega_sp = abs(eig_sp(1));
zeta_sp  = -real(eig_sp(1)) / omega_sp;
fprintf('\n--- Short-Period Mode ---\n');
fprintf('  ω_sp = %.3f rad/s   ζ_sp = %.3f\n', omega_sp, zeta_sp);

%% ── Phugoid Mode (full 4-state longitudinal) ────────────────────────────────
% States: [u (m/s), w (m/s), q (rad/s), theta (rad)]

Xu = -(q_bar * S_ref / (m * V_TAS)) * (2*CD_cruise);
Xw =  (q_bar * S_ref / (m * V_TAS)) * (CL_cruise - 2*CD_cruise*alpha_cruise);
Zu = -(q_bar * S_ref / (m * V_TAS)) * (2*CL_cruise);
Zw =  (q_bar * S_ref / (m * V_TAS)) * Cz_alpha;
Zq =  (q_bar * S_ref * c_bar / (2 * m * V_TAS)) * Cz_q;
Mu =  0;  % Speed stability (Mach tuck effect — set 0 for baseline)
Mw =  (q_bar * S_ref * c_bar / I_yy) * (Cm_alpha / V_TAS);
Mw_dot= (q_bar * S_ref * c_bar^2 / (2 * I_yy * V_TAS)) * (Cm_alpha_dot / V_TAS);
Mq_full = Mq_ref;

A_long = [Xu,   Xw,   0,    -g;
          Zu,   Zw,   V_TAS+Zq, 0;
          Mu+Mw_dot*Zu, Mw+Mw_dot*Zw, Mq_full+Mw_dot*(V_TAS+Zq), 0;
          0,    0,    1,    0];

eig_long = eig(A_long);
% Identify phugoid (pair with smallest |imag|) vs short-period
[~, idx] = sort(abs(real(eig_long)));
ph_pair = eig_long(idx(1:2));
sp_pair = eig_long(idx(3:4));

omega_ph = abs(ph_pair(1));
if omega_ph > 0
    zeta_ph = -real(ph_pair(1)) / omega_ph;
else
    zeta_ph = 0;
end
fprintf('\n--- Phugoid Mode ---\n');
fprintf('  ω_ph = %.4f rad/s   ζ_ph = %.4f', omega_ph, zeta_ph);
if zeta_ph >= 0.04
    fprintf('  [PASS REQ-FCS-009]\n');
else
    fprintf('  [FAIL REQ-FCS-009 — ζ_ph min 0.04]\n');
end

%% ── Lateral-Directional State-Space (4-state) ───────────────────────────────
% States: [beta, p, r, phi]

V   = V_TAS;
Yb  = q_bar * S_ref / m * CY_beta;
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
Yr2 = q_bar * S_ref / m * 0.18;

A_lat = [Yb/V,  0,      (Yb/V - 1), g*cos(0)/V;
         Lb,    Lp,     Lr,         0;
         Nb,    Np,     Nr,         0;
         0,     1,      tan(0),     0];
B_lat = [0,     Yr2/V;
         La,    Lr2;
         Na,    Nr2;
         0,     0];

eig_lat = eig(A_lat);

% Identify Dutch-roll, roll, spiral
[~, si] = sort(abs(imag(eig_lat)), 'descend');
dr_eig   = eig_lat(si(1));
omega_dr = abs(dr_eig);
zeta_dr  = -real(dr_eig) / omega_dr;
roll_eig = eig_lat(si(3));      % Pure real, fast
spiral_eig = eig_lat(si(4));    % Pure real, slow

T2_spiral = log(2) / real(spiral_eig);  % Time-to-double (divergent if > 0)

fprintf('\n--- Dutch Roll Mode ---\n');
fprintf('  ω_dr = %.3f rad/s   ζ_dr = %.3f', omega_dr, zeta_dr);
if zeta_dr >= 0.08
    fprintf('  [PASS REQ-FCS-010]\n');
else
    fprintf('  [FAIL REQ-FCS-010]\n');
end

fprintf('--- Roll Mode ---\n');
fprintf('  τ_roll = %.3f s\n', -1/real(roll_eig));

fprintf('--- Spiral Mode ---\n');
if real(spiral_eig) > 0
    fprintf('  T2 = %.1f s (divergent)', T2_spiral);
    if T2_spiral >= 20
        fprintf('  [PASS REQ-FCS-011]\n');
    else
        fprintf('  [FAIL REQ-FCS-011]\n');
    end
else
    fprintf('  Stable (not applicable)\n');
end

%% ── FBW Control Laws — Normal Law (Pitch, C* Criterion) ─────────────────────

V_cross = 95;                   % [m/s]  C* crossover speed
Kp_q    = 0.065;
Ki_q    = 0.018;
Kd_q    = 0.004;
de_max  = 25 * pi/180;
de_rate = 40 * pi/180;
nz_max  =  2.5;
nz_min  = -1.0;
phi_bank_max = 67 * pi/180;

%% ── FBW — Roll Control Law ───────────────────────────────────────────────────

Kp_roll = 0.55;
Ki_roll = 0.08;
Kff_roll= 0.30;
da_max  = 25 * pi/180;
da_rate = 50 * pi/180;

%% ── Yaw Damper (Dutch-roll suppression, 80 Hz) ──────────────────────────────

Kyd         = 0.18;
omega_n_yd  = 4.0;
zeta_yd     = 0.70;
dr_yd_max   = 8 * pi/180;

%% ── Envelope Protection Limits ──────────────────────────────────────────────

% Speed envelope
Vmo_kt      = 350;              % [kt]   Maximum operating speed
Mmo         = 0.82;             % [-]    Maximum operating Mach
Vd_kt       = 390;              % [kt]   Design dive speed (CS-25.335)
Md          = 0.89;

% Alpha protection (AoA-based, Normal Law)
alpha_prot  = 15.0 * pi/180;   % [rad]  Alpha protection activation
alpha_max   = 18.5 * pi/180;   % [rad]  Maximum alpha (alpha_floor trigger)
alpha_floor = 14.0 * pi/180;   % [rad]  TOGA thrust command threshold

% High-speed protection gains
K_overspeed  = 0.05;           % Pitch-up rate command per kt over Vmo
K_overmach   = 1.5;            % Pitch-up per Mach unit over Mmo
phi_sp_max   = 45 * pi/180;   % Bank angle limit in high-speed protection

% Low-energy warning (STALL WARNING and ALPHA FLOOR)
Valphamax_kt  = Vs_land_kt * 1.05;  % Speed at alpha_max

fprintf('\n--- Envelope Limits ---\n');
fprintf('  Vmo = %d kt  |  Mmo = %.2f  |  Vd = %d kt  |  Md = %.2f\n', ...
        Vmo_kt, Mmo, Vd_kt, Md);
fprintf('  alpha_prot = %.1f deg  |  alpha_max = %.1f deg\n', ...
        alpha_prot*180/pi, alpha_max*180/pi);

%% ── LQR Optimal State Feedback (Longitudinal) ───────────────────────────────

% Augmented state: [u, w, q, theta, z_int] where z_int = integral of altitude error
% Q: penalise altitude deviation and pitch excursion; R: elevator cost
Q_lqr = diag([0.001, 0.001, 1.0, 10.0, 5.0]);  % State weights
R_lqr = 1.0;                                     % Control weight

% Augmented A_long with integrator state
A_aug = [A_long, zeros(4,1);
         0, 0, 0, -V_TAS, 0];   % d(z_int)/dt = -V_TAS * theta (altitude rate)
B_aug = [zeros(4,1); 0];         % Elevator input enters A_long[2,2] effectively
% Note: full LQR requires B_aug from elevator to all states; symbolic here
fprintf('\n--- LQR Design (symbolic) ---\n');
fprintf('  Q = diag([%.3f, %.3f, %.1f, %.1f, %.1f])\n', diag(Q_lqr)');
fprintf('  R = %.1f  (elevator position cost)\n', R_lqr);
fprintf('  Solve: P*A_aug + A_aug''*P - P*B_aug*inv(R)*B_aug''*P + Q = 0\n');

%% ── Autopilot Modes ─────────────────────────────────────────────────────────

% Altitude Hold
Kp_alt   = 0.012;
Ki_alt   = 0.0015;
VS_max   = 4.0;
VS_min   = -3.0;

% Vertical Speed Hold
Kp_vs    = 0.030;
Ki_vs    = 0.004;
theta_vs_max = 12 * pi/180;

% IAS Hold (Autothrottle)
Kp_ias   = 0.045;
Ki_ias   = 0.008;
Kd_ias   = 0.002;
N1_max   = 99.0;
N1_idle  = 25.0;

% Heading Select
Kp_hdg   = 0.018;
phi_hdg_max = 25 * pi/180;

% ILS Localiser
Kp_loc   = 0.040;
Ki_loc   = 0.006;
Kd_loc   = 0.002;
loc_capt_range = 18e3;

% ILS Glideslope
Kp_gs    = 0.055;
Ki_gs    = 0.008;
gs_capt_alt = 1200 * 0.3048;

% CAT IIIb Autoland — Flare and Rollout
h_flare       = 50 * 0.3048;   % [m]   Flare initiation
tau_flare     = 6.0;            % [s]   Flare time constant
theta_td      = -2.5 * pi/180;  % [rad] Target pitch at touchdown
V_rollout_end = 10 * 0.5144;   % [m/s] End of rollout phase (~10 kt)
Kp_rollout    = 0.002;          % Centreline tracking gain post-touchdown
t_rotate      = 1.5;            % [s]   Time from V_R to nose up
theta_rotate  = 15 * pi/180;   % [rad] Initial rotation pitch angle

% Go-Around Mode
gamma_ga  = 4.0 * pi/180;      % [rad]  Climb gradient (4 deg ~ 2500 fpm)
Kp_ga_pitch = 0.020;
TOGA_N1   = 96.0;              % [%]   TOGA N1 setting (ISA, SL)

fprintf('\n--- Autoland (CAT IIIb) Parameters ---\n');
fprintf('  Flare height = %.0f ft  |  tau_flare = %.1f s\n', ...
        h_flare/0.3048, tau_flare);
fprintf('  Rollout tracking Kp = %.4f\n', Kp_rollout);

%% ── Dryden Atmospheric Turbulence Model (MIL-HDBK-1797) ────────────────────

% Turbulence intensities at cruise (moderate)
sigma_u  = 3.0;                 % [m/s]  Longitudinal turbulence intensity
sigma_v  = 3.0;                 % [m/s]  Lateral turbulence intensity
sigma_w  = 1.5;                 % [m/s]  Vertical turbulence intensity

% Scale lengths (cruise, h > 2000 ft)
L_u      = 533;                 % [m]
L_v      = 533;                 % [m]
L_w      = 533;                 % [m]

% Dryden PSD (power spectral density)
% Phi_u(omega) = sigma_u^2 * (2*L_u/pi) / (1 + (L_u*omega/V)^2)
omega_turb = logspace(-2, 2, 200);
Phi_u = sigma_u^2 * (2*L_u/pi) ./ (1 + (L_u*omega_turb/V_TAS).^2);
Phi_w = sigma_w^2 * (2*L_w/pi) * (1 + 3*(L_w*omega_turb/V_TAS).^2) ...
        ./ (1 + (L_w*omega_turb/V_TAS).^2).^2;

% Von Karman PSD (alternate, more accurate at high frequency)
Phi_u_vk = sigma_u^2 * (2*L_u/pi) ./ (1 + 1.339*(L_u*omega_turb/V_TAS).^2).^(5/6);

fprintf('\n--- Dryden Turbulence (Moderate, FL370) ---\n');
fprintf('  σ_u = %.1f m/s  σ_w = %.1f m/s  L = %d m\n', sigma_u, sigma_w, L_u);

%% ── One-Engine-Inoperative (OEI) Handling ───────────────────────────────────

T_oei_at_v2  = T_sl_each * T_lapse(1) * 1.0;   % TOGA thrust, SL, ISA
% Yawing moment from failed engine (left engine assumed)
y_eng        = 5.8;             % [m]   Engine lateral offset from centreline
N_oei        = T_oei_at_v2 * y_eng;  % [N·m] Asymmetric yaw moment

% Rudder authority to counter OEI yawing moment
% N_rudder = q_bar * S_ref * b * Cn_dr * dr_oei
q_bar_v2   = 0.5 * 1.225 * (1.13 * Vs_to_kt * 0.5144)^2;  % At V2, SL
dr_oei_rad = N_oei / (q_bar_v2 * S_ref * b * abs(Cn_dr));
dr_oei_deg = dr_oei_rad * 180/pi;
Vmcg_kt    = Vs_to_kt * 0.95;  % Approximate Vmcg estimate

fprintf('\n--- OEI Analysis (Left Engine Failed) ---\n');
fprintf('  N_oei = %.0f N·m\n', N_oei);
fprintf('  Required dr = %.1f deg (limit ±25 deg)', dr_oei_deg);
if dr_oei_deg <= 25
    fprintf('  [ADEQUATE AUTHORITY]\n');
else
    fprintf('  [INSUFFICIENT RUDDER]\n');
end
fprintf('  Vmcg estimate ≈ %.1f KIAS\n', Vmcg_kt);

% OEI automatic yaw damper enhancement — 3× normal authority
Kyd_oei = 3 * Kyd;
dr_oei_limit = 25 * pi/180;    % Full rudder authority

%% ── Flap / Slat Scheduling ───────────────────────────────────────────────────

% Speed schedule for flap retraction after takeoff (ICAO noise abatement)
V_flap_ret_kt = [Vs_to_kt*1.25, Vs_to_kt*1.35, Vs_to_kt*1.45, Vs_to_kt*1.60];
% [Config 1+F → 1, Config 1 → 0]

% Landing flap extension schedule
V_flap_ext_kt = [250, 200, 185, 177];  % Flap limit speeds Vfe [kt]
VFE           = [250, 215, 200, 185];  % Flap extension speed limits [kt]

fprintf('\n--- High-Lift Schedule ---\n');
for i = 1:length(flap_deg)
    fprintf('  Config %d: F%d / S%d  dCL=%.2f  Vfe=%d kt\n', i, ...
            flap_deg(i), slat_deg(i), dCL_flap(i)+dCL_slat(i), VFE(min(i,4)));
end

%% ── Hydraulic System Model (ATA 29) — Three Independent Systems ─────────────

% System A (left): 3000 PSI, engine 1 pump + electric pump (EDP+EMP)
% System B (right): 3000 PSI, engine 2 pump + electric pump
% System C (centre): 3000 PSI, two electric motor pumps (ACMPs); green for flight

P_hyd_nom   = 3000;             % [psi]  Nominal system pressure
P_hyd_lo    = 2750;             % [psi]  Low pressure warning
P_hyd_min   = 1500;             % [psi]  Minimum for primary flight controls

% Actuator demand model
areas_cm2   = [18.5, 14.2, 9.6, 6.3, 5.1, 3.8];  % Actuator piston areas
names_act   = {'Elevator', 'Rudder', 'Aileron', 'Spoileron', 'Slat', 'Flap'};
rate_max    = [40, 30, 50, 60, 20, 15];            % [deg/s] max rates

% Flow demand at max rate (all actuators simultaneously)
Q_demand_L_s = sum(areas_cm2 .* rate_max * pi/180) * 1e-4;  % [L/s]
fprintf('\n--- Hydraulic System ---\n');
fprintf('  Nominal pressure = %d psi\n', P_hyd_nom);
fprintf('  Peak flow demand = %.2f L/s (all actuators)\n', Q_demand_L_s);

%% ── Actuator Models (second-order with rate + position limits) ──────────────

s           = tf('s');
omega_act_e = 30;   zeta_act_e = 0.71;
omega_act_a = 35;   zeta_act_a = 0.70;
omega_act_r = 25;   zeta_act_r = 0.72;
omega_act_s = 18;   zeta_act_s = 0.68;  % Spoileron
omega_act_th = 22;  zeta_act_th = 0.70; % THS trim

G_act_e  = omega_act_e^2  / (s^2 + 2*zeta_act_e*omega_act_e*s  + omega_act_e^2);
G_act_a  = omega_act_a^2  / (s^2 + 2*zeta_act_a*omega_act_a*s  + omega_act_a^2);
G_act_r  = omega_act_r^2  / (s^2 + 2*zeta_act_r*omega_act_r*s  + omega_act_r^2);
G_act_s  = omega_act_s^2  / (s^2 + 2*zeta_act_s*omega_act_s*s  + omega_act_s^2);
G_act_th = omega_act_th^2 / (s^2 + 2*zeta_act_th*omega_act_th*s + omega_act_th^2);

%% ── Sensor Models ────────────────────────────────────────────────────────────

% Air data (50 Hz)
sigma_V_eas   = 0.5;    % [kt]
sigma_alt     = 15;     % [ft]
sigma_V_mach  = 0.002;
% Radio altimeter (100 Hz, below 2500 ft AGL)
sigma_radioalt = 0.30;  % [ft]   (1-sigma, h < 200 ft)
sigma_radioalt_hi = 1.5; % [ft]  (1-sigma, h < 2500 ft)

% IRS (200 Hz)
sigma_phi   = 0.10 * pi/180;
sigma_theta = 0.05 * pi/180;
sigma_psi   = 0.20 * pi/180;
sigma_p     = 0.01 * pi/180;
sigma_q     = 0.01 * pi/180;
sigma_r     = 0.01 * pi/180;
sigma_nz    = 0.005;

% GPS (SBAS, 10 Hz)
sigma_pos_h = 1.5;     % [m] 95%
sigma_pos_v = 2.0;

%% ── FDI — Triplex Channel Voting ────────────────────────────────────────────

n_channels  = 3;
threshold_3V2 = 0.5 * pi/180;
threshold_mon = 0.3 * pi/180;
tau_fdi       = 0.050;
disagree_latch_cycles = ceil(tau_fdi * 1000);

%% ── Structural Loads Monitoring (Fatigue) ───────────────────────────────────

% Design limit load (DLL) and ultimate load (ULL) — CS-25.301
n_DLL   =  2.5;                 % [g]   Positive limit load factor
n_DLL_n = -1.0;                 % [g]   Negative limit load factor
n_ULL   =  n_DLL * 1.5;        % [g]   Ultimate (no failure)

% Gust load (discrete gust, CS-25.341 Ude method)
Ude_cruise = 15.24;             % [m/s]  Clean smooth gust at cruise altitude
mu_g = 2 * m / (rho * S_ref * c_bar * CL_alpha);   % Mass ratio
K_g  = 0.88 * mu_g / (5.3 + mu_g);                  % Gust alleviation factor
delta_nz_gust = K_g * rho * V_EAS * Ude_cruise * CL_alpha * S_ref / (2 * W);

% Wing root bending moment (cruise + gust)
span_eff    = 0.45 * b/2;      % [m]   Effective load application point
BM_wing_DLL = n_DLL * W/2 * span_eff;   % [N·m]  Cruise limit
BM_wing_gust= (1 + delta_nz_gust) * W/2 * span_eff;

fprintf('\n--- Structural Loads ---\n');
fprintf('  Gust delta_nz = %.3f g  (Ude = %.1f m/s)\n', delta_nz_gust, Ude_cruise);
fprintf('  Wing root BM (limit) = %.3e N·m\n', BM_wing_DLL);
fprintf('  Wing root BM (gust)  = %.3e N·m\n', BM_wing_gust);

%% ── Closed-Loop Analysis ─────────────────────────────────────────────────────

G_plant_q = tf([B_sp(2)], [1, -A_sp(2,2)]);
G_pid_q   = pid(Kp_q, Ki_q, Kd_q, 0.05);
G_cl_q    = feedback(G_pid_q * G_act_e * G_plant_q, 1);
[y_q, t_q_vec] = step(G_cl_q * 1*pi/180, 60);
y_q_norm  = y_q / max(abs(y_q));
idx_90    = find(y_q_norm >= 0.90, 1, 'first');
idx_10    = find(y_q_norm >= 0.10, 1, 'first');
t_rise    = t_q_vec(idx_90) - t_q_vec(idx_10);
overshoot = max(0, (max(y_q_norm) - 1) * 100);
fprintf('\n--- Pitch-Axis Step Response ---\n');
fprintf('  Rise time = %.3f s  |  Overshoot = %.1f %%\n', t_rise, overshoot);

L_q = G_pid_q * G_act_e * G_plant_q;
[gm_q, pm_q, wpc_q, wgc_q] = margin(L_q);
fprintf('  GM = %.2f dB  PM = %.1f deg', 20*log10(gm_q), pm_q);
if 20*log10(gm_q) >= 6 && pm_q >= 45
    fprintf('  [PASS REQ-FCS-012]\n');
else
    fprintf('  [FAIL REQ-FCS-012]\n');
end

%% ── Breguet Range + Block Fuel ──────────────────────────────────────────────

fuel_mass_kg   = 20500;
R_breguet      = (V_TAS / (g * sfc_cruise)) * LD_cruise * log(1 + fuel_mass_kg / (m - fuel_mass_kg));
R_breguet_nm   = R_breguet / 1852;

% Block fuel with taxi and reserves
fuel_taxi_kg   = 150;           % [kg]  Taxi / APU
fuel_reserve_kg= fuel_mass_kg * 0.05;  % 5% final reserve
fuel_block_kg  = fuel_mass_kg - fuel_reserve_kg + fuel_taxi_kg;

fprintf('\n--- Breguet Range & Block Fuel ---\n');
fprintf('  Max range  = %.0f nm  (%.0f km)\n', R_breguet_nm, R_breguet/1000);
fprintf('  Block fuel = %.0f kg  |  Reserve = %.0f kg\n', fuel_block_kg, fuel_reserve_kg);

fprintf('\n=== FCS v2 model complete ===\n');
