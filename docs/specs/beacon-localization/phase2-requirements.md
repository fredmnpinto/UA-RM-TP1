# Phase 2: EKF Core + Localization Requirements

## Overview

This specification defines the Phase 2 requirements for the Mobile Robotics assignment, focusing exclusively on Extended Kalman Filter (EKF) core implementation and robot localization. Phase 2 implements the motion model (prediction step), observation model (beacon measurements), EKF update step (Kalman gain and covariance update), and handles variable numbers of visible beacons with NaN handling. The output is the estimated trajectory saved to loc_129466.txt.

> **IMPORTANT: Beacons are FIXED LANDMARKS (reference points) in the environment. The robot trajectory is an INDEPENDENT path (straight line for simplicity) that passes through/extends beyond the beacon area. The robot MEASURES distance/bearing TO beacons during navigation for EKF localization - it does NOT navigate TO beacons.**

## Functional Requirements

### 1. Motion Model (Prediction Step)

- [ ] Implement motion model function f(x̂_k, u_k, w_k) that predicts next state
- [ ] State vector: x = [x, y, θ]ᵀ (3×1)
- [ ] Control input: u = [v, ω]ᵀ (linear velocity, angular velocity)
- [ ] Prediction: x̄_k+1 = f(x̂_k, u_k, w_k)
  - f() is the process function depending on current state, control inputs, and noise
- [ ] Process noise: w ~ N(0, Q) where Q is process noise covariance
- [ ] Calculate Jacobian J_fx (∂f/∂x) for covariance propagation:
  - J_fx = Jacobian of f with respect to state x
- [ ] Calculate Jacobian J_fw (∂f/∂w) for process noise propagation:
  - J_fw = Jacobian of f with respect to noise w
- [ ] Covariance: P̄_k+1 = J_fx(x̂_k, u_k, w_k) · P̂_k · J_fxᵀ + J_fw(x̂_k, u_k, w_k) · Q · J_fwᵀ

### 2. Observation Model

- [ ] Implement observation model function h(x) that predicts beacon measurements
- [ ] For each beacon at position (x_b, y_b), predict:
  - Distance: d = sqrt((x_b - x)² + (y_b - y)²)
  - Angle: a = atan2(y_b - y, x_b - x) - θ
- [ ] Observation vector z = [d₁, a₁, d₂, a₂, ..., dₙ, aₙ]ᵀ for n visible beacons
- [ ] Calculate Jacobian J_h (∂h/∂x) with variable dimensions:
  - For each visible beacon, 2 rows (distance and angle derivatives)
  - J_h is a (2k) × 3 matrix where k = number of valid beacon measurements
  - ∂d/∂x = -(x_b - x)/d, ∂d/∂y = -(y_b - y)/d, ∂d/∂θ = 0
  - ∂a/∂x = (y_b - y)/d², ∂a/∂y = -(x_b - x)/d², ∂a/∂θ = -1

### 3. EKF Update Step

- [ ] Innovation: ν_k+1 = z_k+1 - h(x̄_k+1)
- [ ] Handle NaN measurements by excluding them from innovation vector
- [ ] Innovation covariance: S = J_h(x̄_k+1) · P̄_k+1 · J_hᵀ + R
  - R is measurement noise covariance matrix (from BeaconDetection output)
  - Dimensions of S: (2k) × (2k) where k = number of valid measurements
- [ ] Kalman gain: K = P̄_k+1 · J_hᵀ · S⁻¹
  - Dimensions of K: 3 × (2k)
- [ ] State update: x̂_k+1 = x̄_k+1 + K · ν
- [ ] Covariance update: P̂_k+1 = P̄_k+1 - K · S · Kᵀ
- [ ] Ensure P̂_k+1 remains symmetric positive semi-definite

### 4. NaN Handling (Variable Beacon Visibility)

- [ ] Detect NaN values in beacon measurements (distance or angle)
- [ ] Skip beacon measurements containing NaN in innovation calculation
- [ ] Dynamically adjust J_h matrix dimensions to exclude NaN measurements
- [ ] Dynamically adjust R matrix dimensions to match valid measurements only
- [ ] If all beacon measurements are NaN at a timestep:
  - Skip update step entirely
  - Use prediction only: x̂_k+1 = x̄_k+1, P̂_k+1 = P̄_k+1
- [ ] Handle partial visibility (some beacons visible, others NaN)

### 5. EKF Initialization

- [ ] Initialize state estimate: x̂₀ = [0, 0, 0]ᵀ (at origin, heading 0)
- [ ] Initialize covariance matrix: P₀ = diag([σ_x², σ_y², σ_θ²])
  - Use small values for initial position uncertainty (e.g., 0.01²)
  - Use larger value for initial heading uncertainty (e.g., 0.1²)
- [ ] Process noise covariance Q based on Vn and Wn parameters:
  - Q = diag([Vn², Wn²]) for linear and angular velocity noise

### 6. Output Generation

- [ ] Generate estimated trajectory matrix: M×3 where M = number of trajectory points
- [ ] Each row: [x_est, y_est, θ_est] (estimated pose at each timestep)
- [ ] Save to loc_129466.txt (comma-separated format)
- [ ] One pose estimate per line: "x, y, θ"
- [ ] File must contain estimates for ALL trajectory points from Phase 1

## Input Specifications

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| N | integer | 4 | Number of beacons |
| Dt | scalar | 1 | Sensor sampling time interval (seconds) |
| Vn | scalar | 0.1 | Linear velocity uncertainty sigma (m/s) |
| Wn | scalar | 0.1 | Angular velocity uncertainty sigma (rad/s) |
| trajectory | M×3 matrix | - | Trajectory from Phase 1 [x, y, θ] |

## Output Specifications

| Output | Type | Description |
|--------|------|-------------|
| estimated_trajectory | M×3 matrix | EKF estimated poses [x_est, y_est, θ_est] |
| loc_129466.txt | text file | Comma-separated estimated trajectory |

### loc_129466.txt Format

```
x1, y1, θ1
x2, y2, θ2
x3, y3, θ3
...
xn, yn, θn
```

Where each line represents the EKF estimated pose at each trajectory point.

## Acceptance Criteria

### Must Have
- [ ] EKF prediction step correctly computes x̄_k+1 and P̄_k+1
- [ ] Observation model correctly predicts distance and angle to beacons
- [ ] EKF update step computes Kalman gain, updates state and covariance
- [ ] Program handles variable numbers of visible beacons (1 to N)
- [ ] NaN measurements are properly skipped without crashing
- [ ] All-NaN case: prediction-only mode works correctly
- [ ] Output file loc_129466.txt is created with correct format
- [ ] Estimated trajectory has same number of points as input trajectory
- [ ] Program runs without MATLAB errors
- [ ] Jacobian J_h dimensions adjust dynamically based on valid measurements

### Should Have
- [ ] Covariance matrices (P, Q, R) are properly maintained and symmetric
- [ ] Kalman gain calculation uses efficient matrix operations
- [ ] EKF converges to reasonable estimates near true trajectory
- [ ] Process noise Q correctly incorporates Vn and Wn parameters
- [ ] Measurement noise R correctly obtained from BeaconDetection()

### Won't Have
- [ ] Kinematic model calculations (Differential Drive, Tricycle, Omnidirectional) - those are Phase 3
- [ ] Output files DD_129466.txt, TRI_129466.txt, OMNI_129466.txt - those are Phase 3
- [ ] Navigation TO beacons (beacons are landmarks for measurement only)
- [ ] Hard-coded beacon positions (must use BeaconDetection())
- [ ] Localization using only deterministic methods (must use EKF)
- [ ] Fixed J_h matrix dimensions (must be variable based on visible beacons)

## Edge Cases

### 1. All Beacons Return NaN
- **Case**: All beacon measurements are NaN at a timestep
- **Expected behavior**: Skip EKF update step; use prediction only (x̂ = x̄, P̂ = P̄); continue to next timestep

### 2. Single Visible Beacon
- **Case**: Only 1 beacon returns valid measurements (d, a), others are NaN
- **Expected behavior**: J_h matrix is 2×3; innovation vector has 2 elements; EKF update proceeds with reduced measurement vector

### 3. Partial Beacon Visibility
- **Case**: 3 beacons total, only 2 return valid data at a timestep
- **Expected behavior**: J_h matrix is 4×3 (2 beacons × 2 measurements each); R matrix adjusted to 4×4; update proceeds with available measurements

### 4. Exactly Two Visible Beacons
- **Case**: 2 beacons visible and returning valid data
- **Expected behavior**: Standard EKF update with J_h = 4×3, innovation = 4×1

### 5. All Beacons Visible (Redundant Case)
- **Case**: N beacons all returning valid measurements (N > 2)
- **Expected behavior**: J_h matrix is (2N)×3; innovation is (2N)×1; EKF uses all measurements for robust localization

### 6. First EKF Step (Initialization)
- **Case**: Initial state at (0, 0, 0) with initial covariance P₀
- **Expected behavior**: First prediction uses initial state; first update (if measurements available) corrects initial estimate

### 7. Consecutive NaN Measurements
- **Case**: Multiple consecutive timesteps with all NaN measurements
- **Expected behavior**: Prediction-only mode continues; uncertainty (P) grows over time due to process noise; no crashes

### 8. Mixed NaN Pattern
- **Case**: At a timestep, beacon 1 = valid, beacon 2 = NaN, beacon 3 = valid, beacon 4 = NaN
- **Expected behavior**: J_h includes only beacons 1 and 3 (4 rows total); innovation has 4 elements; R adjusted to 4×4

### 9. Large Process Noise (High Vn, Wn)
- **Case**: Vn = 1.0, Wn = 1.0 (high uncertainty)
- **Expected behavior**: Prediction covariance P̄ grows faster; Kalman gain adjusts to trust measurements more relative to prediction

### 10. Small Process Noise (Low Vn, Wn)
- **Case**: Vn = 0.01, Wn = 0.01 (low uncertainty)
- **Expected behavior**: Prediction covariance P̄ grows slowly; Kalman gain adjusts to trust prediction more relative to measurements

## Dependencies

### Required Functions
- **BeaconDetection()**: Provided function for beacon position and measurement simulation
  - Returns beacon positions and measurement noise characteristics
  - Must be used as-is for beacon measurements
- **sqrt()**: MATLAB built-in for distance calculations
- **atan2()**: MATLAB built-in for angle calculations
- **eye()**, **zeros()**, **diag()**: MATLAB built-in for matrix creation
- **inv()** or **pinv()**: MATLAB built-in for matrix inversion (for S⁻¹)

### Prior Phase Dependencies
- **Phase 1 Complete**: Trajectory from Phase 1 required as input (M×3 matrix [x, y, θ])
- Understanding of Extended Kalman Filter theory
- Familiarity with Jacobian calculations

### Parameters
- **Dt**: Sampling time interval in seconds (scalar, default: 1)
- **Vn**: Linear velocity uncertainty sigma (scalar, default: 0.1 m/s)
- **Wn**: Angular velocity uncertainty sigma (scalar, default: 0.1 rad/s)

### External Dependencies
- Standard MATLAB functions (no additional toolboxes required for EKF core)
- Peter Corke's Robotics Toolbox (RTB) - optional, for reference only in Phase 2

## Excluded from Phase 2

The following are NOT in Phase 2 scope and will be addressed in later phases:
- Kinematic model calculations (Differential Drive, Tricycle, Omnidirectional) - Phase 3
- Output files DD_129466.txt, TRI_129466.txt, OMNI_129466.txt - Phase 3
- Trajectory planning (already completed in Phase 1)
- Beacon detection simulation (use BeaconDetection() as-is)

> **Key Clarification**: Phase 2 focuses on EKF core algorithm and generating the localization output (loc_129466.txt). The kinematic calculations for different robot types are Phase 3 scope.

## Technical Notes

### State Vector and Covariance
- State: x = [x, y, θ]ᵀ (3×1)
- Covariance: P (3×3) symmetric positive semi-definite matrix

### Jacobian Dimensions Summary
| Jacobian | Dimensions | Description |
|----------|------------|-------------|
| J_fx | 3×3 | ∂f/∂x (motion model wrt state) |
| J_fw | 3×2 | ∂f/∂w (motion model wrt noise) |
| J_h | (2k)×3 | ∂h/∂x (observation model wrt state), k = valid beacons |

### EKF Algorithm Summary
```
Initialize: x̂₀, P₀
For each timestep k = 0, 1, 2, ...:
    // Prediction
    x̄_k+1 = f(x̂_k, u_k, w_k)
    P̄_k+1 = J_fx(x̂_k, u_k, w_k) · P̂_k · J_fxᵀ + J_fw(x̂_k, u_k, w_k) · Q · J_fwᵀ
    
    // Update (if measurements available)
    If any beacon measurements valid:
        ν_k+1 = z_k+1 - h(x̄_k+1)
        S = J_h(x̄_k+1) · P̄_k+1 · J_hᵀ + R
        K = P̄_k+1 · J_hᵀ · S⁻¹
        x̂_k+1 = x̄_k+1 + K · ν
        P̂_k+1 = P̄_k+1 - K · S · Kᵀ
    Else:
        x̂_k+1 = x̄_k+1
        P̂_k+1 = P̄_k+1
```

### Measurement Vector Structure
For k valid beacons, the measurement vector z is:
```
z = [d₁, a₁, d₂, a₂, ..., dₖ, aₖ]ᵀ  (2k × 1)
```
Where dᵢ = distance to beacon i, aᵢ = bearing angle to beacon i
