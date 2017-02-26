function sbx2tif_rgb_partitioned(fname,varargin) 
% sbx2tif_rgb_divided
% Will use parallel processing to convert file in partitions.
% Generates tif file from sbx files
% Writes out file as RGB for single or multi channel recordings
% If aligned = 0, no alignment will occur. If aligned = 1, frames will be aligned. 
% Arguments beyond 'aligned' are optional. If no argument is passed the whole file is written.
% Example: sbx2tif_rgb('day1_000_000',1,200); This will align the first 200 frames and convert to tiff.
 
tic;

z = sbxread(fname,1,1);
global info;
 
if(nargin>1)
    N = min(varargin{1},info.max_idx);
else
    N = info.max_idx;
end

index_max = N;
%frames_per_division = floor(index_max/num_partitions);
%partition_index_top = 1+frames_per_division:frames_per_division:index_max;
%partition_index_top(12) = index_max;
%partition_index_bottom = partition_index_top - (frames_per_division - 1);
%partition_index_bottom(1) = 1;
%partition_index = cat(3,partition_index_bottom,partition_index_top);

data = zeros(info.sz(1),info.sz(2),index_max);
    
parfor i = 1:index_max
   data(:,:,i) = squeeze(sbxread(fname,i,1));
   if i == 1
        imwrite(data(:,:,i),[fname '.tif'],'tif')
    else
        imwrite(data(:,:,i),[fname '.tif'],'tif','writemode','append');
    end
end

%for i = 1:index_max
%    if i == 1
%        imwrite(data(:,:,i),[fname '.tif'],'tif')
%    else
%        imwrite(data(:,:,i),[fname '.tif'],'tif','writemode','append');
%    end
%end

toc;

end



