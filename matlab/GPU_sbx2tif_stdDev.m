function GPU_sbx2tif_stdDev(fname)
    
z = sbxread(fname,1,1);
global info;

col = info.sz(1); 
row = info.sz(2);

numWorkers = 5;
chunk = 100;
a = info.max_idx/numWorkers;
b = floor(info.max_idx/chunk);

if a > chunk
    numDiv = b;
    remainder = info.max_idx - (numDiv*600);
    chunkSize = chunk;
else
    numDiv = numWorkers;
    remainder = info.max_idx - (numDiv*floor(a));
    chunkSize = floor(a);
end

meanMatrix = uint16(zeros(col,row,numDiv+1));

refidx = 10;
ref = squeeze(sbxread(fname,refidx,1));
GPUref = gpuArray(ref);

tic

% calculate mean image using chunks
for i = 1:numDiv+1    
    if i == 1
        tempM = uint16(zeros(col,row));
        for j = 1:chunkSize
            read = squeeze(sbxread(fname,j,1));
            GPUread = gpuArray(read);
            [~,GPUreadA] = imregdemons(GPUread,GPUref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
            readA = gather(GPUreadA);
            tempM(:,:,j) = readA;
        end
        meanImageSlice = mean(tempM,3);
        meanMatrix(:,:,i) = meanImageSlice;
    elseif i == numDiv+1
        tempM = uint16(zeros(col,row));
        a = ((i*chunkSize)-chunkSize)+1;
        for j  = a:remainder
            read = squeeze(sbxread(fname,j,1));
            GPUread = gpuArray(read);
            [~,GPUreadA] = imregdemons(GPUread,GPUref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
            readA = gather(GPUreadA);
            tempM(:,:,j) = readA;
        end
        meanImageSlice = mean(tempM,3);
        meanMatrix(:,:,i) = meanImageSlice;
    else
        tempM = uint16(zeros(col,row));
        a = ((i*chunkSize)-chunkSize)+1;
        for j = a:a+(chunkSize-1)
            read = squeeze(sbxread(fname,j,1));
            GPUread = gpuArray(read);
            [~,GPUreadA] = imregdemons(GPUread,GPUref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
            readA = gather(GPUreadA);
            tempM(:,:,j) = readA;
        end
        meanImageSlice = mean(tempM,3);
        meanMatrix(:,:,i) = meanImageSlice;
    end
end

meanImg = mean(meanMatrix,3);
meanTime = toc;
message = sprintf('Calculated mean image in %d seconds.', meanTime);
disp(message);

for i = 1:info.max_idx
    dRead = double(squeeze(sbxread(fname,i,1)));
    img = (dRead - meanImg).^2;
    if i == 1
        v = img;
    else
        v = v+img;
    end
end

varianceImg = v/info.max_idx;
stdDevImg = sqrt(varianceImg);
stdDevImg = uint16(stdDevImg);
imwrite(stdDevImg,sprintf('STD_%s.tif',fname),'tif');

endTime = toc;
message = sprintf('Completed in %d seconds.',endTime);
disp(message);

end