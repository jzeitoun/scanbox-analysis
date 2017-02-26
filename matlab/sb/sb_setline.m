function sb_setline(n)

global sb img0_h;

x = uint16(n);
fwrite(sb,uint8([2  bitshift(bitand(x,hex2dec('ff00')),-8) bitand(x,hex2dec('00ff'))]));
img0_h.XData = [1 796]; % modified by JZ, added
img0_h.YData = [1 n]; % modified by JZ, added
set(img0_h.Parent,'XLim',[0 796],'YLim',[0 n]); % modified by JZ, added

