function trace = sbx_mmap_meanTrace(fname)
% Extracts mean trace of first available 32x32 region.

tic;

% Create memmapped file.
mm = sbx_memmap(fname);
global info;

loadTime = toc;
fprintf('Loaded file in %d seconds. \n', loadTime);

% Initialize vector to hold trace values.
trace = zeros(1,info.max_idx);

for i = 1:info.max_idx
    roi = intmax('uint16')-permute(mm.Data.img(1:32,1:32,i),[2 1]);
    trace(i) = mean(roi(:));
end

traceTime = toc - loadTime;
fprintf('Calculated trace in %d seconds. \n', traceTime);

end


