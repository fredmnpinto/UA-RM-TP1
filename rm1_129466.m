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

    % ============ ADD LIB DIRECTORY TO PATH ============
    addpath('lib');

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

    % ============ GET BEACON POSITIONS ============
    % Get beacon positions (fixed landmarks in environment)
    B = BeaconDetection(N);
    
    % Collect beacon X and Y coordinates from struct array
    % B.X returns a comma-separated list, so we use [B.X] to collect into vector
    X_vec = [B.X];  % Row vector of all X coordinates
    Y_vec = [B.Y];  % Row vector of all Y coordinates
    beacons = [X_vec(:), Y_vec(:)];  % Nx2 matrix [x, y]

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

    % ============ MERGED VISUALIZATION ============
    fprintf('\nGenerating merged visualization...\n');
    
    % Create single figure with 2 subplots
    figure('Position', [100, 100, 1200, 500]);
    
    % ========== SUBPLOT 1: Trajectory + Robot + EKF ==========
    ax1 = subplot(1, 2, 1);
    hold on;
    grid on;
    
    % Plot beacons (orange circles)
    hBeacons = plot(beacons(:,1), beacons(:,2), 'o', ...
        'MarkerSize', 12, 'MarkerFaceColor', [1, 0.5, 0], ...
        'MarkerEdgeColor', [1, 0.5, 0], 'LineWidth', 1.5);
    
    % Plot ground truth trajectory (blue)
     hGroundTruth = plot(trajectory(:,1), trajectory(:,2), 'b-', 'LineWidth', 2);
    plot(trajectory(:,1), trajectory(:,2), 'b.', 'MarkerSize', 6, ...
        'HandleVisibility', 'off');
    
    % Plot start point
    plot(trajectory(1,1), trajectory(1,2), 'go', ...
        'MarkerSize', 10, 'MarkerFaceColor', 'g');
    
    % Plot end point
    plot(trajectory(end,1), trajectory(end,2), 'ro', ...
        'MarkerSize', 10, 'MarkerFaceColor', 'r');
    
    % Robot visualization (use last position)
    hg = hgtransform;
    [P, hRobot] = DrawRobot(1, 0.01);
    set(hRobot, 'Parent', hg);
    T = makehgtform('translate', [trajectory(end,1), trajectory(end,2), 0], ...
        'zrotate', trajectory(end,3));
    hg.Matrix = T;
    
    % Initialize beacon lines (will be updated in animation)
    % Store handles for updating - initialize with NaN data
    beaconLineHandles = gobjects(N, 1);
    for i = 1:N
        beaconLineHandles(i) = line(ax1, NaN, NaN, ...
            'Color', [1, 0.5, 0], 'LineStyle', '--', 'LineWidth', 1, ...
            'HandleVisibility', 'off');
    end
    
    % Create animated line for EKF estimate (progressive drawing)
    hEKF = animatedline(ax1, 'Color', 'r', 'LineStyle', '--', 'LineWidth', 2, ...
                       'DisplayName', 'EKF Estimate');
    
    % Labels and legend
    xlabel('X (m)');
    ylabel('Y (m)');
    title('Robot Trajectory: Ground Truth (Blue) vs EKF Estimate (Red)');
    legend([hBeacons, hRobot, hGroundTruth, hEKF], ...
            {'Beacons', 'Robot', 'Ground Truth', 'EKF Estimate'}, ...
            'Location', 'best');
    axis equal;
    
    % ========== SUBPLOT 2: Error Plot ==========
    ax2 = subplot(1, 2, 2);
    hold on;
    grid on;
    
    % Calculate position error
    pos_error = sqrt((trajectory(:,1) - estimated_trajectory(:,1)).^2 + ...
                       (trajectory(:,2) - estimated_trajectory(:,2)).^2);
    
    % Create animated line for error plot (progressive drawing)
    hError = animatedline(ax2, 'Color', 'b', 'LineWidth', 2, ...
                         'DisplayName', 'Position Error');
    ylabel('Position Error (m)');
    xlabel('Trajectory Point Index');
    title('EKF Localization Error');
    xlim([1, size(trajectory, 1)]);
    ylim([0, max(pos_error) * 1.1]);
    legend([hError], {'Position Error'}, 'Location', 'best');
    
    % ========== ANIMATION: Robot Moving with EKF ==========
    % Animate robot along trajectory with EKF estimate
    fprintf('  Animating robot with EKF estimate...\n');
    
    for i = 1:size(trajectory, 1)
        % Update robot position (ground truth)
        T = makehgtform('translate', [trajectory(i,1), trajectory(i,2), 0], ...
            'zrotate', trajectory(i,3));
        hg.Matrix = T;
        
        % Update beacon lines from CURRENT position (using SAME call as EKF)
        current_pose = [trajectory(i,1), trajectory(i,2), trajectory(i,3)];
        B_current = BeaconDetection(N, current_pose);
        
        % Update beacon line positions in ax1
        for j = 1:N
            if ~isnan(B_current(j).d) && ~isnan(B_current(j).a)
                set(beaconLineHandles(j), 'XData', [trajectory(i,1), beacons(j,1)], ...
                     'YData', [trajectory(i,2), beacons(j,2)]);
            else
                set(beaconLineHandles(j), 'XData', NaN, 'YData', NaN);
            end
        end
        
        % ========== PROGRESSIVE EKF PLOT ==========
        % Add current EKF estimate to progressive line
        addpoints(hEKF, estimated_trajectory(i,1), estimated_trajectory(i,2));
        
        % Update error plot (show current point) in ax2
        pos_error_i = sqrt((trajectory(i,1) - estimated_trajectory(i,1))^2 + ...
                          (trajectory(i,2) - estimated_trajectory(i,2))^2);
        addpoints(hError, i, pos_error_i);
        
        drawnow limitrate;
        pause(0.1);
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
end
