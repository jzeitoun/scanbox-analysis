function sbx_rgProjections(fname)

z = sbxread(fname,1,1);
global info;

rg_channels = sbxread(fname,1,info.max_idx);
[channels,~,~,~] = size(rg_channels); % determine number of channels

if channels == 1
    channel = squeeze(rg_channels);
    
    if info.channels == 2 % green channel
        greenMAX = max(channel,[],3);
        greenAVG = mean(channel,3);
        
        for i = 1:info.max_idx
            dRead = double(channel(:,:,i));
            img = (dRead - greenAVG).^2;
            if i == 1
                v = img;
            else
                v = v+img;
            end
        end
    
        varianceImg = v/info.max_idx;
        stdDevImg = sqrt(varianceImg);

        greenSTD = uint16(stdDevImg);
        greenAVG = uint16(greenAVG);
        
        imwrite(greenMAX,['Green_MAX_' fname '.tif'],'tif');
        imwrite(greenAVG,['Green_AVG_' fname '.tif'],'tif');
        imwrite(greenSTD,['Green_STD_' fname '.tif'],'tif');
        
    else % red channel
        redMAX = max(channel,[],3);
        redAVG = uint16(mean(channel,3));
        
        imwrite(redMAX,['Red_MAX_' fname '.tif'],'tif');
        imwrite(redAVG,['Red_AVG_' fname '.tif'],'tif');
    end

else
    green = squeeze(rg_channels(1,:,:,:));
    red = squeeze(rg_channels(2,:,:,:));

    % produce average and max projections for red and green
    greenMAX = max(green,[],3);
    greenAVG = mean(green,3);

    redMAX = max(red,[],3);
    redAVG = uint16(mean(red,3));

    % produce standard deviation projection
    for i = 1:info.max_idx
        dRead = double(green(:,:,i));
        img = (dRead - greenAVG).^2;
        if i == 1
            v = img;
        else
            v = v+img;
        end
    end

    varianceImg = v/info.max_idx;
    stdDevImg = sqrt(varianceImg);

    greenSTD = uint16(stdDevImg);
    greenAVG = uint16(greenAVG);

    % write projection tiffs
    imwrite(greenMAX,['Green_MAX_' fname '.tif'],'tif');
    imwrite(greenAVG,['Green_AVG_' fname '.tif'],'tif');
    imwrite(greenSTD,['Green_STD_' fname '.tif'],'tif');
    imwrite(redMAX,['Red_MAX_' fname '.tif'],'tif');
    imwrite(redAVG,['Red_AVG_' fname '.tif'],'tif');

end

end
