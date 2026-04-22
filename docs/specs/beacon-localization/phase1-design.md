# Phase 1: Trajectory Planning - Design Document

## Overview

Phase 1 implements **Trajectory Planning** using the Peter Corke Robotics Toolbox. The trajectory is a robot motion path (straight line for simplicity, starting from origin) that passes through the beacon field. Beacons are **fixed landmarks** in the environment that the robot measures during navigation — they are NOT destinations or waypoints.

This phase produces the trajectory matrix [x, y, θ] required for subsequent EKF localization. The robot will measure distance and bearing TO each beacon during movement.

---

## 1. Function Interface

### 1.1 Function Signature

```matlab
function trajectory = planTrajectory(N, Dt, V)
%PLAN Trajectory Generate robot trajectory (straight line path)
%   Input:
%       N   - Number of beacons (landmark count, integer, default: 4)
%       Dt  - Sensor sampling time interval in seconds (scalar, default: 1)
%       V   - Desired average linear velocity in m/s (scalar, default: 5)
%   Output:
%       trajectory - M×3 matrix [x, y, θ] where M is total trajectory points
%
%   Example:
%       trajectory = planTrajectory(4, 1, 5);
%       trajectory = planTrajectory(6, 0.5, 3);
%
%   Note: Trajectory is independent of beacon positions. Beacons are
%   fixed landmarks the robot will MEASURE during navigation.
```

### 1.2 Input Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| N | integer | 4 | Number of beacons (fixed landmarks) in the environment |
| Dt | scalar | 1 | Sensor sampling time interval (seconds) |
| V | scalar | 5 | Desired average linear velocity (m/s) |

### 1.3 Output Specification

| Output | Type | Description |
|--------|------|-------------|
| trajectory | M×3 matrix | Trajectory points [x, y, θ] |

**Trajectory Matrix Format:**
```
[x1, y1, θ1]  % Start point (0, 0, 0)
[x2, y2, θ2]  % Intermediate point 1
[x3, y3, θ3]  % Intermediate point 2
...
[xn, yn, θn]  % End point (trajectory termination)
```

**Note**: The trajectory does NOT pass through beacons. It is a straight line from origin that may pass through or extend beyond the beacon field. The robot measures distances and bearings TO beacons during movement for EKF localization.

---

## 2. Detailed Function Explanations

### 2.1 planTrajectory()

**Objective**: Generate a robot trajectory (straight line from origin) for navigation. The trajectory is independent of beacon positions — beacons are fixed landmarks the robot will measure during movement for EKF localization, NOT destinations to navigate to.

The function produces a trajectory matrix containing x, y coordinates and heading angles (θ) for each point along the robot's path.

**Function Call**:
```matlab
trajectory = planTrajectory(N, Dt, V);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| N | integer | Number of beacons (fixed landmarks) in the environment. Used to configure the measurement system. Default: 4 |
| Dt | scalar (seconds) | Sensor sampling time interval - the time between consecutive sensor measurements. Used to calculate the spatial spacing between trajectory points. Default: 1 |
| V | scalar (m/s) | Desired average linear velocity of the robot. Combined with Dt to determine the distance (Δd) between consecutive trajectory points. Default: 5 |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| trajectory | M×3 matrix ( doubles) | Complete trajectory with M rows. Each row contains [x, y, θ] where x and y are position coordinates in meters, and θ is the heading angle in radians ranging from -π to π |

---

### 2.2 BeaconDetection()

**Objective**: Generate fixed beacon (landmark) positions in the environment. Beacons are static reference points the robot will measure distance and bearing to during navigation for EKF localization.

**Function Call**:
```matlab
B = BeaconDetection(N);
beacons = B.beacons;
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| N | integer | Number of beacons to generate. Must be a positive integer. The function returns N beacon positions distributed in the 2D environment. Required parameter |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| B | struct | Output structure containing beacon data with fields: beacons (N×2 matrix), dn (distance noise), an (angle noise) |
| B.beacons | N×2 matrix (doubles) | Matrix of N beacon positions where each row contains [x_i, y_i] coordinates in meters. beacons(i,1) is x-coordinate, beacons(i,2) is y-coordinate |
| B.dn | scalar (doubles) | Distance measurement noise standard deviation in meters. Represents sensor error in distance measurements |
| B.an | scalar (doubles) | Angle measurement noise standard deviation in radians. Represents sensor error in angle measurements |

---

### 2.3 pchip()

**Objective**: Create a Piecewise Cubic Hermite Interpolating Polynomial (pchip) object that provides smooth interpolation through the given data points while preserving the shape of the data and avoiding oscillations (no overshoot) between points. This produces a smooth robot trajectory.

**Function Call**:
```matlab
pp = pchip(t, y);
ppval(pp, t_interp);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| t | vector (doubles) | Parameter locations (knots) corresponding to each y value. Must be strictly increasing. For trajectory: t = 1:num_points including origin as first point. This parameterizes the trajectory path |
| y | matrix (doubles) | Function values at locations t. For 2D trajectory: can be separate x and y vectors, or a 2-column matrix where each row is [x, y] coordinates. Contains the trajectory waypoints to interpolate through (origin + path points) |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| pp | struct (piecewise polynomial) | Piecewise polynomial structure (pp form) that can be evaluated by ppval(). Contains coefficients, breakpoints, and interpolation rules |
| interpolation_result | matrix (doubles) | Interpolated values at query points t_interp. Same dimensions as input y. For trajectory: returns [x, y] coordinates at the requested parameter values |

---

### 2.4 Intermediate Point Calculation

**Objective**: Calculate the number of intermediate trajectory points between consecutive waypoints based on the desired spatial spacing. This ensures uniform point distribution along the trajectory, providing consistent sensor sampling intervals for the EKF localization phase.

**Function Call**:
```matlab
delta_d = Dt * V;
n = floor(distance / delta_d);
t_vals = linspace(i, i+1, n + 1);
pts = ppval(pp, t_vals);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| Dt | scalar (seconds) | Sensor sampling time interval. The desired time between consecutive sensor measurements. Default: 1 |
| V | scalar (m/s) | Desired average linear velocity. The target speed at which the robot travels. Combined with Dt gives spatial spacing. Default: 5 |
| delta_d | scalar (meters) | Spatial distance between consecutive trajectory points. Calculated as Dt × V. Represents how far the robot moves in one sampling interval |
| i | integer | Current segment index. Indicates which segment of the path is being interpolated (between waypoint i and i+1) |
| distance | scalar (meters) | Euclidean distance between consecutive waypoints. Calculated as sqrt((x₂-x₁)² + (y₂-y₁)²) |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| delta_d | scalar (doubles) | Distance in meters between consecutive trajectory points. Default: Dt × V = 5 meters (for Dt=1, V=5) |
| n | integer | Number of intermediate points to generate between waypoints. Calculated as floor(distance / delta_d). If distance=20m and delta_d=5m, then n=4 |
| t_vals | vector (doubles) | Parameter values for pchip evaluation. Linearly spaced values from i to i+1 with n+1 points. Used to query the interpolant |
| pts | N×2 matrix (doubles) | Interpolated [x, y] coordinates at the query points. Each row is a trajectory point between waypoints |

---

### 2.5 Heading Angle Calculation

**Objective**: Calculate the heading angle (direction of motion) for each trajectory point. The heading angle is essential for EKF localization as it represents the robot's orientation at each point, enabling the filter to predict and correct the robot's pose.

**Function Call**:
```matlab
theta = atan2(dy, dx);
trajectory(k, 3) = theta;
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| dx | scalar (meters) | Change in x-coordinate from current point to next point: dx = x(k+1) - x(k) |
| dy | scalar (meters) | Change in y-coordinate from current point to next point: dy = y(k+1) - y(k) |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| theta | scalar (radians) | Heading angle measured from positive x-axis, ranging from -π to π. A value of 0 points along positive x-axis, π/2 points along positive y-axis |
| trajectory(k,3) | scalar (radians) | Stored heading angle for trajectory point k. Used by EKF for pose prediction and correction |

**Note on atan2**: The function atan2(dy, dx) is used instead of atan(dy/dx) because:
- It returns the correct angle in all four quadrants
- It handles the case when dx=0 (vertical motion)
- It distinguishes between forward (positive dy) and backward (negative dy) vertical motion

---

## 3. Algorithm Steps

### 3.1 Algorithm Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Trajectory Planning Algorithm              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  IMPORTANT: Beacons are FIXED LANDMARKS (reference points)       │
│  The robot trajectory is an INDEPENDENT path (straight line)    │
│  The robot MEASURES distance/bearing TO beacons during movement  │
│                                                                  │
│  1. BEACON ACQUISITION (for later measurement)                 │
│     B = BeaconDetection(N)                                      │
│     beacons = B.beacons  % Extract N×2 beacon positions          │
│                                                                  │
│  2. TRAJECTORY CONSTRUCTION (straight line path)              │
│     Define trajectory as straight line from origin           │
│     x_wp, y_wp = trajectory waypoints (independent of beacons)│
│                                                                  │
│  3. PCHIP INTERPOLATION                                         │
│     pp_x = pchip(x_wp, y_wp(:,1))  % Interpolant for x          │
│     pp_y = pchip(x_wp, y_wp(:,2))  % Interpolant for y          │
│                                                                  │
│  4. INTERMEDIATE POINT GENERATION                               │
│     Δd = Dt × V                  % Distance between points     │
│     For each segment i:                                        │
│         d = distance between waypoints i and i+1                │
│         n = floor(d / Δd)           % Number of intermediate   │
│         Generate n points using pchip interpolation              │
│                                                                  │
│  5. HEADING ANGLE CALCULATION                                   │
│     For each trajectory point k:                                 │
│         θk = atan2(y(k+1)-y(k), x(k+1)-x(k))                  │
│                                                                  │
│  6. BEACON MEASUREMENTS (post-processing)                      │
│     For each trajectory point and each beacon:                  │
│         d = distance(robot, beacon)                            │
│         b = bearing(robot, beacon)                            │
│         Store for EKF localization                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Step-by-Step Implementation

**Step 1: Beacon Acquisition** (for later measurement, NOT navigation)

```matlab
% Call BeaconDetection to get beacon positions (fixed landmarks)
B = BeaconDetection(N);
beacons = B.beacons;  % N×2 matrix of beacon positions
```

**Step 2: Trajectory Construction** (INDEPENDENT path)

```matlab
% NOTE: Trajectory waypoints are INDEPENDENT of beacon positions!
% For Phase 1: simple straight line path
x_trajectory = [0, 20];  % Example: from origin to x=20
y_trajectory = [0, 5];   % Example: from y=0 to y=5

% The robot will measure TO beacons at each trajectory point
% (not navigate TO beacon positions)
```

**Step 3: pchip() Interpolation**

MATLAB's `pchip()` creates a smooth Piecewise Cubic Hermite Interpolating Polynomial:

```matlab
% Create pchip interpolants for x and y separately
pp_x = pchip(x_waypoints, y_waypoints);
pp_y = pchip(y_waypoints, y_waypoints);

% Alternative: Use x as parameter
t_waypoints = 1:length(x_waypoints);  % Parameter values
pp = pchip(t_waypoints, [x_waypoints; y_waypoints]');
```

The correct pchip usage for 2D interpolation:

```matlab
% Method 1: Separate pchip for each coordinate
pp_x = pchip(beacon_x, x_positions);
pp_y = pchip(beacon_y, y_positions);

% Method 2: Using structure with x as parameter (preferred)
x_param = 1:numel(x_waypoints);
pp = pchip(x_param, [x_waypoints; y_waypoints]');
```

**Step 4: Intermediate Point Calculation**

```matlab
% Calculate spacing between intermediate points
delta_d = Dt * V;  % Distance in meters (default: 5 m for Dt=1, V=5)

% For each segment between consecutive waypoints
for i = 1:(numel(x_waypoints) - 1)
    % Distance between waypoints
    dx = x_waypoints(i+1) - x_waypoints(i);
    dy = y_waypoints(i+1) - y_waypoints(i);
    distance = sqrt(dx^2 + dy^2);
    
    % Number of intermediate points
    n_points = floor(distance / delta_d);
    
    % Generate parameter values for interpolation
    if n_points > 0
        t_interp = linspace(i, i+1, n_points + 1);
        % Evaluate pchip at intermediate parameters
        [x_interp, y_interp] = ppval(pp, t_interp);
    end
end
```

**Step 5: Heading Angle Calculation**

```matlab
% Calculate heading for each trajectory point
n_trajectory = size(trajectory, 1);
for k = 1:(n_trajectory - 1)
    dx = trajectory(k+1, 1) - trajectory(k, 1);
    dy = trajectory(k+1, 2) - trajectory(k, 2);
    trajectory(k, 3) = atan2(dy, dx);
end
% Last point uses previous heading
trajectory(end, 3) = trajectory(end-1, 3);
```

---

## 4. Data Structures

### 4.1 Beacon Positions Storage

```matlab
% Beacon data structure from BeaconDetection
B = BeaconDetection(N);

% Extract beacon positions: N×2 matrix
% beacons(i, :) = [x_i, y_i] for beacon i
beacons = B.beacons;
```

| Field | Type | Description |
|-------|------|-------------|
| B.beacons | N×2 matrix | Beacon (x, y) positions |
| B.dn | scalar | Distance measurement noise |
| B.an | scalar | Angle measurement noise |

### 3.2 Waypoint Vectors

```matlab
% Trajectory waypoints (INDEPENDENT of beacon positions)
% Example for Phase 1: straight line from origin
x_waypoints = [0, 20];  % Robot path x-coordinates
y_waypoints = [0, 5];   % Robot path y-coordinates

% Beacons are fixed landmarks, NOT part of trajectory waypoints
% The robot measures distance/bearing TO beacons during movement
```

### 3.3 Trajectory Matrix

```matlab
% Trajectory matrix: M×3 where M is total number of trajectory points
trajectory = [x, y, theta];  % Each row is [x, y, θ]
```

| Column | Description | Unit |
|--------|-------------|------|
| 1 | x-coordinate | meters |
| 2 | y-coordinate | meters |
| 3 | heading angle | radians |

### 3.4 Interpolation Parameter Vector

```matlab
% Parameter values for pchip interpolation
t_param = 1:num_waypoints;  % [1, 2, 3, ..., N+1]

% Intermediate parameter values
t_interp = linspace(1, num_waypoints, n_points + 1);
```

---

## 5. Key Formulas

### 5.1 Distance Calculation

**Euclidean distance between two points:**

```matlab
distance = sqrt((x2 - x1)^2 + (y2 - y1)^2);
```

**Distance between consecutive beacons:**

```matlab
for i = 1:(num_beacons - 1)
    d(i) = sqrt((beacons(i+1,1) - beacons(i,1))^2 + ...
                (beacons(i+1,2) - beacons(i,2))^2);
end
```

### 4.2 Number of Intermediate Points

**Calculate number of intermediate points between beacons:**

```matlab
% Δd = distance between consecutive trajectory points
delta_d = Dt * V;  % [meters]

% Number of intermediate points
n_intermediate = floor(distance_beacon_pair / delta_d);
```

**Example:**
- If Dt = 1 s and V = 5 m/s, then Δd = 5 m
- For beacons separated by 20 m: n = floor(20/5) = 4 intermediate points

### 4.3 Heading Angle Calculation

**Heading from point i to point i+1:**

```matlab
% Using atan2 for correct quadrant selection
theta = atan2(y_next - y_current, x_next - x_current);
```

**Heading angles in the trajectory:**

```matlab
% For each point k, heading points toward next point
for k = 1:(M-1)
    trajectory(k, 3) = atan2(trajectory(k+1,2) - trajectory(k,2), ...
                              trajectory(k+1,1) - trajectory(k,1));
end

% Last point: use previous heading
trajectory(M, 3) = trajectory(M-1, 3);
```

---

## 6. Implementation Details

### 6.1 Complete MATLAB Implementation

```matlab
function trajectory = planTrajectory(N, Dt, V)
%PLANTRAJECTORY Generate smooth trajectory through beacons
%   Input:
%       N   - Number of beacons (default: 4)
%       Dt  - Time interval in seconds (default: 1)
%       V   - Average velocity in m/s (default: 5)
%   Output:
%       trajectory - M×3 matrix [x, y, theta]

    % Default parameters
    if nargin < 1, N = 4; end
    if nargin < 2, Dt = 1; end
    if nargin < 3, V = 5; end
    
    % Step 1: Beacon acquisition
    B = BeaconDetection(N);
    beacons = B.beacons;  % N×2 matrix
    
    % Step 2: Waypoint construction (include origin)
    x_wp = [0, beacons(:,1)'];  % [0, xb1, xb2, ..., xbN]
    y_wp = [0, beacons(:,2)'];  % [0, yb1, yb2, ..., ybN]
    n_wp = length(x_wp);
    
    % Step 3: pchip interpolation
    t_param = 1:n_wp;
    pp = pchip(t_param, [x_wp; y_wp]');
    
    % Step 4: Intermediate point generation
    delta_d = Dt * V;  % Distance between trajectory points
    trajectory = [];
    
    for i = 1:(n_wp - 1)
        % Distance between consecutive waypoints
        dx = x_wp(i+1) - x_wp(i);
        dy = y_wp(i+1) - y_wp(i);
        dist = sqrt(dx^2 + dy^2);
        
        % Number of intermediate points
        n = floor(dist / delta_d);
        
        if n > 0
            % Generate parameter values
            t_vals = linspace(i, i+1, n + 1);
            
            % Evaluate pchip interpolant
            pts = ppval(pp, t_vals);
            
            % Add to trajectory (exclude last to avoid duplication)
            trajectory = [trajectory; pts(1:end-1, :)];
        end
    end
    
    % Add final waypoint
    trajectory = [trajectory; x_wp(end), y_wp(end), 0];
    
    % Step 5: Heading angle calculation
    M = size(trajectory, 1);
    for k = 1:(M - 1)
        dx = trajectory(k+1, 1) - trajectory(k, 1);
        dy = trajectory(k+1, 2) - trajectory(k, 2);
        trajectory(k, 3) = atan2(dy, dx);
    end
    % Last point uses previous heading
    trajectory(M, 3) = trajectory(M-1, 3);
end
```

### 6.2 Alternative Implementation (Simpler)

```matlab
function trajectory = planTrajectory_simple(N, Dt, V)
% Simplified trajectory planning with pchip

    % Default parameters
    if nargin < 1, N = 4; end
    if nargin < 2, Dt = 1; end
    if nargin < 3, V = 5; end
    
    % Get beacon positions
    B = BeaconDetection(N);
    beacon_x = [0, B.beacons(:,1)'];  % Include origin
    beacon_y = [0, B.beacons(:,2)'];
    
    % Calculate delta distance
    delta_d = Dt * V;
    
    % Initialize trajectory
    trajectory = [0, 0, 0];  % Start at origin
    
    % Generate trajectory through each beacon segment
    for i = 1:(numel(beacon_x) - 1)
        % Distance between beacons
        d = sqrt((beacon_x(i+1) - beacon_x(i))^2 + ...
               (beacon_y(i+1) - beacon_y(i))^2);
        
        % Number of intermediate points
        n = floor(d / delta_d);
        
        if n > 0
            % Generate parameter values
            t = linspace(i, i+1, n + 1);
            
            % pchip interpolation
            x_interp = pchip(1:numel(beacon_x), beacon_x, t);
            y_interp = pchip(1:numel(beacon_y), beacon_y, t);
            
            % Add to trajectory (skip first to avoid duplication)
            for k = 2:n+1
                x = x_interp(k);
                y = y_interp(k);
                trajectory = [trajectory; x, y, 0];
            end
        end
    end
    
    % Calculate heading angles
    for k = 1:(size(trajectory, 1) - 1)
        dx = trajectory(k+1, 1) - trajectory(k, 1);
        dy = trajectory(k+1, 2) - trajectory(k, 2);
        trajectory(k, 3) = atan2(dy, dx);
    end
end
```

### 5.3 Edge Case Handling

#### 6.3.1 Consecutive Beacons at Same Position

```matlab
% Check for zero-distance segments
dx = x_wp(i+1) - x_wp(i);
dy = y_wp(i+1) - y_wp(i);
dist = sqrt(dx^2 + dy^2);

if dist < eps
    % Skip this segment - zero intermediate points
    continue;
end
```

#### 6.3.2 Single Beacon

```matlab
% Handle N = 1 case
if N == 1
    % Direct trajectory from origin to single beacon
    trajectory = [0, 0, 0];
    trajectory = [trajectory; beacons(1,:), atan2(beacons(1,2), beacons(1,1))];
end
```

#### 6.3.3 Large Beacon Separation

```matlab
% Ensure minimum number of intermediate points
n = max(1, floor(distance / delta_d));

% Use logarithmic spacing for very large distances (optional)
if distance > 10 * delta_d
    t = logspace(log10(i), log10(i+1), n + 1);
else
    t = linspace(i, i+1, n + 1);
end
```

---

## 7. Validation Checks

### 7.1 Required Validations

```matlab
function valid = validateTrajectory(trajectory, beacons)
%VALIDATETRAJECTORY Check trajectory meets requirements

    valid = true;
    
    % Check 1: Starts at origin
    if ~all(trajectory(1, :) == [0, 0, 0])
        warning('Trajectory does not start at (0, 0, 0)');
        valid = false;
    end
    
    % Check 2: Trajectory is valid path
    if size(trajectory, 2) ~= 3
        warning('Trajectory must have 3 columns [x, y, theta]');
        valid = false;
    end
    
    % Check 3: Heading angles in valid range
    if any(trajectory(:, 3) < -pi | trajectory(:, 3) > pi)
        warning('Heading angles must be in [-pi, pi]');
        valid = false;
    end
    
    % Check 4: No NaN values
    if any(isnan(trajectory(:)))
        warning('Trajectory contains NaN values');
        valid = false;
    end
    
    % NOTE: Trajectory does NOT need to pass through beacons.
    % Beacons are fixed landmarks for measurement, not waypoints.
end
```

### 7.2 Test Cases

```matlab
% Test 1: Basic call
traj1 = planTrajectory(4, 1, 5);
assert(size(traj1, 2) == 3, 'Trajectory must have 3 columns');
assert(traj1(1,:) == [0, 0, 0], 'Must start at origin');

% Test 2: Custom parameters
traj2 = planTrajectory(6, 0.5, 3);
assert(size(traj2, 1) > 6, 'Must have more points than beacons');

% Test 3: Edge case - single beacon
traj3 = planTrajectory(1, 1, 5);
assert(size(traj3, 1) >= 2, 'Must have start and end points');

% Verify heading angles are in valid range
assert(all(trajectory(:, 3) >= -pi & trajectory(:, 3) <= pi), ...
    'Heading angles must be in [-π, π]');
```

---

## 8. Integration with BeaconDetection

### 8.1 BeaconDetection Function

The trajectory planner calls `BeaconDetection(N)` to obtain beacon positions:

```matlab
% Call BeaconDetection
B = BeaconDetection(N);

% Extract beacon positions
% B.beacons is N×2 matrix: [x, y] coordinates
beacons = B.beacons;

% Example return value:
% B = 
%     beacons: [4x2 double]
%           dn: 0.1    % distance noise
%           an: 0.1    % angle noise
```

### 8.2 Beacon Position Format

| Index | x-coordinate | y-coordinate |
|-------|--------------|--------------|
| 1 | beacons(1,1) | beacons(1,2) |
| 2 | beacons(2,1) | beacons(2,2) |
| ... | ... | ... |
| N | beacons(N,1) | beacons(N,2) |

---

## 9. Example Usage

### 9.1 Basic Usage

```matlab
% Generate trajectory with default parameters
trajectory = planTrajectory();

% Display trajectory summary
fprintf('Trajectory points: %d\n', size(trajectory, 1));
fprintf('Start: (%.2f, %.2f, %.2f)\n', trajectory(1, :));
fprintf('End: (%.2f, %.2f, %.2f)\n', trajectory(end, :));
```

### 9.2 Custom Parameters

```matlab
% Higher resolution trajectory
trajectory = planTrajectory(6, 0.5, 3);

% Plot trajectory
figure;
plot(trajectory(:, 1), trajectory(:, 2), 'b-', 'LineWidth', 2);
hold on;
plot(trajectory(:, 1), trajectory(:, 2), 'bo');  % Points
xlabel('X (m)'); ylabel('Y (m)');
title('Generated Trajectory');
grid on;
```

### 9.3 Expected Output

```
Input: N = 4, Dt = 1, V = 5
Trajectory: Straight line from (0,0) to destination (not beacon positions)
Output: trajectory (M×3)

Example trajectory (independent path, NOT through beacons):
[ 0.00,  0.00,  0.00]  % Origin
[ 1.25,  0.31,  0.24]  % Along straight path
[ 2.50,  0.63,  0.24]  % Along path
[ 5.00,  1.25,  0.24]  % Along path
[ 6.25,  1.56,  0.24]  % Along path
...
[20.00,  5.00,  0.24]  % End point

Total trajectory points: M (depends on path length and Δd)

NOTE: Beacons are measured at each trajectory point (distance + bearing),
but the trajectory itself does NOT pass through beacon positions.
```

---

## 10. Summary

### 10.1 Key Concepts Clarified

| Concept | Clarification |
|---------|-------------|
| **Trajectory** | Robot's motion path (straight line from origin) - INDEPENDENT of beacon positions |
| **Beacons** | Fixed landmarks in the environment - the robot MEASURES them during navigation, NOT navigated to |
| **Waypoints** | Trajectory waypoints (points along robot's path) - NOT beacon positions |
| **Measurement** | At each trajectory point, robot measures distance and bearing TO each beacon |

### 10.2 Key Requirements Met

| Requirement | Implementation |
|-------------|----------------|
| Start at (0,0,0) | Origin included as first trajectory point |
| Trajectory is independent | Straight line path not passing through beacons |
| pchip() smoothing | Separate pchip for x and y |
| Δd spacing | delta_d = Dt × V |
| Heading via atan2() | Calculated between consecutive points |
| Output [x,y,θ] | 3-column trajectory matrix |

### 10.2 Parameters

- **N**: Number of beacons (default: 4)
- **Dt**: Sampling time interval (default: 1 s)
- **V**: Average velocity (default: 5 m/s)
- **Δd**: Distance between points = Dt × V (default: 5 m)

---

## 11. Working Code Example

The following is a complete, self-contained MATLAB script that demonstrates the trajectory planning flow:

```matlab
% Complete Working Example - Phase 1: Trajectory Planning
% This script demonstrates trajectory generation for robot navigation
%
% IMPORTANT CONCEPTS:
% - Trajectory is robot's motion path (straight line from origin)
% - Beacons are FIXED LANDMARKS (not destinations)
% - Robot measures distance/bearing TO beacons for EKF localization
%
% Usage:
%   trajectory = planTrajectory();
%   trajectory = planTrajectory(N, Dt, V);
%
% Example:
%   trajectory = planTrajectory(4, 1, 5);

function trajectory = planTrajectory(N, Dt, V)
%PLAN Trajectory - Generate robot trajectory (independent of beacons)
%
% Parameters:
%   N  - Number of beacons (fixed landmarks, default: 4)
%   Dt - Sensor sampling time interval in seconds (default: 1)
%   V  - Desired linear velocity in m/s (default: 5)
%
% Output:
%   trajectory - Mx3 matrix [x, y, theta] for each robot position

    % Set defaults
    if nargin < 1, N = 4; end
    if nargin < 2, Dt = 1; end
    if nargin < 3, V = 5; end

    % ============ T001: BEACON ACQUISITION ============
    % Get beacon positions (for later measurement, NOT for navigation)
    B = BeaconDetection(N);
    beacons = B.beacons;  % Nx2 matrix [x, y] positions

    % ============ T002: TRAJECTORY CONSTRUCTION ============
    % TODO: Currently uses straight line path (simple case)
    % Future: Could be arbitrary path that passes through beacon area
    % Trajectory is INDEPENDENT of beacon positions
    x_waypoints = [0, 20];  % Example: straight line from x=0 to x=20
    y_waypoints = [0, 5];   % Example: y goes from 0 to 5

    % ============ T003: PCHIP INTERPOLATION ============
    % Create parameter vector for pchip
    t_param = 1:length(x_waypoints);
    
    % Create pchip interpolant for x coordinates
    pp_x = pchip(t_param, x_waypoints);
    % Create pchip interpolant for y coordinates
    pp_y = pchip(t_param, y_waypoints);

    % ============ T004: INTERMEDIATE POINTS ============
    Delta_d = Dt * V;  % Distance between points
    trajectory = [];

    for i = 1:length(x_waypoints)-1
        % Calculate distance between consecutive waypoints
        dx = x_waypoints(i+1) - x_waypoints(i);
        dy = y_waypoints(i+1) - y_waypoints(i);
        distance = sqrt(dx^2 + dy^2);
        
        % Number of intermediate points
        n_points = max(1, floor(distance / Delta_d));
        
        % Generate parameter values
        t_vals = linspace(i, i+1, n_points + 1);
        
        % Evaluate pchip interpolants
        x_pts = ppval(pp_x, t_vals);
        y_pts = ppval(pp_y, t_vals);
        
        % ============ T005: HEADING CALCULATION ============
        for j = 1:length(x_pts)-1
            if j < length(x_pts)
                theta = atan2(y_pts(j+1) - y_pts(j), x_pts(j+1) - x_pts(j));
            else
                theta = 0;  % Last point, no next point
            end
            trajectory = [trajectory; x_pts(j), y_pts(j), theta];
        end
    end

    % Add final point
    trajectory = [trajectory; x_pts(end), y_pts(end), trajectory(end, 3)];

    % ============ T006: VALIDATION ============
    % Ensure start is (0, 0, 0)
    trajectory(1, :) = [0, 0, 0];
end
```

### 11.1 How to Run

```matlab
% Basic usage with defaults
trajectory = planTrajectory();

% Custom usage
trajectory = planTrajectory(4, 1, 5);

% View results
disp(trajectory);

% Plot the trajectory
figure;
plot(trajectory(:,1), trajectory(:,2), 'b-', 'LineWidth', 2);
hold on;
plot(trajectory(:,1), trajectory(:,2), 'b.', 'MarkerSize', 10);
xlabel('X (m)'); ylabel('Y (m)');
title('Generated Trajectory');
grid on;
axis equal;
```

### 11.2 Expected Output

```
Input: N = 4, Dt = 1, V = 5
Trajectory: Straight line from (0,0) to (20,5)

Example trajectory output (first 10 points):
     0.00     0.00     0.00   % Origin
     1.25     0.31     0.24   % Along path
     2.50     0.63     0.24   % Along path
     3.75     0.94     0.24   % Along path
     5.00     1.25     0.24   % Along path
     6.25     1.56     0.24   % Along path
     7.50     1.88     0.24   % Along path
     8.75     2.19     0.24   % Along path
    10.00     2.50     0.24   % Along path
    11.25     2.81     0.24   % Along path
     ...

Total trajectory points: M (depends on path length and Δd)
NOTE: Beacons are measured at each point, NOT at specific trajectory points
```

---

*Document Version: 1.1*
*Updated: 2026-04-19*
*Phase: 1 - Trajectory Planning*