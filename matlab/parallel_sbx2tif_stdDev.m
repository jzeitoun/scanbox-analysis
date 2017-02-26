function parallel_sbx2tif_stdDev(fname,N)
    
z = sbxread(fname,1,1);
global info;

if nargin > 1
    maxIDX = min(N,info.max_idx);
else
    maxIDX = info.max_idx;
end

col = info.sz(1); 
row = info.sz(2);

numWorkers = 5;
chunk = 10;
a = maxIDX/numWorkers;
b = floor(maxIDX/chunk);

%if a > chunk
    numDiv = b;
    remainder = maxIDX - (numDiv*chunk);
    chunkSize = chunk;
%else
%    numDiv = numWorkers;
%    remainder = info.max_idx - (numDiv*floor(a));
%    chunkSize = floor(a);
%end

meanMatrix = uint16(zeros(col,row,numDiv+1));

refidx = 10;
ref = mean(squeeze(sbxread(fname,1,200)),3);

tic

% calculate mean image using chunks
parfor i = 1:numDiv+1    
    if i == 1
        tempM = uint16(zeros(col,row));
        for j = 1:chunkSize
            read = squeeze(sbxread(fname,j,1));
            [~,readA] = imregdemons(read,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
            disp(sprintf('Aligned frame %d.',j));
            tempM(:,:,j) = readA;
        end
        meanImageSlice = mean(tempM,3);
        meanMatrix(:,:,i) = meanImageSlice;
    elseif i == numDiv+1
        tempM = uint16(zeros(col,row));
        a = ((i*chunkSize)-chunkSize)+1;
        for j  = a:remainder
            read = squeeze(sbxread(fname,j,1));
            [~,readA] = imregdemons(read,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
            disp(sprintf('Aligned frame %d.',j));
            tempM(:,:,j) = readA;
        end
        meanImageSlice = mean(tempM,3);
        meanMatrix(:,:,i) = meanImageSlice;
    else
        tempM = uint16(zeros(col,row));
        a = ((i*chunkSize)-chunkSize)+1;
        for j = a:a+(chunkSize-1)
            read = squeeze(sbxread(fname,j,1));
            [~,readA] = imregdemons(read,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
            disp(sprintf('Aligned frame %d.',j));
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

for i = 1:maxIDX
    dRead = double(squeeze(sbxread(fname,i,1)));
    img = (dRead - meanImg).^2;
    if i == 1
        v = img;
    else
        v = v+img;
    end
end

varianceImg = v/maxIDX;
stdDevImg = sqrt(varianceImg);
stdDevImg = uint16(stdDevImg);
imwrite(stdDevImg,sprintf('STD_%s.tif',fname),'tif');

endTime = toc;
message = sprintf('Completed in %d seconds.',endTime);
disp(message);

end


