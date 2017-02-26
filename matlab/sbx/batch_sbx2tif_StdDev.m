function batch_sbx2tif_StdDev()
% pbatch_sbx2tif will convert all sbx files within a directory using
% parallel processing. Set aligned = 0 if you do not want frames to be
% aligned, and 1 if you do. The next argument is optional and will
% determine the number of frames to convert starting with the first one.
% Example: pbatch_sbx2tif(1,100) will align the first 100 frames of all sbx
% files in the directory and convert them to tiff stacks.

tic;

d = dir('*.sbx');

parpool(6);

for i = 1:length(d)
        fn = strtok(d(i).name,'.');
        if (exist(sprintf('STD_%s.tif',fn),'file')) % already converted?
            fprintf('STD_%s.tif already exists.',fn);
        else
            parallel_2_sbx2tif_stdDev(fn);
        end
end

toc;

end
    