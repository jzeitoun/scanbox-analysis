function [eye,eye_data] = sbxeyemotion(fn,varargin)
   load(fn,'-mat'); % should be a '*_eye.mat' file
   W = 40;
 
   if nargin > 1
      rad_range = varargin{1};
   else
      rad_range = [12 32]; % range of radii to search for
   end
 
   data = squeeze(data); % the raw images...
   eye_data = repmat(data,1,1,1,3);
   xc = size(data,2)/2; % image center
   yc = size(data,1)/2;
 
   warning off;
 
   for(n=1:size(data,3))
      [center,radii,metric] = imfindcircles(squeeze(data(yc-W:yc+W,xc-W:xc+W,n)),rad_range,'Sensitivity',1);
      if(isempty(center))
         eye(n).Centroid = [NaN NaN]; % could not find anything...
         eye(n).Area = NaN;
      else
         [~,idx] = max(metric); % pick the circle with best score
         eye(n).Centroid = center(idx,:);
         eye(n).Area = pi*radii(idx)^2;
         green = uint8([0 255 0]);
         circle = int32([center(idx,1)+40,center(idx,2)+40,radii(idx)]);
         %shapeInserter = vision.ShapeInserter('Shape','Circles','BorderColor','Custom','CustomBorderColor',green);
         %shapeInserter = vision.ShapeInserter('Circles',[center(1),center(2),radii])
         RGB = repmat(data(:,:,n),[1,1,3]);
         eye_data(:,:,n,:) = insertShape(RGB,'circle',circle,'Color','green','LineWidth',3);  
      end
   end
 
   save(fn,'eye','-append'); % append the motion estimate data...
