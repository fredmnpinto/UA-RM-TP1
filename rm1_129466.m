function trajectory = rm1_129466(N, Dt, r, L, Vn, Wn, V)
%RM1_129466 - Main function for Mobile Robotics Assignment 1
%
% Parameters:
%   N  - Number of beacons (default: 4)
%   Dt - Sensor sampling time interval in seconds (default: 1)
%   r  - Radius of the robot's wheels in meters (default: 0.15)
%   L  - Separation/distance between wheels in meters (default: 1)
%   Vn - Uncertainty (sigma) in linear velocity in m/s (default: 0.1)
%   Wn - Uncertainty (sigma) in angular velocity in rad/s (default: 0.1)
%   V  - Desired average linear velocity in m/s (default: 5)
%
% Output:
%   trajectory - Mx3 matrix [x, y, theta] for each point

    % ============ SET DEFAULT PARAMETERS ============
    if nargin < 1 || isempty(N), N = 4; end
    if nargin < 2 || isempty(Dt), Dt = 1; end
    if nargin < 3 || isempty(r), r = 0.15; end
    if nargin < 4 || isempty(L), L = 1; end
    if nargin < 5 || isempty(Vn), Vn = 0.1; end
    if nargin < 6 || isempty(Wn), Wn = 0.1; end
    if nargin < 7 || isempty(V), V = 5; end

    % ============ INPUT VALIDATION ============
    % Validate N (number of beacons)
    if ~isscalar(N) || ~isnumeric(N) || N < 1 || N ~= floor(N)
        error('N must be a positive integer (number of beacons)');
    end
    
    % Validate Dt (sampling time interval)
    if ~isscalar(Dt) || ~isnumeric(Dt) || Dt <= 0
        error('Dt must be a positive scalar (sampling time interval in seconds)');
    end
    
    % Validate r (wheel radius)
    if ~isscalar(r) || ~isnumeric(r) || r <= 0
        error('r must be a positive scalar (wheel radius in meters)');
    end
    
    % Validate L (wheelbase)
    if ~isscalar(L) || ~isnumeric(L) || L <= 0
        error('L must be a positive scalar (wheel separation in meters)');
    end
    
    % Validate Vn (velocity uncertainty)
    if ~isscalar(Vn) || ~isnumeric(Vn) || Vn < 0
        error('Vn must be a non-negative scalar (velocity uncertainty)');
    end
    
    % Validate Wn (angular velocity uncertainty)
    if ~isscalar(Wn) || ~isnumeric(Wn) || Wn < 0
        error('Wn must be a non-negative scalar (angular velocity uncertainty)');
    end
    
    % Validate V (desired linear velocity)
    if ~isscalar(V) || ~isnumeric(V) || V <= 0
        error('V must be a positive scalar (desired linear velocity in m/s)');
    end

    % ============ PHASE 1: TRAJECTORY PLANNING ============
    fprintf('Phase 1: Generating trajectory\n');
    fprintf('  N = Dt = %.2f s, V = %.2f m/s\n', Dt, V);
    
    % Call planTrajectory function
    trajectory = planTrajectory(Dt, V, 10);
    
    fprintf('  Generated %d trajectory points\n', size(trajectory, 1));

    % ============ DISPLAY TRAJECTORY ============
    fprintf('\nTrajectory summary:\n');
    fprintf('  Start: [%.2f, %.2f, %.2f] rad\n', trajectory(1, :));
    fprintf('  End:   [%.2f, %.2f, %.2f] rad\n', trajectory(end, :));
    fprintf('  Total distance: %.2f m\n', sum(sqrt(diff(trajectory(:,1)).^2 + diff(trajectory(:,2)).^2)));

    % Display first few and last few points for verification
    if size(trajectory, 1) <= 10
        fprintf('\nFull trajectory:\n');
        disp(trajectory);
    else
        fprintf('\nFirst 5 points:\n');
        disp(trajectory(1:5, :));
        fprintf('Last 5 points:\n');
        disp(trajectory(end-4:end, :));
    end

    % ============ VISUALIZATION ============
    fprintf('\nGenerating visualization...\n');
    
    % Get beacon positions (fixed landmarks in environment)
    B = BeaconDetection(N);
    
    % Collect beacon X and Y coordinates from struct array
    % B.X returns a comma-separated list, so we use [B.X] to collect into vector
    X_vec = [B.X];  % Row vector of all X coordinates
    Y_vec = [B.Y];  % Row vector of all Y coordinates
    beacons = [X_vec(:), Y_vec(:)];  % Nx2 matrix [x, y]
    
    % Create figure for visualization
    figure('Name', 'Robot Trajectory with Beacon Detection', 'NumberTitle', 'off');
    hold on;
    grid on;
    axis equal;
    xlabel('X (m)');
    ylabel('Y (m)');
    title(sprintf('Robot Trajectory - %d Beacons (Straight-line path)', N));
    
    % Plot beacons as orange circles with labels (FIXED LANDMARKS)
    % Plot all beacons at once to create a single graphics object for legend
    hBeacons = plot(beacons(:, 1), beacons(:, 2), 'o', 'MarkerSize', 12, 'MarkerFaceColor', [1, 0.5, 0], 'MarkerEdgeColor', [1, 0.5, 0], 'LineWidth', 1.5);
    for i = 1:size(beacons, 1)
        text(beacons(i,1) + 0.3, beacons(i,2) + 0.3, sprintf('B%d', i), 'FontSize', 8, 'Color', [1, 0.5, 0]);
    end
    
    % Plot trajectory as blue line with dots at each point
    % Plot as a single combined plot to create one graphics object
    hTrajectory = plot(trajectory(:, 1), trajectory(:, 2), 'b-', 'LineWidth', 2);
    hold on;
    plot(trajectory(:, 1), trajectory(:, 2), 'b.', 'MarkerSize', 6, 'HandleVisibility', 'off');
    
    % Create hgtransform for robot positioning (allows efficient transform updates)
    hg = hgtransform;
    
    % Draw robot at origin using differential drive - type 1
    robotScale = 0.015;  % Scale factor for visibility
    [P, hRobot] = DrawRobot(1, robotScale);
    set(hRobot, 'Parent', hg);  % Parent robot to hgtransform
    
    % Get start position
    startX = trajectory(1, 1);
    startY = trajectory(1, 2);
    startTheta = trajectory(1, 3);
    
    % Transform robot to start position using hgtransform
    T_start = makehgtform('translate', [startX, startY, 0], 'zrotate', startTheta);
    hg.Matrix = T_start;
    
    % Create beacon visualization object
    beaconVis = BeaconVisualization(beacons, gca);
    
    % Create a sample detection line for legend (matching BeaconVisualization style)
    hDetection = plot(NaN, NaN, 'r--', 'LineWidth', 1);
    
    % Add legend for visualization elements using explicit handles
    legend([hBeacons, hTrajectory, hRobot, hDetection], ...
          {'Beacons', 'Trajectory', 'Robot', 'Detection Lines'}, ...
          'Location', 'best');
    
    % Animate robot moving along trajectory
    fprintf('  Animating robot along trajectory...\n');
    fprintf('  Showing detection lines from robot to beacons...\n');
    
    pause

    % Animate along trajectory - one frame per trajectory point
    for i = 1:size(trajectory, 1)
        % Get current position from trajectory
        x = trajectory(i, 1);
        y = trajectory(i, 2);
        theta = trajectory(i, 3);
        
        % Update robot position using hgtransform (translate + rotate)
        T = makehgtform('translate', [x, y, 0], 'zrotate', theta);
        hg.Matrix = T;
        
        % Update beacon detection visualization
        beaconVis.update(x, y);
        
        % Use proper MATLAB animation: drawnow limitrate instead of pause
        drawnow limitrate;
        pause(0.05);  % Small pause to make animation visible
    end
    
    fprintf('  Visualization complete.\n');

    % ============ SAVE PARAMETERS FOR LATER PHASES ============
    % Store parameters in base workspace for use in Simulation phase
    assignin('base', 'rm1_N', N);
    assignin('base', 'rm1_Dt', Dt);
    assignin('base', 'rm1_r', r);
    assignin('base', 'rm1_L', L);
    assignin('base', 'rm1_Vn', Vn);
    assignin('base', 'rm1_Wn', Wn);
    assignin('base', 'rm1_V', V);
    assignin('base', 'rm1_trajectory', trajectory);


    fprintf('\nProceed to phase 2?\nPress ENTER\n\n')
    pause

    % ============ PHASE 2: EKF LOCALIZATION ============
    fprintf('\n==============================================\n');
    fprintf('Phase 2: EKF Localization\n');
    fprintf('==============================================\n');
    
    fprintf('Running EKF localization with %d beacons...\n', N);
    fprintf('  Vn = %.3f m/s, Wn = %.3f rad/s\n', Vn, Wn);
    fprintf('  V = %.2f m/s\n', V);
    
    % Run EKF localization
    [estimated_trajectory, P_history] = ekfLocalization(trajectory, N, Dt, Vn, Wn, V);
    
    % Save results to loc_129466.txt
    saveLocalizationResults(estimated_trajectory, 'loc_129466.txt');
    
    % Display summary
    fprintf('\nLocalization Results:\n');
    fprintf('  Estimated trajectory: %d points\n', size(estimated_trajectory, 1));
    fprintf('  First point: [%.6f, %.6f, %.6f]\n', estimated_trajectory(1, :));
    fprintf('  Last point:  [%.6f, %.6f, %.6f]\n', estimated_trajectory(end, :));
    
    % Calculate and display error statistics
    position_error = sqrt((trajectory(:,1) - estimated_trajectory(:,1)).^2 + ...
                         (trajectory(:,2) - estimated_trajectory(:,2)).^2);
    fprintf('\nError Statistics:\n');
    fprintf('  Mean position error: %.4f m\n', mean(position_error));
    fprintf('  Max position error:  %.4f m\n', max(position_error));
    
    % Plot ground truth vs estimate
    figure('Name', 'EKF Localization Results', 'NumberTitle', 'off');
    hold on;
    grid on;
    axis equal;
    xlabel('X (m)');
    ylabel('Y (m)');
    title(sprintf('EKF Localization - %d Beacons', N));
    
    % Plot ground truth
    plot(trajectory(:, 1), trajectory(:, 2), 'b-', 'LineWidth', 2);
    
    % Plot EKF estimate
    plot(estimated_trajectory(:, 1), estimated_trajectory(:, 2), 'r--', 'LineWidth', 2);
    
    % Plot beacons
    plot(beacons(:, 1), beacons(:, 2), 'o', 'MarkerSize', 12, ...
         'MarkerFaceColor', [1, 0.5, 0], 'MarkerEdgeColor', [1, 0.5, 0], 'LineWidth', 1.5);
    
    legend('Ground Truth', 'EKF Estimate', 'Beacons', 'Location', 'best');
    
    % Plot start and end points
    plot(trajectory(1,1), trajectory(1,2), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
    plot(estimated_trajectory(1,1), estimated_trajectory(1,2), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    plot(trajectory(end,1), trajectory(end,2), 'bs', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
    plot(estimated_trajectory(end,1), estimated_trajectory(end,2), 'rs', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    
    % Add legend for start/end
    legend('Ground Truth', 'EKF Estimate', 'Beacons', ...
           'Start (Truth)', 'Start (EKF)', 'End (Truth)', 'End (EKF)', ...
           'Location', 'best');
end
