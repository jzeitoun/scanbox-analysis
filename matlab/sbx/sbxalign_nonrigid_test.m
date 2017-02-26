function [m,disp] = sbxalign_nonrigid_test(fname,idx)
    global D;
 
if(length(idx)==1)
   A = squeeze(sbxread(fname,idx(1),1)); % just one frame... easy!
   m = A;
   disp = {zeros([size(A) 2])};
elseif (length(idx)==2) % align two frames
   A = squeeze(sbxread(fname,idx(1),1)); % read the frames
   B = squeeze(sbxread(fname,idx(2),1));
   [D,Ar] = imregdemons(A,B,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4);
   m = (Ar/2+B/2);
  disp = {D zeros([size(A) 2])};
else
   idx0 = idx(1:floor(end/2)); % split dataset in two
   idx1 = idx(floor(end/2)+1 : end); % recursive alignment
   [A,D0] = sbxalign_nonrigid_test(fname,idx0);
   [B,D1] = sbxalign_nonrigid_test(fname,idx1);
   [D,Ar] = imregdemons(A,B,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4);
   m = (Ar/2+B/2);
   D0 = cellfun(@(x) (x+D),D0,'UniformOutput',false); % concatenate distortions
   disp = [D0 D1];
end