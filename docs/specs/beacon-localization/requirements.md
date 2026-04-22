# Robot Probabilistic Localization using Redundant Landmarks

## Overview

This specification defines the requirements for a MATLAB program that implements robot probabilistic localization using Extended Kalman Filter (EKF) with redundant beacon landmarks. The robot starts at (0, 0, 0) and follows an INDEPENDENT trajectory (straight line) through the environment, extending beyond the beacon area. During navigation, the robot MEASURES distance/bearing TO beacons for EKF localization - it does NOT navigate TO beacons. The system must handle any number of beacons greater than 2, with graceful handling of missing beacon detections (NaN values).

> **IMPORTANT: Beacons are FIXED LANDMARKS (reference points) in the environment. The robot trajectory is an INDEPENDENT path (straight line for simplicity) that passes through/extends beyond the beacon area. The robot MEASURES distance/bearing TO beacons during navigation for EKF localization - it does NOT navigate TO/beacons.**

## User Stories

### Student/Developer User Stories

- As a university student developing a Mobile Robotics assignment, I want to implement an Extended Kalman Filter (EKF) for robot localization so that I can estimate the robot's pose despite sensor measurement uncertainties.

- As a user of the localization system, I want the trajectory to start at (0, 0, 0) and follow an INDEPENDENT straight-line path through the beacon area so that the robot traverses the environment.

- As a user, I want to use beacons as LANDMARKS (reference points for measurement) not as destinations - the robot measures distance/bearing TO beacons during navigation for EKF correction.

- As a user, I want the system to handle variable numbers of visible beacons (including NaN values for undetected beacons) so that the localization remains robust even when some beacons are not detectable.

- As a user, I want to generate wheel velocity commands for three different kinematic models (differential drive, tricycle, omnidirectional) so that I can analyze the physical requirements for each robot type.

- As a user, I want the output files to be created in specific formats (loc_nnnnnn.txt, DD_nnnnnn.txt, TRI_nnnnnn.txt, OMNI_nnnnnn.txt) so that the results can be analyzed and compared against expected values.

## Functional Requirements

### 1. Trajectory Planning

#### 1.1 Beacon Position Acquisition
- [ ] The program must call `BeaconDetection(N)` to obtain beacon positions
- [ ] The program must support N > 2 beacons (typically N = 4-6)
- [ ] Beacon coordinates must be stored and used for trajectory planning

#### 1.2 Trajectory Calculation with pchip()
- [ ] The trajectory must use Piecewise Cubic Hermite Interpolating Polynomial (pchip())
- [ ] The trajectory must start at (0, 0, 0) - origin, oriented horizontally to the right
- [ ] The trajectory is an INDEPENDENT path (straight line) through the environment
- [ ] The trajectory must extend beyond the beacon area
> **IMPORTANT**: Beacons are LANDMARKS, not waypoints - the robot navigates ALONG the trajectory and MEASURES distance/bearing TO beacons during EKF localization

#### 1.3 Intermediate Point Calculation
- [ ] Calculate distance between consecutive observation points: Δd = Δt × V
- [ ] Δt = sensor sampling time interval (Dt parameter, default: 1 s)
- [ ] V = desired average linear velocity (V parameter, default: 5 m/s)
- [ ] Generate intermediate points between beacons based on Δd spacing
- [ ] Each trajectory segment between beacons must contain floor(distance_beacon_pair / Δd) intermediate points

### 2. EKF Localization

#### 2.1 Motion Model
- [ ] Implement motion model function f(x̂_k, u_k, w_k)
- [ ] Input: current state estimate (x, y, θ), control velocities (linear v, angular ω), process noise w_k
- [ ] Output: predicted next state
- [ ] Use linear and angular velocities as control inputs

#### 2.2 Motion Model Jacobian
- [ ] Calculate Jacobian J_fx of motion model with respect to state
- [ ] Calculate Jacobian J_fw of motion model with respect to process noise
- [ ] Use Jacobians in EKF prediction step covariance update

#### 2.3 Process Noise Covariance
- [ ] Create process noise covariance matrix Q based on Vn and Wn parameters
- [ ] Vn = sigma for linear velocity uncertainty (default: 0.1 m/s)
- [ ] Wn = sigma for angular velocity uncertainty (default: 0.1 rad/s)

#### 2.4 Observation Model
- [ ] Implement observation model function h(x) for beacon measurements
- [ ] Calculate predicted distance to each visible beacon: d = sqrt((xb-x)² + (yb-y)²)
- [ ] Calculate predicted angle to each visible beacon: a = atan2(yb-y, xb-x) - θ
- [ ] Handle variable number of beacon measurements (some may be NaN)

#### 2.5 Observation Jacobian
- [ ] Calculate Jacobian J_h of observation model with respect to state
- [ ] J_h dimensions must vary based on number of valid beacon measurements
- [ ] For each valid beacon (distance, angle): partial derivatives with respect to x, y, θ

#### 2.6 EKF Update Step
- [ ] Calculate innovation: z_k+1 - h(x̄_k+1)
- [ ] Handle NaN measurements by excluding them from innovation calculation
- [ ] Calculate innovation covariance: S = J_h * P̄_k+1 * J_h' + R
- [ ] Calculate Kalman gain: K = P̄_k+1 * J_h' * S^(-1)
- [ ] Update state estimate: x̂_k+1 = x̄_k+1 + K * innovation
- [ ] Update covariance: P_k+1 = P̄_k+1 - K * S * K'

#### 2.7 Measurement Noise Covariance
- [ ] Use observation noise from BeaconDetection() output (B.dn, B.an)
- [ ] Create observation covariance matrix R with appropriate dimensions

### 3. Kinematic Model Calculations

#### 3.1 Differential Drive
- [ ] Calculate right wheel angular velocity: ωR
- [ ] Calculate left wheel angular velocity: ωL
- [ ] Formula: v = ωR * r = ωL * r (for straight motion)
- [ ] Formula: ω = (ωR - ωL) * r / L (for turning)
- [ ] Using wheel radius r (default: 0.15 m) and wheel separation L (default: 1 m)

#### 3.2 Tricycle
- [ ] Calculate rear wheel (traction) velocity: ωT
- [ ] Calculate front wheel steering angle: α
- [ ] Rear wheel velocity equals linear velocity divided by wheel radius
- [ ] Steering angle α relates to angular velocity requirement

#### 3.3 Omnidirectional
- [ ] Calculate three wheel velocities: ω1, ω2, ω3
- [ ] Wheels positioned at 120° intervals (or as appropriate for the model)
- [ ] Calculate based on combined linear and angular velocities

### 4. Output Files

#### 4.1 Location File (loc_nnnnnn.txt)
- [ ] Create file with format: x, y, θ (comma-separated)
- [ ] One pose estimate per line
- [ ] Use student number in filename
- [ ] Start from initial position (0, 0, 0)

#### 4.2 Differential Drive File (DD_nnnnnn.txt)
- [ ] Create file with format: ωR, ωL (comma-separated)
- [ ] One line per trajectory point
- [ ] Values in radians/second

#### 4.3 Tricycle File (TRI_nnnnnn.txt)
- [ ] Create file with format: ωT, α (comma-separated)
- [ ] One line per trajectory point
- [ ] ωT in rad/s, α in radians

#### 4.4 Omnidirectional File (OMNI_nnnnnn.txt)
- [ ] Create file with format: ω1, ω2, ω3 (comma-separated)
- [ ] One line per trajectory point
- [ ] Values in radians/second

### 5. Function Signature

#### 5.1 Main Function
- [ ] Function name: rm1_nnnnnn(N, Dt, r, L, Vn, Wn, V)
- [ ] N = number of beacons (default: 4)
- [ ] Dt = sensor sampling time interval in seconds (default: 1)
- [ ] r = wheel radius in meters (default: 0.15)
- [ ] L = wheel separation in meters (default: 1)
- [ ] Vn = linear velocity uncertainty sigma (default: 0.1 m/s)
- [ ] Wn = angular velocity uncertainty sigma (default: 0.1 rad/s)
- [ ] V = desired average linear velocity (default: 5 m/s)

## Acceptance Criteria

### Must Have
- [ ] Trajectory is independent path (straight line) starting at (0, 0, 0)
- [ ] Trajectory extends beyond the beacon area
- [ ] EKF successfully estimates robot pose using beacon MEASUREMENTS (distance/bearing)
- [ ] Program handles missing beacon detections (NaN values) without crashing
- [ ] All output files are created with correct format and contain data for all trajectory points
- [ ] Program runs without MATLAB errors
- [ ] pchip() interpolation used for trajectory smoothing

### Should Have
- [ ] Trajectory intermediate points evenly spaced based on Δd = Δt × V calculation
- [ ] Proper covariance matrices (P, Q, R) are maintained and updated
- [ ] Three kinematic models produce valid wheel velocities
- [ ] Wheel velocities within physically reasonable ranges

### Won't Have
- [ ] Trajectory designed to navigate TO beacons (beacons are landmarks, not destinations)
- [ ] Hard-coded beacon positions (must use BeaconDetection())
- [ ] Localization using only deterministic methods (must use EKF)
- [ ] Output files with incorrect number of columns
- [ ] Files named incorrectly (must follow naming convention)

## Edge Cases

### 1. Beacon Detection Failures
- **Case**: All beacons return NaN for a given observation point
- **Expected behavior**: EKF prediction step continues normally without update step; pose estimate uses only motion model prediction

### 2. Single Visible Beacon
- **Case**: Only 1 beacon returns valid measurements (others are NaN)
- **Expected behavior**: EKF update proceeds with reduced observation vector; localization may have higher uncertainty but should still function

### 3. Two Visible Beacons
- **Case**: Exactly 2 beacons visible and returning valid data
- **Expected behavior**: Standard EKF update with full observation vector dimension (4 states: d1, a1, d2, a2)

### 4. Multiple Visible Beacons
- **Case**: More than 2 beacons returning valid data (redundant case)
- **Expected behavior**: EKF uses all available measurements for more robust localization; Jacobian dimensions increase accordingly

### 5. Straight Line Trajectory
- **Case**: Straight-line trajectory path through beacon area
- **Expected behavior**: Angular velocity remains approximately zero; robot traverses along line while measuring beacons

### 6. Sharp Turns
- **Case**: Trajectory path includes angular changes
- **Expected behavior**: Higher angular velocities calculated; wheel velocities reflect turn requirements

### 7. Small Number of Beacons
- **Case**: N = 3 (minimum meaningful redundant case)
- **Expected behavior**: Program handles 3 beacons correctly for EKF measurement during navigation

### 8. Large Number of Beacons
- **Case**: N > 6 (extended scenario)
- **Expected behavior**: Program scales to handle more beacons; trajectory planning and EKF accommodate N beacons

### 9. Zero Velocity Segments
- **Case**: Consecutive beacons at same position or very close
- **Expected behavior**: Δd calculation may result in zero intermediate points; trajectory handles gracefully

### 10. First Observation Point
- **Case**: Initial state estimate at (0, 0, 0)
- **Expected behavior**: EKF initialized with zero state and initial covariance; first step is prediction from initial state

## Dependencies

### IMPORTANT: Peter Corke's Robotics Toolbox

> **This assignment RECOMMENDS the use of Peter Corke's Robotics Toolbox (RTB) for MATLAB.**
>
> - [ ] Students **SHOULD** use functions from Peter Corke's Robotics Toolbox (RTB) where applicable
> - [ ] When using RTB functions, **ALWAYS consult the local documentation file** `peter_corke_toolbox.md` for function usage
> - [ ] The toolbox provides useful functions for:
>   - Kinematic model calculations (differential drive, tricycle, omnidirectional)
>   - Homogeneous transformations
>   - Robot modeling and simulation

### Documentation Reference
**Local documentation**: `peter_corke_toolbox.md` (in project root directory)
- This is the converted Markdown version of the RTB documentation
- Contains all necessary function references for this assignment
- Take it with a grain of salt but it's probably the best available

### Key RTB Functions to Consider
- `tr2eul`, `eul2tr` - Euler angle conversions
- `angvec2r`, `r2angvec` - Angle-axis conversions  
- `se2`, `twist` - 2D transformations
- Robot-specific functions for kinematic analysis

### Required Functions
- **BeaconDetection()**: Provided function for beacon position and measurement simulation - must be used as-is
- **pchip()**: MATLAB built-in function forPiecewise Cubic Hermite Interpolating Polynomial
- **sqrt()**: MATLAB built-in for square root
- **atan2()**: MATLAB built-in for two-argument arctangent
- **size()**, **length()**, **zeros()**, **ones()**, **eye()**: Standard MATLAB array operations

### External Dependencies
- **Peter Corke's Robotics Toolbox (RTB)** - Recommended for kinematic calculations and transformations
  - See local documentation file: `peter_corke_toolbox.md` for function reference
- Standard MATLAB functions (no additional required dependencies if RTB not used)

### Prior Requirements
- Understanding of Extended Kalman Filter theory
- Knowledge of differential drive, tricycle, and omnidirectional kinematics
- Familiarity with MATLAB programming

## Technical Notes

### Jacobian Dimensions

The observation Jacobian J_h has variable dimensions:
- Each valid beacon contributes 2 rows (distance and angle observations)
- For k visible beacons: J_h will be a (2k) × 3 matrix
- Columns correspond to state variables (x, y, θ)

### EKF Initialization

State vector: x̂ = [x, y, θ]ᵀ (3×1)
Initial state: [0, 0, 0]ᵀ
Initial covariance P₀ should be set to represent initial uncertainty (e.g., small values for x, y and larger for θ)

### File Naming Convention

Replace nnnnnn with student number:
- loc_nnnnnn.txt
- DD_nnnnnn.txt
- TRI_nnnnnn.txt
- OMNI_nnnnnn.txt