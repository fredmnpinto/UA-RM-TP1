classdef EKF < handle
    %EKF Extended Kalman Filter class for robot localization
    %   Uses clear naming to show the flow of estimates:
    %   initial_estimate (x̂_k) -> predict() -> prediction (x̄_k+1) 
    %                            -> update() -> corrected_prediction (x̂_k+1)
    
    properties
        initial_estimate   % x̂_k - Current state estimate (before prediction)
        prediction        % x̄_k+1 - Predicted state (after prediction, before update)
        corrected_prediction    % x̂_k+1 - Corrected prediction (after update with measurements)
        P_initial        % P̂_k - Current covariance (before prediction)
        P_prediction     % P̄_k+1 - Predicted covariance (after prediction)
        P_corrected      % P̂_k+1 - Corrected covariance (after update)
        N                % Number of Beacons
        Q          % Process noise covariance (2x2)
        beacons    % Beacon positions (Nx2)
    end
    
    methods
        function obj = EKF(Vn, Wn, N)
            % Constructor - initialize EKF with parameters
            % Input:
            %   Vn - linear velocity noise sigma
            %   Wn - angular velocity noise sigma
            %   N - number of beacons
            
            % Initialize state
            obj.initial_estimate = [0; 0; 0];
            obj.P_initial = diag([0.01^2, 0.01^2, 0.1^2]);
            
            % Process noise
            obj.Q = [Vn^2, 0; 0, Wn^2];
            
            % Get number of beacons
            obj.N = N;
        end
        
        function [v, omega, dt_actual] = computeControlInput(obj, x_prev, x_curr, V)
            % Compute control input from consecutive poses
            % Input:
            %   x_prev - previous pose [x; y; theta]
            %   x_curr - current pose [x; y; theta]
            %   V - desired linear velocity
            
            dt_actual = norm(x_curr(1:2) - x_prev(1:2)) / V;
            
            % Avoid division by zero when dt_actual is near zero
            if dt_actual < eps
                dt_actual = 0.001;  % Minimum time step to prevent Inf/NaN
            end
            
            v = V;
            omega = wrapAngle(x_curr(3) - x_prev(3)) / dt_actual;
        end
        
        function predict(obj, v, omega, dt)
            % EKF Prediction step
            % Input:
            %   v - linear velocity
            %   omega - angular velocity
            %   dt - time step
            
            % DEBUG: Start of predict
            fprintf('  predict(): BEFORE prediction = [%.4f, %.4f, %.4f], size = [%d, %d]\n', ...
                obj.initial_estimate, size(obj.initial_estimate));
            fprintf('  predict(): theta = %.4f\n', obj.initial_estimate(3));
            
            % Use initial_estimate (x̂_k) as input
            theta = obj.initial_estimate(3);
            
            % Compute prediction (x̄_k+1) - explicitly create column vector
            obj.prediction = zeros(3, 1);  % Initialize as 3x1 column vector
            obj.prediction(1) = obj.initial_estimate(1) + v * dt * cos(theta);
            obj.prediction(2) = obj.initial_estimate(2) + v * dt * sin(theta);
            obj.prediction(3) = wrapAngle(obj.initial_estimate(3) + omega * dt);
            
            % DEBUG: End of predict
            fprintf('  predict(): AFTER prediction = [%.4f, %.4f, %.4f], size = [%d, %d]\n', ...
                obj.prediction, size(obj.prediction));
            
            % Jacobians
            J_fx = [1, 0, -v*dt*sin(theta);
                    0, 1,  v*dt*cos(theta);
                    0, 0,  1];
            
            J_fw = [dt*cos(theta), 0;
                    dt*sin(theta), 0;
                    0,              dt];
            
            % Covariance prediction
            obj.P_prediction = J_fx * obj.P_initial * J_fx' + J_fw * obj.Q * J_fw';
            obj.P_prediction = (obj.P_prediction + obj.P_prediction') / 2;  % Ensure symmetry
        end
        
        function update(obj, robot_pose)
            % EKF Update step with NaN handling
            % Input:
            %   robot_pose - [x, y, theta] for beacon detection
            
            % DEBUG: Start of update
            fprintf('  update(): robot_pose input = [%.4f, %.4f, %.4f]\n', robot_pose);
            
            % Use prediction (x̄_k+1) as input
            x_bar = obj.prediction;
            P_bar = obj.P_prediction;
            
            % DEBUG: Print x_bar and P_bar after assignment
            fprintf('  update(): x_bar = [%.4f, %.4f, %.4f]\n', x_bar);
            fprintf('  update(): P_bar = \n');
            disp(P_bar);
            
            % Get beacon measurements
            B_meas = BeaconDetection(obj.N, robot_pose);
            
            % DEBUG: Beacon measurements
            fprintf('  update(): B_meas.d = ['); fprintf('%.4f ', B_meas.d); fprintf(']\n');
            fprintf('  update(): B_meas.a = ['); fprintf('%.4f ', B_meas.a); fprintf(']\n');
            
            % Build innovation vector and matrices
            nu = [];
            J_h_rows = [];
            R_diag = [];
            
            for i = 1:obj.N
                if ~isnan(B_meas(i).d) && ~isnan(B_meas(i).a)
                    % Predicted measurement using B_meas.X, B_meas.Y
                    dx = B_meas(i).X - x_bar(1);
                    dy = B_meas(i).Y - x_bar(2);
                    d_pred = sqrt(dx^2 + dy^2);
                    a_pred = wrapAngle(atan2(dy, dx) - x_bar(3));
                    
                    % DEBUG: User's 2nd debug log
                    fprintf('  update(): Beacon %d: dx=%.4f, dy=%.4f, d_pred=%.4f, a_pred=%.4f\n', ...
                        i, dx, dy, d_pred, a_pred);
                    fprintf('  update(): B_meas.d(%d)=%.4f, B_meas.a(%d)=%.4f\n', ...
                        i, B_meas(i).d, i, B_meas(i).a);
                    
                    % Innovation
                    nu = [nu; B_meas(i).d - d_pred; wrapAngle(B_meas(i).a - a_pred)];
                    
                    % Jacobian row
                    if d_pred > 0
                        J_h_rows = [J_h_rows;
                                     -(B_meas(i).X-x_bar(1))/d_pred, -(B_meas(i).Y-x_bar(2))/d_pred, 0;
                                     (B_meas(i).Y-x_bar(2))/d_pred^2, -(B_meas(i).X-x_bar(1))/d_pred^2, -1];
                    end
                    
                    % Measurement noise - use per-beacon noise from B_meas
                    R_beacon = [B_meas(i).dn^2, 0; 0, B_meas(i).an^2];
                    R_diag = blkdiag(R_diag, R_beacon);
                end
            end
            
            if ~isempty(nu)
                % DEBUG: Innovation and Kalman gain
                fprintf('  update(): nu (innovation) = ['); fprintf('%.4f ', nu); fprintf(']\n');
                fprintf('  update(): J_h_rows size = [%d, %d]\n', size(J_h_rows));
                
                % Innovation covariance
                S = J_h_rows * P_bar * J_h_rows' + R_diag;
                
                fprintf('  update(): S = %.4f\n', S);
                
                % Kalman gain
                K = P_bar * J_h_rows' / S;
                
                fprintf('  update(): K size = [%d, %d], K = %.4f\n', size(K), K);
                
                % Update state - store as corrected_prediction
                obj.corrected_prediction = x_bar + K * nu;
                obj.corrected_prediction(3) = wrapAngle(obj.corrected_prediction(3));
                
                fprintf('  update(): corrected_prediction = [%.4f, %.4f, %.4f]\n', obj.corrected_prediction);
                fprintf('  update(): P_corrected = \n');
                disp(obj.P_corrected);
                
                % Update covariance (Joseph form)
                I = eye(3);
                obj.P_corrected = (I - K * J_h_rows) * P_bar * (I - K * J_h_rows)' + K * R_diag * K';
                obj.P_corrected = (obj.P_corrected + obj.P_corrected') / 2;  % Ensure symmetry
            else
                % No valid measurements - prediction only
                fprintf('  update(): ALL BEACONS NaN - NO UPDATE!\n');
                obj.corrected_prediction = x_bar;
                obj.P_corrected = P_bar;
            end
        end
    end
end

function angle = wrapAngle(angle)
    % Wrap angle to [-pi, pi]
    angle = atan2(sin(angle), cos(angle));
end
