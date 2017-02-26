function sbx2tif_stdDev(fname)
    
z = sbxread(fname,1,1);
global info;

tic

numDiv = floor(info.max_idx/600);
remainder = info.max_idx - (numDiv*600);
global meanMatrix;
meanMatrix = uint16(zeros(info.sz(1),info.sz(2)),numDiv+1);

% calculate mean image using 600 frame chunks
for i = 1:numDiv+1
    if i == 1
        read = squeeze(sbxread(fname,i,599));
        meanImageSlice = mean(read,3);
        meanMatrix(:,:,i) = meanImageSlice;
    elseif i == numDiv+1
        a = ((i*600)-600)+1;
        read = squeeze(sbxread(fname,a,remainder));
        meanImageSlice = mean(read,3);
    else
        a = ((i*600)-600)+1;
        read = squeeze(sbxread(fname,a,599));
        meanImageSlice = mean(read,3);
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


