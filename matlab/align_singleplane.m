function align_singleplane(filename,varargin)
% Nonrigid alignment for single plane sbx data.
% Writes out standard deviation and max projections.
% 'filename' is the name of the sbx file without '.sbx'
% Optional argument that allows manual selection of the template image:
%  - Option 1: Single index; e.g. 5, selects frame 5 as template.
%  - Option 2: Length 2 array for average image template; e.g. [2 10], 
%       takes the average of frames 2:10.

z = sbxread(filename,1,1);
global info;
originalRecordsPerBuffer = info.recordsPerBuffer;

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

tic

% Determine if necessary to divide file into chunks and how many
frame_size = rows * cols * 2;
fileSize = frame_size * max_idx;
chunk_num_frames = floor(1000000000/frame_size); % using 1GB chunks
chunk_num_frames_size = frame_size * chunk_num_frames;
num_chunks = fileSize/chunk_num_frames_size;

if num_chunks > 1
    num_chunks = floor(num_chunks);
    set_idx = chunk_num_frames;
    remaining_size = fileSize - (num_chunks*chunk_num_frames_size);
    remain_idx = remaining_size/(frame_size);
    num_chunks = num_chunks + 1;
    if remain_idx == 0
        num_chunks = num_chunks - 1;
        remain_idx = set_idx;
    end
    % Create index of weights for mean image calculations
    weight_index(1:num_chunks) = set_idx;
    weight_index(num_chunks) = remain_idx;
else
    set_idx = max_idx;
    num_chunks = 1;
    weight_index = set_idx;
end

% create array to hold mean values of each frame
mean_of_templates = 1:200;

% create memory map to original data
original_mapped_data = memmapfile([filename '.sbx'],'Format',{'uint16' [cols rows max_idx] 'img'},'Repeat',1);

% Generate template
if nargin > 1
    template_indices = varargin{1};
    if size(template_indices) <= [1 2]
        if size(template_indices)< [1 2]
            fprintf('Index %i selected as template.\n',template_indices);
            template = intmax('uint16') - permute(original_mapped_data.Data.img(left_margin:end,:,template_indices),[2 1 3]);
        else
            fprintf('Average of indices %i:%i selected as template.\n',template_indices);
            template = mean(intmax('uint16') - permute(original_mapped_data.Data.img(left_margin:end,:,template_indices(1):template_indices(2)),[2 1 3]));
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
            template = intmax('uint16') - permute(original_mapped_data.Data.img(:,:,brightest_idx),[2 1 3]);  
end

% Initialize array to hold aligned images and set starting index
int = uint16(0);
img_data(1:rows,1:cols-left_margin+1,1:set_idx) = int;

% Initialize array to hold mean images
mean_collection = zeros(rows,cols-left_margin+1,num_chunks);

% Initialize array to hold max images
max_collection(1:rows,1:cols-left_margin+1,1:num_chunks) = int;

% create parallel pool if none exists
pool = gcp('nocreate');
if isempty(pool)
    parpool(num_cores);
end
fprintf('Aligning...\n');

for i = 1:num_chunks
    % Set starting index
    k = ((i * set_idx) - set_idx)+ 1;
    
    % If on last chunk, truncate img_data array
    if num_chunks > 1 && i == num_chunks
        img_data = img_data(:,:,1:remain_idx);
        set_idx = remain_idx;
    end
    
    % Align frames in parallel and store in img_data matrix
    parfor j = 1:set_idx
        frame = k + j - 1;
        img = squeeze(sbxread(filename,frame,1));
        img = img(:,left_margin:end);
        [~,img_aligned] = imregdemons(img,template,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
        img_data(:,:,j) = img_aligned;
    end

    % Store mean image of chunk
    mean_collection(:,:,i) = mean(img_data,3);
    
    % Store max image of chunk
    max_collection(:,:,i) = max(img_data,[],3);
    
    % Convert aligned frames back to raw sbx format
    [m,n,z] = size(img_data);
    img_data = intmax('uint16')-permute(img_data,[2 1 3]);
    img_data = reshape(img_data,[1, (m*n*z)]);
    
    % Write file back out as raw sbx binary
    if i == 1
        fileID = fopen(['Aligned_' filename '.sbx'],'w');
        fwrite(fileID,img_data,'uint16');
        fclose(fileID);
    else
        fileID = fopen(['Aligned_' filename '.sbx'],'a');
        fwrite(fileID,img_data,'uint16');
        fclose(fileID);
    end
    
    % Reshape img_data array back to MxNxZ
    img_data = reshape(img_data,m,n,z);
end

% Calculate and save max projection image
max_projection = max(max_collection,[],3);
imwrite(max_projection,['MAX_' filename '.tif'],'tif');

% Calculate total mean image 
weighted_mean(1:rows,1:cols,1:num_chunks) = 0;

for i = 1:num_chunks
    weighted_mean(:,:,i) = mean_collection(:,:,i)*weight_index(i);
end

meanImg = (sum(weighted_mean,3))/max_idx;

% Write the metadata file, modify fields for newly cropped dimensions
load([filename '.mat']);
info.originalRecordsPerBuffer = originalRecordsPerBuffer;
if info.scanmode == 0
    info.recordsPerBuffer = m/2;
else
    info.recordsPerBuffer = m;
end
info.sz = [m n];
save(['Aligned_' filename '.mat'],'info');

% Calculate standard deviation and write to file
for i = 1:max_idx
    dRead = double(squeeze(sbxread(['Aligned_' filename],i,1)));
    img = (dRead - meanImg).^2;
    if i == 1
        v = img;
    else
        v = v+img;
    end
end

varianceImg = v/max_idx;
stdDevImg = sqrt(varianceImg);
stdDevImg = uint16(stdDevImg);
imwrite(stdDevImg,['STD_' filename '.tif'],'tif');

align_time = toc;
fprintf('Aligned all %d frames in %f seconds.\n', max_idx, align_time);
fprintf('Alignment speed: %f frames/sec.\n', max_idx/align_time);

end


