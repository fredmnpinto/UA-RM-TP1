# Phase 1: Trajectory Planning - Tasks

## Overview

This document outlines the actionable tasks for implementing the Trajectory Planning phase. Each task is mapped to specific functions from the Peter Corke Robotics Toolbox and includes detailed specifications for implementation.

## Task List

### T001: Beacon Acquisition

**Objective**: Call BeaconDetection(N) to get beacon positions for EKF observations (NOT for trajectory waypoints).

**Function Call**:
```matlab
B = BeaconDetection(N);
beacons = B.beacons;
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| N | integer | Number of beacons (default: 4) |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| B | struct | Beacon detection structure containing beacons, dn, an |
| B.beacons | N×2 matrix (doubles) | Beacon (x, y) positions in meters |
| B.dn | scalar | Distance measurement noise std dev |
| B.an | scalar | Angle measurement noise std dev |

**Dependencies**: none
**MATLAB Functions**: BeaconDetection (custom)

**Notes**:
- **IMPORTANT**: Beacons are FIXED LANDMARKS - the robot uses them for EKF localization, NOT as destinations
- The beacon positions are used for the observation model (measuring distance/bearing TO beacons)
- Include origin (0,0) as the trajectory starting point separately

---

### T002: Waypoint Construction

**Objective**: Build x_waypoints and y_waypoints vectors as an INDEPENDENT trajectory (NOT based on beacons).

**Function Call**:
```matlab
% Define trajectory waypoints independently from beacons
% Example: simple straight-line trajectory extending from origin
x_waypoints = [0, 50];  % Start at origin, extend to x=50
y_waypoints = [0, 0];   % Stay on x-axis
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| none | N/A | Waypoints are hardcoded for this assignment |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| x_waypoints | 1×M vector | X-coordinates for trajectory (M waypoints) |
| y_waypoints | 1×M vector | Y-coordinates for trajectory (M waypoints) |

**Dependencies**: T001 (just to get beacon data if needed)
**MATLAB Functions**: none (array operations)

**Notes**:
- **IMPORTANT**: Waypoints are INDEPENDENT of beacon positions - they define the robot's path, not its destination
- For simplicity: use a straight line trajectory from (0,0) extending beyond the beacon area
- The robot will MEASURE distance/bearing TO beacons during navigation, not navigate TO them
- Origin (0, 0) is the starting point

---

### T003: pchip Interpolation

**Objective**: Create Piecewise Cubic Hermite Interpolating Polynomial (pchip) objects for x and y coordinates.

**Function Call**:
```matlab
t_param = 1:length(x_waypoints);
pp_x = pchip(t_param, x_waypoints);
pp_y = pchip(t_param, y_waypoints);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| t_param | vector | Parameter locations 1:(N+1) |
| x_waypoints | vector | X-coordinate waypoints |
| y_waypoints | vector | Y-coordinate waypoints |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| pp_x | struct (pp-form) | pchip interpolant for x-coordinates |
| pp_y | struct (pp-form) | pchip interpolant for y-coordinates |

**Dependencies**: T002
**MATLAB Functions**: pchip, length, colon operator

**Notes**:
- pchip creates smooth interpolation preserving shape
- No overshoot between waypoints
- Each interpolant can be evaluated with ppval()

---

### T004: Intermediate Points Generation

**Objective**: Generate trajectory points between consecutive waypoints using pchip interpolation.

**Function Call**:
```matlab
Delta_d = Dt * V;
for i = 1:length(x_waypoints)-1
    dx = x_waypoints(i+1) - x_waypoints(i);
    dy = y_waypoints(i+1) - y_waypoints(i);
    distance = sqrt(dx^2 + dy^2);
    n_points = max(1, floor(distance / Delta_d));
    t_vals = linspace(i, i+1, n_points + 1);
    x_pts = ppval(pp_x, t_vals);
    y_pts = ppval(pp_y, t_vals);
end
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| Dt | scalar | Sensor sampling time interval in seconds |
| V | scalar | Desired linear velocity in m/s |
| Delta_d | scalar | Distance between trajectory points (Dt × V) |
| i | integer | Current segment index |
| distance | scalar | Euclidean distance between waypoints |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| n_points | integer | Number of intermediate points per segment |
| t_vals | vector | Parameter values for ppval evaluation |
| x_pts | vector | Interpolated x-coordinates |
| y_pts | vector | Interpolated y-coordinates |

**Dependencies**: T003
**MATLAB Functions**: sqrt, floor, linspace, ppval, max

**Notes**:
- Delta_d = Dt × V determines spatial spacing
- At least 1 point per segment (max(1, ...))
- Exclude last point of each segment to avoid duplication

---

### T005: Heading Calculation

**Objective**: Calculate heading angle (theta) for each trajectory point using atan2.

**Function Call**:
```matlab
theta = atan2(dy, dx);
% or in loop context:
theta = atan2(y_pts(j+1) - y_pts(j), x_pts(j+1) - x_pts(j));
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| dy | scalar | Change in y: y(next) - y(current) |
| dx | scalar | Change in x: x(next) - x(current) |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| theta | scalar (radians) | Heading angle in range [-π, π] |

**Dependencies**: T004
**MATLAB Functions**: atan2

**Notes**:
- Use atan2(dy, dx) not atan(dy/dx) for correct quadrant
- Handles vertical motion (dx = 0) correctly
- Last point uses previous heading (no next point available)

---

### T006: Trajectory Assembly

**Objective**: Combine x, y coordinates and theta into the final M×3 trajectory matrix.

**Function Call**:
```matlab
trajectory = [trajectory; x_pts(j), y_pts(j), theta];
% Final point:
trajectory = [trajectory; x_pts(end), y_pts(end), trajectory(end, 3)];
% Ensure origin:
trajectory(1, :) = [0, 0, 0];
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| x_pts | vector | Interpolated x-coordinates |
| y_pts | vector | Interpolated y-coordinates |
| theta | scalar | Heading angle |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| trajectory | M×3 matrix | Complete trajectory [x, y, θ] |

**Dependencies**: T004, T005
**MATLAB Functions**: array concatenation

**Notes**:
- First row must be [0, 0, 0] (origin)
- Last point uses previous heading
- Matrix format: [x, y, heading]

---

### T007: Validation

**Objective**: Verify trajectory correctness before passing to EKF localization.

**Function Call**:
```matlab
% Check start at origin
if ~isequal(trajectory(1, :), [0, 0, 0])
    error('Trajectory must start at origin');
end

% Check trajectory extends beyond beacon area (end point should be beyond first beacon)
if trajectory(end, 1) < beacons(1, 1)
    error('Trajectory must extend beyond beacon area');
end

% Check no NaN values
if any(isnan(trajectory(:)))
    error('Trajectory contains NaN values');
end

% Check heading range
if any(trajectory(:, 3) < -pi | trajectory(:, 3) > pi)
    error('Heading angles out of range');
end
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| trajectory | M×3 matrix | Assembled trajectory from T006 |
| beacons | N×2 matrix | Beacon positions (for bounds check only) |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| valid | boolean | True if all checks pass |

**Dependencies**: T006
**MATLAB Functions**: isequal, isnan, any

**Notes**:
- Start must be (0, 0, 0)
- End must extend beyond the beacon area (independent of specific beacon)
- No NaN values allowed
- Heading must be in [-π, π]

---

## Dependencies

```
T001 (Beacon Acquisition)
    │
    ▼
T002 (Waypoint Construction) ──► T003 (pchip Interpolation)
    │                                │
    │                                ▼
    │                         T004 (Intermediate Points)
    │                                │
    │                                ▼
    │                         T005 (Heading Calculation)
    │                                │
    │                                ▼
    │                         T006 (Trajectory Assembly)
    │                                │
    │                                ▼
    │                         T007 (Validation)
    │
    └───────────────────────────────► [Output to EKF]

[Parallel] T003 and T002 can run in parallel (both depend on T001)
```

## Effort Estimate

| Task | Description | Effort |
|------|-------------|--------|
| T001 | Beacon Acquisition | [Small] |
| T002 | Waypoint Construction | [Small] |
| T003 | pchip Interpolation | [Small] |
| T004 | Intermediate Points | [Medium] |
| T005 | Heading Calculation | [Small] |
| T006 | Trajectory Assembly | [Small] |
| T007 | Validation | [Small] |

## Complete Implementation Order

1. **T001** - Call BeaconDetection(N), extract beacons
2. **T002** - Build x_waypoints, y_waypoints with origin
3. **T003** - Create pp_x, pp_y interpolants (can parallel with T002)
4. **T004** - Generate trajectory points per segment
5. **T005** - Calculate theta using atan2
6. **T006** - Combine into M×3 matrix
7. **T007** - Verify trajectory correctness

---

## Integration Notes

- Input: N (beacons), Dt (time interval), V (velocity)
- Output: trajectory (M×3 matrix [x, y, θ])
- Passed to: Phase 2 (EKF Localization)
- Validates: Start at origin, extends beyond beacon area, smooth independent path

---

*Document Version: 1.0*
*Created: 2026-04-19*
*Phase: 1 - Trajectory Planning*