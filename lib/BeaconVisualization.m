classdef BeaconVisualization
    %BEACONVISUALIZATION Handle beacon detection visualization
    
    properties
        lines     % Array of line handles
        dists     % Array of text handles
        beacons   % Beacon positions [N x 2]
    end
    
    methods
        function obj = BeaconVisualization(beacons, parentAxes)
            % Constructor
            % Input:
            %   beacons - N x 2 matrix of [x, y] positions
            %   parentAxes - axes handle to draw in (optional, defaults to gca)
            
            obj.beacons = beacons;
            
            if nargin < 2 || isempty(parentAxes)
                parentAxes = gca;
            end
            
            % Pre-create detection line and text handles
            obj.lines = gobjects(size(beacons, 1), 1);
            obj.dists = gobjects(size(beacons, 1), 1);
            
            % Initialize all at origin (will be updated)
            for i = 1:size(beacons, 1)
                obj.lines(i) = plot(parentAxes, [0, beacons(i,1)], [0, beacons(i,2)], ...
                    'r--', 'LineWidth', 1, 'Visible', 'off');
                obj.dists(i) = text(parentAxes, beacons(i,1), beacons(i,2), '', ...
                    'FontSize', 8, 'Color', 'r', 'Visible', 'off');
            end
        end
        
        function update(obj, x, y)
            % Update detection lines and distances from robot position
            % Input:
            %   x, y - robot current position
            
            for j = 1:size(obj.beacons, 1)
                dx = obj.beacons(j, 1) - x;
                dy = obj.beacons(j, 2) - y;
                dist = sqrt(dx^2 + dy^2);
                
                % Range thresholds
                minRange = 0.3;
                maxRange = 10.0;
                
                if dist >= minRange && dist <= maxRange
                    set(obj.lines(j), 'Visible', 'on');
                    set(obj.lines(j), 'XData', [x, obj.beacons(j,1)], ...
                                      'YData', [y, obj.beacons(j,2)]);
                    
                    set(obj.dists(j), 'Visible', 'on');
                    midX = (x + obj.beacons(j,1)) / 2;
                    midY = (y + obj.beacons(j,2)) / 2;
                    set(obj.dists(j), 'Position', [midX, midY, 0], ...
                                      'String', sprintf('%.1fm', dist));
                else
                    set(obj.lines(j), 'Visible', 'off');
                    set(obj.dists(j), 'Visible', 'off');
                end
            end
        end
        
        function hide(obj)
            % Hide all detection lines
            for j = 1:size(obj.beacons, 1)
                set(obj.lines(j), 'Visible', 'off');
                set(obj.dists(j), 'Visible', 'off');
            end
        end
    end
end