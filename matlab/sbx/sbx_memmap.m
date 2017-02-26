function mm = sbx_memmap(fname)
% Creates memory map to raw sbx data.
% Only intended for single-channel data.

sbx = sbxread(fname,1,1);
global info;

max_idx = info.max_idx;
rows = info.sz(1);
cols = info.sz(2);

mm = memmapfile([fname '.sbx'],'Format',{'uint16' [cols rows max_idx] 'img'},'Repeat',1,'Writable',true);

