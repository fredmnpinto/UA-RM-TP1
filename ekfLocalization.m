function [estimated_trajectory, P_history] = ekfLocalization(trajectory, N, Dt, Vn, Wn, V)
%EKFLOCALIZATION Extended Kalman Filter for robot localization
%
% Input:
%   trajectory - M×3 matrix [x, y, θ] from Phase 1 (ground truth)
%   N          - Number of beacons (default: 4)
%   Dt         - Sensor sampling time interval in seconds (default: 1)
%   Vn         - Linear velocity uncertainty sigma (default: 0.1 m/s)
%   Wn         - Angular velocity uncertainty sigma (default: 0.1 rad/s)
%   V          - Desired average linear velocity (default: 5 m/s)
%
% Output:
%   estimated_trajectory - M×3 matrix [x_est, y_est, θ_est]
%   P_history           - M×3×3 matrix of covariance history (optional)
%
% Example:
%   est_traj = ekfLocalization(trajectory, 4, 1, 0.1, 0.1, 5);
%
% Note: Beacons are fixed landmarks. Robot measures TO them, not navigates TO them.
%   Flow: initial_estimate -> predict() -> prediction -> update() -> corrected_prediction

    % Set defaults
    if nargin < 2 || isempty(N), N = 4; end
    if nargin < 3 || isempty(Dt), Dt = 1; end
    if nargin < 4 || isempty(Vn), Vn = 0.1; end
    if nargin < 5 || isempty(Wn), Wn = 0.1; end
    if nargin < 6 || isempty(V), V = 5; end
    
    % Create EKF object
    ekf = EKF(Vn, Wn, N);
    
    M = size(trajectory, 1);
    estimated_trajectory = zeros(M, 3);
    P_history = zeros(M, 3, 3);
    
    % Store initial estimate
    estimated_trajectory(1, :) = ekf.initial_estimate';
    P_history(1, :, :) = ekf.P_initial;
    
    % DEBUG: Start
    fprintf('\n=== DEBUG: EKF Localization Start ===\n');
    fprintf('M = %d trajectory points\n', M);
    fprintf('Initial initial_estimate: [%.4f, %.4f, %.4f]\n', ekf.initial_estimate);
    fprintf('Initial P_initial:\n');
    disp(ekf.P_initial);
    
    % EKF Main Loop
    for k = 1:(M-1)
        % Get current ground truth pose (for control input calculation)
        x_prev = trajectory(k, :)';
        x_curr = trajectory(k+1, :)';
        
        % DEBUG: Start of loop
        fprintf('\n=== k = %d ===\n', k);
        fprintf('x_prev = [%.4f, %.4f, %.4f]\n', x_prev);
        fprintf('x_curr = [%.4f, %.4f, %.4f]\n', x_curr);
        
        % Calculate control input from trajectory
        [v, omega, dt_actual] = ekf.computeControlInput(x_prev, x_curr, V);
        
        % DEBUG: After computeControlInput
        fprintf('v = %.4f, omega = %.4f, dt_actual = %.6f\n', v, omega, dt_actual);
        
        % ========== PREDICTION STEP ==========
        % Uses initial_estimate (x̂_k), stores to prediction (x̄_k+1)
        
        % DEBUG: Before predict
        fprintf('Before predict: initial_estimate = [%.4f, %.4f, %.4f]\n', ekf.initial_estimate);
        
        ekf.predict(v, omega, dt_actual);
        
        % DEBUG: After predict
        fprintf('After predict: prediction = [%.4f, %.4f, %.4f]\n', ekf.prediction);
        fprintf('After predict: P_prediction:\n');
        disp(ekf.P_prediction);
        
        % ========== UPDATE STEP ==========
        % Uses prediction (x̄_k+1), stores to corrected_prediction (x̂_k+1)
        
        % DEBUG: About to access ekf.prediction(1)
        fprintf('DEBUG: About to access ekf.prediction(1), size = [%d, %d]\n', size(ekf.prediction));
        
        robot_pose = [ekf.prediction(1), ekf.prediction(2), ekf.prediction(3)];
        
        % DEBUG: Before update
        fprintf('Before update: robot_pose = [%.4f, %.4f, %.4f]\n', robot_pose);
        fprintf('  prediction = [%.4f, %.4f, %.4f]\n', ekf.prediction);
        
        ekf.update(robot_pose);
        
        % DEBUG: After update
        fprintf('After update: corrected_prediction = [%.4f, %.4f, %.4f]\n', ekf.corrected_prediction);
        fprintf('After update: P_corrected:\n');
        disp(ekf.P_corrected);
        
        % Copy corrected_prediction back to initial_estimate for next iteration
        ekf.initial_estimate = ekf.corrected_prediction;
        ekf.P_initial = ekf.P_corrected;
        
        % Store
        estimated_trajectory(k+1, :) = ekf.corrected_prediction';
        P_history(k+1, :, :) = ekf.P_corrected;
    end
end
