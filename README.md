# Mobile Robotics Assignment 1 - EKF Localization

**Student**: 129466  
**Course**: MSc in Mechanical Engineering - Mobile Robotics  
**Assignment**: RM1 - Localization using Extended Kalman Filter

## Overview

This project implements EKF (Extended Kalman Filter) localization for a mobile robot using beacon detection. The robot navigates through a planned trajectory while estimating its pose using distance and angle measurements from fixed beacons in the environment.

## Project Structure

```
├── rm1_129466.m              # Main entry point
├── src/                      # Source directory
│   ├── planTrajectory_AI.m      # Trajectory planning (AI-coded)
│   ├── ekfLocalization.m    # EKF localization loop
│   ├── EKF.m                # EKF class implementation
│   ├── saveLocalizationResults_AI.m # Save results to file (AI-coded)
│   ├── computeKinematics.m    # Compute wheel velocities (NOT renamed per user request)
│   ├── saveKinematicsResults_AI.m # Save wheel velocities to file (AI-coded)
│   ├── BeaconVisualization.m # Beacon detection visualization class
│   └── DrawRobot.m          # Robot shape drawing function
├── BeaconDetection.p         # Provided P-code (beacon simulation)
├── test_computeKinematics_AI.m # Kinematics test script (AI-coded)
├── test_ekf.m               # EKF test script
├── test_trajectory.m        # Trajectory test script
└── AGENTS.md               # AI agent documentation
```

## Main Function

```matlab
trajectory = rm1_129466(N, Dt, r, L, Vn, Wn, V)
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `N` | Number of beacons | 4 |
| `Dt` | Sensor sampling time (s) | 1 |
| `r` | Wheel radius (m) | 0.15 |
| `L` | Wheel separation (m) | 1 |
| `Vn` | Linear velocity uncertainty (m/s) | 0.1 |
| `Wn` | Angular velocity uncertainty (rad/s) | 0.1 |
| `V` | Desired linear velocity (m/s) | 5 |

## Output Files

- `loc_129466.txt` - EKF localization results (x, y, theta)
- `DD_129466.txt` - Differential drive wheel velocities (ωR, ωL)
- `TRI_129466.txt` - Tricycle wheel velocity and steering (ωT, α)
- `OMNI_129466.txt` - Omnidirectional wheel velocities (ω1, ω2, ω3)

## How to Run

```matlab
% Run with default parameters
rm1_129466();

% Run with custom parameters
rm1_129466(4, 1, 0.15, 1, 0.1, 0.1, 5);
```

The visualization shows:
- **Blue line**: Ground truth trajectory
- **Red dashed line**: EKF estimated trajectory
- **Orange circles**: Beacon positions
- **Robot shape**: Current position and orientation
- **Error plot**: Position error over time

## Key Components

### Trajectory Planning (`src/planTrajectory_AI.m`)
Generates trajectory starting at (0,0) passing through all beacons. Uses Hermite cubic interpolation (pchip) as required by assignment section 2.3. Control points evenly spaced in x, y values from pchip.

### EKF Localization (`src/EKF.m`, `src/ekfLocalization.m`)
Implements Extended Kalman Filter with:
- **Prediction step**: Propagates state using velocity commands
- **Update step**: Corrects state using beacon measurements
- **Uses estimated poses** (not ground truth) for control input

State flow: `initial_estimate → predict() → prediction → update() → corrected_prediction`

### Beacon Detection (`BeaconDetection.p`)
Provided P-code function that simulates beacon measurements:
- Returns beacon positions (`B.X`, `B.Y`)
- Returns measurements (`B.d`, `B.a`) with noise (`B.dn`, `B.an`)
- Returns `NaN` when beacon is out of range or detection fails

## Dependencies

- **MATLAB** (tested on R2023b or later)
- **Peter Corke Robotics Toolbox** - Documentation in `peter_corke_toolbox.md`

## Assignment Requirements

This implementation addresses:
- ✅ Trajectory planning with beacon-aware waypoints
- ✅ EKF localization with beacon measurements
- ✅ Proper handling of NaN measurements (beacon out of range)
- ✅ Visualization with ground truth comparison
- ✅ Hermite interpolation for smooth trajectories (Phase 1)
- ✅ Multi-beacon support (N > 3)

## Notes

- Beacons are fixed landmarks; the robot navigates past them, not to them
- The EKF uses the professor's `BeaconDetection.p` as-is (no modifications)
- Trajectory starts at a random point in the first quadrant (within 5×scale meters of origin)
- Position error is displayed in real-time during animation

## Output Files

- `loc_129466.txt` - EKF localization results (x, y, theta)
- `DD_129466.txt` - Differential drive wheel velocities (ωR, ωL)
- `TRI_129466.txt` - Tricycle wheel velocity and steering (ωT, α)
- `OMNI_129466.txt` - Omnidirectional wheel velocities (ω1, ω2, ω3)

