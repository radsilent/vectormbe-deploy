% =============================================================================
% SUBMARINE SONAR SIGNAL PROCESSING SYSTEM
% System: AN/BQQ-10 Class Broadband/Narrowband Sonar Suite
% Platform: SSN Fast-Attack Submarine
% Standards: MIL-STD-2073, NAVSEA S9505-AC-GYD-010
% =============================================================================
%
% REQ-SON-001: Passive detection range >= 35 nm against surface combatant
% REQ-SON-002: Bearing accuracy <= 0.5° RMS for tonal contacts
% REQ-SON-003: False alarm rate <= 1 per hour in SS-4 sea state
% REQ-SON-004: Target motion analysis convergence in <= 8 min
% REQ-SON-005: Simultaneous track capacity >= 128 contacts

%% Cylindrical Bow Array Parameters
N_elements_cyl   = 1240;    % Number of hydrophone elements (cylindrical)
R_array_cyl      = 1.35;    % [m]  Array radius
f_sample         = 48000;   % [Hz] Sample rate
f_low_broad      = 10;      % [Hz] Broadband low cutoff
f_high_broad     = 20000;   % [Hz] Broadband high cutoff
element_spacing  = 0.018;   % [m]  Inter-element spacing (lambda/2 at 40 kHz)
array_gain_cyl   = 30.9;    % [dB] Array gain (10*log10(N))

%% Towed Array (TB-29A Thin-Line)
N_elements_towed = 480;     % Towed array element count
L_towed          = 160;     % [m]  Towed array active aperture
tow_depth        = 150;     % [m]  Operating tow depth
f_vla_low        = 10;      % [Hz] VLA low frequency
f_vla_high       = 1000;    % [Hz] VLA high frequency
array_gain_towed = 26.8;    % [dB] Towed array gain

%% Beamforming Parameters
c_sound       = 1500;       % [m/s] Sound speed (nominal)
c_sound_svp   = [1480, 1490, 1500, 1505, 1510, 1508, 1495]; % SVP profile
z_svp         = [0, 50, 100, 200, 400, 600, 800];           % [m] SVP depths
N_beams       = 360;        % Number of formed beams (1° resolution)
beam_dwell_ms = 100;        % [ms] Beam dwell time
FFT_size      = 4096;       % FFT length for narrowband processing
overlap_pct   = 0.75;       % Overlap fraction for STFT

% Beamforming weights (Dolph-Chebyshev, -50 dB sidelobes)
SLL_dB        = -50;        % Side-lobe level
steering_vec  = @(theta, f) exp(-1j * 2*pi*f/c_sound * ...
                 (0:N_elements_cyl-1)' * element_spacing * sind(theta));

%% Detection Thresholds (DEMON/LOFAR)
DT_broadband   = 12.5;  % [dB] Detection threshold broadband
DT_narrowband  = 6.0;   % [dB] Detection threshold narrowband (LOFAR)
NL_ambient     = 62;    % [dB re 1 uPa] Ambient noise level SS-3
TS_target      = 15;    % [dB] Target strength surface combatant
SL_target      = 165;   % [dB re 1 uPa @ 1m] Source level target
alpha_atten    = 0.002; % [dB/m] Absorption coefficient at 1 kHz

% Figure of merit
TL_max = SL_target - NL_ambient + array_gain_cyl - DT_narrowband;
fprintf('Narrowband FOM: %.1f dB => max range approx %.1f km\n', ...
        TL_max, 10^((TL_max - 20*log10(1))/20) / 1000);

%% Frequency Bands of Interest (LOFAR tonals)
% Machinery line frequencies typical surface combatant
f_tonals_ship = [12.5, 25.0, 50.0, 100, 120, 150, 200, 400]; % [Hz]
f_prop_blade  = [8.3, 16.7, 25.0, 33.3];   % [Hz] 5-blade prop, 100 RPM
f_cavitation  = [500, 1000, 2000, 5000];    % [Hz] Cavitation onset bands

%% Kalman Filter - Target State Estimator (Bearing-Only Tracking)
% State vector: [x, y, vx, vy] own-ship relative coordinates
dt_track = 1.0;       % [s]  Track update interval
sigma_bearing = 0.5 * pi/180;   % [rad] Bearing measurement noise 1-sigma
sigma_proc_v  = 0.05; % [m/s²] Process noise on velocity

% State transition matrix
F_track = [1, 0, dt_track, 0;
           0, 1, 0,        dt_track;
           0, 0, 1,        0;
           0, 0, 0,        1];

% Process noise covariance (Singer model acceleration)
Q_track = sigma_proc_v^2 * ...
          [dt_track^4/4, 0,           dt_track^3/2, 0;
           0,            dt_track^4/4, 0,           dt_track^3/2;
           dt_track^3/2, 0,           dt_track^2,   0;
           0,            dt_track^3/2, 0,            dt_track^2];

% Initial state covariance
P0_track = diag([500^2, 500^2, 5^2, 5^2]); % pos 500m, vel 5 m/s uncertainty

%% Track Management
track_init_threshold  = 3;    % M/N hits to initiate track (3 of 5)
track_drop_threshold  = 5;    % Consecutive misses to drop track
max_tracks            = 128;
gate_probability      = 0.997; % Gating probability (chi-squared, 4-DOF => 18.5)
gate_size_sq          = 18.47;% Chi-squared gate (99.7%, 4 DOF)

%% Signal Processing Chain
fprintf('Sonar Processing Chain:\n');
fprintf('  Bow Array: %d elements, R=%.2f m, Gain=%.1f dB\n', ...
        N_elements_cyl, R_array_cyl, array_gain_cyl);
fprintf('  Towed Array: %d elements, L=%.0f m, Gain=%.1f dB\n', ...
        N_elements_towed, L_towed, array_gain_towed);
fprintf('  Beams: %d x 1-deg | FFT: %d pts @ %d Hz\n', ...
        N_beams, FFT_size, f_sample);
fprintf('  Kalman dt=%.1fs, track capacity: %d contacts\n', ...
        dt_track, max_tracks);
