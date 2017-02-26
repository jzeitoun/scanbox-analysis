function sbxwbdcb(src,callbackdata)

global bgimg mask
global ncell cellpoly status segmenttool_h data mode_h

p = gca;
if(mode_h.Value ==1)
    z = round(p.CurrentPoint);
    z = z(1,1:2);
    m = findobj(segmenttool_h,'tag','method');
    if(z(1)>0 && z(2)>0 && z(1)<796 && z(2)<512)
        switch m.Value
            case 1
                bw = bgimg.CData(:,:,3);
                B = bwboundaries(bw);
                xy = B{1};
                hold(bgimg.Parent,'on');
                h = patch(xy(:,2),xy(:,1),'white','facecolor',[1 .7 .7],'facealpha',0.7,'edgecolor',[1 1 1],'parent',bgimg.Parent,'FaceLighting','none');
                ncell = ncell+1;
                cellpoly{ncell} = h;
                [xx,yy] = meshgrid(1:size(mask,2),1:size(mask,1));
                bw=(inpolygon(xx,yy,xy(:,2),xy(:,1)));
                mask(bw) = ncell;
                hold(bgimg.Parent,'off');
                
                % rescale...
                r = single(bgimg.CData(:,:,1));
                r(mask>0) = 0;
                r = (r-min(r(:)))/(max(r(:))-min(r(:)));
                bgimg.CData(:,:,1) = uint8(r*255);
                status.String = sprintf('Segmented %d cells',ncell);
                drawnow;
                
            case 2
                global nhood_h
                nh = str2double(nhood_h.String);
                img = data(z(2)-nh:z(2)+nh,z(1)-nh:z(1)+nh,:);
                N = size(img,1);
                [xx,yy] = meshgrid(1:N,1:N);
                img = reshape(img,[N*N size(img,3)]);
                lambda = 150;
                img(:,end+1) = lambda*xx(:);
                img(:,end+1) = lambda*yy(:);
                [uu,~,~] = svd(img,0);
                idx = kmeans(uu(:,1:8),4);
                idx = reshape(idx,[N N]);
                
                idx = (idx==idx(nh+1,nh+1));
                idx = imclearborder(gather(idx));
                idx = bwdistgeodesic(idx,nh+1,nh+1);
                idx = imopen(isfinite(idx),strel('disk',1));
                
                if(sum(idx(:))>40)
                    
                    [ii,jj] = find(idx);
                    ii = ii+z(2)-(nh+1); jj = jj+z(1)-(nh+1);
                    z = zeros(size(bgimg.CData,1),size(bgimg.CData,2),'uint8');
                    idx = sub2ind(size(z),ii,jj);
                    z(idx) = 1;
                    bgimg.CData(:,:,3) = z;
                    
                    B = bwboundaries(z);
                    xy = B{1};
                    hold(bgimg.Parent,'on');
                    h = patch(xy(:,2),xy(:,1),'white','facecolor',[1 .7 .7],'facealpha',0.7,'edgecolor',[1 1 1],'parent',bgimg.Parent,'FaceLighting','none');
                    ncell = ncell+1;
                    cellpoly{ncell} = h;
                    
                    hold(bgimg.Parent,'off');
                    mask(z==1) = ncell;
                    
                    % rescale...
                    r = single(bgimg.CData(:,:,1));
                    r(mask>0) = 0;
                    r = (r-min(r(:)))/(max(r(:))-min(r(:)));
                    bgimg.CData(:,:,1) = uint8(r*255);
                    status.String = sprintf('Segmented %d cells',ncell);
                    drawnow;
                end
                
        end
        
    end
end
