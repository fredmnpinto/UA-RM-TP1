% Test script for trajectory and visualization fixes

% Run the main function
fprintf('=== Testing trajectory generation and visualization ===\n\n');

% Generate trajectory with default parameters
trajectory = rm1_129466(4, 1, 0.15, 1, 0.1, 0.1, 5);

fprintf('\n=== Trajectory Results ===\n');
fprintf('Number of points: %d\n', size(trajectory, 1));
fprintf('Start position: [%.2f, %.2f, %.2f]\n', trajectory(1, :));
fprintf('End position: [%.2f, %.2f, %.2f]\n', trajectory(end, :));

% Verify trajectory properties
fprintf('\n=== Verification ===\n');

% Check 1: Starts at origin
if isequal(trajectory(1, :), [0, 0, 0])
    fprintf('PASS: Trajectory starts at origin (0, 0, 0)\n');
else
    fprintf('FAIL: Trajectory does not start at origin\n');
end

% Check 2: Straight-line path (approximately)
distances = sqrt(diff(trajectory(:,1)).^2 + diff(trajectory(:,2)).^2);
fprintf('Distance between consecutive points (min/avg/max): %.2f / %.2f / %.2f m\n', ...
    min(distances), mean(distances), max(distances));

% Check 3: No NaN values
if any(isnan(trajectory(:)))
    fprintf('FAIL: Trajectory contains NaN values\n');
else
    fprintf('PASS: No NaN values in trajectory\n');
end

% Display trajectory points
fprintf('\n=== Sample trajectory points ===\n');
if size(trajectory, 1) <= 20
    disp(trajectory);
else
    fprintf('First 10 points:\n');
    disp(trajectory(1:10, :));
    fprintf('...\n');
    fprintf('Last 10 points:\n');
    disp(trajectory(end-9:end, :));
end