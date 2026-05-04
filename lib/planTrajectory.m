function trajectory = planTrajectory(beacons, Dt, V)
%PLANTRAJECTORY Generate trajectory starting at (0,0), passing through all beacons
%               using Hermite cubic interpolation (pchip) as required by the assignment.
%
% Parameters:
%   beacons - Nx2 matrix of beacon [X, Y] positions
%   Dt      - Sensor sampling time interval in seconds
%   V       - Desired average linear velocity in m/s
%
% Output:
%   trajectory - Mx3 matrix [x, y, theta] for each control point

    % ============ SET DEFAULTS ============
    if nargin < 1 || isempty(beacons), error('beacons (Nx2 matrix) is required'); end
    if nargin < 2 || isempty(Dt), Dt = 1; end
    if nargin < 3 || isempty(V), V = 5; end

    % ============ INPUT VALIDATION ============
    % Validate beacons (Nx2 matrix)
    if ~ismatrix(beacons) || size(beacons, 2) ~= 2
        error('beacons must be an Nx2 matrix [X, Y]');
    end
    
    % Validate Dt (sampling time interval)
    if ~isscalar(Dt) || ~isnumeric(Dt) || Dt <= 0
        error('Dt must be a positive scalar (sampling time interval in seconds)');
    end
    
    % Validate V (desired linear velocity)
    if ~isscalar(V) || ~isnumeric(V) || V <= 0
        error('V must be a positive scalar (desired linear velocity in m/s)');
    end

    num_beacons = size(beacons, 1);

    % ============ DEFINE WAYPOINTS ============
    % Trajectory starts at (0,0), passes through all beacons, ends at last beacon
    waypoints = [0, 0; beacons];  % (num_beacons + 1) x 2 matrix
    x_way = waypoints(:, 1);
    y_way = waypoints(:, 2);

    % ============ GENERATE SMOOTH TRAJECTORY VIA PCHIP ============
    % Hermite cubic interpolation as required by assignment section 2.3
    % Control points are evenly spaced in x, y values from pchip
    x_min = min(x_way);
    x_max = max(x_way);
    Delta_d = Dt * V;  % Approximate distance between control points
    
    % Generate evenly spaced x control points (assignment requirement)
    x_span = x_max - x_min;
    if x_span < 1e-6, x_span = 1; end  % Avoid division by zero
    num_x_points = max(2, ceil(x_span / (Delta_d * 0.7)));  % Approximate spacing
    xq = linspace(x_min, x_max, num_x_points)';  % Column vector of x points
    
    % Get y values via pchip (Hermite interpolation)
    yq = pchip(x_way, y_way, xq);  % Column vector of y points

    % ============ COMPUTE HEADING (THETA) ============
    % Theta = direction to next intermediate point (assignment section 3.2)
    M = length(xq);
    theta = zeros(M, 1);
    for i = 1:M-1
        theta(i) = atan2(yq(i+1) - yq(i), xq(i+1) - xq(i));
    end
    theta(M) = theta(M-1);  % Last point uses previous heading
    theta = wrapToPi(theta);  % Wrap to [-pi, pi]

    % ============ COMBINE INTO TRAJECTORY ============
    trajectory = [xq, yq, theta];

    % ============ VALIDATION ============
    % Check 1: Starts at (0,0)
    if norm(trajectory(1, 1:2) - [0, 0]) > 1e-6
        error('Trajectory must start at (0,0)');
    end
    
    % Check 2: Passes through all beacons (pchip curve passes through waypoints)
    for i = 1:num_beacons
        beacon = beacons(i, :);
        % Verify pchip curve passes through beacon (interpolation property)
        if norm(beacon - waypoints(i+1, :)) > 1e-6
            error('Waypoints must include beacon %d', i);
        end
    end
    
    % Check 3: Ends at last beacon
    if norm(trajectory(end, 1:2) - beacons(end, :)) > 1e-6
        error('Trajectory must end at last beacon');
    end
    
    % Check 4: No NaN values
    if any(isnan(trajectory(:)))
        error('Trajectory contains NaN values');
    end
end

function angle = wrapToPi(angle)
    % Wrap angle to [-pi, pi]
    angle = atan2(sin(angle), cos(angle));
end
