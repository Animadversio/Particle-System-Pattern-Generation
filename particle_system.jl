using Makie, DSP, ImageFiltering
using ColorSchemes
WIDTH = 1000;
DECAY_rate = 0.92;
DIFF_SENSITIVITY = 0.2;
TURN_ANGLE = 0.8;
DIFF_KER = 0.05* [[0.5 1.0 0.5];
                  [1.0 -6. 1.0];
                  [0.5 1.0 0.5]];
DIFF_KER[2,2] += 1;
# OCTARANT = pi/4;
# OCTAANG_arr = [ [1, 0]; [1, 1]; [0, 1]; [-1, 1]; [-1, 0]; [-1, -1]; [0, -1]; [1, -1] ];
DEDEC_NUM = 12;
DEDECRANT = pi/6;
DEDECANG_arr = 3 * [ [2  0]; [2  1]; [1  2]; [0  2]; [-1  2]; [-2  1]; [-2  0]; [-2  -1]; [-1  -2];
                                    [0  -2]; [1  -2]; [2  -1]; ];
@assert(DEDEC_NUM==size(DEDECANG_arr, 1))
PARTICLE_N = 8000;
TIMESTEP = 500;

arena = zeros(Float16, (WIDTH,WIDTH) );
# gpu_arena = arena;
# pos_arr = 450 + (100 * rand([PARTICLE_N, 2], 'single'));%
theta_arr = (2*pi * rand(Float16, (PARTICLE_N,1)));
# pos_arr = WIDTH / 2 - 10 * [cos(theta_arr), sin(theta_arr)];
pos_arr = WIDTH / 2 .+ [- 40 * [cos.(theta_arr[1:2000])  sin.(theta_arr[1:2000])];
                      - 500 * [cos.(theta_arr[2001:5000])  sin.(theta_arr[2001:5000])];
                      - 200 * [cos.(theta_arr[5001:end])  sin.(theta_arr[5001:end])]];
vel_scale_arr = (2.8 .+ 0.4 * randn(Float16, (PARTICLE_N, 1)));
vel_arr = vel_scale_arr.*[cos.(theta_arr) sin.(theta_arr)];
sens_arr = (zeros(Float16, (PARTICLE_N, 3)));
scene = image(arena, show_axis = false, colormap=ColorSchemes.gray.colors, colorrange=[0,1])
# heatmap(arena, colormap=:gray, colorrange=[0,1])
# tic
TIMESTEP = 100;
record(scene, "test.mp4") do io
    for t = 1:TIMESTEP
        global pos_arr, vel_arr, theta_arr, arena, sens_arr, scene
        # scene = image(arena, show_axis = false, colormap=ColorSchemes.gray.colors, colorrange=[0,1])
        image!(scene, arena, show_axis = false, colormap=ColorSchemes.gray.colors, colorrange=[0,1])
        recordframe!(io) # record a new frame
        #
        pos_arr = mod.((pos_arr + vel_arr) .- 1, WIDTH) .+ 1;
        dir_id_arr = mod.(floor.(Int32, theta_arr / DEDECRANT), DEDEC_NUM) .+ 1;
        for part_i = 1: PARTICLE_N
            loc = [floor(Int32,pos_arr[part_i,1]), floor(Int32,pos_arr[part_i,2])];
            arena[loc[1], loc[2]] += 0.9;
            locM = mod.(loc .+ DEDECANG_arr[dir_id_arr[part_i], :] .- 1, WIDTH) .+ 1;
            locL = mod.(loc .+ DEDECANG_arr[mod(dir_id_arr[part_i] - 2, DEDEC_NUM)+1, :] .-1, WIDTH) .+ 1;
            locR = mod.(loc .+ DEDECANG_arr[mod(dir_id_arr[part_i]    , DEDEC_NUM)+1, :] .-1, WIDTH) .+ 1;
            Lsens = arena[locL[1], locL[2]];
            Msens = arena[locM[1], locM[2]];
            Rsens = arena[locR[1], locR[2]];
            if Msens > Lsens && Msens > Rsens
                # do nothing
            elseif Rsens > Lsens && abs(Rsens - Lsens) > DIFF_SENSITIVITY
                theta_arr[part_i] = theta_arr[part_i] .+ DEDECRANT * TURN_ANGLE ;#* rand() ;
            elseif Lsens > Rsens && abs(Rsens - Lsens) > DIFF_SENSITIVITY
                theta_arr[part_i] = theta_arr[part_i] .- DEDECRANT * TURN_ANGLE  ;#* rand() ;
            else
                theta_arr[part_i] = theta_arr[part_i] + DEDECRANT*(2*rand() .- 1) * TURN_ANGLE;
            end
            sens_arr[part_i, :] = [Lsens  Msens  Rsens];
        end
        vel_arr = vel_scale_arr.*[cos.(theta_arr) sin.(theta_arr)];
        # pos_arr = pos_arr_;
            #arena(floor(pos_arr(:,1)), floor(pos_arr(:,2)))  = arena(floor(pos_arr(:,1)), floor(pos_arr(:,2))) + 0.5;
        arena =  DECAY_rate * imfilter(arena, DIFF_KER, Pad(:circular));#, 'same');
        # if do_rec
        #     F{t} = getframe(gcf);
        # end
        sleep(0.01)
    end
end
scene = image(arena, show_axis = false, colormap=ColorSchemes.gray.colors, colorrange=[0,1])

disp("Total Frame rate (Hz)")
disp(TIMESTEP/DT)
