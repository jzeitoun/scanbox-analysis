function align_standard(fname,varargin)
% Aligns recorings made with the optotune sawtooth waveform.
% Only intended for single-channel data.

sbx = sbxread(fname,1,1);
global info;

% initialize parameters
max_idx = info.max_idx;
rows = info.sz(1);
cols = info.sz(2);
num_cores = feature('numCores');

% if bidirectional mode, remove left 100 pixels
if info.scanmode == 0
    left_margin = 101;
else
    left_margin = 1;
end

% create memory map to original data
original_mapped_data = memmapfile([fname '.sbx'],'Format',{'uint16' [cols rows max_idx] 'img'},'Repeat',1);

% create new file to hold aligned data and memory map it
fprintf('Allocating space for aligned data...\n');
f = fopen(['Aligned_' fname '.sbx'],'w');
fclose(f);
size_in_bytes = 2 * (cols-left_margin+1) * rows * max_idx;
FileResize(['Aligned_' fname '.sbx'],size_in_bytes);

% create array to hold mean values of each frame
mean_of_templates = 1:200;

tic;

% generate template
if nargin > 1
    template_indices = varargin{1};
    if size(template_indices) <= [1 2]
        if size(template_indices)< [1 2]
            fprintf('Index %i selected as template.\n',template_indices);
            template = intmax('uint16') - permute(original_mapped_data.Data.img(left_margin:end,:,template_indices),[2 1 3]);
        else
            fprintf('Average of indices %i:%i selected as template.\n',template_indices);
            template = mean(intmax('uint16') - permute(original_mapped_data.Data.img(left_margin:end,:,template_indice(1):template_indices(2)),[2 1 3]));
        end
    else
        error('Error. Length of template array cannot be greater than 2.');
    end
else 
    fprintf('Using automated template selection.\n');
    slice = intmax('uint16') - permute(original_mapped_data.Data.img(left_margin:end,:,1:200),[2 1 3]);
            for n = 1:200
                frame = slice(:,:,n);
                mean_of_templates(n) = mean(frame(:));
            end
            [~,brightest_idx] = max(mean_of_templates);
            template = intmax('uint16') - original_mapped_data.Data.img(:,:,brightest_idx),[2 1 3]);  
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
    [~,aligned_img] = imregdemons(unaligned_img,template,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
    aligned_img = intmax('uint16')-permute(aligned_img,[2 1 3]);
    write_sbxmemmap(aligned_mapped_data,aligned_img,i);
end

% generate max projection
max_projection = max(aligned_mapped_data.Data.img,[],3);
max_projection = intmax('uint16') - permute(max_projection,[2 1]);
imwrite(max_projection,['MAX_' fname '.tif'],'tif');

% generate mean projection
mean_projection = mean(aligned_mapped_data.Data.img,3);
mean_projection = permute(mean_projection,[2 1]);

% write the metadata file, modify fields for newly cropped dimensions
load([fname '.mat']);
info.sz = [rows cols-left_margin+1];
info.originalRecordsPerBuffer = info.recordsPerBuffer;
save(['Aligned_' fname '.mat'],'info');

% Calculate standard deviation and write to file
for i = 1:maxIDX
    dRead = double(aligned_mapped_data.Data.img(:,:,i));
    img = (dRead - mean_projection).^2;
    if i == 1
        v = img;
    else
        v = v+img;
    end
end

varianceImg = v/max_idx;
stdDev_projection = sqrt(varianceImg);
stdDev_projection = uint16(stdDev_projection);
imwrite(stdDev_projection,['STD_' fname '.tif'],'tif');

alignTime = toc;
fprintf('Aligned all %d frames in %f seconds.\n', max_idx, alignTime);
fprintf('Alignment speed: %f frames/sec.\n', max_idx/alignTime);

end