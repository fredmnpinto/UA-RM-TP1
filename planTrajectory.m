function trajectory = planTrajectory(N, Dt, V)
%PLAN Trajectory - Generate straight-line trajectory from origin to destination
%
% Parameters:
%   N  - Number of beacons (default: 4)
%   Dt - Sensor sampling time interval in seconds (default: 1)
%   V  - Desired linear velocity in m/s (default: 5)
%
% Output:
%   trajectory - Mx3 matrix [x, y, theta] for each point
%
% NOTE: Beacons are FIXED LANDMARKS in the environment. The robot passes BY them,
% not TO them. The trajectory is a straight-line path through the environment.

    % Set defaults
    if nargin < 1, N = 4; end
    if nargin < 2, Dt = 1; end
    if nargin < 3, V = 5; end

    % ====== INPUT VALIDATION ======
    % Validate N (number of beacons)
    if ~isscalar(N) || ~isnumeric(N) || N < 1 || N ~= floor(N)
        error('N must be a positive integer (number of beacons)');
    end
    
    % Validate Dt (sampling time interval)
    if ~isscalar(Dt) || ~isnumeric(Dt) || Dt <= 0
        error('Dt must be a positive scalar (sampling time interval in seconds)');
    end
    
    % Validate V (linear velocity)
    if ~isscalar(V) || ~isnumeric(V) || V <= 0
        error('V must be a positive scalar (desired linear velocity in m/s)');
    end

    % ============ T001: BEACON ACQUISITION ============
    % Get beacon positions (they are fixed landmarks in the environment)
    B = BeaconDetection(N);
    beacons = B.beacons;  % Nx2 matrix [x, y] positions

    % ============ T002: TRAJECTORY DEFINITION ============
    % Robot starts at origin and goes to a destination
    % The destination is chosen to be past the last beacon (extending the path)
    % This simulates the robot traversing through the environment
    
    startPoint = [0, 0];
    
    % Find the "center of mass" of beacons to determine general direction
    beaconCenter = mean(beacons, 1);
    
    % Destination: extend beyond the last beacon in the direction of travel
    % The robot travels in a straight line through the beacon field
    % Choose destination such that the path goes "through" the beacons area
    
    % For simplicity, let's define destination as past the furthest beacon
    % in the direction away from origin
    maxDist = 0;
    destPoint = startPoint;
    
    % Calculate destination as extending beyond all beacons
    % Find direction that passes through the beacon cluster
    for i = 1:size(beacons, 1)
        % Check if this beacon is "beyond" current destination in terms of distance from origin
        distFromOrigin = norm(beacons(i, :));
        if distFromOrigin > maxDist
            maxDist = distFromOrigin;
            % Destination is slightly beyond this beacon
            direction = beacons(i, :) / norm(beacons(i, :));
            destPoint = beacons(i, :) + direction * 5; % Go 5m beyond
        end
    end
    
    % If beacons are all at origin or very close, use default destination
    if maxDist < 1
        destPoint = [10, 10];  % Default diagonal path
    end

    % ============ T003: LINEAR INTERPOLATION ============
    % Use linear interpolation (not pchip) for straight-line path
    Delta_d = Dt * V;  % Distance between consecutive points
    
    % Calculate total distance
    dx_total = destPoint(1) - startPoint(1);
    dy_total = destPoint(2) - startPoint(2);
    totalDistance = sqrt(dx_total^2 + dy_total^2);
    
    % Number of intermediate points
    nPoints = max(1, floor(totalDistance / Delta_d));
    
    % Generate linearly spaced points
    t_vals = linspace(0, 1, nPoints + 1);
    
    x_pts = startPoint(1) + t_vals * dx_total;
    y_pts = startPoint(2) + t_vals * dy_total;

    % ============ T004: HEADING CALCULATION ============
    trajectory = [];
    for i = 1:length(x_pts)
        if i < length(x_pts)
            % Heading points toward next point
            theta = atan2(y_pts(i+1) - y_pts(i), x_pts(i+1) - x_pts(i));
        else
            % Last point: compute heading from previous segment
            theta = atan2(y_pts(i) - y_pts(i-1), x_pts(i) - x_pts(i-1));
        end
        trajectory = [trajectory; x_pts(i), y_pts(i), theta];
    end

    % ============ T005: TRAJECTORY ASSEMBLY ============
    % Ensure start is (0, 0, 0)
    trajectory(1, :) = [0, 0, 0];

    % ============ T006: VALIDATION ============
    % Check 1: Start at origin
    if ~isequal(trajectory(1, :), [0, 0, 0])
        error('Trajectory must start at origin');
    end

    % Check 2: No NaN values
    if any(isnan(trajectory(:)))
        error('Trajectory contains NaN values');
    end

    % Check 3: Heading range [-pi, pi]
    if any(trajectory(:, 3) < -pi | trajectory(:, 3) > pi)
        error('Heading angles out of range');
    end
    
    % Check 4: Points are approximately equally spaced
    distances = sqrt(diff(trajectory(:,1)).^2 + diff(trajectory(:,2)).^2);
    if any(abs(distances - Delta_d) > 0.01 * Delta_d)
        warning('Some trajectory points may not be evenly spaced');
    end
end
