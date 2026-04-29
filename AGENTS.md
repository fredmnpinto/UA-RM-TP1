# Agent Guide - Peter Corke Robotics Toolbox

## Student Information

- **Student number**: 129466
- **Main function file**: rm1_129466.m
- **Output file naming convention**:
  - `loc_129466.txt` - Localization results
  - `DD_129466.txt` - Dead reckoning results
  - `TRI_129466.txt` - Triangulation results
  - `OMNI_129466.txt` - Omnidirectional robot results

## Project Files

### Main Function
- `rm1_129466.m` - Main entry point with parameters (N, Dt, r, L, Vn, Wn, V)

### Trajectory Planning
- `planTrajectory.m` - Generates random multi-waypoint trajectory (independent of beacons)
- Uses linear interpolation with Delta_d = Dt * V * 0.5 for smooth animation

### Beacon Simulation
- `BeaconDetection.m` - Mock function generating random beacon positions (2-25m, first quadrant)
- `BeaconVisualization.m` - Class handling beacon detection lines and distance labels

### Visualization
- `DrawRobot.m` - Draws robot shape (types: 1=DD, 2=tricycle, 3=omni)
- `BeaconVisualization` class - Manages detection lines (red dashed) and distance labels

## Documentation Location

**IMPORTANT**: The Peter Corke Robotics Toolbox documentation is located locally in:
- **File**: `peter_corke_toolbox.md` (in project root)
- **Size**: ~400KB (large file)

This file contains the complete reference documentation converted from the original PDF.

## MATLAB Documentation
When verifying MATLAB functions, also consult:
- **MATLAB Online**: https://www.mathworks.com/help/matlab/index.html
- Use this for standard MATLAB functions (plot, pchip, atan2, etc.)

## How to Look Up Functions

### Method 1: Use the codesearch Tool (RECOMMENDED)
The most efficient way to find function definitions is to use the `codesearch` tool:
```
Search query: "FunctionName" or "function description"
```
This searches the local documentation and returns relevant code examples and usage.

### Method 2: Use grep for Headers
If you know the function name, search for its header:
```
Pattern: ^## FunctionName
```
Example: `^## Bicycle` finds the Bicycle class documentation at line ~1915.

### Method 3: Direct Read with Line Numbers
After finding the line number, read directly:
```
Read: peter_corke_toolbox.md from line X (reading ~100 lines)
```

## Key Functions for This Assignment

### Mobile Robot Kinematics
| Function | Line | Description |
|----------|------|-------------|
| Bicycle | 1915 | Bicycle/unicycle kinematic model |
| Bicycle.f | 1972 | Forward motion model |
| Bicycle.deriv | 1960 | Derivative for EKF |
| Bicycle.Fx | 1997 | Jacobian wrt state |
| Bicycle.Fv | 1985 | Jacobian wrt noise |

### Transformations & Rotations
| Function | Line | Description |
|----------|------|-------------|
| angvec2r | 5644 | Angle-axis to rotation matrix |
| eul2tr | 5920 | Euler angles to transform |
| tr2eul | 12248 | Transform to Euler angles |
| Twist | 13096 | Twist class for 2D/3D |
| Twist.se | 13338 | SE(2) element |

### Path Planning (if needed)
| Function | Line | Description |
|----------|------|-------------|
| Astar | 1138 | A* path planning |
| Dstar | 2373 | D* dynamic path planning |
| Bug2 | 2057 | Bug2 path planning |

### Project Functions
| Function | Type | Description |
|----------|------|-------------|
| planTrajectory | Function | Random trajectory with 2-3 waypoints |
| BeaconDetection | Function | Mock beacon generator (random positions) |
| BeaconVisualization | Class | Manages beacon detection visualization |
| DrawRobot | Function | Draws robot shape (provided) |

## Usage Pattern

When you need to use a RTB function:

1. **First**: Use `codesearch` tool with query like "Bicycle kinematic model MATLAB"
2. **Read**: The returned context for usage examples
3. **Implement**: Based on the documented syntax

## Example Lookup

```matlab
% To find Bicycle class usage:
% 1. codesearch("Bicycle class kinematic model")
% 2. Read relevant sections
% 3. Use as documented:
bicycle = Bicycle(V, L);  % max linear velocity, wheelbase
```

## Notes

- The documentation is in Markdown format
- Headers are formatted as `## FunctionName.ClassName` for class methods
- Each function has usage examples in the documentation
- Take notes with a grain of salt - this is converted documentation

## MATLAB Animation Pattern

For animating graphics, use:
```matlab
% Create graphics object
hRobot = scatter(x, y, 100, 'y', 'filled');

% OR for DrawRobot with hgtransform:
hg = hgtransform;
[P, h] = DrawRobot(1, 0.01);
set(h, 'Parent', hg);

% Animate
for i = 1:size(trajectory, 1)
    % Update position
    T = makehgtform('translate', [x, y, 0], 'zrotate', theta);
    hg.Matrix = T;  % NOT 'Transform' - use 'Matrix' property
    
    drawnow limitrate;
    pause(0.1);  % Optional: slow down
end
```

**Important**: hgtransform uses `.Matrix` property, NOT `.Transform`!