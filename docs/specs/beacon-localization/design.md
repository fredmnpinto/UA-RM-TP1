# Beacon Localization - Technical Design

## 1. Architecture Overview

### 1.1 System Components

The system consists of five main components that work together to achieve probabilistic robot localization:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    MAIN FUNCTION: rm1_nnnnnn                   │
│                    (Entry Point)                              │
└─────────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  Beacon      │    │  Trajectory   │    │    EKF        │
│  Detection   │    │  Planner      │    │  Localizer    │
│  Module      │    │  Module       │    │  Module       │
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │                     │
        │              ┌──────┴──────┐              │
        │              ▼             ▼              │
        │        ┌──────────┐ ┌──────────┐          │
        │        │ pchip()  │ │Control   │          │
        │        │ Interp.  │ │Input (v,ω)         │
        │        └──────────┘ └──────────┘          │
        │                                    ┌────────┴───────┐
        │                             ┌──────┴──────┐      │
        │                             ▼             ▼      ▼
        │                      ┌──────────┐ ┌──────────┐ ┌──────────┐
        │                      │ Motion   │ │Observation│ │Kalman   │
        │                      │ Model    │ │ Model     │ │Update   │
        │                      └──────────┘ └──────────┘ └──────────┘
        │                                    │             │
        │                             ┌──────┴────────────┴──┐
        │                             ▼                       ▼
        │                       ┌──────────┐          ┌──────────┐
        │                       │ State    │          │Covariance│
        │                       │ Estimate │          │  Matrix  │
        │                       └──────────┘          └──────────┘
        │                                    │
        └────────────────────────┼───────────┘
                                 ��
                    ┌─────────────────────────┐
                    │    Output Files         │
                    │  - loc_nnnnnn.txt       │
                    │  - DD_nnnnnn.txt        │
                    │  - TRI_nnnnnn.txt       │
                    │  - OMNI_nnnnnn.txt     │
                    └─────────────────────────┘
```

### 1.2 Data Flow

The data flows through the system as follows:

1. **Initialization Phase**
   - Call `BeaconDetection(N)` to get beacon positions and noise parameters
   - Extract beacon coordinates: `B.beacons` (N×2 matrix)
   - Extract noise params: `B.dn` (distance noise), `B.an` (angle noise)

2. **Trajectory Planning Phase**
   - Construct waypoint vector (independent trajectory - straight line from origin)
   - **IMPORTANT**: Waypoints are INDEPENDENT of beacon positions
   - Use `pchip()` to create smooth interpolation
   - Generate intermediate points at Δd = Dt × V spacing
   - Compute heading angles between consecutive points
   - **Note**: The robot navigates ALONG the trajectory and MEASURES distance/bearing TO beacons - it does NOT navigate TO beacons

3. **EKF Localization Phase**
   - For each trajectory point:
     - Compute control input from velocity/heading
     - **Prediction Step**: Propagate state and covariance
     - **Observation Step**: Get beacon measurements
     - **Update Step**: Apply EKF correction if valid beacons

4. **Kinematic Conversion Phase**
   - For each state estimate:
     - Compute differential drive wheel velocities (ωR, ωL)
     - Compute tricycle parameters (ωT, α)
     - Compute omnidirectional wheel velocities (ω1, ω2, ω3)

5. **Output Phase**
   - Write pose estimates to `loc_nnnnnn.txt`
   - Write kinematic commands to output files

### 1.3 Component Responsibilities

| Component | Responsibility | Public Interface |
|-----------|----------------|------------------|
| BeaconDetection | Generate beacon positions and noise | `B = BeaconDetection(N)` |
| TrajectoryPlanner | Generate independent path (straight line) through environment | `[xp, yp, thetap] = planTrajectory(beacons, Dt, V)` |
| MotionModel | Predict next state from velocities | `[x_next, Fx, Fv] = motionModel(x, v, omega, dt)` |
| ObservationModel | Predict beacon observations (distance/bearing TO beacons) | `[z, H] = observationModel(x, beacons)` |
| EKFLocalizer | State estimation with EKF using beacon measurements | `[x_est, P_est] = ekfUpdate(x_prev, P_prev, z, R)` |
| KinematicSolver | Convert to wheel commands | `[wheels] = computeKinematics(v, omega, model)` |

---

## 2. Data Models

### 2.1 State Vector Definition

The robot state is represented as a 3-element column vector:

\[
\mathbf{x} = \begin{bmatrix} x \\ y \\ \theta \end{bmatrix}
\]

Where:
- $x$: Robot position in global X direction (meters)
- $y$: Robot position in global Y direction (meters)
- $\theta$: Robot heading angle from global X-axis (radians)

**Initial State:**
\[
\mathbf{x}_0 = \begin{bmatrix} 0 \\ 0 \\ 0 \end{bmatrix}
\]

### 2.2 State Covariance Matrix

The state uncertainty is represented by a 3×3 covariance matrix:

\[
\mathbf{P} = \begin{bmatrix}
\sigma_{xx}^2 & \sigma_{xy} & \sigma_{x\theta} \\
\sigma_{yx} & \sigma_{yy}^2 & \sigma_{y\theta} \\
\sigma_{\theta x} & \sigma_{\theta y} & \sigma_{\theta}^2
\end{bmatrix}
\]

**Initial Covariance:**
\[
\mathbf{P}_0 = \begin{bmatrix}
0.01 & 0 & 0 \\
0 & 0.01 & 0 \\
0 & 0 & 0.1
\end{bmatrix}
\]

Note: Initial position is known precisely (0.01 m² variance), but heading has higher uncertainty (0.1 rad² variance).

### 2.3 Control Input Vector

The control input consists of linear and angular velocities:

\[
\mathbf{u} = \begin{bmatrix} v \\ \omega \end{bmatrix}
\]

Where:
- $v$: Linear velocity (m/s)
- $\omega$: Angular velocity (rad/s)

### 2.4 Control Input Calculation

From trajectory, angular velocity is computed as:
\[
\omega = \frac{\Delta \theta}{\Delta t} = \frac{\theta_{k+1} - \theta_k}{\Delta t}
\]

With $\Delta t = Dt / V$ (time between intermediate points at velocity V).

### 2.5 Process Noise Covariance Matrix

The process noise models uncertainty in the motion model:

\[
\mathbf{Q} = \begin{bmatrix}
Vn^2 & 0 \\
0 & Wn^2
\end{bmatrix}
\]

Default values:
- $Vn = 0.1$ m/s (linear velocity noise sigma)
- $Wn = 0.1$ rad/s (angular velocity noise sigma)

\[
\mathbf{Q} = \begin{bmatrix}
0.01 & 0 \\
0 & 0.01
\end{bmatrix}
\]

### 2.6 Observation Noise Covariance Matrix

The observation noise depends on the number of visible beacons. For k visible beacons:

\[
\mathbf{R} = \begin{bmatrix}
\sigma_{d1}^2 & 0 & \cdots & 0 \\
0 & \sigma_{a1}^2 & \cdots & 0 \\
\vdots & \vdots & \ddots & \vdots \\
0 & 0 & \cdots & \sigma_{ak}^2
\end{bmatrix}_{(2k \times 2k)}
\]

Using noise from BeaconDetection:
- $\sigma_{di} = B.dn$ (distance noise for beacon i)
- $\sigma_{ai} = B.an$ (angle noise for beacon i)

---

## 3. Motion Model

### 3.1 Process Model Function

The motion model predicts the next state based on current state and control inputs:

\[
\mathbf{f}(\mathbf{x}_k, \mathbf{u}_k) = \begin{bmatrix}
x_k + v_k \cdot \cos(\theta_k) \cdot \Delta t \\
y_k + v_k \cdot \sin(\theta_k) \cdot \Delta t \\
\theta_k + \omega_k \cdot \Delta t
\end{bmatrix}
\]

Where $\Delta t$ is the time step between trajectory points.

### 3.2 State Transition Equations

For discretized motion with time step $\Delta t$:

**X-coordinate:**
\[
x_{k+1} = x_k + v_k \cos(\theta_k) \Delta t
\]

**Y-coordinate:**
\[
y_{k+1} = y_k + v_k \sin(\theta_k) \Delta t
\]

**Heading:**
\[
\theta_{k+1} = \theta_k + \omega_k \Delta t
\]

### 3.3 Jacobian $J_{fx}$ (State Jacobian)

The Jacobian of the motion model with respect to state:

\[
\mathbf{F}_x = \frac{\partial \mathbf{f}}{\partial \mathbf{x}} = \begin{bmatrix}
\frac{\partial x_{k+1}}{\partial x} & \frac{\partial x_{k+1}}{\partial y} & \frac{\partial x_{k+1}}{\partial \theta} \\
\frac{\partial y_{k+1}}{\partial x} & \frac{\partial y_{k+1}}{\partial y} & \frac{\partial y_{k+1}}{\partial \theta} \\
\frac{\partial \theta_{k+1}}{\partial x} & \frac{\partial \theta_{k+1}}{\partial y} & \frac{\partial \theta_{k+1}}{\partial \theta}
\end{bmatrix}
\]

Evaluating partial derivatives:

\[
\mathbf{F}_x = \begin{bmatrix}
1 & 0 & -v_k \sin(\theta_k) \Delta t \\
0 & 1 & v_k \cos(\theta_k) \Delta t \\
0 & 0 & 1
\end{bmatrix}
\]

### 3.4 Jacobian $J_{fv}$ (Input Jacobian)

The Jacobian of the motion model with respect to control inputs:

\[
\mathbf{F}_v = \frac{\partial \mathbf{f}}{\partial \mathbf{u}} = \begin{bmatrix}
\frac{\partial x_{k+1}}{\partial v} & \frac{\partial x_{k+1}}{\partial \omega} \\
\frac{\partial y_{k+1}}{\partial v} & \frac{\partial y_{k+1}}{\partial \omega} \\
\frac{\partial \theta_{k+1}}{\partial v} & \frac{\partial \theta_{k+1}}{\partial \omega}
\end{bmatrix}
\]

Evaluating partial derivatives:

\[
\mathbf{F}_v = \begin{bmatrix}
\cos(\theta_k) \Delta t & 0 \\
\sin(\theta_k) \Delta t & 0 \\
0 & \Delta t
\end{bmatrix}
\]

### 3.5 Process Noise Covariance Transformation

The process noise covariance $Q$ is transformed to state space through $F_v$:

\[
\mathbf{Q}_{state} = \mathbf{F}_v \mathbf{Q} \mathbf{F}_v^T
\]

With $Q$ as diagonal:
\[
\mathbf{Q} = \begin{bmatrix} Vn^2 & 0 \\ 0 & Wn^2 \end{bmatrix}
\]

Resulting in:
\[
\mathbf{Q}_{state} = \begin{bmatrix}
Vn^2 \cos^2(\theta) \Delta t^2 & Vn^2 \sin(\theta)\cos(\theta) \Delta t^2 & 0 \\
Vn^2 \sin(\theta)\cos(\theta) \Delta t^2 & Vn^2 \sin^2(\theta) \Delta t^2 & 0 \\
0 & 0 & Wn^2 \Delta t^2
\end{bmatrix}
\]

### 3.6 MATLAB Implementation

```matlab
function [x_next, Fx, Fv] = motionModel(x, v, omega, dt)
%MOTIONMODEL Compute motion model prediction
%   Input: x = [x; y; theta], v = linear velocity, omega = angular velocity
%   Output: x_next = predicted state, Fx = state Jacobian, Fv = input Jacobian

    theta = x(3);
    cos_t = cos(theta);
    sin_t = sin(theta);
    
    % State prediction
    x_next = [x(1) + v * cos_t * dt;
              x(2) + v * sin_t * dt;
              x(3) + omega * dt];
    
    % State Jacobian Fx
    Fx = [1, 0, -v * sin_t * dt;
          0, 1,  v * cos_t * dt;
          0, 0,  1];
    
    % Input Jacobian Fv
    Fv = [cos_t * dt, 0;
          sin_t * dt, 0;
          0, dt];
end
```

---

## 4. Observation Model

### 4.1 Observation Function

The observation model predicts what the robot would observe from each beacon:

For beacon $i$ at position $(xb_i, yb_i)$, the predicted observation is:

\[
\mathbf{h}_i(\mathbf{x}) = \begin{bmatrix}
d_i \\ \alpha_i
\end{bmatrix}
\]

Where:

**Predicted Distance:**
\[
d_i = \sqrt{(xb_i - x)^2 + (yb_i - y)^2}
\]

**Predicted Angle (bearing):**
\[
\alpha_i = \text{atan2}(yb_i - y, xb_i - x) - \theta
\]

### 4.2 Full Observation Vector

For $k$ visible beacons (non-NaN detections), the observation vector is:

\[
\mathbf{z} = \begin{bmatrix}
d_1 \\ \alpha_1 \\ d_2 \\ \alpha_2 \\ \vdots \\ d_k \\ \alpha_k
\end{bmatrix}_{(2k \times 1)}
\]

### 4.3 Jacobian $J_{hx}$ (Observation Jacobian)

The Jacobian of observation model with respect to state for beacon $i$:

\[
\mathbf{H}_i = \frac{\partial \mathbf{h}_i}{\partial \mathbf{x}} = \begin{bmatrix}
\frac{\partial d_i}{\partial x} & \frac{\partial d_i}{\partial y} & \frac{\partial d_i}{\partial \theta} \\
\frac{\partial \alpha_i}{\partial x} & \frac{\partial \alpha_i}{\partial y} & \frac{\partial \alpha_i}{\partial \theta}
\end{bmatrix}
\]

Let:
\[
\Delta x_i = xb_i - x, \quad \Delta y_i = yb_i - y, \quad r_i = \sqrt{\Delta x_i^2 + \Delta y_i^2}
\]

Then the partial derivatives are:

**For distance:**
\[
\frac{\partial d_i}{\partial x} = -\frac{\Delta x_i}{r_i}, \quad 
\frac{\partial d_i}{\partial y} = -\frac{\Delta y_i}{r_i}, \quad
\frac{\partial d_i}{\partial \theta} = 0
\]

**For angle:**
\[
\frac{\partial \alpha_i}{\partial x} = \frac{\Delta y_i}{r_i^2}, \quad
\frac{\partial \alpha_i}{\partial y} = -\frac{\Delta x_i}{r_i^2}, \quad
\frac{\partial \alpha_i}{\partial \theta} = -1
\]

So the Jacobian for beacon $i$ is:
\[
\mathbf{H}_i = \begin{bmatrix}
-\frac{\Delta x_i}{r_i} & -\frac{\Delta y_i}{r_i} & 0 \\
\frac{\Delta y_i}{r_i^2} & -\frac{\Delta x_i}{r_i^2} & -1
\end{bmatrix}
\]

### 4.4 Combined Jacobian

For $k$ visible beacons:
\[
\mathbf{H} = \begin{bmatrix}
\mathbf{H}_1 \\ \mathbf{H}_2 \\ \vdots \\ \mathbf{H}_k
\end{bmatrix}_{(2k \times 3)}
```

### 4.5 MATLAB Implementation

```matlab
function [z, H, valid_idx] = observationModel(x, beacons, beacon_data)
%OBSERVATIONMODEL Compute predicted beacon observations
%   Input: x = [x; y; theta], beacons = Nx2 beacon positions
%   Output: z = observation vector, H = Jacobian, valid_idx = valid beacon indices

    N = size(beacons, 1);
    z = [];
    H = [];
    valid_idx = [];
    
    for i = 1:N
        % Check if beacon measurement is valid (not NaN)
        if ~isnan(beacon_data(i).distance)
            dx = beacons(i,1) - x(1);
            dy = beacons(i,2) - x(2);
            r = sqrt(dx^2 + dy^2);
            
            % Predicted observation
            d = r;
            alpha = atan2(dy, dx) - x(3);
            z = [z; d; alpha];
            
            % Jacobian for this beacon
            Hi = [-dx/r, -dy/r, 0;
                   dy/r^2, -dx/r^2, -1];
            H = [H; Hi];
            
            valid_idx = [valid_idx; i];
        end
    end
end
```

---

## 5. EKF Algorithm

The Extended Kalman Filter combines prediction and update steps to estimate the robot state.

### 5.1 Algorithm Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      EKF Algorithm                              │
├─────────────────────────────────────────────────────────────────┤
│ 1. INITIALIZE                                                    │
│    x̂₀ = [0, 0, 0]ᵀ                                              │
│    P₀ = diag([0.01, 0.01, 0.1])                                 │
│                                                                  │
│ 2. FOR each time step k = 0, 1, 2, ...                           │
│                                                                  │
│    PREDICTION:                                                  │
│    ───────────                                                  │
│    x̄ₖ = f(x̂ₖ₋₁, uₖ₋₁)                                          │
│    P̄ₖ = Fₓₖ₋₁ Pₖ₋₁ Fₓₖ₋₁ᵀ + Fᵥ Q Fᵥᵀ                         │
│                                                                  │
│    OBSERVATION:                                                  │
│    ───────────                                                  │
│    zₖ = getBeaconObservations()  % May contain NaN              │
│                                                                  │
│    if any valid measurements:                                   │
│                                                                  │
│        COMPUTE innovation:                                      │
│        v = zₖ - h(x̄ₖ)           % Exclude NaN from calculation  │
│                                                                  │
│        COMPUTE Kalman gain:                                      │
│        S = H P̄ₖ Hᵀ + R                                           │
│        K = P̄ₖ Hᵀ S⁻¹                                            │
│                                                                  │
│        UPDATE state:                                            │
│        x̂ₖ = x̄ₖ + K v                                           │
│                                                                  │
│        UPDATE covariance:                                        │
│        Pₖ = (I - K H) P̄ₖ                                        │
│    else:                                                         │
│        % Only prediction (no update)                              │
│        x̂ₖ = x̄ₖ                                                  │
│        Pₖ = P̄ₖ                                                  │
│    end                                                           │
│ end                                                              │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Prediction Step Equations

**State Prediction:**
\[
\overline{\mathbf{x}}_k = \mathbf{f}(\hat{\mathbf{x}}_{k-1}, \mathbf{u}_{k-1})
\]

**Covariance Prediction:**
\[
\overline{\mathbf{P}}_k = \mathbf{F}_x \hat{\mathbf{P}}_{k-1} \mathbf{F}_x^T + \mathbf{F}_v \mathbf{Q} \mathbf{F}_v^T
```

### 5.3 Update Step Equations

**Innovation (measurement residual):**
\[
\mathbf{y}_k = \mathbf{z}_k - \mathbf{h}(\overline{\mathbf{x}}_k)
\]

**Innovation Covariance:**
\[
\mathbf{S}_k = \mathbf{H}_k \overline{\mathbf{P}}_k \mathbf{H}_k^T + \mathbf{R}_k
\]

**Kalman Gain:**
\[
\mathbf{K}_k = \overline{\mathbf{P}}_k \mathbf{H}_k^T \mathbf{S}_k^{-1}
```

**State Update:**
\[
\hat{\mathbf{x}}_k = \overline{\mathbf{x}}_k + \mathbf{K}_k \mathbf{y}_k
\]

**Covariance Update (Joseph form for numerical stability):**
\[
\hat{\mathbf{P}}_k = (\mathbf{I} - \mathbf{K}_k \mathbf{H}_k) \overline{\mathbf{P}}_k
```

### 5.4 Handling NaN Measurements

When beacon detections return NaN (beacon not visible):

1. **Detection Phase:** Identify valid (non-NaN) beacons
2. **Build reduced observation vector:** Only include valid measurements
3. **Build corresponding Jacobian:** Only for valid beacons
4. **Compute reduced R matrix:** Only for valid beacons

```matlab
function [x_est, P_est] = ekfUpdate(x_bar, P_bar, z_meas, beacons, R)
%EKFUPDATE Extended Kalman Filter update step
%   Handles NaN measurements by filtering them out

    % Find valid (non-NaN) measurements
    valid_mask = ~isnan(z_meas(:,1));  % distance not NaN
    
    if sum(valid_mask) == 0
        % No valid measurements - skip update
        x_est = x_bar;
        P_est = P_bar;
        return;
    end
    
    % Get predicted observations
    [z_pred, H] = observationModel(x_bar, beacons);
    
    % Filter to only valid beacons
    z_pred_valid = z_pred(valid_mask);
    H_valid = H(valid_mask, :);
    
    % Build R matrix for valid beacons only
    k = sum(valid_mask);
    R_valid = zeros(2*k, 2*k);
    for i = 1:k
        R_valid(2*i-1, 2*i-1) = R(1);  % distance variance
        R_valid(2*i, 2*i) = R(2);      % angle variance
    end
    
    % Innovation
    y = z_meas(valid_mask) - z_pred_valid;
    
    % Innovation covariance
    S = H_valid * P_bar * H_valid' + R_valid;
    
    % Kalman gain
    K = P_bar * H_valid' / S;
    
    % State update
    x_est = x_bar + K * y;
    
    % Covariance update (Joseph form)
    I = eye(3);
    P_est = (I - K * H_valid) * P_bar;
end
```

### 5.5 EKF Main Loop

```matlab
function [X_est, P_hist] = ekfLocalize(trajectory, beacons, beacon_data, Q, P0)
%EKFLOCALIZE Main EKF localization loop
%   Input: trajectory = [xp, yp, thetap], beacons = beacon positions
%   Output: X_est = state estimates, P_hist = covariance history

    % Initialize
    x_hat = [0; 0; 0];  % Initial state
    P = P0;             % Initial covariance
    
    n_points = size(trajectory, 1);
    X_est = zeros(n_points, 3);
    P_hist = zeros(n_points, 3, 3);
    
    for k = 1:n_points
        % Get control input from trajectory
        if k == 1
            v = 0; omega = 0;
        else
            dx = trajectory(k,1) - trajectory(k-1,1);
            dy = trajectory(k,2) - trajectory(k-1,2);
            d = sqrt(dx^2 + dy^2);
            v = 5;  % Fixed linear velocity
            dt = d / v;
            dtheta = trajectory(k,3) - trajectory(k-1,3);
            omega = dtheta / dt;
        end
        
        % Prediction step
        dt = 1.0;  % Fixed time step
        [x_bar, Fx, Fv] = motionModel(x_hat, v, omega, dt);
        Q_state = Fv * Q * Fv';
        P_bar = Fx * P * Fx' + Q_state;
        
        % Get beacon measurements at this position
        z = [beacon_data.distance, beacon_data.angle];
        
        % Update step
        if any(~isnan(z))
            [x_hat, P] = ekfUpdate(x_bar, P_bar, z', beacons, [B.dn^2, B.an^2]);
        else
            x_hat = x_bar;
            P = P_bar;
        end
        
        % Store results
        X_est(k,:) = x_hat';
        P_hist(k,:,:) = P;
    end
end
```

---

## 6. Trajectory Planning

### 6.1 Overview

The trajectory planner generates a smooth path from the origin (0,0,0) extending through the environment as an independent trajectory (straight line). The trajectory is computed using Piecewise Cubic Hermite Interpolating Polynomial (pchip).

> **IMPORTANT**: Beacons are FIXED LANDMARKS (reference points) in the environment. The robot trajectory is an INDEPENDENT path (straight line for simplicity) that passes through/extends beyond the beacon area. The robot MEASURES distance/bearing TO beacons during navigation for EKF localization - it does NOT navigate TO/beacons.

### 6.2 Waypoint Construction

Construct trajectory waypoints INDEPENDENTLY from beacon positions:

\[
\mathbf{X}_{wp} = \begin{bmatrix} 0 & x_{end} \\ 0 & y_{end} \end{bmatrix}
\]

Where $(x_{end}, y_{end})$ defines the trajectory endpoint extending beyond the beacon area.

For simplicity, use a straight-line trajectory:
- Start: (0, 0)
- End: (50, 0) extends along x-axis beyond beacon area

### 6.3 pchip() Interpolation

MATLAB's `pchip()` creates a smooth interpolation that passes through all trajectory waypoints:

```matlab
% Create pchip interpolant for trajectory (NOT passing through beacons)
x_waypoints = [0, 50];  % Independent trajectory
y_waypoints = [0, 0];
pp = pchip(x_waypoints, y_waypoints);
```

**IMPORTANT**: The trajectory waypoints are INDEPENDENT of beacon positions. Beacons are used for EKF observation (measuring distance/bearing), not as navigation waypoints.

Parameters:
- `x_waypoints`: Vector of x-coordinates defining trajectory path (e.g., [0, 50])
- `y_waypoints`: Vector of y-coordinates defining trajectory path (e.g., [0, 0])

### 6.4 Intermediate Point Calculation

Calculate distance between consecutive waypoints:

\[
\Delta d = Dt \times V
\]

Where:
- $Dt$: Sensor sampling time interval (default: 1 s)
- $V$: Desired average linear velocity (default: 5 m/s)

Example: If Dt = 1s and V = 5 m/s, then $\Delta d = 5$ m between intermediate points.

**Number of intermediate points along trajectory:**
\[
n = \left\lfloor \frac{d_{trajectory}}{\Delta d} \right\rfloor
\]

Where $d_{trajectory}$ is the Euclidean distance between trajectory waypoints (start to end).

### 6.5 Heading Calculation

Compute heading angle between consecutive trajectory points:

\[
\theta_k = \text{atan2}(y_{k+1} - y_k, x_{k+1} - x_k)
\]

This ensures the robot orientation follows the trajectory direction.

### 6.6 MATLAB Implementation

```matlab
function [xp, yp, theta_p] = planTrajectory(beacons, Dt, V)
%PLANTRAJECTORY Generate smooth independent trajectory (NOT through beacons)
%   Input: beacons = Nx2 beacon positions (for reference only), Dt = time step, V = velocity
%   Output: xp, yp, theta_p = trajectory points
%
%   IMPORTANT: Waypoints are INDEPENDENT of beacon positions.
%   The trajectory is a path that extends through the beacon area.

    % Define trajectory waypoints INDEPENDENTLY from beacons
    % Example: straight line extending from origin beyond beacon area
    x_wp = [0, 50];  % Start at origin, extend to x=50
    y_wp = [0, 0];   % Stay on x-axis
    
    % Create pchip interpolant
    pp = pchip(x_wp, y_wp);
    
    % Generate intermediate points
    xp = []; yp = []; theta_p = [];
    delta_d = Dt * V;
    
    for i = 1:(length(x_wp)-1)
        % Distance between consecutive waypoints
        dx = x_wp(i+1) - x_wp(i);
        dy = y_wp(i+1) - y_wp(i);
        d = sqrt(dx^2 + dy^2);
        
        % Number of intermediate points
        n = floor(d / delta_d);
        
        for j = 0:n
            t = j / max(n, 1);  % Parameter 0 to 1
            
            % Interpolated position
            x_interp = ppval(pp, x_wp(i) + t * (x_wp(i+1) - x_wp(i)));
            xp = [xp, x_interp(1)];
            yp = [yp, x_interp(2)];
            
            % Heading (for first point, use next segment)
            if j == 0 && i > 1
                dx_next = xp(end) - xp(end-1);
                dy_next = yp(end) - yp(end-1);
            else
                dx_next = x_wp(i+1) - x_wp(i);
                dy_next = y_wp(i+1) - y_wp(i);
            end
            theta_p = [theta_p, atan2(dy_next, dx_next)];
        end
    end
end
```

---

## 7. Kinematic Model Calculations

This section provides the wheel velocity calculations for three different robot kinematic configurations.

### 7.1 Differential Drive

The differential drive robot has two independent wheels on a common axle.

**Parameters:**
- $r$: Wheel radius (default: 0.15 m)
- $L$: Wheel separation (axle length) (default: 1 m)

**Kinematic Equations:**

From linear velocity $v$ and angular velocity $\omega$:

\[
\omega_R = \frac{v}{r} + \frac{\omega \cdot L}{2r}
\]

\[
\omega_L = \frac{v}{r} - \frac{\omega \cdot L}{2r}
\]

Where:
- $\omega_R$: Right wheel angular velocity (rad/s)
- $\omega_L$: Left wheel angular velocity (rad/s)

**Inverse Relationship:**

Given wheel velocities, compute robot motion:
\[
v = r \cdot \frac{\omega_R + \omega_L}{2}
\]
\[
\omega = r \cdot \frac{\omega_R - \omega_L}{L}
```

**MATLAB Implementation:**

```matlab
function [omega_R, omega_L] = differentialDrive(v, omega, r, L)
%DIFFERENTIALDRIVE Compute wheel velocities for differential drive
%   Input: v = linear velocity, omega = angular velocity
%   Output: omega_R, omega_L = wheel angular velocities

    omega_R = (v / r) + (omega * L / (2 * r));
    omega_L = (v / r) - (omega * L / (2 * r));
end
```

### 7.2 Tricycle Drive

The tricycle robot has one front steering wheel and two rear traction wheels.

**Parameters:**
- $r$: Wheel radius (default: 0.15 m)
- $L$: Wheelbase (distance from front to rear axle) (default: 1 m)

**Kinematic Equations:**

**Rear wheel (traction) velocity:**
\[
\omega_T = \frac{v}{r}
\]

The rear wheel velocity equals the linear velocity divided by the wheel radius.

**Front wheel steering angle:**
\[
\alpha = \arctan\left(\frac{\omega \cdot L}{v}\right)
\]

Where:
- $\omega_T$: Rear wheel angular velocity (rad/s)
- $\alpha$: Front wheel steering angle (radians)
- $\omega$: Angular velocity from EKF
- $v$: Linear velocity

**MATLAB Implementation:**

```matlab
function [omega_T, alpha] = tricycleDrive(v, omega, r, L)
%TRICYCLEDRIVE Compute tricycle wheel parameters
%   Input: v = linear velocity, omega = angular velocity
%   Output: omega_T = rear wheel velocity, alpha = steering angle

    omega_T = v / r;
    if v ~= 0
        alpha = atan(omega * L / v);
    else
        alpha = 0;
    end
end
```

### 7.3 Omnidirectional Drive

The omnidirectional robot has three wheels positioned at 120° intervals.

**Wheel Configuration:**
- Wheel 1: 0° (aligned with x-axis)
- Wheel 2: 120°
- Wheel 3: 240°

**Kinematic Equations:**

For three omni wheels at angles $\phi_1 = 0$, $\phi_2 = 2\pi/3$, $\phi_3 = 4\pi/3$:

\[
\omega_1 = \frac{v \cos(\phi_1) + v \sin(\phi_1) + \omega \cdot R}{r}
\]
\[
\omega_2 = \frac{v \cos(\phi_2) + v \sin(\phi_2) + \omega \cdot R}{r}
\]
\[
\omega_3 = \frac{v \cos(\phi_3) + v \sin(\phi_3) + \omega \cdot R}{r}
\]

Where:
- $R$: Effective radius from center to wheel contact point (depends on configuration)

Simplified for 120° spacing with $R = L/\sqrt{3}$:

\[
\begin{bmatrix}
\omega_1 \\ \omega_2 \\ \omega_3
\end{bmatrix}
= \frac{1}{r}
\begin{bmatrix}
\cos(0) & \sin(0) & L/\sqrt{3} \\
\cos(2\pi/3) & \sin(2\pi/3) & L/\sqrt{3} \\
\cos(4\pi/3) & \sin(4\pi/3) & L/\sqrt{3}
\end{bmatrix}
\begin{bmatrix}
v_x \\ v_y \\ \omega
\end{bmatrix}
```

**MATLAB Implementation:**

```matlab
function [omega1, omega2, omega3] = omniDrive(v, omega, r, L)
%OMNIDRIVE Compute wheel velocities for omnidirectional robot
%   Input: v = linear velocity, omega = angular velocity
%   Output: omega1, omega2, omega3 = wheel angular velocities

    % Effective radius
    R = L / sqrt(3);
    
    % Wheel angles
    phi = [0, 2*pi/3, 4*pi/3];
    
    % Robot oriented in direction of motion
    theta = atan2(v*sin(0), v*cos(0));  % Direction of travel
    
    for i = 1:3
        wheels(i) = (v * cos(phi(i)-theta) + omega * R) / r;
    end
    
    omega1 = wheels(1);
    omega2 = wheels(2);
    omega3 = wheels(3);
end
```

### 7.4 Kinematic Conversion Summary

| Model | Outputs | Parameters |
|-------|---------|-------------|
| Differential Drive | $\omega_R$, $\omega_L$ | $r$, $L$ |
| Tricycle | $\omega_T$, $\alpha$ | $r$, $L$ |
| Omnidirectional | $\omega_1$, $\omega_2$, $\omega_3$ | $r$, $L$ |

---

## 8. Function Interface

### 8.1 Main Function Signature

```matlab
function [loc_file, dd_file, tri_file, omni_file] = rm1_nnnnnn(N, Dt, r, L, Vn, Wn, V)
%RM1_NNNNNN Robot probabilistic localization using EKF with redundant beacons
%
% Input parameters:
%   N   - Number of beacons (default: 4)
%   Dt  - Sensor sampling time interval in seconds (default: 1)
%   r   - Wheel radius in meters (default: 0.15)
%   L   - Wheel separation in meters (default: 1)
%   Vn  - Linear velocity uncertainty sigma (default: 0.1 m/s)
%   Wn  - Angular velocity uncertainty sigma (default: 0.1 rad/s)
%   V   - Desired average linear velocity (default: 5 m/s)
%
% Output:
%   loc_file    - Location of pose estimate file
%   dd_file    - Location of differential drive output file
%   tri_file   - Location of tricycle output file
%   omni_file  - Location of omnidirectional output file
```

Replace `nnnnnn` with student ID number.

### 8.2 Input Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| N | integer | 4 | Number of beacons |
| Dt | scalar | 1 | Sampling time interval (s) |
| r | scalar | 0.15 | Wheel radius (m) |
| L | scalar | 1 | Wheel separation (m) |
| Vn | scalar | 0.1 | Linear velocity noise (m/s) |
| Wn | scalar | 0.1 | Angular velocity noise (rad/s) |
| V | scalar | 5 | Average velocity (m/s) |

### 8.3 Output Files

The function creates four output files in the current directory:

| File | Format | Description |
|------|--------|-------------|
| `loc_nnnnnn.txt` | `x,y,theta` | Pose estimates (N×3) |
| `DD_nnnnnn.txt` | `omega_R,omega_L` | Differential drive (N×2) |
| `TRI_nnnnnn.txt` | `omega_T,alpha` | Tricycle (N×2) |
| `OMNI_nnnnnn.txt` | `omega1,omega2,omega3` | Omnidirectional (N×3) |

### 8.4 Sample Usage

```matlab
% Basic call with defaults
rm1_nnnnnn();

% Call with custom parameters
rm1_nnnnnn(6, 0.5, 0.1, 0.8, 0.05, 0.05, 3);

% Get output filenames for analysis
[loc, dd, tri, omni] = rm1_nnnnnn(4, 1, 0.15, 1, 0.1, 0.1, 5);
```

### 8.5 Helper Functions

The implementation should include these helper functions:

```matlab
function [x_next, Fx, Fv] = motionModel(x, v, omega, dt)
function [z, H, valid_idx] = observationModel(x, beacons, beacon_data)
function [x_est, P_est] = ekfUpdate(x_bar, P_bar, z_meas, beacons, R)
function [xp, yp, theta_p] = planTrajectory(beacons, Dt, V)
function [omega_R, omega_L] = differentialDrive(v, omega, r, L)
function [omega_T, alpha] = tricycleDrive(v, omega, r, L)
function [omega1, omega2, omega3] = omniDrive(v, omega, r, L)
```

---

## 9. Implementation Notes

### 9.1 Matrix Operations

1. **Jacobians**: Always compute at current state estimate
2. **Matrix Inversions**: Use `\` operator or `inv()` for small matrices
3. **Covariance Updates**: Use Joseph form $(I-KH)P(I-KH)^T$ for numerical stability

### 9.2 Error Handling

- **NaN in Measurements**: Skip update step when all beacons return NaN
- **Single Beacon**: Use partial observation update (reduced H and R)
- **Division by Zero**: Check for zero distances before computing angles
- **Negative Velocities**: Ensure non-negative wheel velocities

### 9.3 Peter Corke Robotics Toolbox Functions

The following RTB functions may be useful:

| Function | Purpose |
|----------|---------|
| `Bicycle` | Bicycle kinematic model for reference |
| `angvec2r` | Angle-axis to rotation matrix |
| `tr2eul` | Transform to Euler angles |
| `eul2tr` | Euler angles to transform |
| `se2` | SE(2) homogeneous transform |

### 9.4 Testing Checklist

- [ ] Trajectory starts at (0, 0, 0)
- [ ] Trajectory is independent path (straight line) extending beyond beacon area
- [ ] EKF uses beacons for MEASUREMENT (distance/bearing) during localization
- [ ] EKF produces stable estimates
- [ ] NaN handling works correctly
- [ ] All output files created
- [ ] File formats correct

### 9.5 Performance Considerations

- Preallocate arrays for trajectory and estimates
- Compute Jacobians only when needed
- Use sparse matrices where applicable
- Cache constant values (beacon positions, R matrix)

---

## Appendix A: Mathematical Reference

### State Vector
\[
\mathbf{x} = \begin{bmatrix} x \\ y \\ \theta \end{bmatrix}
\]

### Motion Model
\[
\mathbf{f}(\mathbf{x}, \mathbf{u}) = \begin{bmatrix}
x + v\cos\theta \cdot dt \\
y + v\sin\theta \cdot dt \\
\theta + \omega \cdot dt
\end{bmatrix}
\]

### Observation Model
\[
\mathbf{h}_i(\mathbf{x}) = \begin{bmatrix}
\sqrt{(xb_i-x)^2 + (yb_i-y)^2} \\
\text{atan2}(yb_i-y, xb_i-x) - \theta
\end{bmatrix}
\]

### EKF Equations
- Prediction: $\bar{\mathbf{x}}_k = \mathbf{f}(\hat{\mathbf{x}}_{k-1}, \mathbf{u}_{k-1})$
- Prediction covariance: $\bar{\mathbf{P}}_k = \mathbf{F}_x \hat{\mathbf{P}}_{k-1} \mathbf{F}_x^T + \mathbf{F}_v \mathbf{Q} \mathbf{F}_v^T$
- Kalman gain: $\mathbf{K}_k = \bar{\mathbf{P}}_k \mathbf{H}^T (\mathbf{H} \bar{\mathbf{P}}_k \mathbf{H}^T + \mathbf{R})^{-1}$
- Update: $\hat{\mathbf{x}}_k = \bar{\mathbf{x}}_k + \mathbf{K}_k (\mathbf{z}_k - \mathbf{h}(\bar{\mathbf{x}}_k))$
- Update covariance: $\hat{\mathbf{P}}_k = (\mathbf{I} - \mathbf{K}_k \mathbf{H}) \bar{\mathbf{P}}_k$

---

*Document Version: 1.0*
*Last Updated: 2026-04-19*