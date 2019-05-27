WIDTH = 1500;
arena = zeros([WIDTH,WIDTH],'single');
gpu_arena = gpuArray(arena);
%%
figure(1)
set(gcf,'Position', [2    42   958   954])
subplot('Position',[0.05,0.05,0.9,0.9])
h = imshow(arena,[0,1]);
colormap("Gray")
xticks([])
yticks([])
axis equal tight
%%
do_rec = 0;
if do_rec
    F = {};
end
%%
DECAY_rate = 0.92;
DIFF_SENSITIVITY = 0.2;
TURN_ANGLE = 0.8;
DIFF_KER = 0.05* [[0.5, 1.0, 0.5];
                           [1.0, -6., 1.0];
                           [0.5, 1.0, 0.5]]; 
DIFF_KER(2,2) = DIFF_KER(2,2) +1;
% OCTARANT = pi/4;
% OCTAANG_arr = [ [1, 0]; [1, 1]; [0, 1]; [-1, 1]; [-1, 0]; [-1, -1]; [0, -1]; [1, -1] ];
DEDEC_NUM = 12;
DEDECRANT = pi/6;
DEDECANG_arr = 3 * [ [2, 0]; [2, 1]; [1, 2]; [0, 2]; [-1, 2]; [-2, 1]; [-2, 0]; [-2, -1]; [-1, -2]; 
                                    [0, -2]; [1, -2]; [2, -1]; ];
assert(DEDEC_NUM==size(DEDECANG_arr, 1))
PARTICLE_N = 8000;
TIMESTEP = 500;

arena = zeros([WIDTH,WIDTH],'single');
gpu_arena = arena;
% pos_arr = 450 + (100 * rand([PARTICLE_N, 2], 'single'));%
theta_arr = (2*pi * rand([PARTICLE_N,1], 'single'));
% pos_arr = WIDTH / 2 - 10 * [cos(theta_arr), sin(theta_arr)];
pos_arr = WIDTH / 2 + [- 40 * [cos(theta_arr(1:2000)), sin(theta_arr(1:2000))]; 
                                        - 500 * [cos(theta_arr(2001:5000)), sin(theta_arr(2001:5000))];
                                         - 200 * [cos(theta_arr(5001:end)), sin(theta_arr(5001:end))]];
vel_scale_arr = (2.8 + 0.4* randn([PARTICLE_N, 1], 'single'));
vel_arr = vel_scale_arr.*[cos(theta_arr), sin(theta_arr)];
sens_arr = (zeros([PARTICLE_N, 3]));

tic
for t = 1:TIMESTEP
    figure(1)
    h = imshow(gpu_arena,[0,1]);
    pos_arr = mod((pos_arr + vel_arr) - 1, WIDTH) + 1;
    dir_id_arr = mod(floor(theta_arr / DEDECRANT), DEDEC_NUM) + 1; 
    for part_i = 1: PARTICLE_N
        loc = [floor(pos_arr(part_i,1)), floor(pos_arr(part_i,2))];
        gpu_arena(loc(1), loc(2)) = gpu_arena(loc(1), loc(2)) + 0.9;
        locM = mod(loc + DEDECANG_arr(dir_id_arr(part_i) , :) -1, WIDTH) + 1;
        locL = mod(loc + DEDECANG_arr(mod(dir_id_arr(part_i) - 2, DEDEC_NUM)+1, :) -1, WIDTH) + 1;
        locR = mod(loc + DEDECANG_arr(mod(dir_id_arr(part_i)     , DEDEC_NUM)+1, :) -1, WIDTH) + 1;
        Lsens = gpu_arena(locL(1), locL(2));
        Msens = gpu_arena(locM(1), locM(2));
        Rsens = gpu_arena(locR(1), locR(2));
        if Msens > Lsens && Msens > Rsens
            % do nothing
        elseif Rsens > Lsens && abs(Rsens - Lsens) > DIFF_SENSITIVITY
            theta_arr(part_i) = theta_arr(part_i) + DEDECRANT * TURN_ANGLE ;%* rand(1) ;
        elseif Lsens > Rsens && abs(Rsens - Lsens) > DIFF_SENSITIVITY
            theta_arr(part_i) = theta_arr(part_i) - DEDECRANT * TURN_ANGLE  ;%* rand(1) ;
        else
            theta_arr(part_i) = theta_arr(part_i) + DEDECRANT*(2*rand(1) - 1) * TURN_ANGLE;
        end
        sens_arr(part_i, :) = [Lsens, Msens, Rsens];
    end
    vel_arr = vel_scale_arr.*[cos(theta_arr), sin(theta_arr)];
    % pos_arr = pos_arr_;
        %arena(floor(pos_arr(:,1)), floor(pos_arr(:,2)))  = arena(floor(pos_arr(:,1)), floor(pos_arr(:,2))) + 0.5;
    gpu_arena =  DECAY_rate * conv2(gpu_arena, DIFF_KER, 'same');
    if do_rec
        F{t} = getframe(gcf);
    end
    pause(0.01)
end
DT = toc;
disp("Total Frame rate (Hz)")
disp(TIMESTEP/DT)

%%
filename = 'radiation_unit_circ';
for n = 1:length(F)
    frame = F{n};
    im = frame2im(frame);
    [imind,cm] = rgb2ind(im,256);
    if n == 1
      imwrite(imind,cm,[filename, '.gif'],'gif', 'Loopcount',inf);
    else
      imwrite(imind,cm,[filename, '.gif'],'gif','WriteMode','append');
    end
end
%% Write
writerObj = VideoWriter([filename,'.avi']);
writerObj.FrameRate = 10;
 % set the seconds per image
% open the video writer
open(writerObj);
% write the frames to the video
for i=1:length(F)
    % convert the image to a frame
    frame = F{i} ;    
    writeVideo(writerObj, frame);
end
% close the writer object
close(writerObj);

