# Phase 2: EKF Core + Localization - Design Document

## Overview

Phase 2 implements the **Extended Kalman Filter (EKF) core** for robot localization using beacon measurements. The EKF estimates the robot's pose (x, y, θ) by combining:
1. **Prediction**: Motion model based on control inputs (v, ω)
2. **Update**: Beacon measurements (distance and bearing) when available

Beacons are **fixed landmarks** in the environment. The robot measures distance and bearing TO beacons during navigation - beacons are NOT navigation targets.

---

## 1. Function Interface

### 1.1 Main EKF Function Signature

```matlab
function [estimated_trajectory, P_history] = ekfLocalization(trajectory, N, Dt, Vn, Wn, V)
%EKFLOCALIZATION Extended Kalman Filter for robot localization
%
% Input:
%   trajectory - M×3 matrix [x, y, θ] from Phase 1 (ground truth)
%   N          - Number of beacons (default: 4)
%   Dt         - Sensor sampling time interval in seconds (default: 1)
%   Vn         - Linear velocity uncertainty sigma (default: 0.1 m/s)
%   Wn         - Angular velocity uncertainty sigma (default: 0.1 rad/s)
%   V          - Desired average linear velocity (default: 5 m/s)
%
% Output:
%   estimated_trajectory - M×3 matrix [x_est, y_est, θ_est]
%   P_history           - M×3×3 matrix of covariance history (optional)
%
% Example:
%   est_traj = ekfLocalization(trajectory, 4, 1, 0.1, 0.1, 5);
%
% Note: Beacons are fixed landmarks. Robot measures TO them, not navigates TO them.

    % Set defaults
    if nargin < 2 || isempty(N), N = 4; end
    if nargin < 3 || isempty(Dt), Dt = 1; end
    if nargin < 4 || isempty(Vn), Vn = 0.1; end
    if nargin < 5 || isempty(Wn), Wn = 0.1; end
    if nargin < 6 || isempty(V), V = 5; end
    
    % Get beacon positions and noise parameters
    B = BeaconDetection(N);
    beacons = B.beacons;  % N×2 matrix [x_b, y_b]
    
    % Initialize EKF
    [x_hat, P] = ekfInitialize(Vn, Wn);
    
    % Process noise covariance
    Q = [Vn^2, 0; 0, Wn^2];  % 2×2 matrix
    
    % Measurement noise covariance (will be expanded based on valid beacons)
    R_base = [B.dn^2, 0; 0, B.an^2];  % 2×2 for single beacon
    
    % Preallocate output
    M = size(trajectory, 1);
    estimated_trajectory = zeros(M, 3);
    P_history = zeros(M, 3, 3);
    
    % Store initial estimate
    estimated_trajectory(1, :) = x_hat';
    P_history(1, :, :) = P;
    
    % EKF Main Loop
    for k = 1:(M-1)
        % Get current ground truth pose (for control input calculation)
        x_prev = trajectory(k, :)';
        x_curr = trajectory(k+1, :)';
        
        % Calculate control input from trajectory
        [v, omega, dt_actual] = computeControlInput(x_prev, x_curr, V);
        
        % ========== PREDICTION STEP ==========
        [x_bar, P_bar, Fx, Fv] = ekfPredict(x_hat, P, v, omega, dt_actual, Q);
        
        % ========== GET BEACON MEASUREMENTS ==========
        % Robot position at predicted state
        robot_pose = [x_bar(1), x_bar(2), x_bar(3)];
        
        % Get beacon measurements (with possible NaN)
        B_meas = BeaconDetection(N, robot_pose);
        
        % ========== UPDATE STEP ==========
        if any(~isnan(B_meas.d)) || any(~isnan(B_meas.a))
            % Valid measurements exist - perform update
            [x_hat, P] = ekfUpdate(x_bar, P_bar, B_meas, beacons, R_base);
        else
            % No valid measurements - prediction only
            x_hat = x_bar;
            P = P_bar;
        end
        
        % Store estimate
        estimated_trajectory(k+1, :) = x_hat';
        P_history(k+1, :, :) = P;
    end
end
```

### 1.2 Input Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| trajectory | M×3 matrix | - | Ground truth trajectory [x, y, θ] from Phase 1 |
| N | integer | 4 | Number of beacons (fixed landmarks) |
| Dt | scalar | 1 | Sensor sampling time interval (seconds) |
| Vn | scalar | 0.1 | Linear velocity noise sigma (m/s) |
| Wn | scalar | 0.1 | Angular velocity noise sigma (rad/s) |
| V | scalar | 5 | Desired average linear velocity (m/s) |

### 1.3 Output Specification

| Output | Type | Description |
|--------|------|-------------|
| estimated_trajectory | M×3 matrix | EKF estimated poses [x_est, y_est, θ_est] |
| P_history | M×3×3 matrix | Covariance history (optional, for analysis) |

**loc_129466.txt Format:**
```
x1, y1, θ1
x2, y2, θ2
x3, y3, θ3
...
xn, yn, θn
```

---

## 2. Motion Model (Prediction Step)

### 2.1 State Vector Definition

The robot state is a 3×1 vector:

\[
\mathbf{x} = \begin{bmatrix} x \\ y \\ \theta \end{bmatrix}
\]

Where:
- \(x\): Robot X position (meters)
- \(y\): Robot Y position (meters)
- \(\theta\): Robot heading (radians, from X-axis)

### 2.2 Process Model Function

The motion model predicts the next state based on current state and control inputs:

\[
\mathbf{f}(\mathbf{x}_k, \mathbf{u}_k, \mathbf{w}_k) = \begin{bmatrix}
x_k + v_k \cos(\theta_k) \Delta t \\
y_k + v_k \sin(\theta_k) \Delta t \\
\theta_k + \omega_k \Delta t
\end{bmatrix}
\]

Where:
- \(v_k\): Linear velocity (m/s)
- \(\omega_k\): Angular velocity (rad/s)
- \(\Delta t\): Time step (seconds)
- \(\mathbf{w}_k \sim \mathcal{N}(0, \mathbf{Q})\): Process noise

### 2.3 Jacobian J_fx (State Jacobian)

The Jacobian of the motion model with respect to the state vector:

\[
\mathbf{J}_{fx} = \frac{\partial \mathbf{f}}{\partial \mathbf{x}} = \begin{bmatrix}
1 & 0 & -v_k \sin(\theta_k) \Delta t \\
0 & 1 &  v_k \cos(\theta_k) \Delta t \\
0 & 0 &  1
\end{bmatrix}_{3 \times 3}
\]

**MATLAB Code:**
```matlab
% Compute J_fx (3×3)
J_fx = [1, 0, -v * sin(theta) * dt;
        0, 1,  v * cos(theta) * dt;
        0, 0,  1];
```

### 2.4 Jacobian J_fw (Noise Jacobian)

The Jacobian of the motion model with respect to process noise:

\[
\mathbf{J}_{fw} = \frac{\partial \mathbf{f}}{\partial \mathbf{w}} = \begin{bmatrix}
\cos(\theta_k) \Delta t & 0 \\
\sin(\theta_k) \Delta t & 0 \\
0 & \Delta t
\end{bmatrix}_{3 \times 2}
\]

**MATLAB Code:**
```matlab
% Compute J_fw (3×2)
J_fw = [cos(theta) * dt, 0;
        sin(theta) * dt, 0;
        0, dt];
```

### 2.5 Process Noise Covariance Q

The process noise covariance matrix (2×2) is constructed from Vn and Wn:

\[
\mathbf{Q} = \begin{bmatrix}
Vn^2 & 0 \\
0 & Wn^2
\end{bmatrix}
\]

**MATLAB Code:**
```matlab
% Process noise covariance (2×2)
Q = [Vn^2, 0; 0, Wn^2];
```

### 2.6 Covariance Propagation

The predicted covariance is computed as:

\[
\bar{\mathbf{P}}_{k+1} = \mathbf{J}_{fx} \hat{\mathbf{P}}_k \mathbf{J}_{fx}^T + \mathbf{J}_{fw} \mathbf{Q} \mathbf{J}_{fw}^T
\]

**MATLAB Code:**
```matlab
% Covariance prediction (3×3)
P_bar = J_fx * P * J_fx' + J_fw * Q * J_fw';
```

### 2.7 Complete Prediction Function

```matlab
function [x_bar, P_bar, J_fx, J_fw] = ekfPredict(x_hat, P, v, omega, dt, Q)
%EKFPREDICT EKF prediction step using motion model
%
% Input:
%   x_hat - 3×1 current state estimate [x; y; θ]
%   P      - 3×3 current covariance matrix
%   v      - linear velocity (m/s)
%   omega  - angular velocity (rad/s)
%   dt     - time step (seconds)
%   Q      - 2×2 process noise covariance
%
% Output:
%   x_bar  - 3×1 predicted state
%   P_bar  - 3×3 predicted covariance
%   J_fx   - 3×3 state Jacobian
%   J_fw   - 3×2 noise Jacobian

    theta = x_hat(3);
    cos_t = cos(theta);
    sin_t = sin(theta);
    
    % ========== STATE PREDICTION ==========
    x_bar = [x_hat(1) + v * cos_t * dt;
             x_hat(2) + v * sin_t * dt;
             x_hat(3) + omega * dt];
    
    % ========== JACOBIAN J_fx (3×3) ==========
    J_fx = [1, 0, -v * sin_t * dt;
            0, 1,  v * cos_t * dt;
            0, 0,  1];
    
    % ========== JACOBIAN J_fw (3×2) ==========
    J_fw = [cos_t * dt, 0;
            sin_t * dt, 0;
            0, dt];
    
    % ========== COVARIANCE PREDICTION ==========
    P_bar = J_fx * P * J_fx' + J_fw * Q * J_fw';
    
    % Ensure P_bar is symmetric (numerical stability)
    P_bar = (P_bar + P_bar') / 2;
end
```

### 2.8 Control Input Calculation

The control input (v, ω) is derived from the trajectory:

```matlab
function [v, omega, dt] = computeControlInput(x_prev, x_curr, V)
%COMPUTECONTROLINPUT Calculate control inputs from trajectory
%
% Input:
%   x_prev - 3×1 previous pose [x; y; θ]
%   x_curr - 3×1 current pose [x; y; θ]
%   V      - desired linear velocity (m/s)
%
% Output:
%   v      - linear velocity (m/s)
%   omega  - angular velocity (rad/s)
%   dt     - time step (seconds)

    % Calculate distance and angle change
    dx = x_curr(1) - x_prev(1);
    dy = x_curr(2) - x_prev(2);
    d = sqrt(dx^2 + dy^2);  % Distance traveled
    
    % Linear velocity is constant (given by V)
    v = V;
    
    % Time step based on distance and velocity
    if v > 0
        dt = d / v;
    else
        dt = 1.0;  % Default if stationary
    end
    
    % Angular velocity from heading change
    dtheta = x_curr(3) - x_prev(3);
    
    % Normalize angle to [-pi, pi]
    dtheta = atan2(sin(dtheta), cos(dtheta));
    
    if dt > 0
        omega = dtheta / dt;
    else
        omega = 0;
    end
end
```

---

## 3. Observation Model

### 3.1 Observation Function

For each beacon \(i\) at position \((x_{b,i}, y_{b,i})\), the predicted observation is:

\[
\mathbf{h}_i(\mathbf{x}) = \begin{bmatrix}
d_i \\
\alpha_i
\end{bmatrix}
\]

Where:

**Predicted Distance:**
\[
d_i = \sqrt{(x_{b,i} - x)^2 + (y_{b,i} - y)^2}
\]

**Predicted Bearing Angle:**
\[
\alpha_i = \text{atan2}(y_{b,i} - y, x_{b,i} - x) - \theta
\]

### 3.2 Jacobian J_h (Observation Jacobian)

For a single beacon, the Jacobian of the observation model with respect to the state:

\[
\mathbf{J}_{h,i} = \frac{\partial \mathbf{h}_i}{\partial \mathbf{x}} = \begin{bmatrix}
\frac{\partial d_i}{\partial x} & \frac{\partial d_i}{\partial y} & \frac{\partial d_i}{\partial \theta} \\
\frac{\partial \alpha_i}{\partial x} & \frac{\partial \alpha_i}{\partial y} & \frac{\partial \alpha_i}{\partial \theta}
\end{bmatrix}
\]

Let:
- \(\Delta x_i = x_{b,i} - x\)
- \(\Delta y_i = y_{b,i} - y\)
- \(r_i = \sqrt{\Delta x_i^2 + \Delta y_i^2}\)

**Partial Derivatives for Distance:**
\[
\frac{\partial d_i}{\partial x} = -\frac{\Delta x_i}{r_i}, \quad
\frac{\partial d_i}{\partial y} = -\frac{\Delta y_i}{r_i}, \quad
\frac{\partial d_i}{\partial \theta} = 0
\]

**Partial Derivatives for Angle:**
\[
\frac{\partial \alpha_i}{\partial x} = \frac{\Delta y_i}{r_i^2}, \quad
\frac{\partial \alpha_i}{\partial y} = -\frac{\Delta x_i}{r_i^2}, \quad
\frac{\partial \alpha_i}{\partial \theta} = -1
\]

**Single Beacon Jacobian (2×3):**
\[
\mathbf{J}_{h,i} = \begin{bmatrix}
-\frac{\Delta x_i}{r_i} & -\frac{\Delta y_i}{r_i} & 0 \\
\frac{\Delta y_i}{r_i^2} & -\frac{\Delta x_i}{r_i^2} & -1
\end{bmatrix}
\]

### 3.3 Combined Jacobian for Multiple Beacons

For \(k\) visible beacons, the combined Jacobian is:

\[
\mathbf{J}_h = \begin{bmatrix}
\mathbf{J}_{h,1} \\
\mathbf{J}_{h,2} \\
\vdots \\
\mathbf{J}_{h,k}
\end{bmatrix}_{(2k \times 3)}
\]

**MATLAB Code for Single Beacon:**
```matlab
% For beacon i at (xb, yb), robot at (x, y, theta)
dx = xb - x;
dy = yb - y;
r = sqrt(dx^2 + dy^2);  % Distance to beacon

% Jacobian J_h for this beacon (2×3)
J_h_i = [-dx/r, -dy/r, 0;
          dy/r^2, -dx/r^2, -1];
```

### 3.4 Complete Observation Model Function

```matlab
function [z_pred, J_h, valid_indices] = observationModel(x_bar, beacons, B_meas)
%OBSERVATIONMODEL Compute predicted beacon observations and Jacobian
%
% Input:
%   x_bar       - 3×1 predicted state [x; y; θ]
%   beacons     - N×2 matrix of beacon positions [x_b, y_b]
%   B_meas      - BeaconDetection output with measurements
%
% Output:
%   z_pred      - (2k)×1 predicted observation vector for valid beacons
%   J_h         - (2k)×3 observation Jacobian for valid beacons
%   valid_indices - indices of beacons with valid measurements

    N = size(beacons, 1);
    x = x_bar(1);
    y = x_bar(2);
    theta = x_bar(3);
    
    % Initialize outputs
    z_pred = [];
    J_h = [];
    valid_indices = [];
    
    % Process each beacon
    for i = 1:N
        % Check if measurement is valid (not NaN)
        if ~isnan(B_meas.d(i)) && ~isnan(B_meas.a(i))
            % Beacon position
            xb = beacons(i, 1);
            yb = beacons(i, 2);
            
            % Relative position
            dx = xb - x;
            dy = yb - y;
            r = sqrt(dx^2 + dy^2);
            
            % Avoid division by zero
            if r < 1e-6
                r = 1e-6;
            end
            
            % Predicted observation (2×1)
            d_pred = r;
            a_pred = atan2(dy, dx) - theta;
            a_pred = atan2(sin(a_pred), cos(a_pred));  % Normalize
            
            % Append to prediction vector
            z_pred = [z_pred; d_pred; a_pred];
            
            % Jacobian for this beacon (2×3)
            J_h_i = [-dx/r, -dy/r, 0;
                     dy/r^2, -dx/r^2, -1];
            
            % Append to combined Jacobian
            J_h = [J_h; J_h_i];
            
            % Record valid index
            valid_indices = [valid_indices; i];
        end
    end
end
```

---

## 4. EKF Update Step

### 4.1 Innovation (Measurement Residual)

The innovation vector is the difference between actual and predicted measurements:

\[
\boldsymbol{\nu}_k = \mathbf{z}_k - \mathbf{h}(\bar{\mathbf{x}}_k)
\]

Where:
- \(\mathbf{z}_k\): Actual measurement vector (2k×1)
- \(\mathbf{h}(\bar{\mathbf{x}}_k)\): Predicted measurement vector (2k×1)

**MATLAB Code:**
```matlab
% Build actual measurement vector from valid beacons
z_actual = [];
for i = 1:length(valid_indices)
    idx = valid_indices(i);
    z_actual = [z_actual; B_meas.d(idx); B_meas.a(idx)];
end

% Innovation
nu = z_actual - z_pred;  % (2k)×1
```

### 4.2 Innovation Covariance

\[
\mathbf{S} = \mathbf{J}_h \bar{\mathbf{P}} \mathbf{J}_h^T + \mathbf{R}
\]

Where:
- \(\mathbf{J}_h\): (2k×3) observation Jacobian
- \(\bar{\mathbf{P}}\): (3×3) predicted covariance
- \(\mathbf{R}\): (2k×2k) measurement noise covariance

**MATLAB Code:**
```matlab
% Measurement noise covariance for valid beacons
k = length(valid_indices);
R = zeros(2*k, 2*k);
for i = 1:k
    R(2*i-1, 2*i-1) = B.dn^2;  % Distance variance
    R(2*i, 2*i) = B.an^2;      % Angle variance
end

% Innovation covariance (2k)×(2k)
S = J_h * P_bar * J_h' + R;
```

### 4.3 Kalman Gain

\[
\mathbf{K} = \bar{\mathbf{P}} \mathbf{J}_h^T \mathbf{S}^{-1}
\]

Dimensions: \(\mathbf{K}\) is (3×2k)

**MATLAB Code:**
```matlab
% Kalman gain (3)×(2k)
K = P_bar * J_h' / S;  % Using / for efficient solve
```

### 4.4 State Update

\[
\hat{\mathbf{x}}_k = \bar{\mathbf{x}}_k + \mathbf{K} \boldsymbol{\nu}
\]

**MATLAB Code:**
```matlab
% State update (3×1)
x_hat = x_bar + K * nu;
```

### 4.5 Covariance Update

Using the Joseph form for numerical stability:

\[
\hat{\mathbf{P}}_k = (\mathbf{I} - \mathbf{K} \mathbf{J}_h) \bar{\mathbf{P}} (\mathbf{I} - \mathbf{K} \mathbf{J}_h)^T + \mathbf{K} \mathbf{R} \mathbf{K}^T
\]

Simplified form (if Joseph form is not needed):

\[
\hat{\mathbf{P}}_k = (\mathbf{I} - \mathbf{K} \mathbf{J}_h) \bar{\mathbf{P}}
\]

**MATLAB Code (Joseph Form):**
```matlab
% Covariance update (Joseph form for stability)
I = eye(3);
P = (I - K * J_h) * P_bar * (I - K * J_h)' + K * R * K';

% Ensure symmetry
P = (P + P') / 2;
```

### 4.6 Complete Update Function

```matlab
function [x_hat, P] = ekfUpdate(x_bar, P_bar, B_meas, beacons, R_base)
%EKFUPDATE EKF update step with NaN handling
%
% Input:
%   x_bar   - 3×1 predicted state
%   P_bar   - 3×3 predicted covariance
%   B_meas  - BeaconDetection output structure
%   beacons - N×2 matrix of beacon positions
%   R_base  - 2×2 base measurement noise covariance
%
% Output:
%   x_hat   - 3×1 updated state estimate
%   P       - 3×3 updated covariance

    % ========== GET PREDICTED OBSERVATIONS ==========
    [z_pred, J_h, valid_indices] = observationModel(x_bar, beacons, B_meas);
    
    % Check if any valid measurements
    if isempty(valid_indices)
        % No valid measurements - return prediction
        x_hat = x_bar;
        P = P_bar;
        return;
    end
    
    % ========== BUILD ACTUAL MEASUREMENT VECTOR ==========
    z_actual = [];
    k = length(valid_indices);  % Number of valid beacons
    
    for i = 1:k
        idx = valid_indices(i);
        z_actual = [z_actual; B_meas.d(idx); B_meas.a(idx)];
    end
    
    % ========== INNOVATION ==========
    nu = z_actual - z_pred;  % (2k)×1
    
    % ========== INNOVATION COVARIANCE ==========
    % Build R matrix for valid beacons (2k)×(2k)
    R = zeros(2*k, 2*k);
    for i = 1:k
        R(2*i-1, 2*i-1) = R_base(1,1);  % Distance variance (dn^2)
        R(2*i, 2*i) = R_base(2,2);      % Angle variance (an^2)
    end
    
    % S = J_h * P_bar * J_h' + R
    S = J_h * P_bar * J_h' + R;  % (2k)×(2k)
    
    % ========== KALMAN GAIN ==========
    K = P_bar * J_h' / S;  % (3)×(2k)
    
    % ========== STATE UPDATE ==========
    x_hat = x_bar + K * nu;  % 3×1
    
    % ========== COVARIANCE UPDATE (Joseph Form) ==========
    I = eye(3);
    P = (I - K * J_h) * P_bar * (I - K * J_h)' + K * R * K';
    
    % Ensure symmetry (numerical stability)
    P = (P + P') / 2;
    
    % Ensure positive semi-definite (optional, for robustness)
    [U, D, V] = svd(P);
    D = max(D, 0);  % Set negative eigenvalues to zero
    P = U * D * V';
end
```

---

## 5. NaN Handling (Variable Beacon Visibility)

### 5.1 Strategy

The `BeaconDetection()` function returns NaN for beacons that are:
- Out of range (too close < 0.3m or too far > 10m)
- Randomly missed (~5% chance)

The EKF must handle variable numbers of visible beacons (0 to N).

### 5.2 Detection of NaN Values

```matlab
% Check for NaN in distance or angle measurements
function valid_mask = getValidBeaconMask(B_meas, N)
%GETVALIDBEACONMASK Returns logical mask of valid beacon measurements
%
% Input:
%   B_meas - BeaconDetection output structure
%   N      - Number of beacons
%
% Output:
%   valid_mask - N×1 logical array (true for valid measurements)

    valid_mask = ~isnan(B_meas.d(1:N)) & ~isnan(B_meas.a(1:N));
end
```

### 5.3 Dynamic Matrix Sizing

When beacons return NaN, the observation Jacobian and measurement noise matrices must be dynamically resized:

```matlab
% Count valid measurements
valid_count = sum(valid_mask);

if valid_count == 0
    % All NaN - skip update
    x_hat = x_bar;
    P = P_bar;
    return;
end

% Build reduced Jacobian (2*valid_count)×3
J_h_reduced = zeros(2*valid_count, 3);
% ... fill with only valid beacon Jacobians

% Build reduced R matrix (2*valid_count)×(2*valid_count)
R_reduced = zeros(2*valid_count, 2*valid_count);
% ... fill diagonal with noise variances
```

### 5.4 Edge Cases

| Case | Valid Beacons | Behavior |
|------|---------------|----------|
| All NaN | 0 | Skip update; use prediction only |
| Single beacon | 1 | J_h is 2×3; update proceeds |
| Partial visibility | 1 < k < N | J_h is (2k)×3; use available measurements |
| All visible | N | J_h is (2N)×3; standard EKF update |
| Mixed pattern | Variable | Dynamically build J_h and R |

### 5.5 Implementation in Main Loop

```matlab
% In the main EKF loop:
for k = 1:(M-1)
    % ... prediction step ...
    
    % Get beacon measurements
    robot_pose = [x_bar(1), x_bar(2), x_bar(3)];
    B_meas = BeaconDetection(N, robot_pose);
    
    % Check for valid measurements
    valid_mask = ~isnan(B_meas.d) & ~isnan(B_meas.a);
    valid_count = sum(valid_mask);
    
    if valid_count > 0
        % Valid measurements exist - perform update
        [x_hat, P] = ekfUpdate(x_bar, P_bar, B_meas, beacons, R_base);
    else
        % No valid measurements - prediction only
        fprintf('Timestep %d: All beacons NaN - using prediction only\n', k);
        x_hat = x_bar;
        P = P_bar;
    end
end
```

---

## 6. EKF Initialization

### 6.1 Initial State

\[
\hat{\mathbf{x}}_0 = \begin{bmatrix} 0 \\ 0 \\ 0 \end{bmatrix}
\]

**MATLAB Code:**
```matlab
x_hat = [0; 0; 0];  % Start at origin, heading 0
```

### 6.2 Initial Covariance

Initial uncertainty is small for position (known start) and larger for heading:

\[
\mathbf{P}_0 = \begin{bmatrix}
\sigma_x^2 & 0 & 0 \\
0 & \sigma_y^2 & 0 \\
0 & 0 & \sigma_\theta^2
\end{bmatrix}
= \begin{bmatrix}
0.01 & 0 & 0 \\
0 & 0.01 & 0 \\
0 & 0 & 0.1
\end{bmatrix}
\]

**MATLAB Code:**
```matlab
P = diag([0.01^2, 0.01^2, 0.1^2]);  % [0.0001, 0.0001, 0.01]
% Alternative: slightly larger initial uncertainty
P = diag([0.01, 0.01, 0.1]);  % Diagonal matrix
```

### 6.3 Complete Initialization Function

```matlab
function [x_hat, P] = ekfInitialize(Vn, Wn)
%EKFINITIALIZE Initialize EKF state and covariance
%
% Input:
%   Vn - Linear velocity noise sigma (for reference)
%   Wn - Angular velocity noise sigma (for reference)
%
% Output:
%   x_hat - 3×1 initial state estimate
%   P     - 3×3 initial covariance matrix

    % Initial state: at origin, heading 0
    x_hat = [0; 0; 0];
    
    % Initial covariance
    % Small uncertainty in position (we know we start at origin)
    % Larger uncertainty in heading
    sigma_x = 0.01;   % 1cm standard deviation
    sigma_y = 0.01;   % 1cm standard deviation
    sigma_theta = 0.1; % ~5.7 degrees standard deviation
    
    P = diag([sigma_x^2, sigma_y^2, sigma_theta^2]);
    
    % Alternative: use Vn, Wn for scaling
    % P = diag([Vn^2, Vn^2, Wn^2]);
end
```

---

## 7. Output Generation

### 7.1 Save Estimated Trajectory

```matlab
function saveLocalizationResults(estimated_trajectory, filename)
%SAVELOCALIZATIONRESULTS Save EKF results to file
%
% Input:
%   estimated_trajectory - M×3 matrix [x_est, y_est, θ_est]
%   filename             - output filename (e.g., 'loc_129466.txt')

    fid = fopen(filename, 'w');
    
    M = size(estimated_trajectory, 1);
    
    for i = 1:M
        fprintf(fid, '%.6f, %.6f, %.6f\n', ...
            estimated_trajectory(i, 1), ...
            estimated_trajectory(i, 2), ...
            estimated_trajectory(i, 3));
    end
    
    fclose(fid);
    fprintf('Saved localization results to %s\n', filename);
end
```

### 7.2 Integration with Main Function

```matlab
% At the end of rm1_129466.m, after Phase 2 EKF:
estimated_trajectory = ekfLocalization(trajectory, N, Dt, Vn, Wn, V);

% Save to loc_129466.txt
saveLocalizationResults(estimated_trajectory, 'loc_129466.txt');

% Display summary
fprintf('\nLocalization Results:\n');
fprintf('  Estimated trajectory: %d points\n', size(estimated_trajectory, 1));
fprintf('  First point: [%.2f, %.2f, %.2f]\n', estimated_trajectory(1, :));
fprintf('  Last point:  [%.2f, %.2f, %.2f]\n', estimated_trajectory(end, :));
```

---

## 8. Complete EKF Algorithm Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                  EKF Localization Algorithm                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. INITIALIZE                                                    │
│     x̂₀ = [0, 0, 0]ᵀ                                              │
│     P₀ = diag([0.01², 0.01², 0.1²])                             │
│     Q = diag([Vn², Wn²])                                         │
│                                                                  │
│  2. FOR each timestep k = 0, 1, 2, ..., M-1:                     │
│                                                                  │
│     ┌─────────────── PREDICTION ───────────────┐                  │
│     │  x̄ₖ₊₁ = f(x̂ₖ, uₖ)                      │                  │
│     │  P̄ₖ₊₁ = J_fx P̂ₖ J_fxᵀ + J_fw Q J_fwᵀ   │                  │
│     └─────────────────────────────────────────┘                  │
│                                                                  │
│     ┌─────────────── OBSERVATION ──────────────┐                  │
│     │  B_meas = BeaconDetection(N, x̄ₖ₊₁)      │                  │
│     │  Check for NaN in B_meas.d, B_meas.a    │                  │
│     └─────────────────────────────────────────┘                  │
│                                                                  │
│     ┌─────────────── UPDATE (if valid meas) ─────┐                │
│     │  z_pred, J_h = observationModel(x̄ₖ₊₁)    │                │
│     │  ν = z_actual - z_pred                    │                │
│     │  S = J_h P̄ J_hᵀ + R                       │                │
│     │  K = P̄ J_hᵀ S⁻¹                          │                │
│     │  x̂ₖ₊₁ = x̄ₖ₊₁ + K ν                       │                │
│     │  P̂ₖ₊₁ = (I - K J_h) P̄ (Joseph form)    │                │
│     └─────────────────────────────────────────┘                  │
│                                                                  │
│     ┌─────────────── UPDATE (if ALL NaN) ─────────┐              │
│     │  x̂ₖ₊₁ = x̄ₖ₊₁                                  │              │
│     │  P̂ₖ₊₁ = P̄ₖ₊₁                                  │              │
│     └─────────────────────────────────────────┘                  │
│                                                                  │
│  3. SAVE RESULTS                                                  │
│     Write estimated_trajectory to loc_129466.txt                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. MATLAB Code Structure

### 9.1 Files to Create/Modify

| File | Purpose |
|------|---------|
| `ekfLocalization.m` | Main EKF localization function |
| `ekfPredict.m` | EKF prediction step |
| `ekfUpdate.m` | EKF update step with NaN handling |
| `observationModel.m` | Observation model and Jacobian |
| `ekfInitialize.m` | EKF initialization |
| `computeControlInput.m` | Control input calculation |
| `saveLocalizationResults.m` | Save results to file |
| `rm1_129466.m` | Modified to call EKF and save loc_129466.txt |

### 9.2 Function Call Graph

```
rm1_129466.m
    │
    ├── planTrajectory()  (Phase 1)
    │
    ├── ekfLocalization()  (Phase 2 - NEW)
    │   │
    │   ├── ekfInitialize()
    │   │
    │   ├── [for each timestep]:
    │   │   ├── computeControlInput()
    │   │   ├── ekfPredict()
    │   │   ├── BeaconDetection()  (get measurements)
    │   │   └── ekfUpdate()
    │   │       └── observationModel()
    │   │
    │   └── saveLocalizationResults()
    │
    └── [Phase 3 functions will be added later]
```

---

## 10. Testing and Validation

### 10.1 Test Cases

```matlab
% Test 1: Basic EKF with all beacons visible
trajectory = planTrajectory(4, 1, 5);
est_traj = ekfLocalization(trajectory, 4, 1, 0.1, 0.1, 5);
assert(size(est_traj, 1) == size(trajectory, 1), 'Output size mismatch');

% Test 2: EKF with high process noise
est_traj2 = ekfLocalization(trajectory, 4, 1, 1.0, 1.0, 5);
% Should have larger uncertainty (check P history)

% Test 3: NaN handling - simulate all NaN
% (Requires modifying BeaconDetection to force NaN)

% Test 4: Single beacon visible
% (Requires specific beacon configuration)

% Test 5: Verify output file format
assert(exist('loc_129466.txt', 'file') == 2, 'Output file not created');
```

### 10.2 Validation Checks

- [ ] EKF prediction step correctly computes x̄ and P̄
- [ ] Observation model correctly predicts distance and angle
- [ ] EKF update step computes Kalman gain, updates state and covariance
- [ ] Program handles variable numbers of visible beacons (1 to N)
- [ ] NaN measurements are properly skipped without crashing
- [ ] All-NaN case: prediction-only mode works correctly
- [ ] Output file loc_129466.txt is created with correct format
- [ ] Estimated trajectory has same number of points as input trajectory
- [ ] Jacobian J_h dimensions adjust dynamically based on valid measurements
- [ ] Covariance matrices are symmetric and positive semi-definite

---

## 11. Key Implementation Notes

### 11.1 Numerical Stability

1. **Symmetric Covariance**: Always enforce symmetry after updates:
   ```matlab
   P = (P + P') / 2;
   ```

2. **Positive Semi-Definite**: Use SVD to fix invalid covariances:
   ```matlab
   [U, D, V] = svd(P);
   D = max(D, 0);  % Clip negative eigenvalues
   P = U * D * V';
   ```

3. **Matrix Inversion**: Use `\` or `/` operators instead of `inv()`:
   ```matlab
   K = P_bar * J_h' / S;  % Better than inv(S)
   ```

### 11.2 Angle Normalization

Always normalize angles to [-π, π]:
```matlab
theta = atan2(sin(theta), cos(theta));
```

Apply to:
- Heading estimates
- Bearing angle predictions
- Innovation (angle component)

### 11.3 Preallocation

Preallocate arrays for better performance:
```matlab
M = size(trajectory, 1);
estimated_trajectory = zeros(M, 3);
P_history = zeros(M, 3, 3);
```

---

## Appendix A: Matrix Dimensions Summary

| Matrix | Dimensions | Description |
|--------|------------|-------------|
| **State** | | |
| x̂ | 3×1 | State estimate [x; y; θ] |
| x̄ | 3×1 | Predicted state |
| **Covariance** | | |
| P̂ | 3×3 | State covariance |
| P̄ | 3×3 | Predicted covariance |
| **Jacobians** | | |
| J_fx | 3×3 | ∂f/∂x (motion model wrt state) |
| J_fw | 3×2 | ∂f/∂w (motion model wrt noise) |
| J_h | (2k)×3 | ∂h/∂x (observation model wrt state), k = valid beacons |
| **Noise Covariance** | | |
| Q | 2×2 | Process noise covariance |
| R | (2k)×(2k) | Measurement noise covariance |
| **Kalman Gain** | | |
| K | 3×(2k) | Kalman gain |
| **Innovation** | | |
| ν | (2k)×1 | Innovation vector |
| S | (2k)×(2k) | Innovation covariance |

---

## Appendix B: Example Usage

```matlab
% Complete Phase 2 example
clear; clc;

% Run main function (which calls Phase 1 and Phase 2)
rm1_129466(4, 1, 0.15, 1, 0.1, 0.1, 5);

% Load and verify output
data = load('loc_129466.txt');
disp('First 5 estimated poses:');
disp(data(1:5, :));

disp('Last 5 estimated poses:');
disp(data(end-4:end, :));

% Plot ground truth vs. estimate
trajectory = load('trajectory_backup.txt');  % If saved
figure;
plot(trajectory(:,1), trajectory(:,2), 'b-', 'LineWidth', 2); hold on;
plot(data(:,1), data(:,2), 'r--', 'LineWidth', 2);
legend('Ground Truth', 'EKF Estimate');
xlabel('X (m)'); ylabel('Y (m)');
title('EKF Localization Results');
grid on; axis equal;
```

---

*Document Version: 1.0*  
*Last Updated: 2026-04-29*  
*Phase: 2 - EKF Core + Localization*
