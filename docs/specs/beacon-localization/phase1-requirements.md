# Phase 1: Trajectory Planning Requirements

## Overview

This specification defines the Phase 1 requirements for the Mobile Robotics assignment, focusing exclusively on trajectory planning. Phase 1 generates a smooth trajectory that starts at (0, 0, 0) and extends through the environment as a path (straight line). The trajectory is computed using Piecewise Cubic Hermite Interpolating Polynomial (pchip()) with intermediate points calculated based on time and velocity parameters.

> **IMPORTANT: Beacons are FIXED LANDMARKS (reference points) in the environment. The robot trajectory is an INDEPENDENT path (straight line for simplicity) that passes through/extends beyond the beacon area. The robot MEASURES distance/bearing TO beacons during navigation for EKF localization - it does NOT navigate TO/beacons.**

## Functional Requirements

### 1. Beacon Position Acquisition

- [ ] The program must call `BeaconDetection(N)` to obtain beacon positions
- [ ] The program must support N > 2 beacons (typically N = 4-6)
- [ ] Beacon coordinates must be stored in a structured format for trajectory planning
- [ ] Beacon positions are returned as (x, y) coordinates in the world frame

### 2. Trajectory Calculation with pchip()

- [ ] The trajectory must use MATLAB's `pchip()` function for Piecewise Cubic Hermite Interpolation
- [ ] The trajectory must start at (0, 0, 0) - origin, oriented horizontally (θ = 0)
- [ ] The trajectory is a path (straight line) through the environment
- [ ] The trajectory must end beyond the beacon area
- [ ] pchip() must be applied separately for x and y coordinates

### 3. Intermediate Point Calculation

- [ ] Calculate distance between consecutive observation points: Δd = Δt × V
- [ ] Δt = sensor sampling time interval (Dt parameter, default: 1 s)
- [ ] V = desired average linear velocity (V parameter, default: 5 m/s)
- [ ] Generate intermediate points between beacons based on Δd spacing
- [ ] Each trajectory segment between beacons must contain `floor(distance_beacon_pair / Δd)` intermediate points
- [ ] Δd represents the arc length between consecutive trajectory points

### 4. Heading Angle Calculation

- [ ] Calculate heading angle θ for each trajectory point using atan2()
- [ ] θ = atan2(y_i+1 - y_i, x_i+1 - x_i) for segment from point i to point i+1
- [ ] First point after origin uses heading toward first beacon
- [ ] Heading angles should be in radians, normalized to [-π, π]

### 5. Trajectory Output

- [ ] Generate trajectory points array with format [x, y, θ]
- [ ] x: x-coordinate in meters
- [ ] y: y-coordinate in meters
- [ ] θ: heading angle in radians
- [ ] Number of points = sum of intermediate points for all segments + 1 (start point)

## Input Specifications

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| N | integer | 4 | Number of beacons |
| Dt | scalar | 1 | Sensor sampling time interval (seconds) |
| V | scalar | 5 | Desired average linear velocity (m/s) |

## Output Specifications

| Output | Type | Description |
|--------|------|-------------|
| trajectory | M×3 matrix | Trajectory points [x, y, θ], where M is total trajectory points |

### Trajectory Matrix Format

```
[x1, y1, θ1]  % Start point (0, 0, 0)
[x2, y2, θ2]  % Intermediate point 1
[x3, y3, θ3]  % Intermediate point 2
...
[xn, yn, θn]  % End point (extends beyond beacon area)
```

## Acceptance Criteria

### Must Have
- [ ] Trajectory starts at (0, 0, 0) - origin with heading 0 radians
- [ ] Trajectory is an independent path (straight line) through the environment
- [ ] Trajectory extends beyond the beacon area
- [ ] pchip() interpolation is used for trajectory smoothing
- [ ] Intermediate points are calculated based on Δd = Δt × V
- [ ] All trajectory points have valid (x, y, θ) values
- [ ] Heading angles computed using atan2() between consecutive points

> **IMPORTANT**: Beacons are LANDMARKS (reference points) used for EKF measurement - the robot MEASURES distance/bearing TO beacons during navigation, it does NOT navigate TO beacons.

### Should Have
- [ ] Trajectory intermediate points evenly spaced based on Δd calculation
- [ ] Heading remains constant for straight-line trajectory
- [ ] Last heading matches direction of final segment
- [ ] Number of trajectory points clearly documented

### Won't Have
- [ ] Trajectory designed to navigate TO beacons (beacons are landmarks, not destinations)
- [ ] Hard-coded beacon positions (must use BeaconDetection())
- [ ] Linear interpolation (must use pchip())
- [ ] Missing heading angles in output
- [ ] Output containing only beacon positions without intermediate points

## Edge Cases

> **Note**: Beacons are LANDMARKS for EKF measurement, not waypoints. The trajectory is independent.

### 1. No Beacon Detections (NaN)
- **Case**: All beacons return NaN (not visible) at a timestep
- **Expected behavior**: EKF prediction step continues without update; uses only motion model

### 2. Partial Beacon Visibility
- **Case**: Some beacons visible, others return NaN
- **Expected behavior**: EKF update proceeds with reduced observation vector

### 3. Beacon Coverage Throughout Trajectory
- **Case**: Robot traverses from origin through beacon area
- **Expected behavior**: EKF uses beacon measurements at various points along trajectory

### 4. Trajectory Extends Beyond All Beacons
- **Case**: Trajectory endpoint is beyond all beacon positions
- **Expected behavior**: Robot continues trajectory after passing beacon area; EKF may have no updates beyond beacons

### 5. Straight Line Trajectory
- **Case**: Simple trajectory (e.g., x: 0→50, y: 0→0)
- **Expected behavior**: Heading angle remains constant at 0 radians

## Dependencies

### Required Functions
- **BeaconDetection()**: Provided function for beacon position simulation
- **pchip()**: MATLAB built-in for Piecewise Cubic Hermite Interpolation
- **atan2()**: MATLAB built-in for two-argument arctangent (heading calculation)
- **sqrt()**: MATLAB built-in for distance calculations
- **size()**, **length()**, **zeros()**: Standard MATLAB array operations

### Parameters
- **N**: Number of beacons (integer, N > 2 recommended)
- **Dt**: Sampling time interval in seconds (scalar, default: 1)
- **V**: Desired linear velocity in m/s (scalar, default: 5)

## Excluded from Phase 1

The following are NOT in Phase 1 scope and will be addressed in later phases:
- Extended Kalman Filter (EKF) implementation (Phase 2)
- Motion model and observation model
- Process noise and measurement noise covariance
- Kinematic model calculations (Differential Drive, Tricycle, Omnidirectional)
- Output file generation (loc_nnnnnn.txt, DD_nnnnnn.txt, etc.)
- Beacon measurement simulation (distances and angles)

> **Key Clarification**: In Phase 1, beacons are used only to define the "environment bounds" - the trajectory extends beyond the beacon area so the robot can traverse through and measure beacons during EKF localization in Phase 2.

## Notes

### pchip() Usage

```matlab
% Interpolate x-coordinates
xi = pchip(beacon_x, x_beacons, x_interp);

% Interpolate y-coordinates  
yi = pchip(beacon_y, y_beacons, x_interp);
```

### Heading Calculation

The heading angle θ at point i represents the direction from point i to point i+1:
- θ = 0 corresponds to the positive x-direction (horizontal right)
- π/2 corresponds to positive y-direction (vertical up)
- Negative angles represent clockwise rotation from positive x-axis