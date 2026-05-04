%% Complex Trajectory EKF Localization Test
% 5-segment trajectory: straight, turn, straight, turn, straight

% Add lib directory to path
addpath('src');

% EKF Constructor takes (Vn, Wn, N) only (lib/EKF.m line 20)
Vn = 0.1;       % Linear velocity noise std (m/s)
Wn = 0.05;      % Angular velocity noise std (rad/s)
N = 6;          % Number of beacons (matches BeaconDetection.p)
ekf = EKF(Vn, Wn, N);

% Set initial heading to northeast (45° = pi/4 radians)
ekf.initial_estimate = [0; 0; pi/4];  % [x=0, y=0, θ=45°]

% Motion parameters
dt = 0.1;       % Timestep (s)
num_steps = 100;  % More steps for complex trajectory

% Define complex trajectory with 5 segments (20 steps each)
% Pre-compute heading profile for smooth trajectory
v_const = 1.0;  % Constant linear velocity m/s
v_vals = v_const * ones(num_steps, 1);
real_theta_profile = zeros(num_steps, 1);

% Segment 1 (steps 1-20): Straight northeast (heading pi/4)
real_theta_profile(1:20) = pi/4;

% Segment 2 (steps 21-40): Turn right from pi/4 to -pi/2 (south)
for i = 21:40
    t = (i - 21) / 19;  % t goes from 0 to 1
    real_theta_profile(i) = pi/4 + t * (-pi/2 - pi/4);
end

% Segment 3 (steps 41-60): Straight south (heading -pi/2)
real_theta_profile(41:60) = -pi/2;

% Segment 4 (steps 61-80): Turn left from -pi/2 to 3*pi/4 (northwest)
for i = 61:80
    t = (i - 61) / 19;  % t goes from 0 to 1
    real_theta_profile(i) = -pi/2 + t * (3*pi/4 - (-pi/2));
end

% Segment 5 (steps 81-100): Straight northwest (heading 3*pi/4)
real_theta_profile(81:100) = 3*pi/4;

% Compute omega from theta profile (derivative)
omega_vals = zeros(num_steps, 1);
for i = 2:num_steps
    omega_vals(i) = (real_theta_profile(i) - real_theta_profile(i-1)) / dt;
end

% Initialize trajectory storage
real_traj = zeros(num_steps + 1, 2);  % Real trajectory (ground truth)
ekf_traj = zeros(num_steps + 1, 2);   % EKF estimated trajectory
real_theta = real_theta_profile(1);  % Start heading northeast (45°)
ekf_traj(1, :) = [0, 0];  % Initial EKF estimate

fprintf('Northeast Straight Line Test (2m total, θ=45°)\n');
fprintf('Step | x (m)     | y (m)     | θ (rad)   | x_var      | y_var      | θ_var\n');
fprintf('-------------------------------------------------------------------------------\n');

for step = 1:num_steps
    % Current velocity commands
    v_curr = v_vals(step);
    omega_curr = omega_vals(step);
    curr_theta = real_theta_profile(step);

    % Real trajectory (ground truth): move in direction of pre-computed heading
    real_traj(step+1, :) = real_traj(step, :) + [v_curr * dt * cos(curr_theta), v_curr * dt * sin(curr_theta)];

    % Prediction: uses current initial_estimate (propagated from prior update)
    ekf.predict(v_curr, omega_curr, dt);

    % Update: use predicted pose for beacon detection
    ekf.update(ekf.prediction);

    % Store EKF corrected position
    ekf_traj(step+1, :) = ekf.corrected_prediction(1:2)';

    % Log corrected state/covariance from update
    fprintf('%4d | %.4f     | %.4f     | %.4f     | %.6f | %.6f | %.6f\n', ...
        step, ...
        ekf.corrected_prediction(1), ekf.corrected_prediction(2), ekf.corrected_prediction(3), ...
        ekf.P_corrected(1,1), ekf.P_corrected(2,2), ekf.P_corrected(3,3));
end

% Final validation
fprintf('\nFinal Position: [%.4f, %.4f] (expected ~[1.414, 1.414] for 2m at 45°)\n', ...
    ekf.corrected_prediction(1), ekf.corrected_prediction(2));
fprintf('Final Heading: %.4f rad (expected ~0.7854 rad = 45°)\n', ekf.corrected_prediction(3));

% Plot trajectories
figure;
plot(real_traj(:,1), real_traj(:,2), 'b-', 'LineWidth', 2); hold on;
plot(ekf_traj(:,1), ekf_traj(:,2), 'r--', 'LineWidth', 2);
scatter(real_traj(1,1), real_traj(1,2), 100, 'b', 'filled');
scatter(ekf_traj(1,1), ekf_traj(1,2), 100, 'r', 'filled');
xlabel('X (m)'); ylabel('Y (m)');
title('Robot Trajectory vs EKF Estimation');
legend('Real Trajectory', 'EKF Estimation', 'Location', 'best');
grid on; axis equal; hold off;
