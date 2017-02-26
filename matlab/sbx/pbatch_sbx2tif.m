function pbatch_sbx2tif(aligned,varargin)
% pbatch_sbx2tif 
% Converts all sbx files within a directory using
% parallel processing. 
% If aligned = 0, no alignment will occur. If aligned = 1, frames will be aligned. 
% The next argument is optional and will determine the number of frames to convert,
% starting with the first one.
% Example: pbatch_sbx2tif(1,100) will align the first 100 frames of all sbx
% files in the directory and convert them to tiff stacks.
tic;
d = dir('*.sbx');

if nargin >= 2
    frames = varargin{1};
else
    frames = 0;
end

parfor i = 1:length(d)
        fn = strtok(d(i).name,'.');
        if (exist([fn,'.tif'])) % already converted?
            message = sprintf('%s.tif already exists.',fn);
            disp(message);
        else
            if frames > 0
                sbx2tif_rgb(fn,aligned,frames);
            else
                sbx2tif_rgb(fn,aligned);
            end
        end
end

toc;

end
    