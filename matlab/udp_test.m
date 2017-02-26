function udp_test

global sb_server

udp_open;
%sb_server.BytesAvailableFcnCount = 1;
%sb_server.BytesAvailableFcnMode = 'byte';
%sb_server.BytesAvailableFcn = @udp_close;

while true
    if sb_server.BytesAvailable > 0
            udp_cb(sb_server,[]);
    end
end

function udp_open

%global sb_server;

if(~isempty(sb_server))
    udp_close;
end

sb_server = udp('localhost', 'LocalPort', 7000);%,'BytesAvailableFcn',@udp_cb);
fopen(sb_server);

end


function udp_close

%global sb_server;

try
    fclose(sb_server);
    delete(sb_server);
catch
    sb_server = [];
end
end

function udp_cb(a,b)

s = fgetl(a);

end

end
