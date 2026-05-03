# Phase 2: EKF Core + Localization - Tasks

## Task List

### T001: EKF Initialization

**Objective**: Initialize the Extended Kalman Filter state vector and covariance matrix with appropriate initial values.

**Function Call**:
```matlab
[x_hat, P] = ekfInitialize(Vn, Wn);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| Vn | scalar | Linear velocity noise sigma (m/s) - for reference in setting initial uncertainty |
| Wn | scalar | Angular velocity noise sigma (rad/s) - for reference in setting initial uncertainty |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| x_hat | 3×1 vector | Initial state estimate [x; y; θ] = [0; 0; 0] |
| P | 3×3 matrix | Initial covariance matrix diag([0.01², 0.01², 0.1²]) |

**Dependencies**: none
**MATLAB Functions**: diag
**Effort Estimate**: [Small]

---

### T002: Control Input Calculation

**Objective**: Calculate linear velocity (v) and angular velocity (ω) from consecutive trajectory points to use as control inputs for the motion model.

**Function Call**:
```matlab
[v, omega, dt_actual] = computeControlInput(x_prev, x_curr, V);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| x_prev | 3×1 vector | Previous pose [x_prev; y_prev; θ_prev] |
| x_curr | 3×1 vector | Current pose [x_curr; y_curr; θ_curr] |
| V | scalar | Desired average linear velocity (m/s) |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| v | scalar | Linear velocity (m/s) - set to V |
| omega | scalar | Angular velocity (rad/s) = Δθ / Δt |
| dt_actual | scalar | Actual time step (seconds) = distance / V |

**Dependencies**: none
**MATLAB Functions**: sqrt, atan2, sin, cos
**Effort Estimate**: [Small]

---

### T003: Motion Model Prediction

**Objective**: Perform the EKF prediction step using the motion model, computing predicted state, predicted covariance, and Jacobians.

**Function Call**:
```matlab
[x_bar, P_bar, J_fx, J_fw] = ekfPredict(x_hat, P, v, omega, dt, Q);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| x_hat | 3×1 vector | Current state estimate [x; y; θ] |
| P | 3×3 matrix | Current covariance matrix |
| v | scalar | Linear velocity (m/s) |
| omega | scalar | Angular velocity (rad/s) |
| dt | scalar | Time step (seconds) |
| Q | 2×2 matrix | Process noise covariance [Vn², 0; 0, Wn²] |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| x_bar | 3×1 vector | Predicted state [x̄; ȳ; θ̄] |
| P_bar | 3×3 matrix | Predicted covariance |
| J_fx | 3×3 matrix | Jacobian of motion model wrt state |
| J_fw | 3×2 matrix | Jacobian of motion model wrt noise |

**Dependencies**: T001 (for initial x_hat, P)
**MATLAB Functions**: cos, sin, matrix multiplication
**Effort Estimate**: [Medium]

**Prediction Equations**:
- State: x̄ = [x + v·cos(θ)·dt; y + v·sin(θ)·dt; θ + ω·dt]
- Covariance: P̄ = J_fx·P·J_fxᵀ + J_fw·Q·J_fwᵀ

---

### T004: Beacon Measurement Simulation

**Objective**: Call the BeaconDetection function to simulate beacon measurements at the predicted robot position, handling the returned distances and angles (which may include NaN values).

**Function Call**:
```matlab
B_meas = BeaconDetection(N, robot_pose);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| N | integer | Number of beacons (default: 4) |
| robot_pose | 1×3 vector | Predicted robot pose [x̄, ȳ, θ̄] |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| B_meas | struct | Structure with fields: .d (N×1 distances), .a (N×1 angles), .dn (distance noise), .an (angle noise), .beacons (N×2 positions) |
| valid_mask | N×1 logical | Mask indicating which beacon measurements are valid (not NaN) |

**Dependencies**: T003 (for predicted state x_bar)
**MATLAB Functions**: isnan
**Effort Estimate**: [Small]

**Note**: BeaconDetection returns NaN for beacons that are out of range (< 0.3m or > 10m) or randomly missed (~5% chance).

---

### T005: Observation Model

**Objective**: For each visible beacon, compute the predicted observation (distance and bearing) and build the observation Jacobian J_h and measurement noise matrix R.

**Function Call**:
```matlab
[z_pred, J_h, valid_indices] = observationModel(x_bar, beacons, B_meas);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| x_bar | 3×1 vector | Predicted state [x̄; ȳ; θ̄] |
| beacons | N×2 matrix | Beacon positions [x_b, y_b] for all N beacons |
| B_meas | struct | BeaconDetection output with measurements |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| z_pred | (2k)×1 vector | Predicted observations [d₁; α₁; d₂; α₂; ...] for k valid beacons |
| J_h | (2k)×3 matrix | Observation Jacobian for valid beacons |
| valid_indices | k×1 vector | Indices of beacons with valid measurements |

**Dependencies**: T004 (for B_meas and valid beacon identification)
**MATLAB Functions**: sqrt, atan2, matrix concatenation
**Effort Estimate**: [Medium]

**Observation Model**:
- Predicted distance: dᵢ = √((x_bᵢ - x)² + (y_bᵢ - y)²)
- Predicted bearing: αᵢ = atan2(y_bᵢ - y, x_bᵢ - x) - θ

**Single Beacon Jacobian (2×3)**:
```
J_hᵢ = [-Δxᵢ/rᵢ, -Δyᵢ/rᵢ, 0;
         Δyᵢ/rᵢ², -Δxᵢ/rᵢ², -1]
```
where Δxᵢ = x_bᵢ - x, Δyᵢ = y_bᵢ - y, rᵢ = √(Δxᵢ² + Δyᵢ²)

---

### T006: EKF Update Step

**Objective**: Perform the EKF update step using valid beacon measurements, computing innovation, Kalman gain, and updating state estimate and covariance.

**Function Call**:
```matlab
[x_hat, P] = ekfUpdate(x_bar, P_bar, B_meas, beacons, R_base);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| x_bar | 3×1 vector | Predicted state from prediction step |
| P_bar | 3×3 matrix | Predicted covariance from prediction step |
| B_meas | struct | BeaconDetection output with measurements |
| beacons | N×2 matrix | Beacon positions |
| R_base | 2×2 matrix | Base measurement noise covariance [dn², 0; 0, an²] |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| x_hat | 3×1 vector | Updated state estimate |
| P | 3×3 matrix | Updated covariance matrix (Joseph form for stability) |

**Dependencies**: T003 (prediction), T004 (measurements), T005 (observation model)
**MATLAB Functions**: eye, svd, matrix operations
**Effort Estimate**: [Medium]

**Update Equations**:
1. Innovation: ν = z_actual - z_pred
2. Innovation covariance: S = J_h·P̄·J_hᵀ + R
3. Kalman gain: K = P̄·J_hᵀ·S⁻¹
4. State update: x̂ = x̄ + K·ν
5. Covariance update (Joseph form): P̂ = (I - K·J_h)·P̄·(I - K·J_h)ᵀ + K·R·Kᵀ

---

### T007: NaN Handling

**Objective**: Implement robust handling of NaN measurements in the EKF update, dynamically resizing Jacobians and noise matrices based on valid beacon count.

**Function Call**:
```matlab
valid_mask = getValidBeaconMask(B_meas, N);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| B_meas | struct | BeaconDetection output |
| N | integer | Number of beacons |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| valid_mask | N×1 logical | True for beacons with valid (non-NaN) measurements |

**Dependencies**: T004, T005, T006 (integrated into update logic)
**MATLAB Functions**: isnan, sum, zeros
**Effort Estimate**: [Medium]

**Handling Logic**:
- If valid_count == 0: Skip update, use prediction only (x̂ = x̄, P̂ = P̄)
- If valid_count > 0: Build reduced J_h (2·valid_count × 3) and R (2·valid_count × 2·valid_count)
- Dynamically append only valid beacon Jacobians to J_h
- Set R diagonal elements for valid beacons only

**Edge Cases**:
| Case | Valid Beacons | Behavior |
|------|---------------|----------|
| All NaN | 0 | Skip update; use prediction only |
| Single beacon | 1 | J_h is 2×3; update proceeds |
| Partial visibility | 1 < k < N | J_h is (2k)×3; use available measurements |
| All visible | N | J_h is (2N)×3; standard EKF update |

---

### T008: Output Generation

**Objective**: Save the estimated trajectory to the output file loc_129466.txt in the required comma-separated format.

**Function Call**:
```matlab
saveLocalizationResults(estimated_trajectory, 'loc_129466.txt');
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| estimated_trajectory | M×3 matrix | EKF estimated poses [x_est, y_est, θ_est] for M timesteps |
| filename | string | Output filename ('loc_129466.txt') |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| (none) | - | File written to disk |

**Dependencies**: T001-T006 (must complete EKF loop first)
**MATLAB Functions**: fopen, fprintf, fclose
**Effort Estimate**: [Small]

**Output Format** (loc_129466.txt):
```
x1, y1, θ1
x2, y2, θ2
x3, y3, θ3
...
xn, yn, θn
```

Each line contains x, y, θ separated by commas, with 6 decimal places.

---

### T009: Main EKF Localization Function

**Objective**: Create the main ekfLocalization function that orchestrates the entire EKF process, calling the prediction, update, and output functions in a loop.

**Function Call**:
```matlab
[estimated_trajectory, P_history] = ekfLocalization(trajectory, N, Dt, Vn, Wn, V);
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| trajectory | M×3 matrix | Ground truth trajectory [x, y, θ] from Phase 1 |
| N | integer | Number of beacons (default: 4) |
| Dt | scalar | Sensor sampling time interval (seconds, default: 1) |
| Vn | scalar | Linear velocity uncertainty sigma (default: 0.1 m/s) |
| Wn | scalar | Angular velocity uncertainty sigma (default: 0.1 rad/s) |
| V | scalar | Desired average linear velocity (default: 5 m/s) |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| estimated_trajectory | M×3 matrix | EKF estimated poses [x_est, y_est, θ_est] |
| P_history | M×3×3 matrix | Covariance history (optional, for analysis) |

**Dependencies**: T001-T008 (all previous tasks)
**MATLAB Functions**: nargin, isempty, size, zeros, fprintf
**Effort Estimate**: [Large]

**Main Loop Structure**:
1. Initialize EKF (T001)
2. Get beacon positions from BeaconDetection
3. For each timestep k = 1:(M-1):
   - Calculate control input (T002)
   - Prediction step (T003)
   - Get beacon measurements (T004)
   - If valid measurements exist: Update step (T006)
   - Else: Use prediction only (T007)
   - Store estimate
4. Save results (T008)

---

### T010: Integration with rm1_129466.m

**Objective**: Modify the main rm1_129466.m function to call the EKF localization after trajectory generation and save the results.

**Function Call**:
```matlab
% In rm1_129466.m main flow:
estimated_trajectory = ekfLocalization(trajectory, N, Dt, Vn, Wn, V);
saveLocalizationResults(estimated_trajectory, 'loc_129466.txt');
```

**Input Parameters**:
| Parameter | Type | Purpose |
|-----------|------|---------|
| trajectory | M×3 matrix | Generated by planTrajectory in Phase 1 |
| N, Dt, Vn, Wn, V | scalars | Parameters passed to ekfLocalization |

**Output Values**:
| Output | Type | Purpose |
|--------|------|---------|
| loc_129466.txt | file | Output file with estimated trajectory |

**Dependencies**: T009 (ekfLocalization must be complete)
**MATLAB Functions**: (modification to existing file)
**Effort Estimate**: [Small]

**Integration Points**:
- After Phase 1 trajectory generation
- Call ekfLocalization with trajectory and parameters
- Save results to loc_129466.txt
- Display summary of results

---

## Dependencies

- T001 (EKF Initialization) must complete before T003, T009
- T002 (Control Input) must complete before T003
- T003 (Prediction) must complete before T006, T009
- T004 (Beacon Measurement) must complete before T005, T006
- T005 (Observation Model) must complete before T006
- T006 (EKF Update) must complete before T009
- T007 (NaN Handling) integrated into T006 and T009
- T008 (Output Generation) must complete before T010
- T009 (Main EKF Function) must complete before T010
- [Parallels] T001 || T002 (can run in parallel as they're independent)
- [Parallels] T004 || T005 (T005 depends on T004 output, but can be developed in parallel)

---

## Effort Estimate Summary

| Task | Description | Effort |
|------|-------------|--------|
| T001 | EKF Initialization | [Small] |
| T002 | Control Input Calculation | [Small] |
| T003 | Motion Model Prediction | [Medium] |
| T004 | Beacon Measurement Simulation | [Small] |
| T005 | Observation Model | [Medium] |
| T006 | EKF Update Step | [Medium] |
| T007 | NaN Handling | [Medium] |
| T008 | Output Generation | [Small] |
| T009 | Main EKF Localization Function | [Large] |
| T010 | Integration with rm1_129466.m | [Small] |

---

## Validation Checklist

After completing all tasks, verify:

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
- [ ] Angles are normalized to [-π, π]
- [ ] Numerical stability: covariance symmetry enforced, SVD used if needed

---

*Task Document Version: 1.0*  
*Last Updated: 2026-04-29*  
*Phase: 2 - EKF Core + Localization*
