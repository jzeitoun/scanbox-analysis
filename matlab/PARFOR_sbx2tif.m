function PARFOR_sbx2tif(fname,aligned,varargin) 
% sbx2tif_rgb
% Generates tif file from sbx files
% Writes out file as RGB for single or multi channel recordings
% If aligned = 0, no alignment will occur. If aligned = 1, frames will be aligned. 
% Arguments beyond 'aligned' are optional. If no argument is passed the whole file is written.
% Example: sbx2tif_rgb('day1_000_000',1,200); This will align the first 200 frames and convert to tiff.
 
%k_initial = k;
z = sbxread(fname,1,1);
global info;
 
if aligned == 0           % Determine whether to align
    align_frames = false;
else
    align_frames = true;
end
 
if(nargin>2)
    N = min(varargin{1},info.max_idx);
else
    N = info.max_idx;
end

tic;

tiff = Tiff([fname '.tif'],'w');

tagstruct.ImageLength = info.sz(1);
tagstruct.ImageWidth = info.sz(2);
tagstruct.Photometric = Tiff.Photometric.RGB;
tagstruct.BitsPerSample = 8;
tagstruct.Compression = Tiff.Compression.PackBits;
tagstruct.SamplesPerPixel = 3;
tagstruct.RowsPerStrip = 16;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB';

tiff.setTag(tagstruct);

col = info.sz(1);
row = info.sz(2);
tempIFD = uint8(cat(3,zeros(col,row),zeros(col,row),zeros(col,row)));

tiff.write(tempIFD);

for i = 1:info.max_idx-1
    tiff.writeDirectory();
    tiff.setTag(tagstruct);
    tiff.write(tempIFD);
end



switch info.channels
        case 1                  % Both Channels (PMT 0 + 1)
            %k = 1;
            done = 0;
            refidx = 10; %floor(info.max_idx/2);
            ref1 = sbxread(fname,refidx,1);
            ref1 = squeeze(ref1(1,:,:));
            ref2 = sbxread(fname,refidx,1);
            ref2 = squeeze(ref2(2,:,:));
            %ref = imfuse(ref1,ref2,'falsecolor','Scaling','none','ColorChannels',[2 1 0]);
            
            while(~done && k<=N)
                try
                    q = sbxread(fname,k,1);
                    a = squeeze(q(1,:,:));
                    b = squeeze(q(2,:,:));
                    % Align the frames if set to true
                    if align_frames == true
                        [~,aReg] = imregdemons(a,ref1,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
                        a = aReg;
                        [~,bReg] = imregdemons(b,ref2,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
                        b = bReg;
                    end       
                    q = imfuse(a,b,'falsecolor','Scaling','none','ColorChannels',[2 1 0]);
                     
                    if(k==k_initial)
                        imwrite(q,[fname '.tif'],'tif');
                    else
                        imwrite(q,[fname '.tif'],'tif','writemode','append');
                    end
                catch
                    done = 1;
                end
                k = k+1;
            end
            
        case 2                  % Green Channel (PMT 0)
            %k = 1;
            done = 0;
            refidx = 10; %floor(info.max_idx/2);
            ref = sbxread(fname,refidx,1);
            ref = squeeze(ref(1,:,:));
            
            for k = 1:info.max_idx-1
                    q = sbxread(fname,k,1);
                    q = squeeze(q(1,:,:));
                    % Align the frames if set to true
                    if align_frames == true
                        [~,qA] = imregdemons(q,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
                        q = qA;
                    end
                    [a,b] = size(q);
                    q = repmat(q,1,1,3);
                    gm = cat(3,zeros(a,b),ones(a,b),zeros(a,b));
                    q = double(q);
                    q = q.*gm;
                    q = q/65535;
                    q = 255.*q;
                    q = uint8(q);
                    
                    tiff.setDirectory(k);
                    tiff.write(q);
                end
            
        case 3                  % Red Channel (PMT 1)
            %k = 1;
            done = 0;
            refidx = 10; %floor(info.max_idx/2);
            ref = sbxread(fname,refidx,1);
            ref = squeeze(ref(1,:,:));
            while(~done && k<=N)
                try
                    q = sbxread(fname,k,1);
                    q = squeeze(q(2,:,:));
                    % Align the frames if set to true
                    if align_frames == true
                        [~,qA] = imregdemons(q,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
                        q = qA;
                    end
                    [a,b] = size(q);
                    q = repmat(q,1,1,3);
                    gm = cat(3,ones(a,b),zeros(a,b),zeros(a,b));
                    q = double(q);
                    q = q.*gm;
                    q = q/65535;
                    q = 255.*q;
                    q = uint8(q);
                    if(k==k_initial)
                        imwrite(q,[fname '.tif'],'tif');
                    else
                        imwrite(q,[fname '.tif'],'tif','writemode','append');
                    end
                catch
                    done = 1;
                end
                k = k+1;
            end
end

tiff.close;

toc;

end
