
function sbxwbmcb(src,callbackdata)

global segmenttool_h data nhood frames options th_corr bgimg mode_h

if(mode_h.Value == 1)
    
    p = gca;
    z = round(p.CurrentPoint);
    z = z(1,1:2);
    if(z(1)>0 && z(2)>0 && z(1)<796 && z(2)<512)
        cm = squeeze(sum(bsxfun(@times,data(z(2),z(1),:),data),3))/size(data,3);
        imgth = gather(cm>th_corr);
        bgimg.CData(:,:,2) = uint8(255*imgth);
        D = bwdistgeodesic(imgth,z(1,1),z(1,2));
        bw = imdilate(isfinite(D),strel('disk',1));
        bgimg.CData(:,:,3) = uint8(255*bw);
        drawnow;
    end
end