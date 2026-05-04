# Mobile Robotics Assignment 1 - EKF Localization

**Student**: 129466  
**Course**: MSc in Mechanical Engineering - Mobile Robotics  
**Assignment**: RM1 - Localization using Extended Kalman Filter

## Overview

This project implements EKF (Extended Kalman Filter) localization for a mobile robot using beacon detection. The robot navigates through a planned trajectory while estimating its pose using distance and angle measurements from fixed beacons in the environment.

## Project Structure

```
├── rm1_129466.m              # Main entry point
├── planTrajectory.m          # Trajectory planning (waypoint generation)
├── ekfLocalization.m         # EKF localization loop
├── EKF.m                    # EKF class implementation
├── saveLocalizationResults.m # Save results to file
├── BeaconDetection.p         # Provided P-code (beacon simulation)
├── BeaconVisualization.m     # Beacon detection visualization class
├── DrawRobot.m              # Robot shape drawing function
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
- `DD_129466.txt` - Dead reckoning results (future)
- `TRI_129466.txt` - Triangulation results (future)
- `OMNI_129466.txt` - Omnidirectional robot results (future)

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

### Trajectory Planning (`planTrajectory.m`)
Generates a multi-waypoint trajectory with 2-3 random waypoints. Starts at a random point in the first quadrant (within 5×scale meters of origin). Uses linear interpolation with step size `Delta_d = Dt * V * 0.5` for smooth animation.

### EKF Localization (`EKF.m`, `ekfLocalization.m`)
Implements Extended Kalman Filter with:
- **Prediction step**: Propagates state using velocity commands
- **Update step**: Corrects state using beacon measurements

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

## Future Work

- Implement dead reckoning comparison (DD)
- Add triangulation-based localization (TRI)
- Extend to omnidirectional robot model (OMNI)
