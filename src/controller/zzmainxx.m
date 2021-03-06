%phys_engine_path = ['..',filesep,'physics_engine_v9_william_OCT_1'];
phys_engine_path = ['..',filesep,'phys_engine'];
addpath(phys_engine_path);

ax = axes;
max_time = 20;
world = world1(10,10,10, 20, ax, max_time, 0.01); 
world.draw_scene;

% world1.initialize_configuration(number_of_disks,R,number_of_boxes,l,w,h)
n_obj = 10;
world.initialize_configuration(n_obj,1,0,0,0,0);

% world1.jacobian_initialization();
world.jacobian_initialization();

% world1.dynamics(simulation_time,solver);
solver_choice = 2;

x = world.x_log(:,1);
y = world.y_log(:,1);
z = world.z_log(:,1);

phi = world.angle_phi_log(:,1);
sig = world.angle_sig_log(:,1);
psi = world.angle_psi_log(:,1);

sphere_size = world.radius(:);

%MATLAB folder search path
addpath('iniconfig');

%Define mmap file names
% cfg_ini = ['data',filesep,'cfg.ini'];
% mmap_dataX_pos = ['data',filesep,'dataX_pos'];
% mmap_dataY_pos = ['data',filesep,'dataY_pos'];
% mmap_dataZ_pos = ['data',filesep,'dataZ_pos'];
% 
% mmap_data_siz = ['data',filesep,'data_siz'];
% 
% mmap_dataP_rot = ['data',filesep,'dataP_rot'];
% mmap_dataQ_rot = ['data',filesep,'dataQ_rot'];
% mmap_dataR_rot = ['data',filesep,'dataR_rot'];

%Config Data
ini = IniConfig();
ini.ReadFile(cfg_ini);

num_of_objs = n_obj;
ini.SetValues('Config', 'objects', num_of_objs);
ini.WriteFile(cfg_ini);

%Initialize Data Size - needed for memmap
engine_posX = ones(num_of_objs,1);          
engine_posY = ones(num_of_objs,1);          
engine_posZ = ones(num_of_objs,1);          

engine_size = ones(num_of_objs,1);

engine_rotP  = ones(num_of_objs,1);
engine_rotQ  = ones(num_of_objs,1);
engine_rotR  = ones(num_of_objs,1);

for i=1:num_of_objs
   engine_size(i) = sphere_size(i);
end



%Storing all simulation data for all time
store_posX = ones(max_time,n_obj); store_posY = ones(max_time,n_obj); 
store_posZ = ones(max_time,n_obj);
store_rotP = ones(max_time,n_obj); store_rotQ = ones(max_time,n_obj);
store_rotR = ones(max_time,n_obj);

%Simulate and Store All Data
tic
for i = 1:max_time-1
    disp(i)
    world.dynamics(i,solver_choice);

    %Storing Data
    store_posX(i,:) = world.x_log(:,i+1);
    store_posY(i,:) = world.y_log(:,i+1);
    store_posZ(i,:) = world.z_log(:,i+1);

    store_rotP(i,:) = world.angle_phi_log(:,i+1);
    store_rotQ(i,:) = world.angle_sig_log(:,i+1);
    store_rotR(i,:) = world.angle_psi_log(:,i+1);
    
end
toc

%---------RENDER
%Define mmap file names
cfg_ini = ['data',filesep,'cfg.ini'];
mmap_dataX_pos = ['data',filesep,'dataX_pos'];
mmap_dataY_pos = ['data',filesep,'dataY_pos'];
mmap_dataZ_pos = ['data',filesep,'dataZ_pos'];

mmap_data_siz = ['data',filesep,'data_siz'];

mmap_dataP_rot = ['data',filesep,'dataP_rot'];
mmap_dataQ_rot = ['data',filesep,'dataQ_rot'];
mmap_dataR_rot = ['data',filesep,'dataR_rot'];

%Construct new mmap file. Dimension of mmap file is fixed on construction.
fileID = fopen(mmap_dataX_pos,'w');
fwrite(fileID,engine_posX,'double');
fclose(fileID);

fileID = fopen(mmap_dataY_pos,'w');
fwrite(fileID,engine_posY,'double');
fclose(fileID);

fileID = fopen(mmap_dataZ_pos,'w');
fwrite(fileID,engine_posZ,'double');
fclose(fileID);

fileID = fopen(mmap_data_siz,'w');
fwrite(fileID,engine_size,'double');
fclose(fileID);

fileID = fopen(mmap_dataP_rot,'w');
fwrite(fileID,engine_rotP,'double');
fclose(fileID);

fileID = fopen(mmap_dataQ_rot,'w');
fwrite(fileID,engine_rotQ,'double');
fclose(fileID);

fileID = fopen(mmap_dataR_rot,'w');
fwrite(fileID,engine_rotR,'double');
fclose(fileID);

%Link controller values
ctrl_posX= open_mmap(mmap_dataX_pos);
ctrl_posY= open_mmap(mmap_dataY_pos);
ctrl_posZ= open_mmap(mmap_dataZ_pos);

ctrl_rotP= open_mmap(mmap_dataP_rot); 
ctrl_rotQ= open_mmap(mmap_dataQ_rot); 
ctrl_rotR= open_mmap(mmap_dataR_rot); 

%Start Renderer
start_renderer();

dt = 0.05;
%Render stored data
pause on
tic
for i=1:max_time-1
    pause(dt);
   
    ctrl_posX.Data = store_posX(i,:);
    ctrl_posY.Data = store_posY(i,:);
    ctrl_posZ.Data = store_posZ(i,:);
    
    ctrl_rotP.Data = store_rotP(i,:);
    ctrl_rotQ.Data = store_rotQ(i,:);
    ctrl_rotR.Data = store_rotR(i,:);
end
toc
pause off