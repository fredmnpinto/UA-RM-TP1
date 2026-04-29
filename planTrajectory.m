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
    % Random waypoints - COMPLETELY INDEPENDENT of beacons
    
    rng('shuffle');
    
    % Random start point (in first quadrant, within 5m of origin)
    startX = rand() * 5;
    startY = rand() * 5;
    startPoint = [startX, startY];
    
    % Generate 2-3 random intermediate waypoints
    numWaypoints = 2 + floor(rand() * 2);  % 2 or 3 waypoints
    
    waypoints = zeros(numWaypoints, 2);
    for i = 1:numWaypoints
        waypoints(i, 1) = 2 + rand() * 18;  % x: 2-20m
        waypoints(i, 2) = 2 + rand() * 18;  % y: 2-20m
    end
    
    % Random final destination (past the last waypoint)
    lastWaypoint = waypoints(end, :);
    angle = rand() * 2 * pi;
    dist = 5 + rand() * 10;
    destPoint = lastWaypoint + [dist * cos(angle), dist * sin(angle)];
    
    % Ensure destination in first quadrant
    if destPoint(1) < 2, destPoint(1) = lastWaypoint(1) + 5; end
    if destPoint(2) < 2, destPoint(2) = lastWaypoint(2) + 5; end

    % ============ T003: LINEAR INTERPOLATION ============
    % Generate trajectory by interpolating through all waypoints
    Delta_d = Dt * V;
    trajectory = [];
    
    allPoints = [startPoint; waypoints; destPoint];
    
    for seg = 1:size(allPoints, 1) - 1
        p1 = allPoints(seg, :);
        p2 = allPoints(seg + 1, :);
        
        segDist = sqrt((p2(1)-p1(1))^2 + (p2(2)-p1(2))^2);
        nPoints = max(1, floor(segDist / Delta_d));
        
        t_vals = linspace(0, 1, nPoints + 1);
        x_seg = p1(1) + t_vals * (p2(1) - p1(1));
        y_seg = p1(2) + t_vals * (p2(2) - p1(2));
        
        for i = 1:length(x_seg)
            if i < length(x_seg)
                theta = atan2(y_seg(i+1) - y_seg(i), x_seg(i+1) - x_seg(i));
            else
                if seg < size(allPoints, 1) - 1
                    % Get direction to next segment
                    nextP = allPoints(seg + 2, :);
                    theta = atan2(nextP(2) - p2(2), nextP(1) - p2(1));
                else
                    theta = atan2(y_seg(i) - y_seg(i-1), x_seg(i) - x_seg(i-1));
                end
            end
            trajectory = [trajectory; x_seg(i), y_seg(i), theta];
        end
    end

    % ============ T005: TRAJECTORY ASSEMBLY ============
    % Use the actual start point (now randomized, not forced to origin)

    % ============ T006: VALIDATION ============
    % Check 1: Start at startPoint (verify x, y only; theta is calculated)
    if ~isequal(trajectory(1, 1:2), startPoint)
        error('Trajectory must start at startPoint');
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
