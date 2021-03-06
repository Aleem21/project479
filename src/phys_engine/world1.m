classdef world1 < handle
   properties
        ax;  lines;  
            %lines are for drawing
        lengthhh; width; height;
        number_of_edges; gravity;
        max_time;  time_step;  loop_time=[];  stop_time;  
            %stop time allows user to save the scence data  
            
        RigidBodies = [];        
        global_position;    % (5x3) to update x_log, y_log, z_log, constantly updated
        global_velocity;    % (15x1) the time derivative for the Dofs of the system
        global_mass;    %vector
      
        %All logs (trajectories) are for drawing
        x_log = []; %size = N(RB)*max_time  need for drawing 
        y_log = []; %size = N(RB)*max_time  
        z_log = []; %size = N(RB)*max_time
        angle_phi_log = []; %size = N(RB)*max_time
        angle_sig_log = []; %size = N(RB)*max_time
        angle_psi_log = []; %size = N(RB)*max_time
        
        radius = []; %stores the radius of all spheres
        velocity_log = [];  %updated by global velocity, size = (DoF*N(RB)) * max_time, important for dynamics

        Walls = [];   
        wall_normal = [];
        wall_d = [];
        wall_direction = [];
        
        Normal_object;  %matrix sotring the normal direction between all object-object interaction
        Normal_indices; 
        
        JA;
        JA_indices3=[]; JA_indices4=[]; JA_indices5=[];JA_indices6=[];
        
        Normal_wall;
        
        JAW;
        JAW_indices3=[];JAW_indices4=[];
        object_wall_normal=[];
        
        JW;

        previous_set = [];  %useful for some active methods
   end
   
   methods 
        %Constructor
        function obj = world1(L,W,H,number_of_edges,AXES,max_time,time_step)
            obj.ax = AXES;
            obj.lines = patch();
            
            obj.lengthhh = L;
            obj.width = W;
            obj.height = H;
             
            obj.number_of_edges = number_of_edges;
            obj.max_time = max_time;
            obj.gravity = 100;
            obj.time_step = time_step;
            obj.loop_time = zeros(1,max_time);
            obj.stop_time = 0;
            
            %initializing the walls
            top =    Wall3D(0,0,1,H/2,-1,0);
            bottom = Wall3D(0,0,1,-H/2,1,0);
            right =  Wall3D(1,0,0,L/2,-1,0);
            left =   Wall3D(1,0,0,-L/2,1,0);
            inner =  Wall3D(0,1,0,W/2,-1,0);
            outer =  Wall3D(0,1,0,-W/2,1,0);
            
            obj.adding_wall(top);
            obj.adding_wall(bottom);
            obj.adding_wall(right);  
            obj.adding_wall(left);
            obj.adding_wall(inner);  
            obj.adding_wall(outer);  
        end
   
        function adding_body(obj,B)
            obj.RigidBodies = [obj.RigidBodies B];
            disp('A 3D rigid body has been added to the scene');
            obj.global_position = [obj.global_position; [B.position]];
            obj.global_velocity = [obj.global_velocity; [B.velocity]'];
            obj.global_mass = [obj.global_mass; B.mass_vector'];
            %obj.radius = [obj.radius B.radius];
        end
        
        function adding_wall(obj,W)
            % the wall is a line with equation a*x+b*y+c*z = d
            % wall_direction pointing inward
            obj.Walls = [obj.Walls W];
            obj.wall_normal = [obj.wall_normal; W.normal];
            obj.wall_d = [obj.wall_d; W.d];
            obj.wall_direction = [obj.wall_direction; W.normal_direction];
        end
       
        function initialize_configuration(obj,n_sphere,r,n_box,l,w,h)
            %initialize the configuration of n shperes with the same radius r
            no = n_sphere + n_box;  %number of objects
            r = 0.5;
            xstart = -obj.lengthhh/2 + 1*r;
            xend = obj.lengthhh/2 - 1*r;
            zstart = -obj.height/2 + 1*r;
            zend = obj.height/2 - 1*r - 1;
            ystart = -obj.width/2 + 1*r;
            yend = obj.width/2 - 1*r;
            
            xinterval = 2.1*r;
            yinterval = 2.1*r;
            zinterval = 2.1*r;
            xnumber = floor(abs(xend - xstart)/xinterval);
            ynumber = floor(abs(yend - ystart)/yinterval);
            znumber = floor(abs(zend - zstart)/zinterval);

            %create n number of shperes
            for i = 1:n_sphere
                % distribute the shperes so they won't overlap when created
                x = xstart + (mod((i-1),xnumber)+1)*xinterval;  
                y = yend - floor((i-1)/xnumber)*yinterval + abs(yend - ystart-yinterval/2)*floor((i-1)/(xnumber*ynumber)); 
                z = zend - floor((i-1)/(xnumber*ynumber))*zinterval;
                phi = 2*pi*rand;  theta = 2*pi*rand;  psi = 2*pi*rand; 
                Position = [x,y,z,phi,theta,psi];
                
                vx = 1*rand; vy = 1*rand; vz = 1*rand;
                %vx = 0; vy =0; vz=0;
                omega_phi = 10; omega_theta = 5; omega_psi = 40;
                Velocity = [vx,vy,vz,omega_phi,omega_theta,omega_psi];
                
                %%%%%%%%%%%%%%%%%%%%
                mass = 1;
                res = 1;
                
                %createDisk(obj,r,x,y,vx,vy,angle,omega,obj.number_of_edges);
                obj.adding_body(Sphere(Position,Velocity,mass,r,res));
                obj.radius = [obj.radius r];
                %create a disk with random velocity at the position(x,y)
            end
            
            %initialize space to store the states 
            obj.x_log = zeros(no,obj.max_time);
            obj.y_log = zeros(no,obj.max_time);
            obj.z_log = zeros(no,obj.max_time);
            obj.angle_phi_log = zeros(no,obj.max_time); %size = N(RB)*max_time
            obj.angle_sig_log = zeros(no,obj.max_time); %size = N(RB)*max_time
            obj.angle_psi_log = zeros(no,obj.max_time); %size = N(RB)*max_time
            obj.velocity_log = zeros(6*no,obj.max_time);
            
            % Fill in logs at every time step
            obj.x_log(:,1) = obj.global_position(:,1);
            obj.y_log(:,1) = obj.global_position(:,2);
            obj.z_log(:,1) = obj.global_position(:,3);
            obj.angle_phi_log(:,1) = obj.global_position(:,4);
            obj.angle_sig_log(:,1) = obj.global_position(:,5);
            obj.angle_psi_log(:,1) = obj.global_position(:,6);
            obj.velocity_log(:,1) = obj.global_velocity;
            
            for i = 1:n_sphere
                obj.radius(i) = r;
            end
            obj.radius(2)=0.3; obj.radius(3)=0.3; obj.radius(6)=1;
            
        
        end
   end
   
   methods
        
        function dynamics(obj,t,solver)
            dt = obj.time_step;
            g = obj.gravity;
            nb = length(obj.RigidBodies);
            nw = length(obj.Walls);
            p = nb*(nb - 1)/2;    %number of object-object interaction
            wp= nb*nw;    %number of object-wall interaction
            
            %Extract the position data for all objects
            x = obj.x_log(:,t);  y = obj.y_log(:,t);  z = obj.z_log(:,t);
            phi = obj.angle_phi_log(:,t);
            sig = obj.angle_sig_log(:,t);
            psi = obj.angle_psi_log(:,t);
            radius_vec = obj.radius(:);
                     
%%%%%%%%%%%%%%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % the formula gives the distance between a point and a plane
            % obj.wall_normal is nw by 3, with [a,b,c] on each row for each wall
            % vertcat(x', y', z') is 3 by nb
            % repmat(obj.wall_c,1,nb) is nw by nb 
            distance = abs(obj.wall_normal * vertcat(x',y',z') + repmat(obj.wall_d,1,nb))./ ...
            repmat(sqrt(sum(abs(obj.wall_normal).^2,2)),1,nb);
        
            % repmat(radius_vec',nw,1) is nw by nb 
            oscillation = 0.1 * sin(10*t);
            distance_to_wall = distance - repmat(radius_vec',nw,1) + oscillation;
            
            w_speed_bound = distance_to_wall(:)/dt; 
    
            [JAW_BL] = radius_for_JAW(nw,radius_vec);
            [zzy,yxx] = expand_normal(wp,obj.object_wall_normal);
            
            obj.JAW(obj.JAW_indices3) = -zzy.*JAW_BL; 
            obj.JAW(obj.JAW_indices4) = -yxx.*JAW_BL;  %fill in ones at where with content
            %full(obj.JAW)
            %spy(obj.JAW)
            

            obj.JW = obj.Normal_wall*obj.JAW; 
            Jw = obj.JW; 
            %%%%%%%%%%%%%%%%%%
            CoR = 0.5;  % this implementation would result in tiny penetration into wall
            b = -w_speed_bound+CoR*Jw*obj.global_velocity;
            constraint_count = wp;
%%%%%%%%%%%%%%% End of wall-object distance function and Jw computation %%%%%%%%%

            %the nb by nb matrix consists of repeated columns of XM
            XM = repmat(x,1,nb);   
            YM = repmat(y,1,nb);
            ZM = repmat(z,1,nb);
            rM = repmat(radius_vec,1,nb);
            
            %lower triangle is filled with all relative position difference
            x_diff = tril(XM - XM');  
            y_diff = tril(YM - YM');
            z_diff = tril(ZM - ZM');
            r_sum = tril(rM + rM');
            
            %Find all content indices of a nb by nb lower triangular matrix
            %then store the content indexs (don't care about the content values)
            %Length of "position_indices" is p (total # of object interaction)
            [lower_tri_rows, lower_tri_columns] = find(tril(ones(nb),-1)); 
            position_indices = sub2ind([nb,nb],lower_tri_rows, lower_tri_columns);
            
            %transformation into a vector based on obtained indices(non-zero values remain)
            x_diff = x_diff(position_indices); %size is p by 1
            y_diff = y_diff(position_indices);
            z_diff = z_diff(position_indices);
            r_sum = r_sum(position_indices);
            displacement = horzcat(x_diff,y_diff,z_diff);  %size is p by 3

            dist_btw_centre = sqrt(x_diff.^2+y_diff.^2+z_diff.^2); %size is p by 1
            
            distance_btw_objects = dist_btw_centre - r_sum; %size is p by 1
            %Requires LOTS OF modification if non-spheres exist
            speed_bound = distance_btw_objects / dt;

            normal = displacement./horzcat(dist_btw_centre,dist_btw_centre,dist_btw_centre);
            %Normalized the (p by 3) distance vector

            normal2 = normal';
            normal2 = normal2(:);  %Normalized [x12;y12;z12;x13;y13;z13;...]
            
            
            %obj.Normal_indices already initialized 
            %(filled with ones at correct position) in init-Jacob
            obj.Normal_object(obj.Normal_indices) = normal2; 
            
            
            %normal=[1,2,3;4,5,6;7,8,9;10,11,12;13,14,15;16,17,18];
          
            [JA_BL,JA_TR] = radius_for_JA(nb,radius_vec);
            [zzy,yxx] = expand_normal(p,normal);
            
            obj.JA(obj.JA_indices3) = -zzy.*JA_BL; 
            obj.JA(obj.JA_indices4) = -yxx.*JA_BL;  %fill in ones at where with content
            obj.JA(obj.JA_indices5) = zzy.*JA_TR;  %fill in ones at where with content
            obj.JA(obj.JA_indices6) = yxx.*JA_TR;  %fill in ones at where with content
            %full(obj.JA)
            %spy(obj.JA)
            

            %%hi
            Jo = obj.Normal_object*obj.JA;  %constraints between objects
            
%%%%%%%%%%%%%%% End of object-object distance function and Jo computation %%%%%%%%%

            J = vertcat(Jw,Jo);
            CoR2 = 0.3;  % this implementation would result in tiny penetration into wall
            b = vertcat(b,-speed_bound+CoR2*Jo*obj.global_velocity);
            constraint_count = constraint_count + p;
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %resting threshold
            if (1)
                %construct the matrices to be used in the QP solver
                %   new_v = argmin 1/2* old_v'*M_matrix*old_v - old_v*f_g
                %   subject t0 J*v >= 0
                %   where M_matrix is the mass matrix and f_g is the global
                %   force(gravity)
                
                % need to construct global_mass in the right way
                M_matrix = diag(obj.global_mass); % true for spheres with diagonal inertia tensor
 
                f_g = (M_matrix*obj.velocity_log(:,t) - dt*repmat([0 0 g 0 0 0]',nb,1));
                % If the constrain matrix is not empty, solve for the
                % velocity that satisfies the constrain
                if ~isempty(J)   %Always true 
                    %initial guess is the old velocity
                    x0 = obj.velocity_log(:,t);
                    lambda0 = zeros(constraint_count, 1);
                    previous_set = obj.previous_set;
                    switch solver
                        case 1 
                            %disp('Direct')
                            alg = Direct(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                            %alg2 = Direct(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                        case 2
                            %disp('Iterative')
                            alg = Iterative(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                            %alg2 = Direct(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                        case 3
                            %disp('SCHURPA')
                            alg = SCHURPA2(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                            %alg2 = Direct(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                        case 4
                            alg = SchurComplement(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                            %alg2 = Direct(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                        case 5
                            alg = SCwithCG(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                        case 6
                            alg = SCwithCF(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                        otherwise
                            %disp('Direct')
                            alg = Direct(M_matrix, -f_g, J, b, constraint_count, 6*nb);
                    end
                    [x_pdasm1, fval1, exitflag1, output1, lambda1, active_set] = alg.solve(x0, lambda0, previous_set);

                    obj.global_velocity = x_pdasm1;
                    obj.previous_set = active_set;

                end
                obj.velocity_log(:,t+1)= obj.global_velocity;
            end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %update the configuration using the calculated velocity
            %Order in velocity is x,y,z,phi,sig,psi
            obj.x_log(:,t+1) = x + obj.global_velocity(1:6:end)*dt;
            obj.y_log(:,t+1) = y + obj.global_velocity(2:6:end)*dt;
            obj.z_log(:,t+1) = z + obj.global_velocity(3:6:end)*dt;
            obj.angle_phi_log(:,t+1) = phi + obj.global_velocity(4:6:end)*dt;
            obj.angle_sig_log(:,t+1) = sig + obj.global_velocity(5:6:end)*dt;
            obj.angle_psi_log(:,t+1) = psi + obj.global_velocity(6:6:end)*dt;
            
        end  %End of function dynamics
        
        function draw_scene(obj)
            % set the graphic properties
            set(obj.ax,...
                'Box','on',...
                'DataAspectRatio',[1 1 1],...
                'XLim',[-obj.width/2 obj.width/2],...
                'YLim',[-obj.height/2 obj.height/2],...
                'XLimMode','manual',...
                'YLimMode','manual',...
                'XTick',[-obj.width/2 0 obj.width/2],...
                'YTick',[-obj.height/2 0 obj.height/2],...
                'XTickLabel',[-obj.width/2 0 obj.width/2],...
                'YTickLabel',[-obj.height/2 0 obj.height/2]);
             set(obj.lines,...
                'CData',[],...
                'Parent',obj.ax,...
                'FaceColor','flat',...
                'CDataMapping','scaled',...
                'EdgeColor', [0.1 0.1 0.5],...
                'EdgeAlpha', 0.5,...
                'LineWidth', 1,...
                'tag', 'shape');
        end
          
        function jacobian_initialization(obj)
            % initialize the storage space for the constraint jacobian
            nb = length(obj.RigidBodies);
            nw = length(obj.Walls);
                
            p = nb*(nb-1)/2;  %number of object interaction
            wp = nw*nb;   %number of wall-object interaction
                
            rows = 1:p;
            columns1 = 1:3:3*p;
            columns2 = 2:3:3*p;
            columns3 = 3:3:3*p;
            indices1 = sub2ind([p 3*p], rows, columns1);
            indices2 = sub2ind([p 3*p], rows, columns2);
            indices3 = sub2ind([p 3*p], rows, columns3);
            indices = vertcat(indices1, indices2, indices3);
            indices = indices(:);
            obj.Normal_object = sparse(p,3*p);
            obj.Normal_object(indices) = ones(3*p,1); %Place "1" to everywhere with content
            obj.Normal_indices = indices;
            %%%%%%%%%%%%% End of Normal_object %%%%%%%%%%
            %%%%%%%%%%%%% Begin JA %%%%%%%%%%%%%%%%%%%%%%
            
            [tri_rows, tri_columns] = find(tril(ones(nb),-1)); %the two vectors of lower triangular matrix                

            rows = 1:3*p;
            columns1 = [6*tri_columns-5 6*tri_columns-4 6*tri_columns-3]'; % spread out 3x columns and fill in 2nd and 3rd column
            columns1 = columns1(:)';
 
            indices1 = sub2ind([3*p,6*nb],rows,columns1);

            obj.JA = sparse(3*p,6*nb);
            obj.JA(indices1) = -ones(3*p,1);  %no angular (1st,4th,7th... columns are empty)
                
            columns2  = [6*tri_rows-5 6*tri_rows-4 6*tri_rows-3]';
            columns2 = columns2(:)';
             
            indices2 = sub2ind([3*p,6*nb],rows,columns2);
                    %indices2 = sub2ind([2*p,3*nb],rows,rows2);
            obj.JA(indices2) = ones(3*p,1);  %fill in ones at where with content        
            
            JA_columns3 = zeros(1,length(columns1));  
            JA_columns4 = zeros(1,length(columns1));
            JA_columns5 = zeros(1,length(columns2));
            JA_columns6 = zeros(1,length(columns2));
            
            %This 2 loops store the indices for rx, ry, rz in JA_columns
            for k = 1:length(columns1)
                if mod(k,3)==1
                    JA_columns3(k)=columns1(k)+4;
                    JA_columns4(k)=columns1(k)+5;
                elseif mod(k,3)==2
                    JA_columns3(k)=columns1(k)+2;
                    JA_columns4(k)=columns1(k)+4;  
                else 
                    JA_columns3(k)=columns1(k)+1;
                    JA_columns4(k)=columns1(k)+2;                      
                end
            end
            for k = 1:length(columns2)
                if mod(k,3)==1
                    JA_columns5(k)=columns2(k)+4;
                    JA_columns6(k)=columns2(k)+5;
                elseif mod(k,3)==2
                    JA_columns5(k)=columns2(k)+2;
                    JA_columns6(k)=columns2(k)+4;  
                else 
                    JA_columns5(k)=columns2(k)+1;
                    JA_columns6(k)=columns2(k)+2;                      
                end
            end  
            
            %The scence has to keep the indice values to fill in r_x, r_y, r_z in dynamics
            obj.JA_indices3 = sub2ind([3*p,6*nb],rows,JA_columns3);  %size is 1 by 3p
            obj.JA_indices4 = sub2ind([3*p,6*nb],rows,JA_columns4);
            obj.JA_indices5 = sub2ind([3*p,6*nb],rows,JA_columns5);
            obj.JA_indices6 = sub2ind([3*p,6*nb],rows,JA_columns6);              
            
            obj.JA(obj.JA_indices3) = -ones(3*p,1);  %fill in -ones at where with content            
            obj.JA(obj.JA_indices4) = -ones(3*p,1);  %fill in -ones at where with content
            obj.JA(obj.JA_indices5) = ones(3*p,1);  %fill in ones at where with content
            obj.JA(obj.JA_indices6) = ones(3*p,1);  %fill in ones at where with content
            
            %%%%%%%%%%%% End of JA %%%%%%%%%%%%%%%%%%%%
           
            
            %%%%%%%%%%%%%Begin of Normal_Wall%%%%%%%%%%%%%%%%%%%%
            w_rows = 1:wp;
            w_columns1 = 1:3:3*wp;
            w_columns2 = 2:3:3*wp;
            w_columns3 = 3:3:3*wp;
            % the normal of the wall, pointing away from the forbidden region
         
            %%variable "normal_wall" is re-named "temp" tp avoid confusion with obj.normal_wall
            
            temp = obj.wall_normal.*repmat(obj.wall_direction,1,3);
            temp = repmat(temp,nb,1); 

            w_indices1 = sub2ind([wp 3*wp], w_rows, w_columns1);
            w_indices2 = sub2ind([wp 3*wp], w_rows, w_columns2);
            w_indices3 = sub2ind([wp 3*wp], w_rows, w_columns3);
            obj.Normal_wall = sparse(wp,3*wp);
            obj.Normal_wall(w_indices1) = temp(:,1);
            obj.Normal_wall(w_indices2) = temp(:,2);
            obj.Normal_wall(w_indices3) = temp(:,3);
            
            obj.object_wall_normal = temp; % saved for construction of JAW in dynamics
            %%%%%%%%%%%%%%%%% End of Normal_Wall %%%%%%%%%%%%%%%%
            
            
            
            %%%%%%%%%%%%%%%%% Begin of JAW %%%%%%%%%%%%%%%%%%%%%%
            
            [wall_rows, wall_columns] = find(ones(nw,nb));
            
            wall_rows = 1:3*wp;
            wall_columns = [6*wall_columns-5 6*wall_columns-4, 6*wall_columns-3]';
            wall_columns = wall_columns(:)';
            Wall_indices = sub2ind([3*wp,6*nb],wall_rows,wall_columns);
            
            obj.JAW = sparse(3*wp,6*nb);
            obj.JAW(Wall_indices) = -ones(3*wp,1);
            
            JAW_columns3=zeros(1,length(wall_columns));
            JAW_columns4=zeros(1,length(wall_columns));
        
            %This loop stores the indices for rx, ry, rz in JAW_columns
            for k = 1:length(wall_columns)
                if mod(k,3)==1
                    JAW_columns3(k)=wall_columns(k)+4;
                    JAW_columns4(k)=wall_columns(k)+5;
                elseif mod(k,3)==2
                    JAW_columns3(k)=wall_columns(k)+2;
                    JAW_columns4(k)=wall_columns(k)+4;  
                else 
                    JAW_columns3(k)=wall_columns(k)+1;
                    JAW_columns4(k)=wall_columns(k)+2;                      
                end
            end
            
            obj.JAW_indices3 = sub2ind([3*wp,6*nb],wall_rows,JAW_columns3);
            obj.JAW_indices4 = sub2ind([3*wp,6*nb],wall_rows,JAW_columns4);
         
            obj.JAW(obj.JAW_indices3) = -ones(3*wp,1);  %fill in -ones at where with content            
            obj.JAW(obj.JAW_indices4) = -ones(3*wp,1);  %fill in -ones at where with content            
            %obj_JAW
            %%%%%%%%%%%%%%%%%%% end of JAW %%%%%%%%%%%%%%%%%%%%%%%%%%%
            %obj.JW = Normal_wall*JAW;
        end
        
   end
    
end