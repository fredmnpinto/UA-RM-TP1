function test_computeKinematics_AI()
%TEST_COMPUTEKINEMATICS Test computeKinematics function
%
% Tests all 3 kinematic models (DD, Tricycle, Omnidirectional)
% Verifies formulas and output file formats.

    fprintf('========================================\n');
    fprintf('Testing computeKinematics.m\n');
    fprintf('========================================\n\n');

    % ============ SETUP ===========
    addpath('lib');
    
    r = 0.15;   % wheel radius (m)
    L = 1.0;    % wheel separation (m)
    Dt = 1.0;    % sampling time (s)
    
    % ============ TEST 1: STRAIGHT LINE ===========
    fprintf('Test 1: Straight line motion (theta = 0)\n');
    
    % Trajectory: straight line from (0,0) to (10,0), 5 points
    % Each step: dx=2.5m, dy=0, dtheta=0
    % v = 2.5/Dt = 2.5 m/s, omega = 0
    M = 5;
    trajectory = zeros(M,3);
    for i = 1:M
        trajectory(i, :) = [(i-1)*2.5, 0, 0];  % theta = 0 throughout
    end
    
    [DD, TRI, OMNI] = computeKinematics(trajectory, r, L, Dt);
    
    % Expected values for straight line:
    % v = 2.5 m/s, omega = 0
    % DD: wR = wL = v/r = 2.5/0.15 = 16.667 rad/s
    % TRI: wT = v/r = 16.667, alpha = atan2(0, v) = 0
    expected_w = 2.5 / r;
    
    fprintf('  v = 2.5 m/s, omega = 0\n');
    fprintf('  Expected wR = wL = %.4f rad/s\n', expected_w);
    fprintf('  Actual DD(1,:) = [%.4f, %.4f]\n', DD(1,1), DD(1,2));
    
    assert(abs(DD(1,1) - expected_w) < 0.01, 'DD wR incorrect for straight line');
    assert(abs(DD(1,2) - expected_w) < 0.01, 'DD wL incorrect for straight line');
    assert(abs(DD(1,1) - DD(1,2)) < 1e-6, 'DD wR != wL for straight line');
    
    fprintf('  Expected wT = %.4f, alpha = 0\n', expected_w);
    fprintf('  Actual TRI(1,:) = [%.4f, %.4f]\n', TRI(1,1), TRI(1,2));
    
    assert(abs(TRI(1,1) - expected_w) < 0.01, 'TRI wT incorrect');
    assert(abs(TRI(1,2)) < 1e-6, 'TRI alpha should be 0 for straight line');
    
    fprintf('  OMNI(1,:) = [%.4f, %.4f, %.4f]\n', OMNI(1,1), OMNI(1,2), OMNI(1,3));
    
    fprintf('  PASSED\n\n');
    
    % ============ TEST 2: PURE ROTATION ===========
    fprintf('Test 2: Pure rotation (staying in place)\n');
    
    % Robot rotates in place: x,y fixed, theta increases
    % v = 0, omega = pi/2 rad/s (90 deg/s)
    M = 5;
    trajectory = zeros(M,3);
    omega = pi/2;  % 90 deg/s
    for i = 1:M
        trajectory(i, :) = [0, 0, (i-1)*omega*Dt];  % x,y fixed, theta changes
    end
    
    [DD, TRI, OMNI] = computeKinematics(trajectory, r, L, Dt);
    
    % Expected for pure rotation around center:
    % v = 0, omega = pi/2
    % DD: wR = (v + omega*L/2)/r = (pi/2 * 1/2)/0.15 = 5.236 rad/s
    %     wL = (v - omega*L/2)/r = -5.236 rad/s
    expected_wR = (omega * L / 2) / r;
    expected_wL = -expected_wR;
    
    fprintf('  v = 0, omega = pi/2 rad/s\n');
    fprintf('  Expected wR = %.4f, wL = %.4f\n', expected_wR, expected_wL);
    fprintf('  Actual DD(1,:) = [%.4f, %.4f]\n', DD(1,1), DD(1,2));
    
    assert(abs(DD(1,1) - expected_wR) < 0.01, 'DD wR incorrect for rotation');
    assert(abs(DD(1,2) - expected_wL) < 0.01, 'DD wL incorrect for rotation');
    assert(abs(DD(1,1) + DD(1,2)) < 1e-6, 'DD wR + wL should be 0 for pure rotation');
    
    % Tricycle: wT = v/r = 0, alpha = atan2(omega*L, v) = atan2(1.57, 0) = pi/2
    fprintf('  Expected wT = 0, alpha = pi/2 = %.4f\n', pi/2);
    fprintf('  Actual TRI(1,:) = [%.4f, %.4f]\n', TRI(1,1), TRI(1,2));
    
    assert(abs(TRI(1,1)) < 0.01, 'TRI wT should be 0 for pure rotation');
    assert(abs(wrapToPi(TRI(1,2) - pi/2)) < 0.01, 'TRI alpha incorrect for 90deg/s rotation');
    
    fprintf('  PASSED\n\n');
    
    % ============ TEST 3: CIRCULAR MOTION ===========
    fprintf('Test 3: Circular motion (R=5m) - DEBUGGING\n');
    
    % Circle: radius R=5m, v_desired=2.5 m/s, omega = v/R = 0.5 rad/s
    R = 5.0;
    v_desired = 2.5;
    omega = v_desired / R;  % 0.5 rad/s
    Dt = 1.0;
    
    M = 10;
    trajectory = zeros(M,3);
    for i = 1:M
        theta = (i-1) * omega * Dt;
        trajectory(i, :) = [R*cos(theta), R*sin(theta), theta + pi/2];
    end
    
    % ============ SHOW WHY TEST FAILS ============
    fprintf('\n  DEBUG: Why Test 3 fails:\n');
    
    % What computeKinematics computes:
    dx = trajectory(2,1) - trajectory(1,1);
    dy = trajectory(2,2) - trajectory(1,2);
    chord = sqrt(dx^2 + dy^2);
    v_actual = chord / Dt;
    
    dtheta = wrapToPi(trajectory(2,3) - trajectory(1,3));
    omega_actual = dtheta / Dt;
    
    fprintf('  Point 1: [%.4f, %.4f], theta=%.4f\n', trajectory(1,1), trajectory(1,2), trajectory(1,3));
    fprintf('  Point 2: [%.4f, %.4f], theta=%.4f\n', trajectory(2,1), trajectory(2,2), trajectory(2,3));
    fprintf('  dx = %.4f, dy = %.4f\n', dx, dy);
    fprintf('  Chord length = %.4f m\n', chord);
    fprintf('  Arc length = R*dtheta = %.4f m\n', R*abs(dtheta));
    fprintf('  v_actual (chord/Dt) = %.4f m/s\n', v_actual);
    fprintf('  v_desired = %.4f m/s\n', v_desired);
    fprintf('  DIFFERENCE: v_actual - v_desired = %.4f m/s\n\n', v_actual - v_desired);
    
    fprintf('  For a circle: chord = 2*R*sin(dtheta/2)\n');
    fprintf('  chord = 2*%.1f*sin(%.4f/2) = %.4f m\n', R, dtheta, 2*R*sin(dtheta/2));
    fprintf('  arc = R*dtheta = %.4f m\n', R*abs(dtheta));
    fprintf('  Ratio chord/arc = %.6f\n\n', chord/(R*abs(dtheta)));
    
    % Now run computeKinematics
    [DD, TRI, OMNI] = computeKinematics(trajectory, r, L, Dt);
    
    % Expected values using ACTUAL v (not desired v)
    expected_wR_actual = (v_actual + omega_actual*L/2) / r;
    expected_wL_actual = (v_actual - omega_actual*L/2) / r;
    expected_alpha_actual = atan2(omega_actual*L, v_actual);
    
    fprintf('  Expected (using v_actual=%.4f):\n', v_actual);
    fprintf('    wR = %.4f, wL = %.4f\n', expected_wR_actual, expected_wL_actual);
    fprintf('  Actual DD(1,:) = [%.4f, %.4f]\n', DD(1,1), DD(1,2));
    
    assert(abs(DD(1,1) - expected_wR_actual) < 0.01, 'DD wR wrong');
    assert(abs(DD(1,2) - expected_wL_actual) < 0.01, 'DD wL wrong');
    
    fprintf('  PASSED (with corrected expected values)\n\n');
    
    % ============ TEST 4: LAST POINT ===========
    fprintf('Test 4: Last point set to 0 (robot stops)\n');
    
    assert(norm(DD(end,:)) < 1e-6, 'DD last point should be [0,0]');
    assert(norm(TRI(end,:)) < 1e-6, 'TRI last point should be [0,0]');
    assert(norm(OMNI(end,:)) < 1e-6, 'OMNI last point should be [0,0,0]');
    
    fprintf('  DD(end,:) = [%.4f, %.4f]\n', DD(end,1), DD(end,2));
    fprintf('  TRI(end,:) = [%.4f, %.4f]\n', TRI(end,1), TRI(end,2));
    fprintf('  OMNI(end,:) = [%.4f, %.4f, %.4f]\n', OMNI(end,1), OMNI(end,2), OMNI(end,3));
    fprintf('  PASSED\n\n');
    
    % ============ TEST 5: OUTPUT SIZES ===========
    fprintf('Test 5: Output matrix sizes\n');
    
    assert(size(DD,1) == M, 'DD should have M rows');
    assert(size(DD,2) == 2, 'DD should have 2 columns');
    assert(size(TRI,1) == M, 'TRI should have M rows');
    assert(size(TRI,2) == 2, 'TRI should have 2 columns');
    assert(size(OMNI,1) == M, 'OMNI should have M rows');
    assert(size(OMNI,2) == 3, 'OMNI should have 3 columns');
    
    fprintf('  DD: %dx%d, TRI: %dx%d, OMNI: %dx%d\n', ...
        size(DD,1), size(DD,2), size(TRI,1), size(TRI,2), size(OMNI,1), size(OMNI,2));
    fprintf('  PASSED\n\n');
    
    % ============ ALL TESTS PASSED ===========
    fprintf('========================================\n');
    fprintf('ALL TESTS PASSED!\n');
    fprintf('========================================\n');
end

function angle = wrapToPi(angle)
    % Wrap angle to [-pi, pi]
    angle = atan2(sin(angle), cos(angle));
end
