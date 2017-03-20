function align_sawtooth(filename,varargin)
% Nonrigid alignment of recorings made with the optotune sawtooth waveform.
% Only intended for single-channel data.
% 'filename' is the name of the sbx file without '.sbx'
% Optional argument that allows manual selection of the template image:
%  - Must be an array of length == number of planes.
%  - The value of each index will be the index of the template image for
%       the corresponding plane.
%  - Assign a value of 0 to any indices for which you want to use automated
%       template selection.
%  - Keep in mind, the planes are interleaved so be sure to select each 
%       index from the correct set of frames; e.g. 3 planes will be
%       interleaved as 1,2,3,1,2,3,1,2,3,...
%  - Example: [1 0 3] will use the frame 1 and 3 as the templates for
%       planes 1 and 3, respectively, while the template for plane 2 will
%       be selected automatically.

sbx = sbxread(filename,1,1);
global info;

max_idx = info.max_idx;
rows = info.sz(1);
cols = info.sz(2);
num_planes = info.otparam(3);
num_cores = feature('numCores');
originalRecordsPerBuffer = info.recordsPerBuffer;

% if bidirectional mode, remove left 100 pixels
if info.scanmode == 0
    left_margin = 101;
else
    left_margin = 1; 
end

% create memory map to original data
original_mapped_data = memmapfile([filename '.sbx'],'Format',{'uint16' [cols rows max_idx] 'img'},'Repeat',1);

% create new file to hold aligned data and memory map it
fprintf('Allocating space for aligned data...\n');
f = fopen(['Aligned_' filename '.sbx'],'w');
fclose(f);
size_in_bytes = 2 * (cols-left_margin+1) * rows * max_idx;
FileResize(['Aligned_' filename '.sbx'],size_in_bytes);
aligned_mapped_data = memmapfile(['Aligned_' filename '.sbx'],'Format',{'uint16' [cols-left_margin+1 rows max_idx] 'img'},'Repeat',1,'Writable',true);

% create array to hold template images
fill = uint16(0);
template_array(1:rows,1:cols-left_margin+1,1:num_planes) = fill;

% create array to determine which template to use for each frame
template_lookup = 1:max_idx;
for n = 1:num_planes
    template_lookup(n:num_planes:end) = n;
end

% create array to hold mean values of each frame
mean_of_templates = 1:200;

tic;

% generate templates for each plane
if nargin > 1
    template_indices = varargin{1};
    if size(template_indices) ~= [1 num_planes]
        error('Error. Length of template array must be equal to %i.',num_planes);
    end
    for i = 1:num_planes
        idx = template_indices(i);
        if idx > 0
            % set template to user-defined index for this plane
            template_array(:,:,i) = intmax('uint16') - permute(original_mapped_data.Data.img(left_margin:end,:,idx),[2 1 3]);
            fprintf('Index %i selected as template for plane %i.\n',idx,i-1);
        else
            % use automated method for determining template for this plane
            slice = intmax('uint16') - permute(original_mapped_data.Data.img(left_margin:end,:,i:num_planes:num_planes*200),[2 1 3]);
            for n = 1:200
                frame = slice(:,:,n);
                mean_of_templates(n) = mean(frame(:));
            end
            [~,brightest_idx] = max(mean_of_templates);
            template_array(:,:,i) = slice(:,:,brightest_idx);     
            fprintf('Automated template selection used for plane %i.\n',i-1);
        end
    end
else
    fprintf('Using automated method to determine brightest template image for all planes...\n');
    for n = 1:num_planes
        slice = intmax('uint16') - permute(original_mapped_data.Data.img(left_margin:end,:,n:num_planes:num_planes*200),[2 1 3]);
        for i = 1:200
            frame = slice(:,:,i);
            mean_of_templates(i) = mean(frame(:));
        end
        [~,brightest_idx] = max(mean_of_templates);
        template_array(:,:,n) = slice(:,:,brightest_idx);
    end
end

% create parallel pool if none exists
pool = gcp('nocreate');
if isempty(pool)
    parpool(num_cores);
end
fprintf('Aligning...\n');

% align frames in parallel
parfor i = 1:max_idx
    unaligned_img = read_sbxmemmap(original_mapped_data,left_margin,i);
    template_idx = template_lookup(i);
    [~,aligned_img] = imregdemons(unaligned_img,template_array(:,:,template_idx),[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
    aligned_img = intmax('uint16')-permute(aligned_img,[2 1 3]);
    write_sbxmemmap(aligned_mapped_data,aligned_img,i);
end

% Write the metadata file, modify fields for newly cropped dimensions
load([filename '.mat']);
info.sz = [rows cols-left_margin+1];
info.originalRecordsPerBuffer = originalRecordsPerBuffer;
save(['Aligned_' filename '.mat'],'info');
    
align_time = toc;
fprintf('Aligned all %d frames in %f seconds.\n', max_idx, align_time);
fprintf('Alignment speed: %f frames/sec.\n', max_idx/align_time);

end
