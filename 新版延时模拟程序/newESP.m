% 新版延时模拟及破坏修复模拟程序
% 预处理

clear;close all; clc;tic
% fid = fopen([output_dir,'计算书.txt'],'w');% 打开计算书
fid =1;
fprintf(fid,'%s','开始程序');fprintf(fid,'\r\n');
lib_directory='C:\Users\hc042\Desktop\renxingjisuancode2\';fprintf(fid,'%s',['load=',lib_directory]);fprintf(fid,'\r\n');
funcName = 'newEPS';
libName = 'epanet2';hfileName = 'epanet2.h';fprintf(fid,'%s',['load  ',libName,'/',hfileName]);fprintf(fid,'\r\n');
if libisloaded(libName)
    unloadlibrary (libName)
end
loadlibrary(libName,hfileName);
try
    load  EPA_F
catch
    path('C:\Users\hc042\Desktop\renxingjisuancode2\toolkit',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\readNet',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\damageNet',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\EPS',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\getValue',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\eventTime',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\random',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\random_singleTime',path);%单点模拟所需的函数。
    load  EPA_F2
end
input_net_filename = 'net01.inp';
damage_file = 'damage.txt';
damage_net = 'damage_net.inp';

output_dir=['C:\Users\hc042\Desktop\计算结果','\222\',];
if isdir(output_dir)
    rmdir(output_dir,'s')
end
mkdir(output_dir);
%PDD=============
Hmin=0;%Hmin节点最小压力
Hdes=10;%Hdes节点需求压力;
doa=0.01;%PDD计算精度
circulation_num=40;%PDD循环次数
% repair=================
RepairCrew={'a'};
pipeStatus = [2,1,1,1,0,0,0;
    2,2,2,2,1,0,0];
time = [0,3600,7200,10800,14400,18000,21600];
%=======================
% EPA_format_filename = 'EPA_FORMAT5.txt';
% fid=fopen(EPA_format_filename,'r'); %打开EPA水力模型文件的数据存储格式参数；
% EPA_format=textscan(fid,'%q%q%q%q','delimiter',';');%读取inp文件中的关键词及数据存储类型格式的文件；
% fclose(fid);
% save EPA_F2 EPA_format
%=======================

[t1, net_data ] = read_net( input_net_filename,EPA_format);
if t1
    keyboard
end
[t_e,damage_pipe_info]=ND_Execut_deterministic(net_data,'damage.txt');
t_w = write_Damagefile(damage_pipe_info,'damage2.txt');
if t_e&&t_w
    disp('errors==================');
    keyboard
end
[t_W,pipe_relative]=damageNetInp2_GIRAFFE2(net_data,damage_pipe_info,EPA_format,damage_net);
% 延时模拟
node_id = net_data{2,2}(:,1);%破坏前节点名称
original_junction_num = numel(node_id);%破坏前节点数目
link_id = net_data{5,2}(:,1);%破坏前管线名称
t=calllib('epanet2','ENopen',damage_net,[output_dir,'1.rpt'],[output_dir,'1.out']);
% value =  libpointer('singlePtr',100);
% [c,value] = calllib(libName,'ENgetlinkvalue',1,11,value)
% type = libpointer('int32Ptr',100)
% [c,type] = calllib(libName,'ENgetlinktype',5,type)
if t
    disp('errors==================');
    disp(num2str(t));
end
t1 = calllib('epanet2','ENopenH');
code = calllib('epanet2','ENinitH',0);
n_j =0;
n_r=0;
[c,n_j] = calllib('epanet2','ENgetcount',0,n_j);
[c,n_r] = calllib('epanet2','ENgetcount',1,n_r);
junction_num =n_j -n_r;
temp_t =0;
temp_tstep =1;
time_step_n=0;
% PipeStatus=[time;pipeStatus];
PipeStatus=[pipeStatus];
[newPipeStatus ,timeStepChose]= pipeStatusChange(PipeStatus);
while (temp_tstep &&~code)
    time_step_n=time_step_n+1;
    [code,temp_t]=calllib('epanet2','ENrunH',temp_t);%计算
    if code
        disp(['错误代码：',num2str(code)]);
        keyboard
    end
    [~,based_demand]=Get(junction_num,1);%基础需水量
    [~,real_demand]=Get(junction_num,9);%实际需水量
    [~,real_pre]=Get(junction_num,11);%水压
    [~,real_demand_chosen]=Get_chosen_node_value(original_junction_num,node_id);
    %     if find(real_pre<Hdes) %发现低压则进行PDD运算
    [pre,dem] = EPS_PDD2(circulation_num,doa,Hmin,Hdes,net_data,temp_t,real_demand,based_demand,real_demand_chosen);
    %     end
    time_step_n_cell{time_step_n} =time_step_n;
    TimeStep{time_step_n} =double(temp_t);
    Pressure{time_step_n} = double(pre);
    Demand{time_step_n}=double(dem);
    %      len = Get_chosen_link_value(link_id);
    %=============================================
    disp(num2str(temp_t))
    [lia,loc] = ismember(time_step_n,timeStepChose);
    if lia
        fprintf(fid,'%s\r\n','开始修改管道状态');
        
        mid_status = newPipeStatus(:,loc);
        for i = 1:numel(mid_status)
            pipe_status = mid_status(i);
            switch  pipe_status
                case 2
                    continue %该管道没有修复
                case 1
                    %管道隔离
                    for j =1:numel(pipe_relative{i,2})% 隔离的管道为当前管道相关联的破坏管道。
                        id = libpointer('cstring',pipe_relative{i,2}{1,j});
                        fprintf(fid,'隔离管道:%s\r\n',pipe_relative{i,2}{1,j} );
                        index =libpointer('int32Ptr',0);
                        [code,id,index]=calllib('epanet2','ENgetlinkindex',id,index);
                        if code
                            disp(nem2str(code));
                            keyboard
                        end
                        code=calllib('epanet2','ENsetlinkvalue',index,11,0);%管道id状态为关闭
                        if code
                            disp(nem2str(code));
                            fprintf(fid,'隔离管道:%s出错,代码%s\r\n',id,num2str(code) );
                            keyboard
                        end
                    end
                case 0
                    %reopen 管道，说明该管道修复
                    id=libpointer('cstring',pipe_relative{i,1});
                    index =libpointer('int32Ptr',0);
                    [code,id,index]=calllib('epanet2','ENgetlinkindex',id,index);
                   
                    if code
                        disp(nem2str(code));
                        keyboard
                    end
                    code= calllib('epanet2','ENsetlinkvalue',index,11,1);
                     fprintf(fid,'reopen管道%s,\r\n',pipe_relative{i,1});
                    if code
                        disp(nem2str(code));
                        fprintf(fid,'reopen管道:%s出错,代码%s\r\n',id,num2str(code) );
                        keyboard
                    end
            end
        end
        fprintf(fid,'%s时刻,管道状态修改完毕\r\n',num2str(temp_t) );
    else
        fprintf(fid,'%s时刻,无需修改管道状态\r\n',num2str(temp_t) );
    end
    
    [code,temp_tstep]=calllib('epanet2','ENnextH',temp_tstep);
end
calllib('epanet2','ENcloseH');
calllib('epanet2','ENsaveH');%保存水力文件
calllib('epanet2','ENsetreport','NODES ALL'); % 设置输出报告的格式
calllib('epanet2','ENreport');
calllib('epanet2','ENclose');
