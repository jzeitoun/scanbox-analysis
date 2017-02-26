function r = sbxhartley(fname)

% analyze sparse noise experiment

log = sbxreadhartleylog(fname); % read log
log = log{1};       % assumes only 1 trial
max_k = max(abs(log.kx));

load([fname '_nonrigid.signals'],'-mat');    % load signals
sig = medfilt1(sig,11);             % median filter
sig = zscore(sig);
dsig = diff(sig);    
p = prctile(dsig,65);
dsig = bsxfun(@minus,dsig,p);
dsig = dsig .* (dsig>0);
dsig = zscore(dsig);

ncell = size(dsig,2);
nstim = size(log,1);

r = zeros(2*max_k+1,2*max_k+1,13,ncell);

h = waitbar(0,'Processing...');
for(i=1:nstim)
        r(log.kx(i)+1+max_k,log.ky(i)+1+max_k,:,:) =  squeeze(r(log.kx(i)+1+max_k,log.ky(i)+1+max_k,:,:)) + ...
            dsig(log.sbxframe(i)-2:log.sbxframe(i)+10,:);
    waitbar(i/nstim,h);
end
delete(h);

h = fspecial('gauss',5,1);
hh = waitbar(0,'Filtering...');
k = 0;
for(t=1:13)
    for(n = 1:ncell)
        rf = squeeze(r(:,:,t,n));
        rf = rf + rot90(rf,2); % symmetry 
        r(:,:,t,n) = filter2(h,rf,'same');
        k = k+1;
        waitbar(k/(13*2*ncell),hh);
    end
end
delete(hh);

save([fname '.hartley'],'r','-v7.3');


