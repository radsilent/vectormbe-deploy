% =============================================================================
% AUTONOMOUS VEHICLE SENSOR FUSION SYSTEM
% System: Perception and Tracking Module
% Platform: L4 AV (64-beam LIDAR + 4D Radar + 8 Camera)
% Standards: ISO 21448 (SOTIF), ISO 26262, SAE J3016
% =============================================================================
%
% REQ-FUSE-001: Object detection latency <= 80 ms (95th percentile)
% REQ-FUSE-002: Pedestrian detection range >= 60 m at night (10 lux)
% REQ-FUSE-003: Vehicle position accuracy <= 0.1 m RMS (fused)
% REQ-FUSE-004: False positive rate <= 0.01 per km in urban scenario
% REQ-FUSE-005: Track continuity through 500 ms sensor dropout

%% Sensor Suite Configuration
% LIDAR - Velodyne VLS-128 equivalent
lidar_channels      = 128;          % Number of laser channels
lidar_rot_rate_hz   = 10;           % [Hz] Rotation rate
lidar_h_fov_deg     = 360;          % [deg] Horizontal FOV
lidar_v_fov_deg     = 40;           % [deg] Vertical FOV (-25 to +15 deg)
lidar_range_max     = 300;          % [m]  Max range
lidar_range_res     = 0.03;         % [m]  Range resolution
lidar_pts_per_scan  = 2.4e6;        % Points per second
lidar_angular_res   = 0.2;          % [deg] Horizontal angular resolution

% 4D Imaging Radar - Continental ARS540 equivalent
radar_range_max     = 250;          % [m]
radar_range_res     = 0.39;         % [m]
radar_vel_max       = 100/3.6;      % [m/s] ±100 km/h
radar_vel_res       = 0.18;         % [m/s]
radar_h_fov_deg     = 120;          % [deg]
radar_v_fov_deg     = 28;           % [deg]
radar_az_accuracy   = 0.3;          % [deg] Azimuth accuracy 1-sigma
radar_update_hz     = 20;           % [Hz]
N_radars            = 4;            % Front + 3 corner radars

% Camera Array - 8.3 MP, 30 Hz
cam_resolution      = [3840, 2160]; % pixels
cam_fps             = 30;           % [Hz]
cam_fov_front_deg   = 100;          % [deg] Front wide camera
cam_fov_tele_deg    = 30;           % [deg] Telephoto camera
cam_focal_length_mm = [2.8, 8.0, 16.0]; % Camera focal lengths
N_cameras           = 8;

%% Extended Kalman Filter - Object State Estimator
% State: [x, y, z, vx, vy, vz, ax, ay, heading, yaw_rate] (CTRV model)
n_states = 6;  % [x, y, vx, vy, heading, yaw_rate]
dt_ekf   = 0.05;  % [s] EKF prediction step (20 Hz)

% Process noise - CTRV model
sigma_a_lon  = 2.0;   % [m/s²] Longitudinal acceleration std dev
sigma_a_lat  = 1.5;   % [m/s²] Lateral acceleration std dev
sigma_yaw_dd = 0.5;   % [rad/s²] Yaw rate noise

Q_ekf = diag([0.25^2, 0.25^2, sigma_a_lon^2*dt_ekf^2, ...
              sigma_a_lat^2*dt_ekf^2, 0.01^2, sigma_yaw_dd^2*dt_ekf^2]);

% LIDAR observation model noise
R_lidar = diag([0.05^2, 0.05^2, 0.08^2]);  % [m] x,y,z noise covariance

% Radar observation model noise
R_radar = diag([(radar_range_res/2)^2, ...  % range variance
                (radar_az_accuracy*pi/180)^2, ... % azimuth variance
                (radar_vel_res/2)^2]);             % Doppler variance

% Camera observation model (pixel -> world via homography)
sigma_px    = 1.5;   % [px] Detection centroid noise
f_cam_px    = 2100;  % [px] Effective focal length (front cam)
R_camera    = diag([(sigma_px/f_cam_px)^2, (sigma_px/f_cam_px)^2]);

%% Track Management - Global Nearest Neighbor
track_create_score   = 3;     % Hits needed to confirm track
track_delete_misses  = 8;     % Consecutive misses to delete
max_tracks_active    = 256;   % Maximum simultaneous tracks
gate_mahal_sq        = 9.21;  % Mahalanobis gate (chi2, 2-DOF, 99%)
association_method   = 'GNN'; % Global Nearest Neighbor
N_hypothesis_max     = 50;    % MHT hypothesis cap (fallback)

%% Occupancy Grid Parameters
grid_res      = 0.2;          % [m] Cell resolution
grid_x_range  = [-50, 150];   % [m] X extent (behind/ahead)
grid_y_range  = [-30, 30];    % [m] Y extent
grid_z_slices = 5;            % Height layers
N_cells_x     = diff(grid_x_range) / grid_res;  % 1000 cells
N_cells_y     = diff(grid_y_range) / grid_res;  % 300 cells
p_occ_init    = 0.5;          % Prior occupancy probability
p_occ_hit     = 0.85;         % Sensor hit update
p_occ_miss    = 0.35;         % Sensor miss update
l_occ_min     = log(0.05/0.95); % Log-odds clamp min
l_occ_max     = log(0.95/0.05); % Log-odds clamp max

%% Sensor Fusion Timing Budget [ms]
t_lidar_preproc   = 12.0;   % Voxelization + ground removal
t_lidar_detect    = 18.0;   % 3D object detection (SECOND net)
t_radar_proc      =  3.5;   % CFAR + clustering
t_camera_detect   = 22.0;   % CNN inference (YOLOv8 equivalent)
t_fusion_assoc    =  8.0;   % Data association + EKF update
t_grid_update     =  6.0;   % Occupancy grid update
t_total_budget    = 80.0;   % [ms] Hard deadline
t_pipeline_est    = t_lidar_detect + t_fusion_assoc + t_grid_update;

fprintf('AV Sensor Fusion System Initialized\n');
fprintf('LIDAR: %d ch, %.0f pts/s | Radar: %d units, %.0f m range\n', ...
        lidar_channels, lidar_pts_per_scan, N_radars, radar_range_max);
fprintf('EKF states: %d | Grid: %.0fx%.0f @ %.1f m res\n', ...
        n_states, N_cells_x, N_cells_y, grid_res);
fprintf('Pipeline latency estimate: %.1f / %.1f ms budget\n', ...
        t_pipeline_est, t_total_budget);
