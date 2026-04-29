function B = BeaconDetection(N, P, obsNoise)
%BEACONDETECTION - Mock beacon detection for testing
%
% INPUTS:
%   N - number of beacons to create (default: 4)
%   P - current robot position [x, y, theta] (optional)
%   obsNoise - observation noise [range_sigma, angle_sigma] (optional)
%
% OUTPUT:
%   B - structure with:
%     B.beacons - Nx2 matrix of beacon positions [x, y]
%     B.dn - distance noise sigma
%     B.an - angle noise sigma
%     B.X, B.Y - beacon positions (for compatibility)
%     B.d - measured distances (with noise, NaN if not visible)
%     B.a - measured angles (with noise, NaN if not visible)
%
% NOTES:
%   Beacons return NaN if too close or too far

% Default parameters
if nargin < 1 || isempty(N)
    N = 4;
end
if nargin < 3 || isempty(obsNoise)
    obsNoise = [0.5, 0.05];  % [distance noise (m), angle noise (rad)]
end

% Extract noise parameters
dn = obsNoise(1);  % distance noise sigma
an = obsNoise(2); % angle noise sigma

% Generate random beacon positions in first quadrant (2-25m range)
rng('shuffle');  % Different each run

beacons = zeros(N, 2);
for i = 1:N
    % Random position in first quadrant
    beacons(i, 1) = 2 + rand() * 23;  % x: 2-25m
    beacons(i, 2) = 2 + rand() * 23;  % y: 2-25m
end

% Initialize output structure
B = struct();
B.beacons = beacons;
B.dn = dn;
B.an = an;
B.X = beacons(:,1)';  % row vector for compatibility
B.Y = beacons(:,2)'; % row vector for compatibility
B.d = NaN(1,N);      % measured distances
B.a = NaN(1,N);      % measured angles

% If pose provided, compute measurements
if nargin >= 2 && ~isempty(P)
    % Extract robot pose
    rx = P(1);
    ry = P(2);
    rtheta = P(3);
    
    % Measurement range limits (like real sonar/beacon sensors)
    minRange = 0.3;   % minimum detection range (m)
    maxRange = 10.0;  % maximum detection range (m)
    
    % Compute measurements for each beacon
    for i = 1:N
        % True range and angle
        dx = beacons(i,1) - rx;
        dy = beacons(i,2) - ry;
        trueRange = sqrt(dx^2 + dy^2);
        trueAngle = atan2(dy, dx) - rtheta;
        
        % Normalize angle to [-pi, pi]
        trueAngle = atan2(sin(trueAngle), cos(trueAngle));
        
        % Check visibility (within range limits)
        if trueRange >= minRange && trueRange <= maxRange
            % Add Gaussian noise to measurements
            rangeNoise = dn * randn();
            angleNoise = an * randn();
            
            B.d(i) = trueRange + rangeNoise;
            B.a(i) = trueAngle + angleNoise;
            
            % Occasionally return NaN (simulating missed detection)
            % ~5% chance of missed detection
            if rand() < 0.05
                B.d(i) = NaN;
            end
        else
            % Out of range - return NaN
            B.d(i) = NaN;
            B.a(i) = NaN;
        end
    end
end